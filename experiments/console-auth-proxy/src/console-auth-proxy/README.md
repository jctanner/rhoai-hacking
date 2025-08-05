# Console Auth Proxy

A standalone authentication reverse proxy service that extracts and reuses the mature authentication module from the OpenShift Console project. This service provides enterprise-grade OAuth2/OIDC authentication and session management for applications that need to integrate with OpenShift or generic OIDC providers.

## Features

- **Battle-tested Authentication**: Uses the exact same authentication code as OpenShift Console
- **OAuth2/OIDC Support**: Full support for OpenShift OAuth and generic OIDC providers
- **Reverse Proxy**: Proxies authenticated requests to any backend application
- **Session Management**: Sophisticated dual-store session management with encrypted cookies
- **Security Features**: CSRF protection, token validation, and secure transport
- **Cloud Native**: Kubernetes-ready with health checks and metrics
- **Zero Auth Module Changes**: Preserves the original console auth code without modifications

## Quick Start

### Prerequisites

- Go 1.23+ 
- Access to an OIDC provider or OpenShift cluster
- Backend application to protect

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/console-auth-proxy.git
cd console-auth-proxy

# Build the binary
go build -o console-auth-proxy ./cmd/console-auth-proxy

# Run with configuration file
./console-auth-proxy --config ./configs/dev.yaml
```

### Docker

```bash
# Build container image
docker build -t console-auth-proxy .

# Run with environment variables
docker run -p 8080:8080 \
  -e CAP_ISSUER_URL=https://your-oidc-provider.com \
  -e CAP_CLIENT_ID=your-client-id \
  -e CAP_CLIENT_SECRET=your-client-secret \
  -e CAP_REDIRECT_URL=http://localhost:8080/auth/callback \
  -e CAP_BACKEND_URL=http://your-backend:3000 \
  console-auth-proxy
```

## Command Line Usage

### Basic CLI Examples

The console-auth-proxy supports comprehensive CLI configuration. Here are common usage patterns:

#### Minimal OIDC Setup
```bash
./console-auth-proxy \
  --backend-url http://localhost:3000 \
  --issuer-url https://your-oidc-provider.com \
  --client-id your-client-id \
  --client-secret your-client-secret \
  --redirect-url http://localhost:8080/auth/callback
```

#### OpenShift OAuth Setup
```bash
./console-auth-proxy \
  --auth-source openshift \
  --backend-url http://localhost:3000 \
  --issuer-url https://oauth-openshift.apps.cluster.example.com \
  --client-id console-auth-proxy \
  --client-secret your-openshift-client-secret \
  --redirect-url https://your-proxy.apps.cluster.example.com/auth/callback
```

#### Development Mode (HTTP, insecure cookies)
```bash
./console-auth-proxy \
  --backend-url http://localhost:3000 \
  --issuer-url https://your-oidc-provider.com \
  --client-id dev-client \
  --client-secret dev-secret \
  --redirect-url http://localhost:8080/auth/callback \
  --secure-cookies=false \
  --listen-address 0.0.0.0:8080
```

#### Production Setup with Custom Listen Address
```bash
./console-auth-proxy \
  --config ./configs/production.yaml \
  --listen-address 0.0.0.0:443 \
  --secure-cookies=true
```

### Available CLI Flags

| Flag | Description | Default | Example |
|------|-------------|---------|---------|
| `--config` | Config file path | `./config.yaml` | `--config /etc/proxy/config.yaml` |
| `--listen-address` | Address to listen on | `0.0.0.0:8080` | `--listen-address :8443` |
| `--backend-url` | Backend URL to proxy to | *(required)* | `--backend-url http://app:3000` |
| `--auth-source` | Authentication source | `oidc` | `--auth-source openshift` |
| `--issuer-url` | OIDC/OAuth issuer URL | *(required)* | `--issuer-url https://auth.example.com` |
| `--client-id` | OAuth2 client ID | *(required)* | `--client-id my-app` |
| `--client-secret` | OAuth2 client secret | *(required)* | `--client-secret secret123` |
| `--redirect-url` | OAuth2 redirect URL | *(required)* | `--redirect-url https://proxy.example.com/auth/callback` |
| `--secure-cookies` | Use secure HTTPS-only cookies | `true` | `--secure-cookies=false` |
| `--help, -h` | Show help message | | `--help` |
| `--version, -v` | Show version information | | `--version` |

### Real-World Examples

#### Protecting a Jupyter Notebook Server
```bash
./console-auth-proxy \
  --backend-url http://localhost:8888 \
  --issuer-url https://keycloak.example.com/auth/realms/myrealm \
  --client-id jupyter-proxy \
  --client-secret abc123secret \
  --redirect-url https://jupyter-proxy.example.com/auth/callback \
  --listen-address 0.0.0.0:8080
```

#### Protecting a Grafana Dashboard
```bash
./console-auth-proxy \
  --backend-url http://grafana:3000 \
  --issuer-url https://dex.example.com \
  --client-id grafana-auth \
  --client-secret xyz789secret \
  --redirect-url https://grafana-auth.example.com/auth/callback
```

#### Multi-Service Setup with Config File
```bash
# Use a config file for complex setups
./console-auth-proxy --config ./configs/multi-service.yaml

# Or override specific settings
./console-auth-proxy \
  --config ./configs/base.yaml \
  --backend-url http://different-backend:8080 \
  --listen-address :9090
```

### Environment Variable Equivalents

All CLI flags can be set via environment variables with the `CAP_` prefix:

```bash
# Set via environment variables (useful for containers)
export CAP_BACKEND_URL=http://localhost:3000
export CAP_ISSUER_URL=https://your-oidc-provider.com
export CAP_CLIENT_ID=your-client-id
export CAP_CLIENT_SECRET=your-client-secret
export CAP_REDIRECT_URL=http://localhost:8080/auth/callback
export CAP_SECURE_COOKIES=true

# Run with env vars
./console-auth-proxy
```

### Configuration Priority

Settings are applied in this order (highest to lowest priority):
1. **Command-line flags** (highest priority)
2. **Environment variables**
3. **Configuration file**
4. **Default values** (lowest priority)

```bash
# This overrides config file settings
./console-auth-proxy \
  --config ./configs/production.yaml \
  --backend-url http://override-backend:3000  # This takes precedence
```

### Validation and Debugging

```bash
# Check configuration without starting server
./console-auth-proxy --help
./console-auth-proxy --version

# Validate configuration (will show errors if invalid)
./console-auth-proxy \
  --backend-url http://localhost:3000 \
  --issuer-url https://invalid-url \
  --client-id test
# Will show validation errors and exit
```

### Logging and Troubleshooting

```bash
# Enable verbose logging (via config file or env var)
export CAP_OBSERVABILITY_LOGGING_LEVEL=debug
./console-auth-proxy --config ./configs/dev.yaml

# Check health endpoints
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
curl http://localhost:8080/metrics
```

## Configuration

The proxy can be configured via YAML files, environment variables, or command-line flags.

### Example Configuration

```yaml
server:
  listen_address: "0.0.0.0:8080"

auth:
  auth_source: "oidc"  # or "openshift"
  issuer_url: "https://your-oidc-provider.com"
  client_id: "console-auth-proxy"
  client_secret: "your-client-secret"
  redirect_url: "http://localhost:8080/auth/callback"
  scope: ["openid", "profile", "email"]
  secure_cookies: true

proxy:
  backend:
    url: "http://your-backend:3000"
  headers:
    user_header: "X-Forwarded-User"
    auth_header: "Authorization"
    auth_header_value: "bearer"
```

### Environment Variables

All configuration options can be set via environment variables with the `CAP_` prefix:

- `CAP_ISSUER_URL`: OIDC provider URL
- `CAP_CLIENT_ID`: OAuth2 client ID
- `CAP_CLIENT_SECRET`: OAuth2 client secret
- `CAP_REDIRECT_URL`: OAuth2 redirect URL
- `CAP_BACKEND_URL`: Backend application URL
- `CAP_SECURE_COOKIES`: Use secure cookies (true/false)

### Configuration Files

Example configurations are provided in the `configs/` directory:

- `dev.yaml`: Development configuration with detailed comments
- `production.yaml`: Production configuration with security best practices
- `openshift.yaml`: OpenShift-specific configuration

## Authentication Flows

### OIDC Flow

1. User accesses protected resource
2. Proxy redirects to OIDC provider
3. User authenticates with provider
4. Provider redirects back with authorization code
5. Proxy exchanges code for tokens
6. Proxy creates session and proxies request to backend

### OpenShift Flow

1. User accesses protected resource
2. Proxy redirects to OpenShift OAuth server
3. User authenticates with OpenShift
4. OAuth server redirects back with authorization code
5. Proxy exchanges code for OpenShift token
6. Proxy validates token with Kubernetes API
7. Proxy creates session and proxies request to backend

## Backend Integration

The proxy automatically injects headers into backend requests:

- `Authorization: Bearer <token>`: User's access token
- `X-Forwarded-User`: Username
- `X-Forwarded-User-ID`: User ID
- `X-Forwarded-Email`: User email (if available)

Your backend application can use these headers to identify the authenticated user without implementing OAuth2 flows.

## Endpoints

- `GET /auth/login`: Initiate authentication flow
- `GET /auth/logout`: Clear session and logout
- `GET /auth/callback`: OAuth2 callback endpoint
- `GET /auth/info`: Current user information (debug)
- `GET /auth/error`: Authentication error page
- `GET /healthz`: Liveness probe
- `GET /readyz`: Readiness probe
- `GET /metrics`: Prometheus metrics
- `GET /version`: Version information
- `/*`: All other requests are proxied to backend

## Kubernetes Deployment

### Basic Deployment

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
        - name: CAP_ISSUER_URL
          value: "https://your-oidc-provider.com"
        - name: CAP_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: oauth-credentials
              key: client-id
        - name: CAP_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth-credentials
              key: client-secret
        - name: CAP_BACKEND_URL
          value: "http://backend-service:3000"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8080
```

### OpenShift Deployment

For OpenShift, create an OAuth client and use the OpenShift configuration:

```bash
# Create OAuth client
oc create -f - <<EOF
apiVersion: oauth.openshift.io/v1
kind: OAuthClient
metadata:
  name: console-auth-proxy
secret: your-client-secret
redirectURIs:
- https://your-proxy-route.apps.cluster.example.com/auth/callback
grantMethod: auto
EOF
```

## Security Considerations

### Production Deployment

1. **Use HTTPS**: Always enable TLS in production
2. **Secure Cookies**: Set `secure_cookies: true`
3. **Strong Secrets**: Use cryptographically strong client secrets and cookie keys
4. **Network Policies**: Restrict network access in Kubernetes
5. **RBAC**: Use minimal service account permissions
6. **Regular Updates**: Keep dependencies updated

### Cookie Encryption Keys

Generate secure cookie keys:

```bash
# Authentication key (64 bytes, base64 encoded)
openssl rand -base64 64

# Encryption key (32 bytes, base64 encoded)  
openssl rand -base64 32
```

## Monitoring

### Metrics

The proxy exposes Prometheus metrics at `/metrics`:

- `auth_login_requests_total`: Total login attempts
- `auth_login_successful_total`: Successful logins
- `auth_login_failures_total`: Failed login attempts
- `auth_logout_requests_total`: Logout requests
- `auth_token_refresh_requests_total`: Token refresh attempts
- `proxy_requests_total`: Total proxy requests
- `proxy_request_duration_seconds`: Request duration

### Logging

Structured JSON logging is available for production environments:

```yaml
observability:
  logging:
    level: "info"
    format: "json"
    output: "stdout"
```

## Development

### Building from Source

```bash
# Build
go build -o console-auth-proxy ./cmd/console-auth-proxy

# Run tests
go test ./...

# Run with development config
./console-auth-proxy --config ./configs/dev.yaml
```

### Project Structure

```
├── cmd/console-auth-proxy/    # Application entry point
├── internal/                  # Internal packages
│   ├── config/               # Configuration management
│   ├── proxy/                # Reverse proxy implementation
│   ├── server/               # HTTP server and routes
│   └── version/              # Version information
├── pkg/auth/                 # Console auth module (copied verbatim)
├── configs/                  # Example configurations
├── deployments/             # Kubernetes manifests
└── scripts/                 # Build and utility scripts
```

### Console Auth Module

The `pkg/auth` directory contains the OpenShift Console authentication module copied verbatim. **This code should never be modified** to ensure compatibility and security guarantees from the upstream project.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes (avoiding modifications to `pkg/auth`)
4. Add tests
5. Submit a pull request

## License

This project is based on the OpenShift Console and inherits its Apache 2.0 license.

## Support

- Documentation: See `docs/` directory
- Issues: GitHub Issues
- Discussions: GitHub Discussions

## Related Projects

- [OpenShift Console](https://github.com/openshift/console) - Source of the authentication module
- [oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy) - Alternative OAuth2 proxy solution
- [Keycloak Gatekeeper](https://github.com/keycloak/keycloak-gatekeeper) - Keycloak-based auth proxy