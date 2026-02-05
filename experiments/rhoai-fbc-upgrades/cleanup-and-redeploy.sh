#!/bin/bash
#
# Cleanup failed deployment and redeploy with fixed bundle
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

log_info "Cleaning up failed deployment..."

# Delete Subscription
log_info "Deleting Subscription..."
oc delete subscription rhods-operator -n redhat-ods-operator --ignore-not-found=true
log_success "Subscription deleted"

# Delete InstallPlan
log_info "Deleting InstallPlan..."
oc delete installplan --all -n redhat-ods-operator --ignore-not-found=true
log_success "InstallPlan deleted"

# Delete CSV if exists
log_info "Deleting CSV..."
oc delete csv --all -n redhat-ods-operator --ignore-not-found=true
log_success "CSV deleted"

# Delete CatalogSource
log_info "Deleting old CatalogSource..."
oc delete catalogsource rhoai-custom-catalog -n openshift-marketplace --ignore-not-found=true
sleep 5
log_success "CatalogSource deleted"

log_info ""
log_success "Cleanup complete!"
log_info ""
log_warn "Now run: ./test-deployment.sh"
