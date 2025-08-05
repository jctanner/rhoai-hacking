package config

import (
	"time"

	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

// Config represents the complete configuration for the console auth proxy
type Config struct {
	Server        ServerConfig        `mapstructure:"server" yaml:"server"`
	Auth          AuthConfig          `mapstructure:"auth" yaml:"auth"`
	Proxy         ProxyConfig         `mapstructure:"proxy" yaml:"proxy"`
	Observability ObservabilityConfig `mapstructure:"observability" yaml:"observability"`
}

// ServerConfig contains HTTP server configuration
type ServerConfig struct {
	ListenAddress   string        `mapstructure:"listen_address" yaml:"listen_address"`
	ReadTimeout     time.Duration `mapstructure:"read_timeout" yaml:"read_timeout"`
	WriteTimeout    time.Duration `mapstructure:"write_timeout" yaml:"write_timeout"`
	IdleTimeout     time.Duration `mapstructure:"idle_timeout" yaml:"idle_timeout"`
	ShutdownTimeout time.Duration `mapstructure:"shutdown_timeout" yaml:"shutdown_timeout"`
	TLS             TLSConfig     `mapstructure:"tls" yaml:"tls"`
}

// TLSConfig contains TLS configuration
type TLSConfig struct {
	Enabled  bool   `mapstructure:"enabled" yaml:"enabled"`
	CertFile string `mapstructure:"cert_file" yaml:"cert_file"`
	KeyFile  string `mapstructure:"key_file" yaml:"key_file"`
}

// AuthConfig maps directly to the console auth.Config structure
// This preserves exact compatibility with the console auth module
type AuthConfig struct {
	AuthSource             string   `mapstructure:"auth_source" yaml:"auth_source"`                         // "openshift" or "oidc"
	IssuerURL              string   `mapstructure:"issuer_url" yaml:"issuer_url"`
	LogoutRedirectOverride string   `mapstructure:"logout_redirect_override" yaml:"logout_redirect_override"`
	IssuerCA               string   `mapstructure:"issuer_ca" yaml:"issuer_ca"`
	RedirectURL            string   `mapstructure:"redirect_url" yaml:"redirect_url"`
	ClientID               string   `mapstructure:"client_id" yaml:"client_id"`
	ClientSecret           string   `mapstructure:"client_secret" yaml:"client_secret"`
	Scope                  []string `mapstructure:"scope" yaml:"scope"`
	K8sCA                  string   `mapstructure:"k8s_ca" yaml:"k8s_ca"`
	SuccessURL             string   `mapstructure:"success_url" yaml:"success_url"`
	ErrorURL               string   `mapstructure:"error_url" yaml:"error_url"`
	CookiePath             string   `mapstructure:"cookie_path" yaml:"cookie_path"`
	SecureCookies          bool     `mapstructure:"secure_cookies" yaml:"secure_cookies"`
	OCLoginCommand         string   `mapstructure:"oc_login_command" yaml:"oc_login_command"`

	// Cookie encryption keys (base64 encoded)
	CookieAuthenticationKey string `mapstructure:"cookie_authentication_key" yaml:"cookie_authentication_key"`
	CookieEncryptionKey     string `mapstructure:"cookie_encryption_key" yaml:"cookie_encryption_key"`

	// TLS configuration for auth provider connections
	TLS AuthTLSConfig `mapstructure:"tls" yaml:"tls"`

	// Kubernetes configuration for token validation
	KubeConfig KubeConfig `mapstructure:"kube_config" yaml:"kube_config"`
}

// KubeConfig contains Kubernetes client configuration
type KubeConfig struct {
	InCluster      bool   `mapstructure:"in_cluster" yaml:"in_cluster"`
	ConfigPath     string `mapstructure:"config_path" yaml:"config_path"`
	ServerURL      string `mapstructure:"server_url" yaml:"server_url"`
	BearerToken    string `mapstructure:"bearer_token" yaml:"bearer_token"`
	BearerTokenFile string `mapstructure:"bearer_token_file" yaml:"bearer_token_file"`
	CAFile         string `mapstructure:"ca_file" yaml:"ca_file"`
}

// ProxyConfig contains reverse proxy configuration
type ProxyConfig struct {
	Backend  BackendConfig  `mapstructure:"backend" yaml:"backend"`
	Headers  HeaderConfig   `mapstructure:"headers" yaml:"headers"`
	Timeouts TimeoutConfig  `mapstructure:"timeouts" yaml:"timeouts"`
	TLS      ProxyTLSConfig `mapstructure:"tls" yaml:"tls"`
}

// BackendConfig defines the backend service to proxy to
type BackendConfig struct {
	URL               string `mapstructure:"url" yaml:"url"`
	HealthCheckPath   string `mapstructure:"health_check_path" yaml:"health_check_path"`
	HealthCheckInterval time.Duration `mapstructure:"health_check_interval" yaml:"health_check_interval"`
}

// HeaderConfig defines header manipulation for proxied requests
type HeaderConfig struct {
	// User identity headers to inject
	UserHeader   string `mapstructure:"user_header" yaml:"user_header"`
	UserIDHeader string `mapstructure:"user_id_header" yaml:"user_id_header"`
	EmailHeader  string `mapstructure:"email_header" yaml:"email_header"`
	
	// Authorization header handling
	AuthHeader      string `mapstructure:"auth_header" yaml:"auth_header"`
	AuthHeaderValue string `mapstructure:"auth_header_value" yaml:"auth_header_value"` // "bearer" or "token"
	
	// Custom headers to add
	Custom map[string]string `mapstructure:"custom" yaml:"custom"`
	
	// Headers to remove from backend requests
	Remove []string `mapstructure:"remove" yaml:"remove"`
}

// TimeoutConfig defines timeout settings for proxy requests
type TimeoutConfig struct {
	Dial              time.Duration `mapstructure:"dial" yaml:"dial"`
	TLSHandshake      time.Duration `mapstructure:"tls_handshake" yaml:"tls_handshake"`
	ResponseHeader    time.Duration `mapstructure:"response_header" yaml:"response_header"`
	ExpectContinue    time.Duration `mapstructure:"expect_continue" yaml:"expect_continue"`
	IdleConn          time.Duration `mapstructure:"idle_conn" yaml:"idle_conn"`
	MaxIdleConns      int           `mapstructure:"max_idle_conns" yaml:"max_idle_conns"`
	MaxIdleConnsPerHost int         `mapstructure:"max_idle_conns_per_host" yaml:"max_idle_conns_per_host"`
}

// ProxyTLSConfig contains TLS settings for backend connections
type ProxyTLSConfig struct {
	InsecureSkipVerify bool   `mapstructure:"insecure_skip_verify" yaml:"insecure_skip_verify"`
	ServerName         string `mapstructure:"server_name" yaml:"server_name"` // Override SNI server name
	CAFile             string `mapstructure:"ca_file" yaml:"ca_file"`
	CertFile           string `mapstructure:"cert_file" yaml:"cert_file"`
	KeyFile            string `mapstructure:"key_file" yaml:"key_file"`
}

// AuthTLSConfig contains TLS settings for auth provider connections
type AuthTLSConfig struct {
	InsecureSkipVerify bool   `mapstructure:"insecure_skip_verify" yaml:"insecure_skip_verify"`
	ServerName         string `mapstructure:"server_name" yaml:"server_name"` // Override SNI server name
}

// ObservabilityConfig contains monitoring and logging configuration
type ObservabilityConfig struct {
	Metrics MetricsConfig `mapstructure:"metrics" yaml:"metrics"`
	Logging LoggingConfig `mapstructure:"logging" yaml:"logging"`
	Health  HealthConfig  `mapstructure:"health" yaml:"health"`
}

// MetricsConfig defines Prometheus metrics configuration
type MetricsConfig struct {
	Enabled bool   `mapstructure:"enabled" yaml:"enabled"`
	Path    string `mapstructure:"path" yaml:"path"`
	Address string `mapstructure:"address" yaml:"address"` // If different from main server
}

// LoggingConfig defines logging configuration
type LoggingConfig struct {
	Level  string `mapstructure:"level" yaml:"level"`   // debug, info, warn, error
	Format string `mapstructure:"format" yaml:"format"` // json, text
	Output string `mapstructure:"output" yaml:"output"` // stdout, stderr, file path
}

// HealthConfig defines health check configuration
type HealthConfig struct {
	Enabled     bool   `mapstructure:"enabled" yaml:"enabled"`
	LivenessPath  string `mapstructure:"liveness_path" yaml:"liveness_path"`
	ReadinessPath string `mapstructure:"readiness_path" yaml:"readiness_path"`
}

// SetDefaults sets default values for the configuration
func (c *Config) SetDefaults() {
	// Server defaults
	if c.Server.ListenAddress == "" {
		c.Server.ListenAddress = "0.0.0.0:8080"
	}
	if c.Server.ReadTimeout == 0 {
		c.Server.ReadTimeout = 30 * time.Second
	}
	if c.Server.WriteTimeout == 0 {
		c.Server.WriteTimeout = 30 * time.Second
	}
	if c.Server.IdleTimeout == 0 {
		c.Server.IdleTimeout = 120 * time.Second
	}
	if c.Server.ShutdownTimeout == 0 {
		c.Server.ShutdownTimeout = 30 * time.Second
	}

	// Auth defaults
	if c.Auth.AuthSource == "" {
		c.Auth.AuthSource = "oidc"
	}
	if c.Auth.CookiePath == "" {
		c.Auth.CookiePath = "/"
	}
	if c.Auth.SuccessURL == "" {
		c.Auth.SuccessURL = "/"
	}
	if c.Auth.ErrorURL == "" {
		c.Auth.ErrorURL = "/auth/error"
	}
	if len(c.Auth.Scope) == 0 {
		c.Auth.Scope = []string{"openid", "profile", "email"}
	}

	// Proxy defaults
	if c.Proxy.Headers.UserHeader == "" {
		c.Proxy.Headers.UserHeader = "X-Forwarded-User"
	}
	if c.Proxy.Headers.UserIDHeader == "" {
		c.Proxy.Headers.UserIDHeader = "X-Forwarded-User-ID"
	}
	if c.Proxy.Headers.EmailHeader == "" {
		c.Proxy.Headers.EmailHeader = "X-Forwarded-Email"
	}
	if c.Proxy.Headers.AuthHeader == "" {
		c.Proxy.Headers.AuthHeader = "Authorization"
	}
	if c.Proxy.Headers.AuthHeaderValue == "" {
		c.Proxy.Headers.AuthHeaderValue = "bearer"
	}
	if c.Proxy.Backend.HealthCheckInterval == 0 {
		c.Proxy.Backend.HealthCheckInterval = 30 * time.Second
	}

	// Timeout defaults
	if c.Proxy.Timeouts.Dial == 0 {
		c.Proxy.Timeouts.Dial = 30 * time.Second
	}
	if c.Proxy.Timeouts.TLSHandshake == 0 {
		c.Proxy.Timeouts.TLSHandshake = 10 * time.Second
	}
	if c.Proxy.Timeouts.ResponseHeader == 0 {
		c.Proxy.Timeouts.ResponseHeader = 30 * time.Second
	}
	if c.Proxy.Timeouts.ExpectContinue == 0 {
		c.Proxy.Timeouts.ExpectContinue = 1 * time.Second
	}
	if c.Proxy.Timeouts.IdleConn == 0 {
		c.Proxy.Timeouts.IdleConn = 90 * time.Second
	}
	if c.Proxy.Timeouts.MaxIdleConns == 0 {
		c.Proxy.Timeouts.MaxIdleConns = 100
	}
	if c.Proxy.Timeouts.MaxIdleConnsPerHost == 0 {
		c.Proxy.Timeouts.MaxIdleConnsPerHost = 10
	}

	// Observability defaults
	if c.Observability.Metrics.Path == "" {
		c.Observability.Metrics.Path = "/metrics"
	}
	if c.Observability.Logging.Level == "" {
		c.Observability.Logging.Level = "info"
	}
	if c.Observability.Logging.Format == "" {
		c.Observability.Logging.Format = "text"
	}
	if c.Observability.Logging.Output == "" {
		c.Observability.Logging.Output = "stdout"
	}
	if c.Observability.Health.LivenessPath == "" {
		c.Observability.Health.LivenessPath = "/healthz"
	}
	if c.Observability.Health.ReadinessPath == "" {
		c.Observability.Health.ReadinessPath = "/readyz"
	}
}

// GetKubernetesConfig builds a Kubernetes rest.Config from the configuration
func (a *AuthConfig) GetKubernetesConfig() (*rest.Config, error) {
	if a.KubeConfig.InCluster {
		return rest.InClusterConfig()
	}

	if a.KubeConfig.ConfigPath != "" {
		return clientcmd.BuildConfigFromFlags("", a.KubeConfig.ConfigPath)
	}

	// Manual configuration
	config := &rest.Config{}
	
	if a.KubeConfig.ServerURL != "" {
		config.Host = a.KubeConfig.ServerURL
	}
	
	if a.KubeConfig.BearerToken != "" {
		config.BearerToken = a.KubeConfig.BearerToken
	}
	
	if a.KubeConfig.BearerTokenFile != "" {
		config.BearerTokenFile = a.KubeConfig.BearerTokenFile
	}
	
	if a.KubeConfig.CAFile != "" {
		config.CAFile = a.KubeConfig.CAFile
	}

	return config, nil
}