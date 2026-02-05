# RHOAI Operator Build - Quick Start

## Prerequisites

### Required Source Code

You need the RHOAI operator source code checked out locally in this directory:

```bash
# From the rhoai-fbc-upgrades directory (where this README is)
mkdir -p src/red-hat-data-services
cd src/red-hat-data-services
git clone https://github.com/red-hat-data-services/rhods-operator.git rhods-operator.3.3
cd rhods-operator.3.3
git checkout rhoai-3.3  # Or your target branch
cd ../../..  # Return to rhoai-fbc-upgrades directory
```

**Expected directory structure:**
```
rhoai-fbc-upgrades/  ← You are here (can be anywhere on your system)
├── build-custom-bundle.sh
├── build-rhoai-images.sh
├── test-deployment.sh
├── example_cluster_info/
│   └── rhoai-fbc/bundles/3.3.0/  ← Production bundle data
├── src/  ← Create this
│   └── red-hat-data-services/
│       └── rhods-operator.3.3/  ← Clone RHOAI operator here (rhoai-3.3 branch)
│           ├── Makefile
│           ├── controllers/
│           └── ...
└── ...
```

The build scripts expect the operator source at: `./src/red-hat-data-services/rhods-operator.3.3`

**Note:** This makes the project self-contained - you can clone `rhoai-hacking` anywhere and just create the `src/` directory inside `rhoai-fbc-upgrades/`.

---

## Build the Images

### Recommended: Use Custom Bundle Builder

This preserves all 95 RELATED_IMAGE variables from production:

```bash
./build-custom-bundle.sh
```

**What it does:**
- ✓ Uses cluster-extracted bundle (95 RELATED_IMAGE variables)
- ✓ Patches operator image to your custom build
- ✓ Builds bundle image with cleaned manifests
- ✓ Builds catalog (FBC) image
- ✓ Pushes all images to registry.tannerjc.net/rhoai-upgrade/*

**Estimated time:** 2-3 minutes

### Optional: Build Operator from Source First

If you've made changes to the operator code:

```bash
./build-rhoai-images.sh  # Builds operator only
./build-custom-bundle.sh  # Then build bundle/catalog
```

---

## Deploy to Cluster

### 1. Create CatalogSource

```bash
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhoai-custom-catalog
  namespace: openshift-marketplace
spec:
  displayName: RHOAI Custom Catalog
  sourceType: grpc
  image: registry.tannerjc.net/rhoai-upgrade/rhods-operator-catalog:v3.3.0
  publisher: Custom Build
  updateStrategy:
    registryPoll:
      interval: 10m
EOF
```

### 2. Verify CatalogSource

```bash
oc get catalogsource rhoai-custom-catalog -n openshift-marketplace
oc get pods -n openshift-marketplace -l olm.catalogSource=rhoai-custom-catalog
```

Wait for status: `READY`

### 3. Create Namespace

```bash
oc create namespace redhat-ods-operator
```

### 4. Create OperatorGroup

**IMPORTANT:** RHOAI operator requires AllNamespaces mode!

```bash
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator-group
  namespace: redhat-ods-operator
spec: {}
EOF
```

**Note:** Empty `spec: {}` = AllNamespaces mode (required for RHOAI)

### 5. Create Subscription

```bash
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: stable
  name: rhods-operator
  source: rhoai-custom-catalog
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF
```

### 6. Verify Installation

```bash
# Check CSV (should show rhods-operator.v3.3.0)
oc get csv -n redhat-ods-operator

# Check operator pods (should show 3 pods running)
oc get pods -n redhat-ods-operator

# Check operator logs
oc logs -n redhat-ods-operator deployment/rhods-operator

# Verify RELATED_IMAGE count (should be 95)
oc get deployment rhods-operator -n redhat-ods-operator -o json \
  | jq '[.spec.template.spec.containers[0].env[] | select(.name | startswith("RELATED_IMAGE"))] | length'
```

---

## Images Built

| Component | Image |
|-----------|-------|
| **Operator** | `registry.tannerjc.net/rhoai-upgrade/rhods-operator:3.3.0` |
| **Bundle** | `registry.tannerjc.net/rhoai-upgrade/rhods-operator-bundle:v3.3.0` |
| **Catalog** | `registry.tannerjc.net/rhoai-upgrade/rhods-operator-catalog:v3.3.0` |

---

## Troubleshooting

### Build Issues

**Missing tools:**
```bash
# Check required tools
which operator-sdk opm yq podman
```

**Clean build:**
```bash
cd src/red-hat-data-services/rhods-operator.3.3
make clean
cd -  # Returns to rhoai-fbc-upgrades directory
./build-custom-bundle.sh
```

### Catalog Not Ready

**Check catalog pod:**
```bash
oc get pods -n openshift-marketplace -l olm.catalogSource=rhoai-custom-catalog
oc logs <catalog-pod> -n openshift-marketplace
```

**Common issue:** Image pull failure - check registry credentials

### Package Not Found

**List packages:**
```bash
oc get packagemanifests -n openshift-marketplace | grep rhods
```

**Check catalog:**
```bash
oc describe catalogsource rhoai-custom-catalog -n openshift-marketplace
```

### InstallPlan Fails

**View InstallPlan details:**
```bash
oc get installplan -n redhat-ods-operator -o yaml
```

**Check OLM operator logs:**
```bash
oc logs -n openshift-marketplace deployment/olm-operator
```

**Common issues:**
- `resourceVersion should not be set` - Fixed in build-custom-bundle.sh (metadata cleaning)
- `UnsupportedOperatorGroup` - Use empty `spec: {}` for AllNamespaces mode

### CSV Installation Fails

**Check failure reason:**
```bash
oc get csv -n redhat-ods-operator -o yaml | grep -A10 "message:"
```

**Force reconciliation:**
```bash
oc delete csv --all -n redhat-ods-operator
# Subscription will recreate it
```

---

## More Information

### Documentation

- **[README.md](./README.md)** - Complete technical guide with architecture, troubleshooting, and testing
- **[SCRIPTS_GUIDE.md](./SCRIPTS_GUIDE.md)** - All build/deploy scripts explained
- **[UPGRADE_TEST_WORKFLOW.md](./UPGRADE_TEST_WORKFLOW.md)** - Step-by-step v2.x → v3.x upgrade testing

### Scripts

- **[build-custom-bundle.sh](./build-custom-bundle.sh)** - Main build script (recommended)
- **[build-rhoai-images.sh](./build-rhoai-images.sh)** - Build operator from source
- **[test-deployment.sh](./test-deployment.sh)** - Automated deployment
- **[full-cleanup-rhoai.sh](./full-cleanup-rhoai.sh)** - Complete RHOAI removal

### Bundle Data

- **[example_cluster_info/rhoai-fbc/bundles/3.3.0/](./example_cluster_info/rhoai-fbc/bundles/3.3.0/)** - Production bundle with 95 RELATED_IMAGE vars
- **[example_cluster_info/rhoai-fbc/BUNDLE_STRUCTURE.md](./example_cluster_info/rhoai-fbc/BUNDLE_STRUCTURE.md)** - FBC structure explained
- **[example_cluster_info/rhoai-fbc/README.md](./example_cluster_info/rhoai-fbc/README.md)** - Bundle reference

---

## Quick Reference Commands

```bash
# Build everything
./build-custom-bundle.sh

# Deploy to cluster
./test-deployment.sh

# Clean up RHOAI
./full-cleanup-rhoai.sh

# Verify cleanup
./verify-cleanup.sh

# Check RELATED_IMAGE count
oc get deployment rhods-operator -n redhat-ods-operator -o json \
  | jq '[.spec.template.spec.containers[0].env[] | select(.name | startswith("RELATED_IMAGE"))] | length'
```

---

## Notes

- The custom operator uses production component images via RELATED_IMAGE variables
- AllNamespaces OperatorGroup mode is **required** (not optional)
- Bundle contains 95 RELATED_IMAGE variables (critical for component deployment)
- Catalog defines upgrade path: any 2.25.x → 3.3.0 via `skipRange: '>=2.25.0 <3.3.0'`
