# OpenShift Authorization Concepts: RBAC, SAR, SSAR, and Role Bindings

## **RBAC (Role-Based Access Control)**

RBAC is the **system that controls who can do what** in the cluster.

- **Role** – Defines _what actions_ are allowed on _what resources_, but only within a **single namespace**.
- **ClusterRole** – Same idea as Role, but applies cluster-wide (across all namespaces).
- **RoleBinding** – Grants a Role to a user, group, or service account in a namespace.
- **ClusterRoleBinding** – Grants a ClusterRole to a user, group, or service account across the whole cluster.

Example Role:

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pod-reader
  namespace: my-namespace
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
```

Example RoleBinding:

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: my-namespace
subjects:
  - kind: User
    name: alice
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## **SAR (SubjectAccessReview)**

A **SAR** is a cluster API request to ask:  
_"Can this user do this action?"_

Example:

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

---

## **SSAR (SelfSubjectAccessReview)**

A **SSAR** is the same idea as a SAR, but it’s for the **current logged-in user**.  
You don’t have to specify the user; the API infers it from your token.

Example:

```bash
oc auth can-i get pods --namespace my-namespace
```

This runs a SSAR behind the scenes.

---

## **Role Bindings**

RoleBindings (and ClusterRoleBindings) are what actually **link** a Role/ClusterRole to subjects (users, groups, service accounts). Without a binding, Roles don’t do anything.

---

## **Extra Terminology**

You’ll likely see these terms in the same context:

- **Group** – A collection of users (e.g., `system:authenticated` for all logged-in users).
- **ServiceAccount** – A special Kubernetes identity for workloads (pods) to interact with the API.
- **Verb** – The action (e.g., `get`, `list`, `create`, `update`, `delete`, `watch`, `patch`).
- **Resource** – A Kubernetes object type (e.g., `pods`, `deployments`, `configmaps`).
- **NonResourceURL** – RBAC rules for API endpoints that are not tied to a resource (e.g., `/healthz`, `/metrics`).
- **Impersonation** – Temporarily act as another user to check permissions.
- **ClusterRole Aggregation** – Combine multiple roles via labels into a single aggregate role.

---

## **Practical Permission Debugging**

When you get "access denied" errors, here's how to troubleshoot:

### Check Current Permissions

```bash
# Check if you can perform a specific action
oc auth can-i create pods --namespace my-namespace

# Check all permissions for current user in a namespace
oc auth can-i --list --namespace my-namespace

# Check what a specific user can do
oc auth can-i create pods --as alice --namespace my-namespace
```

### Find Who Has Permissions

```bash
# See who can perform an action
oc policy who-can create pods --namespace my-namespace

# See who can perform cluster-wide actions
oc policy who-can create clusterroles
```

### Common Permission Issues

- **Missing RoleBinding**: Role exists but isn't bound to the user
- **Wrong namespace**: User has permissions in different namespace
- **Insufficient cluster permissions**: Need ClusterRole instead of Role
- **Resource vs subresource**: Need `pods/exec` not just `pods`

---

## **OpenShift-Specific Extensions**

### Built-in ClusterRoles

OpenShift provides several pre-defined roles:

```bash
# View built-in roles
oc get clusterroles | grep -E "admin|edit|view|cluster-admin"
```

- **cluster-admin**: Full cluster access (equivalent to root)
- **admin**: Full access to a project/namespace
- **edit**: Create/modify resources but not view/modify roles
- **view**: Read-only access to most resources

### Security Context Constraints (SCCs)

SCCs work alongside RBAC to control pod security:

```yaml
# Example: Allow a service account to use privileged SCC
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: privileged-scc-binding
subjects:
  - kind: ServiceAccount
    name: my-service-account
    namespace: my-namespace
roleRef:
  kind: ClusterRole
  name: system:openshift:scc:privileged
  apiGroup: rbac.authorization.k8s.io
```

### Project vs Namespace

In OpenShift, projects are namespaces with additional metadata:

```bash
# Create project (creates namespace + project metadata)
oc new-project my-project

# Grant project admin to user
oc policy add-role-to-user admin alice --namespace my-project
```

---

## **Service Account Token Management**

### How Service Accounts Work with RBAC

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

### Using Service Account in Pods

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

### Token Access from Pods

```bash
# Inside a pod, the SA token is mounted at:
cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Use it to make API calls
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" \
     -k https://kubernetes.default.svc/api/v1/namespaces/my-namespace/configmaps
```

---

## **Advanced RBAC Patterns**

### Restricting Access to Specific Resources

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

### Subresource Permissions

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

### Wildcard Usage

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

---

## **Expanded Terminology**

### ClusterRole Aggregation

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

### Impersonation Examples

```bash
# Impersonate another user to test their permissions
oc auth can-i create pods --as alice --namespace my-namespace

# Impersonate a service account
oc auth can-i list secrets --as system:serviceaccount:my-namespace:my-sa

# Create resources as another user (requires impersonation permissions)
oc create deployment nginx --image nginx --as alice
```

### NonResourceURL Examples

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

---

## **Real-World Workflow Examples**

### Complete Multi-Tenant Setup

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

### CI/CD Pipeline Permissions

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

---

## **Common Error Messages and Solutions**

### "Forbidden" Errors

```
Error: pods is forbidden: User "alice" cannot create resource "pods" in API group "" in the namespace "default"
```

**Solution**: Check if user has appropriate Role and RoleBinding in the namespace.

### "Unknown User" Errors

```
Error: the server doesn't have a resource type "user"
```

**Solution**: Users don't exist as cluster resources; they're authenticated externally.

### SCC-Related Errors

```
Error: pods "my-pod" is forbidden: unable to validate against any security context constraint
```

**Solution**: Grant appropriate SCC permissions to the service account.

---

## **Integration with Identity Providers**

### OAuth/OIDC Integration

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

### Group Synchronization

```bash
# View groups a user belongs to
oc get identity

# Check group memberships
oc describe user alice
```

---

## **How They Work Together**

1. **RBAC** defines the allowed actions in Roles/ClusterRoles.
2. **RoleBindings** / **ClusterRoleBindings** grant those roles to users, groups, or service accounts.
3. **SAR / SSAR** let you ask the API if a particular action is allowed.
4. The API server evaluates RBAC rules and returns **allowed** or **denied**.
5. **SCCs** (OpenShift-specific) add an additional security layer for pod permissions.
6. **Identity providers** handle authentication, while RBAC handles authorization.

---

_This document is for personal reference and OpenShift RBAC workflow understanding._
