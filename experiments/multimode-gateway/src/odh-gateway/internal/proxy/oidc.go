package proxy

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"golang.org/x/oauth2"
)

// OIDCConfig holds OIDC configuration
type OIDCConfig struct {
	Enabled      bool
	IssuerURL    string
	ClientID     string
	ClientSecret string
}

// OIDCMiddleware handles OIDC authentication
type OIDCMiddleware struct {
	config       OIDCConfig
	provider     *oidc.Provider
	oauth2Config oauth2.Config
	verifier     *oidc.IDTokenVerifier
	defaultAuth  bool // Global default for authentication requirement
	baseURL      string
	initialized  bool
}

// NewOIDCMiddleware creates a new OIDC middleware
func NewOIDCMiddleware(config OIDCConfig, defaultAuth bool, baseURL string) (*OIDCMiddleware, error) {
	return &OIDCMiddleware{
		config:      config,
		defaultAuth: defaultAuth,
		baseURL:     baseURL,
		initialized: false,
	}, nil
}

// initializeProvider initializes the OIDC provider (lazy initialization)
func (o *OIDCMiddleware) initializeProvider() error {
	if o.initialized || !o.config.Enabled {
		return nil
	}

	ctx := context.Background()
	provider, err := oidc.NewProvider(ctx, o.config.IssuerURL)
	if err != nil {
		return fmt.Errorf("failed to create OIDC provider: %w", err)
	}

	// Configure OAuth2
	o.oauth2Config = oauth2.Config{
		ClientID:     o.config.ClientID,
		ClientSecret: o.config.ClientSecret,
		RedirectURL:  o.baseURL + "/oidc/callback",
		Endpoint:     provider.Endpoint(),
		Scopes:       []string{oidc.ScopeOpenID, "profile", "email"},
	}

	// Configure ID token verifier
	o.verifier = provider.Verifier(&oidc.Config{ClientID: o.config.ClientID})
	o.provider = provider
	o.initialized = true

	log.Printf("OIDC provider initialized successfully for issuer: %s", o.config.IssuerURL)
	return nil
}

// Middleware returns an HTTP middleware that handles OIDC authentication
func (o *OIDCMiddleware) Middleware(authRequired *bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Determine if auth is required for this route
			requireAuth := o.defaultAuth
			if authRequired != nil {
				requireAuth = *authRequired
			}

			// Skip auth if not required or OIDC not enabled
			if !requireAuth || !o.config.Enabled {
				next.ServeHTTP(w, r)
				return
			}

			// Initialize OIDC provider if needed
			if err := o.initializeProvider(); err != nil {
				log.Printf("Failed to initialize OIDC provider: %v", err)
				http.Error(w, "Authentication service temporarily unavailable", http.StatusServiceUnavailable)
				return
			}

			// Handle OIDC callback
			if r.URL.Path == "/oidc/callback" {
				o.handleCallback(w, r)
				return
			}

			// Handle logout
			if r.URL.Path == "/oidc/logout" {
				o.handleLogout(w, r)
				return
			}

			// Check for existing valid session and inject user headers
			if authenticated, username, groups := o.checkAuthAndExtractClaims(r); authenticated {
				// Inject user context headers for downstream services
				r.Header.Set("X-Forwarded-User", username)
				if len(groups) > 0 {
					r.Header.Set("X-Forwarded-Groups", strings.Join(groups, ","))
				}
				next.ServeHTTP(w, r)
				return
			}

			// Redirect to OIDC provider for authentication
			o.redirectToAuth(w, r)
		})
	}
}

// checkAuthAndExtractClaims checks authentication and extracts user claims
func (o *OIDCMiddleware) checkAuthAndExtractClaims(r *http.Request) (bool, string, []string) {
	if !o.initialized {
		return false, "", nil
	}

	// Try to get JWT token from cookie first, then Authorization header
	var tokenString string

	// Check OIDC cookie
	if cookie, err := r.Cookie("oidc_token"); err == nil {
		tokenString = cookie.Value
	} else {
		// Check Authorization header
		authHeader := r.Header.Get("Authorization")
		if strings.HasPrefix(authHeader, "Bearer ") {
			tokenString = strings.TrimPrefix(authHeader, "Bearer ")
		}
	}

	if tokenString == "" {
		return false, "", nil
	}

	// Verify the ID token
	ctx := context.Background()
	idToken, err := o.verifier.Verify(ctx, tokenString)
	if err != nil {
		log.Printf("Token verification failed: %v", err)
		return false, "", nil
	}

	// Extract claims
	var claims map[string]interface{}
	if err := idToken.Claims(&claims); err != nil {
		log.Printf("Failed to extract claims: %v", err)
		return true, "", nil // Token is valid but claims extraction failed
	}

	// Extract username (try preferred_username first, then sub)
	username := ""
	if preferred, ok := claims["preferred_username"].(string); ok {
		username = preferred
	} else if sub, ok := claims["sub"].(string); ok {
		username = sub
	}

	// Extract groups
	var groups []string
	if groupsClaim, ok := claims["groups"]; ok {
		switch v := groupsClaim.(type) {
		case []interface{}:
			for _, group := range v {
				if groupStr, ok := group.(string); ok {
					groups = append(groups, groupStr)
				}
			}
		case []string:
			groups = v
		case string:
			// Single group as string
			groups = []string{v}
		}
	}

	log.Printf("Authenticated user: %s, groups: %v", username, groups)
	return true, username, groups
}

// isAuthenticated checks if the request has a valid authentication token (legacy method)
func (o *OIDCMiddleware) isAuthenticated(r *http.Request) bool {
	authenticated, _, _ := o.checkAuthAndExtractClaims(r)
	return authenticated
}

// redirectToAuth redirects the user to the OIDC provider for authentication
func (o *OIDCMiddleware) redirectToAuth(w http.ResponseWriter, r *http.Request) {
	// Generate state parameter for CSRF protection
	state, err := generateRandomString(32)
	if err != nil {
		log.Printf("Failed to generate state: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	// Store the original URL and state in cookies
	http.SetCookie(w, &http.Cookie{
		Name:     "oidc_state",
		Value:    state,
		Path:     "/",
		HttpOnly: true,
		Secure:   r.TLS != nil,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   300, // 5 minutes
	})

	http.SetCookie(w, &http.Cookie{
		Name:     "oidc_redirect",
		Value:    r.URL.String(),
		Path:     "/",
		HttpOnly: true,
		Secure:   r.TLS != nil,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   300, // 5 minutes
	})

	// Redirect to authorization endpoint
	authURL := o.oauth2Config.AuthCodeURL(state)
	http.Redirect(w, r, authURL, http.StatusFound)
}

// handleCallback handles the OIDC callback
func (o *OIDCMiddleware) handleCallback(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Verify state parameter
	stateCookie, err := r.Cookie("oidc_state")
	if err != nil || stateCookie.Value != r.URL.Query().Get("state") {
		log.Printf("Invalid state parameter")
		http.Error(w, "Invalid state parameter", http.StatusBadRequest)
		return
	}

	// Exchange authorization code for tokens
	code := r.URL.Query().Get("code")
	token, err := o.oauth2Config.Exchange(ctx, code)
	if err != nil {
		log.Printf("Failed to exchange code: %v", err)
		http.Error(w, "Failed to exchange authorization code", http.StatusInternalServerError)
		return
	}

	// Extract and verify ID token
	rawIDToken, ok := token.Extra("id_token").(string)
	if !ok {
		log.Printf("No id_token in response")
		http.Error(w, "No ID token in response", http.StatusInternalServerError)
		return
	}

	idToken, err := o.verifier.Verify(ctx, rawIDToken)
	if err != nil {
		log.Printf("Failed to verify ID token: %v", err)
		http.Error(w, "Failed to verify ID token", http.StatusInternalServerError)
		return
	}

	// Store the ID token in a secure cookie
	http.SetCookie(w, &http.Cookie{
		Name:     "oidc_token",
		Value:    rawIDToken,
		Path:     "/",
		HttpOnly: true,
		Secure:   r.TLS != nil,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   int(time.Until(idToken.Expiry).Seconds()),
	})

	// Clear state and redirect cookies
	http.SetCookie(w, &http.Cookie{
		Name:   "oidc_state",
		Path:   "/",
		MaxAge: -1,
	})

	// Get redirect URL and redirect
	redirectCookie, err := r.Cookie("oidc_redirect")
	redirectURL := "/"
	if err == nil {
		redirectURL = redirectCookie.Value
	}

	http.SetCookie(w, &http.Cookie{
		Name:   "oidc_redirect",
		Path:   "/",
		MaxAge: -1,
	})

	log.Printf("User authenticated successfully, redirecting to: %s", redirectURL)
	http.Redirect(w, r, redirectURL, http.StatusFound)
}

// handleLogout handles user logout
func (o *OIDCMiddleware) handleLogout(w http.ResponseWriter, r *http.Request) {
	// Clear the authentication cookie
	http.SetCookie(w, &http.Cookie{
		Name:   "oidc_token",
		Path:   "/",
		MaxAge: -1,
	})

	// Build logout URL if provider supports it
	logoutURL := "/"
	if o.provider != nil {
		// Try to get end session endpoint
		var claims struct {
			EndSessionEndpoint string `json:"end_session_endpoint"`
		}
		if err := o.provider.Claims(&claims); err == nil && claims.EndSessionEndpoint != "" {
			logoutParams := url.Values{}
			logoutParams.Set("post_logout_redirect_uri", r.Header.Get("Origin")+"/")
			logoutURL = claims.EndSessionEndpoint + "?" + logoutParams.Encode()
		}
	}

	log.Printf("User logged out, redirecting to: %s", logoutURL)
	http.Redirect(w, r, logoutURL, http.StatusFound)
}

// generateRandomString generates a random string for state parameter
func generateRandomString(length int) (string, error) {
	bytes := make([]byte, length)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(bytes)[:length], nil
}
