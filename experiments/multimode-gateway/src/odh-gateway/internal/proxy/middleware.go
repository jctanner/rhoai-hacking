package proxy

import (
	"crypto/rand"
	"encoding/base64"
	"log"
	"net/http"
	"strings"

	"github.com/jctanner/odh-gateway/internal/proxy/providers"
)

// generateRandomString generates a random string of the specified length
func generateRandomString(length int) (string, error) {
	bytes := make([]byte, length)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(bytes)[:length], nil
}

// AuthMiddleware handles authentication using providers
type AuthMiddleware struct {
	provider providers.AuthProvider
}

// NewAuthMiddleware creates a new auth middleware
func NewAuthMiddleware(provider providers.AuthProvider) *AuthMiddleware {
	return &AuthMiddleware{
		provider: provider,
	}
}

// Middleware returns an HTTP middleware that handles authentication
func (m *AuthMiddleware) Middleware(authRequired *bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Determine if auth is required for this route
			requireAuth := false
			if authRequired != nil {
				requireAuth = *authRequired
			}

			// Skip auth if not required or provider not enabled
			if !requireAuth || !m.provider.IsEnabled() {
				next.ServeHTTP(w, r)
				return
			}

			// Check for existing valid session and inject user headers
			if userInfo := m.validateRequest(r); userInfo != nil {
				// Inject user context headers for downstream services
				r.Header.Set("X-Forwarded-User", userInfo.Username)
				if len(userInfo.Groups) > 0 {
					r.Header.Set("X-Forwarded-Groups", strings.Join(userInfo.Groups, ","))
				}

				log.Printf("Authenticated user: %s, groups: %v", userInfo.Username, userInfo.Groups)
				next.ServeHTTP(w, r)
				return
			}

			// Redirect to authentication provider
			m.redirectToAuth(w, r)
		})
	}
}

// validateRequest checks for valid authentication and returns user info
func (m *AuthMiddleware) validateRequest(r *http.Request) *providers.UserInfo {
	// Try to get token from cookie first, then Authorization header
	var tokenString string

	// Check auth cookie
	if cookie, err := r.Cookie("auth_token"); err == nil {
		tokenString = cookie.Value
	} else {
		// Check Authorization header
		authHeader := r.Header.Get("Authorization")
		if strings.HasPrefix(authHeader, "Bearer ") {
			tokenString = strings.TrimPrefix(authHeader, "Bearer ")
		}
	}

	if tokenString == "" {
		return nil
	}

	// Validate token with provider
	userInfo, err := m.provider.ValidateToken(tokenString)
	if err != nil {
		log.Printf("Token validation failed: %v", err)
		return nil
	}

	return userInfo
}

// redirectToAuth redirects the user to the authentication provider
func (m *AuthMiddleware) redirectToAuth(w http.ResponseWriter, r *http.Request) {
	// Generate state parameter for CSRF protection
	state, err := generateRandomString(32)
	if err != nil {
		log.Printf("Failed to generate state: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	// Store the original URL and state in cookies
	http.SetCookie(w, &http.Cookie{
		Name:     "auth_state",
		Value:    state,
		Path:     "/",
		HttpOnly: true,
		Secure:   r.TLS != nil,
		MaxAge:   300, // 5 minutes
	})

	http.SetCookie(w, &http.Cookie{
		Name:     "auth_redirect",
		Value:    r.URL.String(),
		Path:     "/",
		HttpOnly: true,
		Secure:   r.TLS != nil,
		MaxAge:   300, // 5 minutes
	})

	// Get login URL from provider
	loginURL := m.provider.GetLoginURL(state, r.URL.String())
	http.Redirect(w, r, loginURL, http.StatusFound)
}

// HandleCallback handles the authentication callback
func (m *AuthMiddleware) HandleCallback() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify state parameter
		stateCookie, err := r.Cookie("auth_state")
		if err != nil || stateCookie.Value != r.URL.Query().Get("state") {
			log.Printf("Invalid state parameter")
			http.Error(w, "Invalid state parameter", http.StatusBadRequest)
			return
		}

		// Process callback with provider
		userInfo, err := m.provider.HandleCallback(w, r)
		if err != nil {
			log.Printf("Callback processing failed: %v", err)
			http.Error(w, "Authentication failed", http.StatusInternalServerError)
			return
		}

		log.Printf("User authenticated: %s", userInfo.Username)

		// Get original redirect URL
		redirectCookie, err := r.Cookie("auth_redirect")
		redirectURL := "/"
		if err == nil {
			redirectURL = redirectCookie.Value
		}

		// Clear temporary cookies
		http.SetCookie(w, &http.Cookie{
			Name:   "auth_state",
			Value:  "",
			Path:   "/",
			MaxAge: -1,
		})
		http.SetCookie(w, &http.Cookie{
			Name:   "auth_redirect",
			Value:  "",
			Path:   "/",
			MaxAge: -1,
		})

		// Redirect to original URL
		http.Redirect(w, r, redirectURL, http.StatusFound)
	})
}

// HandleLogout handles user logout
func (m *AuthMiddleware) HandleLogout() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Clear auth cookie
		http.SetCookie(w, &http.Cookie{
			Name:   "auth_token",
			Value:  "",
			Path:   "/",
			MaxAge: -1,
		})

		// Get logout URL from provider
		logoutURL := m.provider.GetLogoutURL(r.URL.Query().Get("redirect_uri"))
		if logoutURL != "" {
			http.Redirect(w, r, logoutURL, http.StatusFound)
		} else {
			// Simple logout response
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Logged out successfully"))
		}
	})
}

// HandleLogin provides a direct login endpoint
func (m *AuthMiddleware) HandleLogin() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Generate state parameter
		state, err := generateRandomString(32)
		if err != nil {
			log.Printf("Failed to generate state: %v", err)
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}

		// Store state in cookie
		http.SetCookie(w, &http.Cookie{
			Name:     "auth_state",
			Value:    state,
			Path:     "/",
			HttpOnly: true,
			Secure:   r.TLS != nil,
			MaxAge:   300, // 5 minutes
		})

		// Store redirect URL from query parameter
		redirectURL := r.URL.Query().Get("redirect_uri")
		if redirectURL == "" {
			redirectURL = "/"
		}

		http.SetCookie(w, &http.Cookie{
			Name:     "auth_redirect",
			Value:    redirectURL,
			Path:     "/",
			HttpOnly: true,
			Secure:   r.TLS != nil,
			MaxAge:   300, // 5 minutes
		})

		// Redirect to provider login
		loginURL := m.provider.GetLoginURL(state, redirectURL)
		http.Redirect(w, r, loginURL, http.StatusFound)
	})
}
