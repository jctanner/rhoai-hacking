#!/bin/bash
#
# Build RHOAI Images from Extracted Cluster Bundle
#
# Uses the bundle data extracted from the production cluster which includes
# all RELATED_IMAGE variables and proper configurations.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_SOURCE="${SCRIPT_DIR}/example_cluster_info/rhoai-fbc/bundles/3.3.0"
REGISTRY="registry.tannerjc.net"
REGISTRY_ORG="rhoai-upgrade"
VERSION="3.3.0"

BUNDLE_IMG="${REGISTRY}/${REGISTRY_ORG}/rhods-operator-bundle:v${VERSION}"
CATALOG_IMG="${REGISTRY}/${REGISTRY_ORG}/rhods-operator-catalog:v${VERSION}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

log_info "Building from extracted cluster bundle"
log_info "Source: $BUNDLE_SOURCE"
log_info ""

# Step 1: Build bundle image from extracted data
log_info "Building bundle image from cluster-extracted data..."
cd "$BUNDLE_SOURCE"

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
log_success "Build complete!"
log_info ""
log_info "Images:"
log_info "  Bundle:  $BUNDLE_IMG"
log_info "  Catalog: $CATALOG_IMG"
log_info ""
log_info "RELATED_IMAGE count: $(grep -c RELATED_IMAGE $BUNDLE_SOURCE/manifests/*.clusterserviceversion.yaml)"
