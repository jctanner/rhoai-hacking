# OpenShift Authentication Modes

This document outlines the different authentication modes available in OpenShift and how they interact with the integrated OAuth server and external identity providers.

## Overview

OpenShift supports multiple authentication architectures, controlled by the `Authentication` custom resource (`config.openshift.io/v1`) and feature gates. The authentication mode determines how users and clients authenticate with the cluster.

## Authentication Types

OpenShift supports three primary authentication types via `Authentication.spec.type`:

### 1. IntegratedOAuth (Default)

**Description**: Uses OpenShift's built-in OAuth server as an identity broker.

**Architecture**:

```
User/Client → OpenShift OAuth Server → External Identity Provider → OAuth Server → OpenShift Token
```

**Characteristics**:

- Default authentication mode
- OAuth server acts as identity broker/federation gateway
- Supports multiple identity providers simultaneously
- Issues OpenShift-specific tokens
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
User/Client → External Auth System → Webhook Token Authenticator → kube-apiserver
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

| Feature                | IntegratedOAuth   | OIDC             | None              |
| ---------------------- | ----------------- | ---------------- | ----------------- |
| **OAuth Server Role**  | Identity Broker   | Bypassed for API | Not Used          |
| **Token Type**         | OpenShift Tokens  | External JWT     | External/Webhook  |
| **Identity Providers** | Multiple          | Single OIDC      | External System   |
| **Feature Gate**       | None Required     | ExternalOIDC     | None Required     |
| **Claim Mapping**      | Basic             | Advanced (CEL)   | External System   |
| **Session Management** | OpenShift Managed | Provider Managed | External System   |
| **Upgrade Impact**     | Supported         | May Restrict     | Manual Management |

## Key Implementation Details

### Mutual Exclusion

- Authentication types are **mutually exclusive** per cluster
- Cannot mix `IntegratedOAuth` and `OIDC` for API authentication
- Switching types is a cluster-wide change

### OAuth Server Behavior

When switching from `IntegratedOAuth` to `OIDC`:

- OAuth server process **continues running**
- API authentication **bypasses** OAuth server
- Console/UI may **still use** OAuth server for web flows
- OAuth metadata endpoints may remain available

### Validation Rules

- `WebhookTokenAuthenticator` only allowed with `None` or `IntegratedOAuth` types
- OIDC providers only validated when `ExternalOIDC` feature gate is enabled
- Complex cross-validation ensures configuration consistency

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

## Migration Considerations

### From IntegratedOAuth to OIDC

1. Enable `ExternalOIDC` feature gate
2. Configure external OIDC provider
3. Update `Authentication.spec.type` to `OIDC`
4. Update client configurations to use external OIDC endpoints
5. Test authentication flows thoroughly

### Rollback Considerations

- Feature gate changes may be irreversible
- Token compatibility between modes
- User identity mapping preservation

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
