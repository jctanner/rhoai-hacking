package main

import (
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
)

func main() {
	upstream := getEnv("UPSTREAM_URL", "http://localhost:5000")
	//pathPrefix := strings.TrimRight(getEnv("ROUTE_PREFIX", "/"), "/")
	loginPath := getEnv("LOGIN_PATH", "/login")

	upstreamURL, err := url.Parse(upstream)
	if err != nil {
		log.Fatalf("Invalid UPSTREAM_URL: %v", err)
	}

	proxy := httputil.NewSingleHostReverseProxy(upstreamURL)

	// Rewrite any Location headers from upstream that point to localhost
	proxy.ModifyResponse = func(resp *http.Response) error {
		location := resp.Header.Get("Location")
		if location == "" {
			return nil
		}

		locURL, err := url.Parse(location)
		if err != nil {
			return nil // ignore unparseable URLs
		}

		if locURL.Host == upstreamURL.Host {
			// Convert absolute redirect to relative (preserves path/query)
			locURL.Scheme = ""
			locURL.Host = ""
			newLocation := locURL.String()
			resp.Header.Set("Location", newLocation)
			log.Printf("Rewrote Location header to: %s", newLocation)
		}
		return nil
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Incoming request: %s %s", r.Method, r.URL.Path)

		log.Println("Headers:")
		for name, values := range r.Header {
			for _, value := range values {
				fmt.Printf("  %s: %s\n", name, value)
			}
		}

		auth := r.Header.Get("Authorization")
		_, cookieErr := r.Cookie("_oauth2_proxy")

		if !isValidBearer(auth) && cookieErr != nil {
			rd := r.URL.Path
			if r.URL.RawQuery != "" {
				rd += "?" + r.URL.RawQuery
			}
			redirectURL := loginPath + "?rd=" + url.QueryEscape(rd)
			log.Printf("Unauthenticated request. Redirecting to: %s", redirectURL)
			http.Redirect(w, r, redirectURL, http.StatusFound)
			return
		}

		if cookieErr == nil {
			log.Println("Found _oauth2_proxy cookie — user is logged in.")
		} else {
			log.Println("Valid bearer token found — user is authenticated.")
		}

		r.Host = upstreamURL.Host
		proxy.ServeHTTP(w, r)
	})

	addr := ":8080"
	log.Printf("Starting auth-check-proxy on %s with upstream %s", addr, upstream)
	log.Fatal(http.ListenAndServe(addr, nil))
}

func isValidBearer(authHeader string) bool {
	return strings.HasPrefix(authHeader, "Bearer ") && len(authHeader) > 7
}

func getEnv(key, defaultVal string) string {
	val := os.Getenv(key)
	if val == "" {
		return defaultVal
	}
	return val
}
