package providers

import (
	"context"
	"fmt"
	"log"
	"net/http"

	"github.com/coreos/go-oidc/v3/oidc"
	"golang.org/x/oauth2"
)

// OIDCProvider implements the AuthProvider interface for OpenID Connect
type OIDCProvider struct {
	config       OIDCProviderConfig
	provider     *oidc.Provider
	oauth2Config oauth2.Config
	verifier     *oidc.IDTokenVerifier
	baseURL      string
	initialized  bool
}

// NewOIDCProvider creates a new OIDC provider
func NewOIDCProvider(config OIDCProviderConfig, baseURL string) (*OIDCProvider, error) {
	return &OIDCProvider{
		config:      config,
		baseURL:     baseURL,
		initialized: false,
	}, nil
}

// initializeProvider initializes the OIDC provider (lazy initialization)
func (p *OIDCProvider) initializeProvider() error {
	if p.initialized {
		return nil
	}

	ctx := context.Background()
	provider, err := oidc.NewProvider(ctx, p.config.IssuerURL)
	if err != nil {
		return fmt.Errorf("failed to create OIDC provider: %w", err)
	}

	// Configure OAuth2
	p.oauth2Config = oauth2.Config{
		ClientID:     p.config.ClientID,
		ClientSecret: p.config.ClientSecret,
		RedirectURL:  p.baseURL + "/auth/callback",
		Endpoint:     provider.Endpoint(),
		Scopes:       []string{oidc.ScopeOpenID, "profile", "email"},
	}

	// Configure ID token verifier
	p.verifier = provider.Verifier(&oidc.Config{ClientID: p.config.ClientID})
	p.provider = provider
	p.initialized = true

	log.Printf("OIDC provider initialized successfully for issuer: %s", p.config.IssuerURL)
	return nil
}

// GetLoginURL returns the URL to redirect users for authentication
func (p *OIDCProvider) GetLoginURL(state, redirectURL string) string {
	if err := p.initializeProvider(); err != nil {
		log.Printf("Failed to initialize OIDC provider: %v", err)
		return ""
	}
	return p.oauth2Config.AuthCodeURL(state)
}

// HandleCallback processes the authentication callback and returns user info
func (p *OIDCProvider) HandleCallback(w http.ResponseWriter, r *http.Request) (*UserInfo, error) {
	if err := p.initializeProvider(); err != nil {
		return nil, fmt.Errorf("failed to initialize OIDC provider: %w", err)
	}

	ctx := context.Background()

	// Exchange authorization code for tokens
	code := r.URL.Query().Get("code")
	token, err := p.oauth2Config.Exchange(ctx, code)
	if err != nil {
		return nil, fmt.Errorf("failed to exchange code: %w", err)
	}

	// Extract and verify ID token
	rawIDToken, ok := token.Extra("id_token").(string)
	if !ok {
		return nil, fmt.Errorf("no id_token in response")
	}

	idToken, err := p.verifier.Verify(ctx, rawIDToken)
	if err != nil {
		return nil, fmt.Errorf("failed to verify ID token: %w", err)
	}

	// Extract claims and create UserInfo
	var claims map[string]interface{}
	if err := idToken.Claims(&claims); err != nil {
		return nil, fmt.Errorf("failed to extract claims: %w", err)
	}

	userInfo := p.extractUserInfo(claims)

	// Store the ID token in a secure cookie
	http.SetCookie(w, &http.Cookie{
		Name:     "auth_token",
		Value:    rawIDToken,
		Path:     "/",
		HttpOnly: true,
		Secure:   r.TLS != nil,
		MaxAge:   3600, // 1 hour
	})

	return userInfo, nil
}

// ValidateToken validates a token and returns user info
func (p *OIDCProvider) ValidateToken(tokenString string) (*UserInfo, error) {
	if err := p.initializeProvider(); err != nil {
		return nil, fmt.Errorf("failed to initialize OIDC provider: %w", err)
	}

	ctx := context.Background()
	idToken, err := p.verifier.Verify(ctx, tokenString)
	if err != nil {
		return nil, fmt.Errorf("token verification failed: %w", err)
	}

	// Extract claims
	var claims map[string]interface{}
	if err := idToken.Claims(&claims); err != nil {
		return nil, fmt.Errorf("failed to extract claims: %w", err)
	}

	return p.extractUserInfo(claims), nil
}

// GetLogoutURL returns the URL for logging out
func (p *OIDCProvider) GetLogoutURL(redirectURL string) string {
	// OIDC doesn't have a standard logout URL, but many providers support it
	// This would need to be provider-specific
	return ""
}

// IsEnabled returns whether this provider is enabled
func (p *OIDCProvider) IsEnabled() bool {
	return p.config.IssuerURL != "" && p.config.ClientID != "" && p.config.ClientSecret != ""
}

// Name returns the provider name
func (p *OIDCProvider) Name() string {
	return "oidc"
}

// extractUserInfo extracts user information from JWT claims
func (p *OIDCProvider) extractUserInfo(claims map[string]interface{}) *UserInfo {
	userInfo := &UserInfo{}

	// Extract username (try preferred_username first, then sub)
	if preferred, ok := claims["preferred_username"].(string); ok {
		userInfo.Username = preferred
	} else if sub, ok := claims["sub"].(string); ok {
		userInfo.Username = sub
		userInfo.Sub = sub
	}

	// Extract email
	if email, ok := claims["email"].(string); ok {
		userInfo.Email = email
	}

	// Extract groups
	if groupsClaim, ok := claims["groups"]; ok {
		switch v := groupsClaim.(type) {
		case []interface{}:
			for _, group := range v {
				if groupStr, ok := group.(string); ok {
					userInfo.Groups = append(userInfo.Groups, groupStr)
				}
			}
		case []string:
			userInfo.Groups = v
		case string:
			userInfo.Groups = []string{v}
		}
	}

	return userInfo
}
