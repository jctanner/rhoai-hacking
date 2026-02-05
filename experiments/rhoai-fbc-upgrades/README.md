# RHOAI FBC Catalog & Upgrade Testing

Custom FBC (File-Based Catalog) build system for deploying RHOAI operator modifications via OLM, with focus on testing upgrade paths from v2.x → v3.x.

## Problem Statement

We needed to test RHOAI operator changes (specifically Route → HTTPRoute garbage collection during upgrades) without going through the full Red Hat release pipeline. This required:

1. Building a custom operator from source
2. Creating an OLM-compatible bundle with all production RELATED_IMAGE environment variables
3. Building an FBC catalog that defines the upgrade path
4. Testing the upgrade on a live cluster

The critical challenge: **source-generated bundles have 0 RELATED_IMAGE variables**, while production has 95. Without these, the operator doesn't know which component images to deploy.

## Solution Architecture

### Three-Layer Approach

```
┌─────────────────────────────────────────────────────────────┐
│  Custom Operator Image (Built from Source)                  │
│  registry.tannerjc.net/rhoai-upgrade/rhods-operator:3.3.0   │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Hybrid Bundle (Cluster Data + Custom Operator)             │
│  - 95 RELATED_IMAGE vars from production (cluster-extracted)│
│  - CSV patched to use custom operator image                 │
│  - Runtime metadata cleaned (resourceVersion, uid, etc.)    │
│  registry.tannerjc.net/rhoai-upgrade/rhods-operator-bundle:v3.3.0
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  FBC Catalog (Defines Upgrade Path)                         │
│  - Package: rhods-operator                                   │
│  - Channel: stable                                           │
│  - Upgrade: 2.25.2 → 3.3.0 (skipRange: '>=2.25.0 <3.3.0')  │
│  registry.tannerjc.net/rhoai-upgrade/rhods-operator-catalog:v3.3.0
└─────────────────────────────────────────────────────────────┘
```

### Key Insight: Cluster-Extracted Bundle Data

The production bundle in a running cluster contains metadata that source code doesn't:

| Aspect | Source-Generated | Cluster-Extracted |
|--------|-----------------|-------------------|
| RELATED_IMAGE vars | 0 | 95 |
| CRDs | 27 | 38 |
| Component images | Unknown | SHA-pinned production refs |
| Operator image | Custom | Red Hat official (patchable) |

**Our approach:** Extract bundle from cluster, patch operator image, rebuild catalog.

## What We Built

### Build Scripts

1. **`build-rhoai-images.sh`** - Build operator image from source
   - Builds from `./src/red-hat-data-services/rhods-operator.3.3`
   - Uses `make image-build` with `ODH_PLATFORM_TYPE=RHOAI`
   - Output: `registry.tannerjc.net/rhoai-upgrade/rhods-operator:3.3.0`

2. **`build-custom-bundle.sh`** ⭐ **Main build script**
   - Takes cluster-extracted bundle from `example_cluster_info/rhoai-fbc/bundles/3.3.0/`
   - Cleans runtime metadata (resourceVersion, uid, generation, managedFields)
   - Patches CSV to use custom operator image
   - Preserves all 95 RELATED_IMAGE environment variables
   - Builds bundle and catalog images
   - **This is the recommended build workflow**

3. **`build-from-extracted-bundle.sh`** - Build with Red Hat operator image
   - Uses cluster bundle without operator image patching
   - Only useful for replicating exact cluster state

### Deployment & Testing Scripts

4. **`test-deployment.sh`** - Automated deployment
   - Creates CatalogSource, OperatorGroup (AllNamespaces mode), Subscription
   - Monitors CSV installation and verifies deployment
   - Checks RELATED_IMAGE count (should be 95)

5. **`full-cleanup-rhoai.sh`** - Complete RHOAI removal
   - 13-step cleanup process
   - Deletes all CRs, CRDs, namespaces, catalog sources
   - Removes finalizers from stuck resources
   - Triggers etcd compaction
   - Critical for testing fresh installs and upgrades

6. **`verify-cleanup.sh`** - Verify cleanup completed
7. **`verify-etcd-clean.sh`** - Verify etcd cleanup
8. **`cleanup-and-redeploy.sh`** - Quick cleanup helper
9. **`compare-bundles.sh`** - Compare source vs cluster bundles

### Documentation

- **`SCRIPTS_GUIDE.md`** - Complete script documentation
- **`UPGRADE_TEST_WORKFLOW.md`** - Step-by-step upgrade testing guide
- **`QUICK_START.md`** - Quick start guide with setup instructions

### Data Directories

- **`src/`** - Operator source code (create this directory)
  - `red-hat-data-services/rhods-operator.3.3/` - Clone RHOAI operator here

- **`example_cluster_info/`** - Cluster-extracted bundle data
  - `rhoai-fbc/bundles/3.3.0/` - Production bundle (38 manifests, 95 RELATED_IMAGE vars)

- **`catalog-build/`** - Generated catalog artifacts (created during build)
  - `catalog.yaml` - Built FBC catalog with upgrade path

- **`manifests/`** - Test manifests
  - DSC, DSCI, Route, HTTPRoute test resources

## Technical Deep Dive

### FBC Catalog Structure

File-Based Catalog (FBC) is the modern OLM catalog format (YAML vs deprecated SQLite):

```yaml
---
defaultChannel: stable
name: rhods-operator
schema: olm.package
---
schema: olm.channel
package: rhods-operator
name: stable
entries:
  - name: rhods-operator.v3.3.0
    replaces: rhods-operator.2.25.2      # Direct upgrade path
    skipRange: '>=2.25.0 <3.3.0'         # Allows any 2.25.x → 3.3.0
---
schema: olm.bundle
name: rhods-operator.v3.3.0
package: rhods-operator
image: registry.tannerjc.net/rhoai-upgrade/rhods-operator-bundle:v3.3.0
properties:
  - type: olm.package
    value:
      packageName: rhods-operator
      version: 3.3.0
```

**Upgrade logic:**
- `replaces`: Direct upgrade from this specific version
- `skipRange`: Allows upgrades from any version in range (semver)
- OLM sees both v2 and v3 catalogs, detects available upgrade, creates InstallPlan

### Runtime Metadata Cleaning

Kubernetes rejects CRD manifests with runtime metadata when installing via OLM:

```bash
# Error: "resourceVersion should not be set on objects to be created"

# Fix: Clean metadata from CSV and all CRDs
yq eval -i '
  del(.metadata.resourceVersion) |
  del(.metadata.uid) |
  del(.metadata.generation) |
  del(.metadata.creationTimestamp) |
  del(.metadata.managedFields) |
  del(.metadata.selfLink) |
  del(.status)
' "$CSV_FILE"
```

This is critical when using cluster-extracted bundles.

### OperatorGroup Constraints

RHOAI operator **only supports AllNamespaces mode**:

```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator-group
  namespace: redhat-ods-operator
spec: {}  # Empty spec = AllNamespaces
```

**Why:** The operator deploys components across multiple namespaces:
- `redhat-ods-operator` - Operator itself
- `redhat-ods-applications` - Dashboard, workbenches, etc.
- `redhat-ods-monitoring` - Monitoring stack

OwnNamespace/SingleNamespace modes fail with `UnsupportedOperatorGroup` error.

### CRD Version Conversion (v1 → v2)

Both DSCInitialization and DataScienceCluster CRDs use webhook-based conversion:

```
CRD Versions:
  v1: served=true, storage=false
  v2: served=true, storage=true ← storage version

Conversion Strategy: Webhook
Webhook Service: rhods-operator-service:443/convert
```

When the operator upgrades to v3.3.0:
1. CRDs updated to use v2 as storage version
2. Existing v1 objects automatically converted via webhook
3. Objects stored as v2 in etcd
4. v1 API still served for backward compatibility

No manual migration required - Kubernetes handles this transparently.

### RELATED_IMAGE Variables

These environment variables tell the operator which component images to deploy:

```bash
# Example from CSV
RELATED_IMAGE_ODH_DASHBOARD_IMAGE=registry.redhat.io/rhoai/odh-dashboard-rhel9@sha256:4c314d56...
RELATED_IMAGE_ODH_NOTEBOOK_CONTROLLER_IMAGE=registry.redhat.io/rhoai/odh-notebook-controller-rhel9@sha256:...
# ... 95 total variables
```

**Why critical:**
- Operator reads these at runtime to deploy components
- SHA-pinned for consistency and security
- Source-generated bundles don't have these (templating issue in upstream)
- Cluster-extracted bundles have all 95 (set during Red Hat build process)

**Our solution:** Use cluster bundle data, patch only the operator image.

## Upgrade Testing Results

### Test: v2.25.2 → v3.3.0 Upgrade

**Objective:** Verify Route → HTTPRoute migration with garbage collection

**Setup:**
1. Installed RHOAI v2.25.2 from official catalog (quay.io/rhoai/rhoai-fbc-fragment:rhoai-2.25)
2. Created DSC with dashboard enabled
3. Verified Route CR exists: `rhods-dashboard` (OpenShift Route)

**Upgrade Process:**
1. Deployed custom v3.3.0 catalog
2. Patched Subscription to point to custom catalog
3. OLM detected upgrade path via `skipRange: '>=2.25.0 <3.3.0'`
4. Created InstallPlan, installed CSV v3.3.0
5. Operator pods restarted with custom image

**Results:**
- ✅ CSV upgraded successfully (rhods-operator.3.3.0, Phase: Succeeded)
- ✅ Custom operator image deployed (`registry.tannerjc.net/rhoai-upgrade/rhods-operator:3.3.0`)
- ✅ All 95 RELATED_IMAGE variables preserved
- ✅ **Route CR deleted** (garbage collection worked!)
- ✅ **HTTPRoute CR created** (rhods-dashboard, using Gateway API)
- ✅ DSC/DSCI converted from v1 → v2 (automatic webhook conversion)
- ✅ Dashboard continued running without downtime

**Key Finding:** The garbage collection mechanism successfully cleaned up the old Route CR during the v2 → v3 upgrade, confirming the feature works as designed.

## Common Issues & Solutions

### 1. InstallPlan Fails: "resourceVersion should not be set"

**Cause:** Cluster-extracted manifests contain runtime metadata

**Fix:** Already handled in `build-custom-bundle.sh` - cleans all runtime metadata from CSV and CRDs

### 2. CSV Fails: "UnsupportedOperatorGroup"

**Cause:** OperatorGroup has `targetNamespaces` set (OwnNamespace mode)

**Fix:** Use empty spec `{}` for AllNamespaces mode

### 3. Bundle Missing RELATED_IMAGE Variables

**Cause:** Using source-generated bundle (`make bundle`)

**Fix:** Use `build-custom-bundle.sh` which uses cluster-extracted bundle data

### 4. Upgrade Not Detected by OLM

**Cause:** Missing upgrade path in FBC catalog

**Fix:** Ensure catalog has `replaces` and `skipRange` in channel entry (fixed in `build-custom-bundle.sh`)

### 5. Catalog Pod Crashes: "illegal base64 data"

**Cause:** Incomplete base64 icon data in catalog.yaml

**Fix:** Already handled - we remove icon section from catalog template

### 6. Namespaces Stuck in Terminating

**Cause:** Resources with finalizers blocking deletion

**Fix:** `full-cleanup-rhoai.sh` removes finalizers automatically

## Development Workflow

### Building Custom Operator

```bash
# 1. Make code changes in source tree
cd ./src/red-hat-data-services/rhods-operator.3.3

# 2. Build operator image
cd -  # Return to rhoai-fbc-upgrades directory
./build-rhoai-images.sh  # Only builds operator, not bundle

# 3. Build bundle+catalog with cluster data
./build-custom-bundle.sh  # Uses cluster bundle + custom operator image
```

### Testing Deployment

```bash
# Fresh install
./test-deployment.sh

# After making changes
./cleanup-and-redeploy.sh
./build-custom-bundle.sh
./test-deployment.sh
```

### Testing Upgrades

```bash
# Full upgrade test
# See UPGRADE_TEST_WORKFLOW.md for complete guide

# Phase 1: Clean slate
./full-cleanup-rhoai.sh
./verify-cleanup.sh

# Phase 2-3: Install v2.25.2 with components
# (See UPGRADE_TEST_WORKFLOW.md Phase 2-3)

# Phase 4-5: Deploy v3 catalog and upgrade
# (See UPGRADE_TEST_WORKFLOW.md Phase 4-5)

# Phase 6-7: Verify upgrade and GC
# (See UPGRADE_TEST_WORKFLOW.md Phase 6-7)
```

## Architecture Decisions

### Why Hybrid Bundle?

**Considered alternatives:**
1. ❌ Use source-generated bundle → Missing RELATED_IMAGE vars, operator can't deploy components
2. ❌ Manually add RELATED_IMAGE vars → 95 variables, error-prone, drift from production
3. ✅ Use cluster bundle + patch operator image → Best of both worlds

### Why FBC Instead of SQLite Catalog?

- FBC is the modern standard (OLM v1)
- YAML is human-readable and git-friendly
- Easier to modify upgrade paths
- Better tooling support (opm)

### Why Not Use Mirror/Disconnected Install?

We're testing operator code changes, not component images. The RELATED_IMAGE variables still point to Red Hat registry because:
- We only modified operator code, not component images
- Components (dashboard, notebooks, etc.) use production images
- For disconnected testing, you'd need to mirror all 95 images and update vars

## Repository Structure

```
rhoai-fbc-upgrades/  ← Can be cloned anywhere
├── build-custom-bundle.sh          # ⭐ Main build script
├── build-rhoai-images.sh           # Build operator from source
├── build-from-extracted-bundle.sh  # Build with RH operator image
├── test-deployment.sh              # Automated deployment
├── cleanup-and-redeploy.sh         # Quick cleanup
├── compare-bundles.sh              # Compare bundles
├── full-cleanup-rhoai.sh           # Complete cleanup (13 steps)
├── verify-cleanup.sh               # Verify cleanup
├── verify-etcd-clean.sh            # Verify etcd cleanup
├── README.md                       # This file - complete technical guide
├── SCRIPTS_GUIDE.md                # Scripts documentation
├── UPGRADE_TEST_WORKFLOW.md        # Upgrade testing guide
├── QUICK_START.md                  # Quick start guide
├── .gitignore                      # Ignores src/ and build artifacts
├── src/                            # Create this - operator source code
│   └── red-hat-data-services/
│       └── rhods-operator.3.3/     # Clone RHOAI operator here (rhoai-3.3 branch)
├── catalog-build/                  # Built catalog artifacts (generated)
│   └── catalog.yaml                # FBC catalog with upgrade path
├── example_cluster_info/           # Cluster-extracted bundle data
│   └── rhoai-fbc/
│       └── bundles/3.3.0/          # Production bundle (95 RELATED_IMAGE)
│           ├── manifests/          # 38 manifest files (1 CSV + 37 CRDs)
│           └── metadata/           # Bundle metadata
└── manifests/                      # Test manifests
    ├── minimal-dsc.yaml
    ├── rhods-dashboard.yaml
    ├── nginx-redirect.yaml
    └── test-route*.yaml
```

## References

### OLM Documentation
- [Operator Lifecycle Manager (OLM)](https://olm.operatorframework.io/)
- [File-Based Catalogs (FBC)](https://olm.operatorframework.io/docs/reference/file-based-catalogs/)
- [Install Modes](https://olm.operatorframework.io/docs/advanced-tasks/operator-scoping-with-operatorgroups/)

### RHOAI Documentation
- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed)
- [ODH Operator GitHub](https://github.com/opendatahub-io/opendatahub-operator)

### Related Issues
- Route → HTTPRoute migration (testing garbage collection)
- v2 → v3 upgrade path validation
- Custom operator deployment for testing

## Next Steps

Potential improvements:
- Automate bundle extraction from cluster
- Add bundle validation (check RELATED_IMAGE count, CRD count, etc.)
- Create CI pipeline for build/test
- Add support for multiple operator versions in catalog
- Document component image mirroring for disconnected testing
- Add bundle diff tool to compare changes between versions

## Notes

- This is a **development/testing setup**, not for production use
- The custom operator image is unsigned and won't work with production catalogs
- RELATED_IMAGE variables still point to Red Hat registry (by design)
- etcd cleanup is automatic in Kubernetes - CRD deletion triggers data removal
- The skipRange syntax is semver-compatible: `>=2.25.0 <3.3.0` means any 2.25.x
- AllNamespaces OperatorGroup mode is **required** for RHOAI (not optional)

---

**Last Updated:** 2026-02-04
**RHOAI Version Tested:** v2.25.2 → v3.3.0
**Cluster:** jtannertest.eh5f.s1.devshift.org
