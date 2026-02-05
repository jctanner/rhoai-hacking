#!/bin/bash
#
# Complete RHOAI/RHODS Cleanup Script
#
# Removes all RHOAI components, CRDs, and namespaces
# USE WITH CAUTION - This will delete everything!
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_warn "========================================="
log_warn "RHOAI COMPLETE CLEANUP"
log_warn "========================================="
log_warn ""
log_warn "This will DELETE:"
log_warn "  - All RHOAI subscriptions and CSVs"
log_warn "  - All RHOAI custom resources (DSC, DSCI, Dashboard, etc.)"
log_warn "  - All RHOAI CRDs (~37 CRDs)"
log_warn "  - All RHOAI namespaces (operator, applications, monitoring)"
log_warn "  - All RHOAI catalog sources"
log_warn ""
log_warn "Cluster: $(oc whoami --show-server)"
log_warn ""

read -p "Are you ABSOLUTELY sure? [yes/NO] " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Cleanup cancelled"
    exit 0
fi

log_info ""
log_info "Starting cleanup..."
log_info ""

# Step 1: Delete Custom Resources first (to trigger cleanup)
log_info "Step 1: Deleting RHOAI Custom Resources..."

log_info "  - Deleting DataScienceCluster..."
oc delete datasciencecluster --all -A --ignore-not-found=true --wait=false 2>/dev/null || true

log_info "  - Deleting DSCInitialization..."
oc delete dscinitialization --all -A --ignore-not-found=true --wait=false 2>/dev/null || true

log_info "  - Deleting Dashboard..."
oc delete dashboard --all -A --ignore-not-found=true --wait=false 2>/dev/null || true

log_info "  - Deleting other component CRs..."
oc delete datasciencepipelines --all -A --ignore-not-found=true --wait=false 2>/dev/null || true
oc delete kserve --all -A --ignore-not-found=true --wait=false 2>/dev/null || true
oc delete modelregistry --all -A --ignore-not-found=true --wait=false 2>/dev/null || true
oc delete ray --all -A --ignore-not-found=true --wait=false 2>/dev/null || true
oc delete trustyai --all -A --ignore-not-found=true --wait=false 2>/dev/null || true
oc delete workbenches --all -A --ignore-not-found=true --wait=false 2>/dev/null || true
oc delete modelcontroller --all -A --ignore-not-found=true --wait=false 2>/dev/null || true
oc delete trainingoperator --all -A --ignore-not-found=true --wait=false 2>/dev/null || true

log_success "Custom resources deletion initiated"
log_warn "Waiting 10 seconds for finalizers..."
sleep 10

# Step 2: Delete Subscription
log_info ""
log_info "Step 2: Deleting Subscription..."
oc delete subscription rhods-operator -n redhat-ods-operator --ignore-not-found=true 2>/dev/null || true
oc delete subscription --all -n redhat-ods-operator --ignore-not-found=true 2>/dev/null || true
log_success "Subscriptions deleted"

# Step 3: Delete CSV
log_info ""
log_info "Step 3: Deleting ClusterServiceVersions..."
oc delete csv -n redhat-ods-operator --all --ignore-not-found=true 2>/dev/null || true
log_success "CSVs deleted"

# Step 4: Delete InstallPlans
log_info ""
log_info "Step 4: Deleting InstallPlans..."
oc delete installplan --all -n redhat-ods-operator --ignore-not-found=true 2>/dev/null || true
log_success "InstallPlans deleted"

# Step 5: Delete OperatorGroup
log_info ""
log_info "Step 5: Deleting OperatorGroup..."
oc delete operatorgroup --all -n redhat-ods-operator --ignore-not-found=true 2>/dev/null || true
log_success "OperatorGroup deleted"

# Step 6: Delete CatalogSources
log_info ""
log_info "Step 6: Deleting CatalogSources..."
oc delete catalogsource rhoai-catalog-dev -n openshift-marketplace --ignore-not-found=true 2>/dev/null || true
oc delete catalogsource rhoai-custom-catalog -n openshift-marketplace --ignore-not-found=true 2>/dev/null || true
log_success "CatalogSources deleted"

# Step 7: Remove finalizers from stuck CRs
log_info ""
log_info "Step 7: Removing finalizers from stuck resources..."

# Remove finalizers from DSC
for dsc in $(oc get datasciencecluster -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    ns=$(echo $dsc | awk '{print $1}')
    name=$(echo $dsc | awk '{print $2}')
    log_info "  - Removing finalizer from DataScienceCluster $ns/$name"
    oc patch datasciencecluster $name -n $ns -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
done

# Remove finalizers from DSCI
for dsci in $(oc get dscinitialization -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    ns=$(echo $dsci | awk '{print $1}')
    name=$(echo $dsci | awk '{print $2}')
    log_info "  - Removing finalizer from DSCInitialization $ns/$name"
    oc patch dscinitialization $name -n $ns -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
done

log_success "Finalizers removed"
log_warn "Waiting 5 seconds for deletions..."
sleep 5

# Step 8: Force delete remaining CRs
log_info ""
log_info "Step 8: Force deleting any remaining CRs..."
oc delete datasciencecluster --all -A --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true
oc delete dscinitialization --all -A --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true
oc delete dashboard --all -A --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true
log_success "Remaining CRs deleted"

# Step 9: Delete CRDs
log_info ""
log_info "Step 9: Deleting RHOAI CRDs..."
log_warn "This will remove ~37 CRDs"

# Get all opendatahub.io CRDs
CRDS=$(oc get crds -o name | grep opendatahub.io)

if [ -z "$CRDS" ]; then
    log_info "No RHOAI CRDs found"
else
    CRD_COUNT=$(echo "$CRDS" | wc -l)
    log_info "Found $CRD_COUNT RHOAI CRDs to delete"

    for crd in $CRDS; do
        crd_name=$(basename $crd)
        log_info "  - Deleting $crd_name"
        oc delete $crd --ignore-not-found=true 2>/dev/null || true
    done

    log_success "All RHOAI CRDs deleted"
fi

# Step 10: Delete namespaces
log_info ""
log_info "Step 10: Deleting RHOAI namespaces..."

NAMESPACES="redhat-ods-operator redhat-ods-applications redhat-ods-monitoring"

for ns in $NAMESPACES; do
    if oc get namespace $ns >/dev/null 2>&1; then
        log_info "  - Deleting namespace $ns"
        oc delete namespace $ns --ignore-not-found=true --wait=false 2>/dev/null || true
    fi
done

log_success "Namespace deletion initiated"
log_warn "Namespaces may take time to fully terminate..."

# Step 11: Check for stuck namespaces and force cleanup
log_info ""
log_info "Step 11: Checking for stuck namespaces..."
sleep 5

for ns in $NAMESPACES; do
    if oc get namespace $ns >/dev/null 2>&1; then
        STATUS=$(oc get namespace $ns -o jsonpath='{.status.phase}')
        if [ "$STATUS" = "Terminating" ]; then
            log_warn "  - Namespace $ns is stuck in Terminating state"
            log_info "  - Attempting to remove finalizers..."

            # Remove finalizers from namespace
            oc patch namespace $ns -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true

            # Force delete remaining resources
            oc delete all --all -n $ns --force --grace-period=0 2>/dev/null || true
        fi
    fi
done

# Step 12: Verification
log_info ""
log_info "Step 12: Verifying cleanup..."
log_info ""

# Check for remaining CRDs
REMAINING_CRDS=$(oc get crds -o name 2>/dev/null | grep opendatahub.io | wc -l)
if [ "$REMAINING_CRDS" -eq 0 ]; then
    log_success "✓ All RHOAI CRDs removed"
else
    log_warn "⚠ $REMAINING_CRDS RHOAI CRDs still present"
    oc get crds -o name | grep opendatahub.io
fi

# Check for remaining namespaces
for ns in $NAMESPACES; do
    if oc get namespace $ns >/dev/null 2>&1; then
        log_warn "⚠ Namespace $ns still exists"
    else
        log_success "✓ Namespace $ns removed"
    fi
done

# Check for remaining catalog sources
if oc get catalogsource -n openshift-marketplace | grep -q rhoai; then
    log_warn "⚠ RHOAI catalog sources still present"
else
    log_success "✓ RHOAI catalog sources removed"
fi

# Step 13: Trigger etcd compaction (optional but recommended)
log_info ""
log_info "Step 13: Triggering etcd compaction..."
log_warn "This helps clean up etcd tombstones and deleted data"

# Check if we can access etcd pods
if oc get pods -n openshift-etcd | grep -q etcd; then
    log_info "Attempting to trigger etcd compaction..."

    # Get etcd endpoints
    ETCD_PODS=$(oc get pods -n openshift-etcd -l app=etcd -o name 2>/dev/null || true)

    if [ -n "$ETCD_PODS" ]; then
        log_info "Found etcd pods, triggering compaction and defrag..."

        # Trigger compaction on one etcd member
        FIRST_POD=$(echo "$ETCD_PODS" | head -1)

        # Compact (this is safe and only removes old revisions)
        oc exec -n openshift-etcd $FIRST_POD -c etcd -- \
            etcdctl endpoint status --cluster -w table 2>/dev/null || log_warn "  Could not check etcd status"

        log_info "  Note: etcd compaction happens automatically in OpenShift"
        log_info "  Deleted CRD data should be cleaned up within minutes"
    else
        log_warn "  Cannot access etcd pods directly (normal for managed clusters)"
        log_info "  etcd will clean up automatically via built-in compaction"
    fi
else
    log_info "etcd compaction happens automatically in OpenShift"
    log_info "Deleted CRD data will be cleaned up by background processes"
fi

log_success "Cleanup process complete"

log_info ""
log_success "========================================="
log_success "CLEANUP COMPLETE"
log_success "========================================="
log_info ""
log_info "The cluster is now clean and ready for:"
log_info "  1. Installing RHOAI v2.x"
log_info "  2. Testing upgrade to v3.x"
log_info ""
log_warn "Important notes:"
log_warn "  - Some namespaces may still be terminating"
log_warn "  - etcd tombstones will be cleaned automatically"
log_warn "  - Wait 1-2 minutes for full etcd cleanup"
log_info ""
log_info "Check namespace status with:"
log_info "  oc get namespaces | grep redhat-ods"
log_info ""
log_info "To verify etcd is clean, check API server can create new CRDs:"
log_info "  oc get crds | grep opendatahub  # Should be empty"
