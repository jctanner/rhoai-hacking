#!/bin/bash
set -e

REGISTRY="registry.tannerjc.net/opendatahub"
BUNDLE_IMG="${REGISTRY}/opendatahub-operator-bundle:v3.0.0"
NAMESPACE="opendatahub-operator-system"

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
echo "  - OpenDataHub branding and namespaces"
echo ""

# Verify v2.25.0 is installed
echo "Checking for v2.25.0 installation..."
if ! oc get csv opendatahub-operator.v2.25.0 -n ${NAMESPACE} >/dev/null 2>&1; then
    echo "ERROR: opendatahub-operator.v2.25.0 is not installed."
    echo "Please run ./scripts/install-v2.25.0.sh first."
    exit 1
fi

echo "Found opendatahub-operator.v2.25.0, proceeding with upgrade..."
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
echo "  oc get dsci,dsc -A"
echo ""
echo "Watch operator logs:"
echo "  oc logs -n ${NAMESPACE} -l control-plane=controller-manager --tail=100 -f"
echo ""
echo "Check dashboard:"
echo "  oc get pods -n opendatahub"
echo "  oc get route -n opendatahub odh-dashboard"
echo ""
