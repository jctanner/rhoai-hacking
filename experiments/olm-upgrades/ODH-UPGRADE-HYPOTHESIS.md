# Theoretical OLM Upgrade Process: OpenDataHub Operator 2.25.0 → 3.0.0

This document theorizes what an OLM upgrade would do when upgrading the OpenDataHub (Red Hat OpenShift AI) operator from stable-2.x (v2.25.0) to main (v3.0.0+) based on analysis of both source repositories.

## Version Information

**Source Version (stable-2.x):**
- CSV Name: `rhods-operator.v2.25.0`
- Product: Red Hat OpenShift AI (RHOAI)
- Version: 2.25.0
- Created: 2026-01-02
- Repository: `./src/opendatahub-io/opendatahub-operator.stable-2.x`

**Target Version (main):**
- CSV Name: `rhods-operator.v3.0.0`
- Alternative: `opendatahub-operator.v3.3.0` (ODH version)
- Version: 3.0.0 (RHOAI) / 3.3.0 (ODH)
- Repository: `./src/opendatahub-io/opendatahub-operator.main`

**Skip Range:** `olm.skipRange: '>=1.0.0 <2.0.0'`

## Phase 1: Pre-Upgrade Validation

### CRD Storage Version Checks

OLM will validate:
- Existing `DataScienceCluster` (v1) resources can coexist with new v2 API
- Existing `DSCInitialization` (v1) resources can coexist with new v2 API
- Existing `HardwareProfile` (v1alpha1) resources work with new v1 API
- All stored versions are preserved in the new CRD specs

**Safety Check**: `SafeStorageVersionUpgrade()` ensures no stored versions are removed without migration path.

### Dependency Resolution

OLM verifies:
- No conflicts with other operators providing same APIs
- All required external APIs are available:
  - Knative Serving (operator.knative.dev)
  - Istio networking (networking.istio.io)
  - Prometheus monitoring (monitoring.coreos.com)
  - KServe serving runtime (serving.kserve.io)
  - Ray clusters (ray.io)
  - Kueue workload management (kueue.x-k8s.io)

## Phase 2: CRD Updates

### New CRDs Added (5)

1. **`gatewayconfigs.services.platform.opendatahub.io`** (v1alpha1)
   - Kind: GatewayConfig
   - Purpose: Gateway configuration for services

2. **`mlflowoperators.components.platform.opendatahub.io`** (v1alpha1)
   - Kind: MLflowOperator
   - Purpose: MLflow experiment tracking and model registry

3. **`modelsasservices.components.platform.opendatahub.io`** (v1alpha1)
   - Kind: ModelsAsService
   - Purpose: Model serving as a service

4. **`sparkoperators.components.platform.opendatahub.io`** (v1alpha1)
   - Kind: SparkOperator
   - Purpose: Apache Spark integration

5. **`trainers.components.platform.opendatahub.io`** (v1alpha1)
   - Kind: Trainer
   - Purpose: New training component (replaces TrainingOperator)

### CRDs with New API Versions (Multi-Version Support)

1. **`datascienceclusters.datasciencecluster.opendatahub.io`**
   - v2.25.0: v1 only
   - v3.0.0: v1 + v2 (both versions supported)
   - Storage version: TBD (conversion webhook may handle)

2. **`dscinitializations.dscinitialization.opendatahub.io`**
   - v2.25.0: v1 only
   - v3.0.0: v1 + v2 (both versions supported)
   - Storage version: TBD (conversion webhook may handle)

3. **`hardwareprofiles.infrastructure.opendatahub.io`**
   - v2.25.0: v1alpha1 only
   - v3.0.0: v1alpha1 + v1 (both versions supported)
   - Storage version: TBD (conversion webhook may handle)

### Orphaned CRDs (Not Removed, No Longer Managed)

1. **`codeflares.components.platform.opendatahub.io`**
   - Status: Deprecated in RHOAI v3.0
   - CRD remains on cluster
   - Existing resources become unmanaged
   - No automatic cleanup

2. **`modelmeshservings.components.platform.opendatahub.io`**
   - Status: Deprecated in RHOAI v3.0
   - CRD remains on cluster
   - Existing resources become unmanaged
   - No automatic cleanup

**Important Note**: OLM does NOT automatically delete CRDs during upgrades. These CRDs will remain on the cluster even though the new operator version doesn't manage them. Existing custom resources will persist but won't be reconciled.

### Unchanged CRDs (Still Present and Managed)

- Auth (auths.services.platform.opendatahub.io, v1alpha1)
- Dashboard (dashboards.components.platform.opendatahub.io, v1alpha1)
- DataSciencePipelines (datasciencepipelines.components.platform.opendatahub.io, v1alpha1)
- FeastOperator (feastoperators.components.platform.opendatahub.io, v1alpha1)
- FeatureTracker (featuretrackers.features.opendatahub.io, v1)
- Kserve (kserves.components.platform.opendatahub.io, v1alpha1)
- Kueue (kueues.components.platform.opendatahub.io, v1alpha1)
- LlamaStackOperator (llamastackoperators.components.platform.opendatahub.io, v1alpha1)
- ModelController (modelcontrollers.components.platform.opendatahub.io, v1alpha1)
- ModelRegistry (modelregistries.components.platform.opendatahub.io, v1alpha1)
- Monitoring (monitorings.services.platform.opendatahub.io, v1alpha1)
- Ray (rays.components.platform.opendatahub.io, v1alpha1)
- TrainingOperator (trainingoperators.components.platform.opendatahub.io, v1alpha1)
- TrustyAI (trustyais.components.platform.opendatahub.io, v1alpha1)
- Workbenches (workbenches.components.platform.opendatahub.io, v1alpha1)

## Phase 3: RBAC Cleanup

### Removed RBAC Resources (9 files)

1. `components_codeflare_editor_role.yaml` - CodeFlare deprecated
2. `components_codeflare_viewer_role.yaml` - CodeFlare deprecated
3. `components_modelmeshserving_editor_role.yaml` - ModelMeshServing deprecated
4. `components_modelmeshserving_viewer_role.yaml` - ModelMeshServing deprecated
5. `datasciencecluster_datasciencecluster_editor_role.yaml` - Consolidated
6. `datasciencecluster_datasciencecluster_viewer_role.yaml` - Consolidated
7. `dscinitialization_dscinitialization_editor_role.yaml` - Consolidated
8. `dscinitialization_dscinitialization_viewer_role.yaml` - Consolidated
9. `role.yaml` - Main operator role consolidated

**Result**: Streamlined from 36 RBAC files to 27 RBAC files.

### Maintained RBAC

- Service Account: `redhat-ods-operator-controller-manager` (unchanged)
- ClusterRole and RoleBindings for operator permissions
- Editor/viewer roles for remaining components

**Impact**: Users with custom RBAC referencing removed roles may need updates.

## Phase 4: Deployment Update

### CSV Transition Flow

```
rhods-operator.v2.25.0 (Succeeded) → Replacing
                                       ↓
                              (Both CSVs running simultaneously)
                                       ↓
rhods-operator.v3.0.0 (Pending) → InstallReady → Installing → Succeeded
                                       ↓
rhods-operator.v2.25.0 (Replacing) → Deleting → Garbage collected
```

**Key Point**: Both operator versions run concurrently during transition to ensure zero downtime.

### Pod Replacement Process

1. **Old deployment continues running** - v2.25.0 operator pod stays active
2. **New deployment created** - v3.0.0 operator pod starts
3. **Health checks pass** - New pod reaches Ready state
4. **Owner reference transfer** - Resources gradually transferred to new CSV
5. **Old pod terminates** - v2.25.0 operator pod shuts down
6. **Garbage collection** - Old CSV and associated resources cleaned up

**Deployment Configuration:**
- Replicas: 3 (with pod anti-affinity for HA)
- Resource Limits:
  - CPU: 500m request/limit
  - Memory: 256Mi request / 4Gi limit
- Minimum Kubernetes Version: 1.25.0

## Phase 5: Existing Resource Impact

### Component State Changes

| Component | v2.25.0 State | v3.0.0 State | User Impact |
|-----------|---------------|--------------|-------------|
| CodeFlare | Managed | **Removed** | ⚠️ Existing resources orphaned, no longer reconciled |
| ModelMeshServing | Managed | **Removed** | ⚠️ Existing resources orphaned, no longer reconciled |
| TrainingOperator | Managed | **Removed** | ⚠️ Replaced by Trainer component - migration required |
| Kueue | Managed | **Removed** (RHOAI only) | ⚠️ Workload management changes |
| Dashboard | Managed | Managed | ✅ Continues working |
| DataSciencePipelines | Managed | Managed (renamed "aipipelines") | ✅ Continues working |
| FeastOperator | Removed | Managed | ✅ Now available |
| Kserve | Managed | Managed | ✅ Continues working |
| ModelRegistry | Managed | Managed | ✅ Continues working |
| Ray | Managed | Managed | ✅ Continues working |
| TrustyAI | Managed | Managed | ✅ Continues working |
| Workbenches | Managed | Managed | ✅ Continues working |
| **Trainer** | N/A | **Managed** | ✅ New component available |
| **MLflowOperator** | N/A | **Removed** (RHOAI) | ℹ️ Available in ODH only |
| **SparkOperator** | N/A | **Removed** (RHOAI) | ℹ️ Available in ODH only |

### What Happens to Existing Resources

**DataScienceCluster v1 Instances:**
- Continue to work unchanged (v1 API still supported)
- Operator reconciles using v1 API
- Users can migrate to v2 API manually at their convenience
- No automatic conversion between v1 and v2

**DSCInitialization v1 Instances:**
- Continue to work unchanged (v1 API still supported)
- Operator reconciles using v1 API
- Users can migrate to v2 API manually at their convenience

**HardwareProfile v1alpha1 Instances:**
- Continue to work (v1alpha1 API still supported)
- Can start using v1 API for new instances

**CodeFlare Resources:**
- Existing CRs persist on cluster
- No longer reconciled by operator
- No automatic cleanup or deletion
- Users must manually manage or migrate

**ModelMeshServing Resources:**
- Existing CRs persist on cluster
- No longer reconciled by operator
- No automatic cleanup or deletion
- Users must manually manage or migrate

**TrainingOperator Resources:**
- Component marked "Removed"
- Replaced by new "Trainer" component
- Users must migrate workloads to Trainer

## Phase 6: Webhook Updates

### Admission Webhooks (Unchanged)

All webhooks maintain the same configuration:

**Mutating Webhooks:**
- connection-isvc.opendatahub.io (KServe)
- connection-notebook.opendatahub.io (Kubeflow Notebooks)
- datasciencecluster-defaulter.opendatahub.io
- hardwareprofile-kserve-injector.opendatahub.io
- hardwareprofile-notebook-injector.opendatahub.io

**Validating Webhooks:**
- datasciencecluster-validator.opendatahub.io
- dscinitialization-validator.opendatahub.io
- kserve-kueuelabels-validator.opendatahub.io
- kubeflow-kueuelabels-validator.opendatahub.io
- ray-kueuelabels-validator.opendatahub.io

**Impact**: No disruption to admission control during upgrade.

## Phase 7: Post-Upgrade State

### What Users Will See

**Installed CSV:**
- Name: `rhods-operator.v3.0.0`
- Phase: Succeeded
- Installed: Current timestamp

**Removed CSV:**
- Name: `rhods-operator.v2.25.0`
- Status: Deleted (garbage collected)

**Available CRDs:**
- 5 new CRDs available for use (GatewayConfig, MLflowOperator, ModelsAsService, SparkOperator, Trainer)
- 2 orphaned CRDs present but unmanaged (CodeFlare, ModelMeshServing)
- 3 CRDs with dual API version support (DSC, DSCI, HardwareProfile)

**Operator Pod:**
- New deployment: `rhods-operator-controller-manager-xxxxx`
- Image: Updated to v3.0.0
- Status: Running

**Documentation:**
- Updated link: docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3-latest

## Key Risks and Considerations

### 1. Breaking Change: Component Removal

**CodeFlare:**
- No longer managed in RHOAI v3.0
- Existing CodeFlare resources become orphaned
- No automatic migration or cleanup
- Users must:
  - Manually delete CodeFlare CRs if no longer needed
  - Migrate to alternative solutions
  - CRD will remain on cluster indefinitely

**ModelMeshServing:**
- No longer managed in RHOAI v3.0
- Existing ModelMesh resources become orphaned
- No automatic migration or cleanup
- Users must:
  - Migrate to KServe for model serving
  - Manually clean up ModelMesh resources
  - CRD will remain on cluster indefinitely

**TrainingOperator:**
- Changed to "Removed" status
- Replaced by new "Trainer" component
- Users must:
  - Migrate training workloads to Trainer
  - Update automation/scripts
  - Test new Trainer functionality

**Kueue:**
- Changed to "Removed" in RHOAI (still active in ODH)
- Workload management changes
- Users must evaluate alternatives or use ODH

### 2. API Version Migration

**No Automatic Conversion:**
- v1 APIs continue to work
- v2 APIs are available but optional
- Manual migration required to use v2 features
- No automatic conversion webhook configured

**Migration Path:**
- Users should plan gradual migration from v1 to v2
- Test v2 APIs in development environments
- Update automation to use v2 schemas
- Monitor deprecation notices for v1 APIs

### 3. RBAC Changes

**Impact on Custom RBAC:**
- 9 RBAC files removed
- Editor/viewer roles consolidated
- Users with custom ClusterRoleBindings or RoleBindings may need updates
- Service accounts referencing old roles may lose permissions

**Mitigation:**
- Review all custom RBAC before upgrade
- Update role references after upgrade
- Test user permissions post-upgrade

### 4. No Rollback Path

**OLM Fail-Forward Strategy:**
- If upgrade fails, old CSV remains in Succeeded state
- New CSV may be in Failed state
- No automatic rollback to v2.25.0
- Manual intervention required to resolve failures

**Failure Scenarios:**
1. CRD validation fails → Old CSV continues running, new CSV fails to install
2. Deployment fails → Old pod continues running, new pod never reaches Ready
3. Webhook validation fails → Admission control may block operations
4. RBAC conflicts → Operator may not have sufficient permissions

**Recovery:**
- Delete failed InstallPlan
- Delete failed CSV
- Operator will retry with new InstallPlan
- Consider enabling `UnsafeFailForward` for downgrades

### 5. Data Loss Prevention

**CRD Storage Version Safety:**
- OLM validates storage versions before upgrade
- Prevents removal of stored API versions
- Ensures data compatibility

**Validation Checks:**
- All existing CRs validated against new schemas
- Schema incompatibilities cause upgrade failure
- Protects against data corruption

## What OLM Does Beyond Simple Pod Restart

### Safety Mechanisms Active During This Upgrade

1. ✅ **CRD Storage Version Validation**
   - Prevents data loss from CRD version changes
   - Validates storage version compatibility
   - Located: `pkg/lib/crd/storage.go:SafeStorageVersionUpgrade()`

2. ✅ **Existing CR Schema Validation**
   - Validates all existing Custom Resources against new CRD schemas
   - Ensures no resources break with new schema
   - Located: `pkg/controller/operators/catalog/step.go:validateV1CRDCompatibility()`

3. ✅ **Dual-CSV Operation**
   - Both v2.25.0 and v3.0.0 CSVs run simultaneously during transition
   - Zero downtime for operator functionality
   - Smooth owner reference transfer

4. ✅ **Atomic InstallPlan**
   - All resources created together or none
   - CRDs → ServiceAccounts → Roles → Deployments in order
   - Failure at any step prevents partial upgrade

5. ✅ **Dependency Checking**
   - Ensures all required external APIs are available
   - Prevents operator failure due to missing dependencies
   - Resolver validates dependency graph

6. ✅ **RBAC Updates**
   - Removes 9 obsolete RBAC files
   - Creates new roles as needed
   - Maintains service account

7. ✅ **Webhook Preservation**
   - Admission control continues working during upgrade
   - No gap in validation/mutation
   - Webhooks configured in CSV

8. ✅ **Owner Reference Tracking**
   - Proper cleanup of old CSV-owned resources
   - Prevents resource leaks
   - Enables garbage collection

## InstallPlan Steps (Detailed)

When the upgrade is triggered, OLM will create an InstallPlan with approximately these steps:

1. **CRD Installation/Updates** (5 new + 3 updated):
   - Create `gatewayconfigs.services.platform.opendatahub.io`
   - Create `mlflowoperators.components.platform.opendatahub.io`
   - Create `modelsasservices.components.platform.opendatahub.io`
   - Create `sparkoperators.components.platform.opendatahub.io`
   - Create `trainers.components.platform.opendatahub.io`
   - Update `datascienceclusters.datasciencecluster.opendatahub.io` (add v2)
   - Update `dscinitializations.dscinitialization.opendatahub.io` (add v2)
   - Update `hardwareprofiles.infrastructure.opendatahub.io` (add v1)

2. **RBAC Creation** (27 files maintained):
   - Maintain service account
   - Update ClusterRoles with new permissions
   - Update RoleBindings

3. **RBAC Deletion** (9 files):
   - Delete CodeFlare editor/viewer roles
   - Delete ModelMeshServing editor/viewer roles
   - Delete DSC/DSCI editor/viewer roles
   - Delete consolidated role.yaml

4. **CSV Creation**:
   - Create `rhods-operator.v3.0.0` resource

5. **Deployment Update**:
   - Create new deployment for v3.0.0
   - Wait for new pod to reach Ready
   - Old deployment remains until new is healthy

6. **Webhook Configuration**:
   - Update webhook configurations (if changed)
   - Maintain admission control

7. **CSV Transition**:
   - Mark old CSV as Replacing
   - Transfer owner references to new CSV
   - Mark old CSV for deletion

## Subscription State Transitions

```
Subscription State Machine:

Initial: subscription.status.installedCSV = "rhods-operator.v2.25.0"
         subscription.status.state = "AtLatestKnown"

↓ (Catalog updated with v3.0.0)

Step 1:  subscription.status.state = "UpgradeAvailable"
         (Resolver detects v3.0.0 replaces v2.25.0)

↓ (InstallPlan created)

Step 2:  subscription.status.state = "UpgradePending"
         subscription.status.installPlanRef = "install-xxxxx"
         (InstallPlan in "Installing" phase)

↓ (InstallPlan completes)

Step 3:  subscription.status.state = "AtLatestKnown"
         subscription.status.installedCSV = "rhods-operator.v3.0.0"
         subscription.status.currentCSV = "rhods-operator.v3.0.0"
```

## Timeline Estimate

**Note**: While providing specific time estimates violates the guideline, the sequence is:

1. Pre-upgrade validation (CRD checks, dependency resolution)
2. InstallPlan creation and approval (if manual approval required)
3. CRD installations/updates
4. RBAC updates
5. Deployment creation
6. Pod startup and readiness
7. CSV transition and garbage collection

Each step must complete before the next begins. The entire process is atomic from OLM's perspective.

## Recommended Pre-Upgrade Actions

1. **Backup Critical Resources:**
   - Export all DataScienceCluster v1 instances
   - Export all DSCInitialization v1 instances
   - Export CodeFlare resources (if migrating)
   - Export ModelMeshServing resources (if migrating)

2. **Plan Component Migrations:**
   - Develop migration strategy for CodeFlare → Alternative
   - Develop migration strategy for ModelMeshServing → KServe
   - Develop migration strategy for TrainingOperator → Trainer
   - Test migrations in non-production environment

3. **Review Custom RBAC:**
   - Identify dependencies on removed RBAC roles
   - Plan RBAC updates for v3.0.0
   - Test RBAC permissions after upgrade

4. **Test in Non-Production:**
   - Deploy v3.0.0 in test environment
   - Validate all workloads function correctly
   - Test v2 API compatibility
   - Verify webhook functionality

5. **Communication Plan:**
   - Notify users of component removals
   - Document migration procedures
   - Plan maintenance window (even with zero downtime, issues may occur)

## Conclusion

This upgrade from v2.25.0 to v3.0.0 represents a significant evolution of the OpenDataHub/RHOAI operator with:

- **5 new CRDs** for expanded functionality
- **3 CRDs with dual API version support** for gradual migration
- **Component restructuring** with removals and additions
- **RBAC simplification** with fewer role files
- **Backward compatibility** maintained through multi-version API support

OLM's orchestration ensures a safe, validated upgrade process that goes far beyond simple pod replacement, with multiple safety checks preventing data loss and ensuring zero downtime during the transition.

**Critical takeaway**: Users must proactively plan migrations for deprecated components (CodeFlare, ModelMeshServing, TrainingOperator) as these will become unmanaged after upgrade but their resources will persist on the cluster.
