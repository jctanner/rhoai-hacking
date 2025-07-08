#!/bin/bash
set -euo pipefail

NAMESPACE="echo-test"
HOST="echo.apps-crc.testing"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}$1${NC}"; }
echo_success() { echo -e "${GREEN}$1${NC}"; }
echo_warning() { echo -e "${YELLOW}$1${NC}"; }
echo_error() { echo -e "${RED}$1${NC}"; }

# Stop TinyLB Controller
stop_tinylb_controller() {
    echo_info "🛑 Stopping TinyLB Controller..."
    
    # Check if TinyLB is running
    if [ -f /tmp/tinylb.pid ]; then
        local pid=$(cat /tmp/tinylb.pid)
        if kill -0 $pid 2>/dev/null; then
            echo_info "Stopping TinyLB controller (PID: $pid)..."
            kill $pid
            
            # Wait for process to stop
            local count=0
            while kill -0 $pid 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            if kill -0 $pid 2>/dev/null; then
                echo_warning "Force killing TinyLB controller..."
                kill -9 $pid
            fi
            
            echo_success "✅ TinyLB controller stopped"
        else
            echo_info "TinyLB controller not running"
        fi
        
        # Remove PID file
        rm -f /tmp/tinylb.pid
    else
        echo_info "No TinyLB PID file found"
    fi
    
    # Remove log file
    if [ -f /tmp/tinylb.log ]; then
        rm -f /tmp/tinylb.log
        echo_info "Removed TinyLB log file"
    fi
}

# Clean up TinyLB RBAC resources
cleanup_tinylb_rbac() {
    echo_info "🧹 Cleaning up TinyLB RBAC resources..."
    
    if [ -d "src/tinylb/config/rbac" ]; then
        cd src/tinylb
        oc delete -f config/rbac/ || true
        cd ../..
        echo_success "✅ TinyLB RBAC resources removed"
    else
        echo_warning "⚠️  TinyLB RBAC config not found"
    fi
}

# Remove OpenShift Routes
remove_routes() {
    echo_info "🛤️  Removing OpenShift Routes..."
    
    # Remove routes in the namespace
    oc delete routes --all -n $NAMESPACE || true
    
    # Remove any TinyLB managed routes across all namespaces
    echo_info "Checking for TinyLB managed routes in other namespaces..."
    oc get routes --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | \
        while read ns route; do
            if [ -n "$ns" ] && [ -n "$route" ]; then
                if oc get route "$route" -n "$ns" -o jsonpath='{.metadata.labels.tinylb\.io/managed}' 2>/dev/null | grep -q "true"; then
                    echo_info "Removing TinyLB managed route: $route in namespace $ns"
                    oc delete route "$route" -n "$ns" || true
                fi
            fi
        done
    
    echo_success "✅ Routes removed"
}

# Remove Service Mesh configuration
cleanup_service_mesh() {
    echo_info "🔐 Cleaning up Service Mesh configuration..."
    
    # Remove PeerAuthentication policies
    oc delete peerauthentication --all -n $NAMESPACE || true
    
    # Remove sidecar injection label from namespace
    oc label namespace $NAMESPACE istio-injection- || true
    
    echo_success "✅ Service Mesh configuration cleaned up"
}

# Remove TLS certificates and secrets
remove_certificates() {
    echo_info "🔒 Removing TLS certificates..."
    
    # Remove TLS secrets
    oc delete secret echo-tls-cert -n $NAMESPACE || true
    
    # Remove any temporary certificate files
    rm -f /tmp/gateway-*.pem
    
    echo_success "✅ TLS certificates removed"
}

# Remove Gateway API resources
remove_gateway_resources() {
    echo_info "🌐 Removing Gateway API resources..."
    
    # Remove HTTPRoute
    oc delete httproute --all -n $NAMESPACE || true
    
    # Remove Gateway
    oc delete gateway --all -n $NAMESPACE || true
    
    echo_success "✅ Gateway API resources removed"
}

# Remove application resources
remove_application() {
    echo_info "📦 Removing application resources..."
    
    # Remove deployment
    oc delete deployment --all -n $NAMESPACE || true
    
    # Remove services
    oc delete service --all -n $NAMESPACE || true
    
    # Remove configmaps
    oc delete configmap --all -n $NAMESPACE || true
    
    # Remove any other resources
    oc delete all --all -n $NAMESPACE || true
    
    echo_success "✅ Application resources removed"
}

# Remove namespace
remove_namespace() {
    echo_info "🗑️  Removing namespace..."
    
    # Check if namespace exists
    if oc get namespace $NAMESPACE >/dev/null 2>&1; then
        echo_info "Deleting namespace: $NAMESPACE"
        oc delete namespace $NAMESPACE
        
        # Wait for namespace to be fully deleted
        echo_info "Waiting for namespace deletion to complete..."
        local count=0
        while oc get namespace $NAMESPACE >/dev/null 2>&1 && [ $count -lt 30 ]; do
            sleep 2
            count=$((count + 1))
        done
        
        if oc get namespace $NAMESPACE >/dev/null 2>&1; then
            echo_warning "⚠️  Namespace deletion taking longer than expected"
            echo_warning "   You may need to manually clean up finalizers"
        else
            echo_success "✅ Namespace removed"
        fi
    else
        echo_info "Namespace $NAMESPACE does not exist"
    fi
}

# Clean up DNS entries (informational)
cleanup_dns_info() {
    echo_info "🌐 DNS Cleanup Information"
    
    echo_warning "⚠️  If you added DNS entries to /etc/hosts, you may want to remove them:"
    echo_warning "   Lines containing: $HOST"
    echo_warning "   Lines containing: echo-gateway-istio-echo-test.apps-crc.testing"
    echo_warning ""
    echo_warning "   To remove: sudo sed -i '/$HOST/d' /etc/hosts"
    echo_warning "   To remove: sudo sed -i '/echo-gateway-istio-echo-test.apps-crc.testing/d' /etc/hosts"
}

# Clean up temporary files
cleanup_temp_files() {
    echo_info "🧹 Cleaning up temporary files..."
    
    # Remove any temporary files that might have been created
    rm -f /tmp/tinylb.* /tmp/gateway-*.pem
    
    echo_success "✅ Temporary files cleaned up"
}

# Verify cleanup
verify_cleanup() {
    echo_info "🔍 Verifying cleanup..."
    
    # Check if namespace exists
    if oc get namespace $NAMESPACE >/dev/null 2>&1; then
        echo_warning "⚠️  Namespace $NAMESPACE still exists"
    else
        echo_success "✅ Namespace removed"
    fi
    
    # Check if TinyLB is still running
    if [ -f /tmp/tinylb.pid ]; then
        local pid=$(cat /tmp/tinylb.pid)
        if kill -0 $pid 2>/dev/null; then
            echo_warning "⚠️  TinyLB controller still running (PID: $pid)"
        else
            echo_success "✅ TinyLB controller stopped"
        fi
    else
        echo_success "✅ TinyLB controller stopped"
    fi
    
    # Check for any remaining TinyLB managed routes
    local tinylb_routes=0
    if oc get routes --all-namespaces >/dev/null 2>&1; then
        local route_count=$(oc get routes --all-namespaces -o jsonpath='{range .items[*]}{.metadata.labels.tinylb\.io/managed}{"\n"}{end}' 2>/dev/null | grep "true" | wc -l)
        tinylb_routes=${route_count:-0}
    fi
    if [ "$tinylb_routes" -gt 0 ]; then
        echo_warning "⚠️  $tinylb_routes TinyLB managed routes still exist"
    else
        echo_success "✅ No TinyLB managed routes found"
    fi
    
    # Check for temporary files
    local temp_files=0
    if ls /tmp/tinylb.* /tmp/gateway-*.pem >/dev/null 2>&1; then
        temp_files=$(ls /tmp/tinylb.* /tmp/gateway-*.pem 2>/dev/null | wc -l)
    fi
    if [ "$temp_files" -gt 0 ]; then
        echo_warning "⚠️  $temp_files temporary files still exist"
    else
        echo_success "✅ No temporary files found"
    fi
}

# Main cleanup function
main() {
    echo_info "🧹 Complete Gateway API + TinyLB Cleanup"
    echo_info "========================================"
    
    echo_warning "⚠️  This will remove ALL resources created by DEPLOY_ALL.sh"
    echo_warning "   - TinyLB controller will be stopped"
    echo_warning "   - Namespace '$NAMESPACE' will be deleted"
    echo_warning "   - All Gateway API resources will be removed"
    echo_warning "   - All certificates will be removed"
    echo_warning "   - Service Mesh configuration will be cleaned up"
    echo_warning "   - All temporary files will be removed"
    echo_warning ""
    
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Cleanup cancelled"
        exit 0
    fi
    
    echo_info "Starting cleanup..."
    
    # Step 1: Stop TinyLB Controller
    stop_tinylb_controller
    
    # Step 2: Remove routes (before namespace deletion)
    remove_routes
    
    # Step 3: Remove Gateway API resources
    remove_gateway_resources
    
    # Step 4: Remove certificates
    remove_certificates
    
    # Step 5: Clean up Service Mesh configuration
    cleanup_service_mesh
    
    # Step 6: Remove application resources
    remove_application
    
    # Step 7: Remove namespace
    remove_namespace
    
    # Step 8: Clean up TinyLB RBAC
    cleanup_tinylb_rbac
    
    # Step 9: Clean up temporary files
    cleanup_temp_files
    
    # Step 10: DNS cleanup info
    cleanup_dns_info
    
    # Step 11: Verify cleanup
    verify_cleanup
    
    echo_success "✅ Cleanup Complete!"
    echo_info "==================="
    echo_info "All Gateway API and TinyLB resources have been removed."
    echo_info ""
    echo_info "Note: If you manually modified /etc/hosts, you may want to clean up DNS entries."
    echo_info "Service Mesh 3.0 control plane is left running (not removed)."
}

# Handle script interruption
cleanup_on_exit() {
    echo_info "Cleanup interrupted - stopping TinyLB controller..."
    stop_tinylb_controller
}

trap cleanup_on_exit INT TERM

# Run main function
main "$@" 