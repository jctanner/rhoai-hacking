#!/bin/bash

# Enhanced Gateway API Multi-Service Cleanup Script
# This cleans up all resources created by DEPLOY_ALL_MULTISERVICE.sh

set -euo pipefail

echo "🧹 Starting Multi-Service Gateway API Cleanup..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Check if running on OpenShift
if ! oc whoami &>/dev/null; then
    error "Not logged into OpenShift. Please run 'oc login' first."
    exit 1
fi

# Stop TinyLB controller
log "Stopping TinyLB controller..."
if [ -f /tmp/tinylb.pid ]; then
    TINYLB_PID=$(cat /tmp/tinylb.pid)
    if kill -0 $TINYLB_PID 2>/dev/null; then
        log "Stopping TinyLB controller (PID: $TINYLB_PID)"
        kill $TINYLB_PID
        sleep 2
        # Force kill if still running
        if kill -0 $TINYLB_PID 2>/dev/null; then
            warn "Force killing TinyLB controller"
            kill -9 $TINYLB_PID
        fi
    else
        warn "TinyLB controller not running"
    fi
    rm -f /tmp/tinylb.pid
else
    warn "TinyLB PID file not found"
fi

# Remove TinyLB log file
rm -f /tmp/tinylb.log

# Delete HTTPRoutes first
log "Deleting HTTPRoutes..."
oc delete httproute --all -n echo-test --ignore-not-found=true

# Delete Gateway
log "Deleting Gateway..."
oc delete gateway --all -n echo-test --ignore-not-found=true

# Delete LoadBalancer services (these trigger TinyLB route cleanup)
log "Deleting LoadBalancer services..."
oc delete service -l type=LoadBalancer -n echo-test --ignore-not-found=true
oc delete service echo-gateway-istio -n echo-test --ignore-not-found=true

# Wait for TinyLB to clean up routes
log "Waiting for TinyLB to clean up routes..."
sleep 10

# Manually clean up any remaining routes created by TinyLB
log "Cleaning up TinyLB-managed routes..."
ROUTE_COUNT=$(oc get routes -A --no-headers 2>/dev/null | grep -c "echo-gateway-istio" || echo "0")
if [ "$ROUTE_COUNT" -gt 0 ]; then
    log "Found $ROUTE_COUNT TinyLB-managed routes. Cleaning up..."
    oc get routes -A --no-headers | grep "echo-gateway-istio" | while read -r namespace name rest; do
        log "Deleting route $name in namespace $namespace"
        oc delete route "$name" -n "$namespace" --ignore-not-found=true
    done
fi

# Delete Services
log "Deleting Services..."
oc delete service echo -n echo-test --ignore-not-found=true
oc delete service api-service -n echo-test --ignore-not-found=true
oc delete service static-service -n echo-test --ignore-not-found=true
oc delete service foobar-service -n echo-test --ignore-not-found=true

# Delete Deployments
log "Deleting Deployments..."
oc delete deployment echo -n echo-test --ignore-not-found=true
oc delete deployment api-service -n echo-test --ignore-not-found=true
oc delete deployment static-service -n echo-test --ignore-not-found=true
oc delete deployment foobar-service -n echo-test --ignore-not-found=true

# Delete ConfigMaps (if any)
log "Deleting ConfigMaps..."
oc delete configmap --all -n echo-test --ignore-not-found=true

# Delete certificates
log "Deleting certificates..."
oc delete secret echo-tls-cert -n echo-test --ignore-not-found=true

# Delete namespace
log "Deleting namespace echo-test..."
oc delete project echo-test --ignore-not-found=true

# Wait for namespace deletion
log "Waiting for namespace deletion..."
while oc get project echo-test &>/dev/null; do
    log "Waiting for namespace echo-test to be deleted..."
    sleep 5
done

# Note: We don't manage Service Mesh installation in this script
log "Note: Service Mesh components (if any) are not managed by this script."

# Verify cleanup
log "Verifying cleanup..."
REMAINING_RESOURCES=0

# Check for remaining resources
if oc get project echo-test &>/dev/null; then
    error "Namespace echo-test still exists"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + 1))
fi

ROUTE_COUNT=$(oc get routes -A --no-headers 2>/dev/null | grep -c "echo-gateway-istio" || echo "0")
if [ "$ROUTE_COUNT" -gt 0 ]; then
    error "Found $ROUTE_COUNT remaining TinyLB-managed routes"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + 1))
fi

if [ -f /tmp/tinylb.pid ]; then
    error "TinyLB PID file still exists"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + 1))
fi

if [ -f /tmp/tinylb.log ]; then
    error "TinyLB log file still exists"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + 1))
fi

if [ "$REMAINING_RESOURCES" -eq 0 ]; then
    log "✅ Multi-Service Gateway API cleanup completed successfully!"
    log "All resources have been removed."
else
    error "⚠️  Cleanup completed with $REMAINING_RESOURCES remaining issues."
    error "Please check the errors above and clean up manually if needed."
fi

echo ""
log "Summary of cleaned up resources:"
echo "  ✅ TinyLB controller stopped"
echo "  ✅ HTTPRoutes deleted"
echo "  ✅ Gateway deleted"
echo "  ✅ LoadBalancer services deleted"
echo "  ✅ TinyLB-managed routes cleaned up"
echo "  ✅ All application services deleted (echo, api-service, static-service, foobar-service)"
echo "  ✅ All deployments deleted"
echo "  ✅ ConfigMaps deleted (if any)"
echo "  ✅ Certificates deleted"
echo "  ✅ Namespace echo-test deleted"
echo ""
log "The multi-service Gateway API demo has been completely removed." 