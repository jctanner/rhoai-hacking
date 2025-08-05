package proxy

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"time"

	"k8s.io/klog/v2"

	"github.com/your-org/console-auth-proxy/internal/config"
	"github.com/your-org/console-auth-proxy/pkg/auth"
	"github.com/your-org/console-auth-proxy/pkg/auth/csrfverifier"
)

// AuthenticatedProxy provides reverse proxy functionality with authentication
type AuthenticatedProxy struct {
	proxy         *httputil.ReverseProxy
	authenticator auth.Authenticator
	config        *config.ProxyConfig
	csrfVerifier  *csrfverifier.CSRFVerifier
	backendURL    *url.URL
}

// NewAuthenticatedProxy creates a new authenticated reverse proxy
func NewAuthenticatedProxy(cfg *config.Config, authenticator auth.Authenticator) (*AuthenticatedProxy, error) {
	// Parse backend URL
	backendURL, err := url.Parse(cfg.Proxy.Backend.URL)
	if err != nil {
		return nil, fmt.Errorf("invalid backend URL: %w", err)
	}

	// Create transport with custom timeouts and TLS settings
	transport := &http.Transport{
		TLSHandshakeTimeout:   cfg.Proxy.Timeouts.TLSHandshake,
		ResponseHeaderTimeout: cfg.Proxy.Timeouts.ResponseHeader,
		ExpectContinueTimeout: cfg.Proxy.Timeouts.ExpectContinue,
		IdleConnTimeout:       cfg.Proxy.Timeouts.IdleConn,
		MaxIdleConns:          cfg.Proxy.Timeouts.MaxIdleConns,
		MaxIdleConnsPerHost:   cfg.Proxy.Timeouts.MaxIdleConnsPerHost,
	}

	// Configure TLS if needed
	if backendURL.Scheme == "https" {
		tlsConfig := &tls.Config{
			InsecureSkipVerify: cfg.Proxy.TLS.InsecureSkipVerify,
		}

		// Set custom server name for SNI if provided
		if cfg.Proxy.TLS.ServerName != "" {
			tlsConfig.ServerName = cfg.Proxy.TLS.ServerName
		}

		// Load custom CA if provided
		if cfg.Proxy.TLS.CAFile != "" {
			caData, err := os.ReadFile(cfg.Proxy.TLS.CAFile)
			if err != nil {
				return nil, fmt.Errorf("failed to read CA file %s: %w", cfg.Proxy.TLS.CAFile, err)
			}
			
			certPool, err := x509.SystemCertPool()
			if err != nil {
				klog.Warningf("Failed to get system cert pool, using empty pool: %v", err)
				certPool = x509.NewCertPool()
			}
			
			if !certPool.AppendCertsFromPEM(caData) {
				return nil, fmt.Errorf("failed to parse CA certificates from %s", cfg.Proxy.TLS.CAFile)
			}
			
			tlsConfig.RootCAs = certPool
			klog.V(4).Infof("Loaded custom CA certificates from %s for backend connections", cfg.Proxy.TLS.CAFile)
		}

		// Load client certificate if provided
		if cfg.Proxy.TLS.CertFile != "" && cfg.Proxy.TLS.KeyFile != "" {
			cert, err := tls.LoadX509KeyPair(cfg.Proxy.TLS.CertFile, cfg.Proxy.TLS.KeyFile)
			if err != nil {
				return nil, fmt.Errorf("failed to load client certificate: %w", err)
			}
			tlsConfig.Certificates = []tls.Certificate{cert}
			klog.V(4).Infof("Loaded client certificate from %s for backend connections", cfg.Proxy.TLS.CertFile)
		}

		transport.TLSClientConfig = tlsConfig
	}

	// Create reverse proxy
	proxy := httputil.NewSingleHostReverseProxy(backendURL)
	proxy.Transport = transport

	// Configure proxy director to modify requests
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)
		// The original director already sets the target host and scheme
		// We'll add additional modifications in the ServeHTTP method
	}

	// Create CSRF verifier
	var csrfVerifier *csrfverifier.CSRFVerifier
	if cfg.Auth.SecureCookies {
		// Create CSRF verifier using the redirect URL as the referer URL
		redirectURL, err := url.Parse(cfg.Auth.RedirectURL)
		if err != nil {
			return nil, fmt.Errorf("invalid redirect URL for CSRF verifier: %w", err)
		}
		csrfVerifier = csrfverifier.NewCSRFVerifier(redirectURL, cfg.Auth.SecureCookies)
	}

	return &AuthenticatedProxy{
		proxy:         proxy,
		authenticator: authenticator,
		config:        &cfg.Proxy,
		csrfVerifier:  csrfVerifier,
		backendURL:    backendURL,
	}, nil
}

// ServeHTTP implements the http.Handler interface
func (ap *AuthenticatedProxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Skip authentication for health checks and other special paths
	if ap.shouldSkipAuth(r) {
		ap.proxy.ServeHTTP(w, r)
		return
	}

	// CSRF verification for non-GET requests
	if ap.csrfVerifier != nil && r.Method != "GET" && r.Method != "HEAD" && r.Method != "OPTIONS" {
		csrfHandler := ap.csrfVerifier.WithCSRFVerification(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// CSRF verification passed, continue with authentication
			ap.handleWithAuth(w, r)
		}))
		csrfHandler.ServeHTTP(w, r)
	} else {
		ap.handleWithAuth(w, r)
	}
}

// handleWithAuth handles requests that require authentication
func (ap *AuthenticatedProxy) handleWithAuth(w http.ResponseWriter, r *http.Request) {
	// Authenticate the request
	user, err := ap.authenticator.Authenticate(w, r)
	if err != nil {
		klog.V(4).Infof("Authentication failed for %s %s: %v", r.Method, r.URL.Path, err)
		ap.redirectToLogin(w, r)
		return
	}

	klog.V(6).Infof("Authenticated user %s for %s %s", user.Username, r.Method, r.URL.Path)

	// Set CSRF cookie if we have a verifier
	if ap.csrfVerifier != nil {
		ap.csrfVerifier.SetCSRFCookie(ap.config.Headers.Custom["Cookie-Path"], w)
	}

	// Modify request headers for backend
	ap.injectHeaders(r, user)

	// Remove headers that shouldn't be forwarded
	ap.removeHeaders(r)

	// Proxy the request to backend
	ap.proxy.ServeHTTP(w, r)
}

// injectHeaders adds authentication and user identity headers to the request
func (ap *AuthenticatedProxy) injectHeaders(r *http.Request, user *auth.User) {
	// Add authorization header
	if ap.config.Headers.AuthHeader != "" && user.Token != "" {
		authValue := user.Token
		if ap.config.Headers.AuthHeaderValue == "bearer" {
			authValue = "Bearer " + user.Token
		}
		r.Header.Set(ap.config.Headers.AuthHeader, authValue)
	}

	// Add user identity headers
	if ap.config.Headers.UserHeader != "" && user.Username != "" {
		r.Header.Set(ap.config.Headers.UserHeader, user.Username)
	}

	if ap.config.Headers.UserIDHeader != "" && user.ID != "" {
		r.Header.Set(ap.config.Headers.UserIDHeader, user.ID)
	}

	// Note: Email header would require extending the auth.User struct
	// This is commented out to avoid modifying the console auth module
	// if ap.config.Headers.EmailHeader != "" && user.Email != "" {
	//     r.Header.Set(ap.config.Headers.EmailHeader, user.Email)
	// }

	// Add custom headers
	for name, value := range ap.config.Headers.Custom {
		// Skip Cookie-Path as it's used internally
		if name != "Cookie-Path" {
			r.Header.Set(name, value)
		}
	}

	// Set X-Forwarded headers
	if r.Header.Get("X-Forwarded-For") == "" {
		r.Header.Set("X-Forwarded-For", r.RemoteAddr)
	}
	if r.Header.Get("X-Forwarded-Proto") == "" {
		if r.TLS != nil {
			r.Header.Set("X-Forwarded-Proto", "https")
		} else {
			r.Header.Set("X-Forwarded-Proto", "http")
		}
	}
	if r.Header.Get("X-Forwarded-Host") == "" {
		r.Header.Set("X-Forwarded-Host", r.Host)
	}
}

// removeHeaders removes headers that shouldn't be forwarded to the backend
func (ap *AuthenticatedProxy) removeHeaders(r *http.Request) {
	for _, header := range ap.config.Headers.Remove {
		r.Header.Del(header)
	}

	// Always remove potentially problematic headers
	r.Header.Del("Cookie") // Let the backend handle its own cookies
}

// shouldSkipAuth determines if authentication should be skipped for a request
func (ap *AuthenticatedProxy) shouldSkipAuth(r *http.Request) bool {
	path := r.URL.Path

	// Skip auth for health check paths
	skipPaths := []string{
		"/healthz",
		"/readyz",
		"/metrics",
		"/version",
		"/info",
	}

	for _, skipPath := range skipPaths {
		if path == skipPath {
			return true
		}
	}

	// Skip auth for auth-related paths
	if strings.HasPrefix(path, "/auth/") {
		return true
	}

	return false
}

// redirectToLogin redirects the user to the login page
func (ap *AuthenticatedProxy) redirectToLogin(w http.ResponseWriter, r *http.Request) {
	// Store the original URL for redirect after login
	originalURL := r.URL.String()
	if originalURL != "/" {
		// TODO: Store original URL in session for redirect after login
		klog.V(4).Infof("Storing original URL for post-login redirect: %s", originalURL)
	}

	// Redirect to login
	loginURL := "/auth/login"
	if originalURL != "/" {
		// Add return URL as query parameter
		loginURL += "?return_url=" + url.QueryEscape(originalURL)
	}

	http.Redirect(w, r, loginURL, http.StatusSeeOther)
}

// HealthCheck performs a health check against the backend
func (ap *AuthenticatedProxy) HealthCheck() error {
	if ap.config.Backend.HealthCheckPath == "" {
		return nil // No health check configured
	}

	healthURL := ap.backendURL.ResolveReference(&url.URL{Path: ap.config.Backend.HealthCheckPath})
	
	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: ap.proxy.Transport,
	}

	resp, err := client.Get(healthURL.String())
	if err != nil {
		return fmt.Errorf("backend health check failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 400 {
		return fmt.Errorf("backend health check returned status %d", resp.StatusCode)
	}

	return nil
}