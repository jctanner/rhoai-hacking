package main

import (
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"sync"

	"github.com/coreos/go-oidc/v3/oidc"
	oauth2 "golang.org/x/oauth2"
)

type RouteConfig struct {
	PathPrefix string `json:"pathPrefix"`
	Upstream   string `json:"upstream"`
}

var (
	issuerURL    = os.Getenv("OIDC_ISSUER")
	clientID     = os.Getenv("OIDC_CLIENT_ID")
	clientSecret = os.Getenv("OIDC_CLIENT_SECRET")
	redirectURL  = os.Getenv("OIDC_REDIRECT_URL")

	routeConfigPath = os.Getenv("ROUTE_CONFIG_PATH")

	routeConfigs     []RouteConfig
	redirectStateMap sync.Map // state -> original path
)

func main() {
	// Load route config from file, or fallback to defaults
	if routeConfigPath == "" {
		routeConfigPath = "routes.json"
	}
	if err := loadRouteConfig(routeConfigPath); err != nil {
		log.Printf("[config] Warning: %v. Falling back to default route mappings.", err)
		routeConfigs = []RouteConfig{
			{PathPrefix: "/echo-a", Upstream: "http://echo-a:5678"},
			{PathPrefix: "/echo-b", Upstream: "http://echo-b:5678"},
			{PathPrefix: "/echo-c-protected", Upstream: "http://oauth2-echo-c:4180"},
		}
	}

	// Set up HTTP client that skips TLS verification (for self-signed certs)
	insecureTransport := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	insecureClient := &http.Client{Transport: insecureTransport}
	ctx := oidc.ClientContext(context.Background(), insecureClient)

	// Discover OIDC provider
	provider, err := oidc.NewProvider(ctx, issuerURL)
	if err != nil {
		log.Fatalf("Failed to get OIDC provider: %v", err)
	}

	verifier := provider.Verifier(&oidc.Config{ClientID: clientID})
	oauth2Config := &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint:     provider.Endpoint(),
		RedirectURL:  redirectURL,
		Scopes:       []string{oidc.ScopeOpenID, "profile", "email"},
	}

	http.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		logRequest("CALLBACK", r)

		code := r.URL.Query().Get("code")
		state := r.URL.Query().Get("state")
		if code == "" || state == "" {
			http.Error(w, "Missing code or state", http.StatusBadRequest)
			return
		}

		token, err := oauth2Config.Exchange(ctx, code) // <- use the context with InsecureSkipVerify
		if err != nil {
			log.Printf("[callback] Token exchange failed: %v", err)
			http.Error(w, "Token exchange failed", http.StatusInternalServerError)
			return
		}

		rawIDToken, ok := token.Extra("id_token").(string)
		if !ok {
			http.Error(w, "No id_token field", http.StatusInternalServerError)
			return
		}

		http.SetCookie(w, &http.Cookie{
			Name:     "id_token",
			Value:    rawIDToken,
			Path:     "/",
			HttpOnly: true,
			SameSite: http.SameSiteLaxMode,
		})

		var originalPath string
		if val, ok := redirectStateMap.Load(state); ok {
			originalPath = val.(string)
			redirectStateMap.Delete(state)
		} else {
			originalPath = "/"
		}
		http.Redirect(w, r, originalPath, http.StatusSeeOther)
	})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		logRequest("MAIN", r)

		cookie, err := r.Cookie("id_token")
		if err != nil || cookie.Value == "" {
			state := generateState()
			originalPath := r.URL.RequestURI()
			redirectStateMap.Store(state, originalPath)
			loginURL := oauth2Config.AuthCodeURL(state)
			http.Redirect(w, r, loginURL, http.StatusFound)
			return
		}

		_, err = verifier.Verify(r.Context(), cookie.Value)
		if err != nil {
			http.Error(w, "Invalid token", http.StatusUnauthorized)
			return
		}

		for _, rc := range routeConfigs {
			if strings.HasPrefix(r.URL.Path, rc.PathPrefix) {
				log.Printf("[proxy] Match %s → %s", rc.PathPrefix, rc.Upstream)
				proxyTo(w, r, rc.Upstream)
				return
			}
		}

		fmt.Fprintf(w, "Hello, authenticated user! No route matched.")
	})

	port := os.Getenv("PORT_NUMBER")
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting OIDC proxy on :%s\n", port)
	http.ListenAndServe(":"+port, nil)
}

/*
func proxyTo(w http.ResponseWriter, r *http.Request, upstream string) {
	target, err := url.Parse(upstream)
	if err != nil {
		http.Error(w, "Bad upstream URL", http.StatusInternalServerError)
		return
	}

	clone := r.Clone(r.Context())
	if cookie, err := r.Cookie("id_token"); err == nil && cookie.Value != "" {
		clone.Header.Set("Authorization", "Bearer "+cookie.Value)
		clone.Header.Set("USER_ACCESS_TOKEN", cookie.Value)
		clone.Header.Set("X-FORWARDED-ACCESS-TOKEN", cookie.Value)
	}

	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.ServeHTTP(w, clone)
}
*/

func proxyTo(w http.ResponseWriter, r *http.Request, upstream string) {
	target, err := url.Parse(upstream)
	if err != nil {
		http.Error(w, "Bad upstream URL", http.StatusInternalServerError)
		return
	}

	clone := r.Clone(r.Context())
	if cookie, err := r.Cookie("id_token"); err == nil && cookie.Value != "" {

		clone.Header.Set("Authorization", "Bearer "+cookie.Value)
		clone.Header.Set("USER_ACCESS_TOKEN", cookie.Value)
		clone.Header.Set("X-FORWARDED-ACCESS-TOKEN", cookie.Value)

		claims, err := decodeTokenClaims(cookie.Value)
		if err != nil {
			log.Fatalf("Error decoding token: %v", err)
		} else {
			pretty, err := json.MarshalIndent(claims, "", "  ")
			if err != nil {
				log.Fatalf("Failed to marshal claims for decoded cookie token: %v", err)
			} else {
				log.Printf("Decoded cookie token ..")
				//fmt.Println(string(pretty))
				log.Printf(string(pretty))
			}
		}

		// Try exchanging token for one with desired audience
		exchanged, err := exchangeTokenIfNeeded(
			cookie.Value,
			"console-test",
			http.DefaultClient, // or insecureClient if needed
		)
		if err != nil {
			log.Printf("[proxy] Token exchange failed: %v", err)
			exchanged = cookie.Value // fallback
		} else {
			clone.Header.Set("X-FORWARDED-ACCESS-TOKEN", exchanged)
		}
	}

	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.ServeHTTP(w, clone)
}

func loadRouteConfig(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read config file: %w", err)
	}
	if err := json.Unmarshal(data, &routeConfigs); err != nil {
		return fmt.Errorf("failed to parse config: %w", err)
	}
	log.Printf("[config] Loaded %d route(s) from %s", len(routeConfigs), path)
	return nil
}

func generateState() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func logRequest(tag string, r *http.Request) {
	log.Printf("[%s] %s %s", tag, r.Method, r.URL.Path)
	for k, v := range r.Header {
		log.Printf("[%s] Header: %s=%s", tag, k, strings.Join(v, ", "))
	}
}

func exchangeTokenIfNeeded(rawToken string, audience string, httpClient *http.Client) (string, error) {

	claims, err := decodeTokenClaims(rawToken)
	if err != nil {
		return "", err
	}

	// Extract audience
	audClaim, ok := claims["aud"]
	if !ok {
		return "", fmt.Errorf("aud claim missing")
	}

	audList := []string{}
	switch v := audClaim.(type) {
	case string:
		audList = append(audList, v)
	case []interface{}:
		for _, a := range v {
			if s, ok := a.(string); ok {
				audList = append(audList, s)
			}
		}
	}

	for _, a := range audList {
		if a == audience {
			// Already has desired audience
			return rawToken, nil
		}
	}

	// Perform token exchange
	data := url.Values{}
	data.Set("grant_type", "urn:ietf:params:oauth:grant-type:token-exchange")
	data.Set("subject_token", rawToken)
	data.Set("subject_token_type", "urn:ietf:params:oauth:token-type:access_token")
	data.Set("requested_token_type", "urn:ietf:params:oauth:token-type:access_token")
	data.Set("audience", audience)
	data.Set("client_id", clientID)
	data.Set("client_secret", clientSecret)

	tokenURL := issuerURL + "/protocol/openid-connect/token"
	req, err := http.NewRequest("POST", tokenURL, strings.NewReader(data.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("token exchange failed: %s", string(body))
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	newToken, ok := result["access_token"].(string)
	if !ok {
		return "", fmt.Errorf("access_token missing in response")
	}

	return newToken, nil
}

func decodeTokenClaims(rawToken string) (map[string]interface{}, error) {
	parts := strings.Split(rawToken, ".")
	if len(parts) != 3 {
		return nil, fmt.Errorf("invalid token format")
	}

	// Decode the payload (base64url)
	payload := parts[1]
	decoded, err := base64.RawURLEncoding.DecodeString(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to decode payload: %w", err)
	}

	var claims map[string]interface{}
	if err := json.Unmarshal(decoded, &claims); err != nil {
		return nil, fmt.Errorf("failed to unmarshal claims: %w", err)
	}

	return claims, nil
}
