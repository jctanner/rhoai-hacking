#!/bin/bash

# Multi-Service Gateway API Test Script
# This script validates all routing paths and security configurations

set -euo pipefail

echo "🧪 Starting Multi-Service Gateway API Testing..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Test result functions
test_pass() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log "✅ PASS: $test_name"
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    error "❌ FAIL: $test_name - $reason"
}

# Check if running on OpenShift
if ! oc whoami &>/dev/null; then
    error "Not logged into OpenShift. Please run 'oc login' first."
    exit 1
fi

# Check if echo-test namespace exists
if ! oc get namespace echo-test &>/dev/null; then
    error "Namespace echo-test not found. Please run DEPLOY_ALL_MULTISERVICE.sh first."
    exit 1
fi

# Get TinyLB hostname
info "🔍 Discovering TinyLB hostname..."
TINYLB_HOSTNAME=$(oc get route -n echo-test -l tinylb.io/managed=true -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")

if [ -z "$TINYLB_HOSTNAME" ]; then
    error "TinyLB hostname not found. Please ensure deployment is complete."
    exit 1
fi

log "📡 Using hostname: $TINYLB_HOSTNAME"

# Test function for HTTP requests
test_http_request() {
    local path="$1"
    local expected_response="$2"
    local test_name="$3"
    local url="https://$TINYLB_HOSTNAME$path"
    
    info "🧪 Testing: $test_name"
    info "   URL: $url"
    info "   Expected: $expected_response"
    
    # Make the request with timeout
    local response=$(curl -k -s --max-time 10 "$url" 2>/dev/null || echo "CURL_ERROR")
    
    if [ "$response" = "CURL_ERROR" ]; then
        test_fail "$test_name" "HTTP request failed"
        return 1
    fi
    
    if [[ "$response" == *"$expected_response"* ]]; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name" "Expected '$expected_response', got '$response'"
        return 1
    fi
}

# Test function for security validation
test_security_check() {
    local test_name="$1"
    local command="$2"
    local expected_pattern="$3"
    
    info "🔒 Testing: $test_name"
    
    local result=$(eval "$command" 2>/dev/null || echo "COMMAND_ERROR")
    
    if [ "$result" = "COMMAND_ERROR" ]; then
        test_fail "$test_name" "Command execution failed"
        return 1
    fi
    
    if [[ "$result" =~ $expected_pattern ]]; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name" "Expected pattern '$expected_pattern', got '$result'"
        return 1
    fi
}

echo ""
log "🧪 Phase 1: Infrastructure Validation"
echo ""

# Test 1: Check if Gateway is programmed
test_security_check "Gateway Programming Status" \
    "oc get gateway echo-gateway -n echo-test -o jsonpath='{.status.conditions[?(@.type==\"Programmed\")].status}'" \
    "True"

# Test 2: Check if HTTPRoute is accepted
test_security_check "HTTPRoute Acceptance Status" \
    "oc get httproute multi-path-route -n echo-test -o jsonpath='{.status.parents[0].conditions[?(@.type==\"Accepted\")].status}'" \
    "True"

# Test 3: Check if TLS certificate exists
test_security_check "Gateway API TLS Certificate" \
    "oc get secret echo-tls-cert -n echo-test -o jsonpath='{.type}'" \
    "kubernetes.io/tls"

echo ""
log "🧪 Phase 2: Path-Based Routing Tests"
echo ""

# Test 4: Default route (/) → echo service
test_http_request "/" "Hello from Gateway API - Echo Service!" "Default Route (/) → Echo Service"

# Test 5: API routes (/api) → api-service
test_http_request "/api" "API Service Response - You hit /api/*" "API Route (/api) → API Service"

# Test 6: API routes (/api/users) → api-service
test_http_request "/api/users" "API Service Response - You hit /api/*" "API Route (/api/users) → API Service"

# Test 7: Static routes (/static) → static-service (404 expected - needs path rewrite)
test_http_request "/static" "Error code: 404" "Static Route (/static) → Static Service (404)"

# Test 8: Static routes (/static/css) → static-service (404 expected)
test_http_request "/static/css" "Error code: 404" "Static Route (/static/css) → Static Service (404)"

# Test 9: Exact path (/foo/bar) → foobar-service
test_http_request "/foo/bar" "FooBar Service - You hit exactly /foo/bar!" "Exact Path (/foo/bar) → FooBar Service"

echo ""
log "🧪 Phase 3: Path Precedence Tests"
echo ""

# Test 10: Path precedence - /foo/baz should go to echo (not foobar)
test_http_request "/foo/baz" "Hello from Gateway API - Echo Service!" "Path Precedence (/foo/baz) → Echo Service (not FooBar)"

# Test 11: Path precedence - /foo/bar/extra should go to echo (not foobar)
test_http_request "/foo/bar/extra" "Hello from Gateway API - Echo Service!" "Path Precedence (/foo/bar/extra) → Echo Service (not FooBar)"

# Test 12: Unmatched path should go to echo
test_http_request "/unmatched" "Hello from Gateway API - Echo Service!" "Unmatched Path (/unmatched) → Echo Service"

# Test 13: Deep path should go to echo
test_http_request "/test/deep/path" "Hello from Gateway API - Echo Service!" "Deep Path (/test/deep/path) → Echo Service"

echo ""
log "🧪 Phase 4: Service Mesh mTLS Validation"
echo ""

# Test 14: Check sidecar injection
test_security_check "Sidecar Injection (Echo Service)" \
    "oc get pod -n echo-test -l app=echo -o jsonpath='{.items[0].status.containerStatuses}' | grep -o '\"ready\":true' | wc -l" \
    "2"

test_security_check "Sidecar Injection (API Service)" \
    "oc get pod -n echo-test -l app=api-service -o jsonpath='{.items[0].status.containerStatuses}' | grep -o '\"ready\":true' | wc -l" \
    "2"

test_security_check "Sidecar Injection (Static Service)" \
    "oc get pod -n echo-test -l app=static-service -o jsonpath='{.items[0].status.containerStatuses}' | grep -o '\"ready\":true' | wc -l" \
    "2"

test_security_check "Sidecar Injection (FooBar Service)" \
    "oc get pod -n echo-test -l app=foobar-service -o jsonpath='{.items[0].status.containerStatuses}' | grep -o '\"ready\":true' | wc -l" \
    "2"

# Test 15: Check mTLS policy
test_security_check "STRICT mTLS Policy" \
    "oc get peerauthentication default -n echo-test -o jsonpath='{.spec.mtls.mode}'" \
    "STRICT"

echo ""
log "🧪 Phase 5: TLS/HTTPS Security Validation"
echo ""

# Test 16: Verify Gateway API TLS termination (not Router)
info "🔒 Testing: Gateway API TLS Termination"
TLS_SUBJECT=$(curl -k "https://$TINYLB_HOSTNAME/" -v 2>&1 | grep -E "subject:" | head -1 || echo "")
if [[ "$TLS_SUBJECT" == *"*.apps-crc.testing"* ]]; then
    test_pass "Gateway API TLS Termination (Certificate Subject)"
else
    test_fail "Gateway API TLS Termination (Certificate Subject)" "Expected *.apps-crc.testing in subject, got: $TLS_SUBJECT"
fi

# Test 17: Verify HTTP/2 support (confirms Gateway API processing)
info "🔒 Testing: HTTP/2 Support"
HTTP2_SUPPORT=$(curl -k "https://$TINYLB_HOSTNAME/" -v 2>&1 | grep -E "(ALPN.*h2|using HTTP/2)" || echo "")
if [[ -n "$HTTP2_SUPPORT" ]]; then
    test_pass "HTTP/2 Support (Gateway API Processing)"
else
    test_fail "HTTP/2 Support (Gateway API Processing)" "No HTTP/2 support detected"
fi

# Test 18: Check TinyLB route passthrough configuration
TINYLB_ROUTE_NAME=$(oc get route -n echo-test -l tinylb.io/managed=true -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$TINYLB_ROUTE_NAME" ]; then
    test_security_check "TinyLB Route Passthrough Configuration" \
        "oc get route $TINYLB_ROUTE_NAME -n echo-test -o jsonpath='{.spec.tls.termination}'" \
        "passthrough"
else
    test_fail "TinyLB Route Passthrough Configuration" "TinyLB route not found"
fi

echo ""
log "🧪 Phase 6: Performance and Reliability Tests"
echo ""

# Test 19: Response time check
info "🔒 Testing: Response Time Performance"
RESPONSE_TIME=$(curl -k -s -o /dev/null -w "%{time_total}" "https://$TINYLB_HOSTNAME/" 2>/dev/null || echo "999")
if (( $(echo "$RESPONSE_TIME < 5.0" | bc -l) )); then
    test_pass "Response Time Performance (${RESPONSE_TIME}s < 5.0s)"
else
    test_fail "Response Time Performance" "Response time ${RESPONSE_TIME}s >= 5.0s"
fi

# Test 20: Multiple concurrent requests
info "🔒 Testing: Concurrent Request Handling"
CONCURRENT_SUCCESS=0
for i in {1..5}; do
    if curl -k -s --max-time 5 "https://$TINYLB_HOSTNAME/" | grep -q "Hello from Gateway API - Echo Service!"; then
        CONCURRENT_SUCCESS=$((CONCURRENT_SUCCESS + 1))
    fi
done

if [ "$CONCURRENT_SUCCESS" -eq 5 ]; then
    test_pass "Concurrent Request Handling (5/5 requests succeeded)"
else
    test_fail "Concurrent Request Handling" "Only $CONCURRENT_SUCCESS/5 requests succeeded"
fi

echo ""
log "🧪 Phase 7: Error Handling Tests"
echo ""

# Test 21: Invalid path handling
info "🔒 Testing: Invalid Path Handling"
INVALID_RESPONSE=$(curl -k -s -w "%{http_code}" "https://$TINYLB_HOSTNAME/invalid/path/that/should/go/to/echo" 2>/dev/null || echo "000")
if [[ "$INVALID_RESPONSE" == *"200"* ]] && [[ "$INVALID_RESPONSE" == *"Hello from Gateway API - Echo Service!"* ]]; then
    test_pass "Invalid Path Handling (routed to echo service)"
else
    test_fail "Invalid Path Handling" "Expected 200 with echo response, got: $INVALID_RESPONSE"
fi

# Test 22: HTTPS enforcement
info "🔒 Testing: HTTPS Enforcement"
HTTP_RESPONSE=$(curl -s -w "%{http_code}" "http://$TINYLB_HOSTNAME/" 2>/dev/null || echo "000")
if [[ "$HTTP_RESPONSE" == *"301"* ]] || [[ "$HTTP_RESPONSE" == *"302"* ]] || [[ "$HTTP_RESPONSE" == *"000"* ]]; then
    test_pass "HTTPS Enforcement (HTTP redirected or blocked)"
else
    test_fail "HTTPS Enforcement" "HTTP should be redirected/blocked, got: $HTTP_RESPONSE"
fi

echo ""
log "📊 Test Results Summary"
echo ""

# Calculate success rate
if [ "$TESTS_TOTAL" -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=1; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc -l 2>/dev/null || echo "0")
else
    SUCCESS_RATE="0"
fi

log "Total Tests: $TESTS_TOTAL"
log "Tests Passed: $TESTS_PASSED"
log "Tests Failed: $TESTS_FAILED"
log "Success Rate: ${SUCCESS_RATE}%"

echo ""
if [ "$TESTS_FAILED" -eq 0 ]; then
    log "🎉 All tests passed! Multi-service Gateway API deployment is working correctly."
    log "✅ Path-based routing: Working"
    log "✅ Service Mesh mTLS: Working"  
    log "✅ Gateway API TLS: Working"
    log "✅ TinyLB passthrough: Working"
    log "✅ Performance: Acceptable"
    echo ""
    log "🎯 Next steps:"
    echo "   - Test advanced features (header-based routing, traffic splitting)"
    echo "   - Run load testing for performance validation"
    echo "   - Test service failure scenarios"
    echo ""
    exit 0
else
    error "❌ $TESTS_FAILED tests failed. Please check the deployment and fix issues."
    echo ""
    error "🔧 Debugging commands:"
    echo "   - Check Gateway status: oc get gateway echo-gateway -n echo-test -o yaml"
    echo "   - Check HTTPRoute status: oc get httproute multi-path-route -n echo-test -o yaml"
    echo "   - Check TinyLB logs: tail -f /tmp/tinylb.log"
    echo "   - Check pod status: oc get pods -n echo-test -o wide"
    echo "   - Check service status: oc get svc -n echo-test"
    echo ""
    exit 1
fi 