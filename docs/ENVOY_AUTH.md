# OpenShift Gateway API - OIDC/OAuth Authentication with Envoy Filters

## Overview

While simple authorization filters (like our `FOO: BAR` header example) can deny or allow traffic, Envoy provides much more sophisticated authentication capabilities including full **OIDC/OAuth flows** with external Identity Providers (IDPs).

Instead of just returning `403 Forbidden`, Envoy can:
- **Detect missing/invalid auth tokens**
- **Redirect users to external OIDC provider for authentication**
- **Handle OAuth callback and token exchange**
- **Set secure session cookies**
- **Validate JWT tokens on subsequent requests**

## Key Questions to Explore

1. **Can Envoy's OAuth filter work with Gateway API?**
2. **What OIDC configuration is required?** (realm, client ID, secret, etc.)
3. **How does the redirect flow work in practice?**
4. **Where are client secrets securely stored?**
5. **Integration with popular IDPs** (Keycloak, Auth0, Okta, etc.)
6. **Session management and token refresh**

## Envoy Authentication Filters Available

### 1. `envoy.filters.http.oauth2`
- **Purpose**: Full OAuth2/OIDC authentication flow
- **Capabilities**:
  - Redirects unauthenticated users to IDP
  - Handles OAuth callback and authorization code exchange
  - Sets secure HTTP-only cookies for session management
  - Validates existing sessions on subsequent requests
- **Configuration**: Requires IDP endpoints, client credentials, redirect URIs

### 2. `envoy.filters.http.jwt_authn`
- **Purpose**: JWT token validation (for APIs)
- **Capabilities**:
  - Validates JWT signatures against JWKS endpoints
  - Extracts and validates JWT claims
  - Works with Bearer tokens in Authorization header
- **Use Case**: APIs that expect JWT tokens (not interactive login)

### 3. `envoy.filters.http.ext_authz`
- **Purpose**: Delegate authentication to external service
- **Capabilities**:
  - Calls external auth service for every request
  - Can implement custom authentication logic
  - Supports both HTTP and gRPC auth services
- **Use Case**: Complex custom authentication logic

## Typical OIDC Configuration Requirements

For a full OIDC flow, you'd typically need:

```yaml
# Example configuration structure (not exact Envoy syntax)
oidc_config:
  # IDP Discovery
  issuer: "https://keycloak.example.com/realms/myrealm"
  discovery_endpoint: "https://keycloak.example.com/realms/myrealm/.well-known/openid_configuration"
  
  # Client Registration
  client_id: "gateway-client"
  client_secret: "supersecret123"  # Usually from Kubernetes Secret
  
  # OAuth Flow
  redirect_uri: "https://myapp.example.com/auth/callback"
  scopes: ["openid", "profile", "email"]
  
  # Session Management
  cookie_name: "auth-session"
  cookie_domain: ".example.com"
  session_timeout: "24h"
  
  # Token Validation
  jwks_uri: "https://keycloak.example.com/realms/myrealm/protocol/openid-connect/certs"
```

## Authentication Flow Example

### Scenario: User Accesses Protected Resource

1. **Initial Request**: User visits `https://myapp.example.com/protected`
   - No auth cookie present
   - Envoy OAuth filter detects unauthenticated request

2. **Redirect to IDP**: Envoy returns `302 Found`
   ```
   Location: https://keycloak.example.com/realms/myrealm/protocol/openid-connect/auth?
     client_id=gateway-client&
     redirect_uri=https://myapp.example.com/auth/callback&
     response_type=code&
     scope=openid+profile+email&
     state=random_state_value
   ```

3. **User Authentication**: User logs in at Keycloak
   - Username/password, MFA, social login, etc.
   - IDP validates credentials

4. **OAuth Callback**: IDP redirects back with authorization code
   ```
   GET https://myapp.example.com/auth/callback?
     code=authorization_code_value&
     state=random_state_value
   ```

5. **Token Exchange**: Envoy exchanges code for tokens
   ```bash
   POST https://keycloak.example.com/realms/myrealm/protocol/openid-connect/token
   Content-Type: application/x-www-form-urlencoded
   
   grant_type=authorization_code&
   code=authorization_code_value&
   client_id=gateway-client&
   client_secret=supersecret123&
   redirect_uri=https://myapp.example.com/auth/callback
   ```

6. **Session Creation**: Envoy receives tokens and creates session
   - Sets secure HTTP-only cookie: `auth-session=encrypted_session_data`
   - Redirects user to original URL: `https://myapp.example.com/protected`

7. **Subsequent Requests**: Cookie-based authentication
   - User's browser sends cookie with each request
   - Envoy validates session without IDP round-trip
   - Optional: Validates JWT if tokens are stored in session

## Security Considerations

### Client Secret Management
```yaml
# Kubernetes Secret for OIDC credentials
apiVersion: v1
kind: Secret
metadata:
  name: oidc-client-secret
  namespace: authztest
type: Opaque
data:
  client-id: Z2F0ZXdheS1jbGllbnQ=        # base64: gateway-client
  client-secret: c3VwZXJzZWNyZXQxMjM=    # base64: supersecret123
```

### Cookie Security
- **HTTP-Only**: Prevents XSS access to session cookies
- **Secure**: Only sent over HTTPS connections
- **SameSite**: CSRF protection
- **Domain/Path**: Proper scoping

### Token Storage Options
1. **Server-side sessions**: Envoy stores tokens, issues session ID cookie
2. **Client-side JWT**: Encrypted JWT cookie with tokens
3. **Hybrid**: Session cookie + JWT validation on backend APIs

## Integration with Popular IDPs

### Keycloak (Red Hat SSO)
```yaml
issuer: "https://keycloak.company.com/realms/employees"
# Excellent Kubernetes integration
# Supports custom themes, user federation, etc.
```

### Auth0
```yaml
issuer: "https://company.auth0.com/"
# SaaS-based, easy setup
# Good for startups and quick prototypes
```

### Okta
```yaml
issuer: "https://company.okta.com/oauth2/default"
# Enterprise SSO platform
# Strong compliance and security features
```

### Azure AD / Microsoft Entra
```yaml
issuer: "https://login.microsoftonline.com/{tenant-id}/v2.0"
# Microsoft ecosystem integration
# Office 365, Azure resources, etc.
```

### Google Identity
```yaml
issuer: "https://accounts.google.com"
# Consumer and workspace accounts
# Simple setup for Google ecosystem apps
```

## EnvoyFilter CR Configuration

Based on Envoy's official documentation, here's what the actual EnvoyFilter Custom Resource would look like for OIDC authentication:

### Basic OIDC EnvoyFilter Example

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: oidc-auth-filter
  namespace: authztest
spec:
  workloadSelector:
    labels:
      istio.io/gateway-name: authztest-gateway
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.oauth2
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.oauth2.v3.OAuth2
          config:
            # OAuth Server Endpoints
            token_endpoint:
              cluster: keycloak-cluster
              uri: /realms/myrealm/protocol/openid-connect/token
              timeout: 3s
            authorization_endpoint: "https://keycloak.example.com/realms/myrealm/protocol/openid-connect/auth"
            
            # Client Credentials (from Kubernetes Secret)
            credentials:
              client_id: "gateway-client"
              token_secret:
                name: "oauth-client-secret"
                sds_config:
                  path: "/etc/envoy/oauth-secrets.yaml"
              hmac_secret:
                name: "oauth-hmac-secret"
                sds_config:
                  path: "/etc/envoy/oauth-secrets.yaml"
            
            # OAuth Flow Configuration
            redirect_uri: "https://myapp.example.com/auth/callback"
            redirect_path_matcher:
              path:
                exact: "/auth/callback"
            signout_path:
              path:
                exact: "/auth/signout"
            
            # OAuth Scopes
            auth_scopes:
            - "openid"
            - "profile" 
            - "email"
            
            # Session Management
            forward_bearer_token: true
            
            # Allow some paths to bypass authentication
            pass_through_matcher:
            - name: "health-check"
              exact_match: "/health"
```

### Required Kubernetes Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: oauth-client-secret
  namespace: authztest
type: Opaque
data:
  # OAuth client secret (base64 encoded)
  oauth-client-secret: c3VwZXJzZWNyZXQxMjM=  # supersecret123
  # HMAC secret for cookie signing (base64 encoded)  
  oauth-hmac-secret: aG1hY3NlY3JldDQ1Ng==    # hmacsecret456
```

### Supporting Envoy Cluster Configuration

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: keycloak-cluster
  namespace: authztest
spec:
  workloadSelector:
    labels:
      istio.io/gateway-name: authztest-gateway
  configPatches:
  - applyTo: CLUSTER
    match:
      context: GATEWAY
    patch:
      operation: ADD
      value:
        name: keycloak-cluster
        type: LOGICAL_DNS
        connect_timeout: 5s
        lb_policy: ROUND_ROBIN
        load_assignment:
          cluster_name: keycloak-cluster
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: keycloak.example.com
                    port_value: 443
        transport_socket:
          name: envoy.transport_sockets.tls
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
            sni: keycloak.example.com
```

### Advanced Configuration Options

The OAuth2 filter supports many advanced features:

```yaml
config:
  # ... basic config above ...
  
  # Refresh Token Support
  use_refresh_token: true
  default_expires_in: 3600s  # 1 hour
  default_refresh_token_expires_in: 604800s  # 1 week
  
  # Custom Cookie Configuration  
  credentials:
    cookie_names:
      bearer_token: "MyAppAuthToken"
      oauth_hmac: "MyAppHMAC" 
      oauth_expires: "MyAppExpires"
      id_token: "MyAppIdToken"
      refresh_token: "MyAppRefreshToken"
    cookie_domain: ".example.com"  # For subdomain SSO
  
  # Cookie Security Settings
  cookie_configs:
    bearer_token_cookie_config:
      same_site: LAX
    oauth_hmac_cookie_config:
      same_site: STRICT
  
  # AJAX-Friendly Configuration
  deny_redirect_matcher:
  - name: "api-calls" 
    prefix: "/api/"
  - name: "ajax-header"
    headers:
    - name: "x-requested-with"
      exact_match: "XMLHttpRequest"
  
  # Disable certain cookie types if needed
  disable_id_token_set_cookie: false
  disable_access_token_set_cookie: false
  disable_refresh_token_set_cookie: false
```

## Secret Management with SDS

Instead of mounting secrets as files, you can use Kubernetes secrets directly:

```yaml
# OAuth secrets as SDS configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: oauth-sds-config
  namespace: authztest
data:
  oauth-secrets.yaml: |
    static_resources:
      secrets:
      - name: oauth-client-secret
        generic_secret:
          secret: "supersecret123"
      - name: oauth-hmac-secret  
        generic_secret:
          secret: "hmacsecret456"
```

## Next Steps: Proof of Concept

To validate OIDC authentication with Gateway API, we could create:

1. **OIDC-enabled Keycloak instance** (test IDP)
2. **EnvoyFilter with OAuth2 configuration** (shown above)
3. **Protected application** requiring authentication
4. **End-to-end authentication flow testing**

### Questions for POC Design:

1. **Which IDP should we use?** (Keycloak for self-contained testing?)
2. **Session storage strategy?** (Envoy-managed vs. external Redis?)
3. **Token validation approach?** (Cookie-only vs. JWT validation?)
4. **Multi-application SSO?** (Single domain vs. subdomain cookies?)

## Advantages Over Traditional Ingress

### Gateway API + Envoy OAuth Benefits:
- ✅ **No application changes** - authentication handled at gateway
- ✅ **Consistent security** - all apps get same auth flow
- ✅ **Performance** - local session validation after initial login
- ✅ **Flexibility** - different auth rules per route/domain
- ✅ **Observability** - centralized auth metrics and logging

### vs. Application-Level Authentication:
- ❌ **Every app needs auth code** - repetitive, error-prone
- ❌ **Inconsistent UX** - different login flows per app  
- ❌ **Security gaps** - apps might skip auth entirely
- ❌ **Token management** - each app handles tokens differently

## Architecture Deep Dive

### Request Flow with OIDC Authentication:

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│   Browser   │    │ OpenShift    │    │  Gateway    │    │     App      │
│             │    │   Route      │    │   + Envoy   │    │   Backend    │
└─────────────┘    └──────────────┘    └─────────────┘    └──────────────┘
        │                   │                   │                   │
        │ GET /protected    │                   │                   │
        │──────────────────►│                   │                   │
        │                   │ Forward request   │                   │
        │                   │──────────────────►│                   │
        │                   │                   │ No auth cookie    │
        │ 302 → IDP         │                   │ → redirect to IDP │
        │◄──────────────────│◄──────────────────│                   │
        │                   │                   │                   │
        │ Login at IDP...   │                   │                   │
        │                   │                   │                   │
        │ GET /callback?code│                   │                   │
        │──────────────────►│                   │                   │
        │                   │ Forward callback  │                   │
        │                   │──────────────────►│                   │
        │                   │                   │ Exchange code     │
        │                   │                   │ → set cookie      │
        │ 302 → /protected  │                   │ → redirect        │
        │◄──────────────────│◄──────────────────│                   │
        │                   │                   │                   │
        │ GET /protected    │                   │                   │
        │ Cookie: session   │                   │                   │
        │──────────────────►│                   │                   │
        │                   │ Forward + cookie  │                   │
        │                   │──────────────────►│                   │
        │                   │                   │ Validate session  │
        │                   │                   │ → forward request │
        │                   │                   │──────────────────►│
        │                   │                   │                   │
        │ 200 OK            │                   │ 200 OK            │
        │◄──────────────────│◄──────────────────│◄──────────────────│
```

---

*This document explores OIDC/OAuth authentication capabilities with OpenShift Gateway API and Envoy filters. The goal is to move beyond simple header-based authorization to full-featured identity provider integration.* 