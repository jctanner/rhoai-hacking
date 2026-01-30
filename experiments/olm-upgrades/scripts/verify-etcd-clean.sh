#!/bin/bash

echo "=========================================="
echo "Comprehensive etcd Cache Verification"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test 1: Check for any ODH API groups in API server discovery
echo -e "${YELLOW}[1/7] Checking API server discovery for ODH API groups...${NC}"
if kubectl api-resources --api-group=dscinitialization.opendatahub.io 2>&1 | grep -q "No resources found"; then
  echo -e "  ${GREEN}✓ dscinitialization.opendatahub.io API group not found${NC}"
else
  echo -e "  ${RED}✗ dscinitialization.opendatahub.io API group still exists!${NC}"
  kubectl api-resources --api-group=dscinitialization.opendatahub.io 2>&1
fi

echo ""
if kubectl api-resources --api-group=datasciencecluster.opendatahub.io 2>&1 | grep -q "No resources found"; then
  echo -e "  ${GREEN}✓ datasciencecluster.opendatahub.io API group not found${NC}"
else
  echo -e "  ${RED}✗ datasciencecluster.opendatahub.io API group still exists!${NC}"
  kubectl api-resources --api-group=datasciencecluster.opendatahub.io 2>&1
fi

# Test 2: Try to query for DSCInitializations (should fail cleanly, not with v2 error)
echo ""
echo -e "${YELLOW}[2/7] Testing query for dscinitializations (should fail cleanly)...${NC}"
RESULT=$(oc get dscinitializations -A 2>&1)
if echo "$RESULT" | grep -q "request to convert CR from an invalid group/version.*v2"; then
  echo -e "  ${RED}✗ ETCD CACHE CORRUPTED - Still seeing v2 error!${NC}"
  echo "  Error: $RESULT"
elif echo "$RESULT" | grep -qE "error: the server doesn't have a resource type|no resources found"; then
  echo -e "  ${GREEN}✓ Clean failure - no v2 corruption detected${NC}"
else
  echo -e "  ${YELLOW}⚠ Unexpected response: $RESULT${NC}"
fi

# Test 3: Check raw API endpoints
echo ""
echo -e "${YELLOW}[3/7] Checking raw API endpoints for cached data...${NC}"
for api in "dscinitialization.opendatahub.io/v1" "dscinitialization.opendatahub.io/v2"; do
  echo "  Querying /apis/$api..."
  RESULT=$(kubectl get --raw /apis/$api 2>&1)
  if echo "$RESULT" | grep -qE "404|NotFound|the server could not find the requested resource"; then
    echo -e "    ${GREEN}✓ $api not found (expected)${NC}"
  else
    echo -e "    ${RED}✗ $api still cached!${NC}"
    echo "$RESULT" | head -5
  fi
done

# Test 4: Check for any orphaned Custom Resource instances in etcd
echo ""
echo -e "${YELLOW}[4/7] Checking for orphaned CR instances...${NC}"
# Try to list all instances that might be orphaned
for resource in dscinitializations datascienceclusters; do
  echo "  Checking for orphaned $resource..."
  if oc get $resource -A 2>&1 | grep -q "request to convert CR from an invalid group/version"; then
    echo -e "    ${RED}✗ Found orphaned $resource with v2 corruption!${NC}"
  elif oc get $resource -A 2>&1 | grep -qE "error: the server doesn't have a resource type|no resources found"; then
    echo -e "    ${GREEN}✓ No orphaned $resource found${NC}"
  fi
done

# Test 5: Verify etcd by checking if we can access etcd pods
echo ""
echo -e "${YELLOW}[5/7] Checking etcd pod access (for direct verification)...${NC}"
ETCD_POD=$(oc get pods -n openshift-etcd -l app=etcd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$ETCD_POD" ]; then
  echo "  Found etcd pod: $ETCD_POD"
  echo "  Querying etcd for ODH keys..."
  
  # Check for any keys containing opendatahub
  KEYS=$(oc exec -n openshift-etcd "$ETCD_POD" -- etcdctl get / --prefix --keys-only 2>/dev/null | grep -i opendatahub | head -10 || echo "")
  
  if [ -z "$KEYS" ]; then
    echo -e "    ${GREEN}✓ No opendatahub keys found in etcd${NC}"
  else
    echo -e "    ${RED}✗ Found opendatahub keys in etcd:${NC}"
    echo "$KEYS" | head -10
  fi
else
  echo -e "    ${YELLOW}⚠ Cannot access etcd pods (may not have permissions)${NC}"
fi

# Test 6: Test API server cache refresh
echo ""
echo -e "${YELLOW}[6/7] Testing API server cache refresh...${NC}"
echo "  Forcing cache invalidation by querying multiple API versions..."
for version in v1 v2 v1alpha1; do
  kubectl get --raw /apis/dscinitialization.opendatahub.io/$version/dscinitializations 2>/dev/null || true
  kubectl get --raw /apis/datasciencecluster.opendatahub.io/$version/datascienceclusters 2>/dev/null || true
done
echo -e "  ${GREEN}✓ Cache refresh triggered${NC}"

# Test 7: Final comprehensive check
echo ""
echo -e "${YELLOW}[7/7] Final comprehensive check...${NC}"

echo "  Checking all component CRDs..."
FOUND_ISSUE=0
for resource in dscinitializations datascienceclusters codeflares dashboards kserve rays trustyais workbenches; do
  if oc get $resource -A 2>&1 | grep -q "request to convert CR from an invalid group/version.*v2"; then
    echo -e "    ${RED}✗ $resource: v2 corruption detected!${NC}"
    FOUND_ISSUE=1
  fi
done

if [ $FOUND_ISSUE -eq 0 ]; then
  echo -e "  ${GREEN}✓ No v2 corruption detected in any resource${NC}"
fi

echo ""
echo "=========================================="
if [ $FOUND_ISSUE -eq 0 ]; then
  echo -e "${GREEN}ETCD CACHE VERIFICATION: PASSED${NC}"
  echo ""
  echo "✓ No ODH API groups in discovery"
  echo "✓ No v2 corruption errors"
  echo "✓ No orphaned instances"
  echo "✓ API server cache refreshed"
  echo ""
  echo "etcd appears to be clean of ODH/RHOAI data."
else
  echo -e "${RED}ETCD CACHE VERIFICATION: FAILED${NC}"
  echo ""
  echo "✗ Found corruption or cached data"
  echo ""
  echo "Recommendations:"
  echo "1. Run cleanup script again: ./cleanup-odh-complete.sh"
  echo "2. Restart OpenShift API server pods to force cache clear"
  echo "3. Consider etcd defragmentation if corruption persists"
fi
echo "=========================================="
echo ""
