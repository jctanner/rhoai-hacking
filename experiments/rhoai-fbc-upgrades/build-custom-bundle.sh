#!/bin/bash
#
# Build RHOAI Bundle with Custom Operator Image
#
# Uses cluster-extracted bundle (with RELATED_IMAGE vars) but patches
# the operator image to use your custom-built operator.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_SOURCE="${SCRIPT_DIR}/example_cluster_info/rhoai-fbc/bundles/3.3.0"
REGISTRY="registry.tannerjc.net"
REGISTRY_ORG="rhoai-upgrade"
VERSION="3.3.0"

OPERATOR_IMG="${REGISTRY}/${REGISTRY_ORG}/rhods-operator:${VERSION}"
BUNDLE_IMG="${REGISTRY}/${REGISTRY_ORG}/rhods-operator-bundle:v${VERSION}"
CATALOG_IMG="${REGISTRY}/${REGISTRY_ORG}/rhods-operator-catalog:v${VERSION}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Building custom RHOAI bundle"
log_info "============================"
log_info ""
log_info "Source bundle:   $BUNDLE_SOURCE"
log_info "Operator image:  $OPERATOR_IMG"
log_info "Bundle image:    $BUNDLE_IMG"
log_info "Catalog image:   $CATALOG_IMG"
log_info ""

# Create temporary directory for patched bundle
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

log_info "Creating patched bundle in: $WORK_DIR"

# Copy bundle structure
cp -r "$BUNDLE_SOURCE"/* "$WORK_DIR/"

# Find CSV file
CSV_FILE=$(ls "$WORK_DIR"/manifests/*.clusterserviceversion.yaml)
log_info "Patching CSV: $(basename $CSV_FILE)"

# Clean runtime metadata from CSV (resourceVersion, uid, etc.)
log_info "Cleaning runtime metadata from CSV..."
yq eval -i '
  del(.metadata.resourceVersion) |
  del(.metadata.uid) |
  del(.metadata.generation) |
  del(.metadata.creationTimestamp) |
  del(.metadata.managedFields) |
  del(.metadata.selfLink) |
  del(.status)
' "$CSV_FILE"

# Patch operator image in CSV
log_info "Replacing operator image with: $OPERATOR_IMG"
yq eval -i "
  .metadata.annotations.containerImage = \"$OPERATOR_IMG\" |
  .spec.install.spec.deployments[0].spec.template.spec.containers[0].image = \"$OPERATOR_IMG\"
" "$CSV_FILE"

# Clean CRDs too
log_info "Cleaning runtime metadata from CRDs..."
for crd in "$WORK_DIR"/manifests/*.yaml; do
    if [ "$crd" != "$CSV_FILE" ]; then
        yq eval -i '
          del(.metadata.resourceVersion) |
          del(.metadata.uid) |
          del(.metadata.generation) |
          del(.metadata.creationTimestamp) |
          del(.metadata.managedFields) |
          del(.metadata.selfLink) |
          del(.status)
        ' "$crd" 2>/dev/null || true
    fi
done

# Show what we patched
OLD_IMG=$(grep "registry.redhat.io/rhoai/odh-rhel9-operator" "$BUNDLE_SOURCE"/manifests/*.clusterserviceversion.yaml | head -1 | awk '{print $2}')
log_success "Patched operator image:"
log_info "  Old: $OLD_IMG"
log_info "  New: $OPERATOR_IMG"
log_info ""

# Count RELATED_IMAGE vars
RELATED_COUNT=$(grep -c "RELATED_IMAGE" "$CSV_FILE" || echo 0)
log_info "RELATED_IMAGE variables preserved: $RELATED_COUNT"
log_info ""

# Step 1: Build bundle image
log_info "Building bundle image..."
cd "$WORK_DIR"

cat > bundle.Dockerfile << 'EOF'
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

podman build -f bundle.Dockerfile -t "$BUNDLE_IMG" .
log_success "Bundle image built: $BUNDLE_IMG"

podman push "$BUNDLE_IMG"
log_success "Bundle image pushed"

# Step 2: Build catalog
log_info ""
log_info "Building catalog..."
cd "$SCRIPT_DIR"

mkdir -p catalog-build
cat > catalog-build/catalog.yaml << EOF
---
defaultChannel: stable
name: rhods-operator
schema: olm.package
---
schema: olm.channel
package: rhods-operator
name: stable
entries:
  - name: rhods-operator.v${VERSION}
    replaces: rhods-operator.2.25.2
    skipRange: '>=2.25.0 <3.3.0'
---
schema: olm.bundle
name: rhods-operator.v${VERSION}
package: rhods-operator
image: ${BUNDLE_IMG}
properties:
  - type: olm.package
    value:
      packageName: rhods-operator
      version: ${VERSION}
EOF

cat > catalog-build/catalog.Dockerfile << 'EOF'
FROM quay.io/operator-framework/opm:latest as builder
ADD catalog.yaml /configs/rhods-operator/catalog.yaml
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]

FROM quay.io/operator-framework/opm:latest
ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]
COPY --from=builder /configs /configs
COPY --from=builder /tmp/cache /tmp/cache
LABEL operators.operatorframework.io.index.configs.v1=/configs
EOF

cd catalog-build
podman build -f catalog.Dockerfile -t "$CATALOG_IMG" .
log_success "Catalog image built: $CATALOG_IMG"

podman push "$CATALOG_IMG"
log_success "Catalog image pushed"

log_info ""
log_success "============================"
log_success "BUILD COMPLETE!"
log_success "============================"
log_info ""
log_info "Images built and pushed:"
log_info "  Operator: $OPERATOR_IMG (built earlier)"
log_info "  Bundle:   $BUNDLE_IMG (with $RELATED_COUNT RELATED_IMAGE vars)"
log_info "  Catalog:  $CATALOG_IMG"
log_info ""
log_info "The bundle uses:"
log_info "  ✓ Your custom operator image"
log_info "  ✓ All $RELATED_COUNT RELATED_IMAGE variables from cluster"
log_info "  ✓ All CRDs and manifests from production"
log_info ""
log_warn "Note: The RELATED_IMAGE variables still point to Red Hat registry."
log_warn "The operator will pull those images. If you need disconnected install,"
log_warn "you'll need to mirror those images and update the RELATED_IMAGE vars."
