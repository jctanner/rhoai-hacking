package providers

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/jctanner/odh-gateway/pkg/config"
	"golang.org/x/oauth2"
)

// OpenShiftProvider implements the AuthProvider interface for OpenShift OAuth
type OpenShiftProvider struct {
	config       config.OpenShiftProviderConfig
	oauth2Config oauth2.Config
	httpClient   *http.Client
	baseURL      string
}

// OpenShiftUserInfo represents user information from OpenShift API
type OpenShiftUserInfo struct {
	Metadata struct {
		Name string `json:"name"`
		UID  string `json:"uid"`
	} `json:"metadata"`
	FullName string   `json:"fullName,omitempty"`
	Groups   []string `json:"groups,omitempty"`
}

// NewOpenShiftProvider creates a new OpenShift provider
func NewOpenShiftProvider(config config.OpenShiftProviderConfig, baseURL string) (*OpenShiftProvider, error) {
	// Auto-configure if using service account mode
	if config.ServiceAccount {
		if err := autoConfigureServiceAccount(&config); err != nil {
			return nil, fmt.Errorf("failed to auto-configure service account: %w", err)
		}
	}

	// Set default scope if not provided
	scope := config.Scope
	if scope == "" {
		scope = "user:info"
	}

	// Discover OAuth endpoints
	authURL, tokenURL, err := discoverOAuthEndpoints(config.ClusterURL)
	if err != nil {
		log.Printf("Warning: failed to discover OAuth endpoints, using defaults: %v", err)
		authURL = strings.TrimSuffix(config.ClusterURL, "/") + "/oauth/authorize"
		tokenURL = strings.TrimSuffix(config.ClusterURL, "/") + "/oauth/token"
	}

	// Configure OAuth2
	oauth2Config := oauth2.Config{
		ClientID:     config.ClientID,
		ClientSecret: config.ClientSecret,
		RedirectURL:  baseURL + "/auth/callback",
		Endpoint: oauth2.Endpoint{
			AuthURL:  authURL,
			TokenURL: tokenURL,
		},
		Scopes: []string{scope},
	}

	// Create HTTP client with custom CA if provided
	httpClient := &http.Client{
		Timeout: 30 * time.Second,
	}

	if config.CABundle != "" {
		// Parse CA bundle
		caCertPool := x509.NewCertPool()
		if !caCertPool.AppendCertsFromPEM([]byte(config.CABundle)) {
			return nil, fmt.Errorf("failed to parse CA bundle")
		}

		// Configure TLS
		httpClient.Transport = &http.Transport{
			TLSClientConfig: &tls.Config{
				RootCAs: caCertPool,
			},
		}
	} else {
		// For development/testing - skip certificate verification
		log.Printf("Warning: OpenShift provider configured without CA bundle - skipping certificate verification")
		httpClient.Transport = &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true,
			},
		}
	}

	return &OpenShiftProvider{
		config:       config,
		oauth2Config: oauth2Config,
		httpClient:   httpClient,
		baseURL:      baseURL,
	}, nil
}

// GetLoginURL returns the URL to redirect users for authentication
func (p *OpenShiftProvider) GetLoginURL(state, redirectURL string) string {
	return p.oauth2Config.AuthCodeURL(state)
}

// HandleCallback processes the authentication callback and returns user info
func (p *OpenShiftProvider) HandleCallback(w http.ResponseWriter, r *http.Request) (*UserInfo, error) {
	// Exchange authorization code for tokens
	code := r.URL.Query().Get("code")
	token, err := p.oauth2Config.Exchange(r.Context(), code)
	if err != nil {
		return nil, fmt.Errorf("failed to exchange code: %w", err)
	}

	// Get user info from OpenShift API
	userInfo, err := p.getUserInfo(token.AccessToken)
	if err != nil {
		return nil, fmt.Errorf("failed to get user info: %w", err)
	}

	// Store the access token in a secure cookie
	http.SetCookie(w, &http.Cookie{
		Name:     "auth_token",
		Value:    token.AccessToken,
		Path:     "/",
		HttpOnly: true,
		Secure:   r.TLS != nil,
		MaxAge:   3600, // 1 hour
	})

	return userInfo, nil
}

// ValidateToken validates a token and returns user info
func (p *OpenShiftProvider) ValidateToken(tokenString string) (*UserInfo, error) {
	return p.getUserInfo(tokenString)
}

// GetLogoutURL returns the URL for logging out
func (p *OpenShiftProvider) GetLogoutURL(redirectURL string) string {
	// OpenShift supports logout endpoint
	logoutURL := strings.TrimSuffix(p.config.ClusterURL, "/") + "/oauth/logout"
	if redirectURL != "" {
		logoutURL += "?redirect_uri=" + url.QueryEscape(redirectURL)
	}
	return logoutURL
}

// IsEnabled returns whether this provider is enabled
func (p *OpenShiftProvider) IsEnabled() bool {
	if p.config.ServiceAccount {
		// In service account mode, only cluster URL is required (auto-configured)
		return p.config.ClusterURL != ""
	}
	// In manual mode, all three are required
	return p.config.ClusterURL != "" && p.config.ClientID != "" && p.config.ClientSecret != ""
}

// Name returns the provider name
func (p *OpenShiftProvider) Name() string {
	return "openshift"
}

// getUserInfo fetches user information from OpenShift API using access token
func (p *OpenShiftProvider) getUserInfo(accessToken string) (*UserInfo, error) {
	// Get user info from OpenShift API
	userURL := strings.TrimSuffix(p.config.ClusterURL, "/") + "/apis/user.openshift.io/v1/users/~"

	req, err := http.NewRequest("GET", userURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Accept", "application/json")

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Parse user info response
	var osUser OpenShiftUserInfo
	if err := json.NewDecoder(resp.Body).Decode(&osUser); err != nil {
		return nil, fmt.Errorf("failed to decode user info: %w", err)
	}

	// Get user's groups
	groups, err := p.getUserGroups(accessToken, osUser.Metadata.Name)
	if err != nil {
		log.Printf("Warning: failed to get user groups: %v", err)
		// Continue without groups rather than failing
	}

	return &UserInfo{
		Username: osUser.Metadata.Name,
		Email:    "", // OpenShift doesn't always provide email in user info
		Groups:   groups,
		Sub:      osUser.Metadata.UID,
	}, nil
}

// getUserGroups fetches user's group memberships from OpenShift API
func (p *OpenShiftProvider) getUserGroups(accessToken, username string) ([]string, error) {
	// Get groups from OpenShift API - we need to list all groups and filter by user
	groupsURL := strings.TrimSuffix(p.config.ClusterURL, "/") + "/apis/user.openshift.io/v1/groups"

	req, err := http.NewRequest("GET", groupsURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Accept", "application/json")

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("groups API request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Parse groups response
	var groupsResponse struct {
		Items []struct {
			Metadata struct {
				Name string `json:"name"`
			} `json:"metadata"`
			Users []string `json:"users"`
		} `json:"items"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&groupsResponse); err != nil {
		return nil, fmt.Errorf("failed to decode groups: %w", err)
	}

	// Filter groups that contain the user
	var userGroups []string
	for _, group := range groupsResponse.Items {
		for _, user := range group.Users {
			if user == username {
				userGroups = append(userGroups, group.Metadata.Name)
				break
			}
		}
	}

	return userGroups, nil
}

// autoConfigureServiceAccount configures OpenShift OAuth using service account credentials
func autoConfigureServiceAccount(config *config.OpenShiftProviderConfig) error {
	// Get service account namespace
	namespace := os.Getenv("POD_NAMESPACE")
	if namespace == "" {
		namespace = "default"
		if nsBytes, err := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/namespace"); err == nil {
			namespace = strings.TrimSpace(string(nsBytes))
		}
	}

	// Get service account name from environment variable
	serviceAccount := os.Getenv("OPENSHIFT_SERVICE_ACCOUNT")
	if serviceAccount == "" {
		return fmt.Errorf("service account name not found in OPENSHIFT_SERVICE_ACCOUNT environment variable")
	}

	// Auto-configure OAuth client credentials
	config.ClientID = fmt.Sprintf("system:serviceaccount:%s:%s", namespace, serviceAccount)
	
	// Read service account token
	tokenBytes, err := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/token")
	if err != nil {
		return fmt.Errorf("failed to read service account token: %w", err)
	}
	config.ClientSecret = strings.TrimSpace(string(tokenBytes))

	// Auto-configure cluster URL if not provided
	if config.ClusterURL == "" {
		kubeHost := os.Getenv("KUBERNETES_SERVICE_HOST")
		kubePort := os.Getenv("KUBERNETES_SERVICE_PORT_HTTPS")
		if kubePort == "" {
			kubePort = os.Getenv("KUBERNETES_SERVICE_PORT")
		}
		if kubePort == "" {
			kubePort = "443"
		}
		if kubeHost != "" {
			config.ClusterURL = fmt.Sprintf("https://%s:%s", kubeHost, kubePort)
		} else {
			config.ClusterURL = "https://kubernetes.default.svc.cluster.local"
		}
	}

	// Auto-configure CA bundle if not provided
	if config.CABundle == "" {
		if caBytes, err := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"); err == nil {
			config.CABundle = string(caBytes)
		}
	}

	log.Printf("Auto-configured OpenShift provider with service account: %s", config.ClientID)
	return nil
}

// discoverOAuthEndpoints discovers OpenShift OAuth endpoints using the well-known endpoint
func discoverOAuthEndpoints(clusterURL string) (string, string, error) {
	// Use well-known OAuth authorization server endpoint
	wellKnownURL := strings.TrimSuffix(clusterURL, "/") + "/.well-known/oauth-authorization-server"
	
	// Create HTTP client that skips certificate verification for discovery
	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true,
			},
		},
	}

	resp, err := client.Get(wellKnownURL)
	if err != nil {
		return "", "", fmt.Errorf("failed to fetch OAuth discovery: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("OAuth discovery returned status %d", resp.StatusCode)
	}

	var discovery struct {
		AuthorizationEndpoint string `json:"authorization_endpoint"`
		TokenEndpoint         string `json:"token_endpoint"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&discovery); err != nil {
		return "", "", fmt.Errorf("failed to decode OAuth discovery: %w", err)
	}

	if discovery.AuthorizationEndpoint == "" || discovery.TokenEndpoint == "" {
		return "", "", fmt.Errorf("OAuth endpoints not found in discovery response")
	}

	return discovery.AuthorizationEndpoint, discovery.TokenEndpoint, nil
}
