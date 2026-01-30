# Comprehensive Analysis: OLM Operator Upgrade Process

Based on exploration of the operator-lifecycle-manager codebase, here's a detailed breakdown of how OLM handles operator upgrades:

## 1. UPGRADE STEPS AND ORCHESTRATION

### A. Upgrade Discovery Phase
- **Catalog Polling**: OLM continuously monitors CatalogSources (operator repositories) for new operator versions
- **Channel-Based Updates**: Operators are organized into channels within packages in catalogs. OLM tracks the "channel head" (latest version in a channel)
- **Dependency Graph Construction**: The resolver examines the `replaces` field in ClusterServiceVersions (CSVs) to build a directed acyclic graph (DAG) of versions

**Key File**: `src/operator-framework/operator-lifecycle-manager/pkg/controller/registry/resolver/resolver.go`

The `sortChannel()` function (line 589-679) sorts operator versions by their replacement chain:
- Detects circular dependencies in upgrade paths
- Identifies channel heads (versions not replaced by any other version)
- Ensures a unique replacement chain within each channel

### B. Upgrade Path Resolution
The resolver algorithm (`getSubscriptionVariables()` method at line 228) determines the upgrade path by:
1. Finding the currently installed CSV (tracked in `status.InstalledCSV`)
2. Filtering available operators that can replace it using two predicates:
   - `SkipRangeIncludesPredicate`: Matches if current version falls within a skipRange annotation
   - `ReplacesPredicate`: Matches if the operator explicitly replaces the current version
3. Walking backwards from channel head through the replacement chain to find intermediate versions

**Example from documentation** (`how-to-update-operators.md`):
If installed version is 0.1.1, available versions are 0.1.2 and 0.1.3 (where 0.1.3 replaces 0.1.2 which replaces 0.1.1), OLM will:
- Install 0.1.2 to replace 0.1.1
- Then install 0.1.3 to replace 0.1.2 (one version at a time)

### C. Subscription State Machine
Located in: `src/operator-framework/operator-lifecycle-manager/pkg/controller/operators/catalog/subscription/state.go`

Subscription states during upgrade:
- `None` → `UpgradeAvailable`: Catalog contains a CSV that replaces the installed one
- `UpgradeAvailable` → `UpgradePending`: InstallPlan has been created
- `UpgradePending` → `AtLatestKnown`: Upgrade completes and installed CSV matches latest

## 2. VALIDATION, DEPENDENCY RESOLUTION, AND SAFETY CHECKS

### A. CRD Compatibility Validation
File: `src/operator-framework/operator-lifecycle-manager/pkg/controller/operators/catalog/step.go` (lines 146-177, 253-274)

Two types of validation:

1. **Existing Custom Resource Validation** (`validateV1CRDCompatibility()` / `validateV1Beta1CRDCompatibility()`):
   - Validates all existing Custom Resources against the new CRD's schema
   - Checks if existing served versions are still served in new CRD
   - For v1beta1, handles special case where Spec.Validation and Spec.Versions are mutually exclusive
   - If conversion webhook is specified, warns but allows (trusts webhook to convert)

2. **Storage Version Safety Check** (`SafeStorageVersionUpgrade()` at `src/operator-framework/operator-lifecycle-manager/pkg/lib/crd/storage.go`):
   - **CRITICAL SAFETY CHECK**: Ensures all stored versions from the on-cluster CRD exist in new CRD spec
   - Prevents data loss during CRD migrations
   - Returns error if any stored version would be removed without migration path
   - Checks CRD status.StoredVersions against new spec.Versions

### B. Dependency Resolution Algorithm
File: `dependency-resolution.md` and `pkg/controller/registry/resolver/resolver.go`

The resolver ensures operators work together by:
1. **Preventing API Starvation**: Never uninstalls a provider of a required API without a replacement
2. **Version Deadlock Prevention**: Can simultaneously upgrade interdependent operators
3. **Downgrade Strategy**: If a newer version can't be installed due to missing dependencies, downgrades to previous version
4. **Conflict Detection**: Prevents multiple operators providing the same API (single-package-instance invariant)

**Example scenario from documentation**: If operator A requires API B (provided by operator B), and both need to upgrade:
- Old: A v1.0 requires B v1.0, B provides B v1.0
- New: A v2.0 requires B v2.0, B v2.0 provides B v2.0
- Solution: Both are upgraded together, preventing downtime

### C. Fail-Forward Strategy
File: `src/operator-framework/operator-lifecycle-manager/pkg/controller/registry/resolver/fail_forward.go`

When enabled via OperatorGroup `upgradeStrategy: UnsafeFailForward`:
- Allows downgrades if upgrade fails
- `WalkReplacementChain()` traverses CSV replacement chains and detects failure states
- Subscription transitions to `SubscriptionStateFailed` if InstallPlan fails
- Useful in disconnected environments where high availability is less critical than availability

## 3. INSTALL PLAN EXECUTION

### A. Plan Generation
File: `src/operator-framework/operator-lifecycle-manager/pkg/controller/operators/catalog/operator.go` (lines 1653-1748)

Install plans contain:
- List of steps (resources to create: CRDs, Deployments, ServiceAccounts, Roles, RoleBindings, etc.)
- ClusterServiceVersion names
- Approval strategy (Automatic or Manual)
- Generation number (prevents race conditions in parallel resolution)

Thread-safe plan creation uses mutex lock to prevent duplicate plans from concurrent workers.

### B. Step Execution
Files:
- `pkg/controller/operators/catalog/step_ensurer.go`: Ensures resources exist
- `pkg/controller/operators/catalog/step.go`: Handles CRD creation/updates

Steps execute in dependency order:
1. CRDs created/validated first
2. ServiceAccounts, Roles, RoleBindings created
3. CSV resource created
4. Deployment replaces old pod (triggers pod rolling update)

### C. CSV Transition During Upgrade
File: `architecture.md` (CSV Control Loop)

CSV phases during upgrade:
```
Succeeded (old) → Replacing (detected new CSV) → Deleting (garbage collection)
                ↓
         (Old running while new installs)
                ↓
None → Pending → InstallReady → Installing → Succeeded (new)
```

Key: **Both CSVs run simultaneously during transition** to ensure no downtime and safe owner reference transfer.

## 4. ROLLBACK AND FAILURE HANDLING

### A. Rollback Scenarios
OLM does **not have explicit rollback**, instead:

1. **Failed InstallPlan**: If new version fails to install
   - InstallPlan phase transitions to `Failed`
   - Old CSV remains in `Succeeded` state
   - New CSV may be in `Failed` state
   - Subscription can optionally downgrade with `UnsafeFailForward`

2. **New CSV Detected Issue**: If new CSV can't reach `Succeeded` phase
   - Old CSV remains `Succeeded` and operational
   - Resources continue running with old version

### B. Fail-Forward (Unsafe Downgrade)
When enabled:
- If upgrade fails (InstallPlan phase is `Failed`), resolver can find older versions
- Subscription status transitions to `SubscriptionStateFailed`
- Administrator must manually delete the failed InstallPlan or CSV to trigger resolution

File: `pkg/controller/operators/catalog/operator.go` (lines 1590-1616)

### C. Manual Approval Gates
- InstallPlans can require manual approval before execution
- Humans review plan before approval (prevents bad upgrades)
- Subscription approval strategy: `ApprovalAutomatic` or `ApprovalManual`

## 5. VERSION SKIPPING AND SAFETY

### A. Skip Ranges
File: `how-to-update-operators.md` (lines 96-122)

Annotation: `olm.skipRange: '>=4.1.0 <4.1.2'`

Allows skipping problematic intermediate versions:
- If current version falls in skipRange, jumps directly to channel head
- Prevents installation of bad/vulnerable versions
- Used for security patches and critical fixes

### B. Skipped Releases
CSV field: `spec.skips: [etcdoperator.v0.9.1]`

Allows replacing specific versions:
- Newer version can skip bad intermediate versions
- Maintains update graph consistency across clusters
- Both for clusters that have seen bad version and those that haven't

## 6. KEY SAFETY MECHANISMS

1. **Atomic Resource Creation**: All resources in InstallPlan treated as unit
2. **Owner References**: Track which CSV manages which resources (enables cleanup)
3. **CRD Storage Version Protection**: Prevents data loss during CRD migrations
4. **Existing CR Validation**: Ensures no existing custom resources break
5. **Concurrent Update Safety**: Mutex-protected plan creation, generation numbers
6. **Catalog Invariant**: Single unambiguous upgrade path per package/channel
7. **Dependency Graph Validation**: Detects cycles, ensures all APIs are provided

## SUMMARY OF KEY FILES

| File Path | Purpose |
|-----------|---------|
| `pkg/controller/operators/catalog/operator.go` | Main catalog operator, InstallPlan creation/execution |
| `pkg/controller/registry/resolver/resolver.go` | Dependency resolution and upgrade path calculation |
| `pkg/controller/operators/catalog/subscription/state.go` | Subscription state machine |
| `pkg/controller/operators/catalog/step.go` | CRD validation and resource creation |
| `pkg/lib/crd/storage.go` | CRD storage version safety checks |
| `doc/design/how-to-update-operators.md` | Upgrade path documentation |
| `doc/design/dependency-resolution.md` | Dependency resolution algorithm |
| `doc/design/architecture.md` | Overall architecture and state machines |

## CONCLUSION

OLM's upgrade approach is fundamentally **safe-first**, designed to ensure operators remain running and functional throughout version transitions, with multiple validation layers preventing data loss and dependency conflicts.

The key differentiators beyond simple pod replacement are:
- Dependency graph resolution preventing conflicts
- CRD and CR validation preventing data loss
- Dual-CSV operation during transition for zero downtime
- Atomic InstallPlan execution with all required resources
- Version skipping for security patches
- Owner reference tracking for cleanup

The pod replacement is actually one of the **final steps** after extensive validation and resource preparation.
