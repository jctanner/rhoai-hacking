#!/bin/bash
set -e

REGISTRY="registry.tannerjc.net/opendatahub"
BUNDLE_IMG="${REGISTRY}/opendatahub-operator-bundle:v2.25.0"
NAMESPACE="opendatahub-operator-system"

echo "============================================"
echo "Installing v2.25.0 Operator"
echo "============================================"
echo "Bundle: ${BUNDLE_IMG}"
echo "Namespace: ${NAMESPACE}"
echo "============================================"
echo ""

# Ensure namespace exists
oc get namespace ${NAMESPACE} >/dev/null 2>&1 || oc create namespace ${NAMESPACE}

# Install v2.25.0
operator-sdk run bundle ${BUNDLE_IMG} --namespace ${NAMESPACE} --timeout 10m

echo ""
echo "============================================"
echo "Installation complete!"
echo "============================================"
echo ""
echo "Check status with:"
echo "  oc get csv,pods -n ${NAMESPACE}"
echo "  oc get dscinitializations -A"
echo ""
