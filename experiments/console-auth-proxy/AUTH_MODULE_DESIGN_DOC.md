# OpenShift Console Authentication Module Design Document

## Overview

The OpenShift Console Authentication module (`src/console/pkg/auth`) is a sophisticated authentication proxy system that provides secure authentication and session management for the OpenShift Web Console. It acts as an intermediary between users and the Kubernetes/OpenShift APIs, handling OAuth2/OIDC authentication flows, session lifecycle management, token validation, and security enforcement.

## Architecture

The authentication module follows a layered, pluggable architecture with clean separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    HTTP Handlers Layer                      │
├─────────────────────────────────────────────────────────────┤
│                  Authenticator Interface                    │  
├─────────────────────────────────────────────────────────────┤
│    OAuth2 Auth    │    Static Auth    │   Future Auth       │
│   (OpenShift/OIDC)│   (Development)   │   (Extensions)      │
├─────────────────────────────────────────────────────────────┤
│              Session Management Layer                       │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │  Server Store   │  │  Client Store   │                  │
│  │  (In-Memory)    │  │  (Cookies)      │                  │
│  └─────────────────┘  └─────────────────┘                  │
├─────────────────────────────────────────────────────────────┤
│              Security & Validation Layer                    │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │  CSRF Verifier  │  │ Token Reviewer  │                  │
│  └─────────────────┘  └─────────────────┘                  │
├─────────────────────────────────────────────────────────────┤
│                    Metrics & Monitoring                     │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Authenticator Interface (`types.go`)

The central abstraction that defines the authentication contract:

```go
type Authenticator interface {
    Authenticate(w http.ResponseWriter, req *http.Request) (*User, error)
    LoginFunc(w http.ResponseWriter, req *http.Request)
    LogoutFunc(w http.ResponseWriter, req *http.Request)
    CallbackFunc(fn func(loginInfo sessions.LoginJSON, successURL string, w http.ResponseWriter)) func(w http.ResponseWriter, req *http.Request)
    GetOCLoginCommand() string
    LogoutRedirectURL() string
    GetSpecialURLs() SpecialAuthURLs
    IsStatic() bool
}
```

This interface enables pluggable authentication backends while maintaining consistent behavior.

### 2. OAuth2 Authentication System (`oauth2/`)

The primary authentication implementation supporting both OpenShift OAuth and generic OIDC providers.

#### OAuth2Authenticator (`oauth2/auth.go`)
- **Purpose**: Core OAuth2 flow orchestration
- **Key Features**:
  - OAuth2 authorization code flow implementation
  - State management with cryptographically secure random states
  - HTTP client caching with CA certificate support
  - Configurable scopes and endpoints
  - Integration with both OpenShift and OIDC backends

#### OpenShift Authentication (`oauth2/auth_openshift.go`)
- **Purpose**: OpenShift-specific OAuth integration
- **Key Features**:
  - OpenShift OAuth metadata discovery
  - Integration with OpenShift's built-in OAuth server
  - Support for OpenShift-specific user attributes
  - Kubernetes API integration for token validation

#### OIDC Authentication (`oauth2/auth_oidc.go`)
- **Purpose**: Generic OIDC provider support
- **Key Features**:
  - OIDC Discovery support
  - ID token verification and claims extraction
  - Refresh token handling with race condition protection
  - Configurable OIDC provider endpoints

### 3. Session Management System (`sessions/`)

A sophisticated dual-store session management system ensuring both security and scalability.

#### Combined Session Store (`sessions/combined_sessions.go`)
- **Architecture**: Hybrid storage combining server-side and client-side stores
- **Server Store**: In-memory storage for sensitive session data
- **Client Store**: Encrypted HTTP-only cookies for session tokens
- **Benefits**:
  - Sensitive data never leaves server memory
  - Scalable through stateless cookie distribution
  - Protection against session hijacking

#### Login State Management (`sessions/loginstate.go`)
- **Purpose**: Manages user session lifecycle and token rotation
- **Key Features**:
  - Token expiration tracking with 80% rotation threshold
  - User identity extraction from ID tokens
  - Secure session token generation
  - Token refresh coordination

### 4. Security Layer

#### CSRF Protection (`csrfverifier/csrf.go`)
- **Double Submit Cookie Pattern**: Generates random CSRF tokens stored in cookies and validated via headers
- **Origin Validation**: Verifies request origin for WebSocket upgrades
- **HTTP Method Filtering**: Automatically exempts safe HTTP methods
- **WebSocket Support**: Special handling for WebSocket upgrade requests

#### Token Validation (`tokenreviewer.go`)
- **Purpose**: Validates bearer tokens against Kubernetes TokenReview API
- **Integration**: Uses Kubernetes client-go for token verification
- **Security**: Ensures tokens are valid and authenticated before proxying requests

### 5. Static Authentication (`static/auth.go`)

A development-focused authenticator that bypasses OAuth flows:
- **Use Case**: Local development and testing
- **Behavior**: Returns pre-configured user without authentication
- **Security**: Only suitable for development environments

### 6. Metrics and Monitoring (`metrics.go`)

Comprehensive authentication metrics using Prometheus:

- **Login Metrics**:
  - `login_requests_total`: Total login attempts
  - `login_successful_total`: Successful logins by user role
  - `login_failures_total`: Failed login attempts by reason
  
- **Session Metrics**:
  - `logout_requests_total`: Logout requests by reason
  - `token_refresh_requests_total`: Token refresh attempts by handling type
  
- **User Role Detection**: Automatic classification of users as kubeadmin, cluster-admin, developer, or unknown

## Authentication Flows

### 1. OAuth2 Authorization Code Flow

```
┌─────────┐    ┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│ Browser │    │   Console   │    │    OAuth     │    │ Kubernetes  │
│         │    │   Backend   │    │   Provider   │    │     API     │
└─────────┘    └─────────────┘    └──────────────┘    └─────────────┘
     │                │                    │                  │
     │ 1. Access App  │                    │                  │
     ├───────────────>│                    │                  │
     │                │                    │                  │
     │ 2. Redirect    │                    │                  │
     │    to OAuth    │                    │                  │
     │<───────────────┤                    │                  │
     │                │                    │                  │
     │ 3. Auth Request│                    │                  │
     ├─────────────────────────────────────>│                  │
     │                │                    │                  │
     │ 4. User Login  │                    │                  │
     │<─────────────────────────────────────┤                  │
     │                │                    │                  │
     │ 5. Auth Code   │                    │                  │
     ├───────────────>│                    │                  │
     │                │ 6. Token Exchange  │                  │
     │                ├───────────────────>│                  │
     │                │                    │                  │
     │                │ 7. Access Token    │                  │
     │                │<───────────────────┤                  │
     │                │                    │                  │
     │                │ 8. Validate Token  │                  │
     │                ├─────────────────────────────────────>│
     │                │                    │                  │
     │                │ 9. Token Info      │                  │
     │                │<─────────────────────────────────────┤
     │                │                    │                  │
     │ 10. Set Cookie │                    │                  │
     │    & Redirect  │                    │                  │
     │<───────────────┤                    │                  │
```

### 2. Session Refresh Flow

```
┌─────────┐    ┌─────────────┐    ┌──────────────┐
│ Browser │    │   Console   │    │    OAuth     │
│         │    │   Backend   │    │   Provider   │
└─────────┘    └─────────────┘    └──────────────┘
     │                │                    │
     │ 1. API Request │                    │
     │   (Expired)    │                    │
     ├───────────────>│                    │
     │                │                    │
     │                │ 2. Token Refresh   │
     │                ├───────────────────>│
     │                │                    │
     │                │ 3. New Tokens      │
     │                │<───────────────────┤
     │                │                    │
     │ 4. Updated     │                    │
     │    Session     │                    │
     │<───────────────┤                    │
```

## Session Management Strategy

### Dual-Store Architecture

1. **Server Store (In-Memory)**:
   - Stores `LoginState` objects with sensitive data
   - Indexed by session tokens
   - Automatic cleanup of expired sessions
   - Race condition protection for token refresh

2. **Client Store (HTTP Cookies)**:
   - Stores encrypted session and refresh token references
   - HttpOnly, Secure, SameSite=Strict flags
   - Path-scoped for security
   - Automatic expiration handling

### Session Lifecycle

1. **Creation**: 
   - Generate cryptographically secure session token
   - Store user identity and tokens in server store
   - Set encrypted cookies with session references

2. **Validation**:
   - Extract session token from cookie
   - Lookup session in server store
   - Validate token expiration
   - Return user identity for authenticated requests

3. **Refresh**:
   - Detect tokens approaching expiration (80% threshold)
   - Use refresh token to obtain new access tokens
   - Update session state atomically
   - Synchronize across multiple backend instances

4. **Cleanup**:
   - Automatic removal of expired sessions
   - Logout-triggered session deletion
   - Memory management for server store

## Security Features

### 1. Cross-Site Request Forgery (CSRF) Protection
- **Double Submit Cookie**: Random token in cookie + header
- **Origin Validation**: Strict origin checking for WebSocket upgrades
- **Constant-Time Comparison**: Prevents timing attacks
- **Method Exemption**: Safe HTTP methods bypass CSRF checks

### 2. Token Security
- **Bearer Token Validation**: All tokens validated against Kubernetes API
- **Secure Cookie Handling**: HttpOnly, Secure, SameSite flags
- **Token Rotation**: Proactive token refresh before expiration
- **Session Isolation**: Pod-specific session cookies prevent cross-pod attacks

### 3. Transport Security
- **TLS Configuration**: Secure TLS configuration with custom CA support
- **HTTP Client Caching**: Efficient CA certificate validation
- **Certificate Verification**: Proper certificate chain validation

## Configuration Options

### OAuth2 Configuration
```go
type Config struct {
    AuthSource             AuthSource  // OpenShift or OIDC
    IssuerURL              string      // OAuth provider URL
    LogoutRedirectOverride string      // Custom logout redirect
    IssuerCA               string      // CA certificate path
    RedirectURL            string      // OAuth callback URL
    ClientID               string      // OAuth client ID
    ClientSecret           string      // OAuth client secret
    Scope                  []string    // OAuth scopes
    K8sCA                  string      // Kubernetes API CA
    SuccessURL             string      // Post-login redirect
    ErrorURL               string      // Error page URL
    CookiePath             string      // Cookie path scope
    SecureCookies          bool        // HTTPS-only cookies
    CookieEncryptionKey    []byte      // Cookie encryption key
    CookieAuthenticationKey []byte     // Cookie authentication key
    K8sConfig              *rest.Config // Kubernetes client config
    OCLoginCommand         string      // CLI login command display
}
```

## Integration Points

### 1. HTTP Middleware Integration
The authentication module integrates as HTTP middleware in the console server:
```go
func WithAuthentication(authenticator auth.Authenticator) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            user, err := authenticator.Authenticate(w, r)
            if err != nil {
                // Handle authentication failure
                return
            }
            // Add user context and continue
            ctx := context.WithValue(r.Context(), "user", user)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

### 2. Kubernetes API Proxy
Authenticated user tokens are used to proxy requests to the Kubernetes API:
```go
func (p *Proxy) Handle(user *auth.User, w http.ResponseWriter, r *http.Request) {
    // Add user's bearer token to proxied request
    r.Header.Set("Authorization", "Bearer "+user.Token)
    p.reverseProxy.ServeHTTP(w, r)
}
```

### 3. Metrics Integration
Authentication metrics integrate with Prometheus for monitoring:
- Login success/failure rates
- User role distribution
- Token refresh patterns
- Session lifecycle events

## Key Design Principles

1. **Security First**: Multiple layers of security with defense in depth
2. **Pluggable Architecture**: Clean interfaces allowing future authentication methods
3. **Scalability**: Stateless design with minimal server-side session storage
4. **Observability**: Comprehensive metrics and logging for operational visibility
5. **Standards Compliance**: Full OAuth2/OIDC specification compliance
6. **Development Friendly**: Static authenticator for local development workflows

## Performance Considerations

1. **HTTP Client Caching**: Cached HTTP clients reduce TLS handshake overhead
2. **Async Cache**: Background refresh of OIDC discovery reduces latency
3. **Token Rotation**: Proactive token refresh prevents request failures
4. **Session Cleanup**: Automatic cleanup prevents memory leaks
5. **Refresh Lock**: Prevents thundering herd during token refresh

## Future Extensions

The modular design supports future enhancements:
- **Multi-factor Authentication**: Additional verification steps
- **External Identity Providers**: SAML, LDAP, or custom integrations
- **Session Persistence**: External session stores for true statelessness
- **Audit Logging**: Enhanced security event logging
- **Policy Integration**: Fine-grained access control policies

This authentication module provides a robust, secure, and scalable foundation for the OpenShift Console's authentication and authorization needs while maintaining flexibility for future requirements.