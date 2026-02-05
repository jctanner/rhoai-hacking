# DBASUNG Cluster Information

Comprehensive snapshot of RHOAI cluster state captured for upgrade analysis (2.25.2 → 3.3.0).

## Collection Date
Generated: February 4, 2026

## Quick Start

**View Summary:**
```bash
cat summary.txt
```

**View Upgrade Timeline:**
```bash
cat upgrade-timeline.txt
```

**View Operator Details:**
```bash
cat operator-details.txt
```

## File Organization

### OLM Resources (Operator Lifecycle Manager)
- `catalogsources.yaml` - All CatalogSources (package repositories)
- `subscriptions.yaml` - Operator subscriptions
- `csvs.yaml` - ClusterServiceVersions (installed operators)
- `installplans.yaml` - Installation plans showing upgrade history
- `operatorgroups.yaml` - OperatorGroup configurations
- `packagemanifest-rhods.yaml` - RHODS package manifest

### Operator Resources (RHODS Operator)
- `operator-deployment.yaml` - Operator deployment configuration
- `operator-pods.yaml` - Operator pod specifications
- `operator-replicasets.yaml` - ReplicaSet history (upgrade trail)
- `operator-configmaps.yaml` - ConfigMaps in operator namespace
- `operator-secrets.yaml` - Secrets in operator namespace
- `operator-serviceaccounts.yaml` - ServiceAccounts
- `operator-roles.yaml` - RBAC Roles
- `operator-rolebindings.yaml` - RBAC RoleBindings

### RHOAI Custom Resources
- `datasciencecluster.yaml` - DataScienceCluster CR (main config)
- `dscinitialization.yaml` - DSCInitialization CR (platform init)
- `dashboard-cr.yaml` - Dashboard component CR
- `all-components.yaml` - All component CRs (dashboard, kserve, ray, etc.)

### Dashboard Resources
- `dashboard-deployment.yaml` - Dashboard application deployment
- `dashboard-service.yaml` - Dashboard service
- `dashboard-httproute.yaml` - Dashboard HTTPRoute (Gateway API)
- `dashboard-routes.yaml` - Dashboard Routes (should be empty in 3.3.0)
- `dashboard-all-resources.yaml` - All resources with dashboard label

### Namespaces
- `namespace-operator.yaml` - redhat-ods-operator namespace
- `namespace-applications.yaml` - redhat-ods-applications namespace
- `namespace-monitoring.yaml` - redhat-ods-monitoring namespace

### Cluster Info
- `clusterversion.yaml` - OpenShift cluster version
- `clusteroperators.yaml` - All cluster operators status

### CRDs
- `crds-opendatahub.yaml` - All OpenDataHub CRDs
- `crds-gateway.yaml` - Gateway API CRDs

### Summary Files
- `summary.txt` - Human-readable cluster summary
- `operator-details.txt` - Detailed operator configuration
- `upgrade-timeline.txt` - Reconstructed upgrade timeline

## Key Findings

### Upgrade Evidence
- **From:** rhods-operator.2.25.2
- **To:** rhods-operator.3.3.0
- **Method:** OLM (Operator Lifecycle Manager)
- **Approval:** Manual (InstallPlan shows approval mode)

### Route Migration
- **Expected:** Route CR → HTTPRoute CR
- **Observed:**
  - No Route CRs with `platform.opendatahub.io/part-of=dashboard` label
  - HTTPRoute exists: `rhods-dashboard` (created 2026-01-30T16:42:39Z)
  - All resources annotated with version 3.3.0

### Timeline
```
2026-01-30T16:28:41Z - InstallPlan for 2.25.2 created
2026-01-30T16:40:38Z - InstallPlan for 3.3.0 created
2026-01-30T16:40:49Z - CSV 3.3.0 created
2026-01-30T16:41-42Z - New operator pods created
2026-01-30T16:42:39Z - HTTPRoute created
```

## Garbage Collection Analysis

The Route CR that would have been created by version 2.25.2 no longer exists. Evidence suggests:
1. Upgrade task detected old version 2.x (from DSCI/DSC status.release)
2. Operator ran HardwareProfile migration (2.x → 3.x)
3. Route was either never created or cleaned up by GC
4. Current state is correct: HTTPRoute exists, Route does not

See operator logs in `../dbasung.logs/` for additional context (logs start after initial upgrade).

## Usage Examples

**Check operator image:**
```bash
grep "Image:" operator-details.txt
```

**View all CSVs:**
```bash
yq eval '.items[] | .metadata.name + " - " + .spec.version' csvs.yaml
```

**Check dashboard status:**
```bash
yq eval '.status' dashboard-cr.yaml
```

**Find upgrade-related InstallPlans:**
```bash
yq eval '.items[] | select(.spec.clusterServiceVersionNames[] | contains("rhods")) | .metadata.name + " - " + .spec.clusterServiceVersionNames[0]' installplans.yaml
```

## Re-Collection

To collect fresh data, run:
```bash
./collect_cluster_info.sh
```

## Related Files

- `../dbasung.logs/` - Operator logs from Jan 31 - Feb 4
- `../cluster_inventory.txt` - Legacy combined inventory (971K lines)
- `../cluster_summary.txt` - Legacy summary
