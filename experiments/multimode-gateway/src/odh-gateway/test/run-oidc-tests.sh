#!/bin/sh

# OIDC Integration test script for ODH Gateway
# Tests authentication behavior and redirects

set -e

GATEWAY_URL="http://odh-gateway:8080"
FAILED_TESTS=0
TOTAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

# Test that a protected route redirects to OIDC provider
test_protected_redirect() {
    local url="$1"
    local test_name="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log "${YELLOW}Testing: $test_name${NC}"
    log "URL: $url"
    log "Expected: Redirect to OIDC provider"
    
    # Make request without following redirects and capture response
    response=$(curl -s -w "\n%{http_code}\n%{redirect_url}" "$url" || echo -e "\nERROR")
    http_code=$(echo "$response" | tail -n2 | head -n1)
    redirect_url=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -2)
    
    if [ "$http_code" = "302" ] || [ "$http_code" = "307" ]; then
        # Check if redirect contains OIDC provider URL
        if echo "$redirect_url" | grep -q "fake-oidc-provider.com" || echo "$body" | grep -q "fake-oidc-provider.com"; then
            log "${GREEN}✓ PASS: $test_name${NC}"
            log "  HTTP $http_code redirect to OIDC provider"
        else
            log "${RED}✗ FAIL: $test_name${NC}"
            log "  Expected redirect to OIDC provider"
            log "  Got redirect to: $redirect_url"
            log "  Response body: $body"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        log "${RED}✗ FAIL: $test_name${NC}"
        log "  Expected HTTP 302/307 redirect, got: $http_code"
        log "  Response body: $body"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    echo ""
}

# Test that a public route works without authentication
test_public_route() {
    local url="$1"
    local expected_path="$2"
    local test_name="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log "${YELLOW}Testing: $test_name${NC}"
    log "URL: $url"
    log "Expected path: $expected_path"
    
    # Make the request and capture response
    response=$(curl -s -w "\n%{http_code}" "$url" || echo -e "\nERROR")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        # Parse the JSON response to extract the path
        actual_path=$(echo "$body" | sed -n 's/.*"path": *"\([^"]*\)".*/\1/p')
        if [ "$actual_path" = "$expected_path" ]; then
            log "${GREEN}✓ PASS: $test_name${NC}"
            log "  Expected path: $expected_path"
            log "  Actual path: $actual_path"
        else
            log "${RED}✗ FAIL: $test_name${NC}"
            log "  Expected path: $expected_path"
            log "  Actual path: $actual_path"
            log "  Full response: $body"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        log "${RED}✗ FAIL: $test_name${NC}"
        log "  Expected HTTP 200, got: $http_code"
        log "  Response body: $body"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    echo ""
}

# Function to wait for a service to be ready
wait_for_service() {
    local service_url="$1"
    local service_name="$2"
    local max_attempts=30
    
    log "${YELLOW}Waiting for $service_name to be ready...${NC}"
    for i in $(seq 1 $max_attempts); do
        if curl -s "$service_url" > /dev/null 2>&1; then
            log "${GREEN}$service_name is ready!${NC}"
            return 0
        fi
        if [ $i -eq $max_attempts ]; then
            log "${RED}$service_name failed to start within $max_attempts seconds${NC}"
            return 1
        fi
        sleep 1
    done
}

# Wait for all upstream services to be ready first
log "${YELLOW}=== Waiting for all services to be ready ===${NC}"

wait_for_service "http://jupyter-service:80/" "Jupyter service" || exit 1
wait_for_service "http://public-service:80/" "Public service" || exit 1  
wait_for_service "http://api-service:80/" "API service" || exit 1
wait_for_service "http://docs-service:80/" "Docs service" || exit 1
wait_for_service "http://default-service:80/" "Default service" || exit 1

# Wait for gateway to be ready (using public route that doesn't require auth)
wait_for_service "$GATEWAY_URL/docs/" "ODH Gateway" || exit 1

# Give everything a moment to settle
log "${YELLOW}All services ready, waiting 3 seconds for full initialization...${NC}"
sleep 3

echo ""
log "${YELLOW}=== Starting ODH Gateway OIDC Integration Tests ===${NC}"
echo ""

# Test 1: Protected route should redirect to OIDC provider
test_protected_redirect "$GATEWAY_URL/jupyter/" "Protected Jupyter route redirect"

# Test 2: Protected API route should redirect to OIDC provider  
test_protected_redirect "$GATEWAY_URL/api/" "Protected API route redirect"

# Test 3: Protected subpath should redirect to OIDC provider
test_protected_redirect "$GATEWAY_URL/jupyter/lab" "Protected Jupyter subpath redirect"

# Test 4: Public route should work without authentication
test_public_route "$GATEWAY_URL/public/" "/public/" "Public route without auth"

# Test 5: Public docs route should work without authentication
test_public_route "$GATEWAY_URL/docs/" "/docs/" "Public docs route without auth"

# Test 6: Public docs subpath should work without authentication
test_public_route "$GATEWAY_URL/docs/api" "/docs/api" "Public docs subpath without auth"

# Test 7: Fallback route should work without authentication (no authRequired specified = false)
test_public_route "$GATEWAY_URL/" "/" "Fallback route without auth"

# Test 8: Unknown public path should work without authentication
test_public_route "$GATEWAY_URL/unknown-path" "/unknown-path" "Unknown path fallback without auth"

echo ""
log "${YELLOW}=== OIDC Test Results ===${NC}"
log "Total tests: $TOTAL_TESTS"
log "Passed: $((TOTAL_TESTS - FAILED_TESTS))"
log "Failed: $FAILED_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
    log "${GREEN}All OIDC tests passed! 🎉${NC}"
    exit 0
else
    log "${RED}$FAILED_TESTS OIDC test(s) failed! ❌${NC}"
    exit 1
fi 