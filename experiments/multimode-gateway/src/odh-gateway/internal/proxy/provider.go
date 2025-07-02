package proxy

import (
	"net/http"
)

// AuthProvider defines the interface that all authentication providers must implement
type AuthProvider interface {
	// GetLoginURL returns the URL to redirect users for authentication
	GetLoginURL(state, redirectURL string) string

	// HandleCallback processes the authentication callback and returns user info
	HandleCallback(w http.ResponseWriter, r *http.Request) (*UserInfo, error)

	// ValidateToken validates a token and returns user info
	ValidateToken(tokenString string) (*UserInfo, error)

	// GetLogoutURL returns the URL for logging out (optional)
	GetLogoutURL(redirectURL string) string

	// IsEnabled returns whether this provider is enabled
	IsEnabled() bool

	// Name returns the provider name
	Name() string
}

// UserInfo contains user information extracted from authentication
type UserInfo struct {
	Username string   `json:"username"`
	Email    string   `json:"email,omitempty"`
	Groups   []string `json:"groups,omitempty"`
	Sub      string   `json:"sub,omitempty"`
}

// ProviderConfig holds configuration for authentication providers
type ProviderConfig struct {
	// Provider type (oidc, openshift, etc.)
	Type string `yaml:"type"`

	// OIDC Provider configuration
	OIDC *OIDCProviderConfig `yaml:"oidc,omitempty"`

	// OpenShift Provider configuration
	OpenShift *OpenShiftProviderConfig `yaml:"openshift,omitempty"`
}

// OIDCProviderConfig holds OIDC-specific configuration
type OIDCProviderConfig struct {
	IssuerURL    string `yaml:"issuerUrl"`
	ClientID     string `yaml:"clientId"`
	ClientSecret string `yaml:"clientSecret"`
}

// OpenShiftProviderConfig holds OpenShift-specific configuration
type OpenShiftProviderConfig struct {
	// OpenShift cluster URL (e.g., https://api.cluster.example.com:6443)
	ClusterURL string `yaml:"clusterUrl"`

	// Client ID for OpenShift OAuth
	ClientID string `yaml:"clientId"`

	// Client Secret for OpenShift OAuth
	ClientSecret string `yaml:"clientSecret"`

	// CA Bundle for validating OpenShift API certificates
	CABundle string `yaml:"caBundle,omitempty"`

	// Scope to request (default: "user:info")
	Scope string `yaml:"scope,omitempty"`
}

// CreateProvider creates an authentication provider based on configuration
func CreateProvider(config ProviderConfig, baseURL string) (AuthProvider, error) {
	switch config.Type {
	case "oidc":
		if config.OIDC == nil {
			return NewDisabledProvider("oidc"), nil
		}
		return NewOIDCProvider(*config.OIDC, baseURL)

	case "openshift":
		if config.OpenShift == nil {
			return NewDisabledProvider("openshift"), nil
		}
		return NewOpenShiftProvider(*config.OpenShift, baseURL)

	default:
		return NewDisabledProvider("unknown"), nil
	}
}

// DisabledProvider is a no-op provider for when authentication is disabled
type DisabledProvider struct {
	name string
}

// NewDisabledProvider creates a disabled provider
func NewDisabledProvider(name string) *DisabledProvider {
	return &DisabledProvider{name: name}
}

func (p *DisabledProvider) GetLoginURL(state, redirectURL string) string {
	return ""
}

func (p *DisabledProvider) HandleCallback(w http.ResponseWriter, r *http.Request) (*UserInfo, error) {
	return nil, nil
}

func (p *DisabledProvider) ValidateToken(tokenString string) (*UserInfo, error) {
	return nil, nil
}

func (p *DisabledProvider) GetLogoutURL(redirectURL string) string {
	return ""
}

func (p *DisabledProvider) IsEnabled() bool {
	return false
}

func (p *DisabledProvider) Name() string {
	return p.name
}
