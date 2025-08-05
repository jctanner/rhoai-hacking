#!/bin/bash

# Docker build script for Console Auth Proxy

set -euo pipefail

# Variables
VERSION=${VERSION:-"dev"}
GIT_COMMIT=${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}
BUILD_DATE=${BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}
IMAGE_NAME=${IMAGE_NAME:-"console-auth-proxy"}
IMAGE_TAG=${IMAGE_TAG:-"${VERSION}"}
REGISTRY=${REGISTRY:-""}
PLATFORM=${PLATFORM:-"linux/amd64"}

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

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build Docker image for Console Auth Proxy

OPTIONS:
    -h, --help          Show this help message
    -v, --version       Set version (default: ${VERSION})
    -t, --tag           Set image tag (default: ${IMAGE_TAG})
    -r, --registry      Set registry prefix (e.g., docker.io/myorg)
    -p, --platform      Set target platform (default: ${PLATFORM})
    --push              Push image to registry after build
    --latest            Also tag as 'latest'

ENVIRONMENT VARIABLES:
    VERSION             Version string
    GIT_COMMIT          Git commit hash
    BUILD_DATE          Build timestamp
    IMAGE_NAME          Base image name
    IMAGE_TAG           Image tag
    REGISTRY            Registry prefix
    PLATFORM            Target platform

EXAMPLES:
    # Build local image
    $0

    # Build and tag as latest
    $0 --latest

    # Build for specific version and push
    $0 --version v1.0.0 --registry docker.io/myorg --push

    # Build multi-platform image
    $0 --platform linux/amd64,linux/arm64
EOF
}

# Parse command line arguments
PUSH=false
TAG_LATEST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --latest)
            TAG_LATEST=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Ensure we're in the project root
if [[ ! -f "Dockerfile" ]]; then
    error "Dockerfile not found. Please run this script from the project root."
fi

# Construct full image name
FULL_IMAGE_NAME="${IMAGE_NAME}"
if [[ -n "${REGISTRY}" ]]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}"
fi

log "Building Docker image for Console Auth Proxy..."
log "Version: ${VERSION}"
log "Git Commit: ${GIT_COMMIT}"
log "Build Date: ${BUILD_DATE}"
log "Image: ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
log "Platform: ${PLATFORM}"

# Build arguments
BUILD_ARGS=(
    "--build-arg" "VERSION=${VERSION}"
    "--build-arg" "GIT_COMMIT=${GIT_COMMIT}"
    "--build-arg" "BUILD_DATE=${BUILD_DATE}"
    "--platform" "${PLATFORM}"
    "--tag" "${FULL_IMAGE_NAME}:${IMAGE_TAG}"
)

# Add latest tag if requested
if [[ "${TAG_LATEST}" == "true" ]]; then
    BUILD_ARGS+=("--tag" "${FULL_IMAGE_NAME}:latest")
fi

# Build the image
log "Running docker build..."
if ! docker build "${BUILD_ARGS[@]}" .; then
    error "Docker build failed"
fi

log "Docker build completed successfully!"

# Show image information
docker images "${FULL_IMAGE_NAME}" | head -2

# Test the image
log "Testing the built image..."
if docker run --rm "${FULL_IMAGE_NAME}:${IMAGE_TAG}" --version; then
    log "Image test passed"
else
    warn "Image test failed"
fi

# Push if requested
if [[ "${PUSH}" == "true" ]]; then
    if [[ -z "${REGISTRY}" ]]; then
        warn "No registry specified, skipping push"
    else
        log "Pushing image to registry..."
        docker push "${FULL_IMAGE_NAME}:${IMAGE_TAG}"
        
        if [[ "${TAG_LATEST}" == "true" ]]; then
            docker push "${FULL_IMAGE_NAME}:latest"
        fi
        
        log "Image pushed successfully!"
    fi
fi

log "All operations completed successfully!"
log "Image: ${FULL_IMAGE_NAME}:${IMAGE_TAG}"