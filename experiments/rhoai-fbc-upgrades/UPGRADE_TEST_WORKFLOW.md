# RHOAI Upgrade Testing Workflow

## Overview

This guide covers how to test a RHOAI upgrade from v2.x to v3.x using your custom-built operator.

## Prerequisites

- OpenShift cluster with admin access
- Access to RHOAI v2.x catalog
- Custom v3.3.0 operator, bundle, and catalog built

## Workflow

### Phase 1: Complete Cleanup

Remove all existing RHOAI components from the cluster.

```bash
# 1. Run full cleanup
./full-cleanup-rhoai.sh
# Type 'yes' when prompted

# 2. Verify cleanup completed
./verify-cleanup.sh

# 3. Wait for namespaces to terminate (if needed)
watch oc get namespaces | grep redhat-ods
```

**What gets removed:**
- ✓ All RHOAI custom resources (DSC, DSCI, Dashboard, etc.)
- ✓ All RHOAI subscriptions and CSVs
- ✓ All RHOAI CRDs (~37 CRDs)
- ✓ All RHOAI namespaces (operator, applications, monitoring)
- ✓ All RHOAI catalog sources

---

### Phase 2: Install RHOAI v2.x

Install the baseline version you want to upgrade from.

```bash
# 1. Create catalog source for v2.x
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhoai-catalog-v2
  namespace: openshift-marketplace
spec:
  displayName: RHOAI v2.x Catalog
  sourceType: grpc
  image: quay.io/rhoai/rhoai-fbc-fragment:rhoai-2.25
  publisher: Red Hat
  updateStrategy:
    registryPoll:
      interval: 10m
EOF

# 2. Wait for catalog to be ready
oc get catalogsource rhoai-catalog-v2 -n openshift-marketplace -w

# 3. Create operator namespace
oc create namespace redhat-ods-operator

# 4. Create OperatorGroup (AllNamespaces mode)
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator-group
  namespace: redhat-ods-operator
spec: {}
EOF

# 5. Create Subscription for v2.x
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: stable
  name: rhods-operator
  source: rhoai-catalog-v2
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
  startingCSV: rhods-operator.2.25.2
EOF

# 6. Wait for operator to install
watch oc get csv -n redhat-ods-operator

# 7. Verify v2.x is running
oc get csv rhods-operator.2.25.2 -n redhat-ods-operator
oc get pods -n redhat-ods-operator
```

---

### Phase 3: Deploy RHOAI Components (v2.x)

Create RHOAI custom resources to have something to upgrade.

```bash
# 1. Create DSCInitialization
cat <<EOF | oc apply -f -
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    managementState: Managed
    namespace: redhat-ods-monitoring
  serviceMesh:
    managementState: Removed
  trustedCABundle:
    managementState: Removed
EOF

# 2. Create DataScienceCluster
cat <<EOF | oc apply -f -
apiVersion: datasciencecluster.opendatahub.io/v1
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    dashboard:
      managementState: Managed
    datasciencepipelines:
      managementState: Removed
    kserve:
      managementState: Removed
    modelmeshserving:
      managementState: Removed
    ray:
      managementState: Removed
    workbenches:
      managementState: Removed
EOF

# 3. Wait for components to deploy
watch oc get pods -n redhat-ods-applications

# 4. Verify Dashboard is running
oc get deployment rhods-dashboard -n redhat-ods-applications
oc get route rhods-dashboard -n redhat-ods-applications
```

---

### Phase 4: Prepare for Upgrade

Set up the v3.x catalog alongside v2.x.

```bash
# 1. Deploy your custom v3.x catalog
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhoai-custom-catalog-v3
  namespace: openshift-marketplace
spec:
  displayName: RHOAI Custom v3.x Catalog
  sourceType: grpc
  image: registry.tannerjc.net/rhoai-upgrade/rhods-operator-catalog:v3.3.0
  publisher: Custom Build
  updateStrategy:
    registryPoll:
      interval: 10m
EOF

# 2. Wait for v3 catalog to be ready
oc get catalogsource rhoai-custom-catalog-v3 -n openshift-marketplace -w

# 3. Verify both catalogs are ready
oc get catalogsource -n openshift-marketplace | grep rhoai
```

---

### Phase 5: Perform Upgrade

Trigger the upgrade from v2.x to v3.x.

```bash
# 1. Update subscription to point to v3 catalog
oc patch subscription rhods-operator -n redhat-ods-operator \
  --type merge \
  -p '{
    "spec": {
      "source": "rhoai-custom-catalog-v3",
      "channel": "stable"
    }
  }'

# 2. Monitor the upgrade
watch oc get csv -n redhat-ods-operator

# 3. Watch InstallPlan creation
oc get installplan -n redhat-ods-operator -w

# 4. If using Manual approval, approve the plan
# INSTALL_PLAN=$(oc get installplan -n redhat-ods-operator -o jsonpath='{.items[0].metadata.name}')
# oc patch installplan $INSTALL_PLAN -n redhat-ods-operator --type merge -p '{"spec":{"approved":true}}'

# 5. Monitor operator pods during upgrade
watch oc get pods -n redhat-ods-operator
```

---

### Phase 6: Verify Upgrade

Confirm the upgrade completed successfully.

```bash
# 1. Check CSV version
oc get csv -n redhat-ods-operator

# Should show: rhods-operator.v3.3.0 (Phase: Succeeded)

# 2. Check operator image
oc get deployment rhods-operator -n redhat-ods-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Should show: registry.tannerjc.net/rhoai-upgrade/rhods-operator:3.3.0

# 3. Verify RELATED_IMAGE variables
oc get deployment rhods-operator -n redhat-ods-operator -o json \
  | jq '[.spec.template.spec.containers[0].env[] | select(.name | startswith("RELATED_IMAGE"))] | length'

# Should show: 95

# 4. Check DSC/DSCI status
oc get datasciencecluster default-dsc -o yaml | grep -A5 "status:"
oc get dscinitialization default-dsci -o yaml | grep -A5 "status:"

# 5. Check component deployments
oc get pods -n redhat-ods-applications

# 6. Check for Route → HTTPRoute migration
oc get route -n redhat-ods-applications -l platform.opendatahub.io/part-of=dashboard
# Should be empty (no Routes)

oc get httproute -n redhat-ods-applications
# Should show rhods-dashboard HTTPRoute

# 7. Check operator logs for upgrade tasks
oc logs -n redhat-ods-operator deployment/rhods-operator | grep -i upgrade
```

---

### Phase 7: Test Garbage Collection

Verify that the GC mechanism works during upgrade.

```bash
# 1. Check operator logs for Route deletion
oc logs -n redhat-ods-operator deployment/rhods-operator \
  | grep -E "delete|garbage|GC" | tail -20

# 2. Verify no orphaned resources
oc get all -n redhat-ods-applications -l platform.opendatahub.io/part-of=dashboard

# 3. Check for any v2-specific resources that should be cleaned up
oc get all -A | grep -E "2\.25|v2"
```

---

## Troubleshooting

### Upgrade Stuck at InstallPlan

**Symptoms:** InstallPlan created but not progressing

**Solutions:**
```bash
# Check InstallPlan status
oc get installplan -n redhat-ods-operator -o yaml

# If Manual approval, approve it
INSTALL_PLAN=$(oc get installplan -n redhat-ods-operator -o jsonpath='{.items[0].metadata.name}')
oc patch installplan $INSTALL_PLAN -n redhat-ods-operator --type merge -p '{"spec":{"approved":true}}'
```

---

### CSV Fails to Install

**Symptoms:** CSV in Failed state

**Solutions:**
```bash
# Check failure reason
oc get csv -n redhat-ods-operator -o yaml | grep -A10 "message:"

# Common issues:
# - UnsupportedOperatorGroup: Check OperatorGroup has empty spec {}
# - ResourceVersion error: Bundle needs metadata cleaning (already fixed in build script)
```

---

### Components Not Upgrading

**Symptoms:** Dashboard still shows v2 behavior

**Solutions:**
```bash
# Force DSC/DSCI reconciliation by touching them
oc patch datasciencecluster default-dsc --type merge -p '{"spec":{"components":{"dashboard":{"managementState":"Managed"}}}}'

# Check operator logs
oc logs -n redhat-ods-operator deployment/rhods-operator --tail=100

# Delete and recreate component pods
oc delete pod -n redhat-ods-applications -l platform.opendatahub.io/part-of=dashboard
```

---

### Namespaces Stuck in Terminating

**Symptoms:** Namespace won't delete after cleanup

**Solutions:**
```bash
# Remove finalizers
oc patch namespace redhat-ods-applications -p '{"metadata":{"finalizers":[]}}' --type=merge

# Force delete resources
oc delete all --all -n redhat-ods-applications --force --grace-period=0
```

---

## Expected Results

After successful upgrade:

✅ **Operator:**
- CSV: `rhods-operator.v3.3.0` (Phase: Succeeded)
- Image: `registry.tannerjc.net/rhoai-upgrade/rhods-operator:3.3.0`
- RELATED_IMAGE vars: 95

✅ **Components:**
- Dashboard using HTTPRoute (not Route)
- Component versions updated to 3.3.0
- No v2-specific resources remaining

✅ **Custom Resources:**
- DSC/DSCI show version 3.3.0 in status
- All components reconciled successfully

---

## Cleanup After Testing

To clean up and start fresh:

```bash
# Full cleanup
./full-cleanup-rhoai.sh

# Verify
./verify-cleanup.sh
```

---

## Notes

- **Catalog Coexistence:** Both v2 and v3 catalogs can exist simultaneously during upgrade
- **Automatic vs Manual Approval:** Use Manual for production-like testing, Automatic for quick iterations
- **Component Migration:** Dashboard Route → HTTPRoute happens automatically during upgrade
- **Garbage Collection:** Old Route CRs are cleaned up by the operator's GC mechanism
- **RELATED_IMAGE Variables:** Critical for component deployment - verify they're present!

---

## Reference

See also:
- `SCRIPTS_GUIDE.md` - All build/deploy scripts
- `QUICK_START.txt` - Quick deployment reference
- `full-cleanup-rhoai.sh` - Complete cleanup script
- `verify-cleanup.sh` - Cleanup verification
