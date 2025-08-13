# OpenShift Authorization Concepts: RBAC and Security

A comprehensive guide to Role-Based Access Control (RBAC) in OpenShift and Kubernetes, covering core concepts, OpenShift extensions, and practical implementation.

---

## **Part 1: Foundation - Understanding Authorization**

### **What is RBAC?**

RBAC (Role-Based Access Control) is the **system that controls who can do what** in Kubernetes and OpenShift clusters. It's the authorization layer that determines whether authenticated users, groups, or service accounts can perform specific actions on cluster resources.

### **RBAC in the Security Stack**

RBAC is one layer in a comprehensive security model:

```
┌─────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION                           │
│  (Who are you? - OIDC, LDAP, certificates, tokens)        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   AUTHORIZATION (RBAC)                     │
│  (What can you do? - API access permissions)               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              ADMISSION CONTROL                              │
│  (How can you do it? - SCCs, Pod Security, Quotas)        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 NETWORK POLICIES                            │
│  (Who can talk to whom? - Network-level access control)    │
└─────────────────────────────────────────────────────────────┘
```

### **RBAC vs Other Access Controls**

**RBAC is responsible for:**
- API access permissions (create, read, update, delete resources)
- Who can perform administrative actions
- Service account permissions for applications
- Cross-namespace access controls

**RBAC is NOT responsible for:**
- Network traffic between pods (use Network Policies)
- Pod security contexts (use SCCs/Pod Security Standards)
- Resource consumption limits (use Quotas/Limit Ranges)
- Image security scanning (use Admission Controllers)

---

## **Part 2: Core RBAC Components**

### **Roles and ClusterRoles**

**Role** - Defines permissions within a **single namespace**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: my-namespace
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
```

**ClusterRole** - Defines permissions **cluster-wide** (across all namespaces):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader-cluster
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
```

### **RoleBindings and ClusterRoleBindings**

These **link** roles to subjects (users, groups, service accounts). Without bindings, roles do nothing.

**RoleBinding:**
- Grants permissions within a **single namespace**
- Can bind either a Role OR a ClusterRole to subjects
- When binding a ClusterRole, permissions are limited to the namespace where the RoleBinding exists

**ClusterRoleBinding:**
- Grants permissions **cluster-wide** (across all namespaces)
- Can only bind ClusterRoles (not namespace-scoped Roles)
- Subjects get the permissions everywhere in the cluster

#### **Examples**

**RoleBinding with a Role** (namespace-scoped permissions):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: my-namespace
subjects:
  - kind: User
    name: alice
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**RoleBinding with a ClusterRole** (ClusterRole permissions limited to namespace):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admin-binding
  namespace: my-namespace
subjects:
  - kind: User
    name: bob
roleRef:
  kind: ClusterRole
  name: admin # Built-in ClusterRole, but only applies to my-namespace
  apiGroup: rbac.authorization.k8s.io
```

**ClusterRoleBinding** (cluster-wide permissions):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-binding
subjects:
  - kind: User
    name: charlie
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

#### **When to Use Which**
- **RoleBinding + Role**: Custom permissions for a specific namespace
- **RoleBinding + ClusterRole**: Reuse common ClusterRole permissions in specific namespaces
- **ClusterRoleBinding + ClusterRole**: Grant cluster-wide access (use sparingly!)

### **Subjects: Users, Groups, and Service Accounts**

RBAC bindings grant permissions to **subjects**. Understanding the different subject types is crucial for effective authorization design.

#### **Users**
- **What they are**: Human identities authenticated by external systems (OIDC, LDAP, etc.)
- **Where they come from**: Authentication providers, not stored as cluster resources
- **Naming**: Usually email addresses or usernames (e.g., `alice@company.com`, `system:admin`)
- **Capabilities**: Can perform any action their RBAC permissions allow
- **Lifecycle**: Managed externally; OpenShift only sees them after authentication

#### **Groups**
- **What they are**: Collections of users, typically from external identity providers
- **Where they come from**: LDAP/AD groups, OIDC claims, or OpenShift built-in groups
- **Naming**: Varies by provider (e.g., `/developers`, `system:authenticated`)
- **Capabilities**: Same as users, but applied to all group members
- **Benefits**: Easier management - add/remove users from groups instead of individual bindings

**Common Built-in Groups:**
- `system:authenticated` - All authenticated users
- `system:unauthenticated` - Anonymous users
- `system:cluster-admins` - Cluster administrators

#### **Service Accounts**
- **What they are**: Kubernetes-native identities for workloads (pods, deployments)
- **Where they come from**: Created as cluster resources in namespaces
- **Naming**: `system:serviceaccount:namespace:name`
- **Capabilities**: Limited to what pods need; cannot perform user-specific actions
- **Lifecycle**: Managed within Kubernetes, can be created/deleted like other resources

#### **Subject Comparison**

| Aspect | Users | Groups | Service Accounts |
|--------|--------|--------|------------------|
| **Authentication** | External providers | External providers | Kubernetes tokens |
| **Storage** | Not stored in cluster | Not stored in cluster | Stored as K8s resources |
| **Token Management** | External | External | Kubernetes manages |
| **Impersonation** | Can impersonate others* | Can impersonate others* | Limited impersonation |
| **Interactive Access** | Yes (kubectl, web console) | Yes (through members) | No (pods only) |
| **Cross-namespace** | Yes | Yes | No (namespace-scoped) |

*Requires impersonation permissions

#### **Best Practices by Subject Type**

**Users:**
- Use for human access to clusters
- Prefer group-based permissions over individual user bindings
- Use impersonation for testing permissions

**Groups:**
- Primary method for managing human permissions
- Map external groups to OpenShift roles
- Use built-in groups for common patterns

**Service Accounts:**
- Use for pod-to-API communication
- Follow principle of least privilege
- Create dedicated SAs for different application components
- Never use for human access

#### **Multi-Subject Binding Example**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developers-and-ci
  namespace: my-app
subjects:
  # Human users via group
  - kind: Group
    name: /my-app-developers
    apiGroup: rbac.authorization.k8s.io
  # CI/CD service account
  - kind: ServiceAccount
    name: ci-deployer
    namespace: my-app
  # Emergency access for specific user
  - kind: User
    name: alice@company.com
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

### **Permission Checking: SAR and SSAR**

#### **SAR (SubjectAccessReview)**
A **SAR** is a cluster API request to ask: _"Can this user do this action?"_

```bash
oc create -f - <<EOF
apiVersion: authorization.k8s.io/v1
kind: SubjectAccessReview
spec:
  user: alice
  resourceAttributes:
    namespace: my-namespace
    verb: get
    resource: pods
EOF
```

The API server checks RBAC and replies with `allowed: true` or `allowed: false`.

#### **SSAR (SelfSubjectAccessReview)**
A **SSAR** is the same idea as a SAR, but for the **current logged-in user**. You don't have to specify the user; the API infers it from your token.

```bash
oc auth can-i get pods --namespace my-namespace
```

This runs a SSAR behind the scenes.

---

## **Part 3: OpenShift Extensions**

OpenShift extends Kubernetes RBAC with additional features and concepts while maintaining full compatibility with standard Kubernetes RBAC.

### **Core RBAC Compatibility**

OpenShift is **fully compatible** with standard Kubernetes RBAC:
- All K8s RBAC resources work identically (Role, ClusterRole, RoleBinding, ClusterRoleBinding)
- Standard `kubectl auth can-i` commands work
- YAML manifests are interchangeable

### **Security Context Constraints (SCCs)**

**OpenShift-specific** security layer that works alongside RBAC. Both RBAC AND SCC permissions must allow an action.

#### **Built-in SCCs (Most Restrictive to Least Restrictive)**

```bash
# List all SCCs
oc get scc

# View specific SCC details
oc describe scc restricted
```

**1. `restricted` (Most Secure - Default)**
- **Use Case**: Standard applications, most pods
- **RunAsUser**: MustRunAsRange (non-root)
- **Host Access**: None
- **Risk**: Minimal

**2. `restricted-v2`**
- **Use Case**: Enhanced version with Pod Security Standards compliance
- **Additional Controls**: Seccomp, capabilities dropping enforced

**3. `nonroot`**
- **Use Case**: Applications needing flexibility but still non-root
- **RunAsUser**: MustRunAsNonRoot

**4. `nonroot-v2`**
- **Use Case**: Enhanced nonroot with Pod Security Standards

**5. `anyuid`**
- **Use Case**: Applications that must run as specific UIDs (including root)
- **RunAsUser**: RunAsAny (can run as root)
- **Risk**: Medium - allows root but no host access

**6. `hostmount-anyuid`**
- **Use Case**: Applications needing host volume mounts
- **Volumes**: Includes HostPath
- **Risk**: High - host filesystem access

**7. `hostnetwork`**
- **Use Case**: Applications needing host network (like CNI pods)
- **Network**: Host network access
- **Risk**: High - network access to host

**8. `hostnetwork-v2`**
- **Use Case**: Enhanced hostnetwork with additional controls

**9. `node-exporter`**
- **Use Case**: Monitoring agents like Prometheus node-exporter
- **Host Access**: Read-only host access for metrics

**10. `privileged` (Least Secure)**
- **Use Case**: System pods, infrastructure components
- **Capabilities**: ALL capabilities
- **Host Access**: Full host access
- **Risk**: Maximum - equivalent to root on host

#### **SCC Assignment Examples**

```yaml
# Most secure - restrict to default SCC
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: my-app-restricted
subjects:
  - kind: ServiceAccount
    name: my-app
    namespace: my-namespace
roleRef:
  kind: ClusterRole
  name: system:openshift:scc:restricted
  apiGroup: rbac.authorization.k8s.io

---
# Allow running as any UID (including root)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: legacy-app-anyuid
subjects:
  - kind: ServiceAccount
    name: legacy-app
    namespace: my-namespace
roleRef:
  kind: ClusterRole
  name: system:openshift:scc:anyuid
  apiGroup: rbac.authorization.k8s.io
```

#### **SCC Management Commands**

```bash
# Check which SCC a pod is using
oc get pod my-pod -o yaml | grep "openshift.io/scc"

# Check what SCC a service account can use
oc policy scc-subject-review --serviceaccount=my-sa --namespace=my-namespace

# Add SCC to service account
oc adm policy add-scc-to-user anyuid --serviceaccount=my-sa --namespace=my-namespace

# Remove SCC from service account
oc adm policy remove-scc-from-user anyuid --serviceaccount=my-sa --namespace=my-namespace
```

### **Built-in Roles and Groups**

#### **OpenShift Built-in Roles**
- `admin` - Full namespace access (can manage RBAC within namespace)
- `edit` - Create/modify most resources (cannot manage RBAC)
- `view` - Read-only access
- `self-provisioner` - Can create new projects
- `cluster-reader` - Read-only cluster access
- `cluster-admin` - Full cluster access

#### **OpenShift Built-in Groups**
- `system:cluster-readers` - Read-only cluster access
- `system:cluster-admins` - Full cluster access
- `system:masters` - Legacy cluster admin group

### **Projects vs Namespaces**

OpenShift **Projects** are Kubernetes namespaces with additional metadata:

```yaml
# Kubernetes: Just a namespace
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace

---
# OpenShift: Project with additional annotations and labels
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: my-project
  annotations:
    openshift.io/description: "My application project"
    openshift.io/display-name: "My Project"
    openshift.io/requester: "alice"
```

```bash
# Create project (creates namespace + project metadata)
oc new-project my-project

# Grant project admin to user
oc policy add-role-to-user admin alice --namespace my-project
```

### **Enhanced Policy Commands**

OpenShift provides additional policy management commands:

```bash
# OpenShift-specific policy commands
oc policy who-can create pods --namespace my-project
oc policy add-role-to-user admin alice --namespace my-project
oc policy remove-role-from-user edit bob --namespace my-project
oc policy add-role-to-group view developers --namespace my-project

# Check SCC permissions (OpenShift-only)
oc policy scc-subject-review --serviceaccount=my-sa
oc policy scc-review --serviceaccount=my-sa

# vs Kubernetes equivalent
kubectl create rolebinding admin-binding --clusterrole=admin --user=alice --namespace=my-project
```

### **OAuth Integration**

OpenShift has built-in OAuth server with RBAC integration:

```yaml
# OpenShift OAuth client configuration
apiVersion: oauth.openshift.io/v1
kind: OAuthClient
metadata:
  name: my-app
secret: my-secret
redirectURIs:
  - https://my-app.example.com/callback
grantMethod: auto

---
# Map OAuth groups to roles
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oauth-developers
subjects:
  - kind: Group
    name: my-oauth-group # From OAuth provider
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

### **Migration Considerations**

**From Kubernetes to OpenShift:**
- Add SCC bindings for service accounts that need special privileges
- Review default service account permissions
- Consider using OpenShift built-in roles instead of custom ones
- Update policy management scripts to use `oc policy` commands

**From OpenShift to Kubernetes:**
- Remove SCC-related ClusterRoleBindings
- Replace OpenShift built-in roles with equivalent Kubernetes ones
- Remove Project resources (use Namespaces)
- Update OAuth configuration for different identity providers

---

## **Part 4: Practical Implementation**

### **Permission Debugging**

When you get "access denied" errors, here's how to troubleshoot:

#### **Check Current Permissions**

```bash
# Check if you can perform a specific action
oc auth can-i create pods --namespace my-namespace

# Check all permissions for current user in a namespace
oc auth can-i --list --namespace my-namespace

# Check what a specific user can do
oc auth can-i create pods --as alice --namespace my-namespace
```

#### **Find Who Has Permissions**

```bash
# See who can perform an action
oc policy who-can create pods --namespace my-namespace

# See who can perform cluster-wide actions
oc policy who-can create clusterroles
```

#### **Common Permission Issues**
- **Missing RoleBinding**: Role exists but isn't bound to the user
- **Wrong namespace**: User has permissions in different namespace
- **Insufficient cluster permissions**: Need ClusterRole instead of Role
- **Resource vs subresource**: Need `pods/exec` not just `pods`

#### **Debugging Different Layers**

```bash
# RBAC issues:
oc auth can-i create pods --namespace my-app

# Network Policy issues:
oc get networkpolicies --namespace my-app
oc describe networkpolicy my-policy --namespace my-app

# SCC/Pod Security issues:
oc get pod my-pod -o yaml | grep -A 10 securityContext
oc policy scc-subject-review --serviceaccount=my-sa
```

### **Service Account Management**

#### **Complete Service Account Setup**

```yaml
# Service account with custom permissions
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: my-namespace
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-reader
  namespace: my-namespace
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-app-binding
  namespace: my-namespace
subjects:
  - kind: ServiceAccount
    name: my-app-sa
    namespace: my-namespace
roleRef:
  kind: Role
  name: configmap-reader
  apiGroup: rbac.authorization.k8s.io
```

#### **Using Service Account in Pods**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: my-namespace
spec:
  serviceAccountName: my-app-sa # Uses custom SA permissions
  containers:
    - name: app
      image: my-app:latest
```

#### **Token Access from Pods**

```bash
# Inside a pod, the SA token is mounted at:
cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Use it to make API calls
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" \
     -k https://kubernetes.default.svc/api/v1/namespaces/my-namespace/configmaps
```

### **Real-World Examples**

#### **Complete Multi-Tenant Setup**

```bash
# 1. Create project for team
oc new-project team-alpha

# 2. Create custom role for team needs
oc create -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: team-alpha-developer
  namespace: team-alpha
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list"]  # Can see but not modify PVs
EOF

# 3. Bind role to team members
oc policy add-role-to-user team-alpha-developer alice --namespace team-alpha
oc policy add-role-to-user team-alpha-developer bob --namespace team-alpha

# 4. Create service account for CI/CD
oc create serviceaccount ci-deployer --namespace team-alpha
oc policy add-role-to-user team-alpha-developer system:serviceaccount:team-alpha:ci-deployer
```

#### **CI/CD Pipeline Permissions**

```yaml
# Service account for CI/CD with minimal required permissions
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline-deployer
  namespace: my-app
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
  namespace: my-app
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps", "secrets"]
    verbs: ["get", "list", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list"]
```

#### **Complete Access Control Example**

```yaml
# 1. RBAC: Allow service account to create pods
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-manager
  namespace: app-namespace
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["create", "get", "list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-pod-manager
  namespace: app-namespace
subjects:
  - kind: ServiceAccount
    name: app-deployer
    namespace: app-namespace
roleRef:
  kind: Role
  name: pod-manager
  apiGroup: rbac.authorization.k8s.io

---
# 2. SCC/Pod Security: Control what the pod can do
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: app-scc-binding
subjects:
  - kind: ServiceAccount
    name: app-deployer
    namespace: app-namespace
roleRef:
  kind: ClusterRole
  name: system:openshift:scc:restricted
  apiGroup: rbac.authorization.k8s.io

---
# 3. Network Policy: Control pod network access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-network-policy
  namespace: app-namespace
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              role: database
      ports:
        - protocol: TCP
          port: 5432
```

### **Common Error Messages and Solutions**

#### **"Forbidden" Errors**
```
Error: pods is forbidden: User "alice" cannot create resource "pods" in API group "" in the namespace "default"
```
**Solution**: Check if user has appropriate Role and RoleBinding in the namespace.

#### **"Unknown User" Errors**
```
Error: the server doesn't have a resource type "user"
```
**Solution**: Users don't exist as cluster resources; they're authenticated externally.

#### **SCC-Related Errors**
```
Error: pods "my-pod" is forbidden: unable to validate against any security context constraint
```
**Solution**: Grant appropriate SCC permissions to the service account.

---

## **Part 5: Advanced Topics**

### **Advanced RBAC Patterns**

#### **Restricting Access to Specific Resources**
```yaml
# Only allow access to specific configmaps
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: specific-configmap-access
  namespace: my-namespace
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["app-config", "db-config"] # Only these specific ones
    verbs: ["get", "update"]
```

#### **Subresource Permissions**
```yaml
# Allow viewing pods but also exec into them
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-executor
  namespace: my-namespace
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods/exec"] # Subresource for exec
    verbs: ["create"]
```

#### **Wildcard Usage**
```yaml
# Access to all resources in specific API groups
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app-operator
rules:
  - apiGroups: ["apps", "extensions"]
    resources: ["*"] # All resources in these groups
    verbs: ["*"] # All verbs
```

### **ClusterRole Aggregation**

Combine multiple ClusterRoles into one using labels:

```yaml
# Base aggregated role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
aggregationRule:
  clusterRoleSelectors:
    - matchLabels:
        rbac.example.com/aggregate-to-monitoring: "true"
rules: [] # Rules will be automatically populated

---
# Component role that gets aggregated
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-reader
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints"]
    verbs: ["get", "list", "watch"]
```

### **Impersonation**

```bash
# Impersonate another user to test their permissions
oc auth can-i create pods --as alice --namespace my-namespace

# Impersonate a service account
oc auth can-i list secrets --as system:serviceaccount:my-namespace:my-sa

# Create resources as another user (requires impersonation permissions)
oc create deployment nginx --image nginx --as alice
```

### **NonResourceURL Permissions**

```yaml
# Allow access to cluster info endpoints
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-info-reader
rules:
  - nonResourceURLs: ["/healthz", "/healthz/*", "/version", "/api", "/api/*"]
    verbs: ["get"]
```

### **Custom SCCs**

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: custom-scc
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegedContainer: false
allowedCapabilities: []
defaultAddCapabilities: []
fsGroup:
  type: MustRunAs
  ranges:
    - min: 1000
      max: 2000
readOnlyRootFilesystem: false
requiredDropCapabilities:
  - ALL
runAsUser:
  type: MustRunAsRange
  uidRangeMin: 1000
  uidRangeMax: 2000
seLinuxContext:
  type: MustRunAs
volumes:
  - configMap
  - downwardAPI
  - emptyDir
  - persistentVolumeClaim
  - projected
  - secret
```

### **Identity Provider Integration**

#### **OAuth/OIDC Integration**
```yaml
# Example: Map OIDC groups to OpenShift roles
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oidc-developers
subjects:
  - kind: Group
    name: /developers # Group from OIDC provider
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

#### **Group Synchronization**
```bash
# View groups a user belongs to
oc get identity

# Check group memberships
oc describe user alice
```

---

## **Reference: Terminology and Best Practices**

### **Key Terms**

- **Group** – A collection of users (e.g., `system:authenticated` for all logged-in users)
- **ServiceAccount** – A special Kubernetes identity for workloads (pods) to interact with the API
- **Verb** – The action (e.g., `get`, `list`, `create`, `update`, `delete`, `watch`, `patch`)
- **Resource** – A Kubernetes object type (e.g., `pods`, `deployments`, `configmaps`)
- **NonResourceURL** – RBAC rules for API endpoints not tied to a resource (e.g., `/healthz`, `/metrics`)
- **Impersonation** – Temporarily act as another user to check permissions
- **ClusterRole Aggregation** – Combine multiple roles via labels into a single aggregate role

### **Best Practices for Layered Security**

1. **Start with RBAC**: Define who can do what with API resources
2. **Add Network Policies**: Control pod-to-pod communication
3. **Apply Pod Security**: Restrict what containers can do
4. **Set Resource Limits**: Prevent resource exhaustion
5. **Use Admission Controllers**: Add custom validation/mutation logic

### **SCC Best Practices**

1. **Start Restrictive**: Use `restricted` by default
2. **Escalate Minimally**: Only grant the minimum SCC needed
3. **Avoid Privileged**: Use `privileged` only for system components
4. **Document Exceptions**: Clearly document why non-restricted SCCs are needed
5. **Regular Review**: Periodically audit SCC assignments

---

## **How It All Works Together**

1. **Authentication** determines who you are (external identity providers)
2. **RBAC** defines what actions are allowed in Roles/ClusterRoles
3. **RoleBindings/ClusterRoleBindings** grant those roles to users, groups, or service accounts
4. **SAR/SSAR** let you ask the API if a particular action is allowed
5. **SCCs** (OpenShift-specific) add an additional security layer for pod permissions
6. **Network Policies** control pod-to-pod communication after RBAC allows resource creation
7. **Other admission controllers** add additional validation and security controls

The API server evaluates all these layers and returns **allowed** or **denied** for each request.

---

_This document is for personal reference and OpenShift RBAC workflow understanding._