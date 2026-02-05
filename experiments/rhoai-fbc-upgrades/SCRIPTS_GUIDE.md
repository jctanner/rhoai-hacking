# Scripts Guide

## Overview

This directory contains scripts for building and deploying a custom RHOAI operator from source or cluster-extracted data.

## Build Scripts

### 1. `build-custom-bundle.sh` ⭐ **RECOMMENDED**

**Purpose:** Build bundle and catalog using cluster-extracted data with your custom operator image.

**What it does:**
- ✅ Uses cluster-extracted bundle (preserves all 95 RELATED_IMAGE variables)
- ✅ Cleans runtime metadata (resourceVersion, uid, etc.) from manifests
- ✅ Patches operator image to use your custom build
- ✅ Builds and pushes bundle image
- ✅ Builds and pushes catalog image

**When to use:** When you want to deploy your custom operator code with production-verified component images.

**Output:**
- `registry.tannerjc.net/rhoai-upgrade/rhods-operator-bundle:v3.3.0`
- `registry.tannerjc.net/rhoai-upgrade/rhods-operator-catalog:v3.3.0`

**Prerequisites:** You must first build the operator image (see `build-rhoai-images.sh` or have it already built).

---

### 2. `build-rhoai-images.sh`

**Purpose:** Build operator, bundle, and catalog from source code.

**What it does:**
- ✅ Builds operator image from source
- ✅ Generates bundle from source (Makefile)
- ✅ Builds catalog

**Limitations:**
- ❌ Generated bundle has 0 RELATED_IMAGE variables
- ❌ Operator won't know which component images to deploy
- ❌ Missing 11 CRDs compared to cluster bundle

**When to use:**
- Only if you want to build the operator image itself
- Then use `build-custom-bundle.sh` for the bundle/catalog

**Output:**
- `registry.tannerjc.net/rhoai-upgrade/rhods-operator:3.3.0`

---

### 3. `build-from-extracted-bundle.sh`

**Purpose:** Build bundle and catalog using cluster data (Red Hat operator image).

**What it does:**
- ✅ Uses cluster-extracted bundle (95 RELATED_IMAGE variables)
- ❌ Uses Red Hat's operator image (not your custom build)

**When to use:**
- Only if you want to replicate the exact cluster setup
- Not recommended if you have custom operator code

**Output:**
- `registry.tannerjc.net/rhoai-upgrade/rhods-operator-bundle:v3.3.0` (with RH operator)
- `registry.tannerjc.net/rhoai-upgrade/rhods-operator-catalog:v3.3.0`

---

## Deployment Scripts

### 4. `test-deployment.sh`

**Purpose:** Deploy the custom catalog and operator to a test cluster.

**What it does:**
1. Creates CatalogSource
2. Waits for catalog to be ready
3. Verifies package availability
4. Creates namespace (redhat-ods-operator)
5. Creates OperatorGroup (AllNamespaces mode)
6. Creates Subscription (Automatic approval)
7. Monitors CSV installation
8. Verifies deployment

**Prerequisites:**
- Must have cluster access (`oc` configured)
- Bundle and catalog images must be built and pushed

**Usage:**
```bash
./test-deployment.sh
```

---

### 5. `cleanup-and-redeploy.sh`

**Purpose:** Clean up a failed or existing deployment.

**What it does:**
- Deletes Subscription
- Deletes InstallPlan
- Deletes CSV
- Deletes CatalogSource

**When to use:** Before redeploying after fixing issues.

**Usage:**
```bash
./cleanup-and-redeploy.sh
./test-deployment.sh  # Redeploy
```

---

### 6. `compare-bundles.sh`

**Purpose:** Compare generated bundle vs cluster-extracted bundle.

**What it does:**
- Shows file counts
- Shows RELATED_IMAGE variable counts
- Displays sample variables

**When to use:** To verify what's different between source-generated and cluster bundles.

**Usage:**
```bash
./compare-bundles.sh
```

---

## Recommended Workflow

### Full Build and Deploy

```bash
# 1. Build operator image from source (if needed)
./build-rhoai-images.sh  # Builds operator only

# 2. Build custom bundle with cluster data + your operator
./build-custom-bundle.sh

# 3. Deploy to test cluster
./test-deployment.sh
```

### Cleanup and Redeploy

```bash
# Clean up existing deployment
./cleanup-and-redeploy.sh

# Rebuild with fixes
./build-custom-bundle.sh

# Redeploy
./test-deployment.sh
```

### Compare Bundles

```bash
# See what's different
./compare-bundles.sh
```

---

## Key Differences: Source vs Cluster Bundle

| Aspect | Source-Generated | Cluster-Extracted |
|--------|-----------------|-------------------|
| **RELATED_IMAGE vars** | 0 | 95 |
| **CRD count** | 27 | 38 |
| **Operator image** | Custom | Red Hat (unless patched) |
| **Component images** | Unknown | SHA-pinned production images |
| **Runtime metadata** | Clean | Needs cleaning |

---

## Important Configuration

### OperatorGroup - AllNamespaces Mode Required

RHOAI operator **only supports AllNamespaces mode**:

```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator-group
  namespace: redhat-ods-operator
spec: {}  # Empty spec = AllNamespaces
```

**Supported modes:**
- ✅ AllNamespaces
- ❌ OwnNamespace
- ❌ SingleNamespace
- ❌ MultiNamespace

### Subscription - Automatic vs Manual Approval

**Automatic (recommended for testing):**
```yaml
spec:
  installPlanApproval: Automatic
```

**Manual (recommended for production):**
```yaml
spec:
  installPlanApproval: Manual
```

---

## Troubleshooting

### InstallPlan Fails: "resourceVersion should not be set"

**Cause:** Bundle contains runtime metadata from cluster extraction.

**Fix:** Use `build-custom-bundle.sh` which cleans metadata automatically.

### CSV Fails: "UnsupportedOperatorGroup"

**Cause:** OperatorGroup has targetNamespaces set.

**Fix:** Use empty spec `{}` for AllNamespaces mode.

### Bundle has 0 RELATED_IMAGE variables

**Cause:** Using `build-rhoai-images.sh` generated bundle.

**Fix:** Use `build-custom-bundle.sh` instead.

### Catalog pod crashes with "illegal base64 data"

**Cause:** Incomplete icon in catalog.yaml.

**Fix:** Already fixed in `build-custom-bundle.sh` (icon removed).

---

## Files Generated

### Cluster Data (Already Extracted)
- `example_cluster_info/rhoai-fbc/bundles/3.3.0/` - Production bundle
- `example_cluster_info/rhoai-fbc/catalog.yaml` - Production catalog
- `example_cluster_info/rhoai-fbc/csv-3.3.0.yaml` - Production CSV

### Build Artifacts (Generated by scripts)
- `src/red-hat-data-services/rhods-operator.3.3/rhoai-bundle/` - Source-generated bundle
- `catalog-build/` - Built catalog directory
- Temporary directories in `/tmp/` (cleaned automatically)

---

## Summary

**For most use cases, use this workflow:**

1. `./build-rhoai-images.sh` - Build operator from source (once)
2. `./build-custom-bundle.sh` - Build bundle/catalog with cluster data
3. `./test-deployment.sh` - Deploy and verify

This gives you:
- ✅ Your custom operator code
- ✅ All 95 RELATED_IMAGE variables
- ✅ Production-verified component images
- ✅ Clean manifests (no runtime metadata)
