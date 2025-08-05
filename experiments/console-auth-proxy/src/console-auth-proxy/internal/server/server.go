package server

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"k8s.io/klog/v2"

	"github.com/your-org/console-auth-proxy/internal/config"
	"github.com/your-org/console-auth-proxy/internal/proxy"
	"github.com/your-org/console-auth-proxy/pkg/auth"
	"github.com/your-org/console-auth-proxy/pkg/auth/oauth2"
	"github.com/your-org/console-auth-proxy/pkg/auth/static"
)

// Server represents the HTTP server
type Server struct {
	config        *config.Config
	httpServer    *http.Server
	authenticator auth.Authenticator
	proxy         *proxy.AuthenticatedProxy
	metrics       *auth.Metrics
}

// New creates a new server instance
func New(cfg *config.Config) (*Server, error) {
	// Set configuration defaults
	cfg.SetDefaults()

	// Initialize metrics with a default round tripper
	metrics := auth.NewMetrics(http.DefaultTransport)
	
	// Register metrics with Prometheus
	if cfg.Observability.Metrics.Enabled {
		for _, collector := range metrics.GetCollectors() {
			if err := prometheus.Register(collector); err != nil {
				klog.Warningf("Failed to register metric: %v", err)
			}
		}
	}

	// Initialize authenticator
	authenticator, err := createAuthenticator(cfg, metrics)
	if err != nil {
		return nil, fmt.Errorf("failed to create authenticator: %w", err)
	}

	// Initialize proxy
	proxyHandler, err := proxy.NewAuthenticatedProxy(cfg, authenticator)
	if err != nil {
		return nil, fmt.Errorf("failed to create proxy: %w", err)
	}

	// Create HTTP server
	mux := http.NewServeMux()
	
	// Setup routes
	setupRoutes(mux, cfg, authenticator, proxyHandler, metrics)

	httpServer := &http.Server{
		Addr:         cfg.Server.ListenAddress,
		Handler:      mux,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
		IdleTimeout:  cfg.Server.IdleTimeout,
	}

	// Configure TLS if enabled
	if cfg.Server.TLS.Enabled {
		cert, err := tls.LoadX509KeyPair(cfg.Server.TLS.CertFile, cfg.Server.TLS.KeyFile)
		if err != nil {
			return nil, fmt.Errorf("failed to load TLS certificate: %w", err)
		}

		httpServer.TLSConfig = &tls.Config{
			Certificates: []tls.Certificate{cert},
			MinVersion:   tls.VersionTLS12,
		}
	}

	return &Server{
		config:        cfg,
		httpServer:    httpServer,
		authenticator: authenticator,
		proxy:         proxyHandler,
		metrics:       metrics,
	}, nil
}

// ListenAndServe starts the HTTP server
func (s *Server) ListenAndServe() error {
	if s.config.Server.TLS.Enabled {
		return s.httpServer.ListenAndServeTLS("", "")
	}
	return s.httpServer.ListenAndServe()
}

// Shutdown gracefully shuts down the server
func (s *Server) Shutdown(ctx context.Context) error {
	return s.httpServer.Shutdown(ctx)
}

// Close forcefully closes the server
func (s *Server) Close() error {
	return s.httpServer.Close()
}

// createAuthenticator creates the appropriate authenticator based on configuration
func createAuthenticator(cfg *config.Config, metrics *auth.Metrics) (auth.Authenticator, error) {
	switch cfg.Auth.AuthSource {
	case "static":
		// Static authenticator for development/testing
		user := auth.User{
			ID:       "static-user",
			Username: "static-user",
			Token:    "static-token",
		}
		return static.NewStaticAuthenticator(user), nil

	case "openshift", "oidc":
		// Get Kubernetes configuration
		k8sConfig, err := cfg.Auth.GetKubernetesConfig()
		if err != nil {
			return nil, fmt.Errorf("failed to get Kubernetes config: %w", err)
		}

		// Determine auth source
		var authSource oauth2.AuthSource
		switch cfg.Auth.AuthSource {
		case "openshift":
			authSource = oauth2.AuthSourceOpenShift
		case "oidc":
			authSource = oauth2.AuthSourceOIDC
		default:
			return nil, fmt.Errorf("unsupported auth source: %s", cfg.Auth.AuthSource)
		}

		// Prepare cookie encryption keys
		cookieAuthKey := []byte(cfg.Auth.CookieAuthenticationKey)
		cookieEncryptKey := []byte(cfg.Auth.CookieEncryptionKey)

		// Generate keys if not provided (development only)
		if len(cookieAuthKey) == 0 {
			cookieAuthKey = generateRandomKey(64)
			klog.Warning("No cookie authentication key provided, generated random key for development")
		}
		if len(cookieEncryptKey) == 0 {
			cookieEncryptKey = generateRandomKey(32)
			klog.Warning("No cookie encryption key provided, generated random key for development")
		}

		// Create OAuth2 authenticator configuration
		authConfig := &oauth2.Config{
			AuthSource:                  authSource,
			IssuerURL:                   cfg.Auth.IssuerURL,
			LogoutRedirectOverride:      cfg.Auth.LogoutRedirectOverride,
			IssuerCA:                   cfg.Auth.IssuerCA,
			RedirectURL:                cfg.Auth.RedirectURL,
			ClientID:                   cfg.Auth.ClientID,
			ClientSecret:               cfg.Auth.ClientSecret,
			Scope:                      cfg.Auth.Scope,
			K8sCA:                      cfg.Auth.K8sCA,
			SuccessURL:                 cfg.Auth.SuccessURL,
			ErrorURL:                   cfg.Auth.ErrorURL,
			CookiePath:                 cfg.Auth.CookiePath,
			SecureCookies:              cfg.Auth.SecureCookies,
			CookieEncryptionKey:        cookieEncryptKey,
			CookieAuthenticationKey:    cookieAuthKey,
			TLS: oauth2.TLSConfig{
				InsecureSkipVerify: cfg.Auth.TLS.InsecureSkipVerify,
				ServerName:         cfg.Auth.TLS.ServerName,
			},
			K8sConfig:                  k8sConfig,
			Metrics:                    metrics,
			OCLoginCommand:             cfg.Auth.OCLoginCommand,
		}

		// Create OAuth2 authenticator
		return oauth2.NewOAuth2Authenticator(context.Background(), authConfig)

	default:
		return nil, fmt.Errorf("unsupported auth source: %s", cfg.Auth.AuthSource)
	}
}

// generateRandomKey generates a random key for development purposes
func generateRandomKey(length int) []byte {
	key := make([]byte, length)
	for i := range key {
		key[i] = byte(time.Now().UnixNano() % 256)
	}
	return key
}