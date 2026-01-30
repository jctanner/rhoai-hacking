#!/bin/bash
set -e

# Configuration
VERSION="2.25.0"
REGISTRY="registry.tannerjc.net/opendatahub"
OPERATOR_IMG="${REGISTRY}/rhods-operator:v${VERSION}"
BUNDLE_IMG="${REGISTRY}/rhods-operator-bundle:v${VERSION}"
PLATFORM="linux/amd64"
BUILD_ENV="olm-build-env:go1.24"
WORKSPACE="$(pwd)/src/opendatahub-io/opendatahub-operator.stable-2.x"

echo "=========================================="
echo "Building and Pushing v${VERSION}"
echo "=========================================="
echo "Operator Image: ${OPERATOR_IMG}"
echo "Bundle Image:   ${BUNDLE_IMG}"
echo "Platform:       ${PLATFORM}"
echo "Workspace:      ${WORKSPACE}"
echo "Build Env:      ${BUILD_ENV} (Go 1.24)"
echo "=========================================="

cd "${WORKSPACE}"

# Step 0: Reset and apply patches
echo ""
echo "Step 0/5: Resetting source and applying patches..."
git reset --hard HEAD
git clean -fd

# Apply CSV patch
echo "  Applying stable-2.x-csv.patch..."
git apply ../../../patches/stable-2.x-csv.patch

# Parameterize registry in the patched CSV
echo "  Parameterizing registry path..."
sed -i "s|registry.tannerjc.net/opendatahub|${REGISTRY}|g" bundle/manifests/rhods-operator.clusterserviceversion.yaml

echo "  ✓ Patches applied"

# Step 1: Build and push operator image
echo ""
echo "Step 1/5: Building and pushing operator image..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "make image-build IMG=${OPERATOR_IMG} PLATFORM=${PLATFORM} && make image-push IMG=${OPERATOR_IMG}"

# Step 2: Generate bundle manifests
echo ""
echo "Step 2/5: Generating bundle manifests..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "export REGISTRY=${REGISTRY} && make bundle VERSION=${VERSION} IMG=${OPERATOR_IMG} BUNDLE_IMG=${BUNDLE_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=rhoai"

# Step 3: Build and push bundle image (stable-2.x uses bundle.Dockerfile, not rhoai-bundle.Dockerfile)
echo ""
echo "Step 3/5: Building and pushing RHOAI bundle image..."
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  ${BUILD_ENV} \
  bash -c "podman build --no-cache -f Dockerfiles/bundle.Dockerfile -t ${BUNDLE_IMG} . && podman push ${BUNDLE_IMG}"

# Step 4: Verify patches applied
echo ""
echo "Step 4/5: Verifying patches applied..."
if grep -q "${REGISTRY}/rhods-operator:v${VERSION}" bundle/manifests/rhods-operator.clusterserviceversion.yaml; then
  echo "  ✓ CSV image reference correctly set"
else
  echo "  ✗ WARNING: CSV image reference may not be correct"
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
echo "To install v2.25.0:"
echo "  ./scripts/install-v2.25.0.sh"
echo ""
echo "To upgrade to v3.0.0 after v2.25.0 is installed:"
echo "  ./scripts/upgrade-to-v3.0.0.sh"
echo ""
