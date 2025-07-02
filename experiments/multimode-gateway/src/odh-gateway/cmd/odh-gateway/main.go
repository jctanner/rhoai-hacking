package main

import (
	"log"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	"github.com/jctanner/odh-gateway/internal/proxy"
	"github.com/jctanner/odh-gateway/internal/proxy/providers"
)

var (
	cfgFile string

	// TLS configuration
	tlsCertFile string
	tlsKeyFile  string

	// OIDC configuration
	oidcIssuerURL    string
	oidcClientID     string
	oidcClientSecret string
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "odh-gateway",
	Short: "A configurable reverse proxy for Open Data Hub environments",
	Long: `ODH Gateway is a lightweight, configurable reverse proxy designed for Open Data Hub (ODH) 
and Kubernetes environments. The gateway dynamically routes incoming HTTP requests to upstream 
services based on path prefixes defined in a YAML configuration file.

Features:
- Dynamic routing with hot-reload capability
- OIDC and OpenShift OAuth authentication support
- TLS/HTTPS support
- ConfigMap integration for Kubernetes
- Request logging and monitoring`,
	Run: runGateway,
}

func init() {
	cobra.OnInitialize(initConfig)

	// Global flags for configuration
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is /etc/odh-gateway/config.yaml)")

	// TLS flags
	rootCmd.Flags().StringVar(&tlsCertFile, "tls-cert-file", "", "Path to TLS certificate file (enables HTTPS)")
	rootCmd.Flags().StringVar(&tlsKeyFile, "tls-key-file", "", "Path to TLS private key file (enables HTTPS)")

	// OIDC flags
	rootCmd.Flags().StringVar(&oidcIssuerURL, "oidc-issuer-url", "", "OIDC issuer URL")
	rootCmd.Flags().StringVar(&oidcClientID, "oidc-client-id", "", "OIDC client ID")
	rootCmd.Flags().StringVar(&oidcClientSecret, "oidc-client-secret", "", "OIDC client secret")

	// Bind flags to viper for environment variable support
	viper.BindPFlag("tls.cert-file", rootCmd.Flags().Lookup("tls-cert-file"))
	viper.BindPFlag("tls.key-file", rootCmd.Flags().Lookup("tls-key-file"))
	viper.BindPFlag("oidc.issuer-url", rootCmd.Flags().Lookup("oidc-issuer-url"))
	viper.BindPFlag("oidc.client-id", rootCmd.Flags().Lookup("oidc-client-id"))
	viper.BindPFlag("oidc.client-secret", rootCmd.Flags().Lookup("oidc-client-secret"))

	// Set environment variable prefix
	viper.SetEnvPrefix("GATEWAY")
	viper.AutomaticEnv()

	// Bind additional environment variables for backward compatibility
	viper.BindEnv("tls.cert-file", "TLS_CERT_FILE")
	viper.BindEnv("tls.key-file", "TLS_KEY_FILE")
	viper.BindEnv("oidc.issuer-url", "OIDC_ISSUER_URL")
	viper.BindEnv("oidc.client-id", "OIDC_CLIENT_ID")
	viper.BindEnv("oidc.client-secret", "OIDC_CLIENT_SECRET")
}

// initConfig reads in config file and ENV variables if set
func initConfig() {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		// Set default config path
		viper.AddConfigPath("/etc/odh-gateway")
		viper.SetConfigType("yaml")
		viper.SetConfigName("config")
	}

	// Set config file from environment if available
	if configPath := os.Getenv("GATEWAY_CONFIG"); configPath != "" {
		viper.SetConfigFile(configPath)
	}

	// Read config file (optional)
	if err := viper.ReadInConfig(); err == nil {
		log.Printf("Using config file: %s", viper.ConfigFileUsed())
	}
}

// runGateway is the main gateway server function
func runGateway(cmd *cobra.Command, args []string) {
	// Get TLS configuration from flags/env
	certFile := viper.GetString("tls.cert-file")
	keyFile := viper.GetString("tls.key-file")

	// Validate TLS configuration
	if (certFile != "" && keyFile == "") || (certFile == "" && keyFile != "") {
		log.Fatal("Both --tls-cert-file and --tls-key-file must be provided to enable TLS")
	}

	// Build provider configuration
	var providerConfig providers.ProviderConfig

	// Check for OIDC configuration
	oidcIssuerURLValue := viper.GetString("oidc.issuer-url")
	oidcClientIDValue := viper.GetString("oidc.client-id")
	oidcClientSecretValue := viper.GetString("oidc.client-secret")

	if oidcIssuerURLValue != "" && oidcClientIDValue != "" && oidcClientSecretValue != "" {
		// Configure OIDC provider
		providerConfig = providers.ProviderConfig{
			Type: "oidc",
			OIDC: &providers.OIDCProviderConfig{
				IssuerURL:    oidcIssuerURLValue,
				ClientID:     oidcClientIDValue,
				ClientSecret: oidcClientSecretValue,
			},
		}
		log.Printf("OIDC provider configured")
		log.Printf("OIDC configuration: Issuer=%s, ClientID=%s", oidcIssuerURLValue, oidcClientIDValue)
	} else {
		// No provider configured
		providerConfig = providers.ProviderConfig{
			Type: "disabled",
		}
	}

	// Start the gateway server
	if err := proxy.StartServer(certFile, keyFile, providerConfig); err != nil {
		log.Fatalf("Failed to start gateway: %v", err)
	}
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}
