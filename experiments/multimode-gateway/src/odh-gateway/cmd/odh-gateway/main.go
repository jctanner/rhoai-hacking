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

	// Handle provider configuration from environment variables (backward compatibility)
	var providerConfig proxy.ProviderConfig

	// Check for OIDC environment variables first (backward compatibility)
	oidcIssuerURLValue := getEnvOrFlag("OIDC_ISSUER_URL", *oidcIssuerURL)
	oidcClientIDValue := getEnvOrFlag("OIDC_CLIENT_ID", *oidcClientID)
	oidcClientSecretValue := getEnvOrFlag("OIDC_CLIENT_SECRET", *oidcClientSecret)

	if oidcIssuerURLValue != "" && oidcClientIDValue != "" && oidcClientSecretValue != "" {
		// Use environment variables for OIDC provider
		providerConfig = proxy.ProviderConfig{
			Type: "oidc",
			OIDC: &proxy.OIDCProviderConfig{
				IssuerURL:    oidcIssuerURLValue,
				ClientID:     oidcClientIDValue,
				ClientSecret: oidcClientSecretValue,
			},
		}
		log.Printf("OIDC provider configured from environment variables")
		log.Printf("OIDC configuration: Issuer=%s, ClientID=%s", oidcIssuerURLValue, oidcClientIDValue)
	} else {
		// No provider configured via environment variables
		providerConfig = proxy.ProviderConfig{
			Type: "disabled",
		}
	}

	if err := proxy.StartServer(certFile, keyFile, providerConfig); err != nil {
		log.Fatalf("failed to start gateway: %v", err)
	}
}
