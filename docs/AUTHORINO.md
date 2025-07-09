# Authorino Integration in OpenDataHub Operator

## Overview

Authorino is integrated into the OpenDataHub operator as an **optional authorization provider for Service Mesh functionality**. It provides JWT-based authentication and authorization for OpenDataHub components when Service Mesh is enabled, acting as an external authorization provider for Istio/Maistra service mesh.

## Key Integration Points

### 1. Service Mesh Authorization Feature

Authorino is deployed and managed through the **DSC Initialization controller** as part of the Service Mesh capability, not as a standalone component.

**Primary Controller:**
- `src/opendatahub-operator/internal/controller/services/servicemesh/servicemesh_support.go`

**Feature Management:**
- `src/opendatahub-operator/pkg/feature/servicemesh/` - Contains feature data and resource management

### 2. Conditional Installation

Authorino deployment is **conditional** - the operator checks if the Authorino operator is installed before deploying authorization features:

```go
authorinoInstalled, err := cluster.SubscriptionExists(ctx, r.Client, "authorino-operator")
if err != nil {
    return nil, fmt.Errorf("failed to list subscriptions %w", err)
}

if !authorinoInstalled {
    // Skip authorization capability
    authzMissingOperatorCondition := &common.Condition{
        Type:    status.CapabilityServiceMeshAuthorization,
        Status:  metav1.ConditionFalse,
        Reason:  status.MissingOperatorReason,
        Message: "Authorino operator is not installed on the cluster, skipping authorization capability",
    }
}
```

**File Reference:** `src/opendatahub-operator/internal/controller/services/servicemesh/servicemesh_support.go:124-134`

## Templates and Manifests

### Template Location
Templates are stored in: `src/opendatahub-operator/internal/controller/dscinitialization/resources/authorino/`

### 1. Base Authorino Custom Resource
**File:** `base/operator-cluster-wide-no-tls.tmpl.yaml`

```yaml
apiVersion: operator.authorino.kuadrant.io/v1beta1
kind: Authorino
metadata:
  name: {{ .AuthProviderName }}
  namespace: {{ .AuthNamespace }}
spec:
  authConfigLabelSelectors: security.opendatahub.io/authorization-group=default
  clusterWide: true
  listener:
    tls:
      enabled: false
  oidcServer:
    tls:
      enabled: false
```

**Purpose:** Creates the main Authorino custom resource with cluster-wide scope and TLS disabled.

### 2. Service Mesh Member Integration
**File:** `auth-smm.tmpl.yaml`

```yaml
apiVersion: maistra.io/v1
kind: ServiceMeshMember
metadata:
  name: default
  namespace: {{ .AuthNamespace }}
spec:
  controlPlaneRef:
    namespace: {{ .ControlPlane.Namespace }}
    name: {{ .ControlPlane.Name }}
```

**Purpose:** Integrates Authorino namespace with Service Mesh via ServiceMeshMember.

### 3. External Authorization Provider Configuration
**File:** `mesh-authz-ext-provider.patch.tmpl.yaml`

```yaml
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: {{ .ControlPlane.Name }}
  namespace: {{ .ControlPlane.Namespace }}
spec:
  techPreview:
    meshConfig:
      extensionProviders:
      - name: {{ .AuthExtensionName }}
        envoyExtAuthzGrpc:
          service: {{ .AuthProviderName }}-authorino-authorization.{{ .AuthNamespace }}.svc.cluster.local
          port: 50051
```

**Purpose:** Configures Authorino as an external authorization provider in ServiceMeshControlPlane.

### 4. Sidecar Injection Configuration
**File:** `deployment.injection.patch.tmpl.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .AuthProviderName }}
  namespace: {{ .AuthNamespace }}
spec:
  template:
    metadata:
      labels:
        sidecar.istio.io/inject: "true"
```

**Purpose:** Enables Istio sidecar injection for Authorino deployment.

## Configuration Management

### Feature Data Structure

**File:** `src/opendatahub-operator/pkg/feature/servicemesh/data.go`

The operator uses a structured approach to manage Authorino configuration:

```go
var FeatureData = struct {
    ControlPlane  feature.DataDefinition[dsciv1.DSCInitializationSpec, infrav1.ControlPlaneSpec]
    Authorization AuthorizationData
}{
    // ... definitions
}
```

### Configuration Values

- **AuthProviderName:** Always set to `"authorino"`
- **AuthNamespace:** Defaults to `{ApplicationsNamespace}-auth-provider`
- **AuthExtensionName:** Set to `{ApplicationsNamespace}-auth-provider`
- **AuthConfigLabelSelectors:** `security.opendatahub.io/authorization-group=default`

### ConfigMap References

The operator creates ConfigMaps to store Authorino configuration:

**ConfigMap Name:** `auth-refs`

**Data Fields:**
- `AUTH_AUDIENCE` - JWT audience configuration
- `AUTH_PROVIDER` - Provider name (defaults to "authorino")
- `AUTH_NAMESPACE` - Namespace where Authorino is deployed
- `AUTHORINO_LABEL` - Label selector for AuthConfig resources (`security.opendatahub.io/authorization-group=default`)

**File Reference:** `src/opendatahub-operator/pkg/feature/servicemesh/resources.go:65-85`

## Component Integration

### KServe Integration

KServe specifically checks for Authorino installation and conditionally deploys service mesh-related resources:

**File:** `src/opendatahub-operator/internal/controller/components/kserve/kserve_controller_actions.go`

```go
authorinoInstalled, err := cluster.SubscriptionExists(ctx, rr.Client, "authorino-operator")
if err != nil {
    return fmt.Errorf("failed to list subscriptions %w", err)
}

if !authorinoInstalled {
    // Clean up service mesh resources if Authorino is not installed
    for _, res := range rr.Resources {
        if isForDependency("servicemesh")(&res) {
            err := rr.Client.Delete(ctx, &res, client.PropagationPolicy(metav1.DeletePropagationForeground))
            // ... error handling
        }
    }
}
```

**Lines:** 280-310

## RBAC Requirements

The operator requires specific RBAC permissions for Authorino resources:

**File:** `src/opendatahub-operator/internal/controller/dscinitialization/kubebuilder_rbac.go`

```go
// +kubebuilder:rbac:groups="authorino.kuadrant.io",resources=authconfigs,verbs=*
// +kubebuilder:rbac:groups="operator.authorino.kuadrant.io",resources=authorinos,verbs=*
```

**Lines:** 23-24

These permissions are also reflected in the generated RBAC manifests:
- `src/opendatahub-operator/config/rbac/role.yaml`
- `src/opendatahub-operator/bundle/manifests/opendatahub-operator.clusterserviceversion.yaml`

## Dependencies

### External Dependencies

1. **Authorino Operator** - Must be installed separately
   - Subscription name: `authorino-operator`
   - Namespace: `openshift-operators`

2. **Service Mesh Operator** (Istio/Maistra) - Must be installed separately
   - Required for Service Mesh functionality

### Feature Dependencies

Authorization features have the following preconditions:

```go
PreConditions(
    feature.EnsureOperatorIsInstalled("authorino-operator"),
    servicemesh.EnsureServiceMeshInstalled,
    servicemesh.EnsureAuthNamespaceExists,
)
```

**File Reference:** `src/opendatahub-operator/internal/controller/services/servicemesh/servicemesh_support.go:221`

## Deployment Flow

1. **Dependency Check:** Operator checks if Authorino operator is installed
2. **Namespace Creation:** Creates auth provider namespace if needed
3. **Service Mesh Integration:** Deploys ServiceMeshMember for Authorino namespace
4. **Authorino CR:** Creates Authorino custom resource
5. **External Auth Provider:** Configures Authorino as external authorization provider in ServiceMeshControlPlane
6. **Sidecar Injection:** Patches Authorino deployment for Istio sidecar injection
7. **ConfigMap Creation:** Creates configuration references for other components

## Testing

### Test Files

- `src/opendatahub-operator/internal/controller/components/kserve/kserve_controller_actions_test.go`
  - `TestCleanUpTemplatedResources_withAuthorino`
  - `TestCleanUpTemplatedResources_withoutAuthorino`
- `src/opendatahub-operator/tests/integration/features/servicemesh_feature_test.go`
- `src/opendatahub-operator/tests/e2e/creation_test.go`

### Test Constants

```go
authorinoOpName = "authorino-operator"  // Name of the Authorino Operator
```

**File Reference:** `src/opendatahub-operator/tests/e2e/helper_test.go:33`

## Configuration Examples

### Service Configuration

The Authorino authorization service is configured as:

```
service: {{ .AuthProviderName }}-authorino-authorization.{{ .AuthNamespace }}.svc.cluster.local
port: 50051
```

This creates a service reference like:
`authorino-authorino-authorization.opendatahub-auth-provider.svc.cluster.local:50051`

### Integration Test Example

```go
Expect(envoyExtAuthzGrpc["service"]).To(Equal("authorino-authorino-authorization.auth-provider.svc.cluster.local"))
```

**File Reference:** `src/opendatahub-operator/tests/integration/features/servicemesh_feature_test.go:287`

## Key Takeaways

1. **Optional Feature:** Authorino is not a required component - it's only deployed when the Authorino operator is available
2. **Service Mesh Integration:** Primary purpose is to provide external authorization for Service Mesh
3. **Configuration Management:** Uses ConfigMaps to share configuration with other components
4. **Conditional Logic:** Extensive conditional logic throughout the codebase to handle Authorino presence/absence
5. **Template-Based:** Uses Go templates for resource generation with parameterized values
6. **RBAC Aware:** Requires specific permissions for Authorino CRDs and resources

## Related Documentation

- [OpenDataHub Operator Design](src/opendatahub-operator/docs/DESIGN.md) - Line 125 mentions Authorino integration
- [Component Integration Guide](src/opendatahub-operator/docs/COMPONENT_INTEGRATION.md)
- [README.md](src/opendatahub-operator/README.md) - Line 41 lists Authorino operator as dependency 