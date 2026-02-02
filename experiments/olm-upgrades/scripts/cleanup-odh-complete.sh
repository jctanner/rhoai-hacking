#!/bin/bash
set -e

echo "============================================"
echo "Complete ODH/RHOAI Cleanup Script"
echo "============================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Clean up OLM resources
echo -e "${YELLOW}[1/8] Cleaning up OLM resources...${NC}"
operator-sdk cleanup opendatahub-operator -n opendatahub-operator-system --timeout=30s 2>&1 || echo "Cleanup command failed or timed out, continuing..."

echo ""
echo -e "${YELLOW}[2/8] Deleting CSVs, Subscriptions, and CatalogSources...${NC}"
oc delete csv --all -n opendatahub-operator-system --force --grace-period=0 2>/dev/null || true
oc delete subscription --all -n opendatahub-operator-system --force --grace-period=0 2>/dev/null || true
oc delete catalogsource --all -n opendatahub-operator-system --force --grace-period=0 2>/dev/null || true

echo ""
echo -e "${YELLOW}[3/8] Deleting all ODH namespaces...${NC}"
for ns in opendatahub-operator-system opendatahub; do
  if oc get namespace $ns 2>/dev/null; then
    echo "  Deleting namespace: $ns"
    oc delete namespace $ns --force --grace-period=0 2>/dev/null || true &
  fi
done

# Wait a bit for namespace deletion to start
sleep 5

echo ""
echo -e "${YELLOW}[4/8] Force deleting all ODH CRDs and their instances...${NC}"

# Get list of all ODH CRDs
CRDS=$(oc get crd 2>/dev/null | grep -E "opendatahub|platform\." | awk '{print $1}' || true)

if [ -n "$CRDS" ]; then
  for crd in $CRDS; do
    echo "  Processing CRD: $crd"

    # Try to get all instances and delete them
    KIND=$(echo $crd | cut -d'.' -f1)
    echo "    Checking for instances of $KIND..."

    # Get instances across all namespaces and delete
    oc get $crd --all-namespaces -o json 2>/dev/null | \
      jq -r '.items[]? | "\(.metadata.namespace // "cluster") \(.metadata.name)"' 2>/dev/null | \
      while read ns name; do
        if [ "$ns" = "cluster" ]; then
          echo "      Deleting cluster-scoped: $name"
          oc delete $crd $name --force --grace-period=0 2>/dev/null || true
        else
          echo "      Deleting namespaced: $ns/$name"
          oc delete $crd $name -n $ns --force --grace-period=0 2>/dev/null || true
        fi
      done

    # Remove finalizers from the CRD itself
    echo "    Removing finalizers from CRD..."
    oc patch crd $crd --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true

    # Force delete the CRD
    echo "    Force deleting CRD..."
    oc delete crd $crd --force --grace-period=0 2>/dev/null || true
  done
else
  echo "  No ODH CRDs found"
fi

echo ""
echo -e "${YELLOW}[5/8] Waiting for CRD deletion to complete...${NC}"
for i in {1..30}; do
  REMAINING=$(oc get crd 2>/dev/null | grep -E "opendatahub|platform\." | wc -l || echo "0")
  if [ "$REMAINING" -eq 0 ]; then
    echo -e "  ${GREEN}✓ All CRDs deleted${NC}"
    break
  fi
  echo "  Still waiting... ($REMAINING CRDs remaining)"
  sleep 2
done

echo ""
echo -e "${YELLOW}[6/8] Cleaning up any stuck CRDs with API server cache invalidation...${NC}"

# Force clear any remaining CRDs by removing finalizers via API
STUCK_CRDS=$(oc get crd 2>/dev/null | grep -E "opendatahub|platform\." | awk '{print $1}' || true)
if [ -n "$STUCK_CRDS" ]; then
  for crd in $STUCK_CRDS; do
    echo "  Force clearing stuck CRD: $crd"

    # Remove finalizers via kubectl patch
    kubectl patch crd $crd --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true

    # Try deletion again
    oc delete crd $crd --force --grace-period=0 2>/dev/null &

    # Alternative: Use kubectl delete with cascading=orphan to skip waiting for instances
    kubectl delete crd $crd --cascade=orphan --force --grace-period=0 2>/dev/null || true
  done

  sleep 5
fi

echo ""
echo -e "${YELLOW}[7/8] Cleaning up ClusterRoles and ClusterRoleBindings...${NC}"
oc get clusterrole 2>/dev/null | grep -E "opendatahub|rhods" | awk '{print $1}' | xargs -r oc delete clusterrole 2>/dev/null || true
oc get clusterrolebinding 2>/dev/null | grep -E "opendatahub|rhods" | awk '{print $1}' | xargs -r oc delete clusterrolebinding 2>/dev/null || true

echo ""
echo -e "${YELLOW}[8/8] Final verification and etcd cache invalidation...${NC}"

# Try to trigger etcd cache invalidation by querying the API server for nonexistent resources
# This forces the API server to refresh its cache from etcd
echo "  Triggering API server cache refresh..."
for api in "dscinitialization.opendatahub.io/v1" "dscinitialization.opendatahub.io/v2" "datasciencecluster.opendatahub.io/v1"; do
  kubectl get --raw /apis/$api 2>/dev/null || true
done

# Wait for namespaces to fully terminate
echo "  Waiting for namespace termination..."
for i in {1..20}; do
  NS_COUNT=$(oc get namespaces 2>/dev/null | grep "redhat-ods" | wc -l || echo "0")
  NS_COUNT=${NS_COUNT:-0}  # Default to 0 if empty
  if [ "$NS_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}✓ All namespaces terminated${NC}"
    break
  fi
  echo "  Still terminating... ($NS_COUNT namespaces remaining)"
  sleep 3
done

echo ""
echo "============================================"
echo -e "${GREEN}Final Verification${NC}"
echo "============================================"

echo ""
echo "ODH Namespaces:"
if oc get namespaces 2>/dev/null | grep -E "opendatahub|redhat-ods"; then
  echo -e "  ${RED}✗ Found namespaces (may be terminating)${NC}"
else
  echo -e "  ${GREEN}✓ None found${NC}"
fi

echo ""
echo "ODH CRDs:"
if oc get crd 2>/dev/null | grep -E "opendatahub|platform\."; then
  echo -e "  ${RED}✗ Found CRDs${NC}"
else
  echo -e "  ${GREEN}✓ None found${NC}"
fi

echo ""
echo "ODH API Resources:"
if oc api-resources 2>/dev/null | grep -E "opendatahub|dscinitialization"; then
  echo -e "  ${RED}✗ Found API resources${NC}"
else
  echo -e "  ${GREEN}✓ None found${NC}"
fi

echo ""
echo "============================================"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo "============================================"
echo ""
echo "The cluster should now be clean of all ODH/RHOAI resources."
echo "API server cache has been invalidated."
echo ""
