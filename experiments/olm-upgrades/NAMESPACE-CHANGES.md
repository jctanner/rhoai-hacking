# Namespace Changes: RHOAI → ODH

## Namespace Mapping

| RHOAI Namespace | ODH Namespace | Purpose |
|-----------------|---------------|---------|
| `redhat-ods-operator` | `opendatahub-operator-system` | Operator deployment |
| `redhat-ods-applications` | `opendatahub` | Application deployments (dashboard, notebooks, etc.) |
| `redhat-ods-monitoring` | `opendatahub` | Monitoring (same as applications) |

**Key Difference**: RHOAI uses 3 namespaces, ODH uses 2 (applications and monitoring share the same namespace).

## Script Changes Required

### 1. install-v2.25.0.sh

```bash
# Line 6 - Change namespace variable
NAMESPACE="redhat-ods-operator"
# TO:
NAMESPACE="opendatahub-operator-system"

# This automatically fixes all references since the script uses ${NAMESPACE}:
# - Line 17: oc get namespace ${NAMESPACE}
# - Line 20: operator-sdk run bundle ${BUNDLE_IMG} --namespace ${NAMESPACE}
# - Lines 28-29: oc get csv,pods -n ${NAMESPACE}
```

### 2. upgrade-to-v3.0.0.sh

```bash
# Line 6 - Change namespace variable
NAMESPACE="redhat-ods-operator"
# TO:
NAMESPACE="opendatahub-operator-system"

# This automatically fixes all references:
# - Line 22: oc get csv rhods-operator.v2.25.0 -n ${NAMESPACE}
#   (Also needs CSV name change to opendatahub-operator.v2.25.0)
# - Line 31: operator-sdk run bundle-upgrade ${BUNDLE_IMG} --namespace ${NAMESPACE}
# - Lines 39-41: oc get csv -n ${NAMESPACE}
# - Line 44: oc logs -n ${NAMESPACE}
```

### 3. cleanup-odh-complete.sh

This script has **9 hardcoded namespace references** that need updating:

```bash
# Line 16 - operator-sdk cleanup
operator-sdk cleanup rhods-operator -n redhat-ods-operator --timeout=30s
# TO:
operator-sdk cleanup opendatahub-operator -n opendatahub-operator-system --timeout=30s

# Line 21 - Delete CSVs
oc delete csv --all -n redhat-ods-operator --force --grace-period=0 2>/dev/null || true
# TO:
oc delete csv --all -n opendatahub-operator-system --force --grace-period=0 2>/dev/null || true

# Line 22 - Delete subscriptions
oc delete subscription --all -n redhat-ods-operator --force --grace-period=0 2>/dev/null || true
# TO:
oc delete subscription --all -n opendatahub-operator-system --force --grace-period=0 2>/dev/null || true

# Line 23 - Delete catalog sources
oc delete catalogsource --all -n redhat-ods-operator --force --grace-period=0 2>/dev/null || true
# TO:
oc delete catalogsource --all -n opendatahub-operator-system --force --grace-period=0 2>/dev/null || true

# Line 27 - Namespace deletion loop
for ns in redhat-ods-operator redhat-ods-applications redhat-ods-monitoring; do
# TO:
for ns in opendatahub-operator-system opendatahub; do

# Line 128 - Count remaining namespaces
NS_COUNT=$(oc get namespaces 2>/dev/null | grep "redhat-ods" | wc -l || echo "0")
# TO:
NS_COUNT=$(oc get namespaces 2>/dev/null | grep -E "opendatahub-operator-system|^opendatahub$" | wc -l || echo "0")

# Line 145 - Verification check for remaining namespaces
if oc get namespaces 2>/dev/null | grep -E "opendatahub|redhat-ods"; then
# TO:
if oc get namespaces 2>/dev/null | grep -E "opendatahub-operator-system|^opendatahub$"; then
```

**Note**: The grep pattern for ODH needs to be careful not to match other namespaces like `opendatahub-xyz`. Use `^opendatahub$` to match exactly.

### 4. check-cluster-resources.sh

Check if this script has any namespace references:

```bash
grep -n "redhat-ods\|opendatahub" scripts/check-cluster-resources.sh
```

If it does, update them to match ODH namespaces.

### 5. verify-etcd-clean.sh

Check if this script has any namespace references:

```bash
grep -n "redhat-ods\|namespace" scripts/verify-etcd-clean.sh
```

If it validates specific namespaces, update them.

### 6. clean-etcd-keys.sh

Check if this script has any namespace-specific etcd key patterns:

```bash
grep -n "redhat-ods\|namespace" scripts/clean-etcd-keys.sh
```

### 7. build-and-push-v3.0.0.sh

This script has namespace references in the final instructions:

```bash
# Lines 71-74 - Installation instructions
echo "To install v2.25.0 and upgrade:"
echo "  oc create namespace redhat-ods-operator"
echo "  operator-sdk run bundle ${REGISTRY}/rhods-operator-bundle:v2.25.0 --namespace redhat-ods-operator"
echo "  # Wait for CSV to reach Succeeded, then:"
echo "  operator-sdk run bundle-upgrade ${BUNDLE_IMG} --namespace redhat-ods-operator"
# TO:
echo "To install v2.25.0 and upgrade:"
echo "  oc create namespace opendatahub-operator-system"
echo "  operator-sdk run bundle ${REGISTRY}/opendatahub-operator-bundle:v2.25.0 --namespace opendatahub-operator-system"
echo "  # Wait for CSV to reach Succeeded, then:"
echo "  operator-sdk run bundle-upgrade ${BUNDLE_IMG} --namespace opendatahub-operator-system"
```

## Verification Commands

After updating scripts, verify namespace references:

```bash
# Should find NO references to redhat-ods
grep -r "redhat-ods" scripts/

# Should find references to opendatahub namespaces
grep -r "opendatahub-operator-system\|^opendatahub$" scripts/

# Check specific scripts have been updated
grep "NAMESPACE=" scripts/install-v2.25.0.sh scripts/upgrade-to-v3.0.0.sh
```

## Testing Namespace Changes

After switching to ODH namespaces:

1. **Clean environment**:
   ```bash
   ./scripts/cleanup-odh-complete.sh
   ```

2. **Verify no namespaces remain**:
   ```bash
   oc get namespaces | grep -E "redhat-ods|opendatahub"
   # Should return nothing
   ```

3. **Install v2.25.0**:
   ```bash
   ./scripts/install-v2.25.0.sh
   ```

4. **Verify correct namespaces created**:
   ```bash
   oc get namespaces | grep opendatahub
   # Should show:
   # opendatahub-operator-system
   # opendatahub
   ```

5. **Check pods in correct namespaces**:
   ```bash
   oc get pods -n opendatahub-operator-system  # Should show operator pods
   oc get pods -n opendatahub                   # Should show application pods
   ```

## Common Errors

### Error: namespace "redhat-ods-operator" not found

**Cause**: Script still using RHOAI namespace but ODH is deployed.

**Fix**: Update NAMESPACE variable in the script.

### Error: csv "rhods-operator.v2.25.0" not found

**Cause**: CSV name doesn't match the operator package name.

**Fix**: Change CSV references from `rhods-operator` to `opendatahub-operator`.

### Warning: Multiple namespaces found

**Cause**: Both RHOAI and ODH may be partially installed.

**Fix**: Run cleanup script completely, then reinstall with correct platform.

## Summary

Total namespace references to update: **13 locations across 4 scripts**

1. ✅ `install-v2.25.0.sh` - 1 variable definition (fixes 4 uses)
2. ✅ `upgrade-to-v3.0.0.sh` - 1 variable definition (fixes 5 uses)
3. ⚠️ `cleanup-odh-complete.sh` - 7 hardcoded references
4. ✅ `build-and-push-v3.0.0.sh` - 4 references in instructions

The install and upgrade scripts are easy (just change one variable each). The cleanup script requires more careful editing since namespaces are hardcoded in multiple places.
