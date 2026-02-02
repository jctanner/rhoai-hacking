# v3.x Version Annotation Not Updated After Upgrade

## Test Environment
- Cluster: Managed OpenShift (ROSA)
- Scenario: Upgrade from OpenDataHub v2.25.0 to v3.3.0
- Date: 2026-02-02

## Issue

Dashboard "About" page displays "2.25.0" after successful upgrade to v3.3.0 operator.

## Symptoms

```bash
$ oc get csv -n opendatahub-operator-system
NAME                          VERSION
opendatahub-operator.v3.3.0   3.3.0

$ oc get deployment -n opendatahub odh-dashboard -o yaml | grep "platform.opendatahub.io/version"
    platform.opendatahub.io/version: 2.25.0
```

Dashboard displays old version in UI despite operator CSV showing v3.3.0.

## Root Cause

### Operator Version Caching

Location: `pkg/cluster/cluster_config.go:308-345`

The operator reads its version from the CSV only at startup:

```go
func getRelease(ctx context.Context, cli client.Client) (common.Release, error) {
    // ...
    csv, err := GetClusterServiceVersion(ctx, cli, operatorNamespace)
    initRelease.Version = csv.Spec.Version
    return initRelease, nil
}
```

This version is cached in global `clusterConfig` structure (line 59):
```go
clusterConfig.Release, err = getRelease(ctx, cli)
```

### Version Annotation Propagation

All resources created by the operator receive this annotation:
```yaml
metadata:
  annotations:
    platform.opendatahub.io/version: <cached_version>
```

Dashboard reads this annotation to display version in About page.

### OLM Upgrade Behavior

During OLM upgrade:
1. CSV upgraded from v2.25.0 to v3.3.0
2. Operator deployment updated to v3.3.0 image
3. **Operator pods NOT automatically restarted**
4. Running pods retain cached version from v2.25.0 CSV
5. New resources created with stale version annotation

## Evidence

Operator pod age after upgrade:
```bash
$ oc get pods -n opendatahub-operator-system -l control-plane=controller-manager
NAME                                                       AGE
opendatahub-operator-controller-manager-796b6547dc-2bg8s   121m
opendatahub-operator-controller-manager-796b6547dc-h2lct   121m
opendatahub-operator-controller-manager-796b6547dc-p6w7x   121m
```

Pods started during v2.25.0 deployment, never restarted during upgrade.

## Solution

Restart operator pods to reload CSV version:

```bash
oc delete pod -n opendatahub-operator-system -l control-plane=controller-manager
```

Wait for pods to restart, then recreate Dashboard CR:

```bash
oc delete dashboard default-dashboard
```

DSC controller automatically recreates Dashboard with correct version.

## Verification

After operator pod restart and Dashboard recreation:

```bash
$ oc get dashboard default-dashboard -o yaml | grep "platform.opendatahub.io/version"
    platform.opendatahub.io/version: 3.3.0

$ oc get deployment -n opendatahub odh-dashboard -o yaml | grep "platform.opendatahub.io/version"
    platform.opendatahub.io/version: 3.3.0
```

Dashboard About page now displays "3.3.0".

## Conclusion

Operator caches CSV version at startup. OLM upgrades do not automatically restart operator pods. Manual restart required after upgrade for correct version annotation on new resources.
