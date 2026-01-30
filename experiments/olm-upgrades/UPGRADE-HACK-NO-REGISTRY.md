# Simulating OLM Upgrades Without a Registry

This document describes how to simulate an OLM upgrade using `operator-sdk` shortcuts without requiring a personal container registry.

## Why This Approach

✅ **Quick testing**: No registry setup required
✅ **Simple**: Uses make targets that handle bundling automatically
✅ **Self-contained**: Everything runs locally or in temporary storage

⚠️ **Limitations:**
- Less production-like than using a real registry
- Bundle images are temporary
- Can't easily share bundles with others
- Can't create persistent catalogs

**Use this approach for:** Quick testing when you don't have registry access.

**For a better experience:** See **UPGRADE-HACK-REGISTRY.md** if you have access to a container registry.

## Prerequisites

- `operator-sdk` CLI installed
- OLM installed in the cluster
- Cluster can pull from temporary/local registries created by `operator-sdk`

## Current State of the Repositories

**stable-2.x** (`bundle/manifests/rhods-operator.clusterserviceversion.yaml`):
- CSV name: `rhods-operator.v2.25.0`
- Version: `2.25.0`
- No `replaces` field
- skipRange: `>=1.0.0 <2.0.0`

**main** (`config/rhoai/manifests/bases/rhods-operator.clusterserviceversion.yaml`):
- CSV name: `rhods-operator.v2.0.0` (base template - gets version from Makefile)
- Version: `3.0.0` (from VERSION variable in Makefile)
- No `replaces` field
- skipRange: `>=1.0.0 <2.0.0`

## The Problem

Without a `replaces` field in the v3.0.0 CSV pointing to `rhods-operator.v2.25.0`, OLM won't recognize this as an upgrade in the replacement chain. The `operator-sdk run bundle-upgrade` command may work, but it won't be a true OLM upgrade following the dependency resolution algorithm described in OLM-UPGRADES.md.

## Step-by-Step Instructions

### Step 1: Edit the CSV Base Template

Add the `replaces` field so OLM recognizes the upgrade path.

```bash
cd src/opendatahub-io/opendatahub-operator.main

# Edit the RHOAI CSV base file
vi config/rhoai/manifests/bases/rhods-operator.clusterserviceversion.yaml
```

Add the `replaces` field in the `spec` section (around line 97):

```yaml
spec:
  apiservicedefinitions: {}
  replaces: rhods-operator.v2.25.0  # <-- ADD THIS LINE
  customresourcedefinitions:
    owned:
    - description: HardwareProfile is the Schema for the hardwareprofiles API.
```

Save and exit.

### Step 2: Install v2.25.0 via OLM

```bash
cd src/opendatahub-io/opendatahub-operator.stable-2.x

# Build bundle and install via OLM
make deploy-bundle OPERATOR_NAMESPACE=redhat-ods-operator
```

**What this does:**
1. Runs `manifests` target to generate CRDs, RBAC, etc.
2. Runs `bundle` target to generate bundle manifests (CSV, metadata)
3. Builds bundle image locally
4. Pushes to a temporary/local registry
5. Uses `operator-sdk run bundle` which:
   - Creates a temporary CatalogSource in the cluster
   - Creates a Subscription
   - OLM installs the operator following the full InstallPlan process

**Watch the installation:**

```bash
# Watch CSV status
oc get csv -n redhat-ods-operator -w

# Expected output:
# NAME                      DISPLAY                 VERSION   PHASE
# rhods-operator.v2.25.0    Red Hat OpenShift AI    2.25.0    Pending
# rhods-operator.v2.25.0    Red Hat OpenShift AI    2.25.0    Installing
# rhods-operator.v2.25.0    Red Hat OpenShift AI    2.25.0    Succeeded
```

Wait for CSV to reach `Succeeded` phase before proceeding.

### Step 3: Upgrade to v3.0.0

```bash
cd ../opendatahub-operator.main

# Regenerate bundle with the replaces field
make bundle

# Perform the upgrade via OLM
make upgrade-bundle OPERATOR_NAMESPACE=redhat-ods-operator
```

**What this does:**
1. Regenerates bundle manifests with the new `replaces` field
2. Builds v3.0.0 bundle image
3. Uses `operator-sdk run bundle-upgrade` which:
   - Updates the existing CatalogSource
   - OLM detects the new version via the `replaces: rhods-operator.v2.25.0` field
   - OLM performs the full upgrade process described in ODH-UPGRADE-HYPOTHESIS.md

**Watch the upgrade:**

```bash
# Watch CSV transitions (you'll see BOTH CSVs during transition)
oc get csv -n redhat-ods-operator -w

# Expected output:
# NAME                      DISPLAY                 VERSION   REPLACES                  PHASE
# rhods-operator.v2.25.0    Red Hat OpenShift AI    2.25.0                              Replacing
# rhods-operator.v3.0.0     Red Hat OpenShift AI    3.0.0     rhods-operator.v2.25.0    Installing
# ...
# rhods-operator.v3.0.0     Red Hat OpenShift AI    3.0.0     rhods-operator.v2.25.0    Succeeded
```

## Verification

Check all the OLM resources to verify the upgrade:

```bash
# Check final CSV status
oc get csv -n redhat-ods-operator

# Should show only v3.0.0 in Succeeded state
# NAME                      DISPLAY                 VERSION   REPLACES                  PHASE
# rhods-operator.v3.0.0     Red Hat OpenShift AI    3.0.0     rhods-operator.v2.25.0    Succeeded

# Check subscription status
oc get subscription -n redhat-ods-operator -o yaml

# View install plans (you'll see plans for both install and upgrade)
oc get installplan -n redhat-ods-operator

# See the catalog source created by operator-sdk
oc get catalogsource -n redhat-ods-operator

# Check operator pod (new v3.0.0 pod should be running)
oc get pods -n redhat-ods-operator

# Verify new CRDs were installed
oc get crds | grep opendatahub

# Check for new CRDs specific to v3.0.0
oc get crd gatewayconfigs.services.platform.opendatahub.io
oc get crd mlflowoperators.components.platform.opendatahub.io
oc get crd modelsasservices.components.platform.opendatahub.io
oc get crd sparkoperators.components.platform.opendatahub.io
oc get crd trainers.components.platform.opendatahub.io

# Check for multi-version CRDs
oc get crd datascienceclusters.datasciencecluster.opendatahub.io -o jsonpath='{.spec.versions[*].name}'
# Should show: v1 v2
```

Check subscription details:

```bash
oc get subscription -n redhat-ods-operator -o jsonpath='{.items[0].status}' | jq
```

Expected output:
```json
{
  "installPlanRef": {
    "name": "install-xxxxx"
  },
  "installedCSV": "rhods-operator.v3.0.0",
  "state": "AtLatestKnown"
}
```

## What You'll Observe During Upgrade

All the OLM upgrade mechanisms described in OLM-UPGRADES.md:

1. ✅ **CRD Storage Version Validation**: OLM validates existing CRDs before upgrade
2. ✅ **Existing CR Validation**: All existing Custom Resources validated against new schemas
3. ✅ **Dual-CSV Operation**: Both v2.25.0 and v3.0.0 CSVs running simultaneously during transition
4. ✅ **Atomic InstallPlan**: All resources created together via InstallPlan
5. ✅ **Dependency Resolution**: OLM ensures all required APIs available
6. ✅ **RBAC Updates**: Old roles removed, new roles created
7. ✅ **Webhook Preservation**: Admission control continues during upgrade
8. ✅ **Owner Reference Transfer**: Resources gradually transferred from old to new CSV

See **ODH-UPGRADE-HYPOTHESIS.md** for detailed breakdown of what changes during the v2.25.0 → v3.0.0 upgrade.

## Detailed Observations

### CSV Phase Transitions

Watch the CSV phases carefully:

```bash
oc get csv -n redhat-ods-operator -w
```

You'll see this progression:

```
Stage 1 - v2.25.0 running:
rhods-operator.v2.25.0    Succeeded

Stage 2 - Upgrade detected:
rhods-operator.v2.25.0    Replacing
rhods-operator.v3.0.0     Pending

Stage 3 - New version installing:
rhods-operator.v2.25.0    Replacing
rhods-operator.v3.0.0     InstallReady

Stage 4 - Dual operation:
rhods-operator.v2.25.0    Replacing
rhods-operator.v3.0.0     Installing

Stage 5 - New version ready:
rhods-operator.v2.25.0    Deleting
rhods-operator.v3.0.0     Succeeded

Stage 6 - Final state:
rhods-operator.v3.0.0     Succeeded
```

### InstallPlan Steps

View the upgrade InstallPlan:

```bash
# Find the upgrade InstallPlan
oc get installplan -n redhat-ods-operator

# Get detailed steps
oc get installplan <install-plan-name> -n redhat-ods-operator -o yaml
```

You should see steps for:
- CRD installations/updates (5 new, 3 updated)
- RBAC changes (9 removals, updated permissions)
- Deployment updates
- CSV creation

## Cleanup

To remove the operator and start over:

```bash
# Remove the operator bundle (cleanest method)
operator-sdk cleanup rhods-operator -n redhat-ods-operator

# Or manually delete resources
oc delete csv rhods-operator.v3.0.0 -n redhat-ods-operator
oc delete subscription -l operators.coreos.com/rhods-operator.redhat-ods-operator -n redhat-ods-operator
oc delete catalogsource -l operators.coreos.com/rhods-operator.redhat-ods-operator -n redhat-ods-operator

# CRDs are NOT automatically deleted by OLM
# Delete them manually if needed (WARNING: deletes all CRs too!)
oc get crds | grep opendatahub | awk '{print $1}' | xargs oc delete crd

# Or delete specific CRDs
oc delete crd datascienceclusters.datasciencecluster.opendatahub.io
oc delete crd dscinitializations.dscinitialization.opendatahub.io
# ... etc
```

## Troubleshooting

### `make deploy-bundle` Fails

Check that all prerequisites are met:

```bash
# Verify operator-sdk is installed
operator-sdk version

# Verify cluster access
oc whoami
oc get nodes

# Check if namespace exists
oc get namespace redhat-ods-operator
# If not, create it:
oc create namespace redhat-ods-operator
```

### Bundle Image Build Fails

```bash
# Ensure manifests are generated first
cd src/opendatahub-io/opendatahub-operator.stable-2.x
make manifests
make bundle

# Check for errors in bundle validation
operator-sdk bundle validate ./bundle
```

### Upgrade Not Detected

The most common issue is the missing `replaces` field. Verify it's in the bundle:

```bash
cd src/opendatahub-io/opendatahub-operator.main

# Check the base CSV has replaces field
grep "replaces:" config/rhoai/manifests/bases/rhods-operator.clusterserviceversion.yaml

# Regenerate bundle to include the replaces field
make bundle

# Check generated bundle has replaces field
grep "replaces:" bundle/manifests/rhods-operator.clusterserviceversion.yaml
# Should show: replaces: rhods-operator.v2.25.0
```

If missing from the base file, go back to Step 1 and add it.

### `operator-sdk run bundle-upgrade` Does Nothing

This can happen if OLM doesn't see the upgrade relationship. Check:

```bash
# Verify current CSV
oc get csv -n redhat-ods-operator

# Verify subscription exists
oc get subscription -n redhat-ods-operator

# Check if CatalogSource has the operator
oc get catalogsource -n redhat-ods-operator -o yaml
```

If the subscription doesn't exist, the initial `deploy-bundle` may have failed. Go back to Step 2.

### Pods Not Updating

If you see the new CSV in Succeeded but the old pod is still running:

```bash
# Check pod owner
oc get pods -n redhat-ods-operator -o yaml | grep -A10 ownerReferences

# Force pod deletion if needed (OLM should recreate with new version)
oc delete pod -l app.kubernetes.io/name=rhods-operator -n redhat-ods-operator
```

## Alternative: Using Option 1 (May Not Be True OLM Upgrade)

If you don't want to add the `replaces` field, you can try upgrading without it:

```bash
# Step 1: Install v2.25.0
cd src/opendatahub-io/opendatahub-operator.stable-2.x
make deploy-bundle

# Step 2: Attempt upgrade without replaces
cd ../opendatahub-operator.main
make upgrade-bundle
```

**However**, this may just replace the subscription's bundle reference rather than using OLM's upgrade resolution algorithm. You won't see:
- The full replacement chain behavior
- Dependency resolution across versions
- All the safety checks described in OLM-UPGRADES.md

For a proper OLM upgrade simulation, always add the `replaces` field.

## Why This Works

The `operator-sdk run bundle` and `run bundle-upgrade` commands are specifically designed for development/testing scenarios where you don't have:
- A permanent catalog in a registry
- CI/CD pipeline to build and push bundles
- Production catalog infrastructure

Instead, `operator-sdk`:
- Builds the bundle image locally
- Pushes to a local or temporary registry
- Creates a temporary CatalogSource on the cluster
- Creates/updates the Subscription
- Lets OLM handle the rest

This gives you a real OLM upgrade experience without registry infrastructure.

## Differences from Production Upgrades

**What's the same:**
- OLM's upgrade orchestration and validation
- InstallPlan creation and execution
- CSV state transitions
- CRD and CR validation
- All safety mechanisms

**What's different:**
- Temporary CatalogSource (deleted when you run `operator-sdk cleanup`)
- Bundle images in temporary/local registry (not persistent)
- No permanent catalog (can't share with others)
- No automatic updates (you manually trigger upgrade with `make upgrade-bundle`)

## References

- **OLM-UPGRADES.md**: How OLM upgrades work internally
- **ODH-UPGRADE-HYPOTHESIS.md**: Specific upgrade behavior from v2.25.0 to v3.0.0
- **UPGRADE-HACK-REGISTRY.md**: Better approach if you have registry access
- [operator-sdk bundle documentation](https://sdk.operatorframework.io/docs/olm-integration/tutorial-bundle/)
