#!/bin/bash

# Build script for Console Auth Proxy

set -euo pipefail

# Variables
VERSION=${VERSION:-"dev"}
GIT_COMMIT=${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}
BUILD_DATE=${BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}
BUILD_DIR=${BUILD_DIR:-"./bin"}
BINARY_NAME="console-auth-proxy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Ensure we're in the project root
if [[ ! -f "go.mod" ]]; then
    error "go.mod not found. Please run this script from the project root."
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

# Build flags for version information
LDFLAGS="-X github.com/your-org/console-auth-proxy/internal/version.Version=${VERSION}"
LDFLAGS="${LDFLAGS} -X github.com/your-org/console-auth-proxy/internal/version.GitCommit=${GIT_COMMIT}"
LDFLAGS="${LDFLAGS} -X github.com/your-org/console-auth-proxy/internal/version.BuildDate=${BUILD_DATE}"

log "Building Console Auth Proxy..."
log "Version: ${VERSION}"
log "Git Commit: ${GIT_COMMIT}"
log "Build Date: ${BUILD_DATE}"
log "Output: ${BUILD_DIR}/${BINARY_NAME}"

# Build the binary
if ! go build \
    -ldflags "${LDFLAGS}" \
    -o "${BUILD_DIR}/${BINARY_NAME}" \
    ./cmd/console-auth-proxy; then
    error "Build failed"
fi

log "Build completed successfully!"

# Make binary executable
chmod +x "${BUILD_DIR}/${BINARY_NAME}"

# Show binary info
if [[ -x "${BUILD_DIR}/${BINARY_NAME}" ]]; then
    log "Binary information:"
    "${BUILD_DIR}/${BINARY_NAME}" --version || true
    ls -lh "${BUILD_DIR}/${BINARY_NAME}"
fi