#!/bin/bash
set -e

# Configuration
VERSION="2.25.0"
REGISTRY="registry.tannerjc.net/opendatahub"
OPERATOR_IMG="${REGISTRY}/opendatahub-operator:v${VERSION}"
BUNDLE_IMG="${REGISTRY}/opendatahub-operator-bundle:v${VERSION}"
PLATFORM="linux/amd64"
BUILD_ENV="olm-build-env:go1.24"
WORKSPACE="$(pwd)/src/opendatahub-io/opendatahub-operator.stable-2.x"

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
log_info "Build Env:      ${BUILD_ENV} (Go 1.24)"
log_info "Log File:       ${LOG_FILE}"

cd "${WORKSPACE}"

# Step 0: Reset source
echo ""
echo "Step 0/9: Resetting source..."
git reset --hard HEAD
git clean -fd

echo "  ✓ Source reset"

# Step 1: Patch get_all_manifests.sh to use OpenDataHub repos
echo ""
echo "Step 1/9: Patching get_all_manifests.sh for OpenDataHub repos..."

# Backup original
cp get_all_manifests.sh get_all_manifests.sh.orig

# Replace red-hat-data-services with opendatahub-io
sed -i 's|red-hat-data-services:|opendatahub-io:|g' get_all_manifests.sh

# Replace rhoai-2.25 branches with stable-2.x
sed -i 's|:rhoai-2.25:|:stable-2.x:|g' get_all_manifests.sh

# Special cases: Some repos were listed as :main but should use stable-2.x
# notebooks and kserve need to use stable-2.x branch
sed -i 's|opendatahub-io:notebooks:main:|opendatahub-io:notebooks:stable-2.x:|g' get_all_manifests.sh
sed -i 's|opendatahub-io:kserve:main:|opendatahub-io:kserve:stable-2.x:|g' get_all_manifests.sh

echo "  ✓ get_all_manifests.sh patched for OpenDataHub"

# Step 2: Fetch manifests
echo ""
echo "Step 2/9: Fetching component manifests..."
echo "  Using patched get_all_manifests.sh (should fetch from opendatahub-io)..."
echo "  Key repos being fetched:"
grep "^\[" get_all_manifests.sh | head -5

echo ""
echo "  Starting manifest fetch (this may take a few minutes)..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "./get_all_manifests.sh"

# Restore original script
mv get_all_manifests.sh.orig get_all_manifests.sh

echo "  ✓ Manifests fetched from OpenDataHub repos"
echo "  Checking what was fetched for dashboard..."
if [ -f "opt/manifests/dashboard/odh/params.env" ]; then
  echo "    dashboard/odh/params.env exists:"
  grep "odh-dashboard" opt/manifests/dashboard/odh/params.env | sed 's/^/      /'
else
  echo "    ✗ ERROR: dashboard/odh/params.env not found!"
  exit 1
fi

# Step 3: Patch dashboard manifests
echo ""
echo "Step 3/9: Patching dashboard manifests..."
if [ -d "opt/manifests/dashboard" ]; then
  echo "  Searching for params.env files..."
  find opt/manifests/dashboard -name "params.env" -print

  echo "  Before patching:"
  grep -r "odh-dashboard" opt/manifests/dashboard/ | grep -v Binary || echo "    (no matches)"

  find opt/manifests/dashboard -name "params.env" -exec sed -i 's|odh-dashboard:main|odh-dashboard:v2.25.2-odh|g' {} \;
  echo "  ✓ Dashboard image tag updated to v2.25.2-odh"

  echo "  After patching:"
  grep -r "odh-dashboard" opt/manifests/dashboard/ | grep -v Binary || echo "    (no matches)"

  # Verify the patch was applied
  echo "  Verifying dashboard manifest patches..."
  if grep -r "odh-dashboard:main" opt/manifests/dashboard/ >/dev/null 2>&1; then
    echo "  ✗ ERROR: Found odh-dashboard:main in dashboard manifests - patching failed!"
    grep -r "odh-dashboard:main" opt/manifests/dashboard/
    exit 1
  fi

  if ! grep -r "odh-dashboard:v2.25.2-odh" opt/manifests/dashboard/ >/dev/null 2>&1; then
    echo "  ✗ ERROR: Could not find odh-dashboard:v2.25.2-odh in dashboard manifests!"
    exit 1
  fi

  echo "  ✓ Verified: Dashboard manifests contain v2.25.2-odh"
else
  echo "  ✗ ERROR: opt/manifests/dashboard not found - cannot continue!"
  exit 1
fi

# Step 4: Patch Dockerfile to force using local manifests
echo ""
echo "Step 4/9: Patching Dockerfile to force local manifests..."
echo "  Before patching:"
grep "ARG USE_LOCAL" Dockerfiles/Dockerfile || echo "    (USE_LOCAL not found)"

cp Dockerfiles/Dockerfile Dockerfiles/Dockerfile.orig
sed -i 's|ARG USE_LOCAL=false|ARG USE_LOCAL=true|g' Dockerfiles/Dockerfile

echo "  After patching:"
grep "ARG USE_LOCAL" Dockerfiles/Dockerfile || echo "    (USE_LOCAL not found)"

if grep -q "ARG USE_LOCAL=true" Dockerfiles/Dockerfile; then
  echo "  ✓ Dockerfile patched to default USE_LOCAL=true"
else
  echo "  ✗ ERROR: Dockerfile patch failed!"
  echo "  Dockerfile content around USE_LOCAL:"
  grep -A2 -B2 "USE_LOCAL" Dockerfiles/Dockerfile || echo "    (not found)"
  exit 1
fi

# Step 5: Build and push operator image with patched manifests
echo ""
echo "Step 5/9: Building and pushing operator image..."
echo "  Using pre-patched manifests from opt/manifests..."
echo "  Current dashboard manifest state:"
find opt/manifests/dashboard -name "params.env" -exec echo "    {}" \; -exec grep "odh-dashboard" {} \;

echo ""
echo "  Starting podman build directly on host (not in nested container)..."
podman buildx build --no-cache -f Dockerfiles/Dockerfile --build-arg CGO_ENABLED=1 --platform ${PLATFORM} -t ${OPERATOR_IMG} .

echo ""
echo "  Pushing operator image..."
podman push ${OPERATOR_IMG}

echo "  ✓ Build and push completed"

# Restore original Dockerfile
mv Dockerfiles/Dockerfile.orig Dockerfiles/Dockerfile
echo "  ✓ Dockerfile restored"

# Verify dashboard manifests in the built image
echo ""
echo "  Verifying dashboard manifests in operator image..."
TEMP_CONTAINER=$(podman create ${OPERATOR_IMG})

echo "  Extracting and checking all dashboard params.env files from image..."
for params_file in opt/manifests/dashboard/odh/params.env opt/manifests/dashboard/rhoai/onprem/params.env opt/manifests/dashboard/rhoai/addon/params.env; do
  echo "    Checking: ${params_file}"
  CONTENT=$(podman export ${TEMP_CONTAINER} | tar -xOf - ${params_file} 2>/dev/null || echo "FILE_NOT_FOUND")
  if [ "$CONTENT" = "FILE_NOT_FOUND" ]; then
    echo "      (file not found in image)"
  else
    echo "      Content:"
    echo "$CONTENT" | grep "odh-dashboard" | sed 's/^/        /'
  fi
done

echo ""
echo "  Checking for problematic :main tag..."
if podman export ${TEMP_CONTAINER} | tar -xOf - opt/manifests/dashboard/odh/params.env 2>/dev/null | grep -q "odh-dashboard:main"; then
  echo "  ✗ ERROR: Operator image contains odh-dashboard:main - build failed!"
  echo "  Full params.env content:"
  podman export ${TEMP_CONTAINER} | tar -xOf - opt/manifests/dashboard/odh/params.env 2>/dev/null | sed 's/^/    /'
  podman rm ${TEMP_CONTAINER} >/dev/null 2>&1
  exit 1
fi

echo "  Checking for correct v2.25.2-odh tag..."
if podman export ${TEMP_CONTAINER} | tar -xOf - opt/manifests/dashboard/odh/params.env 2>/dev/null | grep -q "odh-dashboard:v2.25.2-odh"; then
  echo "  ✓ Verified: Operator image contains odh-dashboard:v2.25.2-odh"
else
  echo "  ✗ ERROR: Operator image does not contain odh-dashboard:v2.25.2-odh!"
  echo "  Full params.env content:"
  podman export ${TEMP_CONTAINER} | tar -xOf - opt/manifests/dashboard/odh/params.env 2>/dev/null | sed 's/^/    /'
  podman rm ${TEMP_CONTAINER} >/dev/null 2>&1
  exit 1
fi
podman rm ${TEMP_CONTAINER} >/dev/null 2>&1

# Step 6: Generate bundle manifests
echo ""
echo "Step 6/9: Generating bundle manifests..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "export REGISTRY=${REGISTRY} && make bundle VERSION=${VERSION} IMG=${OPERATOR_IMG} BUNDLE_IMG=${BUNDLE_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=OpenDataHub"

# Step 7: Patch generated bundle CSV for OpenDataHub
echo ""
echo "Step 7/9: Patching generated bundle CSV for OpenDataHub..."

# Change RHOAI namespaces to OpenDataHub
echo "  Updating namespaces..."
sed -i 's|"applicationsNamespace": "redhat-ods-applications"|"applicationsNamespace": "opendatahub"|g' bundle/manifests/rhods-operator.clusterserviceversion.yaml
sed -i 's|"namespace": "redhat-ods-monitoring"|"namespace": "opendatahub"|g' bundle/manifests/rhods-operator.clusterserviceversion.yaml

# Change CSV name from rhods-operator to opendatahub-operator
echo "  Updating CSV name..."
sed -i 's|name: rhods-operator.v2.25.0|name: opendatahub-operator.v2.25.0|g' bundle/manifests/rhods-operator.clusterserviceversion.yaml

# Change display name
echo "  Updating display name..."
sed -i 's|displayName: Red Hat OpenShift AI|displayName: Open Data Hub|g' bundle/manifests/rhods-operator.clusterserviceversion.yaml

# Fix container images (REPLACE_IMAGE placeholders)
echo "  Fixing container image references..."
sed -i "s|containerImage: REPLACE_IMAGE:latest|containerImage: ${REGISTRY}/opendatahub-operator:v${VERSION}|g" bundle/manifests/rhods-operator.clusterserviceversion.yaml
sed -i "s|image: REPLACE_IMAGE:latest|image: ${REGISTRY}/opendatahub-operator:v${VERSION}|g" bundle/manifests/rhods-operator.clusterserviceversion.yaml

# Change package name from rhods-operator to opendatahub-operator (for v3.0.0 upgrade compatibility)
echo "  Updating package name in bundle metadata..."
sed -i 's|operators.operatorframework.io.bundle.package.v1: rhods-operator|operators.operatorframework.io.bundle.package.v1: opendatahub-operator|g' bundle/metadata/annotations.yaml

echo "  ✓ Bundle CSV and metadata patched for OpenDataHub"

# Step 8: Build and push bundle image (stable-2.x uses bundle.Dockerfile, not rhoai-bundle.Dockerfile)
echo ""
echo "Step 8/9: Building and pushing bundle image..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "podman build --no-cache -f Dockerfiles/bundle.Dockerfile -t ${BUNDLE_IMG} . && podman push ${BUNDLE_IMG}"

# Step 9: Verify all patches applied correctly
echo ""
echo "Step 9/9: Final verification of all patches..."

ERRORS=0

# Check CSV patches
echo "  Checking bundle CSV patches..."
if ! grep -q "${REGISTRY}/opendatahub-operator:v${VERSION}" bundle/manifests/rhods-operator.clusterserviceversion.yaml; then
  echo "    ✗ ERROR: CSV does not contain correct operator image"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q "name: opendatahub-operator.v${VERSION}" bundle/manifests/rhods-operator.clusterserviceversion.yaml; then
  echo "    ✗ ERROR: CSV name is not opendatahub-operator.v${VERSION}"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q 'applicationsNamespace": "opendatahub"' bundle/manifests/rhods-operator.clusterserviceversion.yaml; then
  echo "    ✗ ERROR: CSV applicationsNamespace is not opendatahub"
  ERRORS=$((ERRORS + 1))
fi

if grep -q 'redhat-ods-applications\|redhat-ods-monitoring' bundle/manifests/rhods-operator.clusterserviceversion.yaml; then
  echo "    ✗ ERROR: CSV still contains redhat-ods-* namespaces"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q 'displayName: Open Data Hub' bundle/manifests/rhods-operator.clusterserviceversion.yaml; then
  echo "    ✗ ERROR: CSV displayName is not 'Open Data Hub'"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q 'operators.operatorframework.io.bundle.package.v1: opendatahub-operator' bundle/metadata/annotations.yaml; then
  echo "    ✗ ERROR: Bundle package name is not 'opendatahub-operator'"
  ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -eq 0 ]; then
  echo "  ✓ Bundle CSV and metadata correctly patched"
  echo "    - Image: opendatahub-operator:v${VERSION}"
  echo "    - CSV name: opendatahub-operator.v${VERSION}"
  echo "    - Package name: opendatahub-operator"
  echo "    - Namespaces: opendatahub"
  echo "    - Display name: Open Data Hub"
else
  echo ""
  echo "  ✗ CRITICAL: Found $ERRORS error(s) in bundle CSV!"
  echo "  Current CSV settings:"
  grep -E "name: |applicationsNamespace|containerImage|displayName: " bundle/manifests/rhods-operator.clusterserviceversion.yaml | head -10
  exit 1
fi

echo ""
echo "Verifying images in registry..."
podman pull ${OPERATOR_IMG} >/dev/null 2>&1 && echo "  ✓ Operator image available: ${OPERATOR_IMG}" || echo "  ✗ Operator image not found"
podman pull ${BUNDLE_IMG} >/dev/null 2>&1 && echo "  ✓ Bundle image available: ${BUNDLE_IMG}" || echo "  ✗ Bundle image not found"

echo ""
echo "=========================================="
echo "Build and push complete!"
echo "=========================================="
echo "Operator Image: ${OPERATOR_IMG}"
echo "Bundle Image:   ${BUNDLE_IMG}"
echo "=========================================="
echo ""
echo "To install v2.25.0:"
echo "  ./scripts/install-v2.25.0.sh"
echo ""
echo "To upgrade to v3.0.0 after v2.25.0 is installed:"
echo "  ./scripts/upgrade-to-v3.0.0.sh"
echo ""
