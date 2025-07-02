package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Routes   []Route         `yaml:"routes"`
	Provider *ProviderConfig `yaml:"provider,omitempty"`
}

type Route struct {
	PathPrefix   string `yaml:"path"`
	Upstream     string `yaml:"upstream"`
	AuthRequired *bool  `yaml:"authRequired,omitempty"` // Optional per-route auth override
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

func LoadConfig(path string) (*Config, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read config: %w", err)
	}

	var cfg Config
	if err := yaml.Unmarshal(raw, &cfg); err != nil {
		return nil, fmt.Errorf("unmarshal config: %w", err)
	}

	return &cfg, nil
}
