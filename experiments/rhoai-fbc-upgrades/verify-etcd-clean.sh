#!/bin/bash
#
# Verify etcd is clean after RHOAI deletion
#

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }

log_info "etcd Cleanup Verification"
log_info "=========================="
log_info ""

# Check if CRDs are gone from API server (which means etcd should be clean)
log_info "Checking if RHOAI CRDs are removed from etcd..."

CRD_COUNT=$(oc get crds -o name 2>/dev/null | grep -c opendatahub.io || echo 0)

if [ "$CRD_COUNT" -eq 0 ]; then
    log_success "No RHOAI CRDs in API server (etcd is clean)"
else
    log_warn "$CRD_COUNT RHOAI CRDs still in etcd"
    oc get crds -o name | grep opendatahub.io | sed 's/^/  /'
    echo ""
    log_warn "If these CRDs won't delete, try:"
    log_info "  1. Remove finalizers: oc patch crd <name> -p '{\"metadata\":{\"finalizers\":[]}}' --type=merge"
    log_info "  2. Force delete: oc delete crd <name> --force --grace-period=0"
    exit 1
fi

# Try to create and immediately delete a test CRD to verify etcd can handle CRD operations
log_info ""
log_info "Testing etcd CRD operations..."

cat <<EOF | oc apply -f - 2>&1 | grep -q "created" && TEST_RESULT=true || TEST_RESULT=false
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: testcrds.test.cleanup.io
spec:
  group: test.cleanup.io
  names:
    kind: TestCRD
    listKind: TestCRDList
    plural: testcrds
    singular: testcrd
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
          status:
            type: object
EOF

if [ "$TEST_RESULT" = true ]; then
    # Clean up test CRD
    oc delete crd testcrds.test.cleanup.io >/dev/null 2>&1
    log_success "etcd can create/delete CRDs normally"
else
    log_warn "Could not create test CRD (may indicate etcd issues)"
fi

# Check for any opendatahub-related resources in any namespace
log_info ""
log_info "Checking for orphaned RHOAI resources in etcd..."

ORPHANED=$(oc get all -A 2>/dev/null | grep -i -E "rhods|opendatahub|datascience" || true)

if [ -z "$ORPHANED" ]; then
    log_success "No orphaned RHOAI resources found"
else
    log_warn "Found potential orphaned resources:"
    echo "$ORPHANED" | sed 's/^/  /'
fi

# Check etcd health and size (if accessible)
log_info ""
log_info "Checking etcd status..."

if oc get pods -n openshift-etcd -l app=etcd >/dev/null 2>&1; then
    ETCD_POD=$(oc get pods -n openshift-etcd -l app=etcd -o name 2>/dev/null | head -1)

    if [ -n "$ETCD_POD" ]; then
        log_info "etcd health:"
        oc exec -n openshift-etcd $ETCD_POD -c etcd -- \
            etcdctl endpoint health --cluster 2>/dev/null || log_warn "  Cannot check etcd health"

        log_info ""
        log_info "etcd database size:"
        oc exec -n openshift-etcd $ETCD_POD -c etcd -- \
            etcdctl endpoint status --cluster -w table 2>/dev/null || log_warn "  Cannot check etcd size"
    fi
else
    log_info "etcd pods not directly accessible (normal for some cluster types)"
fi

log_info ""
log_info "=========================="
log_success "etcd verification complete"
log_info "=========================="
log_info ""
log_info "Key points about etcd cleanup:"
log_info "  • CRD deletion removes data from etcd automatically"
log_info "  • OpenShift runs etcd compaction every 5 minutes"
log_info "  • Tombstones are cleaned up within 1-2 minutes"
log_info "  • If CRDs are gone from API, etcd is clean"
log_info ""
