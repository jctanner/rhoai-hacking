#!/bin/bash
#
# Test Deployment of Custom RHOAI Catalog
#
# Deploys the custom-built catalog and operator to a test cluster
#

set -e

REGISTRY="registry.tannerjc.net"
REGISTRY_ORG="rhoai-upgrade"
VERSION="3.3.0"
CATALOG_IMG="${REGISTRY}/${REGISTRY_ORG}/rhods-operator-catalog:v${VERSION}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "RHOAI Custom Catalog Deployment Test"
log_info "====================================="
log_info ""
log_info "Cluster: $(oc whoami --show-server)"
log_info "User:    $(oc whoami)"
log_info "Catalog: $CATALOG_IMG"
log_info ""

# Step 1: Create CatalogSource
log_info "Step 1: Creating CatalogSource..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhoai-custom-catalog
  namespace: openshift-marketplace
spec:
  displayName: RHOAI Custom Catalog
  sourceType: grpc
  image: ${CATALOG_IMG}
  publisher: Custom Build
  updateStrategy:
    registryPoll:
      interval: 10m
EOF

log_success "CatalogSource created"

# Step 2: Wait for catalog to be ready
log_info ""
log_info "Step 2: Waiting for catalog pod to be ready..."
sleep 5

for i in {1..30}; do
    POD_STATUS=$(oc get pods -n openshift-marketplace -l olm.catalogSource=rhoai-custom-catalog -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$POD_STATUS" = "Running" ]; then
        log_success "Catalog pod is running"
        break
    fi
    log_info "  Waiting... (${i}/30) Status: $POD_STATUS"
    sleep 2
done

# Check catalog status
CATALOG_STATUS=$(oc get catalogsource rhoai-custom-catalog -n openshift-marketplace -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null || echo "UNKNOWN")
if [ "$CATALOG_STATUS" = "READY" ]; then
    log_success "Catalog is READY"
else
    log_warn "Catalog status: $CATALOG_STATUS"
    log_info "Catalog pod logs:"
    oc logs -n openshift-marketplace -l olm.catalogSource=rhoai-custom-catalog --tail=20 || true
fi

# Step 3: Check if package is available
log_info ""
log_info "Step 3: Checking if rhods-operator package is available..."
sleep 3
if oc get packagemanifest rhods-operator -n openshift-marketplace >/dev/null 2>&1; then
    log_success "Package rhods-operator is available"
    log_info "Available channels:"
    oc get packagemanifest rhods-operator -n openshift-marketplace -o jsonpath='{.status.channels[*].name}' | tr ' ' '\n' | sed 's/^/  - /'
else
    log_error "Package rhods-operator not found in catalog"
    log_info "Available packages:"
    oc get packagemanifests -n openshift-marketplace | grep custom || true
    exit 1
fi

# Step 4: Create operator namespace
log_info ""
log_info "Step 4: Creating operator namespace..."
if oc get namespace redhat-ods-operator >/dev/null 2>&1; then
    log_warn "Namespace redhat-ods-operator already exists"
else
    oc create namespace redhat-ods-operator
    log_success "Namespace created"
fi

# Step 5: Create OperatorGroup
log_info ""
log_info "Step 5: Creating OperatorGroup (AllNamespaces mode)..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator-group
  namespace: redhat-ods-operator
spec: {}
EOF

log_success "OperatorGroup created (watches all namespaces)"

# Step 6: Create Subscription
log_info ""
log_info "Step 6: Creating Subscription..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: stable
  name: rhods-operator
  source: rhoai-custom-catalog
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

log_success "Subscription created with Automatic approval"

# Step 7: Monitor installation (Automatic approval)
log_info ""
log_info "Step 7: Monitoring installation (automatic approval enabled)..."
sleep 10

for i in {1..30}; do
    CSV_PHASE=$(oc get csv rhods-operator.v3.3.0 -n redhat-ods-operator -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

    if [ "$CSV_PHASE" = "NotFound" ]; then
        log_info "  Waiting for CSV... (${i}/30)"
    else
        log_info "  CSV Phase: $CSV_PHASE (${i}/30)"
    fi

    if [ "$CSV_PHASE" = "Succeeded" ]; then
        log_success "Operator installed successfully!"
        break
    elif [ "$CSV_PHASE" = "Failed" ]; then
        log_error "CSV installation failed"
        log_info "Failure reason:"
        oc get csv rhods-operator.v3.3.0 -n redhat-ods-operator -o jsonpath='{.status.reason}' && echo
        oc get csv rhods-operator.v3.3.0 -n redhat-ods-operator -o jsonpath='{.status.message}'
        echo ""
        exit 1
    fi
    sleep 5
done

if [ "$CSV_PHASE" != "Succeeded" ]; then
    log_error "Installation timed out after 150 seconds"
    exit 1
fi

log_info ""
log_info "Operator pod status:"
oc get pods -n redhat-ods-operator

log_info ""
log_info "Operator image:"
oc get deployment rhods-operator -n redhat-ods-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

log_info ""
log_info "RELATED_IMAGE variables count:"
oc get deployment rhods-operator -n redhat-ods-operator -o json | jq '[.spec.template.spec.containers[0].env[] | select(.name | startswith("RELATED_IMAGE"))] | length'

log_info ""
log_success "====================================="
log_success "Deployment test complete!"
log_success "====================================="
log_info ""
log_info "Verify with:"
log_info "  oc get csv -n redhat-ods-operator"
log_info "  oc get pods -n redhat-ods-operator"
log_info "  oc logs -n redhat-ods-operator deployment/rhods-operator"
