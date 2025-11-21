# OpenDataHub and Kuadrant Gateway Integration Compatibility Analysis

This document analyzes the current OpenDataHub (ODH) gateway implementation and explores compatibility with Kuadrant's policy-based API security platform.

## Table of Contents

1. [OpenDataHub Current Gateway Implementation](#opendatahub-current-gateway-implementation)
2. [Authentication Architecture](#authentication-architecture)
3. [EnvoyFilter Deep Dive](#envoyfilter-deep-dive)
4. [kube-auth-proxy Integration](#kube-auth-proxy-integration)
5. [Gateway API Resources](#gateway-api-resources)
6. [Compatibility Analysis](#compatibility-analysis)
7. [Migration Path](#migration-path)

---

## OpenDataHub Current Gateway Implementation

### Overview

OpenDataHub implements a custom gateway solution using:
- **Gateway API** (standard Kubernetes gateway resources)
- **Istio Gateway** (as the Gateway API provider)
- **kube-auth-proxy** (OAuth2 proxy for authentication)
- **EnvoyFilter** (Istio CRD for advanced Envoy configuration)

**Controller Location**: `./src/opendatahub-io/opendatahub-operator/internal/controller/services/gateway/`

### Controller Architecture

The gateway controller follows an action-based reconciliation pattern:

```go
// gateway_controller.go:129-136
WithAction(createGatewayInfrastructure).          // Core gateway setup
WithAction(createKubeAuthProxyInfrastructure).    // Authentication proxy
WithAction(createEnvoyFilter).                    // Service mesh integration
WithAction(createDestinationRule).                // Traffic management
WithAction(template.NewAction()).                 // Template rendering
WithAction(deploy.NewAction(deploy.WithCache())). // Resource deployment with caching
WithAction(syncGatewayConfigStatus).              // Status synchronization
WithAction(gc.NewAction())                        // Garbage collection
```

### Key Components Deployed

1. **GatewayClass** (`data-science-gateway-class`)
2. **Gateway** (`data-science-gateway` in `openshift-ingress` namespace)
3. **kube-auth-proxy** Deployment and Service
4. **EnvoyFilter** (for ext_authz integration)
5. **DestinationRule** (for TLS configuration)
6. **OAuthClient** (for OpenShift OAuth integration)
7. **HTTPRoute** (for OAuth callback)

---

## Authentication Architecture

### Authentication Modes

OpenDataHub supports two authentication modes:

#### 1. Integrated OpenShift OAuth
```yaml
apiVersion: services.opendatahub.io/v1alpha1
kind: GatewayConfig
metadata:
  name: default-gateway
spec:
  # Uses default OpenShift OAuth
  cookie:
    expire: "12h"    # Session duration
    refresh: "30m"   # Token refresh interval
```

#### 2. External OIDC Provider
```yaml
apiVersion: services.opendatahub.io/v1alpha1
kind: GatewayConfig
metadata:
  name: default-gateway
spec:
  oidc:
    issuerURL: "https://keycloak.example.com/realms/datascience"
    clientID: "data-science-apps"
    clientSecretRef:
      name: oidc-credentials
      key: clientSecret
  cookie:
    expire: "12h"
    refresh: "30m"
```

### Authentication Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Client Request                                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Envoy Gateway (Istio)                                    │
│                    (gateway.networking.k8s.io/v1)                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                  EnvoyFilter: ext_authz Filter                              │
│                  (Intercepts ALL requests)                                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│             External Authorization Call                                     │
│  https://kube-auth-proxy.openshift-ingress.svc.cluster.local:8443/oauth2/auth│
│                                                                             │
│  Forwards: Cookie header                                                   │
│  Returns: x-auth-request-user, x-auth-request-email,                       │
│           x-auth-request-access-token                                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
         ┌──────────────────┐          ┌──────────────────────┐
         │ Auth Failed      │          │ Auth Succeeded       │
         │ (401/302)        │          │ (200 OK)             │
         └──────────────────┘          └──────────────────────┘
                                                  │
                                                  ▼
                            ┌────────────────────────────────────┐
                            │  EnvoyFilter: Lua Filter           │
                            │  - Adds Authorization: Bearer      │
                            │  - Strips OAuth2 proxy cookies     │
                            │  - Forwards x-auth-request-* hdrs  │
                            └────────────────────────────────────┘
                                                  │
                                                  ▼
                            ┌────────────────────────────────────┐
                            │       Upstream Service             │
                            │    (Jupyter, Model Serving, etc)   │
                            └────────────────────────────────────┘
```

### OAuth Callback Flow

For initial authentication, ODH creates a dedicated HTTPRoute:

```yaml
# Simplified representation
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: oauth-callback
  namespace: openshift-ingress
spec:
  parentRefs:
  - name: data-science-gateway
  hostnames:
  - "*.apps.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /oauth2/callback
    backendRefs:
    - name: kube-auth-proxy
      port: 8443
```

**Callback Flow**:
1. User accesses protected route without auth cookie
2. ext_authz returns 302 redirect to OAuth provider
3. User authenticates with OAuth provider (OpenShift or OIDC)
4. OAuth provider redirects to `/oauth2/callback`
5. kube-auth-proxy handles callback, sets session cookie
6. User is redirected to original URL
7. Subsequent requests include auth cookie and pass ext_authz check

---

## EnvoyFilter Deep Dive

### Source
`./src/opendatahub-io/opendatahub-operator/internal/controller/services/gateway/resources/envoyfilter-authn.yaml`

The EnvoyFilter is the core integration mechanism between Gateway API and kube-auth-proxy. It consists of **three patches**:

### Patch 1: External Authorization (ext_authz) Filter

**Purpose**: Intercept all requests and validate authentication via kube-auth-proxy

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: authn-filter
  namespace: openshift-ingress
spec:
  workloadSelector:
    labels:
      gateway.networking.k8s.io/gateway-name: data-science-gateway
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
            subFilter:
              name: "envoy.filters.http.router"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.ext_authz
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
          transport_api_version: V3
          http_service:
            server_uri:
              uri: https://kube-auth-proxy.openshift-ingress.svc.cluster.local:8443/oauth2/auth
              cluster: kube-auth-proxy
              timeout: 5s  # Configurable via GatewayConfig.spec.authTimeout
            authorization_request:
              allowed_headers:
                patterns:
                - exact: cookie
            authorization_response:
              allowed_upstream_headers:
                patterns:
                - exact: x-auth-request-user
                - exact: x-auth-request-email
                - exact: x-auth-request-access-token
              allowed_client_headers:
                patterns:
                - exact: set-cookie
```

**Key Behaviors**:
- **Applies to**: Gateway workloads (selected by label `gateway.networking.k8s.io/gateway-name: data-science-gateway`)
- **Position**: Inserted BEFORE the router filter (all requests pass through it)
- **Authorization endpoint**: kube-auth-proxy's `/oauth2/auth` endpoint
- **Request headers forwarded**: `cookie` (for session validation)
- **Response headers to upstream**: `x-auth-request-user`, `x-auth-request-email`, `x-auth-request-access-token`
- **Response headers to client**: `set-cookie` (for setting auth cookies)
- **Timeout**: Configurable (default 5s), controlled by:
  1. `GatewayConfig.spec.authTimeout`
  2. Environment variable `GATEWAY_AUTH_TIMEOUT`
  3. Default: `"5s"`

**Code Reference**: `gateway_auth_actions.go:75-87`

### Patch 2: Lua Filter (Post-Authentication Processing)

**Purpose**: Transform authenticated requests before forwarding to upstream services

```yaml
- applyTo: HTTP_FILTER
  match:
    context: GATEWAY
    listener:
      filterChain:
        filter:
          name: "envoy.filters.network.http_connection_manager"
          subFilter:
            name: "envoy.filters.http.router"
  patch:
    operation: INSERT_BEFORE
    value:
      name: envoy.lua
      typed_config:
        "@type": "type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua"
        inline_code: |
          function envoy_on_request(request_handle)
            -- Extract access token from ext_authz response (set by ext_authz filter after auth)
            local access_token = request_handle:headers():get("x-auth-request-access-token")

            -- Only process requests that have been authenticated (have auth headers)
            -- This ensures we don't strip cookies during ext_authz call to auth proxy
            -- The presence of x-auth-request-access-token indicates authentication succeeded
            -- and we're now forwarding to upstream services, not to the auth proxy
            if access_token then
              -- Set headers for upstream services
              request_handle:headers():add("x-forwarded-access-token", access_token)
              request_handle:headers():replace("authorization", "Bearer " .. access_token)

              -- Strip OAuth2 proxy cookies only when forwarding to upstream services
              -- Cookie name is injected at runtime from OAuth2ProxyCookieName constant (gateway_support.go:75)
              -- Pattern matches cookies starting with the cookie name, handling variations like:
              --   - _oauth2_proxy (main cookie)
              --   - _oauth2_proxy_1, _oauth2_proxy_2 (split cookies if cookie size exceeds limits)
              local cookie_header = request_handle:headers():get("cookie")
              if cookie_header then
                local filtered_cookies = {}
                local cookie_pattern = "^_oauth2_proxy"  # Injected at runtime: {{.CookieName}}

                -- Parse and filter cookies in a single pass
                for cookie in cookie_header:gmatch("([^;]+)") do
                  -- Trim whitespace and extract cookie name
                  local trimmed = cookie:match("^%%s*(.-)%%s*$")
                  if trimmed ~= "" then
                    local cookie_name = trimmed:match("^([^=]+)")
                    -- Only keep cookies that don't match the OAuth2 proxy cookie pattern
                    if cookie_name and not cookie_name:match(cookie_pattern) then
                      table.insert(filtered_cookies, trimmed)
                    end
                  end
                end

                -- Update or remove Cookie header based on filtered results
                if #filtered_cookies > 0 then
                  request_handle:headers():replace("cookie", table.concat(filtered_cookies, "; "))
                else
                  request_handle:headers():remove("cookie")
                end
              end
            end
            -- If no auth token present, preserve cookies (needed for ext_authz authentication)
          end
```

**Key Behaviors**:
1. **Conditional Execution**: Only runs when `x-auth-request-access-token` is present
   - This header is set by ext_authz filter after successful authentication
   - Ensures cookies are NOT stripped during the ext_authz call to kube-auth-proxy

2. **Header Transformation**:
   - Adds `authorization: Bearer <token>` header (standard OAuth2 format)
   - Adds `x-forwarded-access-token: <token>` header (for compatibility)

3. **Cookie Stripping**:
   - Removes all cookies matching pattern `^_oauth2_proxy*`
   - Handles split cookies (`_oauth2_proxy_1`, `_oauth2_proxy_2`, etc.)
   - **Why?** Prevents OAuth session cookies from leaking to backend services
   - **Security benefit**: Backend services don't see authentication cookies

4. **Cookie Pattern Injection**:
   - Cookie name injected at runtime from Go constant
   - Code reference: `gateway_auth_actions.go:105` - `strings.ReplaceAll(yamlString, "{{.CookieName}}", OAuth2ProxyCookieName)`
   - Constant: `OAuth2ProxyCookieName = "_oauth2_proxy"` (defined in `gateway_support.go:75`)

### Patch 3: Cluster Definition (kube-auth-proxy cluster)

**Purpose**: Define the upstream cluster for ext_authz to call

```yaml
- applyTo: CLUSTER
  match:
    context: GATEWAY
  patch:
    operation: ADD
    value:
      name: kube-auth-proxy
      type: STRICT_DNS
      connect_timeout: 5s  # Configurable, same as auth timeout
      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
          common_tls_context:
            validation_context:
              trusted_ca:
                filename: /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt
          sni: kube-auth-proxy.openshift-ingress.svc.cluster.local
      load_assignment:
        cluster_name: kube-auth-proxy
        endpoints:
        - lb_endpoints:
          - endpoint:
              address:
                socket_address:
                  address: kube-auth-proxy.openshift-ingress.svc.cluster.local
                  port_value: 8443
```

**Key Behaviors**:
- **TLS Configuration**: Uses service-ca.crt for validating kube-auth-proxy's certificate
- **Service Name**: `kube-auth-proxy.openshift-ingress.svc.cluster.local`
- **Port**: 8443 (HTTPS)
- **DNS Type**: STRICT_DNS (resolved via Kubernetes DNS)
- **SNI**: Includes SNI for proper TLS certificate validation

**Code Reference**: `gateway_auth_actions.go:89-118`

### EnvoyFilter Application

The EnvoyFilter is created programmatically:

```go
// gateway_auth_actions.go:89-118
func createEnvoyFilter(ctx context.Context, rr *odhtypes.ReconciliationRequest) error {
    gatewayConfig, ok := rr.Instance.(*serviceApi.GatewayConfig)
    if !ok {
        return errors.New("instance is not of type *services.GatewayConfig")
    }

    authTimeout := getGatewayAuthTimeout(gatewayConfig)

    // using yaml templates due to complexity of k8s api struct for envoy filter
    yamlContent, err := gatewayResources.ReadFile("resources/envoyfilter-authn.yaml")
    if err != nil {
        return fmt.Errorf("failed to read EnvoyFilter template: %w", err)
    }

    yamlString := string(yamlContent)
    // Inject timeout values (2 occurrences: ext_authz timeout and cluster connect_timeout)
    yamlString = fmt.Sprintf(yamlString, authTimeout, authTimeout)
    // Inject cookie name pattern for Lua filter
    yamlString = strings.ReplaceAll(yamlString, "{{.CookieName}}", OAuth2ProxyCookieName)

    decoder := serializer.NewCodecFactory(rr.Client.Scheme()).UniversalDeserializer()
    unstructuredObjects, err := resources.Decode(decoder, []byte(yamlString))
    if err != nil {
        return fmt.Errorf("failed to decode EnvoyFilter YAML: %w", err)
    }

    if len(unstructuredObjects) != 1 {
        return fmt.Errorf("expected exactly 1 EnvoyFilter object, got %d", len(unstructuredObjects))
    }

    return rr.AddResources(&unstructuredObjects[0])
}
```

---

## kube-auth-proxy Integration

### Overview

**kube-auth-proxy** is a fork/variant of OAuth2 Proxy, customized for OpenDataHub's needs.

**Repository**: `./src/opendatahub-io/kube-auth-proxy`

### Deployment Architecture

**Namespace**: `openshift-ingress`

**Component**: Deployment + Service

### Deployment Configuration

**Code Reference**: `gateway_support.go:598-793`

```go
deployment := &appsv1.Deployment{
    ObjectMeta: metav1.ObjectMeta{
        Name:      "kube-auth-proxy",
        Namespace: "openshift-ingress",
        Labels:    map[string]string{
            "app": "kube-auth-proxy",
        },
    },
    Spec: appsv1.DeploymentSpec{
        Selector: &metav1.LabelSelector{
            MatchLabels: map[string]string{
                "app": "kube-auth-proxy",
            },
        },
        Template: corev1.PodTemplateSpec{
            ObjectMeta: metav1.ObjectMeta{
                Labels: map[string]string{
                    "app": "kube-auth-proxy",
                },
                Annotations: map[string]string{
                    "opendatahub.io/secret-hash": secretHash,  // Triggers pod restart on secret change
                },
            },
            Spec: corev1.PodSpec{
                SecurityContext: &corev1.PodSecurityContext{
                    RunAsNonRoot: ptr.To(true),
                    SeccompProfile: &corev1.SeccompProfile{
                        Type: corev1.SeccompProfileTypeRuntimeDefault,
                    },
                },
                Containers: []corev1.Container{
                    {
                        Name:  "kube-auth-proxy",
                        Image: getKubeAuthProxyImage(),  // Configurable via env
                        Ports: []corev1.ContainerPort{
                            {ContainerPort: 8080, Name: "http"},
                            {ContainerPort: 8443, Name: "https"},
                            {ContainerPort: 8444, Name: "metrics"},
                        },
                        // ... environment variables, volumes, security context
                    },
                },
            },
        },
    },
}
```

**Key Configuration**:
- **Image**: Controlled by `getKubeAuthProxyImage()` function (environment variable or default)
- **Ports**:
  - 8080: HTTP (internal)
  - 8443: HTTPS (used by ext_authz)
  - 8444: Metrics (Prometheus)
- **Security**:
  - Runs as non-root user
  - Read-only root filesystem
  - Dropped capabilities (ALL)
  - Seccomp profile: RuntimeDefault
- **Secret Hash Annotation**: Forces pod restart when secrets change

### Service Configuration

**Code Reference**: `gateway_support.go:794-822`

```go
service := &corev1.Service{
    ObjectMeta: metav1.ObjectMeta{
        Name:      "kube-auth-proxy",
        Namespace: "openshift-ingress",
        Labels:    map[string]string{
            "app": "kube-auth-proxy",
        },
        Annotations: map[string]string{
            // OpenShift service-ca operator auto-generates TLS certificate
            "service.beta.openshift.io/serving-cert-secret-name": "kube-auth-proxy-tls",
        },
    },
    Spec: corev1.ServiceSpec{
        Selector: map[string]string{
            "app": "kube-auth-proxy",
        },
        Ports: []corev1.ServicePort{
            {
                Name:       "https",
                Port:       8443,
                TargetPort: intstr.FromInt(8443),
            },
            {
                Name:       "metrics",
                Port:       8444,
                TargetPort: intstr.FromInt(8444),
            },
        },
    },
}
```

**Key Features**:
- **Automatic TLS**: Service-CA operator generates and rotates certificates
- **Secret Name**: `kube-auth-proxy-tls` (mounted by deployment)
- **Ports Exposed**:
  - 8443: HTTPS (primary authentication endpoint)
  - 8444: Metrics (monitoring)

### kube-auth-proxy Configuration

The proxy is configured via a Secret containing environment variables and configuration:

**Code Reference**: `gateway_support.go:515-597`

**Key Configuration Fields**:

1. **OAuth Provider**:
   - OpenShift OAuth: `--provider=openshift`
   - OIDC: `--provider=oidc` + `--oidc-issuer-url=<issuerURL>`

2. **Cookie Configuration**:
   - Name: `_oauth2_proxy` (constant)
   - Expire: Configurable via `GatewayConfig.spec.cookie.expire` (default: 24h)
   - Refresh: Configurable via `GatewayConfig.spec.cookie.refresh` (default: 1h)
   - Security: `--cookie-secure=true`, `--cookie-httponly=true`, `--cookie-samesite=lax`

3. **Upstream Configuration**:
   - Static upstream: `--upstream=static://200` (just validates auth, doesn't proxy)
   - Why? Envoy handles actual proxying to backends

4. **TLS Configuration**:
   - Certificate: Mounted from `kube-auth-proxy-tls` secret
   - Port: 8443

5. **Client Credentials**:
   - OpenShift: Auto-generated client secret
   - OIDC: User-provided via `GatewayConfig.spec.oidc.clientSecretRef`

### Environment Variables Injected

```yaml
# Simplified secret data structure
apiVersion: v1
kind: Secret
metadata:
  name: kube-auth-proxy-creds
  namespace: openshift-ingress
type: Opaque
stringData:
  # OAuth2 Proxy Configuration
  OAUTH2_PROXY_CLIENT_ID: "data-science-gateway"
  OAUTH2_PROXY_CLIENT_SECRET: "<generated-or-provided>"
  OAUTH2_PROXY_COOKIE_SECRET: "<generated-32-byte-secret>"

  # OIDC Configuration (if using external OIDC)
  OAUTH2_PROXY_OIDC_ISSUER_URL: "https://keycloak.example.com/realms/datascience"

  # Cookie Settings
  OAUTH2_PROXY_COOKIE_EXPIRE: "12h"
  OAUTH2_PROXY_COOKIE_REFRESH: "30m"
  OAUTH2_PROXY_COOKIE_NAME: "_oauth2_proxy"

  # Security
  OAUTH2_PROXY_COOKIE_SECURE: "true"
  OAUTH2_PROXY_COOKIE_HTTPONLY: "true"
  OAUTH2_PROXY_COOKIE_SAMESITE: "lax"

  # TLS
  OAUTH2_PROXY_HTTPS_ADDRESS: ":8443"
  OAUTH2_PROXY_TLS_CERT_FILE: "/etc/tls/private/tls.crt"
  OAUTH2_PROXY_TLS_KEY_FILE: "/etc/tls/private/tls.key"

  # Upstream (static, no actual proxying)
  OAUTH2_PROXY_UPSTREAM: "static://200"
```

---

## Gateway API Resources

### GatewayClass

**Code Reference**: `gateway.go` (implementation details)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: data-science-gateway-class
spec:
  controllerName: istio.io/gateway-controller
  description: Gateway class for OpenDataHub data science platform
```

**Key Details**:
- **Controller**: `istio.io/gateway-controller` (uses Istio as the Gateway API provider)
- **Single GatewayClass**: ODH uses one GatewayClass for all gateways

### Gateway

**Code Reference**: `gateway_controller_actions.go:66`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: data-science-gateway
  namespace: openshift-ingress
spec:
  gatewayClassName: data-science-gateway-class
  listeners:
  - name: https
    hostname: "*.apps.example.com"  # Derived from OpenShift ingress domain
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: gateway-tls-cert  # Certificate handling based on GatewayConfig.spec.certificate.type
        kind: Secret
    allowedRoutes:
      namespaces:
        from: All  # Allow HTTPRoutes from any namespace
```

**Certificate Types**:

1. **OpenshiftDefaultIngress** (default):
   - Uses OpenShift's default ingress wildcard certificate
   - Certificate: `router-certs-default` from `openshift-ingress` namespace
   - No additional configuration needed

2. **SelfSigned**:
   - Generates self-signed certificate for testing
   - Created by ODH operator
   - **Not for production**

3. **Provided**:
   - User provides certificate via `GatewayConfig.spec.certificate.secretName`
   - Secret must exist in `openshift-ingress` namespace
   - Must contain `tls.crt` and `tls.key`

**Code Reference**: `gateway_controller_actions.go:79-139`

### HTTPRoute (OAuth Callback)

**Code Reference**: `gateway_support.go:869-925`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: oauth-callback
  namespace: openshift-ingress
spec:
  parentRefs:
  - name: data-science-gateway
    namespace: openshift-ingress
  hostnames:
  - "*.apps.example.com"  # Matches gateway hostname
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /oauth2/callback
    backendRefs:
    - name: kube-auth-proxy
      port: 8443
  - matches:
    - path:
        type: PathPrefix
        value: /oauth2/sign_in
    backendRefs:
    - name: kube-auth-proxy
      port: 8443
  - matches:
    - path:
        type: PathPrefix
        value: /oauth2/auth
    backendRefs:
    - name: kube-auth-proxy
      port: 8443
```

**Purpose**: Routes OAuth-specific paths directly to kube-auth-proxy:
- `/oauth2/callback` - OAuth provider redirects here after authentication
- `/oauth2/sign_in` - Manual sign-in endpoint
- `/oauth2/auth` - Auth validation endpoint (called by ext_authz)

---

## Compatibility Analysis

### Current ODH Approach vs Kuadrant

| **Aspect** | **OpenDataHub (Current)** | **Kuadrant** | **Compatibility** |
|------------|---------------------------|--------------|-------------------|
| **Gateway API Provider** | Istio Gateway | Any (Istio, Envoy Gateway, etc.) | ✅ Compatible |
| **Browser Authentication** | EnvoyFilter + kube-auth-proxy (OAuth redirect flows) | AuthPolicy + Authorino (JWT validation only) | ❌ **NOT COMPATIBLE** - Authorino lacks OAuth redirect support |
| **API Authentication** | EnvoyFilter + kube-auth-proxy (token validation) | AuthPolicy + Authorino (JWT, API keys, mTLS) | ✅ Compatible for token-based auth |
| **Rate Limiting** | None (manual EnvoyFilter if needed) | RateLimitPolicy + Limitador | ✅ Kuadrant adds capability |
| **Policy Attachment** | Manual EnvoyFilter configuration | Declarative Policy CRDs | ⚠️ Migration needed |
| **Multi-Cluster** | Single cluster only | Multi-cluster with OCM | ✅ Kuadrant adds capability |
| **DNS Management** | Manual (OpenShift ingress) | DNSPolicy (automated) | ✅ Kuadrant adds capability |
| **TLS Management** | Manual or OpenShift service-ca | TLSPolicy + cert-manager | ✅ Kuadrant adds capability |
| **Configuration Model** | Imperative (controller-generated) | Declarative (user-defined policies) | ⚠️ Paradigm shift |

### Key Differences

#### 1. Authentication Architecture

**ODH Current**:
- Uses **EnvoyFilter** (Istio-specific CRD) to configure ext_authz
- **kube-auth-proxy** (OAuth2 Proxy fork) handles authentication
- Supports **OAuth redirect flows** for browser-based SSO
- Cookie-based session management
- Configuration hardcoded in controller
- Lua filter for post-auth header manipulation

**Kuadrant**:
- Uses **AuthPolicy** (standard Policy Attachment pattern)
- **Authorino** handles authentication
- **Does NOT support OAuth redirect flows** (stateless JWT validation only)
- No cookie-based session management
- Declarative configuration via CRD
- WASM Shim for request processing

**Impact**:
- ❌ **CRITICAL**: Authorino CANNOT replace kube-auth-proxy for browser-based authentication
- ❌ **Migration NOT viable** - Authorino doesn't support OAuth redirect flows or session cookies
- ⚠️ **Must keep kube-auth-proxy** for OpenDataHub's browser-based workloads (Jupyter, dashboards, etc.)
- ✅ Authorino could work for **API-only access** (if clients bring their own JWT tokens)

#### 2. Configuration Ownership

**ODH Current**:
- Gateway controller **generates** all configuration
- Users configure via `GatewayConfig` CRD
- Controller translates to Gateway API + EnvoyFilter resources
- Imperative: "controller decides how to implement requirements"

**Kuadrant**:
- Users **define policies directly**
- Kuadrant Operator translates policies to component-specific configs
- Declarative: "user specifies exactly what they want"

**Impact**:
- ⚠️ Requires rethinking user interface
- ⚠️ ODH users currently don't interact with policies directly
- ✅ More GitOps-friendly with Kuadrant

#### 3. EnvoyFilter Dependency

**ODH Current**:
- **Tightly coupled** to EnvoyFilter (Istio-specific)
- Cannot use other Gateway API providers (e.g., Envoy Gateway, Kong)
- Custom Lua scripts for cookie stripping

**Kuadrant**:
- **Provider-agnostic** (works with any Gateway API implementation)
- Uses WASM Shim (more portable than Lua)
- Supports both Istio and Envoy Gateway

**Impact**:
- ⚠️ ODH's EnvoyFilter approach locks into Istio
- ✅ Kuadrant provides more flexibility for future gateway choices

#### 4. Feature Gaps

**What ODH Has but Kuadrant Doesn't**:
- Integrated OpenShift OAuth support (kube-auth-proxy handles this seamlessly)
- Cookie-based session management with configurable expiry/refresh
- OAuth callback route handling

**What Kuadrant Has but ODH Doesn't**:
- Rate limiting (RateLimitPolicy + Limitador)
- Token-based rate limiting for AI/LLM workloads
- Multi-cluster gateway distribution
- Automated DNS management across clusters
- Declarative TLS certificate management
- Multiple authentication methods (JWT, API keys, mTLS, OPA, etc.)
- Authorization policies (beyond just authentication)

### Critical Limitation: Authorino Does NOT Support OAuth Redirect Flows

**IMPORTANT DISCOVERY**: Authorino cannot directly replace kube-auth-proxy for browser-based authentication.

#### Understanding the "OIDC Support" Confusion

**Why you might hear "Authorino supports OIDC":**

This is technically true, but ambiguous. There are **two different meanings** of "OIDC support":

**Meaning 1: OIDC Token Validation** ✅ (What Authorino DOES)
- Validates JWT tokens issued by OIDC providers
- Uses OIDC Discovery to fetch provider configuration
- Verifies token signatures using JWKS (JSON Web Key Sets)
- Can fetch additional user metadata from UserInfo endpoint
- **Use case**: APIs, service-to-service authentication, programmatic access

**Meaning 2: OIDC Authentication Flows** ❌ (What Authorino does NOT do)
- OAuth2 authorization code flow
- Redirecting users to login pages
- Handling OAuth callbacks
- Exchanging authorization codes for tokens
- Managing session cookies
- **Use case**: Browser-based web applications, transparent SSO

**Authorino's documentation says:**
> "Authorino validates JSON Web Tokens (JWT) issued by an OpenID Connect server that implements OpenID Connect Discovery"

**But also explicitly states:**
> "**Important!** Authorino does NOT implement OAuth2 grants nor OIDC authentication flows. As a common recommendation of good practice, obtaining and refreshing access tokens is for clients to negotiate directly with the auth servers and token issuers."

**For OpenDataHub:**
- **Need**: OIDC authentication flows (browser-based SSO for Jupyter, dashboards)
- **Authorino provides**: OIDC token validation only
- **Conclusion**: Authorino alone is insufficient; must keep kube-auth-proxy

#### What Authorino Does NOT Do

From Authorino's official documentation:
> "Authorino does not implement OAuth2 grants nor OIDC authentication flows. As a common recommendation of good practice, obtaining and refreshing access tokens is for clients to negotiate directly with the auth servers and token issuers. Authorino will only validate those tokens."

**Authorino CANNOT**:
- ❌ Redirect unauthenticated users to OIDC login pages
- ❌ Handle OAuth callbacks (`/oauth2/callback`)
- ❌ Exchange authorization codes for access tokens
- ❌ Manage session cookies
- ❌ Refresh expired tokens
- ❌ Initiate OAuth flows

**Authorino CAN ONLY**:
- ✅ Validate JWT tokens in `Authorization: Bearer <token>` header
- ✅ Verify token signatures using JWKS from OIDC issuer
- ✅ Check token expiration and claims
- ✅ Extract identity information for authorization decisions
- ✅ Fetch additional metadata from OIDC UserInfo endpoint (optional)

#### Authentication Flow Comparison

**kube-auth-proxy (Current ODH)**:
```
User (no cookie) → Gateway → ext_authz → kube-auth-proxy
                                              ↓
                                       "No valid cookie"
                                              ↓
                                       302 Redirect to OIDC provider
                                              ↓
User → OIDC Provider Login → Authenticate → Redirect to /oauth2/callback
                                              ↓
kube-auth-proxy receives callback → Exchange code for token → Set cookie
                                              ↓
User redirected to original URL (now with cookie)
                                              ↓
Subsequent requests: cookie validated by kube-auth-proxy
```

**Authorino (Kuadrant)**:
```
User → Gateway → ext_authz → Authorino
                                ↓
                         "Looking for Bearer token in Authorization header"
                                ↓
                         No token found → 401 Unauthorized
                                ↓
                         ❌ NO REDIRECT TO LOGIN PAGE
                         ❌ User sees error, not login prompt
```

#### Example: What You CANNOT Configure in Authorino

```yaml
# THIS DOES NOT EXIST IN AUTHORINO
apiVersion: authorino.kuadrant.io/v1beta3
kind: AuthConfig
metadata:
  name: oidc-redirect-auth  # ❌ NOT POSSIBLE
spec:
  hosts:
  - myapp.example.com
  authentication:
    "oidc-flow":
      oidc:  # ❌ This section doesn't exist
        issuerURL: https://keycloak.example.com/realms/myrealm
        clientID: my-client-id
        clientSecret: my-secret  # ❌ Authorino doesn't use client secrets
        redirectURL: https://myapp.example.com/oauth2/callback  # ❌ No redirect handling
        cookieName: _oauth2_proxy  # ❌ No cookie management
```

#### What You CAN Configure in Authorino (JWT Validation Only)

```yaml
# THIS IS WHAT ACTUALLY EXISTS
apiVersion: authorino.kuadrant.io/v1beta3
kind: AuthConfig
metadata:
  name: jwt-validation
spec:
  hosts:
  - myapp.example.com
  authentication:
    "keycloak-jwt":
      jwt:
        issuerUrl: https://keycloak.example.com/realms/myrealm
        # That's it. Authorino expects the user to already have a JWT token
        # in the Authorization: Bearer <token> header
  # Optional: fetch additional user info
  metadata:
    "userinfo":
      userInfo:
        identitySource: keycloak-jwt
```

**How Users Get Tokens**:
- Users must obtain tokens **outside** of Authorino (e.g., via Keycloak's login page, API calls, etc.)
- Applications must inject `Authorization: Bearer <token>` header
- **Not suitable for browser-based web applications** that expect transparent SSO

#### Implications for ODH

**For Browser-Based Applications** (Jupyter, model serving UIs, etc.):
- ❌ **Authorino CANNOT replace kube-auth-proxy**
- ✅ **Must keep kube-auth-proxy** (or similar OAuth2 proxy) for:
  - Redirect-based authentication flows
  - Session cookie management
  - OAuth callback handling
  - Token refresh

**For API-Based Applications** (programmatic access):
- ✅ **Authorino could work** if:
  - Clients obtain JWT tokens independently
  - Clients send `Authorization: Bearer <token>` header
  - No browser-based SSO required

#### Where to Configure OIDC Settings

**Answer**: You **cannot** configure redirect-based OIDC authentication in Kuadrant/Authorino. You must use an external OAuth2 proxy.

**If using Authorino for JWT validation only**, you configure:

```yaml
apiVersion: authorino.kuadrant.io/v1beta3
kind: AuthConfig
metadata:
  name: jwt-only
spec:
  authentication:
    "oidc-jwt-validation":
      jwt:
        issuerUrl: https://keycloak.example.com/realms/myrealm
        # No client ID, client secret, or redirect URL needed
        # Authorino just validates tokens using the issuer's public keys
```

But this requires users to get tokens some other way (not via browser redirect).

---

## Migration Path

**UPDATED BASED ON AUTHORINO LIMITATIONS**

### Option 1: Keep ODH Gateway, Add Kuadrant Policies

**Approach**: Run both systems side-by-side

**Architecture**:
```
Gateway API Gateway (Istio)
    │
    ├─ EnvoyFilter (ODH auth) ────> kube-auth-proxy
    │
    └─ AuthPolicy (Kuadrant) ────> Authorino
```

**Pros**:
- ✅ Non-disruptive migration
- ✅ Can test Kuadrant gradually
- ✅ Keep existing ODH authentication

**Cons**:
- ❌ Two authentication systems running
- ❌ Complexity in determining which policy applies
- ❌ Potential conflicts between EnvoyFilter and Kuadrant WASM Shim

**Feasibility**: ⚠️ **Challenging** - EnvoyFilter and Kuadrant both modify Envoy configuration, potential conflicts

---

### Option 2: Replace kube-auth-proxy with Authorino

**Approach**: ❌ **NOT VIABLE** - Authorino cannot replace kube-auth-proxy

**Why This Doesn't Work**:

Authorino **fundamentally cannot** replace kube-auth-proxy for browser-based authentication because:

1. **No OAuth Redirect Support**: Authorino does not implement OAuth2/OIDC flows
2. **No Cookie Management**: Cannot create or validate session cookies
3. **No Callback Handling**: Cannot handle `/oauth2/callback` endpoint
4. **Stateless Only**: Only validates existing JWT tokens, doesn't issue them

**What Would Be Required** (but doesn't exist in Authorino):
```yaml
# THIS IS NOT POSSIBLE WITH AUTHORINO
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: data-science-auth
  namespace: openshift-ingress
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: data-science-gateway
  rules:
    authentication:
      "openshift-oauth":
        oauth2:  # ❌ DOES NOT EXIST
          provider: openshift
          clientID: data-science-gateway
          clientSecret: <secret>
          redirectURL: /oauth2/callback
          cookieName: _oauth2_proxy
```

**What Authorino Actually Provides**:
```yaml
# This only validates tokens, doesn't create them
apiVersion: authorino.kuadrant.io/v1beta3
kind: AuthConfig
metadata:
  name: jwt-validation
spec:
  hosts:
  - "*.apps.example.com"
  authentication:
    "openshift-tokens":
      jwt:
        issuerUrl: https://kubernetes.default.svc  # Validates OpenShift service account tokens
        # But users must already have these tokens - Authorino won't redirect to get them
```

**Conclusion**:
- ❌ **Cannot eliminate kube-auth-proxy** when using Authorino
- ❌ **Not a viable migration path** for browser-based authentication
- ✅ **Could work for API-only access** if clients bring their own tokens

---

### Option 3: Hybrid Approach (ODH Auth + Kuadrant Features)

**Approach**: Keep ODH authentication, use Kuadrant for other features

**Architecture**:
```
Gateway API Gateway (Istio)
    │
    ├─ EnvoyFilter (ODH auth) ────> kube-auth-proxy
    │
    ├─ RateLimitPolicy (Kuadrant) ────> Limitador
    │
    └─ DNSPolicy (Kuadrant) ────> DNS Operator
```

**Implementation**:
1. Keep existing ODH gateway controller + EnvoyFilter + kube-auth-proxy
2. Add Kuadrant Operator (but not Authorino)
3. Use Kuadrant for:
   - Rate limiting (RateLimitPolicy)
   - DNS management (DNSPolicy)
   - TLS management (TLSPolicy)
4. Continue using ODH's EnvoyFilter for authentication

**Pros**:
- ✅ Non-disruptive (keeps existing auth working)
- ✅ Gains Kuadrant's rate limiting and multi-cluster features
- ✅ Incremental migration path
- ✅ Can migrate auth later when ready

**Cons**:
- ❌ Mixed architecture (some Kuadrant, some custom)
- ❌ Still tied to Istio (EnvoyFilter dependency)
- ❌ May have filter ordering issues (EnvoyFilter vs WASM Shim)

**Feasibility**: ✅ **Most Practical** - provides value without breaking existing deployments

---

### Recommended Approach

**REVISED: Based on Authorino's limitations, the recommended path is:**

**Phase 1: Hybrid Approach (Option 3) - ONLY VIABLE PATH**
1. **Keep kube-auth-proxy** for browser-based authentication
   - Cannot be replaced by Authorino
   - Required for OAuth redirect flows
   - Handles session cookies

2. **Add Kuadrant for non-authentication features**:
   - Deploy Kuadrant Operator + Limitador (NOT Authorino for now)
   - Use RateLimitPolicy for API rate limiting
   - Use DNSPolicy for multi-cluster DNS management
   - Use TLSPolicy for certificate lifecycle

3. **Validate coexistence**:
   - Test that EnvoyFilter (auth) and WASM Shim (rate limiting) work together
   - Document filter ordering and any conflicts
   - Measure performance impact

**Phase 2: Evaluate Authorino for API-Only Workloads** (Optional)
- For services that use API keys or Bearer tokens (not browser-based)
- Use AuthPolicy + Authorino for JWT validation
- Examples: Model serving APIs, programmatic notebook access

**Phase 3: Long-Term Architecture Decision**
- **Option A**: Keep hybrid (kube-auth-proxy + Kuadrant features)
  - Proven, stable, works today
  - Mixed architecture but functional

- **Option B**: Investigate OAuth2 Proxy integration with Kuadrant
  - Could Kuadrant integrate with OAuth2 Proxy instead of only Authorino?
  - Would require upstream Kuadrant feature request
  - Alternative: Run OAuth2 Proxy alongside Authorino (each for different routes)

- **Option C**: Frontend handles auth, pass tokens to Authorino
  - Browser apps get tokens from OIDC provider directly (PKCE flow)
  - Pass tokens in Authorization header
  - Authorino validates tokens
  - **Con**: More complex frontend, not transparent SSO

**Conclusion**: **Authorino cannot replace kube-auth-proxy**. The only viable path is keeping kube-auth-proxy and using Kuadrant for its other features (rate limiting, multi-cluster, DNS, TLS).

---

## Next Steps

**UPDATED: Removing infeasible investigations**

1. ~~**Investigate Authorino's OpenShift OAuth Support**~~ - **COMPLETED**: Authorino does NOT support OAuth redirect flows

2. **Test Kuadrant RateLimitPolicy with ODH Gateway**
   - Deploy Kuadrant Operator + Limitador in test environment
   - Create RateLimitPolicy targeting data-science-gateway
   - Validate that EnvoyFilter (ext_authz) and WASM Shim (rate limiting) coexist
   - Test filter ordering: ext_authz → rate limiting → upstream

3. **Analyze Filter Ordering and Compatibility**
   - Document Envoy filter chain with ODH's EnvoyFilter
   - Document Envoy filter chain with Kuadrant's WASM Shim
   - Identify potential conflicts or ordering issues
   - Verify both filters can apply to same gateway workload

4. **Test Multi-Cluster Features**
   - Deploy Kuadrant's multi-cluster gateway controller
   - Test DNSPolicy for multi-cluster DNS management
   - Validate TLSPolicy for certificate distribution
   - Verify kube-auth-proxy works across multiple gateway instances

5. ~~**Prototype AuthPolicy for OpenShift OAuth**~~ - **NOT APPLICABLE**: Authorino cannot handle OAuth redirect flows

6. **Evaluate API-Only Workloads**
   - Identify ODH services that could use token-based auth (not browser-based)
   - Test AuthPolicy + Authorino for model serving APIs
   - Compare with kube-auth-proxy for programmatic access

7. **Document Hybrid Architecture**
   - Create architecture diagrams showing kube-auth-proxy + Kuadrant coexistence
   - Document which features come from ODH vs Kuadrant
   - Provide configuration examples for common scenarios

8. **Upstream Engagement** (Long-term)
   - File Kuadrant issue/feature request for OAuth2 proxy integration
   - Explore if Kuadrant community has interest in redirect-based auth
   - Investigate alternative auth proxies compatible with Kuadrant

---

## References

- **OpenDataHub Operator**: `./src/opendatahub-io/opendatahub-operator/`
- **kube-auth-proxy**: `./src/opendatahub-io/kube-auth-proxy/`
- **Kuadrant Documentation**: `./rhoai-hacking/docs/KUADRANT.md`
- **Gateway API Spec**: https://gateway-api.sigs.k8s.io/
- **Istio Gateway API**: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/
