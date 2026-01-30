#!/bin/bash
set -e

# Configuration
VERSION="3.0.0"
REGISTRY="registry.tannerjc.net/opendatahub"
OPERATOR_IMG="${REGISTRY}/rhods-operator:v${VERSION}"
BUNDLE_IMG="${REGISTRY}/rhods-operator-bundle:v${VERSION}"
PLATFORM="linux/amd64"
BUILD_ENV="olm-build-env:go1.25"
WORKSPACE="$(pwd)/src/opendatahub-io/opendatahub-operator.main"

echo "=========================================="
echo "Building and Pushing v${VERSION}"
echo "=========================================="
echo "Operator Image: ${OPERATOR_IMG}"
echo "Bundle Image:   ${BUNDLE_IMG}"
echo "Platform:       ${PLATFORM}"
echo "Workspace:      ${WORKSPACE}"
echo "=========================================="

cd "${WORKSPACE}"

# Step 0: Reset and apply patches
echo ""
echo "Step 0/5: Resetting source and applying patches..."
git reset --hard HEAD
git clean -fd

# Apply upgrade fixes patch
echo "  Applying main-upgrade-fixes.patch..."
git apply ../../../patches/main-upgrade-fixes.patch

echo "  ✓ Patches applied"

# Step 1: Build and push RHOAI operator image
echo ""
echo "Step 1/5: Building and pushing RHOAI operator image..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "make image-build IMG=${OPERATOR_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=rhoai && make image-push IMG=${OPERATOR_IMG}"

# Step 2: Generate bundle manifests
echo ""
echo "Step 2/5: Generating bundle manifests..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "export REGISTRY=${REGISTRY} && make bundle VERSION=${VERSION} IMG=${OPERATOR_IMG} BUNDLE_IMG=${BUNDLE_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=rhoai"

# Step 3: Build and push RHOAI bundle image (not ODH bundle)
echo ""
echo "Step 3/5: Building and pushing RHOAI bundle image..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "podman build --no-cache -f Dockerfiles/rhoai-bundle.Dockerfile -t ${BUNDLE_IMG} . && podman push ${BUNDLE_IMG}"

# Step 4: Verify patches applied
echo ""
echo "Step 4/5: Verifying patches applied..."
if grep -q "replaces: rhods-operator.v2.25.0" config/rhoai/manifests/bases/rhods-operator.clusterserviceversion.yaml; then
  echo "  ✓ CSV replaces field correctly set"
else
  echo "  ✗ WARNING: CSV replaces field may not be correct"
fi

if grep -q "IsNoMatchError" pkg/upgrade/upgrade_utils.go; then
  echo "  ✓ OdhDashboardConfig error handling fixed"
else
  echo "  ✗ WARNING: OdhDashboardConfig fix may not be applied"
fi

# Step 5: Verify images in registry
echo ""
echo "Step 5/5: Verifying images..."
echo "Checking operator image..."
podman pull ${OPERATOR_IMG} >/dev/null 2>&1 && echo "✓ Operator image available: ${OPERATOR_IMG}" || echo "✗ Operator image not found"
echo "Checking bundle image..."
podman pull ${BUNDLE_IMG} >/dev/null 2>&1 && echo "✓ Bundle image available: ${BUNDLE_IMG}" || echo "✗ Bundle image not found"

echo ""
echo "=========================================="
echo "Build and push complete!"
echo "=========================================="
echo "Operator Image: ${OPERATOR_IMG}"
echo "Bundle Image:   ${BUNDLE_IMG}"
echo "=========================================="
echo ""
echo "To install v2.25.0 and upgrade:"
echo "  oc create namespace redhat-ods-operator"
echo "  operator-sdk run bundle ${REGISTRY}/rhods-operator-bundle:v2.25.0 --namespace redhat-ods-operator"
echo "  # Wait for CSV to reach Succeeded, then:"
echo "  operator-sdk run bundle-upgrade ${BUNDLE_IMG} --namespace redhat-ods-operator"
echo ""
