# RHOAI → OpenDataHub Conversion Summary

All scripts have been converted from RHOAI to OpenDataHub. Here's what changed:

## Changes Applied

### 1. Build Scripts

**build-and-push-v2.25.0.sh:**
- ✅ Operator image: `rhods-operator` → `opendatahub-operator`
- ✅ Bundle image: `rhods-operator-bundle` → `opendatahub-operator-bundle`
- ✅ Platform type: `ODH_PLATFORM_TYPE=rhoai` → `ODH_PLATFORM_TYPE=OpenDataHub`
- ✅ CSV path: `bundle/manifests/rhods-operator...` → `odh-bundle/manifests/opendatahub-operator...`

**build-and-push-v3.0.0.sh:**
- ✅ Version: `3.0.0` → `3.3.0` (ODH uses 3.3.0)
- ✅ Operator image: `rhods-operator` → `opendatahub-operator`
- ✅ Bundle image: `rhods-operator-bundle` → `opendatahub-operator-bundle`
- ✅ Platform type: `ODH_PLATFORM_TYPE=rhoai` → `ODH_PLATFORM_TYPE=OpenDataHub`
- ✅ Dockerfile: `Dockerfiles/rhoai-bundle.Dockerfile` → `Dockerfiles/bundle.Dockerfile`
- ✅ CSV path: `config/rhoai/manifests/bases/rhods-operator...` → `config/manifests/bases/opendatahub-operator...`
- ✅ Instructions: Updated namespace references

### 2. Install/Upgrade Scripts

**install-v2.25.0.sh:**
- ✅ Bundle image: `rhods-operator-bundle` → `opendatahub-operator-bundle`
- ✅ Namespace: `redhat-ods-operator` → `opendatahub-operator-system`

**upgrade-to-v3.0.0.sh:**
- ✅ Version: `3.0.0` → `3.3.0`
- ✅ Bundle image: `rhods-operator-bundle:v3.0.0` → `opendatahub-operator-bundle:v3.3.0`
- ✅ Namespace: `redhat-ods-operator` → `opendatahub-operator-system`
- ✅ CSV check: `rhods-operator.v2.25.0` → `opendatahub-operator.v2.25.0`
- ✅ Log selector: `app.kubernetes.io/name=rhods-operator` → `opendatahub-operator`

### 3. Cleanup Script

**cleanup-odh-complete.sh:**
- ✅ Operator name: `rhods-operator` → `opendatahub-operator`
- ✅ Namespace (operator-sdk): `redhat-ods-operator` → `opendatahub-operator-system`
- ✅ Namespace (CSV/subscription): `redhat-ods-operator` → `opendatahub-operator-system`
- ✅ Namespace loop: 3 namespaces → 2 namespaces
  - FROM: `redhat-ods-operator`, `redhat-ods-applications`, `redhat-ods-monitoring`
  - TO: `opendatahub-operator-system`, `opendatahub`
- ✅ Namespace count grep: Updated to match ODH namespaces
- ✅ Verification grep: Updated to match ODH namespaces
- ✅ ClusterRole cleanup: Removed `rhods` pattern, kept `opendatahub` only

### 4. Patches

**patches/stable-2.x-csv.patch:**
- ✅ File: `bundle/manifests/rhods-operator.clusterserviceversion.yaml` (stable-2.x uses `bundle` dir, not `odh-bundle`)
- ✅ Image reference: `REPLACE_IMAGE:latest` → `opendatahub-operator:v2.25.0`

**patches/stable-2.x-dashboard-image.patch (NEW):**
- ✅ Fixes dashboard image tag: `:main` → `:v2.25.2-odh`
- ✅ Applies to: `manifests/odh/params.env`, `manifests/rhoai/addon/params.env`, `manifests/rhoai/onprem/params.env`
- ✅ Prevents dashboard pod crashes due to incompatible `:main` image (3.x era) with 2.25.0 operator

**patches/main-upgrade-fixes.patch:**
- ✅ File path: `config/rhoai/manifests/bases/rhods-operator...` → `config/manifests/bases/opendatahub-operator...`
- ✅ Replaces field: `rhods-operator.v2.25.0` → `opendatahub-operator.v2.25.0`

### 5. Unchanged Scripts

**check-cluster-resources.sh:**
- No changes needed - uses generic patterns that work for both ODH and RHOAI

**verify-etcd-clean.sh, clean-etcd-keys.sh:**
- No changes needed - work with CRD patterns, not operator-specific names

## Verification Commands

After conversion, verify no RHOAI references remain:

```bash
# Should find NO rhods/rhoai references
grep -r "rhods-operator\|rhoai" scripts/ --include="*.sh"

# Should find NO redhat-ods namespace references  
grep -r "redhat-ods" scripts/ --include="*.sh"

# Should find opendatahub references
grep -r "opendatahub-operator" scripts/ --include="*.sh"

# Should find ODH namespaces
grep -r "opendatahub-operator-system\|^opendatahub$" scripts/ --include="*.sh"
```

## Testing the Conversion

1. **Build containers (one-time):**
   ```bash
   ./scripts/build-containers.sh
   ```

2. **Clean any existing installation:**
   ```bash
   ./scripts/cleanup-odh-complete.sh
   ./scripts/verify-etcd-clean.sh
   ```

3. **Build operator bundles:**
   ```bash
   ./scripts/build-and-push-v2.25.0.sh
   ./scripts/build-and-push-v3.0.0.sh
   ```

4. **Install v2.25.0:**
   ```bash
   ./scripts/install-v2.25.0.sh
   ```

5. **Verify namespaces:**
   ```bash
   oc get namespaces | grep opendatahub
   # Should show:
   # opendatahub-operator-system
   # opendatahub
   ```

6. **Verify CSV:**
   ```bash
   oc get csv -n opendatahub-operator-system
   # Should show: opendatahub-operator.v2.25.0
   ```

7. **Upgrade to v3.3.0:**
   ```bash
   ./scripts/upgrade-to-v3.0.0.sh
   ```

8. **Verify upgrade:**
   ```bash
   oc get csv -n opendatahub-operator-system
   # Should show: opendatahub-operator.v3.3.0
   ```

## Key Differences: ODH vs RHOAI

| Aspect | RHOAI | ODH |
|--------|-------|-----|
| **Operator Package** | `rhods-operator` | `opendatahub-operator` |
| **CSV Name (v2.25.0)** | `rhods-operator.v2.25.0` | `opendatahub-operator.v2.25.0` |
| **CSV Name (v3)** | `rhods-operator.v3.0.0` | `opendatahub-operator.v3.3.0` |
| **Version (main)** | 3.0.0 | 3.3.0 |
| **Operator Namespace** | `redhat-ods-operator` | `opendatahub-operator-system` |
| **Applications Namespace** | `redhat-ods-applications` | `opendatahub` |
| **Monitoring Namespace** | `redhat-ods-monitoring` | `opendatahub` (shared) |
| **Total Namespaces** | 3 | 2 |
| **Platform Type** | `rhoai` | `OpenDataHub` |
| **Config Dir (stable-2.x)** | `config` | `config` (same) |
| **Config Dir (main)** | `config/rhoai` | `config` |
| **Bundle Dir (stable-2.x)** | `bundle` | `bundle` (same) |
| **Bundle Dir (main)** | `rhoai-bundle` | `odh-bundle` |
| **CSV Filename (stable-2.x)** | `rhods-operator.clusterserviceversion.yaml` | `rhods-operator.clusterserviceversion.yaml` (same, not renamed) |
| **Dockerfile (stable-2.x)** | `bundle.Dockerfile` | `bundle.Dockerfile` (same) |
| **Dockerfile (main)** | `rhoai-bundle.Dockerfile` | `bundle.Dockerfile` |

## Dashboard Image Issue - RESOLVED ✅

**Root Cause**: The dashboard manifests in stable-2.x branch use `odh-dashboard:main` tag by default. The `:main` tag is continuously built from the main branch (3.x era code) and is incompatible with the 2.25.0 operator, causing pods to crash with "cross-env: command not found" error.

**Solution**:
1. Created `patches/stable-2.x-dashboard-image.patch` to fix image tags from `:main` to `:v2.25.2-odh`
2. Updated `build-and-push-v2.25.0.sh` to:
   - Reset and patch the dashboard checkout in Step 0
   - Use `USE_LOCAL=1` when running `get_all_manifests.sh` to fetch manifests from the patched local dashboard checkout
   - Verify the dashboard image tag is correctly set in Step 6

This ensures the operator bundle contains dashboard manifests with the correct stable 2.25.x image tag.

## Next Steps

With the conversion complete, you can:

1. Test the full ODH installation and upgrade workflow
2. Address the dashboard image tag issue if needed
3. Verify all patches apply correctly to ODH bundles
4. Update documentation to reflect ODH focus
5. Archive or remove RHOAI-specific references in documentation

All scripts are now OpenDataHub-native!
