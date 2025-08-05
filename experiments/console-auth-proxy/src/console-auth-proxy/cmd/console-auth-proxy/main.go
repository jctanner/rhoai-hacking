package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
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

	// Bind flags to viper
	viper.BindPFlags(rootCmd.PersistentFlags())

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

	// Read environment variables
	viper.SetEnvPrefix("CAP") // Console Auth Proxy
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