#!/bin/bash
set -e

# Configuration
VERSION="3.0.0"
REGISTRY="registry.tannerjc.net/opendatahub"
OPERATOR_IMG="${REGISTRY}/opendatahub-operator:v${VERSION}"
BUNDLE_IMG="${REGISTRY}/opendatahub-operator-bundle:v${VERSION}"
PLATFORM="linux/amd64"
BUILD_ENV="olm-build-env:go1.25"
WORKSPACE="$(pwd)/src/opendatahub-io/opendatahub-operator.main"

# Set up logging
LOG_FILE="$(pwd)/build-v${VERSION}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

# Helper function to print timestamped messages
log_step() {
  echo ""
  echo "=========================================="
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "=========================================="
}

log_info() {
  echo "[$(date '+%H:%M:%S')] $1"
}

log_step "Building and Pushing v${VERSION}"
log_info "Operator Image: ${OPERATOR_IMG}"
log_info "Bundle Image:   ${BUNDLE_IMG}"
log_info "Platform:       ${PLATFORM}"
log_info "Workspace:      ${WORKSPACE}"
log_info "Build Env:      ${BUILD_ENV} (Go 1.25)"
log_info "Log File:       ${LOG_FILE}"

cd "${WORKSPACE}"

# Step 0: Reset and apply patches
echo ""
echo "Step 0/7: Resetting source and applying patches..."
git reset --hard HEAD
git clean -fd

# Apply upgrade fixes patch
log_info "Applying main-upgrade-fixes.patch..."
git apply ../../../patches/main-upgrade-fixes.patch

log_info "✓ Patches applied"

# Step 1: Fetch component manifests
echo ""
echo "Step 1/7: Fetching component manifests..."
log_info "Main branch uses commit hashes in get_all_manifests.sh"
log_info "Starting manifest fetch (this may take a few minutes)..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "./get_all_manifests.sh"

log_info "✓ Manifests fetched"
log_info "Checking what was fetched for dashboard..."
if [ -f "opt/manifests/dashboard/odh/params.env" ]; then
  log_info "  dashboard/odh/params.env exists:"
  grep "odh-dashboard" opt/manifests/dashboard/odh/params.env | sed 's/^/    /'
else
  log_info "  Note: dashboard/odh/params.env not found (may use different structure in main)"
fi

# Step 2: Patch Dockerfile to force using local manifests
echo ""
echo "Step 2/7: Patching Dockerfile to force local manifests..."
log_info "Before patching:"
grep "ARG USE_LOCAL" Dockerfiles/Dockerfile || log_info "  (USE_LOCAL not found)"

cp Dockerfiles/Dockerfile Dockerfiles/Dockerfile.orig
sed -i 's|ARG USE_LOCAL=false|ARG USE_LOCAL=true|g' Dockerfiles/Dockerfile

log_info "After patching:"
grep "ARG USE_LOCAL" Dockerfiles/Dockerfile || log_info "  (USE_LOCAL not found)"

if grep -q "ARG USE_LOCAL=true" Dockerfiles/Dockerfile; then
  log_info "✓ Dockerfile patched to default USE_LOCAL=true"
else
  log_info "✗ ERROR: Dockerfile patch failed!"
  exit 1
fi

# Step 3: Build and push OpenDataHub operator image
echo ""
echo "Step 3/7: Building and pushing OpenDataHub operator image..."
log_info "Using pre-fetched manifests from opt/manifests..."
log_info "Platform type: OpenDataHub (not RHOAI)"

log_info "Verifying Dockerfile and manifests inside build container..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  ${BUILD_ENV} \
  bash -c "echo '  Dockerfile USE_LOCAL setting:' && grep 'ARG USE_LOCAL' Dockerfiles/Dockerfile && echo '  Dashboard manifest in workspace:' && grep 'odh-dashboard' opt/manifests/dashboard/odh/params.env 2>/dev/null || echo '  (dashboard params.env structure may differ in main branch)'"

log_info "Starting podman build inside BUILD_ENV (with --privileged for SELinux)..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "podman buildx build --no-cache -f Dockerfiles/Dockerfile --build-arg CGO_ENABLED=1 --platform ${PLATFORM} -t ${OPERATOR_IMG} . && podman push ${OPERATOR_IMG}"

log_info "✓ Build and push completed"

# Restore original Dockerfile
mv Dockerfiles/Dockerfile.orig Dockerfiles/Dockerfile
log_info "✓ Dockerfile restored"

# Step 4: Generate bundle manifests
echo ""
echo "Step 4/7: Generating bundle manifests..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "export REGISTRY=${REGISTRY} && make bundle VERSION=${VERSION} IMG=${OPERATOR_IMG} BUNDLE_IMG=${BUNDLE_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=OpenDataHub"

# Step 5: Patch generated bundle CSV for OpenDataHub
echo ""
echo "Step 5/7: Patching generated bundle CSV for OpenDataHub..."

# Main branch generates odh-bundle and rhoai-bundle - we use odh-bundle
CSV_FILE="odh-bundle/manifests/opendatahub-operator.clusterserviceversion.yaml"

if [ ! -f "${CSV_FILE}" ]; then
  log_info "✗ ERROR: ${CSV_FILE} not found!"
  log_info "Looking for CSV files..."
  find . -name "*.clusterserviceversion.yaml" -type f | head -5
  exit 1
fi

log_info "Found CSV at: ${CSV_FILE}"

# Add replaces field if it doesn't exist
if ! grep -q "replaces:" ${CSV_FILE}; then
  log_info "Adding replaces field..."
  # Add after the "name:" line in metadata section
  sed -i "/^  name: opendatahub-operator.v${VERSION}/a\  replaces: opendatahub-operator.v2.25.0" ${CSV_FILE}
else
  log_info "Updating existing replaces field..."
  sed -i 's|replaces: .*|replaces: opendatahub-operator.v2.25.0|g' ${CSV_FILE}
fi

# Fix container images
log_info "Fixing container image references..."
sed -i "s|containerImage: quay.io/opendatahub/opendatahub-operator:.*|containerImage: ${REGISTRY}/opendatahub-operator:v${VERSION}|g" ${CSV_FILE}
sed -i "s|image: REPLACE_IMAGE:latest|image: ${REGISTRY}/opendatahub-operator:v${VERSION}|g" ${CSV_FILE}

log_info "✓ Bundle CSV verified and patched"

# Step 6: Build and push bundle image
echo ""
echo "Step 6/7: Building and pushing bundle image..."

# Main branch uses odh-bundle directory and Dockerfiles/bundle.Dockerfile
BUNDLE_DOCKERFILE="Dockerfiles/bundle.Dockerfile"
BUNDLE_DIR="odh-bundle"

if [ ! -f "${BUNDLE_DOCKERFILE}" ]; then
  log_info "✗ ERROR: ${BUNDLE_DOCKERFILE} not found!"
  exit 1
fi

if [ ! -d "${BUNDLE_DIR}" ]; then
  log_info "✗ ERROR: ${BUNDLE_DIR} directory not found!"
  exit 1
fi

log_info "Using bundle directory: ${BUNDLE_DIR}"
log_info "Using Dockerfile: ${BUNDLE_DOCKERFILE}"

# Build and push using the odh-bundle
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "podman build --no-cache -f ${BUNDLE_DOCKERFILE} -t ${BUNDLE_IMG} . && podman push ${BUNDLE_IMG}"

log_info "✓ Bundle image built and pushed"

# Step 7: Verify all patches applied correctly
echo ""
echo "Step 7/7: Final verification of all patches..."

ERRORS=0
CSV_FILE="odh-bundle/manifests/opendatahub-operator.clusterserviceversion.yaml"

# Check CSV patches
log_info "Checking bundle CSV patches..."
if ! grep -q "${REGISTRY}/opendatahub-operator:v${VERSION}" ${CSV_FILE}; then
  log_info "  ✗ ERROR: CSV does not contain correct operator image"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q "name: opendatahub-operator.v${VERSION}" ${CSV_FILE}; then
  log_info "  ✗ ERROR: CSV name is not opendatahub-operator.v${VERSION}"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q 'displayName: Open Data Hub' ${CSV_FILE}; then
  log_info "  ✗ ERROR: CSV displayName is not 'Open Data Hub'"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q "replaces: opendatahub-operator.v2.25.0" ${CSV_FILE}; then
  log_info "  ✗ ERROR: CSV replaces field should be opendatahub-operator.v2.25.0"
  ERRORS=$((ERRORS + 1))
fi

# Check upgrade fixes
if grep -q "IsNoMatchError" pkg/upgrade/upgrade_utils.go; then
  log_info "  ✓ OdhDashboardConfig error handling fixed"
else
  log_info "  ✗ WARNING: OdhDashboardConfig fix may not be applied"
  ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -eq 0 ]; then
  log_info "✓ Bundle CSV correctly configured"
  log_info "  - Image: opendatahub-operator:v${VERSION}"
  log_info "  - CSV name: opendatahub-operator.v${VERSION}"
  log_info "  - Replaces: opendatahub-operator.v2.25.0"
  log_info "  - Display name: Open Data Hub"
else
  echo ""
  log_info "✗ CRITICAL: Found $ERRORS error(s) in bundle CSV!"
  log_info "Current CSV settings:"
  grep -E "name: |replaces:|containerImage|displayName: " ${CSV_FILE} | head -10
  exit 1
fi

echo ""
log_info "Verifying images in registry..."
podman pull ${OPERATOR_IMG} >/dev/null 2>&1 && log_info "  ✓ Operator image available: ${OPERATOR_IMG}" || log_info "  ✗ Operator image not found"
podman pull ${BUNDLE_IMG} >/dev/null 2>&1 && log_info "  ✓ Bundle image available: ${BUNDLE_IMG}" || log_info "  ✗ Bundle image not found"

echo ""
log_step "Build and push complete!"
log_info "Operator Image: ${OPERATOR_IMG}"
log_info "Bundle Image:   ${BUNDLE_IMG}"
echo ""
echo "To upgrade from v2.25.0 to v3.0.0:"
echo "  ./scripts/upgrade-to-v3.0.0.sh"
echo ""
echo "Or manually:"
echo "  operator-sdk run bundle-upgrade ${BUNDLE_IMG} --namespace opendatahub-operator-system --timeout 10m"
echo ""
