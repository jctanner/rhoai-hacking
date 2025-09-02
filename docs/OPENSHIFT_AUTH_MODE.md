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

## ExternalOIDC Implementation Process

The implementation of ExternalOIDC involves a coordinated process between feature gates, custom resources, and cluster operators. This section details the step-by-step process and the components involved.

> **📖 Official Documentation**: The complete administrative procedure for configuring external OIDC authentication is documented in the [Red Hat OpenShift Container Platform 4.19 Authentication and Authorization Guide](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/authentication_and_authorization/external-auth). This section focuses on the technical implementation details and system orchestration that occurs behind the scenes.

```mermaid
sequenceDiagram
    participant Admin as Cluster Admin
    participant FG as FeatureGate CR
    participant Auth as Authentication CR
    participant CAO as cluster-authentication-operator
    participant CKAO as cluster-kube-apiserver-operator
    participant KAS as kube-apiserver
    participant OAuth as OAuth Server
    participant OIDC as External OIDC Provider

    Note over Admin, OIDC: Phase 1: Enable Feature Gate
    Admin->>FG: Update FeatureGate CR<br/>customFeatureGates:<br/>  - ExternalOIDC: Enabled
    FG->>CKAO: Feature gate change detected
    CKAO->>KAS: Restart kube-apiserver pods<br/>(enables OIDC API fields)

    Note over Admin, OIDC: Phase 2: Configure OIDC Authentication
    Admin->>Auth: Update Authentication CR<br/>spec.type: OIDC<br/>spec.oidcProviders: [...]
    Auth->>CAO: Authentication CR change detected
    CAO->>CAO: Validate OIDC configuration<br/>(discovery, claims, etc.)
    CAO->>KAS: Generate kube-apiserver config<br/>with OIDC authenticator
    CAO->>CKAO: Signal configuration change
    CKAO->>KAS: Rolling restart with new config

    Note over Admin, OIDC: Phase 3: Runtime Token Validation
    Admin->>KAS: kubectl request with OIDC token
    KAS->>OIDC: Validate JWT token<br/>(direct validation)
    OIDC-->>KAS: Token valid + claims
    KAS->>KAS: Apply CEL claim mappings<br/>(username, groups, uid)
    KAS-->>Admin: Authorized request response

    Note over OAuth: OAuth server continues running<br/>but bypassed for API auth
```

### Implementation Steps

#### Step 1: Feature Gate Enablement

**Admin Action:**

```yaml
# Update FeatureGate CR
apiVersion: config.openshift.io/v1
kind: FeatureGate
metadata:
  name: cluster
spec:
  customFeatureGates:
    - enabled: true
      name: ExternalOIDC
```

**System Response:**

- `cluster-kube-apiserver-operator` detects feature gate change
- Triggers rolling restart of kube-apiserver static pods
- New API fields become available in Authentication CR schema
- Admission controllers start accepting OIDC configurations

#### Step 2: Authentication Configuration

**Admin Action:**

```yaml
# Update Authentication CR
apiVersion: config.openshift.io/v1
kind: Authentication
metadata:
  name: cluster
spec:
  type: OIDC
  oidcProviders:
    - name: corporate-oidc
      issuer: https://oidc.corp.example.com
      audiences:
        - openshift-cluster
      claimMappings:
        username:
          expression: "claims.preferred_username"
        groups:
          expression: "claims.groups"
```

**System Response:**

- `cluster-authentication-operator` validates OIDC configuration
- Performs OIDC discovery against provider
- Generates kube-apiserver authentication configuration
- Creates necessary secrets and configmaps
- Triggers kube-apiserver reconfiguration

#### Step 3: kube-apiserver Reconfiguration

**Automatic Process:**

```yaml
# Generated kube-apiserver config includes:
authentication:
  oidc:
    issuerURL: https://oidc.corp.example.com
    clientID: openshift-cluster
    usernameClaim: preferred_username
    groupsClaim: groups
    # CEL claim mappings compiled into config
```

**System Actions:**

- `cluster-kube-apiserver-operator` detects config change
- Updates kube-apiserver static pod manifests
- Performs rolling restart of control plane nodes
- New authenticator chain includes OIDC token validator

**Rollout State Monitoring:**

The `cluster-authentication-operator` actively monitors the rollout to ensure OIDC is properly deployed across all control plane nodes before declaring success:

**File**: `pkg/controllers/common/external_oidc.go`

```go
// OIDCAvailable() function performs comprehensive rollout verification:
func (c *AuthConfigChecker) OIDCAvailable() (bool, error) {
    // 1. Verify Authentication CR has type: OIDC
    if auth.Spec.Type != configv1.AuthenticationTypeOIDC {
        return false, nil
    }

    // 2. Collect all active revisions across control plane nodes
    for _, nodeStatus := range kas.Status.NodeStatuses {
        observedRevisions.Insert(nodeStatus.CurrentRevision)
    }

    // 3. For each revision, verify OIDC configuration exists and is correct
    for _, revision := range observedRevisions.UnsortedList() {
        // Check auth-config-<revision> ConfigMap exists (OIDC provider config)
        // Check config-<revision> ConfigMap has proper kube-apiserver args:
        //   - oauthMetadataFile: ""                    (OAuth disabled)
        //   - NO authentication-token-webhook-config   (No OAuth webhook)
        //   - authentication-config: [auth-config.json] (OIDC enabled)
    }
}
```

**Safety Guarantees:**

- **Atomic Rollout**: Returns `false` until ALL nodes have proper OIDC configuration
- **No Mixed Modes**: Prevents scenarios where some nodes use OAuth, others OIDC
- **Configuration Consistency**: Every revision must have identical OIDC setup
- **Rollback Detection**: Immediately detects configuration inconsistencies

This explains why OIDC rollouts take several minutes - the system waits for every control plane node to successfully restart with validated OIDC configuration before considering the change complete.

#### Step 4: Runtime Token Flow

**Token Validation Process:**

1. **Client Request**: User sends request with OIDC JWT token
2. **Token Extraction**: kube-apiserver extracts bearer token
3. **OIDC Validation**: Direct validation against external provider
4. **Claim Processing**: Apply CEL expressions to map claims
5. **Authorization**: Standard RBAC authorization with mapped identity

### Key Components and Responsibilities

#### cluster-authentication-operator

**File**: `pkg/controllers/externaloidc/externaloidc_controller.go`

- Watches Authentication CR for OIDC configuration
- Validates OIDC provider connectivity and metadata
- Generates kube-apiserver authentication configuration
- Manages OIDC client secrets and certificates

#### cluster-kube-apiserver-operator

- Manages kube-apiserver static pod configuration
- Handles rolling restarts when authentication config changes
- Applies generated OIDC authenticator configuration

#### Admission Controllers

**File**: `openshift-kube-apiserver/admission/customresourcevalidation/authentication/validate_authentication.go`

- Validates OIDC provider configurations
- Compiles and validates CEL claim mapping expressions
- Enforces feature gate requirements for OIDC fields

### Configuration Validation

The system performs extensive validation during configuration:

```go
// CEL expression validation
func validateClaimMappings(mappings *configv1.ClaimMappings) error {
    // Compile CEL expressions for username, groups, uid mappings
    // Validate expression syntax and cost estimation
    // Ensure required claims are mappable
}

// OIDC provider validation
func validateOIDCProvider(provider *configv1.OIDCProvider) error {
    // Perform OIDC discovery
    // Validate issuer URL accessibility
    // Check supported algorithms and claims
}
```

### Rollback Process

**Disabling ExternalOIDC (Official Process):**

The [official Red Hat documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/authentication_and_authorization/external-auth#disabling-direct-authentication_external-auth) provides the supported method:

```bash
# Official command to disable external OIDC
oc patch authentication.config/cluster --type=merge -p='
spec:
  type: ""
  oidcProviders: null
'
```

**System Response:**

1. **Authentication CR updated**: `type` set to empty string (equivalent to `IntegratedOAuth`)
2. **OIDC providers removed**: `oidcProviders` field cleared
3. **kube-apiserver restart**: Removes OIDC authenticator from chain
4. **OAuth server**: Resumes handling API authentication via internal webhook
5. **Cluster rollout**: Wait for all nodes to update to new revision

**Feature Gate Disable (Advanced):**

1. **Update FeatureGate CR**: Set `ExternalOIDC: Disabled`
2. **API validation**: OIDC fields become invalid in Authentication CR
3. **Forced cleanup**: Any OIDC configuration must be removed first

> **⚠️ Note**: The official documentation recommends using the `oc patch` command method rather than directly editing the FeatureGate CR, as it provides a cleaner rollback path and proper validation.

## Programmatic Authentication Mode Detection

When building custom controllers that need to integrate with OpenShift's authentication system (e.g., deploying `kube-auth-proxy` instances), you need to programmatically determine the cluster's current authentication mode to configure the proxy with the correct parameters.

### Source of Truth

The **Authentication CR** (`authentication.config.openshift.io/v1`) is the definitive source of truth for determining the cluster's authentication mode. The logic mirrors what the `cluster-authentication-operator` uses internally.

### Go Code Implementation

```go
package main

import (
    "context"
    "fmt"

    configv1 "github.com/openshift/api/config/v1"
    configclient "github.com/openshift/client-go/config/clientset/versioned"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/rest"
)

type AuthenticationMode string

const (
    ModeIntegratedOAuth AuthenticationMode = "IntegratedOAuth"
    ModeOIDC            AuthenticationMode = "OIDC"
    ModeNone            AuthenticationMode = "None"
)

type AuthModeDetector struct {
    configClient configclient.Interface
}

func NewAuthModeDetector(config *rest.Config) (*AuthModeDetector, error) {
    configClient, err := configclient.NewForConfig(config)
    if err != nil {
        return nil, fmt.Errorf("creating config client: %w", err)
    }

    return &AuthModeDetector{
        configClient: configClient,
    }, nil
}

func (d *AuthModeDetector) GetAuthenticationMode(ctx context.Context) (AuthenticationMode, *configv1.Authentication, error) {
    // Get the cluster Authentication CR (always named "cluster")
    auth, err := d.configClient.ConfigV1().Authentications().Get(ctx, "cluster", metav1.GetOptions{})
    if err != nil {
        return "", nil, fmt.Errorf("getting authentication config: %w", err)
    }

    // Determine mode based on Authentication CR spec
    mode := d.determineMode(auth)
    return mode, auth, nil
}

func (d *AuthModeDetector) determineMode(auth *configv1.Authentication) AuthenticationMode {
    // Check explicit type field first
    switch auth.Spec.Type {
    case configv1.AuthenticationTypeOIDC:
        return ModeOIDC
    case configv1.AuthenticationTypeIntegratedOAuth, "":
        // Empty string is equivalent to IntegratedOAuth (default)
        return ModeIntegratedOAuth
    }

    // Advanced mode detection: check for webhook authenticator without OAuth metadata
    if auth.Spec.WebhookTokenAuthenticator != nil &&
       (auth.Spec.OAuthMetadata == nil || auth.Spec.OAuthMetadata.Name == "") {
        return ModeNone
    }

    // Default to IntegratedOAuth if unclear
    return ModeIntegratedOAuth
}

// GetProxyConfiguration returns the configuration needed for kube-auth-proxy
func (d *AuthModeDetector) GetProxyConfiguration(ctx context.Context) (*ProxyConfig, error) {
    mode, auth, err := d.GetAuthenticationMode(ctx)
    if err != nil {
        return nil, err
    }

    config := &ProxyConfig{
        Mode: mode,
    }

    switch mode {
    case ModeIntegratedOAuth:
        config.OAuthConfig = &OAuthProxyConfig{
            // Use OpenShift OAuth server endpoints
            AuthorizeURL:    "https://oauth-openshift.apps.<cluster-domain>/oauth/authorize",
            TokenURL:        "https://oauth-openshift.apps.<cluster-domain>/oauth/token",
            UserinfoURL:     "https://oauth-openshift.apps.<cluster-domain>/oauth/userinfo",
            IssuerURL:       auth.Status.IntegratedOAuthMetadata.Name, // From status
            ClientIDFile:    "/var/run/secrets/oauth/client-id",
            ClientSecretFile: "/var/run/secrets/oauth/client-secret",
        }

    case ModeOIDC:
        if len(auth.Spec.OIDCProviders) == 0 {
            return nil, fmt.Errorf("OIDC mode configured but no providers found")
        }

        // Use first OIDC provider (extend logic for multiple providers as needed)
        provider := auth.Spec.OIDCProviders[0]
        config.OIDCConfig = &OIDCProxyConfig{
            IssuerURL:       provider.Issuer.URL,
            ClientID:        provider.OIDCClients[0].ClientID, // Assumes client configured
            Audiences:       provider.Audiences,
            ClaimMappings:   provider.ClaimMappings,
        }

    case ModeNone:
        config.WebhookConfig = &WebhookProxyConfig{
            // Use external webhook authenticator
            WebhookConfigFile: "/etc/webhook/config",
            CacheTTL:         auth.Spec.WebhookTokenAuthenticator.KubeConfig.Name,
        }
    }

    return config, nil
}

// Configuration structures for kube-auth-proxy
type ProxyConfig struct {
    Mode          AuthenticationMode  `json:"mode"`
    OAuthConfig   *OAuthProxyConfig   `json:"oauth,omitempty"`
    OIDCConfig    *OIDCProxyConfig    `json:"oidc,omitempty"`
    WebhookConfig *WebhookProxyConfig `json:"webhook,omitempty"`
}

type OAuthProxyConfig struct {
    AuthorizeURL     string `json:"authorize_url"`
    TokenURL         string `json:"token_url"`
    UserinfoURL      string `json:"userinfo_url"`
    IssuerURL        string `json:"issuer_url"`
    ClientIDFile     string `json:"client_id_file"`
    ClientSecretFile string `json:"client_secret_file"`
}

type OIDCProxyConfig struct {
    IssuerURL     string                        `json:"issuer_url"`
    ClientID      string                        `json:"client_id"`
    Audiences     []string                      `json:"audiences"`
    ClaimMappings *configv1.ClaimMappings       `json:"claim_mappings,omitempty"`
}

type WebhookProxyConfig struct {
    WebhookConfigFile string `json:"webhook_config_file"`
    CacheTTL          string `json:"cache_ttl"`
}
```

### Usage Example

```go
func main() {
    // Get in-cluster config (or use kubeconfig for development)
    config, err := rest.InClusterConfig()
    if err != nil {
        panic(err)
    }

    detector, err := NewAuthModeDetector(config)
    if err != nil {
        panic(err)
    }

    ctx := context.Background()
    mode, auth, err := detector.GetAuthenticationMode(ctx)
    if err != nil {
        panic(err)
    }

    fmt.Printf("Cluster authentication mode: %s\n", mode)

    // Get proxy configuration
    proxyConfig, err := detector.GetProxyConfiguration(ctx)
    if err != nil {
        panic(err)
    }

    // Deploy kube-auth-proxy with appropriate configuration
    deployProxy(proxyConfig)
}
```

### Key Implementation Notes

#### **1. Authentication CR as Source of Truth**

- Always query `authentication.config.openshift.io/cluster` (name is always "cluster")
- The `spec.type` field is the primary indicator
- Empty `type` equals `IntegratedOAuth` (default behavior)

#### **2. Mode Detection Logic**

- **OIDC Mode**: `spec.type == "OIDC"` AND `spec.oidcProviders` populated
- **IntegratedOAuth Mode**: `spec.type == ""` OR `spec.type == "IntegratedOAuth"`
- **None Mode**: `spec.webhookTokenAuthenticator` set WITHOUT `spec.oauthMetadata`

#### **3. Configuration Extraction**

- **IntegratedOAuth**: Use `status.integratedOAuthMetadata` for issuer URL
- **OIDC**: Extract from `spec.oidcProviders[].issuer.url` and client configuration
- **None**: Use `spec.webhookTokenAuthenticator.kubeConfig` reference

#### **4. Rollout State Validation**

**Critical**: When `spec.type == "OIDC"`, you must verify the configuration has fully rolled out before deploying proxy instances. The Authentication CR may show OIDC mode, but kube-apiserver pods might still be restarting with the new configuration.

```go
// Add rollout validation to your AuthModeDetector
func (d *AuthModeDetector) IsOIDCFullyDeployed(ctx context.Context) (bool, error) {
    mode, auth, err := d.GetAuthenticationMode(ctx)
    if err != nil {
        return false, err
    }

    // Only relevant for OIDC mode
    if mode != ModeOIDC {
        return true, nil
    }

    // Get KubeAPIServer CR to check rollout status
    kasClient := d.configClient.OperatorV1().KubeAPIServers()
    kas, err := kasClient.Get(ctx, "cluster", metav1.GetOptions{})
    if err != nil {
        return false, fmt.Errorf("getting kubeapiserver status: %w", err)
    }

    // Collect all active revisions across control plane nodes
    observedRevisions := make(map[int32]bool)
    for _, nodeStatus := range kas.Status.NodeStatuses {
        observedRevisions[nodeStatus.CurrentRevision] = true
    }

    if len(observedRevisions) == 0 {
        return false, nil // No nodes reporting status yet
    }

    // Verify each revision has proper OIDC configuration
    coreClient, err := kubernetes.NewForConfig(d.restConfig)
    if err != nil {
        return false, err
    }

    for revision := range observedRevisions {
        // Check auth-config-<revision> ConfigMap exists (OIDC provider config)
        authConfigName := fmt.Sprintf("auth-config-%d", revision)
        _, err := coreClient.CoreV1().ConfigMaps("openshift-kube-apiserver").Get(
            ctx, authConfigName, metav1.GetOptions{})
        if errors.IsNotFound(err) {
            return false, nil // Rollout still in progress
        } else if err != nil {
            return false, fmt.Errorf("checking auth-config-%d: %w", revision, err)
        }

        // Check main config-<revision> has OIDC configuration
        configName := fmt.Sprintf("config-%d", revision)
        cm, err := coreClient.CoreV1().ConfigMaps("openshift-kube-apiserver").Get(
            ctx, configName, metav1.GetOptions{})
        if err != nil {
            return false, fmt.Errorf("checking config-%d: %w", revision, err)
        }

        configYaml := cm.Data["config.yaml"]

        // Validate OIDC-specific configuration is present
        if !strings.Contains(configYaml, `"oauthMetadataFile":""`) ||
           strings.Contains(configYaml, `"authentication-token-webhook-config-file":`) ||
           !strings.Contains(configYaml, `"authentication-config":["/etc/kubernetes/static-pod-resources/configmaps/auth-config/auth-config.json"]`) {
            return false, nil // This revision doesn't have OIDC config yet
        }
    }

    return true, nil // All revisions have proper OIDC configuration
}
```

#### **5. Controller Integration Pattern**

```go
func (r *YourController) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // Determine authentication mode
    mode, auth, err := r.authDetector.GetAuthenticationMode(ctx)
    if err != nil {
        return ctrl.Result{}, err
    }

    // For OIDC mode, wait for full rollout before proceeding
    if mode == ModeOIDC {
        fullyDeployed, err := r.authDetector.IsOIDCFullyDeployed(ctx)
        if err != nil {
            return ctrl.Result{}, err
        }

        if !fullyDeployed {
            r.Log.Info("OIDC configuration still rolling out, requeueing...")
            return ctrl.Result{RequeueAfter: time.Minute}, nil
        }
    }

    // Safe to deploy/configure kube-auth-proxy now
    proxyConfig, err := r.authDetector.GetProxyConfiguration(ctx)
    if err != nil {
        return ctrl.Result{}, err
    }

    return r.reconcileProxy(ctx, proxyConfig)
}
```

#### **6. Controller Setup Considerations**

Your custom controller should:

- **Watch Authentication CR** for changes using informers
- **Watch KubeAPIServer CR** for rollout status updates (OIDC mode only)
- **Requeue reconciliation** during OIDC rollouts instead of failing
- **Handle rollout coordination** similar to cluster-authentication-operator
- **Validate configuration** before deploying proxy instances
- **Implement proper backoff** for rollout waiting (avoid tight loops)

This approach ensures your `kube-auth-proxy` instances are only deployed after the cluster's authentication configuration has fully stabilized, preventing authentication failures during the transition period.

---

_This document reflects the authentication architecture found in the OpenShift Kubernetes codebase as of the current analysis._
