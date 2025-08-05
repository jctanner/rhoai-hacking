package server

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"k8s.io/klog/v2"

	"github.com/your-org/console-auth-proxy/internal/config"
	"github.com/your-org/console-auth-proxy/internal/proxy"
	"github.com/your-org/console-auth-proxy/internal/version"
	"github.com/your-org/console-auth-proxy/pkg/auth"
	"github.com/your-org/console-auth-proxy/pkg/auth/sessions"
)

// setupRoutes configures all HTTP routes for the server
func setupRoutes(
	mux *http.ServeMux,
	cfg *config.Config,
	authenticator auth.Authenticator,
	proxyHandler *proxy.AuthenticatedProxy,
	metrics *auth.Metrics,
) {
	// Authentication routes
	setupAuthRoutes(mux, cfg, authenticator)

	// Health check routes
	if cfg.Observability.Health.Enabled {
		setupHealthRoutes(mux, cfg)
	}

	// Metrics routes
	if cfg.Observability.Metrics.Enabled {
		setupMetricsRoutes(mux, cfg)
	}

	// Version/info routes
	setupInfoRoutes(mux)

	// Default route - proxy all other requests
	mux.Handle("/", proxyHandler)
}

// setupAuthRoutes configures authentication-related routes
func setupAuthRoutes(mux *http.ServeMux, cfg *config.Config, authenticator auth.Authenticator) {
	// Login route - redirects to OAuth provider
	mux.HandleFunc("/auth/login", func(w http.ResponseWriter, r *http.Request) {
		klog.V(4).Infof("Login request from %s", r.RemoteAddr)
		authenticator.LoginFunc(w, r)
	})

	// Logout route - clears session and redirects
	mux.HandleFunc("/auth/logout", func(w http.ResponseWriter, r *http.Request) {
		klog.V(4).Infof("Logout request from %s", r.RemoteAddr)
		authenticator.LogoutFunc(w, r)
	})

	// OAuth callback route - handles OAuth2 authorization code flow
	mux.HandleFunc("/auth/callback", authenticator.CallbackFunc(handleAuthCallback))

	// Auth info route - returns current user information (for debugging)
	mux.HandleFunc("/auth/info", func(w http.ResponseWriter, r *http.Request) {
		handleAuthInfo(w, r, authenticator)
	})

	// Error route - displays authentication errors
	mux.HandleFunc("/auth/error", func(w http.ResponseWriter, r *http.Request) {
		handleAuthError(w, r)
	})
}

// setupHealthRoutes configures health check routes
func setupHealthRoutes(mux *http.ServeMux, cfg *config.Config) {
	// Liveness probe - indicates if the application is running
	mux.HandleFunc(cfg.Observability.Health.LivenessPath, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Readiness probe - indicates if the application is ready to serve traffic
	mux.HandleFunc(cfg.Observability.Health.ReadinessPath, func(w http.ResponseWriter, r *http.Request) {
		// TODO: Add actual readiness checks (database connectivity, etc.)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})
}

// setupMetricsRoutes configures Prometheus metrics routes
func setupMetricsRoutes(mux *http.ServeMux, cfg *config.Config) {
	mux.Handle(cfg.Observability.Metrics.Path, promhttp.Handler())
}

// setupInfoRoutes configures version and information routes
func setupInfoRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		buildInfo := version.Get()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(buildInfo)
	})

	mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
		info := map[string]interface{}{
			"service": "console-auth-proxy",
			"version": version.Get(),
			"status":  "running",
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(info)
	})
}

// handleAuthCallback handles successful OAuth2 authentication
func handleAuthCallback(loginInfo sessions.LoginJSON, successURL string, w http.ResponseWriter) {
	klog.V(4).Infof("Authentication successful for user: %s", loginInfo.UserID)
	
	// Set a cookie with user info for debugging (optional)
	if klog.V(6).Enabled() {
		userInfoJSON, _ := json.Marshal(loginInfo)
		klog.V(6).Infof("User login info: %s", userInfoJSON)
	}

	// Redirect to success URL
	http.Redirect(w, &http.Request{}, successURL, http.StatusSeeOther)
}

// handleAuthInfo returns current authentication information
func handleAuthInfo(w http.ResponseWriter, r *http.Request, authenticator auth.Authenticator) {
	user, err := authenticator.Authenticate(w, r)
	if err != nil {
		// Not authenticated
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"authenticated": false,
			"error":         "Not authenticated",
		})
		return
	}

	// Return user information (be careful not to expose sensitive data)
	userInfo := map[string]interface{}{
		"authenticated": true,
		"user_id":       user.ID,
		"username":      user.Username,
		// Note: We don't return the token for security reasons
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(userInfo)
}

// handleAuthError displays authentication errors
func handleAuthError(w http.ResponseWriter, r *http.Request) {
	errorType := r.URL.Query().Get("error_type")
	errorMsg := r.URL.Query().Get("error")

	klog.Warningf("Authentication error: type=%s, message=%s", errorType, errorMsg)

	// Return a simple error page
	w.Header().Set("Content-Type", "text/html")
	w.WriteHeader(http.StatusUnauthorized)
	
	errorPage := `<!DOCTYPE html>
<html>
<head>
    <title>Authentication Error</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .error { color: #d32f2f; background: #ffebee; padding: 20px; border-radius: 4px; }
        .retry { margin-top: 20px; }
        .retry a { color: #1976d2; text-decoration: none; }
        .retry a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>Authentication Error</h1>
    <div class="error">
        <p><strong>Error:</strong> %s</p>
        <p><strong>Type:</strong> %s</p>
    </div>
    <div class="retry">
        <p><a href="/auth/login">Try logging in again</a></p>
    </div>
</body>
</html>`

	w.Write([]byte(fmt.Sprintf(errorPage, errorMsg, errorType)))
}