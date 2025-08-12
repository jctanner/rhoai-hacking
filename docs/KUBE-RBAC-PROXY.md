# kube-rbac-proxy: Analysis and Architecture

## Overview

**kube-rbac-proxy** is a small HTTP reverse proxy designed to provide Kubernetes RBAC-based authentication and authorization for single upstream services. It acts as a security gateway that enforces Kubernetes native RBAC policies before proxying requests to backend services.

## Purpose and Use Cases

### Primary Purpose

- **Secure services that lack built-in authentication/authorization** by adding a Kubernetes RBAC layer
- **Enforce fine-grained access control** using standard Kubernetes RBAC mechanisms
- **Provide authentication via multiple methods** (service account tokens, client certificates, OIDC)

### Common Use Cases

- **Prometheus metrics protection**: Securing `/metrics` endpoints with RBAC policies
- **Service mesh integration**: Adding authentication to legacy services
- **Zero-trust networking**: Ensuring only authorized entities can access services
- **Sidecar pattern**: Running alongside applications to provide security layer
- **Multi-tenant environments**: Isolating access to services based on user/service account permissions

## Architecture Overview

### Core Components

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
│   Client    │──▶│  kube-rbac-proxy │──▶│  Upstream   │
│ (with auth) │    │                  │    │   Service   │
└─────────────┘    └──────────────────┘    └─────────────┘
                           │
                           ▼
                   ┌──────────────────┐
                   │ Kubernetes API   │
                   │ - TokenReview    │
                   │ - SubjectAccess  │
                   │   Review         │
                   └──────────────────┘
```

### Request Processing Pipeline

1. **Client Request** → kube-rbac-proxy (with authentication credentials)
2. **Path Filtering** → Check allow/ignore path patterns
3. **Authentication** → Validate credentials via Kubernetes APIs
4. **Authorization** → Check RBAC permissions via SubjectAccessReview
5. **Header Injection** → Add user identity headers (optional)
6. **Proxy Forward** → Send request to upstream service

## Authentication Methods

### 1. Service Account Tokens (Default)

- Uses Kubernetes `TokenReview` API to validate JWT tokens
- Supports audience validation for enhanced security
- Automatically extracts user and group information

```yaml
# Example: Client with service account token
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-reader
```

### 2. Client TLS Certificates

- Validates X.509 client certificates against configured CA
- Uses certificate CommonName as username
- Supports certificate-based authentication

```bash
# Configure client CA
--client-ca-file=/path/to/ca.crt
```

### 3. OIDC (OpenID Connect) - Token Validation Only

- **Validates existing JWT tokens** from external OIDC providers (does NOT initiate login flows)
- **Passive authentication**: Expects clients to already have valid OIDC tokens
- **Not an OIDC client**: Does not perform OAuth2/OIDC authorization code flow or redirects
- Configurable claims mapping for username and groups
- Supports multiple signing algorithms

```bash
# OIDC configuration - validates tokens issued by the OIDC provider
--oidc-issuer=https://example.com
--oidc-clientID=my-client
--oidc-username-claim=email
--oidc-groups-claim=groups
```

**Important**: Clients must obtain OIDC tokens through other means (e.g., separate login flow, CLI tools, etc.) before sending requests to kube-rbac-proxy.

## Authorization Configuration

### Resource Attributes

The most common authorization method - checks if user has permission on specific Kubernetes resources:

```yaml
authorization:
  resourceAttributes:
    namespace: default
    apiVersion: v1
    resource: services
    subresource: proxy
    name: kube-rbac-proxy
```

This requires the client to have permission like:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: metrics-reader
rules:
  - apiGroups: [""]
    resources: ["services/proxy"]
    verbs: ["get"]
```

### Static Authorization

Hardcoded authorization rules for specific scenarios:

```yaml
authorization:
  static:
    - user:
        name: "system:serviceaccount:monitoring:prometheus"
      verb: "get"
      resource: "metrics"
      resourceRequest: false
      path: "/metrics"
```

### Request Rewrites

Dynamic authorization based on request parameters:

```yaml
authorization:
  resourceAttributes:
    namespace: "{{.Value}}" # Template using query parameter
    resource: "pods"
  rewrites:
    byQueryParameter:
      name: "namespace"
```

## Key Code Components

### 1. Main Application (`cmd/kube-rbac-proxy/app/kube-rbac-proxy.go`)

- Sets up HTTP server with TLS
- Configures authentication and authorization chains
- Implements request filtering pipeline
- Manages upstream proxy connection

### 2. Authentication Layer (`pkg/authn/`)

- **DelegatingAuthenticator**: Kubernetes TokenReview integration
- **OIDC Authenticator**: External OIDC provider support
- **Certificate validation**: X.509 client certificate handling

### 3. Authorization Layer (`pkg/authz/`)

- **SAR Authorizer**: SubjectAccessReview API integration
- **Static Authorizer**: Hardcoded authorization rules
- **Union Authorizer**: Combines multiple authorization methods

### 4. Filter Chain (`pkg/filters/`)

```go
// Request processing pipeline
handlerFunc := proxy.ServeHTTP
handlerFunc = filters.WithAuthHeaders(cfg.auth.Authentication.Header, handlerFunc)
handlerFunc = filters.WithAuthorization(authorizer, cfg.auth.Authorization, handlerFunc)
handlerFunc = filters.WithAuthentication(authenticator, cfg.auth.Authentication.Token.Audiences, handlerFunc)
```

### 5. Proxy Configuration (`pkg/proxy/`)

- Request attribute generation based on HTTP method
- Template-based resource attribute rewriting
- User context management

## Configuration Examples

### Basic Metrics Protection

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-rbac-proxy-config
data:
  config.yaml: |
    authorization:
      resourceAttributes:
        namespace: monitoring
        resource: services
        subresource: proxy
        name: prometheus
```

### OIDC Integration (Token Validation)

```bash
# kube-rbac-proxy validates OIDC tokens but does NOT handle login flows
kube-rbac-proxy \
  --secure-listen-address=0.0.0.0:8443 \
  --upstream=http://localhost:8080/ \
  --oidc-issuer=https://keycloak.example.com/auth/realms/kubernetes \
  --oidc-clientID=kube-rbac-proxy \
  --oidc-username-claim=preferred_username \
  --oidc-groups-claim=groups

# Clients must obtain tokens separately, e.g.:
# curl -H "Authorization: Bearer $(oidc-token)" https://proxy:8443/api
```

### Multi-tenant with Rewrites

```yaml
authorization:
  resourceAttributes:
    namespace: "{{.Value}}"
    resource: "pods"
    name: "{{.Value}}"
  rewrites:
    byQueryParameter:
      name: "tenant"
```

## Security Considerations

### Token Security

- **Service account tokens**: Receiving service can impersonate the client
- **Recommendation**: Use mTLS for high-privilege scenarios
- **Best practice**: Use low-privilege tokens specifically for authorization

### TLS Configuration

- **Always use HTTPS** in production environments
- **Client certificate authentication** provides better security properties
- **Proper CA management** is crucial for certificate-based auth

### Network Policies

- kube-rbac-proxy **complements** but doesn't replace NetworkPolicies
- NetworkPolicies don't apply to HostNetworking pods
- Combined approach provides defense in depth

## Deployment Patterns

### Sidecar Pattern

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: app
          image: my-app:latest
          args: ["--listen=127.0.0.1:8080"]
        - name: kube-rbac-proxy
          image: quay.io/brancz/kube-rbac-proxy:v0.19.1
          args:
            - "--secure-listen-address=0.0.0.0:8443"
            - "--upstream=http://127.0.0.1:8080/"
            - "--config-file=/etc/config/config.yaml"
```

### Standalone Service

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: kube-rbac-proxy
          image: quay.io/brancz/kube-rbac-proxy:v0.19.1
          args:
            - "--secure-listen-address=0.0.0.0:8443"
            - "--upstream=http://backend-service:8080/"
```

## Integration with RHOAI/OpenShift

### OpenShift Fork Differences

The OpenShift downstream version ([github.com/openshift/kube-rbac-proxy](https://github.com/openshift/kube-rbac-proxy)) includes several OpenShift-specific enhancements:

#### **Hardcoded Metrics Authorizer**

The downstream version includes a hardcoded authorizer specifically for OpenShift monitoring:

```go
// pkg/hardcodedauthorizer/metrics.go
func (metricsAuthorizer) Authorize(ctx context.Context, a authorizer.Attributes) (authorized authorizer.Decision, reason string, err error) {
    if a.GetUser().GetName() != "system:serviceaccount:openshift-monitoring:prometheus-k8s" {
        return authorizer.DecisionNoOpinion, "", nil
    }
    if !a.IsResourceRequest() && a.GetVerb() == "get" && a.GetPath() == "/metrics" {
        return authorizer.DecisionAllow, "requesting metrics is allowed", nil
    }
    return authorizer.DecisionNoOpinion, "", nil
}
```

This authorizer:

- **Hardcodes permission** for the `system:serviceaccount:openshift-monitoring:prometheus-k8s` service account
- **Allows GET requests** to `/metrics` endpoint without additional RBAC checks
- **Reduces API server load** by avoiding SubjectAccessReview calls for Prometheus scraping
- **Temporary solution** until Cluster Monitoring Operator (CMO) implements static authorizer configuration

#### **OpenShift-specific Build Process**

- **Dockerfile.ocp**: Uses OpenShift-specific base images (`registry.ci.openshift.org/ocp/builder:rhel-9-golang-1.23-openshift-4.19`)
- **CI Integration**: Uses OpenShift CI/CD pipeline with `.ci-operator.yaml`
- **Vendored Dependencies**: Includes full vendor directory for offline builds complying with ART policies
- **OWNERS file**: OpenShift-specific maintainers and reviewers (Red Hat employees)

#### **Enhanced Testing**

- **Hardcoded authorizer tests**: Specific test scenarios for OpenShift monitoring integration
- **OpenShift namespace tests**: Tests using `openshift-monitoring` namespace
- **Service account validation**: Tests for `prometheus-k8s` service account access

#### **Authorization Chain Order**

The downstream version places the hardcoded authorizer first in the authorization chain:

```go
authorizer := union.New(
    // prefix the authorizer with the permissions for metrics scraping which are well known.
    // openshift RBAC policy will always allow this user to read metrics.
    // TODO: remove this, once CMO lands static authorizer configuration.
    hardcodedauthorizer.NewHardCodedMetricsAuthorizer(),
    staticAuthorizer,
    sarAuthorizer,
)
```

### Service Mesh Integration

- Works alongside Istio/Envoy for additional security layers
- Can be used as ingress point before service mesh
- Provides Kubernetes-native RBAC that service mesh may not support

### OpenShift OAuth Integration

- Can integrate with OpenShift's OAuth server for user authentication
- Supports OpenShift service account tokens
- Compatible with OpenShift RBAC policies

### Monitoring Stack Protection

- **Built-in Prometheus integration**: Downstream version includes hardcoded authorization for Prometheus
- Commonly used to protect Prometheus, Grafana, and other monitoring tools
- Enables fine-grained access control for metrics endpoints
- Supports multi-tenant monitoring scenarios

## Performance and Scalability

### Resource Usage

- Lightweight proxy with minimal overhead
- Memory usage scales with number of concurrent connections
- CPU usage primarily from cryptographic operations (TLS, JWT validation)

### Caching

- Built-in caching for authentication decisions (2-minute default TTL)
- Authorization decisions cached separately (5-minute allow, 30-second deny)
- Reduces load on Kubernetes API server

### HTTP/2 Support

- Native HTTP/2 support for both client and upstream connections
- Configurable connection limits and frame sizes
- Can force HTTP/2 cleartext (h2c) for upstream connections

## Troubleshooting

### Common Issues

1. **Authentication failures**: Check token validity and audience configuration
2. **Authorization denials**: Verify RBAC policies match resource attributes
3. **TLS errors**: Ensure certificate validity and CA configuration
4. **Upstream connection issues**: Verify upstream URL and network connectivity

### Debugging

```bash
# Enable verbose logging
--v=10 --logtostderr=true

# Check specific components
--auth-header-fields-enabled=true  # Debug header injection
--proxy-endpoints-port=8444        # Separate health check port
```

### Monitoring

- Built-in `/healthz` endpoint for health checks
- Prometheus metrics available (when properly configured)
- Structured logging for audit trails

## Future Considerations

### Project Status

- Currently in **alpha** stage with potential breaking changes
- Seeking acceptance as official Kubernetes project
- Active development with regular security updates

### Planned Changes

- Deprecation of some flags for Kubernetes alignment
- Enhanced security features
- Better integration with sig-auth standards

## Summary: Upstream vs OpenShift Fork

| Feature                    | Upstream (brancz/kube-rbac-proxy)                     | OpenShift Fork (openshift/kube-rbac-proxy)                    |
| -------------------------- | ----------------------------------------------------- | ------------------------------------------------------------- |
| **Core Functionality**     | Standard RBAC proxy with authentication/authorization | Same + OpenShift-specific enhancements                        |
| **Authorization Chain**    | Static → SAR authorizers                              | **Hardcoded** → Static → SAR authorizers                      |
| **Prometheus Integration** | Requires full RBAC configuration                      | **Hardcoded permission** for `prometheus-k8s` service account |
| **Build Process**          | Standard Go build with distroless images              | **OpenShift CI/CD** with RHEL-based images                    |
| **Dependencies**           | Standard go.mod dependencies                          | **Vendored dependencies** for offline builds                  |
| **Target Environment**     | Generic Kubernetes                                    | **OpenShift-optimized**                                       |
| **Maintenance**            | Community-driven                                      | **Red Hat OpenShift team**                                    |
| **Performance**            | Standard SubjectAccessReview for all requests         | **Optimized for Prometheus** (skips API calls)                |

### Key Takeaways

1. **The OpenShift fork is primarily optimized for monitoring use cases** with hardcoded permissions for Prometheus
2. **Both versions maintain the same core architecture** and API compatibility
3. **The hardcoded authorizer is a temporary optimization** until better static configuration is available
4. **OpenShift version includes enterprise build and security practices** (vendored deps, RHEL images, CI/CD)
5. **For non-OpenShift environments**, the upstream version is more appropriate
6. **For OpenShift monitoring stacks**, the downstream version provides better performance

This analysis is based on examination of both the upstream kube-rbac-proxy source code and the OpenShift downstream fork, providing a comprehensive understanding of their differences, capabilities, and usage patterns within Kubernetes and OpenShift environments.
