package main

import (
	"flag"
	"log"
	"os"

	"github.com/jctanner/odh-gateway/internal/proxy"
)

// getEnvOrFlag returns environment variable value if set, otherwise returns flag value
func getEnvOrFlag(envKey, flagValue string) string {
	if env := os.Getenv(envKey); env != "" {
		return env
	}
	return flagValue
}

func main() {
	var (
		tlsCertFile = flag.String("tls-cert-file", "", "Path to TLS certificate file (enables HTTPS)")
		tlsKeyFile  = flag.String("tls-key-file", "", "Path to TLS private key file (enables HTTPS)")

		// OIDC configuration flags
		oidcEnabled      = flag.Bool("oidc-enabled", false, "Enable OIDC authentication globally (can be overridden per route)")
		oidcIssuerURL    = flag.String("oidc-issuer-url", "", "OIDC issuer URL")
		oidcClientID     = flag.String("oidc-client-id", "", "OIDC client ID")
		oidcClientSecret = flag.String("oidc-client-secret", "", "OIDC client secret")
	)
	flag.Parse()

	// Handle TLS certificates
	var certFile, keyFile string
	if *tlsCertFile != "" && *tlsKeyFile != "" {
		certFile = *tlsCertFile
		keyFile = *tlsKeyFile
	} else if *tlsCertFile != "" || *tlsKeyFile != "" {
		log.Fatal("Both --tls-cert-file and --tls-key-file must be provided to enable TLS")
	}

	// Handle OIDC configuration with environment variable fallback
	oidcConfig := proxy.OIDCConfig{
		Enabled:      *oidcEnabled || os.Getenv("OIDC_ENABLED") == "true",
		IssuerURL:    getEnvOrFlag("OIDC_ISSUER_URL", *oidcIssuerURL),
		ClientID:     getEnvOrFlag("OIDC_CLIENT_ID", *oidcClientID),
		ClientSecret: getEnvOrFlag("OIDC_CLIENT_SECRET", *oidcClientSecret),
	}

	// Enable OIDC automatically if environment variables are provided
	if !oidcConfig.Enabled && oidcConfig.IssuerURL != "" && oidcConfig.ClientID != "" && oidcConfig.ClientSecret != "" {
		oidcConfig.Enabled = true
		log.Printf("OIDC automatically enabled due to environment variables")
	}

	// Validate OIDC configuration if enabled
	if oidcConfig.Enabled {
		if oidcConfig.IssuerURL == "" || oidcConfig.ClientID == "" || oidcConfig.ClientSecret == "" {
			log.Fatal("When OIDC is enabled, --oidc-issuer-url, --oidc-client-id, and --oidc-client-secret must be provided (or set via OIDC_* environment variables)")
		}
		log.Printf("OIDC configuration: Issuer=%s, ClientID=%s", oidcConfig.IssuerURL, oidcConfig.ClientID)
	}

	if err := proxy.StartServer(certFile, keyFile, oidcConfig); err != nil {
		log.Fatalf("failed to start gateway: %v", err)
	}
}
