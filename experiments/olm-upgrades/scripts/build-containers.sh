#!/bin/bash
set -e

echo "=========================================="
echo "Building OLM Build Environment Containers"
echo "=========================================="
echo ""

# Build Go 1.24 container for v2.25.0
echo "Building olm-build-env:go1.24 (for v2.25.0)..."
podman build \
  -f dockerfiles/build-container.Dockerfile \
  -t olm-build-env:go1.24 \
  .

echo "✓ Built olm-build-env:go1.24"
echo ""

# Build Go 1.25 container for v3.0.0
echo "Building olm-build-env:go1.25 (for v3.0.0)..."
podman build \
  -f dockerfiles/build-container-go125.Dockerfile \
  -t olm-build-env:go1.25 \
  .

echo "✓ Built olm-build-env:go1.25"
echo ""

echo "=========================================="
echo "Build Containers Ready"
echo "=========================================="
echo ""
podman images | grep olm-build-env
echo ""
echo "These containers are used by the build scripts:"
echo "  - build-and-push-v2.25.0.sh uses olm-build-env:go1.24"
echo "  - build-and-push-v3.0.0.sh uses olm-build-env:go1.25"
echo ""
