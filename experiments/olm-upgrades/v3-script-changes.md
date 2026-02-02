# v3.0.0 Script Updates for OpenDataHub

## Changes Made

### build-and-push-v3.0.0.sh

**Image Names:**
- Changed from: `rhods-operator:v3.0.0`
- Changed to: `opendatahub-operator:v3.0.0`
- Changed from: `rhods-operator-bundle:v3.0.0`
- Changed to: `opendatahub-operator-bundle:v3.0.0`

**Build Process:**
1. Added logging to file: `build-v3.0.0.log`
2. Added timestamped log functions: `log_step()`, `log_info()`
3. Added manifest fetching step (Step 1/7)
4. Added Dockerfile patching step (Step 2/7) to force `USE_LOCAL=true`
5. Changed image build to run directly on host (not in nested container)
6. Changed platform type from `rhoai` to `OpenDataHub`
7. Added bundle CSV patching (Step 5/7):
   - CSV name: `rhods-operator.v3.0.0` → `opendatahub-operator.v3.0.0`
   - Display name: `Red Hat OpenShift AI` → `Open Data Hub`
   - Replaces field: `rhods-operator.v2.25.0` → `opendatahub-operator.v2.25.0`
   - Container images: Fixed REPLACE_IMAGE placeholders
8. Added comprehensive verification (Step 7/7)
9. Updated instructions to reference `opendatahub-operator-system` namespace

**Key Fixes Applied:**
- Manifests are fetched from opendatahub-io repos (already correct in main branch)
- Dockerfile patched to prevent re-fetching manifests during build
- Build runs on host to avoid nested container volume mount issues
- OpenDataHub branding throughout

### upgrade-to-v3.0.0.sh

**Configuration:**
- Changed bundle image: `rhods-operator-bundle:v3.0.0` → `opendatahub-operator-bundle:v3.0.0`
- Changed namespace: `redhat-ods-operator` → `opendatahub-operator-system`

**CSV Checks:**
- Changed from: `rhods-operator.v2.25.0`
- Changed to: `opendatahub-operator.v2.25.0`

**Output Instructions:**
- Updated to reference `opendatahub-operator-system` namespace
- Updated to reference `opendatahub` namespace for dashboard
- Changed log selector from `app.kubernetes.io/name=rhods-operator` to `control-plane=controller-manager`

## Testing Sequence

1. Build v3.0.0:
   ```bash
   ./scripts/build-and-push-v3.0.0.sh
   ```

2. Verify v2.25.0 is installed:
   ```bash
   kubectl get csv opendatahub-operator.v2.25.0 -n opendatahub-operator-system
   ```

3. Upgrade to v3.0.0:
   ```bash
   ./scripts/upgrade-to-v3.0.0.sh
   ```

4. Verify upgrade:
   ```bash
   kubectl get csv -n opendatahub-operator-system
   kubectl get dsci,dsc -A
   kubectl get pods -n opendatahub
   ```

## Expected Results

- CSV should be: `opendatahub-operator.v3.0.0`
- Display name should be: `Open Data Hub`
- Replaces should reference: `opendatahub-operator.v2.25.0`
- All namespaces should use `opendatahub` (not `redhat-ods-*`)
- Dashboard should continue running with correct image tags
