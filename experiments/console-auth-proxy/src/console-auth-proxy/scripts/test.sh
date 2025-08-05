#!/bin/bash

# Test script for Console Auth Proxy

set -euo pipefail

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

log "Running tests for Console Auth Proxy..."

# Run go mod tidy to ensure dependencies are clean
log "Running go mod tidy..."
go mod tidy

# Run go mod verify to ensure dependencies are authentic
log "Verifying dependencies..."
go mod verify

# Run tests with coverage
log "Running unit tests..."
go test -v -race -coverprofile=coverage.out ./...

# Generate coverage report
if [[ -f "coverage.out" ]]; then
    log "Generating coverage report..."
    go tool cover -html=coverage.out -o coverage.html
    
    # Show coverage summary
    total_coverage=$(go tool cover -func=coverage.out | grep total | awk '{print $3}')
    log "Total test coverage: ${total_coverage}"
    
    # Check if coverage meets minimum threshold
    coverage_percent=$(echo "${total_coverage}" | sed 's/%//')
    if (( $(echo "${coverage_percent} >= 50" | bc -l) )); then
        log "Coverage meets minimum threshold (50%)"
    else
        warn "Coverage below minimum threshold (50%): ${total_coverage}"
    fi
fi

# Run linting (if golangci-lint is available)
if command -v golangci-lint &> /dev/null; then
    log "Running linter..."
    golangci-lint run
else
    warn "golangci-lint not found, skipping linting"
fi

# Run go vet
log "Running go vet..."
go vet ./...

# Check for potential security issues (if gosec is available)
if command -v gosec &> /dev/null; then
    log "Running security checks..."
    gosec ./...
else
    warn "gosec not found, skipping security checks"
fi

# Build to ensure everything compiles
log "Testing build..."
./scripts/build.sh

log "All tests completed successfully!"

# Cleanup
if [[ -f "coverage.out" ]]; then
    log "Coverage report available at: coverage.html"
fi