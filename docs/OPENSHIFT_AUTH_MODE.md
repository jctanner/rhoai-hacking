# OpenShift Authentication Modes

This document outlines the different authentication modes available in OpenShift and how they interact with the integrated OAuth server and external identity providers.

## Overview

OpenShift supports multiple authentication architectures, controlled by the `Authentication` custom resource (`config.openshift.io/v1`) and feature gates. The authentication mode determines how users and clients authenticate with the cluster.

## Architecture Overview

```mermaid
graph TB
    %% User/Client Entry Points
    User[User/Client]

    %% Authentication Mode Decision
    User --> AuthMode{Authentication Mode}

    %% IntegratedOAuth Mode
    AuthMode -->|IntegratedOAuth| OAuthServer[OpenShift OAuth Server]
    OAuthServer --> IdP[Identity Provider<br/>HTPasswd, LDAP, GitHub, etc.]
    IdP --> OAuthServer
    OAuthServer --> OSToken[OpenShift Token]

    %% Token Validation for IntegratedOAuth
    OSToken --> APIServer1[kube-apiserver]
    APIServer1 --> WebhookInternal[Internal Webhook<br/>webhook-authentication-integrated-oauth]
    WebhookInternal --> TokenReview1[TokenReview API]
    TokenReview1 --> OAuthServer
    OAuthServer --> ValidResponse1[Validation Response]
    ValidResponse1 --> APIServer1

    %% OIDC Mode
    AuthMode -->|OIDC Type| ExternalOIDC[External OIDC Provider]
    ExternalOIDC --> JWTToken[JWT Token]
    JWTToken --> APIServer2[kube-apiserver]
    APIServer2 --> DirectValidation[Direct JWT Validation<br/>No Webhook]
    DirectValidation --> APIServer2

    %% None Mode
    AuthMode -->|None Type| ExternalAuth[External Auth System]
    ExternalAuth --> ExtToken[External Token]
    ExtToken --> APIServer3[kube-apiserver]
    APIServer3 --> WebhookExternal[External Webhook<br/>Custom Configuration]
    WebhookExternal --> TokenReview2[TokenReview API]
    TokenReview2 --> ExternalValidator[External Validation Service]
    ExternalValidator --> ValidResponse2[Validation Response]
    ValidResponse2 --> APIServer3

    %% Final API Access
    APIServer1 --> APIAccess[API Resource Access]
    APIServer2 --> APIAccess
    APIServer3 --> APIAccess

    %% Feature Gate Control
    FeatureGate[ExternalOIDC<br/>Feature Gate] -.-> ExternalOIDC
    FeatureGate -.-> JWTToken

    %% Styling
    classDef userEntry fill:#e1f5fe
    classDef oauthComponents fill:#f3e5f5
    classDef oidcComponents fill:#fff3e0
    classDef noneComponents fill:#fce4ec
    classDef apiComponents fill:#e8f5e8
    classDef webhookComponents fill:#f0f4c3

    class User,AuthMode userEntry
    class OAuthServer,IdP,OSToken,WebhookInternal,TokenReview1,ValidResponse1 oauthComponents
    class ExternalOIDC,JWTToken,DirectValidation oidcComponents
    class ExternalAuth,ExtToken,WebhookExternal,TokenReview2,ExternalValidator,ValidResponse2 noneComponents
    class APIServer1,APIServer2,APIServer3,APIAccess apiComponents
    class WebhookInternal,WebhookExternal webhookComponents
```

## Authentication Types

OpenShift supports three primary authentication types via `Authentication.spec.type`:

### 1. IntegratedOAuth (Default)

**Description**: Uses OpenShift's built-in OAuth server as an identity broker.

**Architecture**:

```
User/Client → OpenShift OAuth Server → External Identity Provider → OAuth Server → OpenShift Token
Token Validation: Client → kube-apiserver → webhook-authentication-integrated-oauth → OAuth Server
```

**Characteristics**:

- Default authentication mode
- OAuth server acts as identity broker/federation gateway
- Supports multiple identity providers simultaneously
- Issues OpenShift-specific tokens
- kube-apiserver validates tokens via internal webhook to OAuth server
- Maintains user sessions and identity mapping
- Always available (no feature gate required)

**Configuration**: Via `OAuth` custom resource with identity providers:

```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
spec:
  identityProviders:
    - name: google-oidc
      type: OpenID
      openID:
        clientID: "your-client-id"
        clientSecret:
          name: google-secret
        issuer: "https://accounts.google.com"
```

### 2. OIDC (External OIDC)

**Description**: Direct integration with external OIDC providers, bypassing OpenShift's OAuth server for API authentication.

**Feature Gate**: Requires `ExternalOIDC` feature gate to be enabled.

**Architecture**:

```
User/Client → External OIDC Provider → JWT Token → Direct to kube-apiserver
```

**Characteristics**:

- Cloud-native OIDC standard compliance
- Direct JWT token usage from external providers
- Advanced claim mapping with CEL expressions
- Reduced authentication latency (no broker hop)
- Single external OIDC provider per cluster

**Configuration**: Via `Authentication` custom resource:

```yaml
apiVersion: config.openshift.io/v1
kind: Authentication
spec:
  type: OIDC
  oidcProviders:
    - name: external-oidc
      issuer: "https://your-oidc-provider.com"
      claimMappings:
        uid:
          claim: "sub"
```

### 3. None

**Description**: No cluster-managed authentication system. Requires external authentication infrastructure.

**⚠️ Advanced Configuration**: While technically configurable, this mode is rarely used in practice and requires significant expertise and external infrastructure.

**Architecture**:

```
User/Client → External Auth System → External Token
Token Validation: Client → kube-apiserver → External Webhook Authenticator → External Validation Service
```

**Characteristics**:

- Completely external authentication
- **Requires manual configuration** of external OAuth/OIDC systems
- **Must provide webhook token authenticators** for token validation via TokenReview API
- **Must configure external OAuth metadata** pointing to your authentication system
- Full control over authentication flow
- **No OpenShift-managed tokens** - all token lifecycle handled externally

**Prerequisites for Configuration**:

- External OAuth/OIDC server infrastructure
- Webhook token authenticator service
- OAuth metadata configuration
- Manual user identity management
- Custom token validation logic

**Typical Use Cases**:

- Air-gapped environments with existing enterprise authentication
- Highly regulated environments requiring external identity providers
- Custom authentication solutions that don't fit standard patterns
- Migration scenarios requiring temporary disabling of OpenShift auth

## Feature Gates

### ExternalOIDC

Controls availability of direct OIDC integration features:

**Enables**:

- `Authentication.spec.type: OIDC`
- `Authentication.spec.oidcProviders` field
- `Authentication.status.oidcClients` tracking

### ExternalOIDCWithUIDAndExtraClaimMappings

Extends ExternalOIDC with advanced claim mapping:

**Enables**:

- UID claim mapping with CEL expressions
- Extra claims mapping for custom attributes
- Complex token transformation rules

## Authentication Mode Comparison

| Feature                | IntegratedOAuth                   | OIDC                  | None              |
| ---------------------- | --------------------------------- | --------------------- | ----------------- |
| **OAuth Server Role**  | Identity Broker + Token Validator | Bypassed for API      | Not Used          |
| **Token Type**         | OpenShift Tokens                  | External JWT          | External/Webhook  |
| **Token Validation**   | Internal Webhook to OAuth         | Direct JWT Validation | External Webhook  |
| **Identity Providers** | Multiple                          | Single OIDC           | External System   |
| **Feature Gate**       | None Required                     | ExternalOIDC          | None Required     |
| **Claim Mapping**      | Basic                             | Advanced (CEL)        | External System   |
| **Session Management** | OpenShift Managed                 | Provider Managed      | External System   |
| **Upgrade Impact**     | Supported                         | May Restrict          | Manual Management |

## Key Implementation Details

### Mutual Exclusion

- Authentication types are **mutually exclusive** per cluster
- Cannot mix `IntegratedOAuth` and `OIDC` for API authentication
- Switching types is a cluster-wide change

### OAuth Server Behavior

When switching from `IntegratedOAuth` to `OIDC`:

- OAuth server process **continues running**
- API authentication **bypasses** OAuth server (no more internal webhook validation)
- kube-apiserver switches from webhook validation to direct JWT validation
- Console/UI may **still use** OAuth server for web flows
- OAuth metadata endpoints may remain available

### Validation Rules

- `WebhookTokenAuthenticator` allowed with `None` or `IntegratedOAuth` types (IntegratedOAuth uses internal webhook)
- OIDC providers only validated when `ExternalOIDC` feature gate is enabled
- Complex cross-validation ensures configuration consistency

### Real-World Configuration Example

A typical OpenShift cluster (like CRC) shows this configuration pattern:

```yaml
# Authentication resource (defaults)
apiVersion: config.openshift.io/v1
kind: Authentication
spec:
  type: ""  # Empty = IntegratedOAuth (default)
  webhookTokenAuthenticator:
    kubeConfig:
      name: webhook-authentication-integrated-oauth  # Internal webhook
status:
  integratedOAuthMetadata:
    name: oauth-openshift  # OAuth server metadata

# OAuth resource (identity providers)
apiVersion: config.openshift.io/v1
kind: OAuth
spec:
  identityProviders:
  - name: developer
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
```

## Feature Gate Control

Authentication features controlled by feature gates:

```yaml
# Example: Authentication resource with feature gate annotations
apiVersion: config.openshift.io/v1
kind: Authentication
metadata:
  annotations:
    # These fields only available with ExternalOIDC feature gate
spec:
  type: OIDC # +openshift:validation:FeatureGateAwareEnum
  oidcProviders: # +openshift:enable:FeatureGate=ExternalOIDC
    - name: provider
      claimMappings: # +openshift:enable:FeatureGate=ExternalOIDCWithUIDAndExtraClaimMappings
        uid:
          expression: "claims.sub" # CEL expression
```

## Security Implications

### IntegratedOAuth Security

- Centralized token management
- OpenShift-controlled token lifecycle
- Unified audit logging through OAuth server

### Direct OIDC Security

- External provider token validation
- JWT signature verification
- Direct provider trust relationship
- Advanced claim validation with CEL

## Troubleshooting

### Common Issues

1. **Feature gate not enabled**: OIDC type unavailable
2. **Configuration conflicts**: Webhook authenticators with OIDC type
3. **Token validation failures**: External OIDC connectivity issues
4. **Claim mapping errors**: CEL expression compilation failures

### Diagnostic Commands

```bash
# Check current authentication configuration
oc get authentication cluster -o yaml

# Check feature gate status
oc get featuregate cluster -o yaml

# Check OAuth configuration (IntegratedOAuth mode)
oc get oauth cluster -o yaml

# Check authentication admission controller logs
oc logs -n openshift-kube-apiserver <pod> | grep ValidateAuthentication
```

## References

- [OpenShift Authentication API](https://docs.openshift.com/container-platform/latest/rest_api/config_apis/authentication-config-openshift-io-v1.html)
- [Kubernetes Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- [OIDC Specification](https://openid.net/connect/)
- [CEL Expression Language](https://github.com/google/cel-spec)

---

_This document reflects the authentication architecture found in the OpenShift Kubernetes codebase as of the current analysis._
