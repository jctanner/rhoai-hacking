package main

import (
	"log"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	"github.com/jctanner/odh-gateway/internal/proxy"
	"github.com/jctanner/odh-gateway/internal/proxy/providers"
	"github.com/jctanner/odh-gateway/pkg/config"
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

	// OpenShift OAuth configuration
	openshiftClusterURL   string
	openshiftClientID     string
	openshiftClientSecret string
	openshiftCABundle     string
	openshiftScope        string
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

	// OpenShift OAuth flags
	rootCmd.Flags().StringVar(&openshiftClusterURL, "openshift-cluster-url", "", "OpenShift cluster URL (e.g., https://api.cluster.example.com:6443)")
	rootCmd.Flags().StringVar(&openshiftClientID, "openshift-client-id", "", "OpenShift OAuth client ID")
	rootCmd.Flags().StringVar(&openshiftClientSecret, "openshift-client-secret", "", "OpenShift OAuth client secret")
	rootCmd.Flags().StringVar(&openshiftCABundle, "openshift-ca-bundle", "", "OpenShift CA bundle (PEM format)")
	rootCmd.Flags().StringVar(&openshiftScope, "openshift-scope", "", "OpenShift OAuth scope (default: user:info)")

	// Bind flags to viper for environment variable support
	viper.BindPFlag("tls.cert-file", rootCmd.Flags().Lookup("tls-cert-file"))
	viper.BindPFlag("tls.key-file", rootCmd.Flags().Lookup("tls-key-file"))
	viper.BindPFlag("oidc.issuer-url", rootCmd.Flags().Lookup("oidc-issuer-url"))
	viper.BindPFlag("oidc.client-id", rootCmd.Flags().Lookup("oidc-client-id"))
	viper.BindPFlag("oidc.client-secret", rootCmd.Flags().Lookup("oidc-client-secret"))
	viper.BindPFlag("openshift.cluster-url", rootCmd.Flags().Lookup("openshift-cluster-url"))
	viper.BindPFlag("openshift.client-id", rootCmd.Flags().Lookup("openshift-client-id"))
	viper.BindPFlag("openshift.client-secret", rootCmd.Flags().Lookup("openshift-client-secret"))
	viper.BindPFlag("openshift.ca-bundle", rootCmd.Flags().Lookup("openshift-ca-bundle"))
	viper.BindPFlag("openshift.scope", rootCmd.Flags().Lookup("openshift-scope"))

	// Set environment variable prefix
	viper.SetEnvPrefix("GATEWAY")
	viper.AutomaticEnv()

	// Bind additional environment variables for backward compatibility
	viper.BindEnv("tls.cert-file", "TLS_CERT_FILE")
	viper.BindEnv("tls.key-file", "TLS_KEY_FILE")
	viper.BindEnv("oidc.issuer-url", "OIDC_ISSUER_URL")
	viper.BindEnv("oidc.client-id", "OIDC_CLIENT_ID")
	viper.BindEnv("oidc.client-secret", "OIDC_CLIENT_SECRET")
	viper.BindEnv("openshift.cluster-url", "OPENSHIFT_CLUSTER_URL")
	viper.BindEnv("openshift.client-id", "OPENSHIFT_CLIENT_ID")
	viper.BindEnv("openshift.client-secret", "OPENSHIFT_CLIENT_SECRET")
	viper.BindEnv("openshift.ca-bundle", "OPENSHIFT_CA_BUNDLE")
	viper.BindEnv("openshift.scope", "OPENSHIFT_SCOPE")
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

	// Check for OpenShift configuration
	openshiftClusterURLValue := viper.GetString("openshift.cluster-url")
	openshiftClientIDValue := viper.GetString("openshift.client-id")
	openshiftClientSecretValue := viper.GetString("openshift.client-secret")
	openshiftCABundleValue := viper.GetString("openshift.ca-bundle")
	openshiftScopeValue := viper.GetString("openshift.scope")

	// Provider selection logic - OpenShift takes precedence if both are configured
	if openshiftClusterURLValue != "" && openshiftClientIDValue != "" && openshiftClientSecretValue != "" {
		// Configure OpenShift provider
		providerConfig = providers.ProviderConfig{
			Type: "openshift",
			OpenShift: &config.OpenShiftProviderConfig{
				ClusterURL:   openshiftClusterURLValue,
				ClientID:     openshiftClientIDValue,
				ClientSecret: openshiftClientSecretValue,
				CABundle:     openshiftCABundleValue,
				Scope:        openshiftScopeValue,
			},
		}
		log.Printf("OpenShift OAuth provider configured")
		log.Printf("OpenShift configuration: ClusterURL=%s, ClientID=%s", openshiftClusterURLValue, openshiftClientIDValue)
		if openshiftCABundleValue != "" {
			log.Printf("OpenShift CA bundle configured")
		}
		if openshiftScopeValue != "" {
			log.Printf("OpenShift scope: %s", openshiftScopeValue)
		}
	} else if oidcIssuerURLValue != "" && oidcClientIDValue != "" && oidcClientSecretValue != "" {
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
		log.Printf("No authentication provider configured - running without authentication")
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
