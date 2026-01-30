# Cleanup Scripts for ODH/RHOAI

This directory contains comprehensive cleanup and verification scripts for removing all traces of OpenDataHub/RHOAI from an OpenShift cluster, including clearing etcd cache.

## Scripts

### 1. cleanup-odh-complete.sh
**Purpose:** Complete cleanup of all ODH/RHOAI resources from the cluster

**What it does:**
- Runs `operator-sdk cleanup` to remove OLM resources
- Deletes all CSVs, Subscriptions, and CatalogSources
- Deletes all ODH/RHOAI namespaces
- Force deletes all ODH CRDs and their instances
- Removes finalizers from stuck resources
- Cleans up ClusterRoles and ClusterRoleBindings
- Triggers API server cache invalidation
- Provides comprehensive verification

**Usage:**
```bash
./cleanup-odh-complete.sh
```

**Note:** This script does NOT clean etcd keys directly. After running this, run `verify-etcd-clean.sh` to check for orphaned keys.

### 2. verify-etcd-clean.sh
**Purpose:** Comprehensive verification that etcd cache is clear of ODH data

**What it checks:**
- API server discovery for ODH API groups
- Tests for v2 corruption errors
- Checks raw API endpoints
- Searches for orphaned CR instances
- **Directly queries etcd for opendatahub keys**
- Verifies API server cache refresh
- Runs comprehensive resource checks

**Usage:**
```bash
./verify-etcd-clean.sh
```

**Output:**
- ✓ PASSED - No ODH data in etcd
- ✗ FAILED - Found orphaned keys (run clean-etcd-keys.sh)

### 3. clean-etcd-keys.sh
**Purpose:** Directly removes orphaned ODH keys from etcd

**What it does:**
- Accesses etcd pod directly
- Searches for all keys containing "opendatahub"
- Deletes each orphaned key
- Verifies deletion

**When to use:**
- After `verify-etcd-clean.sh` reports orphaned keys
- When you see v2 corruption errors after cleanup
- When CRDs are deleted but instances remain

**Usage:**
```bash
./clean-etcd-keys.sh
```

**Requirements:**
- Access to openshift-etcd namespace
- Permissions to exec into etcd pods

## Complete Cleanup Workflow

### Step 1: Initial Cleanup
```bash
./cleanup-odh-complete.sh
```

Wait for completion (may take 2-3 minutes).

### Step 2: Verify etcd
```bash
./verify-etcd-clean.sh
```

If it reports **PASSED**, you're done!

If it reports **FAILED** with orphaned keys, proceed to Step 3.

### Step 3: Clean etcd (if needed)
```bash
./clean-etcd-keys.sh
```

### Step 4: Re-verify
```bash
./verify-etcd-clean.sh
```

Should now report **PASSED**.

## Understanding etcd Corruption

### What causes it?
- Installing and deleting operators multiple times during testing
- CRDs deleted while instances still exist
- API version migrations (v1 → v2) with orphaned references

### Symptoms:
- Error: `request to convert CR from an invalid group/version: dscinitialization.opendatahub.io/v2`
- Operator pods crash-looping
- CSV stuck in Installing phase
- Resources can't be queried even after CRD deletion

### Why standard cleanup isn't enough:
1. **CRD deletion** removes the schema but not etcd data
2. **Namespace deletion** doesn't affect cluster-scoped CRD data
3. **API server cache** may serve stale data
4. **etcd keys persist** even after CRDs are removed

### The complete solution:
1. Delete all instances first (cleanup-odh-complete.sh)
2. Delete CRDs (cleanup-odh-complete.sh)
3. Verify etcd is clean (verify-etcd-clean.sh)
4. Remove orphaned keys if found (clean-etcd-keys.sh)

## Verification Checklist

After cleanup, all of these should return **no results or clean errors**:

```bash
# No CRDs
oc get crd | grep -E "opendatahub|platform\."

# No namespaces
oc get namespaces | grep -E "redhat-ods"

# No API resources
oc api-resources | grep -E "opendatahub|dscinitialization"

# Clean query failure (not v2 error)
oc get dscinitializations -A

# No etcd keys
# (requires verify-etcd-clean.sh)
```

## Troubleshooting

### Script hangs during CRD deletion
**Cause:** Finalizers or instances blocking deletion

**Solution:** Script automatically removes finalizers and uses `--force --grace-period=0`

### Still seeing v2 errors after cleanup
**Cause:** Orphaned etcd keys

**Solution:** Run `clean-etcd-keys.sh`

### Cannot access etcd pods
**Cause:** Insufficient permissions

**Solution:** Requires cluster-admin or openshift-etcd namespace access

### Namespaces stuck in Terminating
**Cause:** Finalizers on resources

**Solution:** Wait for cleanup script to complete (removes finalizers automatically)

## Safety Notes

- ✅ **Safe**: These scripts are safe for development/test clusters
- ⚠️ **Caution**: Direct etcd manipulation should only be done on non-production clusters
- ❌ **Never**: Do not run etcd cleanup on production clusters without backup
- 💾 **Best Practice**: Take etcd backup before running cleanup scripts

## What Gets Deleted

### Namespaces:
- redhat-ods-operator
- redhat-ods-applications
- redhat-ods-monitoring

### CRDs (25+ total):
- dscinitializations.dscinitialization.opendatahub.io
- datascienceclusters.datasciencecluster.opendatahub.io
- All component CRDs (codeflares, dashboards, kserve, ray, etc.)
- All service CRDs (servicemeshes, auths, etc.)

### OLM Resources:
- ClusterServiceVersions
- Subscriptions
- CatalogSources
- OperatorGroups
- InstallPlans

### Cluster Resources:
- ClusterRoles (matching opendatahub/rhods)
- ClusterRoleBindings (matching opendatahub/rhods)

### etcd Keys:
- All keys under `/kubernetes.io/*.opendatahub.io/`

## Post-Cleanup

After successful cleanup:
1. Cluster is clean of all ODH/RHOAI resources
2. etcd has no orphaned keys
3. API server cache is cleared
4. Ready for fresh installation

You can verify with:
```bash
./verify-etcd-clean.sh
```

Should report: **ETCD CACHE VERIFICATION: PASSED**
