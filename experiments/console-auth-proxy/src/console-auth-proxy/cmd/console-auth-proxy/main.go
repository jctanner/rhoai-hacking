package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	"github.com/your-org/console-auth-proxy/internal/config"
	"github.com/your-org/console-auth-proxy/internal/server"
	"github.com/your-org/console-auth-proxy/internal/version"
)

var (
	cfgFile string
	cfg     *config.Config
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "console-auth-proxy",
		Short: "OpenShift Console Authentication Proxy",
		Long: `A standalone authentication reverse proxy service that uses the OpenShift Console's 
authentication module to provide OAuth2/OIDC authentication for backend applications.`,
		Version: version.Version,
		RunE:    run,
	}

	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is ./config.yaml)")
	rootCmd.PersistentFlags().String("listen-address", "0.0.0.0:8080", "Address to listen on")
	rootCmd.PersistentFlags().String("backend-url", "", "Backend URL to proxy to")
	rootCmd.PersistentFlags().String("auth-source", "oidc", "Authentication source (openshift or oidc)")
	rootCmd.PersistentFlags().String("issuer-url", "", "OIDC issuer URL")
	rootCmd.PersistentFlags().String("client-id", "", "OAuth2 client ID")
	rootCmd.PersistentFlags().String("client-secret", "", "OAuth2 client secret")
	rootCmd.PersistentFlags().String("redirect-url", "", "OAuth2 redirect URL")
	rootCmd.PersistentFlags().Bool("secure-cookies", true, "Use secure cookies (HTTPS)")
	
	// TLS options for auth provider connections
	rootCmd.PersistentFlags().Bool("auth-tls-insecure-skip-verify", false, "Skip TLS certificate verification for auth provider")
	rootCmd.PersistentFlags().String("auth-tls-server-name", "", "Override SNI server name for auth provider connections")
	
	// TLS options for backend proxy connections
	rootCmd.PersistentFlags().Bool("proxy-tls-insecure-skip-verify", false, "Skip TLS certificate verification for backend")
	rootCmd.PersistentFlags().String("proxy-tls-server-name", "", "Override SNI server name for backend connections")
	rootCmd.PersistentFlags().String("proxy-tls-ca-file", "", "Custom CA file for backend connections")
	rootCmd.PersistentFlags().String("proxy-tls-cert-file", "", "Client certificate file for backend connections")
	rootCmd.PersistentFlags().String("proxy-tls-key-file", "", "Client private key file for backend connections")

	// Bind flags to viper with custom mappings for nested config
	viper.BindPFlags(rootCmd.PersistentFlags())
	
	// Map CLI flags to nested config structure
	viper.BindPFlag("auth.tls.insecure_skip_verify", rootCmd.PersistentFlags().Lookup("auth-tls-insecure-skip-verify"))
	viper.BindPFlag("auth.tls.server_name", rootCmd.PersistentFlags().Lookup("auth-tls-server-name"))
	viper.BindPFlag("proxy.tls.insecure_skip_verify", rootCmd.PersistentFlags().Lookup("proxy-tls-insecure-skip-verify"))
	viper.BindPFlag("proxy.tls.server_name", rootCmd.PersistentFlags().Lookup("proxy-tls-server-name"))
	viper.BindPFlag("proxy.tls.ca_file", rootCmd.PersistentFlags().Lookup("proxy-tls-ca-file"))
	viper.BindPFlag("proxy.tls.cert_file", rootCmd.PersistentFlags().Lookup("proxy-tls-cert-file"))
	viper.BindPFlag("proxy.tls.key_file", rootCmd.PersistentFlags().Lookup("proxy-tls-key-file"))

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func run(cmd *cobra.Command, args []string) error {
	// Initialize configuration
	if err := initConfig(); err != nil {
		return fmt.Errorf("failed to initialize config: %w", err)
	}

	// Validate configuration
	if err := cfg.Validate(); err != nil {
		return fmt.Errorf("invalid configuration: %w", err)
	}

	log.Printf("Starting Console Auth Proxy %s", version.Version)
	log.Printf("Config: Auth Source=%s, Listen=%s, Backend=%s", 
		cfg.Auth.AuthSource, cfg.Server.ListenAddress, cfg.Proxy.Backend.URL)

	// Create and start server
	srv, err := server.New(cfg)
	if err != nil {
		return fmt.Errorf("failed to create server: %w", err)
	}

	// Start server in goroutine
	serverErrors := make(chan error, 1)
	go func() {
		log.Printf("Server listening on %s", cfg.Server.ListenAddress)
		serverErrors <- srv.ListenAndServe()
	}()

	// Wait for interrupt signal
	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt, syscall.SIGTERM)

	// Block until we receive our signal or an error from the server
	select {
	case err := <-serverErrors:
		return fmt.Errorf("server error: %w", err)
	case sig := <-interrupt:
		log.Printf("Received signal %v, initiating shutdown", sig)

		// Create context with timeout for shutdown
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		// Attempt graceful shutdown
		if err := srv.Shutdown(ctx); err != nil {
			log.Printf("Server shutdown error: %v", err)
			srv.Close()
		}

		log.Printf("Server shutdown complete")
	}

	return nil
}

func initConfig() error {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		viper.SetConfigName("config")
		viper.SetConfigType("yaml")
		viper.AddConfigPath(".")
		viper.AddConfigPath("./configs")
	}

	// Read environment variables with key replacer for nested configs
	viper.SetEnvPrefix("CAP") // Console Auth Proxy
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_", "-", "_"))
	viper.AutomaticEnv()

	// Read config file if it exists
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return fmt.Errorf("failed to read config file: %w", err)
		}
		log.Printf("No config file found, using defaults and environment variables")
	} else {
		log.Printf("Using config file: %s", viper.ConfigFileUsed())
	}

	// Unmarshal config
	cfg = &config.Config{}
	if err := viper.Unmarshal(cfg); err != nil {
		return fmt.Errorf("failed to unmarshal config: %w", err)
	}

	return nil
}