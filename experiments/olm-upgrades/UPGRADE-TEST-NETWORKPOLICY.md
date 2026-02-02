# v3.x NetworkPolicy Failure on Managed OpenShift

## Test Environment
- Cluster: Managed OpenShift (ROSA)
- Scenario: Upgrade from OpenDataHub v2.25.0
- Version: OpenDataHub v3.3.0 (main branch)
- Date: 2026-02-02

## Scope

**This issue affects all v3.x deployments on managed OpenShift**, not just upgrades:
- Fresh v3.x installs
- Upgrades to v3.x
- Any v3.x deployment on managed clusters

The problem is architectural incompatibility between v3.x design and managed cluster restrictions.

## Test Results

### Operator Install: Success
- CSV: opendatahub-operator.v3.3.0 (Succeeded)
- Replaces: opendatahub-operator.v2.25.0 (upgrade test)
- Pods: 3/3 controller-manager replicas running

### GatewayConfig: Failed
```
NAME              READY   REASON
default-gateway   False   Error
```

## Failure Details

### Error
```
admission webhook "networkpolicies-validation.managed.openshift.io" denied the request:
User 'system:serviceaccount:opendatahub-operator-system:opendatahub-operator-controller-manager'
prevented from creating network policy that may impact default ingress, which is managed by Red Hat.
```

### Root Cause
v3.x GatewayConfig controller attempts to create NetworkPolicy in `openshift-ingress` namespace.
Managed cluster admission webhook blocks all NetworkPolicy creation in managed namespaces including `openshift-ingress`.

### Resource Details
- Resource: NetworkPolicy `kube-auth-proxy`
- Namespace: openshift-ingress
- Owner: GatewayConfig `default-gateway`
- Created by: DSCInitialization controller (automatic)

## Architecture Conflict

v3.x introduced GatewayConfig as required component:
- Created automatically by DSCInitialization
- No disable flag available
- Requires NetworkPolicy in openshift-ingress namespace
- Hard blocked by managed cluster policies

## Current State

Running components:
- opendatahub-operator: v3.3.0
- DSCInitialization: Ready
- DataScienceCluster: Ready
- Dashboard: 2 pods (5/5 containers running)

Failed components:
- GatewayConfig: Error state, cannot provision

## Blocked By

Managed cluster admission webhook: `networkpolicies-validation.managed.openshift.io`

Regular expressions blocking namespace access:
- `^openshift-ingress$`
- `^openshift-.*`
- Others (full list in error message)

## Technical Analysis

### NetworkPolicy Purpose
Location: `internal/controller/services/gateway/resources/kube-auth-proxy-networkpolicy.yaml`

The NetworkPolicy restricts ingress traffic to kube-auth-proxy pods in openshift-ingress:
- Allows traffic from gateway/envoy pods (port 8443) for authentication
- Allows metrics collection from openshift-monitoring (port 9000)
- Allows metrics collection from openshift-user-workload-monitoring (port 9000)

### Code Implementation
Location: `internal/controller/services/gateway/gateway_controller_actions.go:238-266`

NetworkPolicy creation:
- Enabled by default when `spec.networkPolicy.ingress` is nil
- Can be disabled via `spec.networkPolicy.ingress.enabled: false`
- Code comment states: "Set Enabled=false only in development environments or when using alternative network security controls"

## Potential Workaround

Disable NetworkPolicy creation by patching GatewayConfig:
```yaml
spec:
  networkPolicy:
    ingress:
      enabled: false
```

### Workaround Considerations
- Managed clusters have existing network security controls
- kube-auth-proxy pods would rely on cluster-level security instead of NetworkPolicy
- Code comments indicate this is not recommended for production
- May be acceptable in managed environments with alternative security controls

### Test Workaround
```bash
kubectl patch gatewayconfig default-gateway --type=merge -p '{"spec":{"networkPolicy":{"ingress":{"enabled":false}}}}'
```

### Workaround Test Results
```
NAME              READY   REASON
default-gateway   True
```

Status after disabling NetworkPolicy:
- GatewayConfig: Ready=True, ProvisioningSucceeded=True
- NetworkPolicy: Not created (as expected)
- kube-auth-proxy pods: 2/2 Running
- Gateway functionality: Operational

The workaround successfully resolves the v3.x deployment issue on managed OpenShift.

## Conclusion

v3.x architecture assumes NetworkPolicy creation in openshift-ingress namespace. Managed OpenShift blocks this via admission webhook. Workaround (disabling NetworkPolicy) is tested and functional. Code marks this as development-only, but managed clusters have alternative security controls.
