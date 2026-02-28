# HashiCorp Vault Architecture Analysis

> **Source**: Analysis of HashiCorp Vault source code in `./src.references/vault`
>
> **Last Updated**: 2026-02-27
>
> **Purpose**: Understanding Vault's architecture for token generation, encryption at rest, storage schemas, and security mechanisms for potential application to API key management systems.

---

## Executive Summary

HashiCorp Vault provides a sophisticated, security-first architecture for secret management with the following key capabilities:

- ✅ **Token Generation**: Native support for both persistent (Service) and ephemeral (Batch) tokens
- ✅ **Encryption at Rest**: AES-256-GCM with keyring-based rotation
- ✅ **Zero-Trust Storage**: All data encrypted before hitting storage backends
- ✅ **Seal/Unseal Mechanism**: Defense-in-depth protection requiring master key
- ✅ **Audit Trail**: Accessor-based logging prevents token exposure
- ✅ **Pluggable Storage**: Backend-agnostic design with consistent encryption

### Comparison with RFC API Key Security Specification

This document has been analyzed against the [RFC API Key Security Specification](../RFC-API-Key-Security-Specification.md) to understand how Vault's architecture aligns with industry best practices for API key management.

**Key Alignments**:
- Strong cryptographic foundation (AES-256-GCM, high entropy, CSPRNG)
- Comprehensive access control (ACL, policies, namespaces)
- Robust audit capabilities (accessor indirection, sensitive field protection)
- Defense-in-depth security model (sealed barrier, encryption at rest)

**Architectural Differences**:
- **Storage Model**: Vault uses encrypted storage (AES-GCM) vs. RFC's hash-only requirement (BCrypt/Argon2)
- **Token Types**: Vault distinguishes service (stateful) vs. batch (stateless) tokens
- **Validation**: Vault's database lookup model vs. RFC's hash comparison or stateless JWT pattern
- **Philosophy**: Vault optimizes for operational flexibility; RFC optimizes for maximum security against database compromise

See Section 11 "Questions for Further Exploration" for detailed analysis of how Vault's implementation compares to RFC requirements and where additional investigation is needed.

---

## 1. Token Generation and Management

### Token Structure

**Location**: `vault/sdk/logical/token.go`

```go
type TokenEntry struct {
    // Identifiers
    ID          string    // Primary token identifier (internal index)
    Accessor    string    // Secondary UUID for indirect reference (audit logs)
    ExternalID  string    // The actual token returned to users

    // Type and Hierarchy
    Type        TokenType  // TokenTypeService or TokenTypeBatch
    Parent      string     // Links to parent token for revocation trees

    // Security
    Policies    []string   // List of assigned policies
    BoundCIDRs  []string   // CIDR restrictions

    // Lifecycle
    CreationTime int64     // Unix timestamp of creation
    TTL          time.Duration  // Time-to-live duration
    ExpireTime   time.Time      // Calculated expiration
    NumUses      int            // Restriction counter
                                // Special values: -1=final use, -2=tainted, -3=revocation failed

    // Identity and Context
    EntityID     string    // Link to identity entity
    NamespaceID  string    // Namespace isolation
    CubbyholeID  string    // Private per-token storage reference

    // Metadata
    Meta         map[string]string  // Audit metadata
    InternalMeta map[string]string  // Internal metadata
}
```

### Token Types

#### Service Tokens (Persistent)
- **Storage**: Fully persisted in encrypted storage
- **Features**:
  - Support renewal and TTL extension
  - Can have child tokens (revocation trees)
  - Policy-based access control
  - Cubbyhole private storage
- **ID Format**: 24-character base62-encoded random ID
  - Modern: `hvs.` prefix (4 bytes)
  - Legacy: `s.` prefix (2 bytes)
- **Storage Paths**:
  ```
  id/<tokenid>           → Full TokenEntry (encrypted)
  accessor/<accessorid>  → Accessor-to-ID mapping
  parent/<parentid>      → Parent-child relationships
  ```

#### Batch Tokens (Ephemeral)
- **Storage**: NOT persisted in backend
- **Features**:
  - Encrypted as protobuf inline
  - Returned as base64-encoded encrypted payload
  - Single-use, no renewal
  - No parent/child relationships
  - No cubbyhole storage
- **Use Case**: High-throughput, short-lived access

### Token Generation Process

**Location**: `vault/vault/token_store.go:1044+`

1. **Random ID Generation**:
   ```go
   // Service tokens use cryptographically secure random generation
   tokenID := base62.Random(24) // or base62.RandomWithReader()

   // Root tokens use special secure reader
   tokenID := generateRoot(core.secureRandomReader)
   ```

2. **Storage Persistence** (Service tokens only):
   ```
   Write to: id/<tokenid>        → Full TokenEntry
   Write to: accessor/<accessor> → Points to tokenid
   Write to: parent/<parentid>   → Add to parent's children list
   ```

3. **Token Return**:
   - Service: Return `ExternalID` to user
   - Batch: Return encrypted protobuf payload

### Token Access Control

**Limitations**:
- Tokens with `NumUses > 0` cannot create child tokens
- Batch tokens cannot create additional tokens
- Token CIDR restrictions via `BoundCIDRs`
- Entity-based policy inheritance via `EntityID`

### Security Features

1. **Accessor Indirection**:
   - Audit logs use `Accessor` (UUID), never the actual token ID
   - Prevents token leakage through logs
   - Allows token lookup without exposing sensitive ID

2. **Revocation Trees**:
   - Parent tokens can revoke all descendants
   - Cascading revocation via `parent/<parentid>` index

3. **Cubbyhole Storage**:
   - Per-token private storage (`CubbyholeID`)
   - Destroyed when token is revoked
   - Inaccessible to other tokens

---

## 2. Encryption at Rest

### AES-GCM Barrier

**Location**: `vault/vault/barrier_aes_gcm.go`

#### Cryptographic Specifications

- **Algorithm**: AES-GCM (Advanced Encryption Standard with Galois Counter Mode)
- **Key Size**: 256-bit (32 bytes)
- **Cipher Mode**: AEAD (Authenticated Encryption with Associated Data)
- **Nonce Size**: 12 bytes (default Go GCM nonce)
- **Auth Tag Size**: 16 bytes
- **Versions**: AESGCMVersion1, AESGCMVersion2

#### Encrypted Data Format

```
[VersionByte][Term (4 bytes)][Nonce (12 bytes)][EncryptedData][AuthTag (16 bytes)]
```

**Components**:
- **VersionByte**: Encryption scheme version (0x01 or 0x02)
- **Term**: Key term number (4-byte uint32) - identifies which key was used
- **Nonce**: Random 12-byte value for GCM
- **EncryptedData**: Actual ciphertext
- **AuthTag**: GCM authentication tag for integrity

#### Encryption Process

**Location**: `vault/vault/barrier_aes_gcm.go`

```go
func (b *AESGCMBarrier) Encrypt(ctx context.Context, key string, plaintext []byte) ([]byte, error) {
    // 1. Lock check: ensure barrier is unsealed
    if b.sealed {
        return nil, ErrBarrierSealed
    }

    // 2. Get active term from keyring
    term := b.keyring.ActiveTerm()
    key := b.keyring.TermKey(term)

    // 3. Create AEAD cipher from active key
    aead := cipher.NewGCM(key.Value)

    // 4. Generate random nonce
    nonce := make([]byte, 12)
    rand.Read(nonce)

    // 5. Encrypt with tracking
    ciphertext := aead.Seal(nil, nonce, plaintext, nil)
    b.trackEncryption(term) // For rotation triggers

    // 6. Return formatted ciphertext
    return [version][term][nonce][ciphertext][tag], nil
}
```

#### Decryption Process

```go
func (b *AESGCMBarrier) Decrypt(_ context.Context, key string, ciphertext []byte) ([]byte, error) {
    // 1. Extract term from first 4 bytes (after version)
    term := binary.BigEndian.Uint32(ciphertext[1:5])

    // 2. Look up decryption key by term
    // Supports historical keys for backward compatibility
    key := b.keyring.TermKey(term)
    if key == nil {
        return nil, fmt.Errorf("invalid term: %d", term)
    }

    // 3. Decrypt using appropriate key
    aead := cipher.NewGCM(key.Value)
    nonce := ciphertext[5:17]
    payload := ciphertext[17:]

    return aead.Open(nil, nonce, payload, nil)
}
```

### Keyring Management

**Location**: `vault/vault/keyring.go`

#### Keyring Structure

```go
type Keyring struct {
    rootKey      []byte           // Master key used to encrypt the keyring itself
    keys         map[uint32]*Key  // Historical keys for decryption (term → key)
    activeTerm   uint32           // Current term used for new encryptions
    rotationConfig RotationConfig // Auto-rotation settings
}

type Key struct {
    Term         uint32    // Sequential term number
    Version      int       // Key version
    Value        []byte    // Actual key material (32 bytes for AES-256)
    InstallTime  time.Time // When this key was created
    Encryptions  uint64    // Count of encryptions with this key
}
```

#### Key Storage Paths

```
core/master              → Root key (encrypted under itself via PBKDF2 or seal)
core/keyring             → Keyring (encrypted under root key)
core/upgrade/<term>      → Key upgrade paths for standby instances
```

#### Key Rotation

**Automatic Rotation Triggers**:

1. **Maximum Operation Count**: 3.86 billion encryptions per key
   - Based on AES-GCM security limits (2^32 operations)
   - Tracked via `Encryptions` counter

2. **Time Interval**: Configurable rotation period
   - Default: None (manual only)
   - Can be set via `rotation_period` config

3. **Legacy Rotation**: 1 year without activity
   - Forces upgrade of very old keys

**Rotation Process**:

```go
func (c *Core) RotateKeyring() error {
    // 1. Generate new encryption key
    newKey := &Key{
        Term:    c.barrier.ActiveTerm() + 1,
        Version: c.barrier.CurrentVersion(),
        Value:   randomBytes(32), // Crypto-secure random
        InstallTime: time.Now(),
    }

    // 2. Add to keyring
    c.barrier.keyring.AddKey(newKey)

    // 3. Encrypt keyring under root key
    encryptedKeyring := encryptKeyring(c.barrier.keyring, rootKey)

    // 4. Persist to storage
    c.barrier.Put("core/keyring", encryptedKeyring)

    // 5. Create upgrade path for standby nodes
    c.barrier.Put("core/upgrade/" + newKey.Term, upgradeInfo)

    // 6. Set as active term
    c.barrier.keyring.SetActiveTerm(newKey.Term)
}
```

**Key Properties**:
- Old keys retained for decryption of historical data
- No need to rewrap existing data on rotation
- New encryptions use new key immediately
- Seamless for clients (transparent)

#### Encryption Count Tracking

```go
// Local tracking for rotation decisions
UnaccountedEncryptions  atomic.Uint64  // Counter since last persistence
totalLocalEncryptions   atomic.Uint64  // Metrics/observability

func (b *AESGCMBarrier) trackEncryption(term uint32) {
    count := b.UnaccountedEncryptions.Add(1)

    // Persist every 1000 encryptions
    if count%1000 == 0 {
        b.persistEncryptions()
    }

    // Check rotation threshold
    if b.keyring.TermKey(term).Encryptions > RotationThreshold {
        b.scheduleRotation()
    }
}
```

### Memory Safety

**Security Measures**:

1. **Memory Zeroing**:
   ```go
   func memzero(data []byte) {
       for i := range data {
           data[i] = 0
       }
   }

   // Used after key operations
   defer memzero(keyMaterial)
   ```

2. **Atomic Operations**: Thread-safe counters via `sync/atomic`

3. **RWMutex Locking**: Concurrent access protection
   ```go
   b.l.RLock()  // Read operations
   b.l.Lock()   // Write operations (seal/unseal/rotate)
   ```

4. **Secure Random Sources**:
   ```go
   core.secureRandomReader  // crypto/rand.Reader for production
   // Used for: root tokens, key generation, nonces
   ```

---

## 3. Database Schemas and Storage

### Storage Backend Architecture

Vault uses a **pluggable storage backend** system. The barrier encrypts all data before it reaches the backend, making the choice of backend transparent to security.

#### Supported Backends

**Location**: `physical/` directory

- **In-Memory**: `physical/inmem/` - Testing only
- **Consul**: `physical/consul/` - Service discovery integration
- **etcd**: `physical/etcd/` - Kubernetes-native
- **Raft**: `physical/raft/` - Built-in clustering
- **DynamoDB**: `physical/dynamodb/` - AWS-native
- **S3**: `physical/s3/` - Object storage
- **GCS**: `physical/gcs/` - Google Cloud Storage
- **Azure Blob**: `physical/azure/` - Azure-native
- **PostgreSQL**: `physical/postgresql/` - Relational DB
- **MySQL**: `physical/mysql/` - Relational DB
- **CockroachDB**: `physical/cockroachdb/` - Distributed SQL
- **CassandraDB**: `physical/cassandra/` - Wide-column store
- **FoundationDB**: `physical/foundationdb/` - Ordered key-value

### Example: CockroachDB Schema

**Location**: `physical/cockroachdb/cockroachdb.go`

#### Main Storage Table

```sql
CREATE TABLE vault_kv_store (
    path   STRING,    -- Key path (e.g., "id/hvs.abc123")
    value  BYTES,     -- Encrypted value (ciphertext only)
    PRIMARY KEY (path)
);
```

**Notes**:
- `value` column contains **only encrypted data** (never plaintext)
- No schema knowledge of what's stored (barrier abstraction)
- Path is human-readable, but value is opaque

#### High Availability Lock Table

```sql
CREATE TABLE vault_ha_locks (
    ha_key      TEXT NOT NULL,
    ha_identity TEXT NOT NULL,
    ha_value    TEXT,
    valid_until TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ha_key PRIMARY KEY (ha_key)
);
```

**Purpose**:
- Leader election in HA clusters
- TTL-based lease management
- Identity tracking for active node

### Storage Entry Structure

**Location**: `sdk/physical/entry.go`

```go
type Entry struct {
    Key       string   // Path identifier (e.g., "id/hvs.token123")
    Value     []byte   // Encrypted data (ciphertext)
    SealWrap  bool     // Flag for additional seal wrapping (Enterprise)
    ValueHash []byte   // Hash for replication verification
}
```

**Location**: `sdk/logical/storage.go`

```go
type StorageEntry struct {
    Key      string   // Logical path
    Value    []byte   // Always encrypted when stored via barrier
    SealWrap bool     // Additional seal wrapping flag
}
```

### Data Flow: Write Path

```
1. Application Data (JSON)
   ↓
2. JSON Encode → []byte
   ↓
3. Barrier.Encrypt() → AES-GCM encryption
   ↓
4. Physical Entry{Key: "path", Value: ciphertext}
   ↓
5. Backend.Put() → Database INSERT/UPDATE
   ↓
6. Storage: path="id/token123", value=[encrypted bytes]
```

### Data Flow: Read Path

```
1. Backend.Get("id/token123")
   ↓
2. Physical Entry{Key: "path", Value: ciphertext}
   ↓
3. Barrier.Decrypt(ciphertext) → plaintext []byte
   ↓
4. JSON Decode → Struct (e.g., TokenEntry)
   ↓
5. Return to application
```

### Critical Storage Paths

#### Encrypted Paths (Normal Operation)

```
id/<tokenid>              → Service token entries
accessor/<accessorid>     → Accessor-to-ID mappings
parent/<parentid>         → Parent-child relationships
core/keyring              → Encryption keyring (encrypted under root key)
core/master               → Root key (encrypted under itself or HSM)
core/upgrade/<term>       → Key upgrade paths for standbys
core/wrapping/jwtkey      → Response wrapping ECDSA key
auth/token/roles/<name>   → Token role definitions
auth/token/salt           → Salt for hashing (accessors, etc.)
sys/policy/<name>         → ACL policies
sys/mounts/*              → Mount table configuration
```

#### Plaintext Paths (Sealed-State Readable)

These paths are readable even when Vault is sealed (used for initialization):

```
core/seal-config          → Shamir seal configuration
core/recovery-config      → Recovery key configuration
core/seal-gen-info        → Seal generation tracking
core/hsm-encrypted-key    → HSM-wrapped keys (Enterprise)
```

---

## 4. Seal/Unseal Architecture

### SecurityBarrier Interface

**Location**: `vault/vault/barrier.go`

```go
type SecurityBarrier interface {
    // Initialization
    Initialized() (bool, error)
    Initialize(context.Context, []byte, []byte, io.Reader) error

    // Seal State
    Sealed() (bool, error)
    Unseal(context.Context, []byte) error
    Seal() error
    VerifyRoot([]byte) error

    // Encryption Operations (require unsealed state)
    Encrypt(context.Context, string, []byte) ([]byte, error)
    Decrypt(context.Context, string, []byte) ([]byte, error)

    // Key Management
    Rotate(context.Context) (uint32, error)
    Keyring() (*Keyring, error)

    // Storage Operations
    Put(context.Context, *logical.StorageEntry) error
    Get(context.Context, string) (*logical.StorageEntry, error)
    Delete(context.Context, string) error
    List(context.Context, string) ([]string, error)
}
```

### Seal States

#### Sealed State (`b.sealed = true`)

**Restrictions**:
- ❌ All `Encrypt()` operations fail with `ErrBarrierSealed`
- ❌ All `Decrypt()` operations fail with `ErrBarrierSealed`
- ❌ Normal `Put/Get/Delete` operations blocked
- ✅ Can read `core/seal-config` and other initialization paths
- ✅ Can check initialization status

**Purpose**: Defense-in-depth. Even if attacker gains storage access, sealed vault prevents any data access.

#### Unsealed State (`b.sealed = false`)

**Capabilities**:
- ✅ Master key loaded in memory
- ✅ Keyring decrypted and accessible
- ✅ Full encrypt/decrypt operations
- ✅ All storage operations enabled

**Security**: Master key exists **only in memory** during unsealed state.

### Seal Configuration

**Location**: `vault/vault/seal_config.go`

```go
type SealConfig struct {
    Type            string    // "shamir", "awskms", "azurekeyvault", etc.

    // Shamir Secret Sharing (default)
    SecretShares    int       // N (total shares)
    SecretThreshold int       // T (threshold - minimum shares to unseal)

    // Optional PGP Encryption of Shares
    PGPKeys         []string  // PGP public keys for encrypting shares

    // Rekey Operation
    Nonce           string    // Nonce for rekey operation
    Backup          bool      // Store encrypted backup of keys

    // Auto-Seal (HSM/Cloud KMS)
    StoredShares    int       // 0 for Shamir, 1 for auto-seal

    // Verification
    VerificationKey []byte    // New key pending validation
    VerificationNonce string  // Verification operation nonce
}
```

### Shamir Secret Sharing

**Algorithm**: Shamir's Secret Sharing Scheme (SSSS)

**Configuration Example**:
```
SecretShares: 5        (Generate 5 key shares)
SecretThreshold: 3     (Require any 3 shares to reconstruct master key)
```

**Unseal Process**:

```go
func (c *Core) Unseal(key []byte) (bool, error) {
    // 1. Add unseal key to recovery pool
    c.unlockInfo.Keys = append(c.unlockInfo.Keys, key)

    // 2. Check if threshold met
    if len(c.unlockInfo.Keys) < c.sealConfig.SecretThreshold {
        return false, nil // Still sealed, need more keys
    }

    // 3. Reconstruct master key using Shamir
    masterKey, err := shamir.Combine(c.unlockInfo.Keys)
    if err != nil {
        return false, err
    }

    // 4. Verify master key by attempting to decrypt keyring
    keyring, err := c.barrier.RecoverKeyring(masterKey)
    if err != nil {
        c.unlockInfo.Keys = nil // Wrong keys, reset
        return false, ErrBarrierInvalidKey
    }

    // 5. Unseal barrier
    c.barrier.Unseal(masterKey)
    c.barrier.sealed = false

    // 6. Clear unseal keys from memory
    memzero(masterKey)
    c.unlockInfo.Keys = nil

    return true, nil // Successfully unsealed
}
```

### Auto-Seal (HSM/Cloud KMS)

**Supported Providers**:
- AWS KMS
- Azure Key Vault
- GCP Cloud KMS
- HSMs (via PKCS#11)
- Transit (Vault-to-Vault)

**Configuration**:
```
StoredShares: 1         // Master key stored encrypted under KMS
SecretShares: 1         // No Shamir split needed
SecretThreshold: 1      // Automatic unseal
```

**Benefits**:
- Automatic unseal on restart
- No manual unseal key management
- Audit trail in cloud provider
- Hardware-backed key protection

**Tradeoff**: Dependency on external service for unsealing

### Initialization Process

**Location**: `vault/vault/core.go`

```go
func (c *Core) Initialize(ctx context.Context, params InitParams) (*InitResult, error) {
    // 1. Generate master key (root key)
    masterKey := make([]byte, 32) // 256-bit
    _, err := rand.Read(masterKey)

    // 2. Generate initial encryption key
    encKey := make([]byte, 32)
    _, err = rand.Read(encKey)

    // 3. Initialize barrier with keys
    err = c.barrier.Initialize(ctx, masterKey, encKey, rand.Reader)

    // 4. Split master key using Shamir (if configured)
    shares, err := shamir.Split(masterKey,
        params.SecretShares,
        params.SecretThreshold)

    // 5. Optionally PGP-encrypt shares
    if len(params.PGPKeys) > 0 {
        shares = pgpEncryptShares(shares, params.PGPKeys)
    }

    // 6. Persist seal configuration
    c.physical.Put("core/seal-config", encodeSealConfig(params))

    // 7. Generate root token
    rootToken, err := c.tokenStore.rootToken(ctx)

    // 8. Return shares and root token to operator
    return &InitResult{
        SecretShares: shares,
        RootToken:    rootToken,
    }, nil
}
```

**Security Notes**:
- Master key **never persisted in plaintext**
- Shares distributed to different operators
- Root token shown **only once** during initialization
- Initialization is one-time operation (cannot re-initialize without wiping storage)

---

## 5. Access Control and Authorization

### ACL System

**Location**: `vault/vault/acl.go`

#### ACL Structure

```go
type ACL struct {
    // Path Matching
    exactRules          *radix.Tree  // Exact path matches
    prefixRules         *radix.Tree  // Prefix-based matches (e.g., "secret/*")
    segmentWildcardPaths *radix.Tree // Glob patterns (e.g., "secret/+/data")

    // Special Policies
    root         bool             // Root policy flag (unrestricted)
    rgpPolicies  []*Policy        // Sentinel-based role-governing policies
    egpPolicies  []*Policy        // Sentinel-based endpoint-governing policies

    // Configuration
    namespace    string           // Namespace context
}
```

#### Capabilities

**Capability Types**:

```go
const (
    DenyCapability     = "deny"     // Explicit denial (overrides all)
    CreateCapability   = "create"   // Create new data
    ReadCapability     = "read"     // Read existing data
    UpdateCapability   = "update"   // Update existing data
    DeleteCapability   = "delete"   // Delete data
    ListCapability     = "list"     // List keys/paths
    SudoCapability     = "sudo"     // Privileged operations
    SubscribeCapability = "subscribe" // Event subscription
    PublishCapability   = "publish"   // Event publishing
)
```

**CapabilitiesBitmap**: Efficient 32-bit representation

```go
type CapabilitiesBitmap uint32

const (
    DenyCapabilityInt     CapabilitiesBitmap = 1 << iota
    CreateCapabilityInt
    ReadCapabilityInt
    UpdateCapabilityInt
    DeleteCapabilityInt
    ListCapabilityInt
    SudoCapabilityInt
    // ... etc
)
```

#### Policy Evaluation

**Location**: `vault/vault/acl.go`

```go
func (a *ACL) AllowOperation(ctx context.Context, req *logical.Request) (*AuthResults, error) {
    // 1. Check root policy (bypass all checks)
    if a.root {
        return &AuthResults{Allowed: true}, nil
    }

    // 2. Find matching policy rules (exact → prefix → glob)
    var matchingRules *ACLPermissions

    // Try exact match first
    if rule := a.exactRules.Get(req.Path); rule != nil {
        matchingRules = rule.(*ACLPermissions)
    } else if rule := a.prefixRules.LongestPrefix(req.Path); rule != nil {
        matchingRules = rule.(*ACLPermissions)
    } else if rule := a.segmentWildcardPaths.Match(req.Path); rule != nil {
        matchingRules = rule.(*ACLPermissions)
    }

    // 3. No matching rules = deny
    if matchingRules == nil {
        return &AuthResults{Allowed: false}, nil
    }

    // 4. Check for explicit deny (highest priority)
    if matchingRules.CapabilitiesBitmap & DenyCapabilityInt != 0 {
        return &AuthResults{Allowed: false, DeniedDueToACL: true}, nil
    }

    // 5. Check required capability
    required := operationCapability(req.Operation)
    if matchingRules.HasCapability(required) {
        return &AuthResults{Allowed: true}, nil
    }

    // 6. Check for sudo requirement
    if req.IsSudoOperation {
        if matchingRules.HasCapability(SudoCapability) {
            return &AuthResults{Allowed: true}, nil
        }
        return &AuthResults{Allowed: false, NeedsSudo: true}, nil
    }

    return &AuthResults{Allowed: false}, nil
}
```

#### Policy HCL Syntax

```hcl
# Example policy
path "secret/data/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/*" {
    capabilities = ["list"]
}

path "auth/token/create" {
    capabilities = ["create", "update"]

    # Parameter constraints
    allowed_parameters = {
        "policies" = ["dev-policy", "staging-policy"]
        "ttl" = ["1h", "2h"]
    }

    # Required parameters
    required_parameters = ["policies"]
}

# Sudo-protected path
path "sys/seal" {
    capabilities = ["sudo", "update"]
}

# Explicit deny
path "secret/restricted/*" {
    capabilities = ["deny"]
}
```

### BarrierView (Namespace Isolation)

**Location**: `vault/vault/barrier_view.go`

#### Purpose
Provides path-prefix isolation for different mounts and namespaces, preventing cross-mount access.

```go
type BarrierView struct {
    barrier   SecurityBarrier  // Underlying barrier
    prefix    string           // Enforced prefix (e.g., "auth/token/")
    readOnlyErr error          // Optional read-only enforcement
}

func (v *BarrierView) Get(ctx context.Context, key string) (*logical.StorageEntry, error) {
    // Automatically prefix the key
    return v.barrier.Get(ctx, v.prefix + key)
}

func (v *BarrierView) SubView(prefix string) *BarrierView {
    // Create nested view: parent.prefix + prefix
    return &BarrierView{
        barrier: v.barrier,
        prefix:  v.prefix + prefix,
    }
}
```

**Example Usage**:

```go
// Token auth backend gets view at "auth/token/"
tokenView := barrier.SubView("auth/token/")

// When token store writes: tokenView.Put("id/hvs.abc", data)
// Actually stored at: "auth/token/id/hvs.abc"

// Token store CANNOT access: "auth/userpass/*" or "secret/*"
```

### Token-Based Access Control

**Token Access Limitations**:

```go
func (ts *TokenStore) validateTokenForCreation(parent *TokenEntry) error {
    // 1. Batch tokens cannot create children
    if parent.Type == logical.TokenTypeBatch {
        return errors.New("batch tokens cannot create child tokens")
    }

    // 2. Tokens with usage limits cannot create children
    if parent.NumUses > 0 {
        return errors.New("tokens with num_uses cannot create child tokens")
    }

    // 3. Check CIDR restrictions
    if len(parent.BoundCIDRs) > 0 {
        if !cidrsContain(parent.BoundCIDRs, req.Connection.RemoteAddr) {
            return errors.New("request from unauthorized CIDR")
        }
    }

    return nil
}
```

**Entity-Based Policy Inheritance**:

```go
// Entity provides identity across auth methods
type Entity struct {
    ID       string      // Unique entity ID
    Name     string      // Human-readable name
    Policies []string    // Directly assigned policies
    Aliases  []*Alias    // Auth method aliases
}

// When token is created with EntityID:
// effectivePolicies = token.Policies + entity.Policies + entity.GroupPolicies
```

---

## 6. Response Wrapping and Attestation

### Response Wrapping

**Location**: `vault/vault/wrapping.go`

#### Purpose
Protect sensitive responses in transit using single-use, TTL-limited wrapping tokens.

#### Architecture

```go
type WrapInfo struct {
    Token           string        // Single-use wrapping token
    TTL             time.Duration // Wrapping token TTL
    CreationTime    time.Time     // When wrapping occurred
    WrappedAccessor string        // Accessor of wrapped token (if applicable)
    Format          string        // "jwt" or "token"
}
```

#### JWT-Based Wrapping

**Key Management**:
```go
// ECDSA P-521 key for JWT signing
type wrappingKey struct {
    privateKey *ecdsa.PrivateKey  // Signing key
    publicKey  *ecdsa.PublicKey   // Verification key
}

// Stored at: core/wrapping/jwtkey
```

**Wrapping Process**:

```go
func (c *Core) WrapResponse(response *logical.Response) (*WrapInfo, error) {
    // 1. Serialize response
    responseJSON, _ := json.Marshal(response)

    // 2. Create wrapping token with single use
    wrapToken, err := c.tokenStore.createWrappingToken(
        TTL: defaultWrappingTTL,
        NumUses: 1,
        Policies: []string{"response-wrapping"},
    )

    // 3. Sign response as JWT (if configured)
    if c.wrappingJWT {
        claims := jwt.MapClaims{
            "token": wrapToken.ID,
            "accessor": wrapToken.Accessor,
            "response": base64.StdEncoding.EncodeToString(responseJSON),
            "exp": time.Now().Add(wrapToken.TTL).Unix(),
        }
        jwtToken, _ := jwt.SignedString(c.wrappingKey.privateKey, claims)
        return &WrapInfo{Token: jwtToken, Format: "jwt"}, nil
    }

    // 4. Store response in cubbyhole
    c.tokenStore.cubbyholePut(wrapToken.CubbyholeID, "response", responseJSON)

    return &WrapInfo{
        Token: wrapToken.ExternalID,
        TTL: wrapToken.TTL,
        Format: "token",
    }, nil
}
```

**Unwrapping Process**:

```go
func (c *Core) Unwrap(ctx context.Context, wrapToken string) (*logical.Response, error) {
    // 1. Lookup wrapping token
    token, err := c.tokenStore.Lookup(ctx, wrapToken)
    if err != nil || token.NumUses == 0 {
        return nil, errors.New("wrapping token expired or already used")
    }

    // 2. Retrieve wrapped response from cubbyhole
    entry, err := c.tokenStore.cubbyholeGet(token.CubbyholeID, "response")

    // 3. Revoke wrapping token (single-use enforcement)
    c.tokenStore.Revoke(ctx, wrapToken)

    // 4. Return original response
    var response logical.Response
    json.Unmarshal(entry.Value, &response)
    return &response, nil
}
```

**Security Properties**:
- Single-use tokens (automatically revoked after unwrap)
- TTL-limited (default: 5 minutes)
- JWT signatures provide integrity (optional)
- Cubbyhole isolation prevents other tokens from accessing
- Audit log captures wrap/unwrap events

### Attestation Mechanisms

While Vault doesn't have explicit "attestation" in the traditional sense, it provides several trust-building mechanisms:

#### 1. Seal Status Verification

```go
func (c *Core) SealStatus() (*SealStatusResponse, error) {
    return &SealStatusResponse{
        Type:         c.seal.BarrierType(),
        Initialized:  c.barrier.Initialized(),
        Sealed:       c.barrier.Sealed(),
        N:            c.sealConfig.SecretShares,
        T:            c.sealConfig.SecretThreshold,
        Progress:     len(c.unlockInfo.Keys),
        Nonce:        c.unlockInfo.Nonce,
        Version:      version.GetVersion().VersionNumber(),
        ClusterName:  c.clusterName,
        ClusterID:    c.clusterID,
    }, nil
}
```

**Verifiable Properties**:
- Seal state (sealed/unsealed)
- Initialization status
- Version information
- Cluster identity

#### 2. Rekey Verification

```go
type RekeyVerificationRequest struct {
    Key   string  // Verification key share
    Nonce string  // Operation nonce
}

// Rekey process includes verification phase:
// 1. Generate new keys
// 2. Store VerificationKey in seal config
// 3. Require threshold verification with new keys
// 4. Only commit after verification succeeds
```

**Purpose**: Ensures operators actually have the new keys before discarding old ones.

#### 3. Audit Logging

```go
type AuditEntry struct {
    Type      string          // "request" or "response"
    Auth      *AuditAuth      // Authentication info
    Request   *AuditRequest   // Request details
    Response  *AuditResponse  // Response details
    Error     string          // Error if any
}

type AuditAuth struct {
    Accessor     string            // Token accessor (NOT token ID)
    DisplayName  string            // Human-readable name
    Policies     []string          // Effective policies
    EntityID     string            // Identity entity
    Metadata     map[string]string // Auth metadata
}
```

**Audit Trail Properties**:
- Immutable append-only log
- Contains accessor (not sensitive token ID)
- Full request/response capture (with HMAC for sensitive fields)
- Cryptographic hashing of sensitive values
- Multiple audit device support (file, syslog, socket)

#### 4. Seal Wrapping Attestation (Enterprise)

**Location**: `vault/vault/seal_wrapped_value.go`

```go
type SealWrappedValue struct {
    // Multi-wrap support for values protected under multiple seals
    Wrapped      bool              // Is this value wrapped?
    Generation   uint64            // Generation number for cache coherency
    SealNames    []string          // Which seals protect this value
}
```

**Format**:
```
[16-byte header: "multiwrapvalue:1"]
[4-byte length]
[Protobuf MultiWrapValue]
```

**Purpose**: Provides cryptographic proof that specific values were protected by HSM/auto-seal.

---

## 7. Seal Wrapping (Enterprise Feature)

**Location**: `vault/vault/seal_wrapped_value.go`

### Purpose

Provide additional layer of encryption for highly sensitive data using external seals (HSM, Cloud KMS).

### Architecture

```go
type SealWrappedValue struct {
    // Multi-wrap support
    Wrapped    bool     // Is this value seal-wrapped?
    Generation uint64   // Generation number for cache coherency
    SealNames  []string // Which seals protect this value (e.g., ["awskms", "hsm"])
}

type MultiWrapValue struct {
    // Protobuf definition
    Slots []*MultiWrapValueSlot  // One slot per seal

    // Metadata
    Generation uint64   // Version tracking
    Plaintext  bool     // If true, value not encrypted (metadata only)
}

type MultiWrapValueSlot struct {
    SealName string   // Seal identifier
    Value    []byte   // Encrypted value under this seal
}
```

### Wire Format

```
[16-byte header: "multiwrapvalue:1"]
[4-byte length: uint32 big-endian]
[Protobuf-encoded MultiWrapValue]
```

### Encryption Process

```go
func (c *Core) SealWrap(plaintext []byte, sealNames []string) (*SealWrappedValue, error) {
    slots := make([]*MultiWrapValueSlot, len(sealNames))

    // Encrypt under each specified seal
    for i, sealName := seal := range c.seals[sealName] {
        ciphertext, err := seal.Encrypt(plaintext)
        slots[i] = &MultiWrapValueSlot{
            SealName: sealName,
            Value:    ciphertext,
        }
    }

    // Create multi-wrap value
    mwv := &MultiWrapValue{
        Slots:      slots,
        Generation: c.sealGeneration.Load(),
        Plaintext:  false,
    }

    // Encode as protobuf
    encoded, _ := proto.Marshal(mwv)

    // Add header and length
    result := append([]byte("multiwrapvalue:1"), encodeLength(len(encoded))...)
    result = append(result, encoded...)

    return &SealWrappedValue{
        Wrapped:    true,
        Generation: mwv.Generation,
        SealNames:  sealNames,
    }, nil
}
```

### Decryption Process

```go
func (c *Core) SealUnwrap(wrapped *SealWrappedValue) ([]byte, error) {
    // 1. Parse header
    if !bytes.HasPrefix(wrapped.Value, []byte("multiwrapvalue:1")) {
        return nil, errors.New("invalid seal wrap format")
    }

    // 2. Decode protobuf
    mwv := &MultiWrapValue{}
    proto.Unmarshal(wrapped.Value[20:], mwv)

    // 3. Try each seal slot until one succeeds
    for _, slot := range mwv.Slots {
        seal := c.seals[slot.SealName]
        if seal == nil {
            continue // Seal not available
        }

        plaintext, err := seal.Decrypt(slot.Value)
        if err == nil {
            return plaintext, nil
        }
    }

    return nil, errors.New("no seal could decrypt the value")
}
```

### Use Cases

**Paths that use seal wrapping**:
```
core/keyring              → Encryption keyring
core/master               → Root key
core/hsm-encrypted-key    → HSM-specific keys
auth/*/recovery-keys      → Recovery keys
sys/mfa/*                 → MFA secrets
```

**Benefits**:
- Extra protection for master keys
- Audit trail in cloud provider (KMS logs)
- Hardware-backed security (HSM)
- Regulatory compliance (FIPS 140-2/3)

---

## 8. Key Security Features Summary

### Cryptographic Properties

| Feature | Implementation | Security Benefit |
|---------|---------------|------------------|
| **Encryption Algorithm** | AES-256-GCM | NIST-approved, authenticated encryption |
| **Key Size** | 256 bits | Post-quantum resistant (for symmetric) |
| **Nonce** | 12 bytes random | Prevents replay attacks |
| **Auth Tag** | 16 bytes | Integrity and authenticity |
| **Key Rotation** | Automatic at 3.86B ops | Limits key exposure window |
| **Master Key** | Never persisted plaintext | Prevents offline attacks |
| **Memory Zeroing** | `memzero()` after use | Prevents memory dumps |

### Defense in Depth Layers

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: Seal (Defense against offline attacks)    │
│  - Vault must be unsealed (master key in memory)    │
│  - Sealed = All encryption/decryption blocked       │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│ Layer 2: Barrier Encryption (Data confidentiality) │
│  - All data encrypted with AES-GCM before storage   │
│  - Key rotation without rewrapping data             │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│ Layer 3: ACL Policies (Authorization)              │
│  - Path-based access control                        │
│  - Capability checks (create/read/update/delete)    │
│  - Entity-based policy inheritance                  │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│ Layer 4: Namespace Isolation (Multi-tenancy)       │
│  - BarrierView prefix enforcement                   │
│  - Prevents cross-namespace access                  │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│ Layer 5: Audit Logging (Accountability)            │
│  - Immutable audit trail                            │
│  - Accessor indirection (no sensitive data in logs) │
│  - HMAC of sensitive fields                         │
└─────────────────────────────────────────────────────┘
```

### Token Security Features

| Feature | Description | Benefit |
|---------|-------------|---------|
| **Accessor Indirection** | Separate UUID for audit logs | Prevents token leakage |
| **Revocation Trees** | Parent-child relationships | Cascading revocation |
| **Cubbyhole Storage** | Per-token private storage | Isolated data storage |
| **NumUses Limits** | Count-based expiration | Limits token abuse |
| **CIDR Restrictions** | IP-based access control | Reduces attack surface |
| **Entity Linking** | Identity across auth methods | Unified access control |
| **Batch Tokens** | Non-persistent, inline encrypted | High-throughput, ephemeral |

### Storage Security Properties

| Property | Implementation | Security Guarantee |
|----------|----------------|-------------------|
| **Encryption at Rest** | All values encrypted | Storage compromise ≠ data exposure |
| **Backend Agnostic** | Pluggable storage | No trust in backend required |
| **Path Isolation** | BarrierView prefixes | Cross-mount protection |
| **Version Tracking** | SealWrappedValue generations | Cache coherency, replay detection |
| **Historical Keys** | Multi-term keyring | Backward compatibility without rewrap |

---

## 9. Recommendations for API Key Systems

Based on Vault's architecture, here are key design principles for a secure API key management system:

### ✅ Must Have

1. **Encryption at Rest**:
   - Use AES-256-GCM for all stored data
   - Implement keyring-based rotation (avoid rewrapping all data)
   - Never persist master key in plaintext

2. **Access Control**:
   - Implement path-based ACL system
   - Use capability-based permissions (not just CRUD)
   - Support policy inheritance via entities/groups

3. **Audit Logging**:
   - Use accessor indirection (never log actual API keys)
   - Immutable, append-only audit trail
   - HMAC sensitive fields before logging

4. **Token Structure**:
   - Support both persistent and ephemeral tokens
   - Implement TTL and usage limits
   - Create revocation trees (parent-child relationships)

5. **Secure Initialization**:
   - One-time initialization process
   - Shamir secret sharing for master key (or HSM)
   - Show root credentials only once

### ⚠️ Should Have

1. **Response Wrapping**:
   - Protect sensitive responses in transit
   - Single-use wrapping tokens with short TTL
   - JWT signatures for integrity

2. **Namespace Isolation**:
   - Multi-tenancy via path prefixes
   - Prevent cross-tenant access

3. **High Availability**:
   - Leader election via distributed locks
   - Standby node support with upgrade paths

4. **Key Rotation**:
   - Automatic rotation based on operation count
   - Time-based rotation policies
   - Seamless rotation without downtime

### 🚀 Nice to Have

1. **Seal Wrapping**:
   - Additional HSM/KMS protection for master keys
   - Multi-seal support for defense in depth

2. **Auto-Seal**:
   - Cloud KMS integration (AWS/Azure/GCP)
   - Automatic unsealing on restart

3. **Sentinel Policies**:
   - Fine-grained, code-based policies
   - Role/endpoint-governing policies

---

## 10. File References

### Core Token Files

- `vault/sdk/logical/token.go` - TokenEntry structure
- `vault/vault/token_store.go:1044+` - Token creation logic
- `vault/vault/expiration.go` - Token TTL and expiration

### Encryption Files

- `vault/vault/barrier_aes_gcm.go` - AES-GCM barrier implementation
- `vault/vault/keyring.go` - Keyring management and rotation
- `vault/vault/barrier.go` - SecurityBarrier interface

### Storage Files

- `physical/cockroachdb/cockroachdb.go` - CockroachDB backend example
- `sdk/physical/entry.go` - Physical storage entry structure
- `sdk/logical/storage.go` - Logical storage entry structure

### Access Control Files

- `vault/vault/acl.go` - ACL system and policy evaluation
- `vault/vault/barrier_view.go` - Namespace isolation
- `vault/vault/policy.go` - Policy parsing and management

### Seal/Unseal Files

- `vault/vault/core.go` - Core initialization and unsealing
- `vault/vault/seal_config.go` - Seal configuration structure
- `vault/vault/seal.go` - Seal interface

### Security Files

- `vault/vault/wrapping.go` - Response wrapping
- `vault/vault/seal_wrapped_value.go` - Seal wrapping (Enterprise)
- `vault/vault/audit.go` - Audit logging

---

## 11. Questions for Further Exploration

The following questions emerged from comparing Vault's architecture with the RFC API Key Security Specification requirements. They are organized by topic to guide further investigation into how Vault implements (or could implement) specific RFC recommendations.

**Priority Levels**:
- **Critical**: Affects security posture or compliance requirements
- Standard: Important for operational capability or best practices alignment
- Low priority: Nice-to-have features or future enhancements

### Token Generation and Format Design

- [ ] Do Vault tokens include checksum validation for error detection (like GitHub's 6-character checksum)?
- [ ] What is the exact entropy calculation for 24-character base62 tokens? (Expected: log2(62^24) = ~143 bits)
- [ ] Can Vault token prefixes be customized per token type or policy?
- [ ] How does Vault's token format compare to RFC recommendations for `[PREFIX]_[SECRET][CHECKSUM]` structure?

### Token Storage and Validation Security Model

- [ ] **Critical**: Why does Vault use encryption instead of BCrypt/Argon2 hashing for token storage?
  - RFC requires hash-only storage (BCrypt/Argon2) to protect against database compromise
  - Vault stores encrypted TokenEntry, which exposes tokens if barrier is unsealed during compromise
  - What are the security trade-offs? Does Vault's sealed barrier provide equivalent protection?
- [ ] Can Vault implement hash-based validation mode for compliance requirements (PCI DSS, etc.)?
- [ ] What is the performance difference between Vault's AES-GCM validation vs. RFC's BCrypt approach?
  - RFC benchmarks: BCrypt ~12ms per validation, recommends caching
  - Vault: Database lookup + AES-GCM decryption - what is actual latency?
- [ ] Does Vault cache successful token authentication results to improve performance?

### Stateless vs Stateful Token Models

- [ ] How does Vault's batch token implementation compare to Keycloak's JWT stateless model?
- [ ] What is the exact format of batch tokens (encrypted protobuf structure)?
- [ ] Could Vault implement a pure stateless mode with revocation lists (like Keycloak)?
  - Store only revoked token IDs + expiration timestamps
  - Enable instant revocation while maintaining stateless validation
- [ ] What are the performance characteristics of service tokens (stateful) vs batch tokens (stateless)?

### Rotation and Lifecycle Management

- [ ] How does Vault handle token renewal and TTL extension?
- [ ] Does Vault support automated token rotation with grace periods (RFC requirement: 24-72 hour overlap)?
  - RFC pattern: Generate K2 while K1 valid, both work during grace period, then K1 expires
  - Can Vault issue overlapping tokens or only extend single token TTL?
- [ ] What is Vault's recommended token rotation schedule (30/60/90 days per RFC risk levels)?
- [ ] How does parent token rotation affect child token validity?
- [ ] Can entities have multiple active tokens with different permissions (multi-key model)?
- [ ] Does Vault enforce maximum token age or alert on old tokens?

### Revocation and Security

- [ ] **Critical**: How are stateless batch tokens revoked before expiration?
  - Can they be revoked at all, or must they expire naturally?
  - Does Vault maintain a revocation list for batch tokens?
- [ ] Does Vault maintain revocation lists for performance optimization (à la Keycloak)?
  - Pattern: Store only revoked token IDs + expiration, not full tokens
  - Enables fast "is this revoked?" checks
- [ ] Can Vault revoke all tokens for an entity in a single operation (batch revocation)?
- [ ] Does Vault track token reuse to prevent replay attacks?
  - RFC requirement: Mark token as "used" in cache/database
  - On reuse, detect replay and revoke session
  - Critical for batch tokens which are stateless
- [ ] Does Vault prevent reuse of revoked token IDs (blacklisting)?
- [ ] Does Vault support revocation rollback for accidental revocations?

### Access Control and Authorization

- [ ] How does Vault's path-based ACL system compare to RFC's scope-based permissions?
  - RFC model: Scopes like `api:read`, `users:write` assigned to keys
  - Vault model: Path-based capabilities (create, read, update, delete, list, sudo)
  - Which is more granular? Can Vault express same constraints?
- [ ] Can Vault tokens have different scopes/permissions without different policies?
  - Scenario: Same role, different scopes per token
- [ ] Does Vault support per-token resource restrictions beyond path-based ACLs?
  - RFC example: "This key can only access customer ID 12345"
  - Vault: Path templating with `{{identity.entity.id}}`?
- [ ] How does Vault enforce "deny by default" principle?
- [ ] How do Sentinel policies integrate with base ACL system?

### Monitoring, Logging, and Audit

- [ ] Does Vault's audit system comply with RFC logging requirements?
  - RFC fields: Timestamp, key ID (hashed), IP, resource, status, latency
  - Map Vault's AuditEntry to RFC requirements
- [ ] How does Vault handle audit log retention and rotation?
  - RFC: 90 days minimum, 1 year recommended
  - Does Vault enforce retention or delegate to audit device?
- [ ] Does Vault provide built-in anomaly detection for token usage?
  - RFC requirements: Velocity checks, volume anomalies, geographic anomalies
  - Or must this be done by external SIEM?
- [ ] What native SIEM integrations does Vault support?
  - Known: Syslog can forward to SIEM
  - Native connectors for Splunk, ELK, QRadar, Datadog?
- [ ] Does Vault track per-token usage patterns for security analysis?
  - RFC metrics: Request volume, error rates, geographic data per key
  - Can Vault alert on unusual token usage?

### Rate Limiting and Abuse Prevention

- [ ] Does Vault have built-in per-token rate limiting?
  - RFC requirement: Layered rate limits (per-second, per-hour, per-day)
  - Or is this delegated to API gateway/proxy?
- [ ] Can Vault enforce request quotas per token or entity?
  - RFC pattern: Different limits for different key types (read-only, admin)
- [ ] How does Vault handle brute force authentication attacks?
  - RFC mitigation: Rate limiting on failed authentication attempts
  - Progressive delays? Account lockout?
- [ ] Does Vault return RFC-compliant rate limit responses?
  - RFC requirement: HTTP 429 with `Retry-After` header

### Transmission and Network Security

- [ ] Does Vault support RFC 6750 Bearer token authentication scheme?
  - Current: Custom `X-Vault-Token` header
  - RFC: `Authorization: Bearer <token>`
  - Why the difference? Compatibility implications?
- [ ] Can Vault enforce TLS 1.3 as minimum version?
  - RFC requirement: TLS 1.3 REQUIRED, TLS 1.2 acceptable fallback
  - Can Vault reject TLS 1.2 and below?
- [ ] Does Vault send HSTS headers?
  - RFC: `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
- [ ] How does Vault prevent token leakage in URLs?
  - RFC prohibition: MUST NOT transmit keys in query parameters
  - Vault design prevents this by design?

### Cryptographic Agility and Future-Proofing

- [ ] Can Vault migrate from AES-GCM to a different encryption algorithm?
  - Current: AESGCMVersion1 and Version2 (both use AES-GCM)
  - RFC requirement: Support migration to different algorithm families
  - Can Vault switch to ChaCha20-Poly1305, post-quantum algorithms, etc.?
- [ ] Does Vault have a post-quantum cryptography roadmap?
  - RFC concern: Quantum computers may break current crypto
  - Keycloak example: Experimental ML-DSA support (post-quantum signatures)
  - Is Vault evaluating NIST post-quantum algorithms (ML-KEM, ML-DSA, SLH-DSA)?
- [ ] How does Vault handle algorithm deprecation?
  - Scenario: AES-GCM found vulnerable, need to migrate
  - Can Vault re-encrypt all data with new algorithm?

### High Availability and Performance

- [ ] How does HA failover work in detail?
- [ ] What are the performance characteristics of different storage backends?
- [ ] What is the maximum sustainable token validation throughput?
- [ ] How does Vault handle token validation in multi-region deployments?
  - Challenge: Token created in region A, validated in region B
  - RFC pattern: Stateless tokens enable global validation
- [ ] What is the performance impact of seal wrapping?

### Compliance and Standards

- [ ] What are the specific FIPS 140-2/3 compliance features?
  - Does Vault have FIPS-certified build?
  - HSM integration details for FIPS 140-2 Level 3+?
- [ ] Can Vault generate compliance reports (PCI DSS, SOC 2, HIPAA)?
  - Built-in reports or requires external processing?
- [ ] How does Vault handle GDPR right to erasure for tokens?
  - Does token deletion remove all traces from audit logs?
  - Or are audit logs immutable (conflict with GDPR)?

### Identity and Authentication

- [ ] How does identity/entity system work across auth methods?
- [ ] What are the different auth backend architectures (LDAP, OIDC, etc.)?
- [ ] How does Vault handle database credential rotation?

---

## Glossary

- **Barrier**: Encryption layer that wraps physical storage, providing encryption/decryption
- **Seal**: Protection mechanism requiring master key to unlock Vault
- **Keyring**: Collection of encryption keys (historical + active)
- **Term**: Sequential number identifying a specific encryption key
- **Accessor**: Non-sensitive UUID for referencing tokens in audit logs
- **Cubbyhole**: Private per-token storage space
- **Service Token**: Persistent token stored in backend
- **Batch Token**: Ephemeral token encrypted inline, not persisted
- **Root Token**: Unrestricted token with all capabilities
- **Entity**: Identity that spans multiple auth methods
- **Namespace**: Isolated path prefix for multi-tenancy
- **BarrierView**: Path-prefixed view of the barrier for isolation
- **Seal Wrapping**: Additional encryption layer using HSM/KMS
- **Response Wrapping**: Single-use token protecting sensitive responses
