# Console Auth Proxy Design Document

## Project Overview

The Console Auth Proxy is a standalone authentication reverse proxy service that extracts and reuses the mature authentication module from the OpenShift Console project. This service provides enterprise-grade OAuth2/OIDC authentication and session management for applications that need to integrate with OpenShift or generic OIDC providers.

## Goals and Objectives

### Primary Goals
1. **Reuse Proven Code**: Leverage the battle-tested authentication implementation from OpenShift Console without modification
2. **Standalone Service**: Create an independent reverse proxy that can protect any backend application
3. **Minimal Changes**: Preserve the original `pkg/auth` code unchanged to maintain compatibility and security guarantees
4. **Dependency Preservation**: Maintain the same Go module dependencies as the console project where possible
5. **Production Ready**: Inherit the production-grade features like metrics, logging, and security from the original implementation

### Secondary Goals
1. **Cloud Native**: Design for containerized deployment with Kubernetes integration
2. **Configuration Driven**: Support flexible configuration for different deployment scenarios
3. **Observability**: Maintain comprehensive metrics and logging capabilities
4. **Extensibility**: Allow for future enhancements while preserving the core auth module

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Console Auth Proxy                           │
├─────────────────────────────────────────────────────────────────┤
│                     HTTP Router & Middleware                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Auth Routes   │  │  Health Routes  │  │  Metrics Routes │  │
│  │  /auth/login    │  │   /healthz      │  │   /metrics      │  │
│  │  /auth/logout   │  │   /readyz       │  │                 │  │
│  │  /auth/callback │  │                 │  │                 │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    Authentication Middleware                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                pkg/auth (Unmodified)                        │ │
│  │  ┌─────────────────┐  ┌─────────────────┐                  │ │
│  │  │   OAuth2 Auth   │  │   Session Mgmt  │                  │ │
│  │  │ (OpenShift/OIDC)│  │  (Dual Store)   │                  │ │
│  │  └─────────────────┘  └─────────────────┘                  │ │
│  │  ┌─────────────────┐  ┌─────────────────┐                  │ │
│  │  │  CSRF Verifier  │  │ Token Reviewer  │                  │ │
│  │  └─────────────────┘  └─────────────────┘                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                     Reverse Proxy Layer                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  httputil.ReverseProxy with User Context Injection         │ │
│  │  - Adds Authorization headers                               │ │
│  │  - Injects user identity headers                            │ │
│  │  - Handles backend connection management                    │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend Application                          │
│                (Any HTTP service)                               │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Strategy

### Phase 1: Extract and Preserve
1. **Copy `pkg/auth` Verbatim**: Copy the entire authentication package structure without any modifications
2. **Preserve Dependencies**: Import the relevant sections of `go.mod` from the console project
3. **Minimal Wrapper**: Create a thin wrapper that initializes the auth module with configuration
4. **Basic Proxy**: Implement a simple reverse proxy that uses the auth module for protection

### Phase 2: Integration and Enhancement  
1. **Configuration System**: Implement comprehensive configuration management
2. **Health Checks**: Add readiness and liveness probes for Kubernetes deployment
3. **Metrics Enhancement**: Ensure all auth metrics are properly exposed
4. **Proxy Features**: Add advanced proxy features like header injection and backend selection

### Phase 3: Production Readiness
1. **Container Images**: Create optimized container images for deployment
2. **Helm Charts**: Provide Kubernetes deployment manifests
3. **Documentation**: Comprehensive deployment and configuration documentation
4. **Testing**: Integration tests with various OIDC providers

## Project Structure

```
console-auth-proxy/
├── cmd/
│   └── console-auth-proxy/
│       └── main.go                    # Application entry point
├── internal/
│   ├── config/
│   │   ├── config.go                  # Configuration management
│   │   └── validation.go              # Config validation
│   ├── proxy/
│   │   ├── proxy.go                   # Reverse proxy implementation
│   │   ├── middleware.go              # HTTP middleware
│   │   └── headers.go                 # Header manipulation
│   ├── server/
│   │   ├── server.go                  # HTTP server setup
│   │   ├── routes.go                  # Route definitions
│   │   └── handlers.go                # HTTP handlers
│   └── version/
│       └── version.go                 # Version information
├── pkg/
│   └── auth/                          # Copied verbatim from console
│       ├── oauth2/
│       ├── sessions/
│       ├── csrfverifier/
│       ├── static/
│       ├── types.go
│       ├── tokenreviewer.go
│       └── metrics.go
├── deployments/
│   ├── kubernetes/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── rbac.yaml
│   └── helm/
│       └── console-auth-proxy/
├── configs/
│   ├── dev.yaml
│   ├── production.yaml
│   └── openshift.yaml
├── scripts/
│   ├── build.sh
│   ├── test.sh
│   └── docker-build.sh
├── go.mod                             # Dependencies from console + additions
├── go.sum
├── Dockerfile
├── README.md
└── LICENSE
```

## Dependency Management Strategy

### Preserve Console Dependencies
```go
// Key dependencies to preserve from console go.mod:
module github.com/your-org/console-auth-proxy

go 1.23.6

require (
    // Auth-related dependencies from console
    github.com/coreos/go-oidc v2.3.0+incompatible
    github.com/coreos/pkg v0.0.0-20240122114842-bbd7aa9bf6fb
    github.com/gorilla/securecookie v1.1.2
    github.com/gorilla/sessions v1.4.0
    github.com/gorilla/websocket v1.5.3
    github.com/openshift/api v3.9.0+incompatible
    github.com/openshift/client-go v0.0.0-20230926161409-848405da69e1
    github.com/openshift/library-go v0.0.0-20231020125034-5a2d9fe760b3
    github.com/prometheus/client_golang v1.22.0
    github.com/prometheus/common v0.63.0
    golang.org/x/oauth2 v0.X.X
    k8s.io/client-go v0.X.X
    k8s.io/klog/v2 v2.X.X
    
    // Additional dependencies for proxy functionality
    gopkg.in/yaml.v3 v3.0.1              // Configuration
    github.com/spf13/cobra v1.8.0         // CLI
    github.com/spf13/viper v1.18.2        // Configuration management
)
```

### Dependency Isolation Strategy
1. **Vendor Directory**: Consider using Go modules with vendoring for reproducible builds
2. **Version Pinning**: Pin to exact versions used in the console project
3. **Selective Import**: Only import the minimal set of dependencies required by `pkg/auth`
4. **Regular Updates**: Establish a process to sync with console dependency updates

## Configuration System

### Configuration Structure
```go
type Config struct {
    // Server configuration
    Server ServerConfig `yaml:"server"`
    
    // Auth configuration (maps directly to console auth.Config)
    Auth AuthConfig `yaml:"auth"`
    
    // Proxy configuration
    Proxy ProxyConfig `yaml:"proxy"`
    
    // Logging and metrics
    Observability ObservabilityConfig `yaml:"observability"`
}

type AuthConfig struct {
    // Direct mapping to console pkg/auth Config
    AuthSource             string   `yaml:"authSource"`             // "openshift" or "oidc"
    IssuerURL              string   `yaml:"issuerURL"`
    LogoutRedirectOverride string   `yaml:"logoutRedirectOverride"`
    IssuerCA               string   `yaml:"issuerCA"`
    RedirectURL            string   `yaml:"redirectURL"`
    ClientID               string   `yaml:"clientID"`
    ClientSecret           string   `yaml:"clientSecret"`
    Scope                  []string `yaml:"scope"`
    K8sCA                  string   `yaml:"k8sCA"`
    SuccessURL             string   `yaml:"successURL"`
    ErrorURL               string   `yaml:"errorURL"`
    CookiePath             string   `yaml:"cookiePath"`
    SecureCookies          bool     `yaml:"secureCookies"`
    OCLoginCommand         string   `yaml:"ocLoginCommand"`
}

type ProxyConfig struct {
    Backend    BackendConfig    `yaml:"backend"`
    Headers    HeaderConfig     `yaml:"headers"`
    Timeouts   TimeoutConfig    `yaml:"timeouts"`
}
```

### Configuration Sources
1. **YAML Files**: Primary configuration method
2. **Environment Variables**: Override for containerized deployments
3. **Command Line Flags**: Development and testing overrides
4. **Kubernetes ConfigMaps/Secrets**: Cloud-native configuration

## Integration with pkg/auth

### Wrapper Implementation
```go
package main

import (
    "context"
    "net/http"
    
    "github.com/your-org/console-auth-proxy/pkg/auth"
    "github.com/your-org/console-auth-proxy/pkg/auth/oauth2"
    "github.com/your-org/console-auth-proxy/internal/config"
    "github.com/your-org/console-auth-proxy/internal/proxy"
)

func main() {
    cfg := config.Load()
    
    // Initialize auth exactly as console does
    authConfig := &oauth2.Config{
        AuthSource:               cfg.Auth.AuthSource,
        IssuerURL:                cfg.Auth.IssuerURL,
        LogoutRedirectOverride:   cfg.Auth.LogoutRedirectOverride,
        IssuerCA:                 cfg.Auth.IssuerCA,
        RedirectURL:              cfg.Auth.RedirectURL,
        ClientID:                 cfg.Auth.ClientID,
        ClientSecret:             cfg.Auth.ClientSecret,
        Scope:                    cfg.Auth.Scope,
        // ... other config mapping
    }
    
    authenticator, err := oauth2.NewOAuth2Authenticator(context.Background(), authConfig)
    if err != nil {
        panic(err)
    }
    
    // Create proxy with auth protection
    proxyHandler := proxy.NewAuthenticatedProxy(cfg.Proxy, authenticator)
    
    // Setup routes exactly as console does
    mux := http.NewServeMux()
    mux.HandleFunc("/auth/login", authenticator.LoginFunc)
    mux.HandleFunc("/auth/logout", authenticator.LogoutFunc)
    mux.HandleFunc("/auth/callback", authenticator.CallbackFunc(handleAuthCallback))
    mux.Handle("/", proxyHandler)
    
    server := &http.Server{
        Addr:    cfg.Server.Address,
        Handler: mux,
    }
    
    server.ListenAndServe()
}
```

### Zero-Modification Principle
- **No changes to `pkg/auth`**: Preserve all files exactly as they exist in console
- **Interface compliance**: Use the exact same interfaces and data structures
- **Configuration compatibility**: Support all configuration options from console
- **Behavior preservation**: Maintain identical authentication behavior

## Reverse Proxy Implementation

### Core Proxy Logic
```go
type AuthenticatedProxy struct {
    proxy         *httputil.ReverseProxy
    authenticator auth.Authenticator
    config        ProxyConfig
}

func (ap *AuthenticatedProxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // Authenticate request using unmodified pkg/auth
    user, err := ap.authenticator.Authenticate(w, r)
    if err != nil {
        // Redirect to login if not authenticated
        ap.redirectToLogin(w, r)
        return
    }
    
    // Inject user context and headers for backend
    ap.injectUserContext(r, user)
    
    // Proxy to backend
    ap.proxy.ServeHTTP(w, r)
}

func (ap *AuthenticatedProxy) injectUserContext(r *http.Request, user *auth.User) {
    // Add authorization header for backend
    r.Header.Set("Authorization", "Bearer "+user.Token)
    
    // Add user identity headers
    r.Header.Set("X-Forwarded-User", user.Username)
    r.Header.Set("X-Forwarded-User-ID", user.ID)
    
    // Add any custom headers from configuration
    for key, value := range ap.config.Headers.Custom {
        r.Header.Set(key, value)
    }
}
```

### Backend Integration Features
1. **Header Injection**: Automatically add user identity and authorization headers
2. **Backend Discovery**: Support multiple backend selection strategies
3. **Health Checks**: Monitor backend availability
4. **Load Balancing**: Optional load balancing across multiple backends
5. **TLS Termination**: Handle TLS for both client and backend connections

## Deployment Strategy

### Container Image
```dockerfile
FROM golang:1.23-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o console-auth-proxy ./cmd/console-auth-proxy

FROM alpine:latest
RUN apk --no-cache add ca-certificates
COPY --from=builder /src/console-auth-proxy /usr/local/bin/
ENTRYPOINT ["console-auth-proxy"]
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: console-auth-proxy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: console-auth-proxy
  template:
    metadata:
      labels:
        app: console-auth-proxy
    spec:
      containers:
      - name: console-auth-proxy
        image: console-auth-proxy:latest
        ports:
        - containerPort: 8080
        env:
        - name: CONFIG_FILE
          value: /etc/config/config.yaml
        volumeMounts:
        - name: config
          mountPath: /etc/config
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8080
      volumes:
      - name: config
        configMap:
          name: console-auth-proxy-config
```

## Security Considerations

### Inherited Security Features
- **OAuth2/OIDC Compliance**: Full standards compliance from console implementation
- **CSRF Protection**: Double-submit cookie pattern
- **Session Security**: Secure session management with encrypted cookies
- **Token Validation**: Kubernetes TokenReview integration
- **Transport Security**: TLS configuration and certificate validation

### Additional Security Measures
1. **Network Policies**: Restrict network access in Kubernetes
2. **RBAC**: Minimal service account permissions
3. **Secret Management**: Secure handling of OAuth client secrets
4. **Audit Logging**: Security event logging for compliance
5. **Rate Limiting**: Protect against brute force attacks

## Monitoring and Observability

### Metrics (Inherited from pkg/auth)
- `auth_login_requests_total`
- `auth_login_successful_total`
- `auth_login_failures_total`
- `auth_logout_requests_total`
- `auth_token_refresh_requests_total`

### Additional Proxy Metrics
- `proxy_requests_total`
- `proxy_request_duration_seconds`
- `proxy_backend_errors_total`
- `proxy_active_sessions`

### Logging Strategy
1. **Structured Logging**: JSON format for machine processing
2. **Log Levels**: Configurable verbosity levels
3. **Request Tracing**: Correlation IDs for request tracking
4. **Security Events**: Authentication and authorization events

## Testing Strategy

### Unit Tests
- **Auth Module**: Rely on existing console test suite
- **Proxy Logic**: Test request routing and header injection
- **Configuration**: Validate configuration parsing and validation

### Integration Tests
- **OIDC Providers**: Test against real OIDC providers (Keycloak, Auth0, etc.)
- **OpenShift Integration**: Test with OpenShift OAuth server
- **Backend Applications**: Test with various backend application types

### End-to-End Tests
- **Full Authentication Flow**: Complete OAuth2 flows
- **Session Management**: Session creation, refresh, and expiration
- **Proxy Functionality**: End-to-end request proxying with authentication

## Migration and Compatibility

### Console Compatibility
- **Same Behavior**: Identical authentication behavior to console
- **Configuration Compatibility**: Support console-style configuration
- **Session Interoperability**: Sessions should work identically
- **Metrics Compatibility**: Same metric names and labels

### Update Strategy
1. **Console Sync**: Regular synchronization with console auth module updates
2. **Dependency Updates**: Coordinated dependency updates
3. **Regression Testing**: Comprehensive testing after updates
4. **Rollback Plan**: Quick rollback capability for problematic updates

## Development Workflow

### Initial Setup
1. **Extract Auth Module**: Copy `pkg/auth` from console repository
2. **Setup Dependencies**: Import relevant dependencies from console `go.mod`
3. **Basic Wrapper**: Create minimal wrapper to initialize auth module
4. **Simple Proxy**: Implement basic reverse proxy functionality
5. **Configuration**: Add configuration system

### Development Process
1. **Feature Branches**: Use feature branches for all changes
2. **No Auth Changes**: Strict policy against modifying `pkg/auth`
3. **Testing**: Comprehensive testing for all new features
4. **Documentation**: Update documentation for all changes
5. **Code Review**: Peer review for all changes

### Continuous Integration
1. **Build Pipeline**: Automated builds for all commits
2. **Test Suite**: Run full test suite on all PRs
3. **Security Scanning**: Automated security vulnerability scanning
4. **Container Building**: Automated container image builds
5. **Deployment Testing**: Automated deployment validation

## Future Enhancements

### Planned Features
1. **Multi-Backend Support**: Route to different backends based on rules
2. **API Gateway Features**: Rate limiting, request transformation
3. **Advanced Session Management**: External session stores (Redis, etc.)
4. **Custom Authentication**: Plugin system for custom auth methods
5. **GraphQL Support**: Special handling for GraphQL endpoints

### Extension Points
1. **Middleware System**: Pluggable middleware for custom logic
2. **Backend Selectors**: Custom backend selection algorithms
3. **Header Transformers**: Custom header transformation logic
4. **Authentication Hooks**: Pre/post authentication hooks
5. **Metrics Extensions**: Custom metrics collection

## Success Criteria

### Technical Success
- [ ] Auth module functions identically to console implementation
- [ ] Zero modifications required to `pkg/auth` files
- [ ] All console dependencies preserved and compatible
- [ ] Production-ready deployment artifacts
- [ ] Comprehensive test coverage

### Operational Success
- [ ] Successful deployment in Kubernetes environments
- [ ] Integration with common OIDC providers
- [ ] Performance comparable to console auth
- [ ] Comprehensive monitoring and alerting
- [ ] Documentation suitable for operations teams

### Community Success
- [ ] Open source release with permissive license
- [ ] Community adoption and contributions
- [ ] Integration examples with popular applications
- [ ] Active maintenance and support

This design document serves as the blueprint for creating a standalone authentication proxy that leverages the proven console authentication implementation while providing the flexibility needed for general-purpose authentication proxy use cases.