# Keycloak Integration Guide

This guide covers setting up Keycloak as an identity provider for OpenShift Container Platform (OCP) and Open Data Hub (ODH) integration.

## Table of Contents
- [Container Setup](#container-setup)
- [Realm Configuration](#realm-configuration)
- [Client Configuration](#client-configuration)
- [OpenShift BYOIDC Integration](#openshift-byoidc-integration)
- [ROSA Integration](#rosa-red-hat-openshift-on-aws-integration)
- [ODH Client Configuration](#odh-client-configuration)

## Container Setup

### Spinning up Keycloak Container

#### Quick Start (No External Database Required)

Keycloak runs perfectly fine without an external database - it uses an embedded H2 database by default, which is ideal for development and testing.

**Using Docker:**
```bash
# Simple Keycloak setup - no external database needed!
docker run -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin123 \
  quay.io/keycloak/keycloak:latest \
  start-dev
```

**Using Podman:**
```bash
# Simple Keycloak setup with Podman
podman run -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin123 \
  quay.io/keycloak/keycloak:latest \
  start-dev
```

#### Docker Compose (Simple Setup)
```yaml
version: '3.8'
services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin123
    ports:
      - "8080:8080"
    command: start-dev
    # Data is stored in embedded H2 database
    # For persistence, mount a volume:
    # volumes:
    #   - keycloak_data:/opt/keycloak/data

# Uncomment if you want persistent storage:
# volumes:
#   keycloak_data:
```

#### Production Setup with External Database (Optional)

For production environments, you may want to use an external database like PostgreSQL:

**Docker with PostgreSQL:**
```bash
# Production-ready setup with external database
docker run -p 8080:8080 \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://localhost:5432/keycloak \
  -e KC_DB_USERNAME=keycloak \
  -e KC_DB_PASSWORD=password \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin123 \
  quay.io/keycloak/keycloak:latest \
  start --optimized
```

**Docker Compose with PostgreSQL:**
```yaml
version: '3.8'
services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin123
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: password
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    command: start
    
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## Realm Configuration

### Using Realm Files at Startup Time

Create a realm configuration file (`realm-export.json`) and mount it to the container:

```bash
# Mount realm file during container startup
docker run -p 8080:8080 \
  -v /path/to/realm-export.json:/opt/keycloak/data/import/realm.json \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin123 \
  quay.io/keycloak/keycloak:latest \
  start-dev --import-realm
```

#### Example Realm Configuration
```json
{
  "realm": "openshift",
  "enabled": true,
  "displayName": "OpenShift Realm",
  "accessTokenLifespan": 3600,
  "sslRequired": "external",
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,
  "editUsernameAllowed": false,
  "bruteForceProtected": true,
  "clients": []
}
```

### Using API to Create Realms

#### Get Admin Token
```bash
# Get admin access token
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin123" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')
```

#### Create Realm via API
```bash
# Create new realm
curl -X POST "http://localhost:8080/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "openshift",
    "enabled": true,
    "displayName": "OpenShift Realm",
    "accessTokenLifespan": 3600,
    "sslRequired": "external"
  }'
```

### Creating Realms in the UI

1. Access Keycloak Admin Console at `http://localhost:8080`
2. Login with admin credentials
3. Click "Create Realm" button
4. Enter realm name (e.g., "openshift")
5. Configure realm settings:
   - **General**: Set display name, HTML display name
   - **Login**: Configure login options (remember me, email as username, etc.)
   - **Keys**: Manage signing keys
   - **Email**: Configure SMTP settings for email notifications
   - **Themes**: Customize login/account themes
   - **Localization**: Set supported locales
   - **Security Defenses**: Configure brute force protection, headers, etc.

## Client Configuration

### Creating Clients in the UI

**⚠️ Important: Redirect URLs Matter!**

**Security Best Practice:** Always use specific, exact redirect URIs. Never use wildcards (`*`) in redirect URIs as they create security vulnerabilities by allowing potential redirect attacks to arbitrary URLs.

1. Navigate to your realm → Clients → Create Client
2. **General Settings:**
   - Client type: `OpenID Connect`
   - Client ID: `openshift` (for OCP) or `odh` (for ODH)
3. **Capability Config:**
   - Client authentication: `On` (for confidential clients)
   - Authorization: `Off` (unless using fine-grained authorization)
   - Standard flow: `On`
   - Direct access grants: `On`
4. **Login Settings:**
   - **Root URL**: `https://your-cluster-domain`
   - **Home URL**: `https://your-cluster-domain`
   - **Valid redirect URIs**: 
     - For BYOIDC Console: `https://console-openshift-console.apps.your-cluster-domain.com/auth/callback`
     - For BYOIDC CLI: `http://localhost:8080`, `https://oauth.openshift.io/*`
     - For ODH: `https://rhods-dashboard.apps.your-cluster-domain.com/oauth2callback/keycloak`
   - **Valid post logout redirect URIs**: 
     - `https://console-openshift-console.apps.your-cluster-domain.com`
     - `https://rhods-dashboard.apps.your-cluster-domain.com`
   - **Web origins**: `+` (or specific origins like `https://console-openshift-console.apps.your-cluster-domain.com`)

**Note**: For BYOIDC integration, you'll need multiple clients as detailed in the [OpenShift BYOIDC Integration](#openshift-byoidc-integration) section.

#### Critical Redirect URL Configuration

For OpenShift integration, the redirect URL format is crucial:
```
https://oauth-openshift.apps.<cluster-domain>/oauth2callback/<identity-provider-name>
```

Example:
```
https://oauth-openshift.apps.cluster-abc123.abc123.sandbox123.opentlc.com/oauth2callback/keycloak
```

### Client API Configuration

```bash
# Create OpenShift client via API
curl -X POST "http://localhost:8080/admin/realms/openshift/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "openshift",
    "enabled": true,
    "clientAuthenticatorType": "client-secret",
    "redirectUris": ["https://oauth-openshift.apps.your-cluster-domain.com/oauth2callback/keycloak"],
    "webOrigins": ["https://console-openshift-console.apps.your-cluster-domain.com"],
    "publicClient": false,
    "protocol": "openid-connect",
    "standardFlowEnabled": true,
    "directAccessGrantsEnabled": true
  }'
```

## OpenShift BYOIDC Integration

**🚨 IMPORTANT: These instructions are for self-managed/on-premises OpenShift clusters only!**

**Managed OpenShift services use different identity integration methods:**
- **ROSA (Red Hat OpenShift on AWS)**: Uses very different identity provider configurations

For managed OpenShift services, consult the specific documentation for your platform rather than following these BYOIDC instructions.

## ROSA (Red Hat OpenShift on AWS) Integration

**⚠️ CRITICAL: External auth providers must be enabled at cluster creation time and cannot be changed afterwards!**

### ROSA Cluster Creation

When creating a ROSA cluster that will use external identity providers like Keycloak, you **must** include the `--external-auth-providers-enabled` flag during cluster creation:

```bash
rosa create cluster \
    --sts \
    --oidc-config-id $OIDC_CONFIG_ID \
    --cluster-name=$CLUSTER_NAME \
    --version=4.19.4 \
    --sts \
    --mode=auto \
    --hosted-cp \
    --subnet-ids=$PRIVATE_SUBNET,$PUBLIC_SUBNET \
    --compute-machine-type $MACHINE_POOL_TYPE \
    --role-arn=$INSTALLER_ROLE \
    --support-role-arn=$SUPPORT_ROLE \
    --worker-iam-role=$WORKER_ROLE \
    --external-auth-providers-enabled
```

**Note**: Replace `4.19.4` with the latest available OpenShift version. You can check available versions with:
```bash
rosa list versions --channel-group=stable
```

**Key Points:**
- The `--external-auth-providers-enabled` flag is **required** for Keycloak integration
- This setting **cannot be modified** after cluster creation
- If you forget this flag, you'll need to recreate the cluster entirely
- ROSA uses different identity provider configuration methods than self-managed OpenShift

### ROSA Identity Provider Configuration

Once your ROSA cluster is created with external auth providers enabled, configure Keycloak as an external auth provider using the ROSA CLI:

```bash
rosa create external-auth-provider \
    --cluster=$ROSA_CLUSTER_NAME \
    --name=keycloak \
    --issuer-url=https://your-keycloak-domain/realms/your-realm \
    --issuer-audiences=rosa-console,rosa-cli,odh-dashboard \
    --claim-mapping-username-claim=preferred_username \
    --claim-mapping-groups-claim=groups \
    --console-client-id=rosa-console \
    --console-client-secret=your-console-client-secret
```

**Configuration Parameters:**
- `--cluster`: Your ROSA cluster name
- `--name`: Name for the external auth provider (e.g., "keycloak")
- `--issuer-url`: Your Keycloak realm URL (replace with your actual domain and realm)
- `--issuer-audiences`: Comma-separated list of audiences (console, CLI, and ODH)
- `--claim-mapping-username-claim`: Maps to `preferred_username` from Keycloak
- `--claim-mapping-groups-claim`: Maps to `groups` claim for RBAC
- `--console-client-id`: Client ID for the console (must match Keycloak client)
- `--console-client-secret`: Client secret from Keycloak

**Prerequisites for ROSA External Auth:**
- ROSA cluster created with `--external-auth-providers-enabled`
- Keycloak realm configured with appropriate clients:
  - `rosa-console`: Confidential client for OpenShift Console
  - `rosa-cli`: Public client for CLI access  
  - ODH client configured with `odh-dashboard` audience

### Prerequisites
- **Self-managed OpenShift 4.19+ cluster** (not ROSA) with cluster-admin privileges
- Accessible Keycloak instance with configured realm and client
- Valid TLS certificates (for production)
- **Important**: BYOIDC is a TechPreview feature that requires enabling TechPreviewNoUpgrade featureset (see configuration steps below)

### Reference Documentation
- [OpenShift External Authentication](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html-single/authentication_and_authorization/index#external-auth)

### Configuration Steps

#### 1. Enable BYOIDC Feature (Required)

**⚠️ WARNING: This will reboot the cluster and may take significant time to complete!**

BYOIDC is a TechPreview feature that must be explicitly enabled:

```bash
# Enable TechPreview features (including BYOIDC)
oc patch featuregate cluster --type=merge -p '{"spec":{"featureSet":"TechPreviewNoUpgrade"}}'
```

**Alternative method using oc edit:**
```bash
# Edit the featuregate directly
oc edit featuregates cluster

# Replace the {} in the spec line with:
# spec:
#   featureSet: TechPreviewNoUpgrade
```

**Wait for cluster stabilization:**
```bash
# Monitor cluster operators until all are stable
oc get clusteroperators

# Wait until all operators show AVAILABLE=True, PROGRESSING=False, DEGRADED=False
# This process can take 15-30 minutes as nodes will reboot
```

#### 2. Create Keycloak Clients:

You need to create multiple clients in Keycloak for BYOIDC:

**Create Console Client (`ocp-console`):**
```bash
# Create console client via API
curl -X POST "http://localhost:8080/admin/realms/openshift/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "ocp-console",
    "enabled": true,
    "clientAuthenticatorType": "client-secret",
    "redirectUris": ["https://console-openshift-console.apps.your-cluster-domain.com/auth/callback"],
    "webOrigins": ["https://console-openshift-console.apps.your-cluster-domain.com"],
    "publicClient": false,
    "protocol": "openid-connect",
    "standardFlowEnabled": true,
    "directAccessGrantsEnabled": true
  }'
```

**Create CLI Client (`oc-cli`):**
```bash
# Create CLI client via API (public client, no secret needed)
curl -X POST "http://localhost:8080/admin/realms/openshift/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "oc-cli",
    "enabled": true,
    "publicClient": true,
    "protocol": "openid-connect",
    "standardFlowEnabled": true,
    "directAccessGrantsEnabled": true,
    "redirectUris": ["http://localhost:8080", "http://localhost:*", "https://oauth.openshift.io/*"]
  }'
```

**Get Console Client Secret:**
```bash
# Get console client secret
CLIENT_ID=$(curl -s -X GET "http://localhost:8080/admin/realms/openshift/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[] | select(.clientId=="ocp-console") | .id')

curl -s -X GET "http://localhost:8080/admin/realms/openshift/clients/$CLIENT_ID/client-secret" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.value'
```

#### 3. Create OpenShift Secret:
```bash
# Create secret for console client (matches the OAuth configuration)
oc create secret generic console-secret \
  --from-literal=clientSecret=<your-console-client-secret> \
  -n openshift-config
```

#### 4. Create OAuth Configuration:

**Create the OAuth configuration file (`oauth-byoidc-config.yaml`):**
```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  oidcProviders:
  - name: 'keycloak-oidc-server'
    claimMappings:
      groups:
        claim: groups
        prefixPolicy: NoPrefix
      username:
        claim: preferred_username
        prefixPolicy: NoPrefix
    issuer:
      audiences:
      - ocp-console
      - oc-cli
      - odh
      issuerURL: https://your-keycloak-domain/realms/openshift
    oidcClients:
    - clientID: oc-cli
      componentName: cli
      componentNamespace: openshift-console
    - clientID: ocp-console
      clientSecret:
        name: console-secret
      componentName: console
      componentNamespace: openshift-console
  type: OIDC
  webhookTokenAuthenticator: null
```

#### 5. Apply Configuration:
```bash
oc apply -f oauth-byoidc-config.yaml
```

#### 6. Verify Configuration:
```bash
# Check OAuth pods restart
oc get pods -n openshift-authentication

# Check login page for new identity provider
# Visit: https://console-openshift-console.apps.your-cluster-domain.com
```

## ODH Client Configuration

### Creating ODH Client

ODH requires a separate client configuration with specific audience settings.

1. **Create ODH Client in Keycloak UI:**
   - Client ID: `odh`
   - Client authentication: `On`
   - Valid redirect URIs: `https://rhods-dashboard.apps.your-cluster-domain.com/oauth2callback/keycloak`
   
2. **Configure Client Scopes:**
   
   **Groups Mapper Configuration:**
   - Go to Client → odh → Client Scopes → Dedicated tab
   - Click "Add mapper" → "By configuration"
   - Select "Group Membership"
   - Configure the mapper:
     - Name: `groups`
     - Token Claim Name: `groups`
     - Full group path: `Off` (use simple group names)
     - Add to ID token: `On`
     - Add to access token: `On`
     - Add to userinfo: `On`
   
   **Audience Mapper Configuration:**
   - Add "Audience" mapper:
     - Mapper Type: `Audience`
     - Included Client Audience: `odh`
     - Add to access token: `On`

3. **Integration with BYOIDC:**
   
   The ODH client integrates with the BYOIDC OAuth configuration. Ensure that:
   - The `odh` audience is included in the BYOIDC `issuer.audiences` list
   - Groups mapping is properly configured (already handled in the BYOIDC configuration above)
   
   The complete OAuth configuration is handled in the [OpenShift BYOIDC Integration](#openshift-byoidc-integration) section.

### Groups and RBAC Setup

**Create Groups in Keycloak:**
1. Go to your realm → Groups → Create group
2. Create ODH-specific groups such as:
   - `odh-admins`: Full administrative access to ODH
   - `odh-users`: Standard user access to ODH
   - `data-scientists`: Access to data science workbenches
   - `model-developers`: Access to model serving capabilities

**Assign Users to Groups:**
1. Go to Users → select user → Groups tab
2. Click "Join Group" and select appropriate groups

### Token Verification

**Verify Groups and Audience in Token:**
```bash
# Decode JWT token to verify audience and groups
echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq '.'

# Verify specific claims
echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq '.aud'      # Should include "odh"
echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq '.groups'  # Should list user's groups
```

**Expected Token Structure:**
```json
{
  "aud": ["odh", "openshift"],
  "groups": ["odh-users", "data-scientists"],
  "preferred_username": "jane.doe",
  "email": "jane.doe@example.com",
  ...
}
```

