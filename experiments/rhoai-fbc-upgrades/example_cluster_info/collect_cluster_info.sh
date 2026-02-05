#!/bin/bash
#
# Cluster Information Collection Script
# Collects comprehensive cluster state for RHOAI upgrade analysis
#

set -e

OUTDIR="/home/jtanner/workspace/github/jctanner.redhat/2026_02_04_dashboard_route_garbage_cleanup/example_cluster_info"
cd "$OUTDIR"

echo "Starting cluster information collection..."
echo "Output directory: $OUTDIR"
echo ""

# ============================================================================
# OLM RESOURCES
# ============================================================================
echo "Collecting OLM resources..."

echo "  - CatalogSources"
oc get catalogsources -A -o yaml > catalogsources.yaml 2>&1

echo "  - Subscriptions"
oc get subscriptions -A -o yaml > subscriptions.yaml 2>&1

echo "  - ClusterServiceVersions (CSVs)"
oc get csv -A -o yaml > csvs.yaml 2>&1

echo "  - InstallPlans"
oc get installplans -A -o yaml > installplans.yaml 2>&1

echo "  - OperatorGroups"
oc get operatorgroups -A -o yaml > operatorgroups.yaml 2>&1

echo "  - PackageManifests (RHODS)"
oc get packagemanifest rhods-operator -n redhat-ods-operator -o yaml > packagemanifest-rhods.yaml 2>&1

# ============================================================================
# OPERATOR RESOURCES
# ============================================================================
echo "Collecting operator resources..."

echo "  - Operator Deployment"
oc get deployment rhods-operator -n redhat-ods-operator -o yaml > operator-deployment.yaml 2>&1

echo "  - Operator Pods"
oc get pods -n redhat-ods-operator -o yaml > operator-pods.yaml 2>&1

echo "  - Operator ReplicaSets"
oc get replicasets -n redhat-ods-operator -o yaml > operator-replicasets.yaml 2>&1

echo "  - Operator ConfigMaps"
oc get configmaps -n redhat-ods-operator -o yaml > operator-configmaps.yaml 2>&1

echo "  - Operator Secrets"
oc get secrets -n redhat-ods-operator -o yaml > operator-secrets.yaml 2>&1

echo "  - Operator ServiceAccount"
oc get serviceaccounts -n redhat-ods-operator -o yaml > operator-serviceaccounts.yaml 2>&1

echo "  - Operator Roles"
oc get roles -n redhat-ods-operator -o yaml > operator-roles.yaml 2>&1

echo "  - Operator RoleBindings"
oc get rolebindings -n redhat-ods-operator -o yaml > operator-rolebindings.yaml 2>&1

# ============================================================================
# RHOAI CUSTOM RESOURCES
# ============================================================================
echo "Collecting RHOAI custom resources..."

echo "  - DataScienceCluster"
oc get datasciencecluster -A -o yaml > datasciencecluster.yaml 2>&1

echo "  - DSCInitialization"
oc get dscinitializations.dscinitialization.opendatahub.io -A -o yaml > dscinitialization.yaml 2>&1

echo "  - Dashboard CR"
oc get dashboard -A -o yaml > dashboard-cr.yaml 2>&1

echo "  - All Component CRs"
oc get dashboard,datasciencepipelines,kserve,modelregistry,ray,trustyai,workbenches,modelcontroller,trainingoperator -A -o yaml > all-components.yaml 2>&1

# ============================================================================
# DASHBOARD RESOURCES
# ============================================================================
echo "Collecting dashboard resources..."

echo "  - Dashboard Deployment"
oc get deployment rhods-dashboard -n redhat-ods-applications -o yaml > dashboard-deployment.yaml 2>&1

echo "  - Dashboard Service"
oc get service rhods-dashboard -n redhat-ods-applications -o yaml > dashboard-service.yaml 2>&1

echo "  - Dashboard HTTPRoute"
oc get httproute rhods-dashboard -n redhat-ods-applications -o yaml > dashboard-httproute.yaml 2>&1

echo "  - Dashboard Routes (with label)"
oc get route -A -l 'platform.opendatahub.io/part-of=dashboard' -o yaml > dashboard-routes.yaml 2>&1

echo "  - All Dashboard Resources (by label)"
oc get all -n redhat-ods-applications -l platform.opendatahub.io/part-of=dashboard -o yaml > dashboard-all-resources.yaml 2>&1

# ============================================================================
# NAMESPACES
# ============================================================================
echo "Collecting namespace information..."

echo "  - Operator Namespace"
oc get namespace redhat-ods-operator -o yaml > namespace-operator.yaml 2>&1

echo "  - Applications Namespace"
oc get namespace redhat-ods-applications -o yaml > namespace-applications.yaml 2>&1

echo "  - Monitoring Namespace"
oc get namespace redhat-ods-monitoring -o yaml > namespace-monitoring.yaml 2>&1

# ============================================================================
# CLUSTER INFORMATION
# ============================================================================
echo "Collecting cluster information..."

echo "  - ClusterVersion"
oc get clusterversion -o yaml > clusterversion.yaml 2>&1

echo "  - ClusterOperators"
oc get clusteroperators -o yaml > clusteroperators.yaml 2>&1

# ============================================================================
# CRDS
# ============================================================================
echo "Collecting CRDs..."

echo "  - RHOAI CRDs"
oc get crds -o yaml | grep -A1000 "opendatahub.io" > crds-opendatahub.yaml 2>&1 || true

echo "  - Gateway API CRDs"
oc get crds -o yaml | grep -A1000 "gateway.networking" > crds-gateway.yaml 2>&1 || true

# ============================================================================
# SUMMARY FILES
# ============================================================================
echo "Generating summary files..."

cat > summary.txt << 'EOFSUM'
================================================================================
CLUSTER SUMMARY
Generated: $(date)
================================================================================

CLUSTER VERSION
---------------
EOFSUM
oc get clusterversion -o json | jq -r '.items[0] | "Version: \(.status.desired.version)\nChannel: \(.spec.channel)"' >> summary.txt 2>&1

cat >> summary.txt << 'EOFSUM'

OPERATOR VERSION
----------------
EOFSUM
oc get csv rhods-operator.3.3.0 -n redhat-ods-operator -o json | jq -r '"Name: \(.metadata.name)\nVersion: \(.spec.version)\nReplaces: \(.spec.replaces)\nPhase: \(.status.phase)\nCreated: \(.metadata.creationTimestamp)"' >> summary.txt 2>&1

cat >> summary.txt << 'EOFSUM'

OPERATOR PODS
-------------
EOFSUM
oc get pods -n redhat-ods-operator -o json | jq -r '.items[] | "Pod: \(.metadata.name)\nCreated: \(.metadata.creationTimestamp)\nRestarts: \(.status.containerStatuses[0].restartCount)\nStatus: \(.status.phase)\nImage: \(.spec.containers[0].image)\n"' >> summary.txt 2>&1

cat >> summary.txt << 'EOFSUM'

CATALOG SOURCES
---------------
EOFSUM
oc get catalogsources -A -o json | jq -r '.items[] | "Name: \(.metadata.name)\nNamespace: \(.metadata.namespace)\nType: \(.spec.sourceType)\nImage: \(.spec.image // "N/A")\nAddress: \(.spec.address // "N/A")\n"' >> summary.txt 2>&1

cat >> summary.txt << 'EOFSUM'

INSTALL PLANS (RHODS)
---------------------
EOFSUM
oc get installplans -n redhat-ods-operator -o json | jq -r '.items[] | select(.spec.clusterServiceVersionNames[] | contains("rhods")) | "Name: \(.metadata.name)\nCSV: \(.spec.clusterServiceVersionNames[0])\nApproval: \(.spec.approval)\nApproved: \(.spec.approved)\nCreated: \(.metadata.creationTimestamp)\n"' >> summary.txt 2>&1

cat >> summary.txt << 'EOFSUM'

DATASCIENCECLUSTER
------------------
EOFSUM
oc get datasciencecluster default-dsc -o json | jq -r '"Name: \(.metadata.name)\nCreated: \(.metadata.creationTimestamp)\nGeneration: \(.metadata.generation)\nPhase: \(.status.phase)\nRelease: \(.status.release.name) \(.status.release.version)\nObservedGeneration: \(.status.observedGeneration)"' >> summary.txt 2>&1

cat >> summary.txt << 'EOFSUM'

DSCINITIALIZATION
-----------------
EOFSUM
oc get dscinitializations.dscinitialization.opendatahub.io default-dsci -o json | jq -r '"Name: \(.metadata.name)\nCreated: \(.metadata.creationTimestamp)\nPhase: \(.status.phase)\nRelease: \(.status.release.name) \(.status.release.version)"' >> summary.txt 2>&1

cat >> summary.txt << 'EOFSUM'

DASHBOARD COMPONENT
-------------------
EOFSUM
oc get dashboard default-dashboard -o json | jq -r '"Name: \(.metadata.name)\nCreated: \(.metadata.creationTimestamp)\nReady: \(.status.phase)\nVersion: \(.metadata.annotations."platform.opendatahub.io/version")"' >> summary.txt 2>&1

cat >> summary.txt << 'EOFSUM'

DASHBOARD HTTPROUTE
-------------------
EOFSUM
oc get httproute rhods-dashboard -n redhat-ods-applications -o json | jq -r '"Name: \(.metadata.name)\nCreated: \(.metadata.creationTimestamp)\nVersion: \(.metadata.annotations."platform.opendatahub.io/version")\nOwnerRef: \(.metadata.ownerReferences[0].kind)/\(.metadata.ownerReferences[0].name)"' >> summary.txt 2>&1

cat >> summary.txt << 'EOFSUM'

DASHBOARD ROUTES (with label)
------------------------------
EOFSUM
ROUTE_COUNT=$(oc get route -A -l 'platform.opendatahub.io/part-of=dashboard' --no-headers 2>/dev/null | wc -l)
echo "Count: $ROUTE_COUNT (Expected: 0 for v3.3.0)" >> summary.txt

# ============================================================================
# OPERATOR DETAILS
# ============================================================================
cat > operator-details.txt << 'EOFOP'
================================================================================
OPERATOR DETAILED CONFIGURATION
================================================================================

OPERATOR IMAGE
--------------
EOFOP
oc get deployment rhods-operator -n redhat-ods-operator -o jsonpath='{.spec.template.spec.containers[0].image}' >> operator-details.txt
echo "" >> operator-details.txt
echo "" >> operator-details.txt

cat >> operator-details.txt << 'EOFOP'
ENVIRONMENT VARIABLES
---------------------
EOFOP
oc get deployment rhods-operator -n redhat-ods-operator -o json | jq -r '.spec.template.spec.containers[0].env[] | "  \(.name) = \(.value // (.valueFrom | tostring))"' >> operator-details.txt 2>&1

cat >> operator-details.txt << 'EOFOP'

RESOURCE LIMITS
---------------
EOFOP
oc get deployment rhods-operator -n redhat-ods-operator -o json | jq -r '.spec.template.spec.containers[0].resources' >> operator-details.txt 2>&1

cat >> operator-details.txt << 'EOFOP'

VOLUMES
-------
EOFOP
oc get deployment rhods-operator -n redhat-ods-operator -o json | jq -r '.spec.template.spec.volumes[]? | "  Name: \(.name)\n  Type: \(if .configMap then "ConfigMap: \(.configMap.name)" elif .secret then "Secret: \(.secret.secretName)" elif .emptyDir then "EmptyDir" else "Other" end)\n"' >> operator-details.txt 2>&1

# ============================================================================
# UPGRADE TIMELINE
# ============================================================================
cat > upgrade-timeline.txt << 'EOFTL'
================================================================================
UPGRADE TIMELINE RECONSTRUCTION
================================================================================

Based on cluster resources:

EOFTL

echo "Install Plans:" >> upgrade-timeline.txt
oc get installplans -n redhat-ods-operator -o json | jq -r '.items[] | select(.spec.clusterServiceVersionNames[] | contains("rhods")) | "  \(.metadata.creationTimestamp) - \(.spec.clusterServiceVersionNames[0]) (\(.spec.approval))"' >> upgrade-timeline.txt 2>&1

echo "" >> upgrade-timeline.txt
echo "Key Resources Created:" >> upgrade-timeline.txt
oc get dscinitializations.dscinitialization.opendatahub.io default-dsci -o json | jq -r '"  \(.metadata.creationTimestamp) - DSCInitialization created"' >> upgrade-timeline.txt 2>&1
oc get datasciencecluster default-dsc -o json | jq -r '"  \(.metadata.creationTimestamp) - DataScienceCluster created"' >> upgrade-timeline.txt 2>&1
oc get dashboard default-dashboard -o json | jq -r '"  \(.metadata.creationTimestamp) - Dashboard CR created"' >> upgrade-timeline.txt 2>&1
oc get deployment rhods-dashboard -n redhat-ods-applications -o json | jq -r '"  \(.metadata.creationTimestamp) - Dashboard Deployment created"' >> upgrade-timeline.txt 2>&1
oc get httproute rhods-dashboard -n redhat-ods-applications -o json | jq -r '"  \(.metadata.creationTimestamp) - HTTPRoute created"' >> upgrade-timeline.txt 2>&1

echo "" >> upgrade-timeline.txt
echo "CSV Information:" >> upgrade-timeline.txt
oc get csv rhods-operator.3.3.0 -n redhat-ods-operator -o json | jq -r '"  Name: \(.metadata.name)\n  Replaces: \(.spec.replaces)\n  Created: \(.metadata.creationTimestamp)\n  LastUpdate: \(.status.lastUpdateTime)"' >> upgrade-timeline.txt 2>&1

# ============================================================================
# FILE INVENTORY
# ============================================================================
echo ""
echo "Collection complete!"
echo ""
echo "Generated files:"
ls -lh "$OUTDIR" | grep -v "^total" | awk '{printf "  %-40s %8s\n", $9, $5}'
echo ""
echo "Summary: $(ls -1 "$OUTDIR" | wc -l) files created"
