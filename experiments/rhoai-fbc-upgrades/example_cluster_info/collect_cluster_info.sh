#!/bin/bash
#
# Minimal Bundle Collection Script
# Extracts RHOAI operator bundle data from a running cluster
#
# This script collects ONLY what's needed for the FBC build:
# - Bundle manifests (CSV + CRDs) from the installed operator
#
# Usage:
#   1. Have RHOAI operator installed on cluster
#   2. Run: ./collect_cluster_info.sh [version]
#   3. Creates: rhoai-fbc/bundles/<version>/ directory
#

set -e

VERSION="${1:-3.3.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="${SCRIPT_DIR}/rhoai-fbc"

echo "================================================================"
echo "RHOAI Bundle Extraction"
echo "================================================================"
echo "Version: $VERSION"
echo "Output:  ${OUTDIR}/bundles/${VERSION}/"
echo ""

# Check if operator is installed
if ! oc get csv -n redhat-ods-operator | grep -q "rhods-operator"; then
    echo "ERROR: RHOAI operator not found in redhat-ods-operator namespace"
    echo "Please install the operator first."
    exit 1
fi

CSV_NAME=$(oc get csv -n redhat-ods-operator -o name | grep rhods-operator | head -1)
echo "Found CSV: $CSV_NAME"
echo ""

# Create output directory structure
BUNDLE_DIR="${OUTDIR}/bundles/${VERSION}"
mkdir -p "${BUNDLE_DIR}/manifests"
mkdir -p "${BUNDLE_DIR}/metadata"

echo "Collecting bundle manifests..."

# Extract CSV
echo "  - ClusterServiceVersion"
oc get "$CSV_NAME" -n redhat-ods-operator -o yaml > "${BUNDLE_DIR}/manifests/$(basename $CSV_NAME).yaml"

# Extract all CRDs that the operator owns
echo "  - CustomResourceDefinitions"
CRD_COUNT=0
oc get csv "$CSV_NAME" -n redhat-ods-operator -o json | \
    jq -r '.spec.customresourcedefinitions.owned[]?.name' | \
    while read crd; do
        if [ -n "$crd" ]; then
            echo "    • $crd"
            oc get crd "$crd" -o yaml > "${BUNDLE_DIR}/manifests/${crd}.yaml"
            ((CRD_COUNT++))
        fi
    done

# Create metadata/annotations.yaml
echo "  - Bundle metadata"
cat > "${BUNDLE_DIR}/metadata/annotations.yaml" << EOF
annotations:
  operators.operatorframework.io.bundle.channels.v1: stable
  operators.operatorframework.io.bundle.channel.default.v1: stable
  operators.operatorframework.io.bundle.manifests.v1: manifests/
  operators.operatorframework.io.bundle.mediatype.v1: registry+v1
  operators.operatorframework.io.bundle.metadata.v1: metadata/
  operators.operatorframework.io.bundle.package.v1: rhods-operator
EOF

# Create bundle.Dockerfile
echo "  - Bundle Dockerfile"
cat > "${BUNDLE_DIR}/bundle.Dockerfile" << 'EOF'
FROM scratch
COPY manifests /manifests/
COPY metadata /metadata/
LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=rhods-operator
LABEL operators.operatorframework.io.bundle.channels.v1=stable
LABEL operators.operatorframework.io.bundle.channel.default.v1=stable
EOF

# Count files
MANIFEST_COUNT=$(ls -1 "${BUNDLE_DIR}/manifests/" | wc -l)

echo ""
echo "================================================================"
echo "Collection Complete!"
echo "================================================================"
echo "Bundle location: ${BUNDLE_DIR}"
echo "Manifests:       $MANIFEST_COUNT files (1 CSV + CRDs)"
echo ""
echo "Bundle structure:"
tree -L 2 "${BUNDLE_DIR}" 2>/dev/null || find "${BUNDLE_DIR}" -type f | sed 's|^|  |'
echo ""
echo "To use this bundle:"
echo "  1. Review manifests: ls -la ${BUNDLE_DIR}/manifests/"
echo "  2. Build with: ./build-custom-bundle.sh"
echo ""

# Create README
cat > "${OUTDIR}/README.md" << 'EOFREADME'
# RHOAI FBC Bundle Data

This directory contains cluster-extracted RHOAI operator bundle data used for building custom FBC catalogs.

## Directory Structure

```
rhoai-fbc/
└── bundles/
    └── 3.3.0/  (or your version)
        ├── manifests/
        │   ├── rhods-operator.clusterserviceversion.yaml  (1 CSV)
        │   └── *.opendatahub.io.yaml                      (37 CRDs)
        ├── metadata/
        │   └── annotations.yaml
        └── bundle.Dockerfile
```

## What's Included

**CSV (ClusterServiceVersion):**
- Operator deployment configuration
- 95 RELATED_IMAGE environment variables (critical!)
- Permissions, RBAC, owned CRDs

**CRDs (CustomResourceDefinitions):**
- All 37+ CRDs that the operator manages
- DataScienceCluster, DSCInitialization, Dashboard, etc.
- Full OpenAPI schemas

## Why This Data?

The production bundle contains data not available in source code:
- **95 RELATED_IMAGE variables** - Tell operator which component images to deploy
- **SHA-pinned image references** - Production-verified component images
- **Complete CRD set** - Source-generated bundles missing 11 CRDs
- **Clean manifests** - No runtime metadata (resourceVersion, uid, etc.)

## How to Collect

Run the collection script on a cluster with RHOAI installed:

```bash
./collect_cluster_info.sh [version]
```

This will extract the bundle from the running operator.

## How to Use

The `build-custom-bundle.sh` script uses this bundle data:
1. Copies bundle manifests
2. Cleans runtime metadata (resourceVersion, uid, etc.)
3. Patches CSV to use custom operator image
4. Preserves all 95 RELATED_IMAGE variables
5. Builds bundle and catalog images

## Notes

- Bundle data is extracted from production cluster
- RELATED_IMAGE variables point to Red Hat registry
- Operator image can be patched to custom build
- Runtime metadata must be cleaned before deployment
EOFREADME

echo "Created: ${OUTDIR}/README.md"
echo ""
