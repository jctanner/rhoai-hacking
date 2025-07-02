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
	mu     sync.RWMutex
	router http.Handler
)

// StartServer starts the reverse proxy with hot-reload and request logging
func StartServer(tlsCertFile, tlsKeyFile string) error {
	cfgPath := os.Getenv("GATEWAY_CONFIG")
	if cfgPath == "" {
		cfgPath = "/etc/odh-gateway/config.yaml"
	}

	if err := reloadConfig(cfgPath); err != nil {
		return err
	}

	go watchConfig(cfgPath)
	go pollConfig(cfgPath)

	port := os.Getenv("GATEWAY_PORT")
	if port == "" {
		if tlsCertFile != "" && tlsKeyFile != "" {
			port = "8443" // Default HTTPS port
		} else {
			port = "8080" // Default HTTP port
		}
	}

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
		return http.ListenAndServeTLS(":"+port, tlsCertFile, tlsKeyFile, handler)
	} else {
		log.Printf("Starting HTTP server on :%s", port)
		return http.ListenAndServe(":"+port, handler)
	}
}

// reloadConfig builds the routing mux and updates the global router
func reloadConfig(path string) error {
	// Force a fresh read by resolving the symlink
	resolvedPath, err := filepath.EvalSymlinks(path)
	if err != nil {
		return fmt.Errorf("failed to resolve symlink for %s: %w", path, err)
	}

	cfg, err := config.LoadConfig(resolvedPath)
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	mux := http.NewServeMux()
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

		// Register the handler for this prefix without stripping the path
		mux.Handle(prefix, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if strings.HasPrefix(r.URL.Path, prefix) {
				proxy.ServeHTTP(w, r)
			} else {
				http.NotFound(w, r)
			}
		}))

		log.Printf("Routing %s -> %s", prefix, route.Upstream)
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

func watchConfig(path string) {
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

// pollConfig polls the config file every 2 seconds and reloads if the hash changes
func pollConfig(path string) {
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
			if err := reloadConfig(path); err != nil {
				log.Printf("polling: reload failed: %v", err)
			}
		}

		time.Sleep(2 * time.Second)
	}
}
