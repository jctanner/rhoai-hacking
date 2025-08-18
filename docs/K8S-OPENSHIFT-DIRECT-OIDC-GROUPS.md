# Managing Groups with OIDC in Kubernetes

When migrating from **OpenShift-managed groups** to **direct OIDC
authentication** with the Kubernetes API server, group membership lives
entirely in the **Identity Provider (IdP)** (e.g., Keycloak, Microsoft
Entra). Below is guidance for how to handle this setup, including how
IdP group APIs work.

## Architecture Overview

The diagram below illustrates the complete OIDC group management ecosystem, showing three distinct workflows:

1. **User Authentication Flow** (top path): Users authenticate with the IdP and receive tokens containing group claims for Kubernetes API access
2. **Administrative Group Discovery** (middle path): Service accounts use IdP admin APIs to enumerate available groups and discover membership (for automation/tooling)
3. **GitOps RBAC Policy Management** (bottom path): RBAC policies that reference IdP group names are declaratively managed in Git and applied to the cluster

```mermaid
graph TD
    A["User"] --> B["Identity Provider<br/>(Keycloak/Entra)"]
    B --> C["OIDC ID Token<br/>with groups claim"]
    C --> D["Kubernetes API Server<br/>--oidc-groups-claim=groups"]
    D --> E["RBAC Evaluation"]
    E --> F["ClusterRoleBinding<br/>subjects: Group"]
    F --> G["Access Granted/Denied"]
    
    H["Admin/Service Account"] --> I["IdP Admin API<br/>(Keycloak Admin/MS Graph)"]
    I --> J["Access Token<br/>with appropriate scopes"]
    J --> K["Group Discovery<br/>Membership Queries"]
    
    L["GitOps Repository"] --> M["RBAC Policy Manifests<br/>(RoleBindings referencing IdP groups)"]
    M --> D
```

**Key Points:**
- **Group membership** is managed entirely in the IdP, not in Kubernetes
- **RBAC policies** reference IdP group names/IDs as subjects in role bindings (managed via GitOps)
- **Group discovery** (listing available groups, querying membership) requires separate access tokens with admin scopes
- **GitOps workflows** manage the RBAC policy definitions, but actual group membership changes happen in the IdP

------------------------------------------------------------------------

## 1. How IdP Group APIs Work

### Keycloak

-   **Token injection**: Keycloak can include groups (or roles) as
    claims in tokens (e.g., `groups`).
-   **Group enumeration via Admin API**:
    -   `GET /{realm}/groups` → list all groups (paginated).
    -   `GET /{realm}/groups/{id}` → details for one group.
    -   `GET /{realm}/users/{id}/groups` → groups for a specific user.
-   Requires an **access token** with appropriate roles (`view-groups`,
    `view-users`), not just an ID token from login.

**Example:**

``` bash
# Get admin token (client credentials)
curl -X POST https://<KEYCLOAK>/realms/<realm>/protocol/openid-connect/token   -d grant_type=client_credentials   -d client_id=<admin-client>   -d client_secret=<secret>

# List groups
curl -H "Authorization: Bearer <access_token>"   https://<KEYCLOAK>/admin/realms/<realm>/groups
```

### Microsoft Entra ID (Azure AD)

-   **Token injection**: Can include `groups` claims in ID/Access
    tokens. If the user is in too many groups, a **link to Microsoft
    Graph** is added instead of embedding them all.
-   **Group enumeration via Microsoft Graph API**:
    -   `GET https://graph.microsoft.com/v1.0/groups` → all groups.
    -   `GET https://graph.microsoft.com/v1.0/me/memberOf` → groups for
        signed-in user.
    -   `GET https://graph.microsoft.com/v1.0/users/{id}/memberOf` →
        groups for a given user.
-   Requires an **access token** minted for Graph
    (`aud: https://graph.microsoft.com`) with scopes like
    `Group.Read.All` or `Directory.Read.All`.

**Example:**

``` bash
# Get Graph token (client credentials)
curl -X POST https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token   -d grant_type=client_credentials   -d client_id=<appId>   -d client_secret=<secret>   -d scope="https://graph.microsoft.com/.default"

# List groups
curl -H "Authorization: Bearer <graph_access_token>"   https://graph.microsoft.com/v1.0/groups
```

**Important:**
- An **ID token from login is not enough**. You need an **access token**
with the right `aud` and scopes.

### Admin API Access Token Requirements

Both Keycloak and Microsoft Entra ID share similar challenges when it comes to accessing group information via their admin APIs.

**The Core Problem:**

The ID token from user login is designed for authentication and contains user claims (including groups if configured). However, both IdP admin APIs require a separate access token with admin privileges. This creates a chicken-and-egg problem: you need admin access to list groups, but users typically shouldn't have admin roles.

**Token Exchange Solution:**

OAuth 2.0 Token Exchange (RFC 8693) can help bridge this gap:

``` bash
# Keycloak token exchange
curl -X POST https://<KEYCLOAK>/realms/<realm>/protocol/openid-connect/token \
  -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange \
  -d client_id=<your-client> \
  -d client_secret=<secret> \
  -d subject_token=<user-id-token> \
  -d requested_token_type=urn:ietf:params:oauth:token-type:access_token \
  -d audience=<admin-client-id>

# Microsoft Entra ID on-behalf-of flow (similar concept)
curl -X POST https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token \
  -d grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
  -d client_id=<client-id> \
  -d client_secret=<secret> \
  -d assertion=<user-access-token> \
  -d scope=https://graph.microsoft.com/.default \
  -d requested_token_use=on_behalf_of
```

**Remaining Challenges:**
- **Permission Model**: Users still need admin roles assigned, which may violate least-privilege principles
- **Security Scope**: Exchanged tokens might grant broader admin access than needed
- **Token Lifetime**: Admin tokens may have different expiration policies than user tokens
- **Complexity**: Additional token management logic in applications
- **Delegation Rights**: Requires careful configuration of delegation permissions

**Better Alternatives:**
- **Service Account Pattern**: Use client credentials flow with a dedicated service account that has only the necessary group read permissions
- **Proxy Service**: Build a lightweight API that handles group lookups with proper authorization and caching
- **IdP Configuration**: Configure group claims to include all necessary groups in ID tokens, avoiding admin API calls entirely
- **Group Synchronization**: Periodically sync group information to a local cache or database

### Token Types and Usage

```mermaid
graph LR
    A["User Login"] --> B["ID Token"]
    A --> C["Access Token"]
    
    B --> D["Kubernetes API<br/>Authentication"]
    B --> E["Contains: sub, groups<br/>Audience: client-id"]
    
    C --> F["IdP Admin APIs<br/>Group Management"]
    C --> G["Contains: scopes<br/>Audience: IdP/Graph API"]
    
    subgraph "ID Token Usage"
        D
        E
    end
    
    subgraph "Access Token Usage"
        F
        G
    end
    
    H["Client Credentials Flow"] --> I["Service Account<br/>Access Token"]
    I --> F
```

### Group Dependency Caveats

While embedding groups in OIDC tokens is convenient, there are several important limitations to consider:

**Token Size Limits:**

OIDC tokens are typically transmitted in HTTP headers, which have size constraints:
- **Web servers**: Nginx default is 4KB-8KB, Apache 8KB
- **Load balancers**: Often 16KB-32KB limits
- **Browsers**: Vary widely, some as low as 2KB for cookies
- **Proxies**: Corporate proxies may have strict limits

When users belong to many groups, tokens can exceed these limits, causing authentication failures.

**Group Overage Handling:**

Both IdPs have mechanisms to handle large group lists:

``` bash
# Keycloak: Groups may be omitted if token becomes too large
# Check realm settings for "Access Token Lifespan" and group claim limits

# Microsoft Entra ID: Returns overage claim instead of groups
{
  "aud": "your-app-id",
  "sub": "user-id", 
  "groups": ["group1", "group2"],  # Only partial list
  "_claim_names": {
    "groups": "src1"
  },
  "_claim_sources": {
    "src1": {
      "endpoint": "https://graph.microsoft.com/v1.0/me/memberOf"
    }
  }
}
```

**Important:** The endpoint in `_claim_sources` requires a Microsoft Graph access token, NOT the user's ID token. This creates the same token access challenge discussed earlier - you need a separate token with `aud: https://graph.microsoft.com` and appropriate scopes like `Group.Read.All`.

**Performance Impacts:**
- **Network overhead**: Large tokens increase bandwidth usage
- **Parsing cost**: Applications must parse larger JSON structures
- **Memory usage**: Tokens stored in session state consume more memory
- **Caching complexity**: Large tokens complicate caching strategies

**Recommended Mitigations:**

1. **Group Filtering**: Configure IdP to include only relevant groups in tokens
2. **Role-Based Claims**: Use roles instead of groups (`--oidc-groups-claim=roles`)
3. **Group Hierarchies**: Structure groups to minimize membership overlap
4. **Lazy Loading**: Fetch detailed group information on-demand via admin APIs
5. **Proxy Services**: Use intermediary services to manage group resolution
6. **Token Compression**: Some IdPs support compressed tokens (rarely practical)

**Monitoring and Alerting:**
- Monitor token sizes in production
- Alert on authentication failures due to header size limits
- Track group membership growth over time

------------------------------------------------------------------------

## 2. Kubernetes with OIDC: Suggested Approach

### Use IdP Groups Directly

-   Configure the API server with:
    -   `--oidc-issuer-url=...`
    -   `--oidc-client-id=...`
    -   `--oidc-username-claim=sub|email`
    -   `--oidc-groups-claim=groups`
    -   (Optional) `--oidc-groups-prefix=oidc:`
-   Bind RBAC roles directly to IdP group strings.

**Example:**

``` yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: view-for-team-platform
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: Group
  name: oidc:team-platform
```

### Authentication and Authorization Flow

```mermaid
sequenceDiagram
    participant User
    participant IdP as Identity Provider
    participant K8s as Kubernetes API Server
    participant RBAC as RBAC Engine
    
    User->>IdP: 1. Authenticate (username/password)
    IdP->>IdP: 2. Validate credentials
    IdP->>IdP: 3. Lookup user groups
    IdP->>User: 4. Return ID Token (with groups claim)
    User->>K8s: 5. API Request + Bearer Token
    K8s->>K8s: 6. Validate token signature
    K8s->>K8s: 7. Extract username and groups
    K8s->>RBAC: 8. Check permissions (user, groups, resource)
    RBAC->>K8s: 9. Allow/Deny decision
    K8s->>User: 10. API Response
```

### Handle Group Overage

-   **Preferred:** Configure IdP to emit group names or IDs under the
    claim threshold.
-   **Alternative:** Use an OIDC broker (Dex, Pinniped) that expands
    groups into a new token.
-   **Or:** Use roles instead of groups (`--oidc-groups-claim=roles`).

### Replace OpenShift Group APIs

-   OpenShift provided first-class `Group` objects. Kubernetes does
    not.
-   Manage RBAC in **GitOps** (Helm/Kustomize) with
    Role/ClusterRoleBindings that reference IdP group strings.
-   If automation is needed, query IdP APIs (Keycloak Admin API or
    Microsoft Graph) and render RBAC YAML.

### Application Group Lookups

-   Apps needing "list all groups" should query IdP APIs, not
    Kubernetes.\
-   Use **service accounts** or **client credentials** for backend
    calls.

### Naming & Stability

-   Prefer **group IDs** if possible (immutable).
-   If using names, standardize conventions.
-   Use `--oidc-groups-prefix` to avoid collisions.

### Common Pitfalls

-   Expecting Kubernetes to expand group overage links.
-   Creating Kubernetes `Group` objects (they have no effect).
-   Calling IdP APIs directly from browser apps (CORS/perms issues).
-   Confusing ID tokens with access tokens.

------------------------------------------------------------------------

## 3. Day-0 Checklist

1.  Configure apiserver OIDC flags (issuer, client, username, groups,
    prefix).
2.  Ensure IdP emits groups/roles you plan to bind.
3.  Create baseline RBAC bindings in GitOps.\
4.  Use IdP APIs for group enumeration, not Kubernetes.\
5.  Manage membership only in the IdP.

------------------------------------------------------------------------

**Summary:**
- Groups should be **managed in the IdP**.
- Kubernetes consumes groups as strings from OIDC claims.\
- If you need all groups or membership data, query the **IdP's
Admin/Graph API** with a proper access token.
- Keep RBAC declarative in Git, and avoid drift between K8s and the IdP.
