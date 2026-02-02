# OpenDataHub vs RHOAI Build Differences

This document outlines what needs to change to switch from building RHOAI bundles to OpenDataHub bundles.

## Key Differences

### 1. Operator Package Name

| Platform | Operator Package | CSV Name |
|----------|------------------|----------|
| **RHOAI** | `rhods-operator` | `rhods-operator.v2.25.0` |
| **ODH** | `opendatahub-operator` | `opendatahub-operator.v2.25.0` |

### 2. Make Variables

| Variable | RHOAI Value | ODH Value |
|----------|-------------|-----------|
| `ODH_PLATFORM_TYPE` | `rhoai` | `OpenDataHub` (default) |
| `OPERATOR_PACKAGE` | `rhods-operator` | `opendatahub-operator` |
| `BUNDLE_DIR` | `rhoai-bundle` | `odh-bundle` |
| `CONFIG_DIR` | `config/rhoai` | `config` |
| `DOCKERFILE_FILENAME` | `rhoai.Dockerfile` | `Dockerfile` |
| `BUNDLE_DOCKERFILE_FILENAME` | `rhoai-bundle.Dockerfile` | `bundle.Dockerfile` |
| `OPERATOR_NAMESPACE` | `redhat-ods-operator-system` | `opendatahub-operator-system` |
| `APPLICATIONS_NAMESPACE` | `redhat-ods-applications` | `opendatahub` |

### 3. Docker Images

**Current (RHOAI):**
```bash
OPERATOR_IMG="registry.tannerjc.net/opendatahub/rhods-operator:v2.25.0"
BUNDLE_IMG="registry.tannerjc.net/opendatahub/rhods-operator-bundle:v2.25.0"
```

**Proposed (ODH):**
```bash
OPERATOR_IMG="registry.tannerjc.net/opendatahub/opendatahub-operator:v2.25.0"
BUNDLE_IMG="registry.tannerjc.net/opendatahub/opendatahub-operator-bundle:v2.25.0"
```

### 4. Dockerfiles

**Main Branch:**
- **RHOAI**: Uses `Dockerfiles/rhoai.Dockerfile` and `Dockerfiles/rhoai-bundle.Dockerfile`
- **ODH**: Uses `Dockerfiles/Dockerfile` and `Dockerfiles/bundle.Dockerfile`

**Stable-2.x Branch:**
- **RHOAI**: Uses `Dockerfiles/bundle.Dockerfile` (contains RHOAI logic)
- **ODH**: Same file but behavior changes with `ODH_PLATFORM_TYPE=OpenDataHub`

### 5. Manifests Source

The `get_all_manifests.sh` script downloads component manifests:

**Current RHOAI references:**
```bash
["dashboard"]="red-hat-data-services:odh-dashboard:rhoai-2.25:manifests"
```

**ODH equivalent:**
```bash
["dashboard"]="opendatahub-io:odh-dashboard:stable-2.x:manifests"
```

This is automatically handled by the Makefile when `ODH_PLATFORM_TYPE=OpenDataHub`.

## Changes Required for Build Scripts

### For v2.25.0 (stable-2.x)

**File: `scripts/build-and-push-v2.25.0.sh`**

Change:
```bash
# FROM (RHOAI):
VERSION="2.25.0"
REGISTRY="registry.tannerjc.net/opendatahub"
OPERATOR_IMG="${REGISTRY}/rhods-operator:v${VERSION}"
BUNDLE_IMG="${REGISTRY}/rhods-operator-bundle:v${VERSION}"
...
make bundle VERSION=${VERSION} IMG=${OPERATOR_IMG} BUNDLE_IMG=${BUNDLE_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=rhoai
...
podman build --no-cache -f Dockerfiles/bundle.Dockerfile -t ${BUNDLE_IMG} .

# TO (ODH):
VERSION="2.25.0"
REGISTRY="registry.tannerjc.net/opendatahub"
OPERATOR_IMG="${REGISTRY}/opendatahub-operator:v${VERSION}"
BUNDLE_IMG="${REGISTRY}/opendatahub-operator-bundle:v${VERSION}"
...
make bundle VERSION=${VERSION} IMG=${OPERATOR_IMG} BUNDLE_IMG=${BUNDLE_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=OpenDataHub
...
podman build --no-cache -f Dockerfiles/bundle.Dockerfile -t ${BUNDLE_IMG} .
```

**Note**: In stable-2.x, `bundle.Dockerfile` is used for both, but the content changes based on `ODH_PLATFORM_TYPE`.

### For v3.0.0 (main)

**File: `scripts/build-and-push-v3.0.0.sh`**

Change:
```bash
# FROM (RHOAI):
VERSION="3.0.0"
REGISTRY="registry.tannerjc.net/opendatahub"
OPERATOR_IMG="${REGISTRY}/rhods-operator:v${VERSION}"
BUNDLE_IMG="${REGISTRY}/rhods-operator-bundle:v${VERSION}"
...
make image-build IMG=${OPERATOR_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=rhoai
...
make bundle VERSION=${VERSION} IMG=${OPERATOR_IMG} BUNDLE_IMG=${BUNDLE_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=rhoai
...
podman build --no-cache -f Dockerfiles/rhoai-bundle.Dockerfile -t ${BUNDLE_IMG} .

# TO (ODH):
VERSION="3.3.0"  # Note: Main branch uses 3.3.0 for ODH, not 3.0.0
REGISTRY="registry.tannerjc.net/opendatahub"
OPERATOR_IMG="${REGISTRY}/opendatahub-operator:v${VERSION}"
BUNDLE_IMG="${REGISTRY}/opendatahub-operator-bundle:v${VERSION}"
...
make image-build IMG=${OPERATOR_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=OpenDataHub
...
make bundle VERSION=${VERSION} IMG=${OPERATOR_IMG} BUNDLE_IMG=${BUNDLE_IMG} PLATFORM=${PLATFORM} ODH_PLATFORM_TYPE=OpenDataHub
...
podman build --no-cache -f Dockerfiles/bundle.Dockerfile -t ${BUNDLE_IMG} .
```

### For Install Script

**File: `scripts/install-v2.25.0.sh`**

Change:
```bash
# FROM (RHOAI):
BUNDLE_IMG="${REGISTRY}/rhods-operator-bundle:v2.25.0"
NAMESPACE="redhat-ods-operator"

# TO (ODH):
BUNDLE_IMG="${REGISTRY}/opendatahub-operator-bundle:v2.25.0"
NAMESPACE="opendatahub-operator-system"
```

### For Upgrade Script

**File: `scripts/upgrade-to-v3.0.0.sh`**

Change:
```bash
# FROM (RHOAI):
BUNDLE_IMG="${REGISTRY}/rhods-operator-bundle:v3.0.0"
NAMESPACE="redhat-ods-operator"
...
oc get csv rhods-operator.v2.25.0 -n ${NAMESPACE}

# TO (ODH):
BUNDLE_IMG="${REGISTRY}/opendatahub-operator-bundle:v3.3.0"
NAMESPACE="opendatahub-operator-system"
...
oc get csv opendatahub-operator.v2.25.0 -n ${NAMESPACE}
```

## Patch Changes Required

### stable-2.x CSV Patch

**Current**: Patches `bundle/manifests/rhods-operator.clusterserviceversion.yaml`

**ODH**: Would patch `odh-bundle/manifests/opendatahub-operator.clusterserviceversion.yaml`

The patch file location and content would need to reference the correct CSV name.

### main Upgrade Fixes Patch

**Current**: Adds `replaces: rhods-operator.v2.25.0`

**ODH**: Would add `replaces: opendatahub-operator.v2.25.0`

File path changes:
- **RHOAI**: `config/rhoai/manifests/bases/rhods-operator.clusterserviceversion.yaml`
- **ODH**: `config/manifests/bases/opendatahub-operator.clusterserviceversion.yaml`

## Cleanup Script Changes

**File: `scripts/cleanup-odh-complete.sh`**

Current script already handles ODH patterns correctly (searches for "opendatahub"). Main changes:

```bash
# FROM (RHOAI):
NAMESPACE="redhat-ods-operator"
CSV_NAME="rhods-operator"

# TO (ODH):
NAMESPACE="opendatahub-operator-system"
CSV_NAME="opendatahub-operator"
```

Namespaces to clean up:
- **RHOAI**: `redhat-ods-operator`, `redhat-ods-applications`, `redhat-ods-monitoring`
- **ODH**: `opendatahub-operator-system`, `opendatahub`, `opendatahub` (monitoring in same namespace)

## Dashboard Image Issue

The dashboard image tag problem is the same for both ODH and RHOAI:

**In dashboard manifests (`src/opendatahub-io/odh-dashboard.stable-2.x/manifests`):**
- `rhoai/onprem/params.env`: `odh-dashboard-image=quay.io/opendatahub/odh-dashboard:main`
- `odh/params.env`: `odh-dashboard-image=quay.io/opendatahub/odh-dashboard:main`

Both use `:main` tag which has the `cross-env` bug. Proper fix:
```bash
odh-dashboard-image=quay.io/opendatahub/odh-dashboard:stable-2.x
```

This would need to be patched in the dashboard repo manifests or overridden in the operator build.

## Recommended Approach

### Option 1: Dual Scripts (Current + ODH)

Keep current RHOAI scripts and create parallel ODH scripts:
- `build-and-push-odh-v2.25.0.sh`
- `build-and-push-odh-v3.3.0.sh`
- `install-odh-v2.25.0.sh`
- `upgrade-odh-to-v3.3.0.sh`

**Pros**: Can test both platforms, easy comparison
**Cons**: Duplicate code, more maintenance

### Option 2: Parameterized Scripts

Add a `PLATFORM` variable to each script:
```bash
PLATFORM="${PLATFORM:-rhoai}"  # Default to rhoai for backward compatibility

if [ "$PLATFORM" = "odh" ]; then
    OPERATOR_NAME="opendatahub-operator"
    OPERATOR_NAMESPACE="opendatahub-operator-system"
    # ... ODH-specific settings
else
    OPERATOR_NAME="rhods-operator"
    OPERATOR_NAMESPACE="redhat-ods-operator"
    # ... RHOAI-specific settings
fi
```

**Pros**: Single set of scripts, easier maintenance
**Cons**: More complex scripts

### Option 3: Complete Switch to ODH

Replace all RHOAI references with ODH.

**Pros**: Simplest, avoids RHOAI-specific issues like dashboard image tags
**Cons**: Loses RHOAI testing capability

## Summary

To switch from RHOAI to ODH:

1. **Change all `rhods-operator` → `opendatahub-operator`**
2. **Change all `ODH_PLATFORM_TYPE=rhoai` → `ODH_PLATFORM_TYPE=OpenDataHub`**
3. **Update image names** to use `opendatahub-operator` instead of `rhods-operator`
4. **Update namespaces** from `redhat-ods-*` to `opendatahub*`
5. **Change Dockerfiles** (main branch only): `rhoai-bundle.Dockerfile` → `bundle.Dockerfile`
6. **Update version for main branch**: `3.0.0` → `3.3.0`
7. **Update patches** to reference correct CSV names and paths
8. **Fix dashboard image tag** from `:main` → `:stable-2.x`

The core issue (dashboard `:main` image with `cross-env` bug) exists in both ODH and RHOAI manifests and needs to be fixed regardless of platform choice.
