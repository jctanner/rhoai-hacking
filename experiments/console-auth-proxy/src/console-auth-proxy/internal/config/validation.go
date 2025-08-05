package config

import (
	"fmt"
	"net/url"
	"strings"
)

// Validate validates the configuration and returns an error if invalid
func (c *Config) Validate() error {
	if err := c.Server.Validate(); err != nil {
		return fmt.Errorf("server config: %w", err)
	}

	if err := c.Auth.Validate(); err != nil {
		return fmt.Errorf("auth config: %w", err)
	}

	if err := c.Proxy.Validate(); err != nil {
		return fmt.Errorf("proxy config: %w", err)
	}

	return nil
}

// Validate validates server configuration
func (s *ServerConfig) Validate() error {
	if s.ListenAddress == "" {
		return fmt.Errorf("listen_address is required")
	}

	if s.TLS.Enabled {
		if s.TLS.CertFile == "" {
			return fmt.Errorf("tls.cert_file is required when TLS is enabled")
		}
		if s.TLS.KeyFile == "" {
			return fmt.Errorf("tls.key_file is required when TLS is enabled")
		}
	}

	return nil
}

// Validate validates authentication configuration
func (a *AuthConfig) Validate() error {
	// Validate auth source
	switch strings.ToLower(a.AuthSource) {
	case "openshift", "oidc":
		// Valid auth sources
	default:
		return fmt.Errorf("auth_source must be 'openshift' or 'oidc', got: %s", a.AuthSource)
	}

	// Validate required fields
	if a.IssuerURL == "" {
		return fmt.Errorf("issuer_url is required")
	}

	if _, err := url.Parse(a.IssuerURL); err != nil {
		return fmt.Errorf("issuer_url is not a valid URL: %w", err)
	}

	if a.ClientID == "" {
		return fmt.Errorf("client_id is required")
	}

	if a.ClientSecret == "" {
		return fmt.Errorf("client_secret is required")
	}

	if a.RedirectURL == "" {
		return fmt.Errorf("redirect_url is required")
	}

	if _, err := url.Parse(a.RedirectURL); err != nil {
		return fmt.Errorf("redirect_url is not a valid URL: %w", err)
	}

	// Validate URLs if provided
	if a.SuccessURL != "" {
		if _, err := url.Parse(a.SuccessURL); err != nil {
			return fmt.Errorf("success_url is not a valid URL: %w", err)
		}
	}

	if a.ErrorURL != "" {
		if _, err := url.Parse(a.ErrorURL); err != nil {
			return fmt.Errorf("error_url is not a valid URL: %w", err)
		}
	}

	if a.LogoutRedirectOverride != "" {
		if _, err := url.Parse(a.LogoutRedirectOverride); err != nil {
			return fmt.Errorf("logout_redirect_override is not a valid URL: %w", err)
		}
	}

	// Validate cookie path
	if a.CookiePath == "" {
		return fmt.Errorf("cookie_path cannot be empty")
	}

	if !strings.HasPrefix(a.CookiePath, "/") {
		return fmt.Errorf("cookie_path must start with /")
	}

	// Validate scopes
	if len(a.Scope) == 0 {
		return fmt.Errorf("at least one scope is required")
	}

	// Validate Kubernetes configuration if not using in-cluster config
	if !a.KubeConfig.InCluster {
		if a.KubeConfig.ConfigPath == "" && a.KubeConfig.ServerURL == "" {
			return fmt.Errorf("either kube_config.config_path or kube_config.server_url is required when not using in-cluster config")
		}

		if a.KubeConfig.ServerURL != "" {
			if _, err := url.Parse(a.KubeConfig.ServerURL); err != nil {
				return fmt.Errorf("kube_config.server_url is not a valid URL: %w", err)
			}

			if a.KubeConfig.BearerToken == "" && a.KubeConfig.BearerTokenFile == "" {
				return fmt.Errorf("either kube_config.bearer_token or kube_config.bearer_token_file is required when using server_url")
			}
		}
	}

	return nil
}

// Validate validates proxy configuration
func (p *ProxyConfig) Validate() error {
	if err := p.Backend.Validate(); err != nil {
		return fmt.Errorf("backend: %w", err)
	}

	if err := p.Headers.Validate(); err != nil {
		return fmt.Errorf("headers: %w", err)
	}

	return nil
}

// Validate validates backend configuration
func (b *BackendConfig) Validate() error {
	if b.URL == "" {
		return fmt.Errorf("url is required")
	}

	parsedURL, err := url.Parse(b.URL)
	if err != nil {
		return fmt.Errorf("url is not a valid URL: %w", err)
	}

	if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		return fmt.Errorf("url scheme must be http or https, got: %s", parsedURL.Scheme)
	}

	if parsedURL.Host == "" {
		return fmt.Errorf("url must include a host")
	}

	// Validate health check path if provided
	if b.HealthCheckPath != "" {
		if !strings.HasPrefix(b.HealthCheckPath, "/") {
			return fmt.Errorf("health_check_path must start with /")
		}
	}

	return nil
}

// Validate validates header configuration
func (h *HeaderConfig) Validate() error {
	// Validate auth header value
	switch strings.ToLower(h.AuthHeaderValue) {
	case "bearer", "token", "":
		// Valid values
	default:
		return fmt.Errorf("auth_header_value must be 'bearer' or 'token', got: %s", h.AuthHeaderValue)
	}

	// Validate header names
	if h.UserHeader != "" && !isValidHeaderName(h.UserHeader) {
		return fmt.Errorf("user_header is not a valid HTTP header name: %s", h.UserHeader)
	}

	if h.UserIDHeader != "" && !isValidHeaderName(h.UserIDHeader) {
		return fmt.Errorf("user_id_header is not a valid HTTP header name: %s", h.UserIDHeader)
	}

	if h.EmailHeader != "" && !isValidHeaderName(h.EmailHeader) {
		return fmt.Errorf("email_header is not a valid HTTP header name: %s", h.EmailHeader)
	}

	if h.AuthHeader != "" && !isValidHeaderName(h.AuthHeader) {
		return fmt.Errorf("auth_header is not a valid HTTP header name: %s", h.AuthHeader)
	}

	// Validate custom headers
	for name := range h.Custom {
		if !isValidHeaderName(name) {
			return fmt.Errorf("custom header name is not valid: %s", name)
		}
	}

	// Validate remove headers
	for _, name := range h.Remove {
		if !isValidHeaderName(name) {
			return fmt.Errorf("remove header name is not valid: %s", name)
		}
	}

	return nil
}

// isValidHeaderName checks if a string is a valid HTTP header name
func isValidHeaderName(name string) bool {
	if name == "" {
		return false
	}

	for _, char := range name {
		// HTTP header names can contain ASCII letters, digits, and hyphens
		if !((char >= 'A' && char <= 'Z') || (char >= 'a' && char <= 'z') || 
			 (char >= '0' && char <= '9') || char == '-' || char == '_') {
			return false
		}
	}

	return true
}