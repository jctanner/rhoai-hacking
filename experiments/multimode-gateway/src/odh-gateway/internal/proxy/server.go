package proxy

import (
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"sync"

	"github.com/fsnotify/fsnotify"
	"github.com/jctanner/odh-gateway/pkg/config"
)

var (
	mu     sync.RWMutex
	router http.Handler
)

// StartServer starts the reverse proxy with hot-reload and request logging
func StartServer() error {
	cfgPath := os.Getenv("GATEWAY_CONFIG")
	if cfgPath == "" {
		cfgPath = "/etc/odh-gateway/config.yaml"
	}

	if err := reloadConfig(cfgPath); err != nil {
		return err
	}

	go watchConfig(cfgPath)

	port := os.Getenv("GATEWAY_PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Listening on :%s", port)
	return http.ListenAndServe(":"+port, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s %s", r.RemoteAddr, r.Method, r.URL)
		mu.RLock()
		defer mu.RUnlock()
		router.ServeHTTP(w, r)
	}))
}

// reloadConfig builds the routing mux and updates the global router
func reloadConfig(path string) error {
	cfg, err := config.LoadConfig(path)
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
