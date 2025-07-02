#!/bin/sh

# Integration test script for ODH Gateway
# Tests basic proxy functionality without OIDC

set -e

GATEWAY_URL="http://odh-gateway:8080"
FAILED_TESTS=0
TOTAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

test_endpoint() {
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

test_redirect() {
    local url="$1"
    local expected_location="$2"
    local test_name="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log "${YELLOW}Testing: $test_name${NC}"
    log "URL: $url"
    log "Expected redirect to: $expected_location"
    
    # Make the request and capture response with headers
    response=$(curl -s -w "\n%{http_code}\n%{redirect_url}" "$url" || echo -e "\nERROR")
    http_code=$(echo "$response" | tail -n2 | head -n1)
    redirect_url=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -2)
    
    if [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
        if [ "$redirect_url" = "$expected_location" ] || echo "$body" | grep -q "$expected_location"; then
            log "${GREEN}✓ PASS: $test_name${NC}"
            log "  HTTP $http_code redirect to: $expected_location"
        else
            log "${RED}✗ FAIL: $test_name${NC}"
            log "  Expected redirect to: $expected_location"
            log "  Got redirect to: $redirect_url"
            log "  Response body: $body"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        log "${RED}✗ FAIL: $test_name${NC}"
        log "  Expected HTTP 301/302 redirect, got: $http_code"
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
wait_for_service "http://mlflow-service:80/" "MLflow service" || exit 1  
wait_for_service "http://docs-service:80/" "Documentation service" || exit 1
wait_for_service "http://api-service:80/" "API service" || exit 1
wait_for_service "http://default-service:80/" "Default service" || exit 1

# Now wait for gateway to be ready
wait_for_service "$GATEWAY_URL/" "ODH Gateway" || exit 1

# Give everything a moment to settle
log "${YELLOW}All services ready, waiting 3 seconds for full initialization...${NC}"
sleep 3

echo ""
log "${YELLOW}=== Starting ODH Gateway Integration Tests ===${NC}"
echo ""

# Test 1: Jupyter service routing
test_endpoint "$GATEWAY_URL/jupyter/" "/jupyter/" "Jupyter service proxy"

# Test 2: Jupyter subpath routing  
test_endpoint "$GATEWAY_URL/jupyter/lab" "/jupyter/lab" "Jupyter lab subpath proxy"

# Test 3: MLflow service routing
test_endpoint "$GATEWAY_URL/mlflow/" "/mlflow/" "MLflow service proxy"

# Test 4: MLflow subpath routing
test_endpoint "$GATEWAY_URL/mlflow/experiments" "/mlflow/experiments" "MLflow experiments subpath proxy"

# Test 5: Documentation service routing
test_endpoint "$GATEWAY_URL/docs/" "/docs/" "Documentation service proxy"

# Test 6: Documentation subpath routing
test_endpoint "$GATEWAY_URL/docs/api" "/docs/api" "Documentation API subpath proxy"

# Test 7: API service routing
test_endpoint "$GATEWAY_URL/api/" "/api/" "API service proxy"

# Test 8: API subpath routing
test_endpoint "$GATEWAY_URL/api/health" "/api/health" "API health subpath proxy"

# Test 9: Fallback route (root)
test_endpoint "$GATEWAY_URL/" "/" "Fallback route (root)"

# Test 10: Fallback route (unknown path)
test_endpoint "$GATEWAY_URL/unknown-path" "/unknown-path" "Fallback route (unknown path)"

# Test 11: Check that paths without trailing slash redirect correctly
test_redirect "$GATEWAY_URL/jupyter" "/jupyter/" "Jupyter without trailing slash redirect"

echo ""
log "${YELLOW}=== Test Results ===${NC}"
log "Total tests: $TOTAL_TESTS"
log "Passed: $((TOTAL_TESTS - FAILED_TESTS))"
log "Failed: $FAILED_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
    log "${GREEN}All tests passed! 🎉${NC}"
    exit 0
else
    log "${RED}$FAILED_TESTS test(s) failed! ❌${NC}"
    exit 1
fi 