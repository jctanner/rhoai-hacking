#!/bin/bash
set -e

REGISTRY="registry.tannerjc.net/opendatahub"
BUNDLE_IMG="${REGISTRY}/rhods-operator-bundle:v3.0.0"
NAMESPACE="redhat-ods-operator"

echo "============================================"
echo "Upgrading to v3.0.0 Operator"
echo "============================================"
echo "Bundle: ${BUNDLE_IMG}"
echo "Namespace: ${NAMESPACE}"
echo "============================================"
echo ""
echo "This bundle includes:"
echo "  - Conversion webhook fix (from main branch rebase)"
echo "  - OdhDashboardConfig error handling fix"
echo ""

# Verify v2.25.0 is installed
echo "Checking for v2.25.0 installation..."
if ! oc get csv rhods-operator.v2.25.0 -n ${NAMESPACE} >/dev/null 2>&1; then
    echo "ERROR: v2.25.0 is not installed. Please run install-v2.25.0.sh first."
    exit 1
fi

echo "Found v2.25.0, proceeding with upgrade..."
echo ""

# Upgrade to v3.0.0
operator-sdk run bundle-upgrade ${BUNDLE_IMG} --namespace ${NAMESPACE} --timeout 10m

echo ""
echo "============================================"
echo "Upgrade complete!"
echo "============================================"
echo ""
echo "Check status with:"
echo "  oc get csv -n ${NAMESPACE}"
echo "  oc get pods -n ${NAMESPACE}"
echo "  oc get dscinitializations -A"
echo ""
echo "Watch operator logs for OdhDashboardConfig handling:"
echo "  oc logs -n ${NAMESPACE} -l app.kubernetes.io/name=rhods-operator --tail=100 -f"
echo ""
