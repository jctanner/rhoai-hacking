#!/bin/bash

echo "=========================================="
echo "Checking All Cluster-Wide ODH Resources"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FOUND_RESOURCES=0

# Function to check and display resources
check_resource() {
  RESOURCE_TYPE=$1
  SEARCH_PATTERN=$2
  DESCRIPTION=$3
  
  echo -e "${YELLOW}Checking $DESCRIPTION...${NC}"
  RESULT=$(oc get $RESOURCE_TYPE -o name 2>/dev/null | grep -iE "$SEARCH_PATTERN" || echo "")
  
  if [ -z "$RESULT" ]; then
    echo -e "  ${GREEN}✓ None found${NC}"
  else
    echo -e "  ${RED}✗ Found resources:${NC}"
    echo "$RESULT" | sed 's/^/    /'
    FOUND_RESOURCES=$((FOUND_RESOURCES + 1))
  fi
  echo ""
}

# Check various cluster-wide resource types
check_resource "mutatingwebhookconfigurations" "opendatahub|rhods|odh" "MutatingWebhookConfigurations"
check_resource "validatingwebhookconfigurations" "opendatahub|rhods|odh" "ValidatingWebhookConfigurations"
check_resource "apiservices" "opendatahub|rhods|odh" "APIServices"
check_resource "clusterroles" "opendatahub|rhods|odh" "ClusterRoles"
check_resource "clusterrolebindings" "opendatahub|rhods|odh" "ClusterRoleBindings"
check_resource "priorityclasses" "opendatahub|rhods|odh" "PriorityClasses"
check_resource "storageclasses" "opendatahub|rhods|odh" "StorageClasses"
check_resource "ingressclasses" "opendatahub|rhods|odh" "IngressClasses"

# OpenShift-specific resources
echo -e "${YELLOW}Checking OpenShift-specific resources...${NC}"
check_resource "scc" "opendatahub|rhods|odh" "SecurityContextConstraints"
check_resource "consoleclidownloads" "opendatahub|rhods|odh" "ConsoleCLIDownloads"
check_resource "consolelinks" "opendatahub|rhods|odh" "ConsoleLinks"
check_resource "consolequickstarts" "opendatahub|rhods|odh" "ConsoleQuickStarts"
check_resource "consolenotifications" "opendatahub|rhods|odh" "ConsoleNotifications"

# Check for operator groups in other namespaces
echo -e "${YELLOW}Checking OperatorGroups in all namespaces...${NC}"
OG_RESULT=$(oc get operatorgroups --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("opendatahub|rhods|odh"; "i")) | "\(.metadata.namespace)/\(.metadata.name)"' || echo "")
if [ -z "$OG_RESULT" ]; then
  echo -e "  ${GREEN}✓ None found${NC}"
else
  echo -e "  ${RED}✗ Found OperatorGroups:${NC}"
  echo "$OG_RESULT" | sed 's/^/    /'
  FOUND_RESOURCES=$((FOUND_RESOURCES + 1))
fi
echo ""

# Check for service accounts in kube-system or openshift-* namespaces
echo -e "${YELLOW}Checking ServiceAccounts in system namespaces...${NC}"
SA_RESULT=$(oc get sa --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.metadata.namespace | test("^(kube-|openshift-)")) | select(.metadata.name | test("opendatahub|rhods|odh"; "i")) | "\(.metadata.namespace)/\(.metadata.name)"' || echo "")
if [ -z "$SA_RESULT" ]; then
  echo -e "  ${GREEN}✓ None found${NC}"
else
  echo -e "  ${RED}✗ Found ServiceAccounts:${NC}"
  echo "$SA_RESULT" | sed 's/^/    /'
  FOUND_RESOURCES=$((FOUND_RESOURCES + 1))
fi
echo ""

# Check for ConfigMaps in system namespaces
echo -e "${YELLOW}Checking ConfigMaps in system namespaces...${NC}"
CM_RESULT=$(oc get cm --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.metadata.namespace | test("^(kube-|openshift-)")) | select(.metadata.name | test("opendatahub|rhods|odh"; "i")) | "\(.metadata.namespace)/\(.metadata.name)"' || echo "")
if [ -z "$CM_RESULT" ]; then
  echo -e "  ${GREEN}✓ None found${NC}"
else
  echo -e "  ${RED}✗ Found ConfigMaps:${NC}"
  echo "$CM_RESULT" | sed 's/^/    /'
  FOUND_RESOURCES=$((FOUND_RESOURCES + 1))
fi
echo ""

# Check for Secrets in system namespaces
echo -e "${YELLOW}Checking Secrets in system namespaces...${NC}"
SECRET_RESULT=$(oc get secrets --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.metadata.namespace | test("^(kube-|openshift-)")) | select(.metadata.name | test("opendatahub|rhods|odh"; "i")) | "\(.metadata.namespace)/\(.metadata.name)"' || echo "")
if [ -z "$SECRET_RESULT" ]; then
  echo -e "  ${GREEN}✓ None found${NC}"
else
  echo -e "  ${RED}✗ Found Secrets:${NC}"
  echo "$SECRET_RESULT" | sed 's/^/    /'
  FOUND_RESOURCES=$((FOUND_RESOURCES + 1))
fi
echo ""

# Summary
echo "=========================================="
if [ $FOUND_RESOURCES -eq 0 ]; then
  echo -e "${GREEN}ALL CLUSTER-WIDE RESOURCES: CLEAN${NC}"
  echo ""
  echo "✓ No MutatingWebhookConfigurations"
  echo "✓ No ValidatingWebhookConfigurations"
  echo "✓ No APIServices"
  echo "✓ No ClusterRoles/ClusterRoleBindings"
  echo "✓ No SecurityContextConstraints"
  echo "✓ No Console resources"
  echo "✓ No system namespace resources"
  echo ""
  echo "Cluster is completely clean of ODH/RHOAI resources."
else
  echo -e "${RED}FOUND $FOUND_RESOURCES RESOURCE TYPE(S)${NC}"
  echo ""
  echo "These resources should be cleaned up before installation."
  echo "Run: ./cleanup-cluster-resources.sh"
fi
echo "=========================================="
echo ""
