# Upgrade Test: OdhDashboardConfig Error Handling and Version Caching

**Discovered:** 2026-01-29 (OdhDashboardConfig), 2026-02-02 (Version Caching)
**Severity:** HIGH - Prevents operator from starting and blocks architectural migrations
**Component:** opendatahub-operator upgrade package
**Affects:** v3.3.0 (likely affects other 3.x versions)

## Summary

The opendatahub-operator crashes on startup when the `OdhDashboardConfig` CRD doesn't exist in the cluster. This is a **normal, expected scenario** when:
- Operator is freshly installed
- DataScienceCluster CR hasn't been created yet
- Dashboard component isn't deployed
- User is running minimal configuration

The root cause is incorrect error handling in the upgrade code that fails to distinguish between:
- "Resource instance not found" (expected, should fall back to manifests)
- "Resource type/CRD doesn't exist" (also expected, should fall back to manifests)

## Discovery Context

This bug was discovered during OLM upgrade testing from v2.25.0 → v3.3.0:

1. Successfully cleaned cluster completely
2. Installed v2.25.0 successfully (created default DSCInitialization but no DataScienceCluster)
3. Attempted upgrade to v3.3.0 with conversion webhook fix
4. Operator initially started successfully (conversion webhook fix worked!)
5. Operator then crashed in crash-loop with error about missing OdhDashboardConfig
6. All 3 operator pods in CrashLoopBackOff
7. Service had no endpoints → conversion webhook unavailable → upgrade blocked

## Symptoms

### Operator Pod Crash Loop
```bash
oc get pods -n redhat-ods-operator | grep rhods-operator
# rhods-operator-58d8df7bd4-2nmp6   0/1  CrashLoopBackOff   6 (102s ago)   10m
# rhods-operator-58d8df7bd4-b5dvg   0/1  CrashLoopBackOff   6 (72s ago)    10m
# rhods-operator-58d8df7bd4-s9szd   0/1  CrashLoopBackOff   6 (29s ago)    10m
```

### CSV Stuck in Installing
```bash
oc get csv -n redhat-ods-operator
# NAME                     DISPLAY                  VERSION   REPLACES                 PHASE
# rhods-operator.v3.3.0    Red Hat OpenShift AI     3.3.0     rhods-operator.v2.25.0   Installing
```

### No Service Endpoints
```bash
oc get endpoints rhods-operator-service -n redhat-ods-operator
# NAME                     ENDPOINTS   AGE
# rhods-operator-service               18m
```

No endpoints because all pods are crashing.

### Error in Operator Logs
```json
{
  "level": "error",
  "ts": "2026-01-30T03:08:25Z",
  "logger": "setup",
  "msg": "problem running manager",
  "error": "1 error occurred:\n\t* failed to get OdhDashboardConfig: failed to get OdhDashboardConfig from cluster: no matches for kind \"OdhDashboardConfig\" in version \"opendatahub.io/v1alpha\"\n\n"
}
```

### DSCInitialization Query Fails
```bash
oc get dscinitializations -A
# Error from server: conversion webhook for dscinitialization.opendatahub.io/v2, Kind=DSCInitialization failed:
# Post "https://rhods-operator-service.redhat-ods-operator.svc:443/convert?timeout=30s":
# no endpoints available for service "rhods-operator-service"
```

Conversion webhook can't function because operator pods are crashed.

## Root Cause Analysis

### Code Location
**File:** `pkg/upgrade/upgrade_utils.go`
**Function:** `getOdhDashboardConfig()`

### Problematic Code
```go
func getOdhDashboardConfig(ctx context.Context, cli client.Client, applicationNS string) (*unstructured.Unstructured, bool, error) {
	log := logf.FromContext(ctx)
	odhConfig := &unstructured.Unstructured{}
	odhConfig.SetGroupVersionKind(gvk.OdhDashboardConfig)

	// Try to get the OdhDashboardConfig from cluster first
	err := cli.Get(ctx, client.ObjectKey{Name: odhDashboardConfigName, Namespace: applicationNS}, odhConfig)
	if err == nil {
		log.Info("Found OdhDashboardConfig in cluster")
		return odhConfig, true, nil
	}

	// ❌ BUG: This check is insufficient!
	// If not found in cluster, check if it's a "not found" error
	if !k8serr.IsNotFound(err) {
		return nil, false, fmt.Errorf("failed to get OdhDashboardConfig from cluster: %w", err)
	}

	log.Info("OdhDashboardConfig not found in cluster, attempting to load from manifests")

	// Try to load from manifests
	manifestConfig, found, err := loadOdhDashboardConfigFromManifests(ctx)
	// ... (continues to load from manifests)
}
```

### The Problem

**Two Different Error Types:**

1. **`k8serr.IsNotFound(err)`** - Returns true when:
   - Resource **instance** doesn't exist
   - But the CRD/resource type **does** exist
   - Example: `pods/my-pod not found`

2. **`meta.IsNoMatchError(err)`** - Returns true when:
   - Resource **type/kind** doesn't exist
   - The CRD itself is not installed
   - Example: `no matches for kind "OdhDashboardConfig" in version "opendatahub.io/v1alpha"`

**Current Behavior:**

When the OdhDashboardConfig CRD doesn't exist:
1. `cli.Get()` returns `NoKindMatchError`
2. `k8serr.IsNotFound(err)` returns **false** (it's a different error type)
3. Check `if !k8serr.IsNotFound(err)` evaluates to **true**
4. Function returns error and crashes operator
5. Never reaches the fallback to load from manifests

**Expected Behavior:**

The function should fall through to load from manifests in **both** cases:
- When resource instance doesn't exist (`IsNotFound`)
- When resource type/CRD doesn't exist (`IsNoMatchError`)

### Why OdhDashboardConfig CRD Doesn't Exist

**CRD Ownership:**
- `OdhDashboardConfig` CRD is defined in: `odh-dashboard/manifests/common/crd/odhdashboardconfigs.opendatahub.io.crd.yaml`
- CRD is **NOT** included in the operator bundle
- CRD is deployed by the **Dashboard component** when it runs
- Dashboard component only runs when:
  - User creates DataScienceCluster CR
  - Dashboard component is enabled in DSC spec

**Normal Deployment Flow:**
1. Install operator (creates DSCInitialization)
2. Operator starts up
3. User creates DataScienceCluster CR
4. Dashboard component deploys
5. Dashboard component creates OdhDashboardConfig CRD and instance

**What Happens in Our Test:**
1. Install operator (creates DSCInitialization)
2. Operator starts up ← **CRASHES HERE**
3. Never get to create DataScienceCluster
4. Dashboard never deploys
5. OdhDashboardConfig CRD never created

### When the Code Runs

**Call Stack:**
```
cmd/main.go:475
  └─ upgrade.CleanupExistingResource()
       └─ upgrade.MigrateToInfraHardwareProfiles()  (line 93, only if major version 2→3 upgrade)
            └─ getOdhDashboardConfig()  ← CRASHES HERE
```

**Triggered When:**
- Operator starts up
- Old release version major = 2, new major = 3
- Runs hardware profile migration
- Migration needs OdhDashboardConfig to extract container sizes

**Purpose:**
The migration converts v2 accelerator profiles and container sizes to v3 hardware profiles. It needs the OdhDashboardConfig to read:
- `notebookSizes` (deprecated, migrated to hardware profiles)
- `modelServerSizes` (deprecated, migrated to hardware profiles)
- Accelerator profile configurations

## Impact Assessment

### Severity: HIGH

**Affected Scenarios:**
1. ✅ **Fresh installation** - Creates DSCInitialization but no DSC
2. ✅ **Minimal configuration** - Running without Dashboard component
3. ✅ **Upgrade from v2.x → v3.x** - Migration code runs at startup
4. ✅ **Any scenario without Dashboard** - CRD never deployed

**Not Affected:**
- Existing deployments with Dashboard already running
- Clusters where OdhDashboardConfig CRD already exists

### User Impact

**Complete Operator Failure:**
- Operator cannot start
- CSV stuck in Installing phase
- No components can be deployed
- No reconciliation happening
- Conversion webhooks unavailable
- Cluster essentially non-functional for ODH/RHOAI

**Cascading Failures:**
- Conversion webhook service has no endpoints
- DSCInitialization queries fail
- Other CRD queries may fail if they require conversion
- Entire upgrade path blocked

## The Fix

### Code Change Required

**File:** `pkg/upgrade/upgrade_utils.go`
**Function:** `getOdhDashboardConfig()`

**Change:**
```go
func getOdhDashboardConfig(ctx context.Context, cli client.Client, applicationNS string) (*unstructured.Unstructured, bool, error) {
	log := logf.FromContext(ctx)
	odhConfig := &unstructured.Unstructured{}
	odhConfig.SetGroupVersionKind(gvk.OdhDashboardConfig)

	// Try to get the OdhDashboardConfig from cluster first
	err := cli.Get(ctx, client.ObjectKey{Name: odhDashboardConfigName, Namespace: applicationNS}, odhConfig)
	if err == nil {
		log.Info("Found OdhDashboardConfig in cluster")
		return odhConfig, true, nil
	}

	// ✅ FIX: Handle both "not found" and "no such kind" errors
	// If not found in cluster (either instance or CRD missing), load from manifests
	if !k8serr.IsNotFound(err) && !meta.IsNoMatchError(err) {
		return nil, false, fmt.Errorf("failed to get OdhDashboardConfig from cluster: %w", err)
	}

	log.Info("OdhDashboardConfig not found in cluster, attempting to load from manifests")

	// Try to load from manifests
	manifestConfig, found, err := loadOdhDashboardConfigFromManifests(ctx)
	if err != nil {
		return nil, false, fmt.Errorf("failed to load OdhDashboardConfig from manifests: %w", err)
	}

	if !found {
		log.Info("OdhDashboardConfig not found in cluster or manifests")
		return nil, false, nil
	}

	log.Info("Successfully loaded OdhDashboardConfig from manifests")
	return manifestConfig, true, nil
}
```

**Required Import:**
```go
import (
	// ... existing imports ...
	"k8s.io/apimachinery/pkg/api/meta"
)
```

### Explanation

The fix adds `!meta.IsNoMatchError(err)` to the error check, which allows the function to fall back to loading from manifests when:

1. **`k8serr.IsNotFound(err)`** - Resource instance doesn't exist (but CRD does)
2. **`meta.IsNoMatchError(err)`** - Resource type/CRD doesn't exist

Only if it's **neither** of these error types (i.e., a real unexpected error like network timeout, permission denied, etc.) should it return an error.

## Reproduction Steps

### Minimal Reproduction

1. **Start with clean cluster:**
   ```bash
   # Use cleanup scripts to ensure clean state
   ./cleanup-odh-complete.sh
   ./verify-etcd-clean.sh
   ```

2. **Install operator:**
   ```bash
   oc create namespace redhat-ods-operator
   operator-sdk run bundle registry.tannerjc.net/opendatahub/rhods-operator-bundle:v3.0.0 \
     --namespace redhat-ods-operator
   ```

3. **Observe crash:**
   ```bash
   # Wait ~30 seconds, then check
   oc get pods -n redhat-ods-operator
   # All rhods-operator-* pods will be in CrashLoopBackOff

   oc logs <pod-name> -n redhat-ods-operator
   # Will show: "failed to get OdhDashboardConfig: no matches for kind..."
   ```

### Reproduction via Upgrade Path

1. **Install v2.25.0:**
   ```bash
   oc create namespace redhat-ods-operator
   operator-sdk run bundle registry.tannerjc.net/opendatahub/rhods-operator-bundle:v2.25.0 \
     --namespace redhat-ods-operator
   # Wait for CSV to reach Succeeded
   ```

2. **Upgrade to v3.x:**
   ```bash
   operator-sdk run bundle-upgrade registry.tannerjc.net/opendatahub/rhods-operator-bundle:v3.0.0 \
     --namespace redhat-ods-operator
   ```

3. **Observe crash:**
   - New v3.x operator pods start
   - Upgrade code runs (because major version changed 2→3)
   - Tries to migrate hardware profiles
   - Needs OdhDashboardConfig
   - CRD doesn't exist
   - Crashes

## Verification of Fix

After applying the fix, the operator should:

1. **Start successfully** even when OdhDashboardConfig CRD doesn't exist
2. **Log message:** "OdhDashboardConfig not found in cluster, attempting to load from manifests"
3. **Load defaults** from embedded manifests in operator image
4. **Continue with migration** using manifest data
5. **Reach Succeeded** CSV phase
6. **Serve conversion webhook** properly (endpoints available)

### Test Commands

```bash
# After fix applied and operator rebuilt:

# 1. Check pods are running (not crashing)
oc get pods -n redhat-ods-operator | grep rhods-operator
# Should show: 3/3 Running with 0 restarts

# 2. Check CSV reached Succeeded
oc get csv -n redhat-ods-operator
# Should show: rhods-operator.v3.x.x   Succeeded

# 3. Check service has endpoints
oc get endpoints rhods-operator-service -n redhat-ods-operator
# Should show IP addresses for 3 pods

# 4. Verify DSCInitialization queries work
oc get dscinitializations -A
# Should work without conversion webhook errors

# 5. Check operator logs for proper fallback
oc logs <pod-name> -n redhat-ods-operator | grep -i "OdhDashboardConfig"
# Should show: "OdhDashboardConfig not found in cluster, attempting to load from manifests"
# Should show: "Successfully loaded OdhDashboardConfig from manifests"
```

## Related Issues

### Connection to Conversion Webhook Fix

This bug was discovered **after** the conversion webhook deadlock fix was applied:

1. **Previous Issue:** Conversion webhook deadlock prevented operator from starting
2. **Fix Applied:** Rebased main branch with conversion webhook fix
3. **New Issue Discovered:** Operator started successfully (webhook fix worked!)
4. **But Then:** Crashed immediately due to OdhDashboardConfig error

The conversion webhook fix **worked correctly**. This is a **separate, independent bug** that was masked by the webhook deadlock.

### Why This Bug Wasn't Caught Earlier

**Likely Scenarios:**
1. **Development testing** - Developers likely create DSC immediately after operator install, which deploys Dashboard and creates the CRD
2. **CI/CD** - Tests probably include Dashboard deployment, so CRD exists
3. **Previous versions** - May not have had the hardware profile migration code that triggers the crash
4. **Upgrade testing** - May have been tested with existing Dashboard deployments where CRD already existed

**Our Test Was Unique:**
- Clean cluster (no pre-existing CRDs)
- No DataScienceCluster created
- Minimal DSCInitialization only
- Simulates real-world "just installed operator, now what?" scenario

## Recommendations

### Immediate Actions

1. **Apply the fix** - Add `!meta.IsNoMatchError(err)` to error handling
2. **Add unit tests** - Test `getOdhDashboardConfig()` with simulated NoMatchError
3. **Integration test** - Test operator startup without Dashboard/DSC

### Code Review

**Questions to Consider:**
1. Are there other places in the codebase with similar error handling bugs?
2. Should there be a helper function for "resource not available" checks?
3. Should migration code be more defensive about missing CRDs?

**Pattern to Search For:**
```go
if !k8serr.IsNotFound(err) {
    return error
}
```

Any code using this pattern should be reviewed to ensure it also handles `meta.IsNoMatchError(err)`.

### Testing Improvements

**Add Test Scenarios:**
1. Fresh operator install (no DSC, no Dashboard)
2. Minimal configuration (DSCInitialization only)
3. Upgrade without existing Dashboard deployment
4. Startup with various missing CRDs

**Test Matrix:**
- ✅ Fresh install + no DSC
- ✅ Fresh install + DSC without Dashboard
- ✅ Fresh install + DSC with Dashboard
- ✅ Upgrade 2.x→3.x without Dashboard
- ✅ Upgrade 2.x→3.x with Dashboard

## Additional Context

### OdhDashboardConfig CRD Details

**File:** `odh-dashboard/manifests/common/crd/odhdashboardconfigs.opendatahub.io.crd.yaml`

**API:**
- Group: `opendatahub.io`
- Version: `v1alpha`
- Kind: `OdhDashboardConfig`
- Scope: Namespaced

**Purpose:**
Configuration for ODH Dashboard including:
- Feature flags (enable/disable various features)
- Notebook sizes (deprecated, migrated to hardware profiles)
- Model server sizes (deprecated, migrated to hardware profiles)
- Accelerator profiles (deprecated, migrated to hardware profiles)

**Deployment:**
- Owned by Dashboard component
- Deployed when Dashboard reconciles
- Not included in operator bundle CRDs

### Hardware Profile Migration Context

**What It Does:**
The migration code (`MigrateToInfraHardwareProfiles`) runs during v2→v3 upgrades to:

1. Convert AcceleratorProfiles → HardwareProfiles (2 per accelerator: notebook + serving)
2. Convert container sizes → HardwareProfiles (1 per size)
3. Update Notebook annotations to reference new HardwareProfiles
4. Update InferenceService annotations to reference new HardwareProfiles

**Why It Needs OdhDashboardConfig:**
The config contains the source data for migration:
- `spec.notebookSizes` - Defines notebook resource limits
- `spec.modelServerSizes` - Defines model server resource limits
- Accelerator profile configurations

**Fallback Mechanism:**
If OdhDashboardConfig isn't available in the cluster, it should load default configuration from embedded manifests at:
```
odhDashboardConfigPath = "/dashboard/rhoai/shared/odhdashboardconfig/odhdashboardconfig.yaml"
```

This fallback exists and works correctly - the bug simply prevents it from being reached.

## Related Issue: Version Caching Bug Blocks Route Migration

### Discovery Context

During upgrade testing from v2.25.0 → v3.3.0 (2026-02-02), a second issue was discovered related to operator version caching.

### Symptoms

After successful OLM upgrade:
- Operator v3.3.0 image running
- CSV showing v3.3.0
- **Dashboard Route object still present** (should have been replaced by HTTPRoute)
- Dashboard version annotation showing 2.25.0 instead of 3.3.0

### Root Cause

The operator caches its version from the CSV only at startup in `pkg/cluster/cluster_config.go`:

```go
func getRelease(ctx context.Context, cli client.Client) (common.Release, error) {
    // ...
    csv, err := GetClusterServiceVersion(ctx, cli, operatorNamespace)
    initRelease.Version = csv.Spec.Version
    return initRelease, nil
}
```

This cached version is used for:
1. **Resource annotations** - `platform.opendatahub.io/version`
2. **Manifest path selection** - Determines which manifests to render

### Impact on Upgrades

**Expected v3.3.0 Behavior:**
- Operator renders manifests from v3.3.0 path
- Kustomization includes `httproute.yaml`, excludes `routes.yaml`
- GC action deletes old Route object
- HTTPRoute created

**Actual Behavior After Upgrade:**
- Operator cached version 2.25.0 (likely race condition during upgrade)
- Operator renders manifests from v2.25.0 path
- Kustomization includes `routes.yaml`
- Route object kept alive by reconciliation
- **Architectural migration blocked**

### Evidence

Operator pod age after upgrade:
```bash
$ oc get pods -n opendatahub-operator-system -l control-plane=controller-manager
NAME                                                       AGE
opendatahub-operator-controller-manager-796b6547dc-2bg8s   121m
```

Pods started during upgrade but never restarted to reload CSV version.

Dashboard annotations before operator restart:
```yaml
metadata:
  annotations:
    platform.opendatahub.io/version: 2.25.0
```

Resources before operator restart:
- Route `odh-dashboard` in `opendatahub` namespace: **Present**
- HTTPRoute `odh-dashboard` in `opendatahub` namespace: **Missing**

### Resolution

Manual operator pod restart required:
```bash
oc delete pod -n opendatahub-operator-system -l control-plane=controller-manager
```

After restart:
- Operator loads v3.3.0 from CSV
- Version annotation: 3.3.0
- Route deleted by GC action
- HTTPRoute created
- Gateway API migration complete

### Scope

This affects all v2.x → v3.x upgrades:
- Version annotations remain at old version
- Architectural migrations incomplete
- Resources use old manifest versions
- Manual intervention required

### Recommendation

**Operator Should Restart After OLM Upgrade:**

Options:
1. **OLM triggers restart** - Deployment spec change to force pod recreation
2. **Operator watches CSV** - Detect version changes and restart
3. **Documentation** - Instruct users to restart operator pods after upgrade

**Testing Required:**
- Verify operator pod restart behavior during OLM upgrades
- Test version caching with various upgrade paths
- Confirm architectural migrations complete without manual intervention

## Conclusion

This is a **critical bug** that prevents the operator from starting in common deployment scenarios. The fix is **simple and low-risk** - just adding one additional error type check to allow fallback to manifests when CRDs don't exist.

The bug demonstrates the importance of testing "minimal configuration" scenarios where optional components aren't deployed yet.

The version caching issue is a **separate critical bug** that blocks architectural migrations during upgrades and requires manual operator restart to complete.

**Priority:** HIGH - Should be fixed before next release
**Risk:** LOW - One-line fix, well-understood error handling
**Testing:** Required - Add automated tests for this scenario
