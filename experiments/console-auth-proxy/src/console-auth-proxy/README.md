# Console Auth Proxy

A standalone authentication reverse proxy service that extracts and reuses the mature authentication module from the OpenShift Console project. This service provides enterprise-grade OAuth2/OIDC authentication and session management for applications that need to integrate with OpenShift or generic OIDC providers.

## Features

- **Battle-tested Authentication**: Uses the exact same authentication code as OpenShift Console
- **OAuth2/OIDC Support**: Full support for OpenShift OAuth and generic OIDC providers
- **Reverse Proxy**: Proxies authenticated requests to any backend application
- **Session Management**: Sophisticated dual-store session management with encrypted cookies
- **Security Features**: CSRF protection, token validation, secure transport, and flexible TLS configuration
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

# Run with self-signed certificates (development)
docker run -p 8080:8080 \
  -e CAP_ISSUER_URL=https://self-signed-oidc.internal \
  -e CAP_CLIENT_ID=your-client-id \
  -e CAP_CLIENT_SECRET=your-client-secret \
  -e CAP_REDIRECT_URL=http://localhost:8080/auth/callback \
  -e CAP_BACKEND_URL=https://self-signed-app.internal \
  -e CAP_AUTH_TLS_INSECURE_SKIP_VERIFY=true \
  -e CAP_PROXY_TLS_INSECURE_SKIP_VERIFY=true \
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
| `--auth-tls-insecure-skip-verify` | Skip TLS verification for auth provider | `false` | `--auth-tls-insecure-skip-verify=true` |
| `--auth-tls-server-name` | Override SNI server name for auth provider | | `--auth-tls-server-name=auth.internal` |
| `--proxy-tls-insecure-skip-verify` | Skip TLS verification for backend | `false` | `--proxy-tls-insecure-skip-verify=true` |
| `--proxy-tls-server-name` | Override SNI server name for backend | | `--proxy-tls-server-name=app.internal` |
| `--proxy-tls-ca-file` | Custom CA file for backend connections | | `--proxy-tls-ca-file=/etc/ssl/ca.crt` |
| `--proxy-tls-cert-file` | Client certificate file for backend | | `--proxy-tls-cert-file=/etc/ssl/client.crt` |
| `--proxy-tls-key-file` | Client private key file for backend | | `--proxy-tls-key-file=/etc/ssl/client.key` |
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

#### Self-Signed Certificates (Development)
```bash
# Skip TLS verification for both auth provider and backend
./console-auth-proxy \
  --backend-url https://self-signed-app.internal:8443 \
  --issuer-url https://self-signed-keycloak.internal:8443/auth/realms/myrealm \
  --client-id console-proxy \
  --client-secret mysecret \
  --redirect-url https://proxy.example.com/auth/callback \
  --auth-tls-insecure-skip-verify=true \
  --proxy-tls-insecure-skip-verify=true
```

#### SNI Override for IP-based Connections
```bash
# Use IP addresses but override SNI names to match certificates
./console-auth-proxy \
  --backend-url https://192.168.1.100:8080 \
  --issuer-url https://10.0.0.50:8443 \
  --auth-tls-server-name keycloak.internal \
  --proxy-tls-server-name app.internal \
  --client-id my-client \
  --client-secret my-secret \
  --redirect-url https://proxy.example.com/auth/callback
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

# TLS configuration via environment variables
export CAP_AUTH_TLS_INSECURE_SKIP_VERIFY=false
export CAP_AUTH_TLS_SERVER_NAME=auth.internal
export CAP_PROXY_TLS_INSECURE_SKIP_VERIFY=false
export CAP_PROXY_TLS_SERVER_NAME=app.internal
export CAP_PROXY_TLS_CA_FILE=/etc/ssl/ca/ca.crt

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
  
  # TLS settings for auth provider connections
  tls:
    insecure_skip_verify: false  # Set to true to skip TLS verification (dev only)
    server_name: ""              # Override SNI server name if needed

proxy:
  backend:
    url: "http://your-backend:3000"
  headers:
    user_header: "X-Forwarded-User"
    auth_header: "Authorization"
    auth_header_value: "bearer"
  
  # TLS settings for backend connections
  tls:
    insecure_skip_verify: false  # Set to true to skip TLS verification (dev only)
    server_name: ""              # Override SNI server name if needed
    ca_file: ""                  # Custom CA certificate file
    cert_file: ""                # Client certificate file for mTLS
    key_file: ""                 # Client private key file for mTLS
```

### Environment Variables

All configuration options can be set via environment variables with the `CAP_` prefix:

- `CAP_ISSUER_URL`: OIDC provider URL
- `CAP_CLIENT_ID`: OAuth2 client ID
- `CAP_CLIENT_SECRET`: OAuth2 client secret
- `CAP_REDIRECT_URL`: OAuth2 redirect URL
- `CAP_BACKEND_URL`: Backend application URL
- `CAP_SECURE_COOKIES`: Use secure cookies (true/false)

#### TLS Configuration Variables

- `CAP_AUTH_TLS_INSECURE_SKIP_VERIFY`: Skip TLS verification for auth provider (true/false)
- `CAP_AUTH_TLS_SERVER_NAME`: Override SNI server name for auth provider
- `CAP_PROXY_TLS_INSECURE_SKIP_VERIFY`: Skip TLS verification for backend (true/false)
- `CAP_PROXY_TLS_SERVER_NAME`: Override SNI server name for backend
- `CAP_PROXY_TLS_CA_FILE`: Custom CA file for backend connections
- `CAP_PROXY_TLS_CERT_FILE`: Client certificate file for backend connections
- `CAP_PROXY_TLS_KEY_FILE`: Client private key file for backend connections

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

## TLS Configuration

The proxy supports comprehensive TLS configuration for both auth provider connections and backend service connections.

### Common TLS Scenarios

#### Self-Signed Certificates (Development Only)

⚠️ **Warning**: Only use `insecure_skip_verify` in development environments.

```yaml
auth:
  tls:
    insecure_skip_verify: true

proxy:
  tls:
    insecure_skip_verify: true
```

#### SNI Override for IP-Based Connections

When connecting to services by IP address but certificates use hostnames:

```yaml
auth:
  issuer_url: "https://192.168.1.100:8443"
  tls:
    server_name: "keycloak.internal"

proxy:
  backend:
    url: "https://10.0.0.50:8080"
  tls:
    server_name: "app.internal"
```

#### Custom CA Certificates

For services using private/corporate CA certificates:

```yaml
auth:
  issuer_ca: "/etc/ssl/ca/auth-provider-ca.crt"

proxy:
  tls:
    ca_file: "/etc/ssl/ca/backend-ca.crt"
```

#### Mutual TLS (mTLS)

For backend services requiring client certificates:

```yaml
proxy:
  tls:
    ca_file: "/etc/ssl/ca/backend-ca.crt"
    cert_file: "/etc/ssl/client/client.crt"
    key_file: "/etc/ssl/client/client.key"
```

For detailed TLS configuration examples and troubleshooting, see [TLS_CONFIGURATION.md](./TLS_CONFIGURATION.md).

## Security Considerations

### Production Deployment

1. **Use HTTPS**: Always enable TLS in production
2. **Secure Cookies**: Set `secure_cookies: true`
3. **Strong Secrets**: Use cryptographically strong client secrets and cookie keys
4. **Network Policies**: Restrict network access in Kubernetes
5. **RBAC**: Use minimal service account permissions
6. **Regular Updates**: Keep dependencies updated
7. **TLS Best Practices**: Never use `insecure_skip_verify` in production

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