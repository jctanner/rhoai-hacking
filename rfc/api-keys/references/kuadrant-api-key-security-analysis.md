# Kuadrant API Key & Security Architecture Analysis

> **Source**: Analysis of Kuadrant/Authorino source code repositories
>
> **Date**: 2026-03-02
>
> **Repositories Examined**:
> - `github.com/kuadrant/authorino` (Authentication/Authorization Engine)
> - `github.com/kuadrant/kuadrant-operator` (Policy Orchestration)
> - `github.com/kuadrant/docs.kuadrant.io` (Documentation)

---

## Executive Summary

**Kuadrant** is a Kubernetes-native API management platform built on Gateway API and Envoy Proxy, offering authentication, authorization, rate limiting, DNS, and TLS management. It uses **Authorino** as its authentication/authorization engine.

## ⚠️ CRITICAL SECURITY FINDING

**API keys in Kuadrant/Authorino are stored in PLAINTEXT** in Kubernetes Secrets with **NO cryptographic hashing or encryption** at the application layer.

- ✅ **Performance**: <1ms validation via in-memory map lookup
- ❌ **Security**: Complete credential exposure if Kubernetes Secrets compromised
- ❌ **No hashing**: API keys stored as literal strings in Secret `data.api_key` field
- ❌ **Direct string comparison**: No constant-time comparison or hash verification

**Security Model**: Kubernetes RBAC and etcd encryption-at-rest (optional) rather than application-layer cryptographic protection.

---

## 1. Architecture Overview

### 1.1 Component Stack

```
┌─────────────────────────────────────────────────────────────┐
│                     API CONSUMER                             │
│                (Client with API Key)                         │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP Request (API Key in header)
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                  ENVOY PROXY / ISTIO                         │
│              (Gateway API Implementation)                    │
└────────────────────────┬────────────────────────────────────┘
                         │ gRPC External Auth Request
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    AUTHORINO                                 │
│            (Authentication/Authorization Service)            │
│                                                              │
│  ┌──────────────────────────────────────────────────┐       │
│  │  Auth Pipeline (5 phases):                       │       │
│  │  1. Authentication (identity verification)       │       │
│  │  2. Metadata (external data fetching)            │       │
│  │  3. Authorization (policy enforcement)           │       │
│  │  4. Response (dynamic headers/metadata)          │       │
│  │  5. Callbacks (HTTP notifications)               │       │
│  └──────────────────────────────────────────────────┘       │
│                         │                                    │
│                         ↓                                    │
│            ┌────────────────────────┐                        │
│            │  In-Memory API Key     │                        │
│            │  Cache (plaintext)     │                        │
│            │  map[string]Secret     │                        │
│            └────────────────────────┘                        │
└─────────────────────────┬──────────────────────────────────┘
                          │ Watches for Secret updates
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                KUBERNETES SECRETS                            │
│                                                              │
│  apiVersion: v1                                              │
│  kind: Secret                                                │
│  data:                                                       │
│    api_key: bmR5Qnpy...  (base64, decoded = plaintext)      │
└─────────────────────────────────────────────────────────────┘
                          │ (if enabled)
                          ↓
                 etcd encryption-at-rest
```

### 1.2 Key Components

| Component | Technology | Purpose | API Keys Role |
|-----------|-----------|---------|---------------|
| **Kuadrant Operator** | Go, controller-runtime | Policy orchestration, Gateway API integration | Creates AuthPolicy CRDs |
| **Authorino** | Go, gRPC | Envoy external authorization service | Validates API keys |
| **Gateway Provider** | Istio or Envoy Gateway | Ingress traffic management | Calls Authorino for auth |
| **Limitador** | Rust | Rate limiting engine | Can use identity from API key auth |
| **Kubernetes Secrets** | Kubernetes API | Credential storage | **Stores plaintext API keys** |

---

## 2. API Key Authentication Implementation

### 2.1 Creating API Keys

API keys are represented as Kubernetes Secrets with specific labels and structure.

**Example Secret**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: user-1-api-key
  namespace: my-app
  labels:
    authorino.kuadrant.io/managed-by: authorino  # Required for Authorino to watch
    group: friends                                # Custom label for selector matching
type: Opaque
stringData:
  api_key: ndyBzreUzF4zqDQsqSPMHkRhriEOtcRx      # PLAINTEXT API KEY
```

**Secret Requirements**:
1. **Mandatory `api_key` entry**: Must contain the literal API key value
2. **Managed-by label**: Must match Authorino's `--secret-label-selector` (default: `authorino.kuadrant.io/managed-by=authorino`)
3. **Selector labels**: Must match the `spec.authentication.apiKey.selector` in AuthConfig/AuthPolicy
4. **Namespace**: Must be in same namespace as AuthConfig, OR `allNamespaces: true` for cluster-wide Authorino

### 2.2 Declaring Authentication in AuthPolicy

**AuthPolicy (Kuadrant)**:
```yaml
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: my-api-protection
  namespace: my-app
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: my-route
  rules:
    authentication:
      "api-key-users":
        apiKey:
          selector:
            matchLabels:
              group: friends              # Matches Secret labels
          allNamespaces: false             # Only watch secrets in same namespace
        credentials:
          authorizationHeader:
            prefix: APIKEY                 # Extract from "Authorization: APIKEY <key>"
```

**AuthConfig (Authorino native)**:
```yaml
apiVersion: authorino.kuadrant.io/v1beta3
kind: AuthConfig
metadata:
  name: talker-api-protection
spec:
  hosts:
  - my-api.example.com
  authentication:
    "friends":
      apiKey:
        selector:
          matchLabels:
            group: friends
      credentials:
        authorizationHeader:
          prefix: APIKEY
```

### 2.3 API Key Validation Flow

**Request Path**:
```
1. Client → Envoy
   GET /api/resource HTTP/1.1
   Host: my-api.example.com
   Authorization: APIKEY ndyBzreUzF4zqDQsqSPMHkRhriEOtcRx

2. Envoy → Authorino (gRPC External Auth)
   CheckRequest {
     attributes: {
       request: {
         http: {
           method: "GET",
           path: "/api/resource",
           headers: {"authorization": "APIKEY ndyBzreUzF4zqDQsqSPMHkRhriEOtcRx"}
         }
       }
     }
   }

3. Authorino validates:
   a. Extract credential: "ndyBzreUzF4zqDQsqSPMHkRhriEOtcRx"
   b. Look up in cached secrets map
   c. Direct string comparison (see source code below)

4. Authorino → Envoy
   CheckResponse { status: { code: 0 } }  # OK = 0, DENIED = 7

5. Envoy → Upstream (if authorized)
   GET /api/resource HTTP/1.1
   (with optional injected headers from Authorino)
```

---

## 3. Source Code Analysis: Plaintext Storage & Validation

### 3.1 API Key Storage Implementation

**File**: `pkg/evaluators/identity/api_key.go`

**Data Structure** (Lines 23-33):
```go
type APIKey struct {
	auth.AuthCredentials

	Name           string              `yaml:"name"`
	LabelSelectors k8s_labels.Selector `yaml:"labelSelectors"`
	Namespace      string              `yaml:"namespace"`

	secrets   map[string]k8s.Secret   // ⚠️ PLAINTEXT map: key=API key value, value=Secret
	mutex     sync.RWMutex            // Thread safety for concurrent access
	k8sClient k8s_client.Reader       // Kubernetes API client
}
```

**Loading Secrets from Kubernetes** (Lines 51-69):
```go
func (a *APIKey) loadSecrets(ctx context.Context) error {
	opts := []k8s_client.ListOption{k8s_client.MatchingLabelsSelector{Selector: a.LabelSelectors}}
	if namespace := a.Namespace; namespace != "" {
		opts = append(opts, k8s_client.InNamespace(namespace))
	}
	var secretList = &k8s.SecretList{}
	if err := a.k8sClient.List(ctx, secretList, opts...); err != nil {
		return err
	}

	a.mutex.Lock()
	defer a.mutex.Unlock()

	for _, secret := range secretList.Items {
		a.appendK8sSecretBasedIdentity(secret)  // Loads plaintext keys into map
	}

	return nil
}
```

**Storing Plaintext Keys in Map** (Lines 147-154):
```go
// Appends the K8s Secret to the cache of API keys
// Caution! This function is not thread-safe. Make sure to acquire a lock before calling it.
func (a *APIKey) appendK8sSecretBasedIdentity(secret k8s.Secret) bool {
	value, isAPIKeySecret := secret.Data[apiKeySelector]  // apiKeySelector = "api_key"
	if isAPIKeySecret && len(value) > 0 {
		a.secrets[string(value)] = secret  // ⚠️ PLAINTEXT key as map key!
		return true
	}
	return false
}
```

### 3.2 API Key Validation (Direct String Comparison)

**File**: `pkg/evaluators/identity/api_key.go` (Lines 72-86)

```go
// Call will evaluate the credentials within the request against the authorized ones
func (a *APIKey) Call(pipeline auth.AuthPipeline, _ context.Context) (interface{}, error) {
	// Extract API key from request
	if reqKey, err := a.GetCredentialsFromReq(pipeline.GetHttp()); err != nil {
		return nil, err
	} else {
		a.mutex.RLock()
		defer a.mutex.RUnlock()

		// ⚠️ DIRECT STRING COMPARISON - NO HASHING!
		for key, secret := range a.secrets {
			if key == reqKey {  // Simple string equality check
				return secret, nil
			}
		}
	}
	return nil, errors.New(invalidApiKeyMsg)  // "the API Key provided is invalid"
}
```

**Validation Logic**:
1. **No hashing**: API key value from request compared directly to plaintext cached keys
2. **No constant-time comparison**: Standard Go `==` operator (vulnerable to timing attacks)
3. **No hash verification**: No BCrypt, Argon2, or PBKDF2 involved
4. **In-memory cache**: All valid API keys held in plaintext in process memory

### 3.3 Dynamic Secret Updates

**File**: `pkg/evaluators/identity/api_key.go` (Lines 94-122)

Authorino watches for Secret changes and updates the in-memory cache dynamically:

```go
func (a *APIKey) AddK8sSecretBasedIdentity(ctx context.Context, new k8s.Secret) {
	if !a.withinScope(new.GetNamespace()) {
		return
	}

	a.mutex.Lock()
	defer a.mutex.Unlock()

	logger := log.FromContext(ctx).WithName("apikey")

	// updating existing
	newAPIKeyValue := string(new.Data[apiKeySelector])
	for oldAPIKeyValue, current := range a.secrets {
		if current.GetNamespace() == new.GetNamespace() && current.GetName() == new.GetName() {
			if oldAPIKeyValue != newAPIKeyValue {
				a.appendK8sSecretBasedIdentity(new)
				delete(a.secrets, oldAPIKeyValue)
				logger.V(1).Info("api key updated")
			} else {
				logger.V(1).Info("api key unchanged")
			}
			return
		}
	}

	if a.appendK8sSecretBasedIdentity(new) {
		logger.V(1).Info("api key added")
	}
}
```

**Implications**:
- API keys can be rotated by updating the Secret (no downtime)
- Changes propagate to Authorino's cache within seconds
- Old key immediately removed from map (instant revocation)

### 3.4 API Key Revocation

**File**: `pkg/evaluators/identity/api_key.go` (Lines 124-139)

```go
func (a *APIKey) RevokeK8sSecretBasedIdentity(ctx context.Context, deleted k8s_types.NamespacedName) {
	if !a.withinScope(deleted.Namespace) {
		return
	}

	a.mutex.Lock()
	defer a.mutex.Unlock()

	for key, secret := range a.secrets {
		if secret.GetNamespace() == deleted.Namespace && secret.GetName() == deleted.Name {
			delete(a.secrets, key)  // Remove from cache immediately
			log.FromContext(ctx).WithName("apikey").V(1).Info("api key deleted")
			return
		}
	}
}
```

**Revocation**: Deleting the Secret instantly revokes access (removed from cache).

---

## 4. Security Model Analysis

### 4.1 Storage Layers (All Plaintext)

| Layer | Technology | Credential Format | Protection Mechanism |
|-------|-----------|-------------------|----------------------|
| **Authorino Process Memory** | Go map[string]Secret | Plaintext string keys | Process isolation only |
| **Kubernetes Secret** | etcd key-value store | Base64-encoded plaintext | Kubernetes RBAC, optional etcd encryption-at-rest |
| **etcd Storage** | Raft-replicated KV | Plaintext or encrypted (if enabled) | etcd encryption-at-rest (operator must enable) |
| **Backup/Snapshots** | etcd snapshot files | Same as etcd storage | Filesystem encryption, access control |

**Base64 Encoding ≠ Encryption**:
```yaml
stringData:
  api_key: ndyBzreUzF4zqDQsqSPMHkRhriEOtcRx  # Human-readable input

# Stored in etcd as:
data:
  api_key: bmR5Qnpyc1V6RjR6cURRc3FTUE1Ia1JocmlFT3RjUng=  # Base64 (trivially decoded)
```

Base64 decoding: `echo "bmR5Qnpy..." | base64 -d` → `ndyBzreUzF4zqDQsqSPMHkRhriEOtcRx`

### 4.2 Threat Model & Attack Scenarios

**Complete Credential Exposure Scenarios**:

| Attack Vector | Access Point | Result | Authorino-Specific Mitigation |
|--------------|-------------|--------|-------------------------------|
| **Kubernetes RBAC Bypass** | `kubectl get secret -o yaml` | All API keys in plaintext | RBAC policies (but admins can still read) |
| **etcd Access** | Direct etcd client connection | All Secrets readable | mTLS between kube-apiserver and etcd |
| **etcd Backup Theft** | Stolen snapshot files | All credentials if not encrypted | etcd encryption-at-rest (must be enabled) |
| **Compromised Pod** | Pod with `secrets: read` permission | Read any Secret in namespace | Least-privilege RBAC, Pod Security Policies |
| **Privileged Container** | `hostPath` mount to etcd data dir | Direct access to etcd storage | Pod Security Standards (restrict privileged) |
| **Kubernetes Audit Logs** | Logs may contain Secret data | Credentials in audit trail | Audit policy to redact Secret data |
| **Authorino Process Dump** | `gcore` or `/proc/<pid>/mem` | In-memory map with all keys | Process isolation, non-root container |
| **Supply Chain** | Compromised Helm chart or operator | Malicious code with Secret access | Image signing, provenance verification |

### 4.3 Available Protection Mechanisms

**Kubernetes-Level Protection**:
1. **RBAC**: Restrict who can read Secrets
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   rules:
   - apiGroups: [""]
     resources: ["secrets"]
     verbs: ["get", "list"]  # Grants read access
   ```
   **Limitation**: Cluster admins and service accounts with broad permissions can still read.

2. **etcd Encryption at Rest**:
   ```yaml
   # kube-apiserver flag
   --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
   ```
   ```yaml
   # encryption-config.yaml
   apiVersion: apiserver.config.k8s.io/v1
   kind: EncryptionConfiguration
   resources:
   - resources:
     - secrets
     providers:
     - aescbc:
         keys:
         - name: key1
           secret: <base64-encoded-32-byte-key>
     - identity: {}  # Fallback to plaintext
   ```
   **Protection**: Encrypts Secrets in etcd, but **NOT in Kubernetes API responses** or Authorino's memory.

3. **Pod Security Standards**:
   - Enforce `restricted` or `baseline` profiles
   - Prevent privileged containers, host path mounts
   - Limit capabilities (no `CAP_SYS_ADMIN`, `CAP_SYS_PTRACE`)

4. **Network Policies**:
   - Restrict which pods can access kube-apiserver
   - Isolate Authorino pods in dedicated namespace

**Authorino-Level Protection**:
1. **Label Selectors**: Restrict which Secrets Authorino watches
   ```yaml
   # Authorino CR
   spec:
     secretLabelSelector:
       matchLabels:
         authorino.kuadrant.io/managed-by: authorino
   ```
   **Limitation**: Still plaintext in cache for matched Secrets.

2. **Namespace Scoping**: Limit to specific namespace
   ```yaml
   # AuthConfig
   spec:
     authentication:
       "api-keys":
         apiKey:
           selector: {...}
           allNamespaces: false  # Only same namespace
   ```

3. **Process Isolation**: Authorino runs as non-root user in container
   - Reduces risk of process memory dumps
   - Still vulnerable to container escape or privileged access

### 4.4 What Authorino Does NOT Do

**No Application-Layer Cryptographic Protection**:
- ❌ No BCrypt, Argon2, PBKDF2, or scrypt hashing
- ❌ No encryption with application-managed keys
- ❌ No integration with HashiCorp Vault, AWS Secrets Manager, Azure Key Vault
- ❌ No constant-time comparison (uses Go `==` operator)
- ❌ No salting or key derivation
- ❌ No protection against timing attacks

**Comparison with 3scale**:

| Aspect | Kuadrant/Authorino | 3scale Apisonator |
|--------|-------------------|-------------------|
| Storage | Kubernetes Secrets (plaintext) | Redis (plaintext) + PostgreSQL (plaintext) |
| Validation | Go map lookup + string comparison | Redis SISMEMBER + string comparison |
| Cache | In-memory Go map | In-memory Ruby hash + memoization |
| Protection | Kubernetes RBAC + etcd encryption | Network isolation + TLS + Redis AUTH |
| Performance | <1ms (in-memory lookup) | <1ms (Redis lookup) |
| Hashing | **NONE** | **NONE** |

Both platforms prioritize **performance over cryptographic security**.

---

## 5. Comparison with RFC Security Best Practices

### 5.1 Compliance Matrix

| Best Practice | Kuadrant/Authorino | RFC Recommendation | Compliant? |
|--------------|-------------------|-------------------|------------|
| **OWASP ASVS 2.4.1**: Use approved cryptographic hash | Plaintext storage | BCrypt/Argon2/PBKDF2 | ❌ **FAIL** |
| **NIST SP 800-63B**: Hash memorized secrets | No hashing | Mandatory hashing | ❌ **FAIL** |
| **PCI DSS 3.4**: Render credentials unreadable | Plaintext in Secrets | Encrypted or hashed | ❌ **FAIL** (if protecting payment data) |
| **Defense in Depth**: Multiple security layers | Kubernetes RBAC only | Application-layer crypto + perimeter | ❌ **INSUFFICIENT** |
| **Least Privilege**: Secrets unreadable by admins | Readable by cluster admins | Hash prevents recovery | ❌ **VIOLATED** |
| **Constant-Time Comparison**: Prevent timing attacks | Uses Go `==` | `subtle.ConstantTimeCompare` | ❌ **FAIL** |

### 5.2 Security Model Comparison

**Kuadrant/Authorino Approach**:
```
┌──────────────────────────────────────┐
│  KUBERNETES RBAC + etcd ENCRYPTION   │  ← Perimeter Defense
│  ┌────────────────────────────────┐  │
│  │  Authorino Process Memory      │  │
│  │  map["key123"] = Secret{...}   │  │  ← Plaintext
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  Kubernetes Secrets            │  │
│  │  data.api_key: "key123"        │  │  ← Plaintext (base64-encoded)
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
         ↓ If perimeter breached
    ALL CREDENTIALS EXPOSED
```

**RFC Hash-Based Approach**:
```
┌──────────────────────────────────────┐
│  APPLICATION-LAYER CRYPTOGRAPHY      │  ← Defense in Depth
│  ┌────────────────────────────────┐  │
│  │  Application Memory            │  │
│  │  BCrypt::verify(input, hash)   │  │  ← Hash comparison only
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  Database Storage              │  │
│  │  key_hash: "$2a$12$..."        │  │  ← Irreversible hash
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
         ↓ Even if database breached
    CREDENTIALS REMAIN PROTECTED
    (brute-force required, infeasible for high-entropy keys)
```

### 5.3 Performance vs Security Trade-off

**Validation Latency**:

| Approach | Implementation | Single Validation | Throughput (per core) |
|----------|---------------|------------------|----------------------|
| **Kuadrant (Plaintext)** | Go map lookup + string comparison | <0.1ms | 10,000-50,000/sec |
| **RFC (BCrypt cost=12)** | Hash comparison | ~100ms | ~10/sec |
| **RFC (Argon2id)** | Memory-hard hash | ~150ms | ~6/sec |

**Infrastructure Impact** (10,000 auth/sec target):

| Approach | CPU Cores Required | Memory | Cost Multiplier |
|----------|-------------------|--------|-----------------|
| **Kuadrant** | 1-2 cores | ~100MB | 1x (baseline) |
| **BCrypt** | 1,000 cores | ~10GB | ~500x |
| **Argon2id** | 1,500 cores | ~30GB | ~750x |

**Kuadrant's Justification**:
- Kubernetes-native platform for cloud-native microservices
- Envoy external auth protocol requires low latency (<10ms target)
- Horizontal scaling via Gateway API (multiple Authorino replicas)
- Trust Kubernetes security model (RBAC, network policies, encryption-at-rest)

---

## 6. When to Use Kuadrant vs. RFC Approach

### 6.1 Kuadrant/Authorino is Appropriate When:

✅ **Performance is critical**:
- Sub-millisecond authorization latency required
- High-throughput API gateways (10K+ requests/sec)
- Real-time authorization decisions needed

✅ **Kubernetes-native environment**:
- Strong Kubernetes RBAC enforcement
- etcd encryption-at-rest enabled
- Network policies isolate Authorino
- Platform team controls cluster access

✅ **Compliance permits plaintext**:
- Regulations don't mandate cryptographic credential storage
- API keys don't protect highly sensitive data
- Insider threat risk is acceptable

✅ **Operational simplicity**:
- Kubernetes Secrets as API for key management
- Dynamic updates without application changes
- Automatic propagation across replicas

### 6.2 RFC Hash-Based Approach is Required When:

✅ **Regulatory compliance**:
- PCI DSS, HIPAA, FedRAMP, SOC 2 Type II
- GDPR high-risk data processing
- Industry standards mandate cryptographic protection

✅ **Defense in depth**:
- Zero-trust architecture
- Assume Kubernetes may be compromised
- Insider threat is a concern

✅ **Credential protection priority**:
- API keys grant access to critical systems
- Breach would have severe consequences
- Keys cannot be easily rotated

✅ **Moderate throughput**:
- <1,000 requests/sec authorization load
- Can tolerate 50-100ms validation latency
- Infrastructure cost acceptable

---

## 7. Recommendations for Secure Kuadrant Deployments

### 7.1 Mandatory Security Controls

If using Kuadrant/Authorino with plaintext API keys, implement these compensating controls:

1. **Enable etcd Encryption at Rest**
   ```yaml
   # kube-apiserver configuration
   --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
   ```
   Rotate encryption keys regularly (at least quarterly).

2. **Strict RBAC for Secrets**
   ```yaml
   # Deny direct Secret access to all non-admin users
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata:
     name: secret-reader-deny
   rules:
   - apiGroups: [""]
     resources: ["secrets"]
     verbs: ["get", "list", "watch"]
     # Explicitly deny by not granting to users
   ```

3. **Audit Logging with Secret Redaction**
   ```yaml
   # kube-apiserver audit policy
   - level: Metadata
     resources:
     - group: ""
       resources: ["secrets"]
     omitStages: ["RequestReceived"]
   ```

4. **Network Policies**
   ```yaml
   # Restrict access to kube-apiserver
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: authorino-isolation
   spec:
     podSelector:
       matchLabels:
         app: authorino
     policyTypes:
     - Ingress
     - Egress
     ingress:
     - from:
       - podSelector:
           matchLabels:
             app: envoy
     egress:
     - to:
       - namespaceSelector: {}
         podSelector:
           matchLabels:
             component: kube-apiserver
   ```

5. **Pod Security Standards**
   ```yaml
   # Enforce restricted profile
   apiVersion: v1
   kind: Namespace
   metadata:
     name: authorino-system
     labels:
       pod-security.kubernetes.io/enforce: restricted
       pod-security.kubernetes.io/audit: restricted
       pod-security.kubernetes.io/warn: restricted
   ```

6. **Backup Encryption**
   - Encrypt etcd snapshots with GPG or cloud KMS
   - Store backups in encrypted storage (S3 SSE-KMS, Azure Blob encryption)
   - Restrict backup access to ops team only

7. **Secret Rotation Policy**
   - Rotate API keys quarterly (or more frequently)
   - Automate rotation with tooling (e.g., Kubernetes CronJobs)
   - Maintain audit trail of all key creations/deletions

8. **Monitoring & Alerting**
   - Alert on Secret access from unexpected pods
   - Monitor for privilege escalation attempts
   - Track failed authentication attempts (potential key guessing)

### 7.2 Alternative: Kubernetes External Secrets with Hashing

For environments requiring cryptographic protection, consider this hybrid approach:

**Architecture**:
```
┌──────────────────────────────────────┐
│  External Secret Store (Vault/AWS)   │
│  ┌────────────────────────────────┐  │
│  │  Hashed API Keys               │  │
│  │  key_hash: "$2a$12$..."        │  │
│  └────────────────────────────────┘  │
└────────────┬─────────────────────────┘
             │ External Secrets Operator
             ↓
┌──────────────────────────────────────┐
│  Kubernetes Secrets (Hashed)         │
│  data.api_key_hash: "$2a$12$..."     │
└────────────┬─────────────────────────┘
             │
             ↓
┌──────────────────────────────────────┐
│  Custom Authorino Identity Evaluator │
│  (with BCrypt verification)          │
└──────────────────────────────────────┘
```

**Implementation**:
1. Store hashed API keys in Vault/AWS Secrets Manager
2. Use External Secrets Operator to sync to Kubernetes Secrets
3. Implement custom Authorino identity evaluator (Go plugin)
4. Verify requests using BCrypt comparison

**Trade-offs**:
- ✅ Cryptographic credential protection
- ✅ Centralized secret management
- ❌ Increased complexity (custom code required)
- ❌ Higher latency (~100ms per request)
- ❌ Not officially supported by Kuadrant

---

## 8. Kuadrant Advantages Over 3scale

Despite the shared plaintext storage limitation, Kuadrant offers several advantages:

### 8.1 Cloud-Native Architecture

| Aspect | Kuadrant | 3scale |
|--------|----------|--------|
| **Deployment** | Kubernetes-native operators | Multi-component (Rails, Ruby, Redis, PostgreSQL) |
| **Configuration** | Kubernetes CRDs (declarative) | Web UI + API (imperative) |
| **GitOps Ready** | Yes (all resources in Git) | Partial (requires API calls) |
| **Multi-Cluster** | Native DNS + Gateway API | Requires Zync sync service |

### 8.2 Gateway API Integration

- **Standard API**: Uses Gateway API (CNCF project), not proprietary
- **Multi-Provider**: Works with Istio, Envoy Gateway, Kong, others
- **Policy Attachment**: GEP-713 standard for auth, rate limiting, TLS, DNS
- **HTTPRoute Targeting**: Fine-grained policies per route rule

### 8.3 Feature Comparison

| Feature | Kuadrant | 3scale |
|---------|----------|--------|
| **API Key Storage** | Kubernetes Secrets (plaintext) | Redis + PostgreSQL (plaintext) |
| **Authentication** | JWT, API Key, mTLS, OAuth2, OIDC, K8s TokenReview | JWT, API Key, OAuth2, OIDC |
| **Authorization** | OPA, Kubernetes RBAC, Pattern Matching, SpiceDB | Pattern Matching |
| **Rate Limiting** | Per-user, Global, Token-based (AI/LLM) | Per-user, Global |
| **Policy Engine** | Authorino (Go, gRPC) | Backend (Ruby, HTTP) |
| **External Metadata** | HTTP, OIDC UserInfo, UMA | Limited |
| **Dynamic Response** | Wristband tokens, JSON injection | Limited |

---

## 9. Conclusion

### 9.1 Key Findings Summary

**Kuadrant/Authorino API Key Security Model**:
- ✅ **Kubernetes-native**: Leverages Secrets API, RBAC, etcd encryption
- ✅ **High performance**: <1ms validation, 10K+ auth/sec
- ✅ **Dynamic management**: Instant key rotation, automatic propagation
- ✅ **Simple operations**: Standard Kubernetes tooling
- ❌ **Plaintext storage**: No cryptographic hashing or encryption at application layer
- ❌ **Perimeter-only security**: Relies entirely on Kubernetes security
- ❌ **Non-compliant**: Violates OWASP, NIST, PCI DSS credential storage best practices

### 9.2 Comparison with 3scale

**Similarities**:
- Both store credentials in plaintext
- Both use direct string comparison for validation
- Both prioritize performance over cryptographic security
- Both rely on perimeter defense (network isolation, access control)

**Differences**:
- **Storage**: Kubernetes Secrets (Kuadrant) vs. Redis/PostgreSQL (3scale)
- **Protocol**: gRPC External Auth (Kuadrant) vs. HTTP REST (3scale)
- **Deployment**: Cloud-native operators (Kuadrant) vs. Traditional app deployment (3scale)
- **Complexity**: Lower (Kuadrant) vs. Higher (3scale - 10+ components)

### 9.3 Recommendations for RFC Implementation

**DO NOT adopt Kuadrant's plaintext storage approach unless**:
1. Performance requirements exceed hash validation capacity (>10K auth/sec)
2. Kubernetes security controls are exceptionally strong
3. Regulatory compliance permits plaintext credential storage
4. Organization explicitly accepts the risk

**DO adopt these Kuadrant patterns**:
1. ✅ **Declarative configuration**: CRDs for auth policies
2. ✅ **Dynamic credential management**: Live updates without restarts
3. ✅ **External auth protocol**: Separation of gateway and auth service
4. ✅ **Multi-phase auth pipeline**: Authentication, metadata, authorization, response, callbacks
5. ✅ **Label-based selectors**: Flexible credential scoping

**RFC Default Recommendation**:
- **Use cryptographic hashing** (BCrypt, Argon2id) as the baseline secure approach
- Document plaintext storage as an opt-in performance optimization for specific use cases
- Require explicit risk acceptance and compensating controls for plaintext deployments
- Provide implementation guidance for both approaches with clear trade-off documentation

### 9.4 Final Security Assessment

**Kuadrant/Authorino Security Rating** (for API key storage):

| Criterion | Rating | Notes |
|-----------|--------|-------|
| **Cryptographic Protection** | ❌ **0/10** | No hashing, no encryption at app layer |
| **Defense in Depth** | ⚠️ **3/10** | Kubernetes RBAC only, no app-layer crypto |
| **Insider Threat Resistance** | ❌ **1/10** | Cluster admins can read all keys |
| **Compliance** | ❌ **2/10** | Non-compliant with most security standards |
| **Performance** | ✅ **10/10** | <1ms validation, 10K+ auth/sec |
| **Operational Simplicity** | ✅ **9/10** | Standard Kubernetes tooling |
| **Cloud-Native Fit** | ✅ **10/10** | Perfect Kubernetes integration |

**Overall Assessment**: **High-performance, cloud-native solution with weak cryptographic security**. Suitable for internal corporate APIs with strong perimeter security, but not for regulated environments or high-security use cases.

---

## 10. References

### 10.1 Source Code

- **Authorino API Key Implementation**: `pkg/evaluators/identity/api_key.go`
- **Authorino Auth Pipeline**: `pkg/auth/auth.go`
- **Kuadrant AuthPolicy CRD**: `api/v1/authpolicy_types.go`

### 10.2 Documentation

- [Authorino API Key Authentication Guide](https://github.com/kuadrant/authorino/blob/main/docs/user-guides/api-key-authentication.md)
- [Authorino Architecture](https://github.com/kuadrant/authorino/blob/main/docs/architecture.md)
- [Kuadrant Auth Overview](https://docs.kuadrant.io/latest/kuadrant-operator/doc/overviews/auth)
- [Gateway API Policy Attachment](https://gateway-api.sigs.k8s.io/geps/gep-713/)

### 10.3 Related Projects

- **Authorino**: https://github.com/kuadrant/authorino
- **Kuadrant Operator**: https://github.com/kuadrant/kuadrant-operator
- **Limitador**: https://github.com/kuadrant/limitador (Rate limiting engine)
- **Gateway API**: https://gateway-api.sigs.k8s.io/

---

**Document Version**: 1.0
**Last Updated**: 2026-03-02
**Analysis Depth**: Source code level (Go implementation)
