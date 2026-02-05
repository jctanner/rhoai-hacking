#!/bin/bash
#
# Helper script to auto-populate the test-route.yaml with actual cluster values
#
# Usage: ./fill-route-values.sh [dashboard-cr-name] [namespace]
#

set -e

DASHBOARD_NAME="${1:-}"
NAMESPACE="${2:-}"

# Auto-detect Dashboard CR if not provided
if [ -z "$DASHBOARD_NAME" ]; then
  echo "Attempting to auto-detect Dashboard CR..."

  # Get all Dashboard CRs with namespace info
  DASHBOARD_INFO=$(oc get dashboard -A -o json 2>/dev/null)
  DASHBOARD_COUNT=$(echo "$DASHBOARD_INFO" | jq -r '.items | length')

  if [ "$DASHBOARD_COUNT" -eq 0 ]; then
    echo "ERROR: No Dashboard CRs found in cluster"
    echo "Please ensure Dashboard component is deployed first"
    exit 1
  elif [ "$DASHBOARD_COUNT" -eq 1 ]; then
    DASHBOARD_NAME=$(echo "$DASHBOARD_INFO" | jq -r '.items[0].metadata.name')
    NAMESPACE=$(echo "$DASHBOARD_INFO" | jq -r '.items[0].metadata.namespace')
    echo "  Found Dashboard CR: $DASHBOARD_NAME in namespace: $NAMESPACE"
  else
    echo "ERROR: Multiple Dashboard CRs found. Please specify which one to use:"
    echo "  $0 <dashboard-cr-name> [namespace]"
    echo ""
    echo "Available Dashboard CRs:"
    oc get dashboard -A 2>/dev/null
    exit 1
  fi
fi

# Dashboard CRs are cluster-scoped, so we need to find the deployment namespace
if [ -z "$NAMESPACE" ]; then
  echo "Attempting to auto-detect Dashboard deployment namespace..."

  # Dashboard CR is cluster-scoped (no namespace), so find where it deploys resources
  NAMESPACE=$(oc get deployment -A -l platform.opendatahub.io/part-of=dashboard -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || echo "")

  if [ -z "$NAMESPACE" ]; then
    echo "WARNING: Dashboard deployment not found yet. Using default: opendatahub"
    NAMESPACE="opendatahub"
  else
    echo "  Found Dashboard deployment in namespace: $NAMESPACE"
  fi
fi

echo "Fetching Dashboard CR details..."
echo "  Name: $DASHBOARD_NAME (cluster-scoped)"
echo "  Deployment Namespace: $NAMESPACE"

# Get Dashboard CR UID (Dashboard is cluster-scoped, no namespace needed)
DASHBOARD_UID=$(oc get dashboard "$DASHBOARD_NAME" -o jsonpath='{.metadata.uid}' 2>/dev/null)
if [ -z "$DASHBOARD_UID" ]; then
  echo "ERROR: Could not get UID for Dashboard CR '$DASHBOARD_NAME'"
  exit 1
fi

echo "  UID: $DASHBOARD_UID"

# Get platform type (ODH or RHOAI)
PLATFORM_TYPE=$(oc get dashboard "$DASHBOARD_NAME" \
  -o jsonpath='{.metadata.annotations.platform\.opendatahub\.io/type}' 2>/dev/null || echo "OpenDataHub")

if [ -z "$PLATFORM_TYPE" ]; then
  echo "  Platform type not found in annotations, using default: OpenDataHub"
  PLATFORM_TYPE="OpenDataHub"
else
  echo "  Platform type: $PLATFORM_TYPE"
fi

# Create filled manifest
OUTPUT_FILE="test-route-filled.yaml"
echo ""
echo "Creating filled manifest: $OUTPUT_FILE"

sed -e "s/<DASHBOARD_UID>/$DASHBOARD_UID/g" \
    -e "s/<DASHBOARD_NAME>/$DASHBOARD_NAME/g" \
    -e "s/<NAMESPACE>/$NAMESPACE/g" \
    -e "s/platform.opendatahub.io\/type: \"OpenDataHub\"/platform.opendatahub.io\/type: \"$PLATFORM_TYPE\"/g" \
    test-route.yaml > "$OUTPUT_FILE"

echo ""
echo "✓ Created: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the manifest: cat $OUTPUT_FILE"
echo "  2. Apply the Route: oc apply -f $OUTPUT_FILE"
echo "  3. Trigger Dashboard reconciliation: oc annotate dashboard $DASHBOARD_NAME test-gc=\$(date +%s) --overwrite"
echo "  4. Watch the Route get deleted: oc get route odh-dashboard -n $NAMESPACE -w"
echo ""
echo "Expected behavior:"
echo "  - GC finds Route (has label: platform.opendatahub.io/part-of=dashboard)"
echo "  - GC checks ownership (has ownerReference to Dashboard CR) ✓"
echo "  - GC detects version mismatch (annotation shows old version)"
echo "  - GC deletes the Route automatically"
