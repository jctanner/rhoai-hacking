# BYOIDC WASM Plugin Design Document

## Project Overview

**Project Name**: BYOIDC WASM Plugin (Bring Your Own OIDC)  
**Purpose**: Enable integration of existing OIDC/OAuth authentication services with Istio Gateway API via WASM plugins  
**Status**: 🚧 Design Phase  
**Target Users**: Platform teams with existing authentication services who need Gateway API integration  

## Executive Summary

This project delivers a **custom WASM plugin** that acts as a bridge between **Istio Gateway API** and **existing OIDC/OAuth authentication services**, enabling reuse of proven authentication logic without migrating to ext_authz or EnvoyFilter approaches.

**Key Value Proposition**: Preserve existing authentication investments while gaining Gateway API portability and Istio's native WASM capabilities.

## Problem Statement

### Current Situation

**Scenario**: Organizations have existing `kube-auth-proxy` or similar services that:
- ✅ Handle OpenShift OAuth and OIDC authentication flows
- ✅ Return `302 Found` (redirect) or `200 OK` responses based on header inspection  
- ✅ Are battle-tested and working in production
- ✅ Integrate with organizational identity providers

### Constraints and Requirements

**Technical Constraints**:
- ❌ **Cannot use EnvoyFilter** (deprecated, vendor-specific)
- ❌ **Cannot use ext_authz** (organizational policy restrictions)
- ✅ **Must use WASM plugins** (Istio's preferred extension mechanism)
- ✅ **Must work with Gateway API** (portability requirement)

**Business Requirements**:
- 🎯 **Reuse existing auth service** - avoid rewriting working authentication logic
- 🎯 **Maintain auth flows** - preserve OAuth/OIDC redirect patterns  
- 🎯 **Gateway API compatibility** - work with standard Gateway/HTTPRoute resources
- 🎯 **Production readiness** - handle error cases, timeouts, monitoring

## Solution Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌────────────────────┐    ┌─────────────────┐
│   Client        │    │  Istio Gateway   │    │   WASM Plugin      │    │ Existing Auth   │
│                 │    │  (Gateway API)   │    │  (Our Solution)    │    │ Service         │
└─────────────────┘    └──────────────────┘    └────────────────────┘    └─────────────────┘
         │                        │                        │                        │
         │  1. HTTP Request       │                        │                        │
         │──────────────────────→ │                        │                        │
         │                        │  2. WASM Filter        │                        │
         │                        │──────────────────────→ │                        │
         │                        │                        │  3. dispatch_http_call │
         │                        │                        │──────────────────────→ │
         │                        │                        │  4. 200 OK / 302 Found│
         │                        │                        │ ←──────────────────────│
         │  5. Response (Allow    │  6. Forward / Redirect │                        │
         │     or Redirect)       │ ←──────────────────────│                        │
         │ ←──────────────────────│                        │                        │
```

### Core Components

#### 1. WASM Plugin (Our Implementation)
- **Language**: Rust (using proxy-wasm-rust-sdk)
- **Function**: HTTP client that calls existing auth service
- **Location**: Runs inside Istio's Envoy proxies
- **Configuration**: Via WasmPlugin CRD pluginConfig

#### 2. Existing Auth Service (Customer's)
- **Type**: HTTP service (e.g., kube-auth-proxy)
- **Interface**: GET `/auth/verify` endpoint
- **Response Patterns**: 
  - `200 OK` with user headers → Allow request
  - `302 Found` with Location header → Redirect to auth
  - `4xx/5xx` → Deny access

#### 3. Gateway API Resources
- **Gateway**: Entry point with TLS termination
- **HTTPRoute**: Routing rules with path-based auth requirements
- **WasmPlugin**: Istio CRD for WASM plugin deployment

## Technical Implementation

### WASM Plugin Core Logic

```rust
// Core HTTP interception and auth decision flow
impl HttpContext for AuthProxy {
    fn on_http_request_headers(&mut self) -> Action {
        // Extract headers needed for auth decision
        let auth_headers = vec![
            ("authorization", self.get_header("authorization")),
            ("cookie", self.get_header("cookie")),
            ("x-forwarded-user", self.get_header("x-forwarded-user")),
        ];
        
        // Make HTTP call to existing auth service
        match self.dispatch_http_call(
            "kube-auth-proxy",  // Cluster name
            vec![
                (":method", "GET"),
                (":path", "/auth/verify"),
                (":authority", "kube-auth-proxy.auth-system.svc.cluster.local"),
            ],
            None,  // No body
            vec![],  // Headers from original request
            Duration::from_secs(5),
        ) {
            Ok(_) => Action::Pause,  // Wait for response
            Err(_) => {
                // Fallback: deny on service error
                self.send_http_response(503, vec![], Some("Auth service unavailable"));
                Action::Pause
            }
        }
    }
    
    fn on_http_call_response(&mut self, _token_id: u32, _num_headers: usize, _body_size: usize, _num_trailers: usize) {
        // Handle response from auth service
        if let Some(status) = self.get_http_call_response_header(":status") {
            match status.as_str() {
                "200" => {
                    // Auth success - continue to upstream
                    if let Some(user) = self.get_http_call_response_header("x-auth-user") {
                        self.set_header("x-forwarded-user", &user);
                    }
                    self.resume_http_request();
                }
                "302" => {
                    // Auth redirect - return to client
                    if let Some(location) = self.get_http_call_response_header("location") {
                        self.send_http_response(
                            302, 
                            vec![("location", &location)], 
                            Some("Redirecting to auth")
                        );
                    }
                }
                _ => {
                    // Any other response = deny
                    self.send_http_response(403, vec![], Some("Access denied"));
                }
            }
        }
    }
}
```

### Configuration Schema

```rust
#[derive(Deserialize)]
struct PluginConfig {
    auth_service: AuthServiceConfig,
    routes: Vec<RouteConfig>,
    oauth_config: Option<OAuthConfig>,
    error_responses: Option<ErrorResponses>,
}

#[derive(Deserialize)]
struct AuthServiceConfig {
    endpoint: String,           // "http://kube-auth-proxy.auth-system.svc.cluster.local:8080"
    verify_path: String,        // "/auth/verify"  
    timeout: u64,               // 5000 (milliseconds)
}

#[derive(Deserialize)]
struct RouteConfig {
    path_prefix: String,        // "/public/", "/app/", "/admin/"
    auth_required: bool,        // true/false
    required_headers: Option<Vec<String>>, // ["x-admin-token"]
}

#[derive(Deserialize)] 
struct OAuthConfig {
    forward_oauth_headers: bool,      // true
    oauth_header_prefix: String,      // "x-forwarded-"
    oauth_redirect_base: String,      // "https://oauth-openshift.apps.cluster.local"
    oidc_issuer: Option<String>,      // "https://keycloak.company.com/realm"
}
```

### Deployment Configuration

#### WasmPlugin Resource

```yaml
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: byoidc-auth-plugin
  namespace: istio-system
spec:
  # Target Istio gateways
  selector:
    matchLabels:
      istio: ingressgateway
      
  # Authentication phase, high priority
  phase: AUTHN
  priority: 1000
  
  # OCI image containing our WASM binary
  url: oci://my-registry/byoidc-wasm-plugin:v1.0.0
  
  pluginConfig:
    # Auth service configuration
    auth_service:
      cluster_name: "outbound|8080||kube-auth-proxy.auth-system.svc.cluster.local"
      endpoint: "http://kube-auth-proxy.auth-system.svc.cluster.local:8080"
      verify_path: "/auth/verify"
      timeout: 5000
      
    # Route-based auth rules
    routes:
      - path_prefix: "/public/"
        auth_required: false
      - path_prefix: "/app/"  
        auth_required: true
      - path_prefix: "/admin/"
        auth_required: true
        required_headers: ["x-admin-token"]
        
    # OAuth/OIDC integration
    oauth_config:
      forward_oauth_headers: true
      oauth_header_prefix: "x-forwarded-"
      oauth_redirect_base: "https://oauth-openshift.apps.cluster.local"
      oidc_issuer: "https://keycloak.company.com/auth/realms/production"
      
    # Error handling
    error_responses:
      auth_service_error:
        status: 503
        body: '{"error": "authentication_service_unavailable"}'
      access_denied:
        status: 403
        body: '{"error": "access_denied"}'
```

#### Complete Gateway API Stack

```yaml
# 1. Existing Auth Service (Customer's)
apiVersion: v1
kind: Service
metadata:
  name: kube-auth-proxy
  namespace: auth-system
spec:
  selector:
    app: kube-auth-proxy
  ports:
  - port: 8080
    targetPort: 8080

---
# 2. Gateway API Entry Point
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: secure-gateway
  namespace: gateway-system
spec:
  gatewayClassName: istio
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "*.company.com"
    tls:
      mode: Terminate
      certificateRefs:
      - name: tls-cert

---
# 3. Application Routing
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: protected-apps
  namespace: gateway-system
spec:
  parentRefs:
  - name: secure-gateway
  
  hostnames:
  - "app.company.com"
  
  rules:
  # Public endpoints (no auth required)
  - matches:
    - path:
        type: PathPrefix
        value: "/public/"
    backendRefs:
    - name: public-service
      port: 8080
      
  # Protected endpoints (auth required via WASM plugin)
  - matches:
    - path:
        type: PathPrefix  
        value: "/app/"
    backendRefs:
    - name: protected-app
      port: 8080

---
# 4. Service Mesh Integration (if needed)
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: auth-service-entry
  namespace: istio-system
spec:
  hosts:
  - kube-auth-proxy.auth-system.svc.cluster.local
  ports:
  - number: 8080
    name: http
    protocol: HTTP
  resolution: DNS
  location: MESH_INTERNAL
```

## Request Flow Examples

### Successful Authentication Flow

```
1. Client Request:
   GET https://app.company.com/app/dashboard
   Cookie: session=abc123

2. Istio Gateway → WASM Plugin:
   - Plugin checks: "/app/" requires auth
   - Extracts Cookie header

3. WASM Plugin → Auth Service:
   GET http://kube-auth-proxy.auth-system.svc.cluster.local:8080/auth/verify
   Cookie: session=abc123

4. Auth Service Response:
   200 OK
   x-auth-user: alice
   x-auth-groups: admin,developers

5. WASM Plugin Processing:
   - Adds headers: x-forwarded-user: alice, x-forwarded-groups: admin,developers
   - Resumes request to upstream

6. Request Success:
   Request continues to protected-app with user context
```

### Authentication Required Flow

```
1. Client Request:
   GET https://app.company.com/app/dashboard
   (no auth headers)

2. WASM Plugin → Auth Service:
   GET http://kube-auth-proxy.auth-system.svc.cluster.local:8080/auth/verify
   (no auth headers)

3. Auth Service Response:
   302 Found
   Location: https://oauth-openshift.apps.cluster.local/oauth/authorize?client_id=...&redirect_uri=...

4. WASM Plugin Response:
   302 Found  
   Location: https://oauth-openshift.apps.cluster.local/oauth/authorize?client_id=...&redirect_uri=...

5. Client Redirect:
   Browser follows redirect to OAuth provider for authentication
```

## Build and Deployment Process

### Development Workflow

```bash
# 1. Setup development environment
rustup target add wasm32-unknown-unknown

# 2. Build WASM binary
cargo build --target wasm32-unknown-unknown --release

# 3. Create OCI image
docker build . -t my-registry/byoidc-wasm-plugin:v1.0.0

# 4. Push to registry
docker push my-registry/byoidc-wasm-plugin:v1.0.0

# 5. Deploy via Kubernetes
kubectl apply -f wasmplugin.yaml
```

### Project Structure

```
byoidc-wasm-plugin/
├── Cargo.toml                 # Rust dependencies
├── src/
│   ├── lib.rs                # Main plugin entry point
│   ├── config.rs             # Configuration parsing
│   ├── auth.rs               # Authentication logic  
│   └── http_client.rs        # dispatch_http_call wrapper
├── Dockerfile                # OCI image build
├── wasmplugin.yaml          # Kubernetes deployment
├── examples/
│   ├── complete-stack.yaml   # Full Gateway API example
│   └── test-requests.sh      # Testing scripts
└── README.md                # Getting started guide
```

## Testing Strategy

### Unit Tests

```bash
# Rust unit tests for core logic
cargo test

# WASM-specific testing with proxy-wasm-test-framework
cargo test --features test
```

### Integration Tests

```bash
# Test against real auth service
./examples/test-requests.sh

# Verify different response codes
curl -v -H "Cookie: invalid" https://app.company.com/app/dashboard  # Expect 302
curl -v -H "Cookie: valid_session" https://app.company.com/app/dashboard  # Expect 200
```

### Performance Tests

- **Latency Impact**: Measure auth call overhead
- **Throughput**: Requests per second with auth enabled
- **Memory Usage**: WASM plugin memory consumption
- **Error Handling**: Behavior under auth service outages

## Success Criteria

### Functional Requirements

✅ **Auth Integration**: Successfully call existing auth service and handle 200/302 responses  
✅ **Header Forwarding**: Pass through user/group information from auth service  
✅ **Route-based Auth**: Support path-based authentication requirements  
✅ **Error Handling**: Graceful fallback when auth service is unavailable  
✅ **OAuth Flow Preservation**: Maintain existing OAuth/OIDC redirect behavior  

### Non-Functional Requirements

⚡ **Performance**: < 10ms latency overhead per request  
🔒 **Security**: No credential leakage, secure default deny  
📈 **Reliability**: 99.9% auth call success rate  
🔧 **Maintainability**: Clear configuration schema, good error messages  
📊 **Observability**: Proper metrics and logging integration  

### Production Readiness Checklist

- [ ] **Security Review**: Credential handling, input validation
- [ ] **Performance Testing**: Load testing with realistic traffic  
- [ ] **Monitoring Setup**: Metrics, alerts, dashboards
- [ ] **Documentation**: Runbooks, troubleshooting guides
- [ ] **Rollback Plan**: Blue/green deployment strategy

## Development Guidelines

### Code Quality Standards

- **Rust Best Practices**: Follow Rust API guidelines
- **Error Handling**: Use Result<> types, no unwrap() in production code
- **Logging**: Structured logging with appropriate levels
- **Configuration Validation**: Fail fast on invalid config
- **Testing**: Unit tests for all core functions

### Monitoring and Observability

```rust
// Key metrics to expose
- byoidc_auth_requests_total{status="200|302|403|503"}
- byoidc_auth_request_duration_seconds
- byoidc_auth_service_errors_total
- byoidc_config_reload_total{status="success|error"}
```

### Development Tools

```bash
# Debug builds with logging
cargo build --target wasm32-unknown-unknown --features=debug

# Local testing with Envoy
envoy -c test-envoy-config.yaml

# WASM plugin inspection
wasm-objdump -h target/wasm32-unknown-unknown/release/byoidc_plugin.wasm
```

## Future Enhancements

### Phase 2 Features

1. **Multi-Auth Service Support**: Call different auth services based on hostname/path
2. **Caching Layer**: Cache auth decisions to reduce latency
3. **Advanced Routing**: Header-based auth requirements, regex path matching
4. **Metrics Dashboard**: Grafana dashboard for auth service integration
5. **A/B Testing**: Gradual rollout capabilities with traffic splitting

### Integration Opportunities

- **Service Mesh Policies**: Integration with Istio AuthorizationPolicy
- **External Secrets**: Secure credential management via External Secrets Operator
- **GitOps**: ArgoCD/Flux deployment patterns
- **Multi-Cluster**: Cross-cluster auth service federation

## Next Steps

### Immediate (Week 1-2)

1. **Project Setup**: Initialize Rust project with proxy-wasm-rust-sdk
2. **Core Implementation**: Basic HTTP dispatch and response handling
3. **Configuration Parsing**: WasmPlugin config deserialization
4. **Local Testing**: Test with standalone Envoy setup

### Short Term (Week 3-4)

1. **Istio Integration**: Test with real Istio Gateway API stack
2. **Error Handling**: Comprehensive error scenarios and fallbacks  
3. **Documentation**: API documentation and deployment guides
4. **CI/CD Pipeline**: Automated building and testing

### Medium Term (Month 2)

1. **Production Hardening**: Performance tuning, security review
2. **Monitoring Integration**: Metrics, logging, alerting setup
3. **User Acceptance Testing**: Test with real auth services and workloads
4. **Production Deployment**: Staged rollout with monitoring

---

**Document Version**: 1.0  
**Last Updated**: January 2025  
**Status**: ✅ Ready for Implementation  
**Next Review**: End of Phase 1 (Week 2)
