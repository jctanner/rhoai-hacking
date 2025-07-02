# ODH Gateway

A lightweight, configurable reverse proxy designed for Open Data Hub (ODH) and Kubernetes environments. The gateway dynamically routes incoming HTTP requests to upstream services based on path prefixes defined in a YAML configuration file.

## Features

- **Dynamic Routing**: Route requests to different upstream services based on URL path prefixes
- **Hot Reload**: Automatically reload configuration changes without restarting the service
- **ConfigMap Integration**: Designed to work with Kubernetes ConfigMaps for configuration management
- **Request Logging**: Comprehensive logging of all incoming requests
- **Containerized**: Ready-to-deploy Docker container with multi-stage build
- **Symlink Support**: Properly handles symlinked configuration files (important for Kubernetes mounts)

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client        │──▶│   ODH Gateway   │──▶│   Upstream      │
│   Request       │    │   (Reverse      │    │   Services      │
│                 │    │    Proxy)       │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  Configuration  │
                       │  YAML File      │
                       │  (ConfigMap)    │
                       └─────────────────┘
```

The gateway consists of three main components:

1. **Configuration Management** (`pkg/config/`): Loads and parses YAML routing configuration
2. **Proxy Server** (`internal/proxy/`): HTTP reverse proxy with routing logic and hot-reload capability
3. **Main Application** (`cmd/odh-gateway/`): Entry point that starts the server

## Configuration

### Command Line Flags

| Flag | Description |
|------|-------------|
| `--config` | Path to configuration file (default: `/etc/odh-gateway/config.yaml`) |
| `--tls-cert-file` | Path to TLS certificate file (enables HTTPS) |
| `--tls-key-file` | Path to TLS private key file (enables HTTPS) |
| `--oidc-issuer-url` | OIDC issuer URL |
| `--oidc-client-id` | OIDC client ID |
| `--oidc-client-secret` | OIDC client secret |
| `--openshift-cluster-url` | OpenShift cluster URL (e.g., https://api.cluster.example.com:6443) |
| `--openshift-client-id` | OpenShift OAuth client ID |
| `--openshift-client-secret` | OpenShift OAuth client secret |
| `--openshift-ca-bundle` | OpenShift CA bundle (PEM format) |
| `--openshift-scope` | OpenShift OAuth scope (default: user:info) |

**Notes:**
- Both `--tls-cert-file` and `--tls-key-file` must be provided together to enable HTTPS
- **Authentication Provider Selection**:
  - OpenShift OAuth takes precedence if all required OpenShift flags are provided
  - OIDC authentication is used if all required OIDC flags are provided and OpenShift is not configured
  - No authentication is used if neither provider is fully configured
- All flags can be set via environment variables (see below)
- Use `--help` to see the full help output with descriptions

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GATEWAY_CONFIG` | `/etc/odh-gateway/config.yaml` | Path to the configuration file |
| `GATEWAY_PORT` | `8080` (HTTP) / `8443` (HTTPS) | Port for the gateway to listen on |
| `OIDC_ISSUER_URL` | - | OIDC issuer URL |
| `OIDC_CLIENT_ID` | - | OIDC client ID |
| `OIDC_CLIENT_SECRET` | - | OIDC client secret |
| `OPENSHIFT_CLUSTER_URL` | - | OpenShift cluster URL |
| `OPENSHIFT_CLIENT_ID` | - | OpenShift OAuth client ID |
| `OPENSHIFT_CLIENT_SECRET` | - | OpenShift OAuth client secret |
| `OPENSHIFT_CA_BUNDLE` | - | OpenShift CA bundle (PEM format) |
| `OPENSHIFT_SCOPE` | `user:info` | OpenShift OAuth scope |

**Environment Variable Priority:** Environment variables take precedence over command line flags. Authentication providers are automatically enabled based on which environment variables are configured (OpenShift takes precedence over OIDC if both are configured).

### Configuration File Format

The gateway reads its routing configuration from a YAML file with the following structure:

```yaml
routes:
  - path: "/jupyter/"
    upstream: "http://jupyter-service:8888"
    authRequired: true  # Override global OIDC setting for this route
  - path: "/mlflow/"
    upstream: "http://mlflow-service:5000"
    authRequired: false # Disable auth for this route even if globally enabled
  - path: "/tensorboard/"
    upstream: "http://tensorboard-service:6006"
    # authRequired not specified - uses global default
```

#### Route Configuration

- **`path`**: URL path prefix to match (automatically normalized to end with `/`)
- **`upstream`**: Target service URL to proxy requests to
- **`authRequired`** *(optional)*: Boolean to override global OIDC authentication setting for this specific route

#### Fallback Route Support

The gateway supports using `"/"` as a catchall fallback route for any requests that don't match more specific path prefixes. This is useful for handling static assets, health checks, or providing a default service.

**Example with fallback and authentication:**
```yaml
routes:
  - path: "/jupyter/"
    upstream: "http://jupyter-service:8888"
    authRequired: true  # Requires OIDC authentication
  - path: "/mlflow/"
    upstream: "http://mlflow-service:5000"
    authRequired: true  # Requires OIDC authentication
  - path: "/public/"
    upstream: "http://public-service:8080"
    authRequired: false # No authentication required
  - path: "/"
    upstream: "http://default-service:8080"  # Uses global auth setting
```

**Request routing behavior:**
- `GET /jupyter/lab` → `http://jupyter-service:8888/jupyter/lab`
- `GET /mlflow/experiments` → `http://mlflow-service:5000/mlflow/experiments`
- `GET /unknown/path` → `http://default-service:8080/unknown/path` (fallback)
- `GET /favicon.ico` → `http://default-service:8080/favicon.ico` (fallback)

**Important notes:**
- List more specific routes before the `"/"` fallback in your configuration
- The full original path is preserved when forwarding to upstream services
- Only one `"/"` route should be configured (last one wins if multiple are defined)

### Example Kubernetes ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: odh-gateway-config
data:
  config.yaml: |
    routes:
      - path: "/jupyter/"
        upstream: "http://jupyter-notebook-service:8888"
      - path: "/mlflow/"
        upstream: "http://mlflow-tracking-service:5000"
      - path: "/tensorboard/"
        upstream: "http://tensorboard-service:6006"
```

## Hot Reload Mechanism

The gateway implements a dual approach for configuration reloading:

1. **File System Watching**: Uses `fsnotify` to watch for changes in the configuration file directory
2. **Polling**: Every 2 seconds, checks the file's SHA256 hash for changes as a fallback mechanism

This approach ensures configuration changes are picked up reliably, even in environments where file system events might be unreliable (like some Kubernetes setups).

## Building and Deployment

### Local Development

```bash
# Install dependencies
go mod download

# Run locally with HTTP
export GATEWAY_CONFIG=./config.yaml
export GATEWAY_PORT=8080
go run cmd/odh-gateway/main.go

# Run locally with HTTPS
export GATEWAY_CONFIG=./config.yaml
export GATEWAY_PORT=8443
go run cmd/odh-gateway/main.go \
    --tls-cert-file=/path/to/cert.pem \
    --tls-key-file=/path/to/cert.key

# Run with OIDC authentication (automatically enabled when all OIDC vars are set)
export GATEWAY_CONFIG=./config.yaml
export OIDC_ISSUER_URL=https://your-keycloak.com/auth/realms/your-realm
export OIDC_CLIENT_ID=odh-gateway
export OIDC_CLIENT_SECRET=your-client-secret
go run cmd/odh-gateway/main.go

# Run with OpenShift OAuth authentication (automatically enabled when all OpenShift vars are set)
export GATEWAY_CONFIG=./config.yaml
export OPENSHIFT_CLUSTER_URL=https://api.cluster.example.com:6443
export OPENSHIFT_CLIENT_ID=odh-gateway
export OPENSHIFT_CLIENT_SECRET=your-oauth-secret
export OPENSHIFT_CA_BUNDLE="$(cat /path/to/ca-bundle.pem)"
go run cmd/odh-gateway/main.go

# Run with OpenShift OAuth using command line flags
go run cmd/odh-gateway/main.go \
    --openshift-cluster-url=https://api.cluster.example.com:6443 \
    --openshift-client-id=odh-gateway \
    --openshift-client-secret=your-oauth-secret \
    --openshift-ca-bundle="$(cat /path/to/ca-bundle.pem)"
```

### Docker Build

```bash
# Build the container
docker build -t odh-gateway:latest .

# Run the container
docker run -p 8080:8080 -v $(pwd)/config.yaml:/etc/odh-gateway/config.yaml odh-gateway:latest
```

### Automated Build and Publishing

The project includes a Makefile with targets for automated build and deployment:

```bash
# Build the container image
make build

# Build and push to registry
make publish

# View all available targets
make help
```

The `make publish` target builds and pushes the image to `registry.tannerjc.net/odh-proxy:latest`.

**Available make targets:**
- `make build` - Build the container image
- `make publish` - Build and push the container image to registry
- `make build-binary` - Build the Go binary locally
- `make test` - Run Go tests
- `make test-integration` - Run integration tests
- `make gen-certs` - Generate self-signed certificates for development
- `make clean` - Clean up build artifacts

### TLS Certificate Setup

For development and testing, you can create self-signed certificates:

```bash
# Generate a private key
openssl genrsa -out cert.key 2048

# Generate a self-signed certificate
openssl req -new -x509 -key cert.key -out cert.pem -days 365 \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Run with TLS
./odh-gateway-server \
    --tls-cert-file=./cert.pem \
    --tls-key-file=./cert.key
```

For production environments, use certificates from a trusted Certificate Authority or tools like cert-manager in Kubernetes.

### Authentication

The gateway supports multiple authentication providers for securing access to upstream services.

#### Provider Selection

The gateway automatically selects the authentication provider based on the configuration provided:

1. **OpenShift OAuth** (takes precedence): Enabled when `--openshift-cluster-url`, `--openshift-client-id`, and `--openshift-client-secret` are provided
2. **OIDC**: Enabled when `--oidc-issuer-url`, `--oidc-client-id`, and `--oidc-client-secret` are provided
3. **No Authentication**: Used when neither provider is fully configured

#### OpenShift OAuth Setup

```bash
# Run with OpenShift OAuth authentication
./odh-gateway-server \
    --openshift-cluster-url=https://api.cluster.example.com:6443 \
    --openshift-client-id=your-oauth-client-id \
    --openshift-client-secret=your-oauth-client-secret \
    --openshift-ca-bundle="$(cat /path/to/ca-bundle.pem)"

# Or via environment variables
export OPENSHIFT_CLUSTER_URL=https://api.cluster.example.com:6443
export OPENSHIFT_CLIENT_ID=your-oauth-client-id
export OPENSHIFT_CLIENT_SECRET=your-oauth-client-secret
export OPENSHIFT_CA_BUNDLE="$(cat /path/to/ca-bundle.pem)"
./odh-gateway-server
```

**OpenShift OAuth Configuration Requirements:**
- **OAuth Client**: Must be registered in OpenShift with appropriate redirect URIs
- **Cluster URL**: Full API URL of your OpenShift cluster
- **CA Bundle**: (Optional but recommended) PEM-encoded CA certificates for validating OpenShift API calls
- **Scope**: (Optional) OAuth scope to request (defaults to `user:info`)

#### OIDC Setup

```bash
# Run with OIDC authentication
./odh-gateway-server \
    --oidc-issuer-url=https://your-oidc-provider.com/auth/realms/your-realm \
    --oidc-client-id=your-client-id \
    --oidc-client-secret=your-client-secret

# Or via environment variables
export OIDC_ISSUER_URL=https://your-oidc-provider.com/auth/realms/your-realm
export OIDC_CLIENT_ID=your-client-id
export OIDC_CLIENT_SECRET=your-client-secret
./odh-gateway-server
```

#### Authentication Endpoints

When authentication is enabled, the gateway provides these endpoints:

**For OpenShift OAuth:**
- `/auth/callback` - OAuth callback endpoint (automatically handled)
- `/auth/logout` - Logout endpoint to clear authentication

**For OIDC:**
- `/oidc/callback` - OIDC callback endpoint (automatically handled)
- `/oidc/logout` - Logout endpoint to clear authentication

#### Authentication Flow

The authentication flow is similar for both providers:

1. **Unauthenticated Request**: User accesses a protected route
2. **Redirect to Provider**: Gateway redirects to authentication provider (OpenShift/OIDC)
3. **User Login**: User authenticates with the provider
4. **Callback**: Provider redirects back to callback endpoint with authorization code
5. **Token Exchange**: Gateway exchanges code for access/ID token and validates it
6. **Session Cookie**: Gateway sets secure session cookie with token
7. **Access Granted**: User is redirected to original URL with authenticated session

#### Per-Route Authentication Control

- **Global Default**: Authentication is enabled when any provider is configured
- **Route Override**: Use `authRequired: true/false` in route configuration to override global setting
- **Flexible Control**: Mix authenticated and public routes as needed

## Kubernetes Deployment

### Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: odh-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: odh-gateway
  template:
    metadata:
      labels:
        app: odh-gateway
    spec:
      containers:
      - name: odh-gateway
        image: registry.tannerjc.net/odh-proxy:latest
        ports:
        - containerPort: 8080
        env:
        - name: GATEWAY_CONFIG
          value: "/etc/odh-gateway/config.yaml"
        - name: GATEWAY_PORT
          value: "8080"
        # Uncomment below for OIDC authentication (automatically enabled when all variables are set)
        # - name: OIDC_ISSUER_URL
        #   value: "https://your-keycloak.com/auth/realms/your-realm"
        # - name: OIDC_CLIENT_ID
        #   value: "odh-gateway"
        # - name: OIDC_CLIENT_SECRET
        #   valueFrom:
        #     secretKeyRef:
        #       name: oidc-client-secret
        #       key: client-secret
        # Uncomment below for OpenShift OAuth authentication (takes precedence over OIDC)
        # - name: OPENSHIFT_CLUSTER_URL
        #   value: "https://api.cluster.example.com:6443"
        # - name: OPENSHIFT_CLIENT_ID
        #   value: "odh-gateway"
        # - name: OPENSHIFT_CLIENT_SECRET
        #   valueFrom:
        #     secretKeyRef:
        #       name: openshift-oauth-secret
        #       key: client-secret
        # - name: OPENSHIFT_CA_BUNDLE
        #   valueFrom:
        #     configMapKeyRef:
        #       name: openshift-ca-bundle
        #       key: ca-bundle.pem
        volumeMounts:
        - name: config-volume
          mountPath: /etc/odh-gateway
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        # Uncomment below for HTTPS with TLS certificates
        # args:
        #   - "--tls-cert-file=/etc/tls/tls.crt"
        #   - "--tls-key-file=/etc/tls/tls.key"
        # volumeMounts:
        # - name: tls-certs
        #   mountPath: /etc/tls
        #   readOnly: true
      volumes:
      - name: config-volume
        configMap:
          name: odh-gateway-config
      # Uncomment below for HTTPS with TLS certificates
      # - name: tls-certs
      #   secret:
      #     secretName: odh-gateway-tls
      # Uncomment below for OIDC client secret
      # - name: oidc-client-secret
      #   secret:
      #     secretName: odh-gateway-oidc-secret
---
apiVersion: v1
kind: Service
metadata:
  name: odh-gateway-service
spec:
  selector:
    app: odh-gateway
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

## Request Flow

1. **Client Request**: A client sends an HTTP request to the gateway
2. **Path Matching**: The gateway examines the request path and matches it against configured route prefixes
3. **Upstream Forwarding**: The request is forwarded to the appropriate upstream service
4. **Response Relay**: The upstream response is relayed back to the client
5. **Logging**: All requests are logged with client IP, method, and URL

## Logging

The gateway provides comprehensive request logging with authentication status:

```
2024/01/15 10:30:45 Starting HTTP server on :8080
2024/01/15 10:30:45 OIDC authentication enabled (issuer: https://keycloak.example.com/auth/realms/odh)
2024/01/15 10:30:45 Routing /jupyter/ -> http://jupyter-service:8888 (auth required)
2024/01/15 10:30:45 Routing /mlflow/ -> http://mlflow-service:5000 (auth required)
2024/01/15 10:30:45 Routing /public/ -> http://public-service:8080 (auth disabled)
2024/01/15 10:30:45 Routing / -> http://default-service:8080 (auth required (default))
2024/01/15 10:31:02 192.168.1.100:54321 GET /jupyter/lab
2024/01/15 10:31:15 192.168.1.100:54322 POST /mlflow/api/2.0/mlflow/experiments/create
2024/01/15 10:31:25 User authenticated successfully, redirecting to: /jupyter/lab
```

## CLI Help

The gateway now uses Cobra for CLI argument parsing, providing improved help output and command-line experience:

```bash
# View detailed help with all available flags
odh-gateway --help

# Sample output:
# ODH Gateway is a lightweight, configurable reverse proxy designed for Open Data Hub (ODH)
# and Kubernetes environments. The gateway dynamically routes incoming HTTP requests to upstream
# services based on path prefixes defined in a YAML configuration file.
#
# Features:
# - Dynamic routing with hot-reload capability
# - OIDC and OpenShift OAuth authentication support
# - TLS/HTTPS support
# - ConfigMap integration for Kubernetes
# - Request logging and monitoring
#
# Usage:
#   odh-gateway [flags]
#
# Flags:
#       --config string                    config file (default is /etc/odh-gateway/config.yaml)
#   -h, --help                             help for odh-gateway
#       --oidc-client-id string            OIDC client ID
#       --oidc-client-secret string        OIDC client secret
#       --oidc-issuer-url string           OIDC issuer URL
#       --openshift-ca-bundle string       OpenShift CA bundle (PEM format)
#       --openshift-client-id string       OpenShift OAuth client ID
#       --openshift-client-secret string   OpenShift OAuth client secret
#       --openshift-cluster-url string     OpenShift cluster URL (e.g., https://api.cluster.example.com:6443)
#       --openshift-scope string           OpenShift OAuth scope (default: user:info)
#       --tls-cert-file string             Path to TLS certificate file (enables HTTPS)
#       --tls-key-file string              Path to TLS private key file (enables HTTPS)
```

## Dependencies

- **Go 1.24+**: Programming language
- **gopkg.in/yaml.v3**: YAML configuration parsing
- **github.com/fsnotify/fsnotify**: File system event monitoring
- **github.com/coreos/go-oidc/v3**: OpenID Connect client library
- **golang.org/x/oauth2**: OAuth2 client library
- **github.com/spf13/cobra**: CLI framework for improved command-line experience
- **github.com/spf13/viper**: Configuration management with environment variable support

## Use Cases

This gateway is particularly useful for:

- **Multi-service ODH deployments** where different tools need to be accessible under different paths
- **Kubernetes environments** where services need dynamic routing configuration
- **Development environments** where routing needs to change frequently
- **Microservice architectures** requiring a simple, lightweight reverse proxy

## Security Considerations

- **Authentication Providers**: 
  - **OIDC**: Provides enterprise-grade authentication via OpenID Connect with ID token validation
  - **OpenShift OAuth**: Integrates with OpenShift's built-in OAuth server for seamless cluster authentication
- **Secure Cookies**: Access/ID tokens are stored in HTTP-only, secure cookies with appropriate SameSite policies
- **CSRF Protection**: State parameter validation prevents cross-site request forgery attacks
- **Token Validation**: 
  - OIDC: ID tokens are verified against the provider's public keys
  - OpenShift: Access tokens are validated against the OpenShift API
- **SSL/TLS**: Should be used in production environments (especially important with authentication cookies)
- **Certificate Validation**: 
  - OpenShift OAuth: Use proper CA bundles to validate API server certificates
  - Development environments may skip verification but should use proper certificates in production
- **Network Policies**: Should be used to restrict access to upstream services
- **Secret Management**: OAuth/OIDC client secrets should be stored securely (e.g., Kubernetes secrets)
- **OpenShift RBAC Integration**: OpenShift OAuth respects cluster RBAC policies and group memberships
- **Configuration Protection**: Configuration files may contain sensitive upstream URLs and should be protected accordingly

## Future Enhancements

The configuration structure includes commented fields for potential future features:

- Authentication requirements per route
- Advanced routing rules (headers, query parameters)
- Load balancing across multiple upstreams
- Health checking of upstream services
- Metrics and monitoring integration 