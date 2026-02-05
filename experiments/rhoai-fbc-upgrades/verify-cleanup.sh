#!/bin/bash
#
# Verify RHOAI cleanup completion
#

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

log_info "RHOAI Cleanup Verification"
log_info "============================="
log_info ""
log_info "Cluster: $(oc whoami --show-server)"
log_info ""

ALL_CLEAR=true

# Check CRDs
log_info "Checking CRDs..."
CRD_COUNT=$(oc get crds -o name 2>/dev/null | grep -c opendatahub.io || echo 0)
if [ "$CRD_COUNT" -eq 0 ]; then
    log_success "No RHOAI CRDs found"
else
    log_error "$CRD_COUNT RHOAI CRDs still present:"
    oc get crds -o name | grep opendatahub.io | sed 's/^/  /'
    ALL_CLEAR=false
fi

# Check namespaces
log_info ""
log_info "Checking namespaces..."
for ns in redhat-ods-operator redhat-ods-applications redhat-ods-monitoring; do
    if oc get namespace $ns >/dev/null 2>&1; then
        STATUS=$(oc get namespace $ns -o jsonpath='{.status.phase}')
        if [ "$STATUS" = "Terminating" ]; then
            log_warn "Namespace $ns is Terminating (may take time)"
        else
            log_error "Namespace $ns still exists (Status: $STATUS)"
        fi
        ALL_CLEAR=false
    else
        log_success "Namespace $ns removed"
    fi
done

# Check catalog sources
log_info ""
log_info "Checking catalog sources..."
CATALOG_COUNT=$(oc get catalogsource -n openshift-marketplace -o name 2>/dev/null | grep -c rhoai || echo 0)
if [ "$CATALOG_COUNT" -eq 0 ]; then
    log_success "No RHOAI catalog sources found"
else
    log_error "$CATALOG_COUNT RHOAI catalog sources still present:"
    oc get catalogsource -n openshift-marketplace | grep rhoai | sed 's/^/  /'
    ALL_CLEAR=false
fi

# Check for any remaining RHOAI pods
log_info ""
log_info "Checking for RHOAI pods..."
PODS=$(oc get pods -A -o wide 2>/dev/null | grep -E "rhods|opendatahub" || true)
if [ -z "$PODS" ]; then
    log_success "No RHOAI pods found"
else
    log_warn "RHOAI-related pods still running:"
    echo "$PODS" | sed 's/^/  /'
    ALL_CLEAR=false
fi

# Summary
log_info ""
log_info "============================="
if [ "$ALL_CLEAR" = true ]; then
    log_success "Cleanup complete! Cluster is clean."
    log_info ""
    log_info "Ready to install RHOAI v2 for upgrade testing."
else
    log_warn "Cleanup incomplete. Some resources remain."
    log_info ""
    log_info "If namespaces are stuck in Terminating state:"
    log_info "  1. Wait a few more minutes"
    log_info "  2. Or run: ./full-cleanup-rhoai.sh again"
fi
log_info ""
