package proxy

import (
	"os"

	"github.com/jctanner/odh-gateway/internal/proxy/providers"
)

// shouldUpdateProvider determines if the provider should be updated
func shouldUpdateProvider(newConfig providers.ProviderConfig) bool {
	if authProvider == nil {
		return true
	}

	// For now, always update if config changes
	// In the future, we could be more sophisticated about comparing configs
	return true
}

// getBaseURL constructs the base URL for callbacks
func getBaseURL() string {
	port := os.Getenv("GATEWAY_PORT")
	if port == "" {
		port = "8080"
	}

	// For now, assume HTTP. In production, this should be configurable
	return "http://localhost:" + port
}
