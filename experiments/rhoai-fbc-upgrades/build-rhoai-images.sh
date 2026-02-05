#!/bin/bash
#
# RHOAI Operator Build Script
#
# Builds operator image, bundle image, and FBC catalog image from source
# and pushes them to registry.tannerjc.net/rhoai-upgrade/*
#
# Source: ./src/red-hat-data-services/rhods-operator.3.3
# Registry: registry.tannerjc.net/rhoai-upgrade/* (no credentials required)
#

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/src/red-hat-data-services/rhods-operator.3.3"
REGISTRY="registry.tannerjc.net"
REGISTRY_ORG="rhoai-upgrade"
VERSION="3.3.0"

# Image names
OPERATOR_IMG="${REGISTRY}/${REGISTRY_ORG}/rhods-operator:${VERSION}"
BUNDLE_IMG="${REGISTRY}/${REGISTRY_ORG}/rhods-operator-bundle:v${VERSION}"
CATALOG_IMG="${REGISTRY}/${REGISTRY_ORG}/rhods-operator-catalog:v${VERSION}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory not found: $SOURCE_DIR"
    exit 1
fi

log_info "RHOAI Operator Build Script"
log_info "============================"
log_info ""
log_info "Configuration:"
log_info "  Source:        $SOURCE_DIR"
log_info "  Version:       $VERSION"
log_info "  Registry:      $REGISTRY"
log_info "  Organization:  $REGISTRY_ORG"
log_info ""
log_info "Images to build:"
log_info "  Operator:      $OPERATOR_IMG"
log_info "  Bundle:        $BUNDLE_IMG"
log_info "  Catalog:       $CATALOG_IMG"
log_info ""

# Change to source directory
cd "$SOURCE_DIR"
log_info "Changed to: $(pwd)"
log_info ""

# Test registry access
log_info "Testing registry access..."
if podman login "$REGISTRY" --get-login >/dev/null 2>&1 || [ $? -eq 0 ]; then
    log_success "Registry is accessible"
else
    log_warn "Not logged into registry (should be fine if no credentials required)"
fi
log_info ""

# Step 1: Build operator image
log_info "============================"
log_info "Step 1: Building operator image"
log_info "============================"
log_info "Command: make image-build ODH_PLATFORM_TYPE=RHOAI VERSION=$VERSION IMG=$OPERATOR_IMG"
log_info ""

if make image-build \
    ODH_PLATFORM_TYPE=RHOAI \
    VERSION="$VERSION" \
    IMG="$OPERATOR_IMG" \
    IMAGE_BUILDER=podman; then
    log_success "Operator image built: $OPERATOR_IMG"
else
    log_error "Failed to build operator image"
    exit 1
fi
log_info ""

# Step 2: Push operator image
log_info "Pushing operator image..."
if podman push "$OPERATOR_IMG"; then
    log_success "Operator image pushed: $OPERATOR_IMG"
else
    log_error "Failed to push operator image"
    exit 1
fi
log_info ""

# Step 3: Build bundle
log_info "============================"
log_info "Step 2: Generating and building bundle"
log_info "============================"
log_info "Command: make bundle-build ODH_PLATFORM_TYPE=RHOAI VERSION=$VERSION IMG=$OPERATOR_IMG BUNDLE_IMG=$BUNDLE_IMG"
log_info ""

if make bundle-build \
    ODH_PLATFORM_TYPE=RHOAI \
    VERSION="$VERSION" \
    IMG="$OPERATOR_IMG" \
    BUNDLE_IMG="$BUNDLE_IMG" \
    IMAGE_BUILDER=podman; then
    log_success "Bundle built: $BUNDLE_IMG"
else
    log_error "Failed to build bundle"
    exit 1
fi
log_info ""

# Step 4: Push bundle image
log_info "Pushing bundle image..."
if podman push "$BUNDLE_IMG"; then
    log_success "Bundle image pushed: $BUNDLE_IMG"
else
    log_error "Failed to push bundle image"
    exit 1
fi
log_info ""

# Step 5: Build catalog (FBC)
log_info "============================"
log_info "Step 3: Building catalog (FBC)"
log_info "============================"

# Fix package name in catalog template for RHOAI
log_info "Fixing package name in catalog template for RHOAI..."
if [ -f "config/catalog/fbc-basic-template.yaml" ]; then
    sed -i 's/name: opendatahub-operator/name: rhods-operator/g' config/catalog/fbc-basic-template.yaml
    sed -i 's/package: opendatahub-operator/package: rhods-operator/g' config/catalog/fbc-basic-template.yaml
    log_success "Catalog template fixed"
fi

# Also fix update-catalog-template.sh script
if [ -f "hack/update-catalog-template.sh" ]; then
    sed -i 's/package_name="opendatahub-operator"/package_name="rhods-operator"/g' hack/update-catalog-template.sh
    log_success "Catalog script fixed"
fi

log_info "Command: make catalog-build ODH_PLATFORM_TYPE=RHOAI VERSION=$VERSION BUNDLE_IMG=$BUNDLE_IMG CATALOG_IMG=$CATALOG_IMG"
log_info ""

if make catalog-build \
    ODH_PLATFORM_TYPE=RHOAI \
    VERSION="$VERSION" \
    BUNDLE_IMG="$BUNDLE_IMG" \
    BUNDLE_IMGS="$BUNDLE_IMG" \
    CATALOG_IMG="$CATALOG_IMG" \
    IMAGE_BUILDER=podman; then
    log_success "Catalog built: $CATALOG_IMG"
else
    log_error "Failed to build catalog"
    exit 1
fi
log_info ""

# Step 6: Push catalog image
log_info "Pushing catalog image..."
if podman push "$CATALOG_IMG"; then
    log_success "Catalog image pushed: $CATALOG_IMG"
else
    log_error "Failed to push catalog image"
    exit 1
fi
log_info ""

# Summary
log_success "============================"
log_success "BUILD COMPLETE!"
log_success "============================"
log_info ""
log_info "Images pushed to $REGISTRY/$REGISTRY_ORG:"
log_info ""
log_info "  Operator Image:"
log_info "    $OPERATOR_IMG"
log_info ""
log_info "  Bundle Image:"
log_info "    $BUNDLE_IMG"
log_info ""
log_info "  Catalog Image:"
log_info "    $CATALOG_IMG"
log_info ""
log_info "Next Steps:"
log_info "----------"
log_info ""
log_info "1. Create a CatalogSource:"
log_info ""
cat << EOF
cat <<YAML | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhoai-custom-catalog
  namespace: openshift-marketplace
spec:
  displayName: RHOAI Custom Catalog
  sourceType: grpc
  image: ${CATALOG_IMG}
  publisher: Custom Build
  updateStrategy:
    registryPoll:
      interval: 10m
YAML
EOF
log_info ""
log_info "2. Create a Subscription to install the operator:"
log_info ""
cat << EOF
cat <<YAML | oc apply -f -
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
  installPlanApproval: Manual
YAML
EOF
log_info ""
log_success "Build script completed successfully!"
log_info ""

# Save manifest generation info
MANIFEST_INFO="${SCRIPT_DIR}/build-manifest-info.txt"
cat > "$MANIFEST_INFO" << EOF
RHOAI Operator Build Information
Generated: $(date)

Source Directory: $SOURCE_DIR
Version: $VERSION

Images Built:
  Operator: $OPERATOR_IMG
  Bundle:   $BUNDLE_IMG
  Catalog:  $CATALOG_IMG

Build Commands:
  make image-build ODH_PLATFORM_TYPE=RHOAI VERSION=$VERSION IMG=$OPERATOR_IMG
  make bundle-build ODH_PLATFORM_TYPE=RHOAI VERSION=$VERSION IMG=$OPERATOR_IMG BUNDLE_IMG=$BUNDLE_IMG
  make catalog-build ODH_PLATFORM_TYPE=RHOAI VERSION=$VERSION BUNDLE_IMG=$BUNDLE_IMG CATALOG_IMG=$CATALOG_IMG

Generated Bundle Directory:
  $(pwd)/rhoai-bundle/

Generated Catalog Directory:
  $(pwd)/catalog/
EOF

log_info "Build information saved to: $MANIFEST_INFO"
