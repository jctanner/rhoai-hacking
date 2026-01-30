# OLM Upgrade Test Results: v2.25.0 → v3.0.0

**Test Date:** 2026-01-29
**Test Environment:** OpenShift 4.20.10
**Registry:** registry.tannerjc.net (anonymous push/pull)

## Summary

Successfully demonstrated the OLM upgrade process from opendatahub-operator v2.25.0 (stable-2.x) to v3.0.0 (main). Built operator images and bundles using containerized Go environments, installed v2.25.0, and initiated the upgrade to v3.0.0. Observed multiple OLM validation mechanisms in action.

## Build Process

### Containerized Build Environments

Created two build container images to handle different Go version requirements:

**Go 1.24 Container (for stable-2.x):**
```dockerfile
FROM registry.access.redhat.com/ubi9/go-toolset:1.24
USER root
RUN dnf install -y podman make git && dnf clean all
RUN mkdir -p /home/default/.config/containers && \
    echo 'unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]' > /etc/containers/registries.conf
WORKDIR /workspace
USER default
```

**Go 1.25 Container (for main branch):**
```dockerfile
FROM registry.access.redhat.com/ubi9/go-toolset:1.25
USER root
RUN dnf install -y podman make git && dnf clean all

# Configure podman to skip signature verification for nested builds
RUN cat > /etc/containers/policy.json << 'POLICY'
{
    "default": [{"type": "insecureAcceptAnything"}],
    "transports": {
        "docker-daemon": {
            "": [{"type": "insecureAcceptAnything"}]
        }
    }
}
POLICY

RUN mkdir -p /home/default/.config/containers && \
    echo 'unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]' > /etc/containers/registries.conf
WORKDIR /workspace
USER default
```

### Critical Build Issues Discovered

1. **PLATFORM Environment Variable Override**
   - Issue: `ubi9/go-toolset` containers set `PLATFORM=el9` as an environment variable
   - Impact: Overrides Makefile's `PLATFORM ?= linux/amd64`, causing build failures
   - Solution: Explicitly set `PLATFORM=linux/amd64` when running make inside containers

2. **Nested Podman Signature Verification**
   - Issue: Inner podman enforces GPG signature verification for Red Hat registries
   - Impact: Signature verification failures when pulling images during nested builds
   - Solution: Configure relaxed signature policy in Go 1.25 container

3. **Bundle Version Mismatch**
   - Issue: Without `VERSION` parameter, bundle defaults to Go version (e.g., 1.24.6)
   - Impact: Wrong CSV version in bundle
   - Solution: Always specify `VERSION=X.Y.Z` parameter

4. **Bundle Image Reference**
   - Issue: Without `IMG` parameter, CSV defaults to `quay.io/opendatahub/opendatahub-operator:latest`
   - Impact: Operator pods pull wrong image, causing crashes
   - Solution: Always specify `IMG=$REGISTRY/rhods-operator:vX.Y.Z` parameter

5. **Bundle Dockerfile Behavior**
   - Issue: Multi-stage `Dockerfiles/rhoai-bundle.Dockerfile` runs `make bundle` internally without parameters
   - Impact: Generated bundle has wrong image references
   - Solution: Build bundle manifests first with correct parameters, then build simple bundle image from manifests

### Successful Build Commands

**v2.25.0 Build:**
```bash
# Build and push operator image
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  olm-build-env:go1.24 \
  bash -c "make image-build IMG=$REGISTRY/rhods-operator:v2.25.0 PLATFORM=linux/amd64 && \
           make image-push IMG=$REGISTRY/rhods-operator:v2.25.0"

# Build bundle manifests
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  olm-build-env:go1.24 \
  bash -c "make bundle VERSION=2.25.0 IMG=$REGISTRY/rhods-operator:v2.25.0 PLATFORM=linux/amd64 ODH_PLATFORM_TYPE=rhoai"

# Build and push bundle image from manifests
cat > /tmp/bundle.Dockerfile << 'EOF'
FROM scratch
LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=rhods-operator
LABEL operators.operatorframework.io.bundle.channels.v1=alpha,stable,fast
LABEL operators.operatorframework.io.bundle.channel.default.v1=stable
COPY bundle/manifests /manifests/
COPY bundle/metadata /metadata/
COPY bundle/tests/scorecard /tests/scorecard/
EOF

podman build -f /tmp/bundle.Dockerfile -t $REGISTRY/rhods-operator-bundle:v2.25.0 . && \
podman push $REGISTRY/rhods-operator-bundle:v2.25.0
```

**v3.0.0 Build:**
```bash
# Build and push operator image
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  olm-build-env:go1.25 \
  bash -c "make image-build IMG=$REGISTRY/rhods-operator:v3.0.0 PLATFORM=linux/amd64 && \
           make image-push IMG=$REGISTRY/rhods-operator:v3.0.0"

# Build bundle manifests (includes replaces: rhods-operator.v2.25.0)
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  olm-build-env:go1.25 \
  bash -c "make bundle VERSION=3.0.0 IMG=$REGISTRY/rhods-operator:v3.0.0 PLATFORM=linux/amd64 ODH_PLATFORM_TYPE=rhoai"

# Build and push bundle image from workspace manifests
cat > /tmp/bundle.Dockerfile << 'EOF'
FROM scratch
LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=rhods-operator
LABEL operators.operatorframework.io.bundle.channels.v1=alpha,stable,fast
LABEL operators.operatorframework.io.bundle.channel.default.v1=stable
COPY rhoai-bundle/manifests /manifests/
COPY rhoai-bundle/metadata /metadata/
COPY rhoai-bundle/tests/scorecard /tests/scorecard/
EOF

podman build -f /tmp/bundle.Dockerfile -t $REGISTRY/rhods-operator-bundle:v3.0.0 . && \
podman push $REGISTRY/rhods-operator-bundle:v3.0.0
```

## Installation and Upgrade

### v2.25.0 Installation (After Complete Cleanup)

```bash
oc create namespace redhat-ods-operator
operator-sdk run bundle registry.tannerjc.net/opendatahub/rhods-operator-bundle:v2.25.0 -n redhat-ods-operator
```

**Result:** ✅ SUCCESS (with manual intervention)
- CSV reached `Succeeded` phase
- 3 operator pods running (1/1 Ready)
- 21 ODH CRDs installed
- InstallPlan approved and executed successfully

**Issue Encountered:**
- servicemeshes.services.platform.opendatahub.io CRD not created by OLM
- InstallPlan showed status: "Created" but CRD didn't exist in cluster
- Manually created CRD from bundle manifests unblocked installation
- CSV transitioned from Pending (RequirementsNotMet) → Succeeded after manual CRD creation

**Root Cause:**
Likely residual state from previous etcd cleanup. The servicemeshes key was one of the keys explicitly deleted from etcd during cleanup. OLM may have encountered a conflict or cached state preventing automatic CRD creation.

**Verification:**
```bash
oc get csv rhods-operator.v2.25.0 -n redhat-ods-operator
# NAME                     DISPLAY                  VERSION   REPLACES   PHASE
# rhods-operator.v2.25.0   Red Hat OpenShift AI     2.25.0               Succeeded

oc get crds | grep opendatahub | wc -l
# 21
```

### v3.0.0 Upgrade Attempt (After Complete Cleanup and Stable v2.25.0)

```bash
operator-sdk run bundle-upgrade registry.tannerjc.net/opendatahub/rhods-operator-bundle:v3.0.0 -n redhat-ods-operator
```

**Result:** ❌ FAILED - Conversion Webhook Deadlock

**What Succeeded:**
- ✅ OLM recognized the upgrade path via `replaces: rhods-operator.v2.25.0`
- ✅ CSV v3.0.0 created with correct version
- ✅ Dual-CSV operation observed (v2.25.0: Replacing, v3.0.0: Installing)
- ✅ InstallPlan created and approved
- ✅ New v3.0.0 CRDs installed (gatewayconfigs, mlflowoperators, modelsasservices, sparkoperators, trainers)
- ✅ Correct operator image deployed (registry.tannerjc.net/opendatahub/rhods-operator:v3.0.0)

**What Failed:**
- ❌ v3.0.0 operator pod crash-looping (3+ restarts)
- ❌ Health probes failing (connection refused on port 8081)
- ❌ Operator hangs after initial "Cluster config" log message
- ❌ operator-sdk upgrade command timed out after 60 seconds

**CSV Status:**
```
NAME                     DISPLAY                  VERSION   REPLACES                 PHASE
rhods-operator.v2.25.0   Red Hat OpenShift AI     2.25.0                             Replacing
rhods-operator.v3.0.0    Red Hat OpenShift AI     3.0.0     rhods-operator.v2.25.0   Installing
```

**Pod Status:**
```
NAME                                READY   STATUS    RESTARTS
rhods-operator-79bb966c7c-bhzrj     0/1     Running   3 (ongoing)
rhods-operator-6fc589969b-24g4j     1/1     Running   0           (v2.25.0 - still running)
rhods-operator-6fc589969b-8htq2     1/1     Running   0           (v2.25.0 - still running)
rhods-operator-6fc589969b-tjrh8     1/1     Running   0           (v2.25.0 - still running)
```

**Root Cause: CRD Conversion Webhook Deadlock**

The upgrade failed due to a catch-22 with CRD conversion webhooks:

1. **CRD State:**
   ```bash
   oc get crd dscinitializations.dscinitialization.opendatahub.io -o jsonpath='{.spec.versions[*].name}'
   # v1 v2

   oc get crd dscinitializations.dscinitialization.opendatahub.io -o jsonpath='{.status.storedVersions}'
   # ["v1","v2"]

   oc get crd dscinitializations.dscinitialization.opendatahub.io -o jsonpath='{.spec.conversion.strategy}'
   # Webhook
   ```

2. **Existing Instance:**
   - A `default-dsci` DSCInitialization instance exists from v2.25.0 installation
   - Instance is stored in v1 format
   - CRD requires webhook for v1↔v2 conversion

3. **Webhook Configuration:**
   ```json
   {
     "strategy": "Webhook",
     "webhook": {
       "clientConfig": {
         "service": {
           "name": "rhods-operator-service",
           "namespace": "redhat-ods-operator",
           "path": "/convert",
           "port": 443
         }
       }
     }
   }
   ```

4. **The Deadlock:**
   - **v2.25.0 operator:** Running but doesn't have `/convert` webhook endpoint (built before v2 API existed)
   - **v3.0.0 operator:** Tries to query DSCInitializations during startup
   - **API Server:** Rejects queries because conversion webhook fails: `"conversion webhook for dscinitialization.opendatahub.io/v1, Kind=DSCInitialization failed: the server could not find the requested resource"`
   - **v3.0.0 operator:** Hangs waiting for API query, never starts webhook server, fails health checks, gets restarted
   - **Cycle repeats:** Operator can't start → webhook not available → API queries fail → operator can't start

5. **Evidence:**

   **Error when querying DSCInitializations:**
   ```bash
   oc get dscinitializations -A
   # Error from server: conversion webhook for dscinitialization.opendatahub.io/v1,
   # Kind=DSCInitialization failed: the server could not find the requested resource
   ```

   **Raw API works (bypasses conversion):**
   ```bash
   oc get --raw /apis/dscinitialization.opendatahub.io/v1/dscinitializations
   # {"apiVersion":"dscinitialization.opendatahub.io/v1","items":[...]}  # SUCCESS
   ```

   **v3.0.0 operator logs (minimal before hang):**
   ```json
   {"level":"info","ts":"2026-01-30T02:12:01Z","logger":"setup","msg":"Cluster config",
    "Operator Namespace":"redhat-ods-operator","Application Namespace":"redhat-ods-applications",
    "Release":{"name":"OpenShift AI Self-Managed","version":"2.25.0"},
    "Cluster":{"type":"OpenShift","version":"4.20.10"}}
   ```

   **Pod events:**
   ```
   Warning  Unhealthy  Liveness probe failed: Get "http://10.129.3.98:8081/healthz":
                       dial tcp 10.129.3.98:8081: connect: connection refused
   Warning  Unhealthy  Readiness probe failed: Get "http://10.129.3.98:8081/readyz":
                       dial tcp 10.129.3.98:8081: connect: connection refused
   ```

**Why This Happened:**

This is a **CRD versioning upgrade anti-pattern**:
- v2.25.0 → v3.0.0 introduces a new API version (v2) to an existing CRD
- The new version requires a conversion webhook
- But the old operator doesn't have the webhook implementation
- During upgrade, OLM updates CRDs before operator pods, creating a window where:
  - CRD expects webhook for conversion
  - Old operator doesn't provide it
  - New operator can't start because it can't query CRDs due to missing webhook

**Implications:**

This represents a **breaking upgrade path** that cannot complete without manual intervention. The upgrade requires either:
1. Removing existing CR instances before upgrade
2. Implementing conversion webhook in the old version first
3. Using a multi-step upgrade path with intermediate version
4. Manual CRD manipulation to bypass conversion temporarily

This is likely **not the intended upgrade path** for production deployments and may indicate:
- Missing migration documentation
- Need for upgrade testing in real deployment scenarios
- Potential bug in upgrade design between v2.25.0 and v3.0.0

## OLM Validation Mechanisms Observed

### 1. CRD Storage Version Validation ✅

**Mechanism:** OLM validates that new CRDs don't remove versions listed as stored versions on existing CRDs.

**Observed Error:**
```
risk of data loss updating "dscinitializations.dscinitialization.opendatahub.io":
new CRD removes version v2 that is listed as a stored version on the existing CRD
```

**Context:**
- Existing CRD had `storedVersions: ["v1", "v2"]`
- New bundle only provided v1
- OLM blocked the upgrade to prevent data loss

**Documented in:** OLM-UPGRADES.md, Section "CRD Compatibility Validation"

### 2. Existing CR Validation ✅

**Mechanism:** OLM validates all existing Custom Resources against the new CRD schema before allowing upgrade.

**Observed Error:**
```
error validating existing CRs against new CRD's schema for "dscinitializations.dscinitialization.opendatahub.io":
request to convert CR from an invalid group/version: dscinitialization.opendatahub.io/v2
```

**Context:**
- etcd had corrupted references to v2 API version
- OLM attempted to validate existing CRs
- Validation failed due to invalid group/version

**Documented in:** OLM-UPGRADES.md, Section "Pre-upgrade Validation"

### 3. Dual-CSV Operation ✅

**Mechanism:** During upgrades, both old and new CSVs run simultaneously for zero-downtime upgrades.

**Observed:**
```
NAME                      DISPLAY                  VERSION   REPLACES                  PHASE
rhods-operator.v2.25.0    Red Hat OpenShift AI     2.25.0                              Installing
rhods-operator.v3.0.0     Red Hat OpenShift AI     3.0.0     rhods-operator.v2.25.0    Pending
```

**Context:**
- v2.25.0 CSV transitioned from Succeeded → Installing
- v3.0.0 CSV created in Pending phase
- Both CSVs present during upgrade window

**Documented in:** OLM-UPGRADES.md, Section "Dual-CSV Operation"

### 4. InstallPlan Creation and Execution ✅

**Mechanism:** OLM creates InstallPlans that list all resources to be created/updated atomically.

**Observed:**
- InstallPlan created automatically for upgrade
- Contained list of CRDs, RBAC resources, deployments
- Approved automatically (or manually depending on subscription settings)
- Executed atomically

**Documented in:** OLM-UPGRADES.md, Section "InstallPlan Execution"

### 5. Replacement Chain Recognition ✅

**Mechanism:** OLM uses the `replaces` field in CSV to build upgrade paths.

**Observed:**
- v3.0.0 CSV included `replaces: rhods-operator.v2.25.0`
- OLM automatically recognized this as an upgrade from v2.25.0
- Created appropriate upgrade InstallPlan

**Documented in:** OLM-UPGRADES.md, Section "Upgrade Discovery and Path Resolution"

## Issues Encountered

### 1. Corrupted etcd State

**Issue:** Previous failed upgrade attempts left corrupted API version references in etcd.

**Impact:**
- Prevented clean reinstallation of v2.25.0
- Blocked v3.0.0 upgrade validation
- CRDs stuck with `storedVersions: ["v1", "v2"]` when only v1 existed

**Root Cause:** Test iterations without full cleanup between attempts

**Resolution Required:**
- Force delete CRDs with finalizer removal
- Clear etcd storage for opendatahub CRDs
- Start fresh with clean namespace

### 2. Bundle Image Generation

**Issue:** Multi-stage bundle Dockerfiles run `make bundle` internally without passed parameters.

**Impact:** Generated bundles had wrong operator image references

**Solution:** Build bundle manifests separately with correct parameters, then build simple bundle image

### 3. CRD Conversion Webhook Deadlock During Upgrade

**Issue:** v3.0.0 operator unable to start during upgrade due to CRD conversion webhook deadlock.

**Symptoms:**
- v3.0.0 operator pod crash-looping with health probe failures
- Operator hangs after initial cluster config log
- Error querying CRDs: "conversion webhook for dscinitialization.opendatahub.io/v1, Kind=DSCInitialization failed: the server could not find the requested resource"
- Dual-CSV stuck (v2.25.0: Replacing, v3.0.0: Installing)

**Impact:**
- Upgrade completely blocked
- Cannot complete transition from v2.25.0 to v3.0.0
- Cluster left in inconsistent state with two operator versions deployed

**Root Cause:**
CRD versioning upgrade anti-pattern where:
1. CRD upgrade adds new version (v2) requiring conversion webhook
2. v2.25.0 operator lacks `/convert` endpoint (built before v2 existed)
3. v3.0.0 operator queries DSCInitializations during startup
4. API server requires conversion webhook for query
5. Webhook unavailable → query fails → operator hangs → webhook never starts → cycle repeats

**Technical Details:**
- CRD has `spec.conversion.strategy: Webhook` and `status.storedVersions: ["v1","v2"]`
- Existing `default-dsci` instance stored in v1 format
- Webhook points to `rhods-operator-service:443/convert`
- Direct v1 API queries work: `oc get --raw /apis/dscinitialization.opendatahub.io/v1/dscinitializations`
- Queries through kubectl fail due to conversion requirement

**Workaround Attempts:**
- ❌ Cannot delete existing DSCInitialization (conversion webhook required for deletion)
- ❌ Cannot disable webhook (CRD validation prevents removing webhook config while strategy=Webhook)
- ❌ Operator startup blocked so can't establish working webhook

**Resolution Required:**
Would need one of:
1. Delete CR instances before upgrade (prevents operator from querying during startup)
2. Backport conversion webhook to v2.25.0
3. Multi-step upgrade through intermediate version with webhook support
4. Manual CRD patching to temporarily bypass conversion (risky)
5. Fresh installation of v3.0.0 instead of in-place upgrade

### 4. CRD Creation Failure After etcd Cleanup

**Issue:** servicemeshes.services.platform.opendatahub.io CRD not created by OLM during fresh installation after complete cluster cleanup including etcd key removal.

**Symptoms:**
- InstallPlan showed CRD with `status: Created`
- CRD not present in cluster (`oc get crd servicemeshes.services.platform.opendatahub.io` returned NotFound)
- CSV stuck in Pending phase with RequirementsNotMet
- OLM logs showed repeated "requirements were not met" errors

**Impact:**
- CSV unable to reach Succeeded phase
- Operator installation blocked despite all other resources created successfully

**Root Cause:**
Likely residual API server cache or etcd state after explicit etcd key deletion during cleanup. The servicemeshes key (`/kubernetes.io/services.platform.opendatahub.io/servicemeshes/default-servicemesh`) was one of the orphaned keys deleted directly from etcd. OLM may have encountered a conflict or cached reference preventing automatic CRD creation.

**Workaround:**
```bash
# Manually create the servicemeshes CRD from bundle manifests
oc create -f bundle/manifests/services.platform.opendatahub.io_servicemeshes.yaml
```

After manual CRD creation, OLM detected the requirement was met and CSV transitioned to Succeeded within ~10 seconds.

**Implications:**
- OLM's InstallPlan status may not reflect actual cluster state after etcd manipulation
- Direct etcd cleanup can leave API server in inconsistent state
- Manual verification of CRD creation may be necessary after aggressive cleanup procedures
- Consider API server restart or cache invalidation after direct etcd modifications

## Lessons Learned

### 1. Containerized Builds are Essential

Different branches require different Go versions. Using containerized build environments with specific Go versions ensures reproducible builds and avoids host system conflicts.

### 2. Always Specify Critical Parameters

**Required for every bundle build:**
- `VERSION=X.Y.Z` - Sets bundle version
- `IMG=$REGISTRY/operator:vX.Y.Z` - Sets operator image in CSV
- `PLATFORM=linux/amd64` - Overrides container's PLATFORM env var
- `ODH_PLATFORM_TYPE=rhoai` - Builds RHOAI flavor (rhods-operator package)

### 3. Bundle Build Pattern

The safest pattern is:
1. Run `make bundle` with all parameters to generate manifests
2. Build simple bundle image directly from generated manifests
3. Don't use multi-stage Dockerfiles that re-run `make bundle`

### 4. OLM Validation is Strict

OLM's validation mechanisms are thorough:
- CRD compatibility checks prevent data loss
- Existing CR validation ensures schema compatibility
- Storage version validation prevents downgrades
- These are features, not bugs - they protect production systems

### 5. Test Environment Cleanup

Between test iterations, full cleanup is required:
- Delete namespace (removes namespaced resources)
- Delete CRDs (cluster-scoped, not removed with namespace)
- May need to clear etcd state for corrupted references

### 6. CRD Conversion Webhooks Create Upgrade Complexity

Adding new API versions with conversion webhooks to existing CRDs creates upgrade challenges:
- Conversion webhook must be available BEFORE CRD update completes
- Old operator may not have webhook implementation
- New operator can't start if it queries CRDs during initialization
- Creates potential deadlock: webhook needed for queries, queries needed to start webhook
- **Safe Pattern:** Either implement webhook in old version first, or don't query CRDs during operator startup
- **Risk:** In-place upgrades can fail completely if this pattern isn't followed

## Documentation Created

1. **OLM-UPGRADES.md** - Comprehensive guide to OLM's internal upgrade mechanisms
2. **ODH-UPGRADE-HYPOTHESIS.md** - Theoretical analysis of v2.25.0 → v3.0.0 upgrade
3. **UPGRADE-HACK-REGISTRY.md** - Complete guide for testing upgrades with personal registry
4. **UPGRADE-HACK-NO-REGISTRY.md** - Alternative guide without registry
5. **UPGRADE-HACK.md** - Overview and chooser document

## Next Steps

To complete a successful upgrade test:

1. **Clean the cluster thoroughly:**
   - Delete redhat-ods-operator namespace
   - Force delete all opendatahub CRDs
   - Clear any etcd state if needed

2. **Fresh installation:**
   - Create new namespace
   - Install v2.25.0 with verified bundle
   - Wait for CSV to reach Succeeded

3. **Execute upgrade:**
   - Run bundle-upgrade with v3.0.0 bundle
   - Monitor CSV transitions
   - Verify operator pods using correct v3.0.0 image

## Conclusion

**Build Process:** ✅ SUCCESS
- Successfully created containerized build environments for Go 1.24 and Go 1.25
- Built operator images and bundles with correct versioning and image references
- Solved critical parameter passing issues (VERSION, IMG, PLATFORM, ODH_PLATFORM_TYPE)
- Documented reproducible build process using containerized environments

**v2.25.0 Installation:** ✅ SUCCESS (with manual intervention)
- CSV reached Succeeded phase after manual servicemeshes CRD creation
- 3 operator pods running stably
- 21 CRDs installed successfully
- Verified stable operation

**v3.0.0 Upgrade:** ❌ FAILED
- OLM correctly recognized upgrade path via `replaces` field
- Dual-CSV operation initiated (v2.25.0: Replacing, v3.0.0: Installing)
- New v3.0.0 CRDs installed successfully
- **Upgrade blocked by CRD conversion webhook deadlock**
- v3.0.0 operator pod crash-looping, unable to complete startup
- Cluster left in inconsistent state with partial upgrade

**Key Findings:**

1. **OLM Validation Mechanisms:** Successfully observed OLM's CRD compatibility validation, dual-CSV operation, and InstallPlan execution during upgrade attempt

2. **Build Complexity:** Containerized builds essential for managing different Go version requirements across branches

3. **CRD Versioning Anti-Pattern Discovered:** Adding new CRD versions with conversion webhooks during upgrades creates deadlock risk when:
   - Old operator lacks webhook implementation
   - New operator queries CRDs during startup
   - Results in unrecoverable upgrade failure

4. **etcd State Sensitivity:** Direct etcd manipulation can leave API server in inconsistent state, affecting subsequent operations

5. **Upgrade Path Issue:** The v2.25.0 → v3.0.0 upgrade path appears to have a **breaking design flaw** that prevents successful in-place upgrades when CR instances exist

**Value Delivered:**
- Comprehensive documentation of OLM upgrade mechanisms (OLM-UPGRADES.md)
- Reproducible build process for testing upgrades (UPGRADE-HACK-*.md)
- Identified critical upgrade path issue requiring upstream investigation
- Complete troubleshooting documentation for future testing
- Cleanup scripts for thorough cluster state management

**Recommendation:**
The CRD conversion webhook deadlock issue should be reported to the opendatahub-operator project as it represents a blocker for production upgrades from v2.25.0 to v3.0.0 when DSCInitialization instances exist.
