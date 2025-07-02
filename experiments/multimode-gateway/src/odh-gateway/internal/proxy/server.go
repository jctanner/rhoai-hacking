package proxy

import (
	"crypto/sha256"
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/jctanner/odh-gateway/pkg/config"
)

var (
	mu             sync.RWMutex
	router         http.Handler
	authProvider   AuthProvider
	authMiddleware *AuthMiddleware
)

// StartServer starts the reverse proxy with hot-reload and request logging
func StartServer(tlsCertFile, tlsKeyFile string, providerConfig ProviderConfig) error {
	cfgPath := os.Getenv("GATEWAY_CONFIG")
	if cfgPath == "" {
		cfgPath = "/etc/odh-gateway/config.yaml"
	}

	// Determine base URL for OIDC callbacks
	port := os.Getenv("GATEWAY_PORT")
	if port == "" {
		if tlsCertFile != "" && tlsKeyFile != "" {
			port = "8443" // Default HTTPS port
		} else {
			port = "8080" // Default HTTP port
		}
	}

	scheme := "http"
	if tlsCertFile != "" && tlsKeyFile != "" {
		scheme = "https"
	}
	baseURL := fmt.Sprintf("%s://localhost:%s", scheme, port)

	// Initialize authentication provider
	var err error
	authProvider, err = CreateProvider(providerConfig, baseURL)
	if err != nil {
		return fmt.Errorf("failed to create auth provider: %w", err)
	}

	// Initialize auth middleware
	authMiddleware = NewAuthMiddleware(authProvider)

	if err := reloadConfig(cfgPath, providerConfig); err != nil {
		return err
	}

	go watchConfig(cfgPath, providerConfig)
	go pollConfig(cfgPath, providerConfig)

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s %s", r.RemoteAddr, r.Method, r.URL)
		mu.RLock()
		defer mu.RUnlock()
		router.ServeHTTP(w, r)
	})

	// Start HTTPS server if TLS certificates are provided
	if tlsCertFile != "" && tlsKeyFile != "" {
		log.Printf("Starting HTTPS server on :%s", port)
		log.Printf("Using TLS cert: %s", tlsCertFile)
		log.Printf("Using TLS key: %s", tlsKeyFile)
		if authProvider.IsEnabled() {
			log.Printf("Authentication enabled using %s provider", authProvider.Name())
		}
		return http.ListenAndServeTLS(":"+port, tlsCertFile, tlsKeyFile, handler)
	} else {
		log.Printf("Starting HTTP server on :%s", port)
		if authProvider.IsEnabled() {
			log.Printf("Authentication enabled using %s provider", authProvider.Name())
		}
		return http.ListenAndServe(":"+port, handler)
	}
}

// reloadConfig builds the routing mux and updates the global router
func reloadConfig(path string, fallbackProviderConfig ProviderConfig) error {
	// Force a fresh read by resolving the symlink
	resolvedPath, err := filepath.EvalSymlinks(path)
	if err != nil {
		return fmt.Errorf("failed to resolve symlink for %s: %w", path, err)
	}

	cfg, err := config.LoadConfig(resolvedPath)
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Use provider config from file if available, otherwise use fallback (environment variables)
	var providerConfig ProviderConfig
	if cfg.Provider != nil {
		providerConfig = ProviderConfig{
			Type:      cfg.Provider.Type,
			OIDC:      (*OIDCProviderConfig)(cfg.Provider.OIDC),
			OpenShift: (*OpenShiftProviderConfig)(cfg.Provider.OpenShift),
		}
	} else {
		providerConfig = fallbackProviderConfig
	}

	// Update auth provider if config changed
	if authProvider == nil || shouldUpdateProvider(providerConfig) {
		newProvider, err := CreateProvider(providerConfig, getBaseURL())
		if err != nil {
			log.Printf("Failed to create new provider: %v", err)
		} else {
			authProvider = newProvider
			authMiddleware = NewAuthMiddleware(authProvider)
			log.Printf("Auth provider updated: %s (enabled: %v)", authProvider.Name(), authProvider.IsEnabled())
		}
	}

	mux := http.NewServeMux()

	// Register auth endpoints if provider is enabled
	if authProvider != nil && authProvider.IsEnabled() {
		mux.Handle("/auth/callback", authMiddleware.HandleCallback())
		mux.Handle("/auth/logout", authMiddleware.HandleLogout())
		mux.Handle("/auth/login", authMiddleware.HandleLogin())
	}

	for _, route := range cfg.Routes {
		if route.PathPrefix == "" {
			log.Printf("Skipping route with empty path prefix")
			continue
		}

		target, err := url.Parse(route.Upstream)
		if err != nil {
			log.Printf("Invalid upstream URL %q: %v", route.Upstream, err)
			continue
		}

		prefix := route.PathPrefix
		// Ensure the prefix ends with a slash so subpaths are matched
		if !strings.HasSuffix(prefix, "/") {
			prefix += "/"
		}

		proxy := httputil.NewSingleHostReverseProxy(target)

		// Create the handler for this route
		routeHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if strings.HasPrefix(r.URL.Path, prefix) {
				proxy.ServeHTTP(w, r)
			} else {
				http.NotFound(w, r)
			}
		})

		// Wrap with auth middleware if available
		var finalHandler http.Handler = routeHandler
		if authMiddleware != nil {
			finalHandler = authMiddleware.Middleware(route.AuthRequired)(routeHandler)
		}

		mux.Handle(prefix, finalHandler)

		authStatus := "no auth"
		if authProvider != nil && authProvider.IsEnabled() {
			if route.AuthRequired != nil {
				if *route.AuthRequired {
					authStatus = "auth required"
				} else {
					authStatus = "auth disabled"
				}
			} else {
				authStatus = "no auth (default)"
			}
		}

		log.Printf("Routing %s -> %s (%s)", prefix, route.Upstream, authStatus)
	}

	mu.Lock()
	router = mux
	mu.Unlock()
	return nil
}

/*
// watchConfig watches the config file and reloads when it changes
func watchConfig(path string) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Printf("watch error: %v", err)
		return
	}
	defer watcher.Close()

	if err := watcher.Add(path); err != nil {
		log.Printf("watch add error: %v", err)
		return
	}

	for {
		select {
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}
			if event.Op&(fsnotify.Write|fsnotify.Create) != 0 {
				log.Printf("Detected change in config: %s", event.Name)
				if err := reloadConfig(path); err != nil {
					log.Printf("Failed to reload config: %v", err)
				}
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			log.Printf("watch error: %v", err)
		}
	}
}
*/

func watchConfig(path string, fallbackProviderConfig ProviderConfig) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Printf("watch error: %v", err)
		return
	}
	defer watcher.Close()

	dir := filepath.Dir(path)
	if err := watcher.Add(dir); err != nil {
		log.Printf("watch add error: %v", err)
		return
	}

	for {
		select {
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}

			// Watch for changes to the symlink target
			if filepath.Clean(event.Name) == filepath.Clean(path) &&
				(event.Op&(fsnotify.Write|fsnotify.Create|fsnotify.Remove|fsnotify.Rename)) != 0 {

				log.Printf("Detected change in config: %s", event.Name)
				if err := reloadConfig(path, fallbackProviderConfig); err != nil {
					log.Printf("Failed to reload config: %v", err)
				}
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			log.Printf("watch error: %v", err)
		}
	}
}

// pollConfig polls the config file every 2 seconds and reloads if the hash changes
func pollConfig(path string, fallbackProviderConfig ProviderConfig) {
	var lastHash [32]byte

	for {
		resolvedPath, err := filepath.EvalSymlinks(path)
		if err != nil {
			log.Printf("polling: failed to resolve symlink: %v", err)
			time.Sleep(2 * time.Second)
			continue
		}

		data, err := os.ReadFile(resolvedPath)
		if err != nil {
			if !os.IsNotExist(err) && !os.IsPermission(err) {
				log.Printf("polling: read error: %v", err)
			}
			time.Sleep(2 * time.Second)
			continue
		}

		hash := sha256.Sum256(data)
		if hash != lastHash {
			log.Printf("polling: detected config change via hash")
			lastHash = hash
			if err := reloadConfig(path, fallbackProviderConfig); err != nil {
				log.Printf("polling: reload failed: %v", err)
			}
		}

		time.Sleep(2 * time.Second)
	}
}
