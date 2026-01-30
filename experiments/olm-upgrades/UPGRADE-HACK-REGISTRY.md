# Simulating OLM Upgrades With a Personal Registry

This document describes how to simulate an OLM upgrade using a personal container registry (e.g., `registry.tannerjc.net`, `quay.io`, etc.).

## Why This Approach

✅ **Simpler workflow**: Build, push, install - standard container workflow
✅ **Production-like**: Uses real registry, real bundle images
✅ **Reusable**: Bundle images persist for later use
✅ **Debuggable**: Can inspect bundle images, pull them to other clusters
✅ **Catalog-ready**: Easy to create multi-version catalogs
✅ **Shareable**: Others can pull your bundles for testing

This is the recommended approach if you have registry access.

## Prerequisites

- Container registry with push access (e.g., `registry.tannerjc.net`)
- `podman` or `docker` configured and logged in to your registry
- OLM installed in the cluster
- `operator-sdk` CLI installed

## Current State of the Repositories

**stable-2.x** (`bundle/manifests/rhods-operator.clusterserviceversion.yaml`):
- CSV name: `rhods-operator.v2.25.0`
- Version: `2.25.0`
- No `replaces` field
- skipRange: `>=1.0.0 <2.0.0`

**main** (`config/rhoai/manifests/bases/rhods-operator.clusterserviceversion.yaml`):
- CSV name: `rhods-operator.v2.0.0` (base template - gets version from Makefile)
- Version: `3.0.0` (from VERSION variable in Makefile)
- No `replaces` field
- skipRange: `>=1.0.0 <2.0.0`

## Quick Start

If you just want the commands:

```bash
# Set your registry
export REGISTRY=registry.tannerjc.net/opendatahub

# Add replaces field to main branch CSV (see Step 1 below)

# Build and push v2.25.0 (IMPORTANT: specify VERSION and IMG)
cd src/opendatahub-io/opendatahub-operator.stable-2.x
make image IMG=$REGISTRY/rhods-operator:v2.25.0
make bundle VERSION=2.25.0 IMG=$REGISTRY/rhods-operator:v2.25.0 BUNDLE_IMG=$REGISTRY/rhods-operator-bundle:v2.25.0
make bundle-build bundle-push BUNDLE_IMG=$REGISTRY/rhods-operator-bundle:v2.25.0
operator-sdk run bundle $REGISTRY/rhods-operator-bundle:v2.25.0 -n redhat-ods-operator

# Build and push v3.0.0 (IMPORTANT: specify VERSION and IMG)
cd ../opendatahub-operator.main
make image IMG=$REGISTRY/rhods-operator:v3.0.0
make bundle VERSION=3.0.0 IMG=$REGISTRY/rhods-operator:v3.0.0 BUNDLE_IMG=$REGISTRY/rhods-operator-bundle:v3.0.0
make bundle-build bundle-push BUNDLE_IMG=$REGISTRY/rhods-operator-bundle:v3.0.0
operator-sdk run bundle-upgrade $REGISTRY/rhods-operator-bundle:v3.0.0 -n redhat-ods-operator

# Watch the upgrade
oc get csv -n redhat-ods-operator -w
```

**Note**: If you encounter Go version compatibility errors during `make bundle-build`, see the "Troubleshooting: Go Version Compatibility Issue" section in Step 3 below for a containerized build workaround.

See below for detailed step-by-step instructions.

---

## Detailed Step-by-Step Instructions

### Step 1: Edit the CSV to Add `replaces` Field

For OLM to recognize this as an upgrade in the replacement chain, the v3.0.0 CSV must have a `replaces` field pointing to v2.25.0.

```bash
cd src/opendatahub-io/opendatahub-operator.main

# Edit the RHOAI CSV base file
vi config/rhoai/manifests/bases/rhods-operator.clusterserviceversion.yaml
```

Add the `replaces` field in the `spec` section (around line 97):

```yaml
spec:
  apiservicedefinitions: {}
  replaces: rhods-operator.v2.25.0  # <-- ADD THIS LINE
  customresourcedefinitions:
    owned:
    - description: HardwareProfile is the Schema for the hardwareprofiles API.
```

Save and exit.

### Step 2: Create Build Container Images

**Why use build containers?**
- Ensures Go version consistency (stable-2.x needs Go 1.24, main needs Go 1.25)
- Avoids conflicts with your host system's Go version
- Provides a reproducible build environment
- Handles podman-in-podman for building and pushing bundle images

Create both Go 1.24 and Go 1.25 build containers:

```bash
# Create Dockerfile for Go 1.24 (for stable-2.x)
cat > /tmp/build-container.Dockerfile << 'EOF'
FROM registry.access.redhat.com/ubi9/go-toolset:1.24

USER root

# Install podman and build tools
RUN dnf install -y podman make git && dnf clean all

# Configure podman
RUN mkdir -p /home/default/.config/containers && \
    echo 'unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]' > /etc/containers/registries.conf

WORKDIR /workspace
USER default
EOF

# Build the Go 1.24 container
podman build --security-opt label=disable -t olm-build-env:go1.24 -f /tmp/build-container.Dockerfile

# Create Dockerfile for Go 1.25 (for main branch)
cat > /tmp/build-container-go125.Dockerfile << 'EOF'
FROM registry.access.redhat.com/ubi9/go-toolset:1.25

USER root

# Install podman and build tools
RUN dnf install -y podman make git && dnf clean all

# Configure podman to skip signature verification for nested builds
RUN cat > /etc/containers/policy.json << 'POLICY'
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ],
    "transports": {
        "docker-daemon": {
            "": [
                {
                    "type": "insecureAcceptAnything"
                }
            ]
        }
    }
}
POLICY

# Configure podman registries
RUN mkdir -p /home/default/.config/containers && \
    echo 'unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]' > /etc/containers/registries.conf

WORKDIR /workspace
USER default
EOF

# Build the Go 1.25 container
podman build --security-opt label=disable -t olm-build-env:go1.25 -f /tmp/build-container-go125.Dockerfile
```

Now set your registry in environment variables:

```bash
export REGISTRY=registry.tannerjc.net/opendatahub
```

### Step 3: Build and Push v2.25.0 Operator and Bundle

**CRITICAL Parameters Required**:
- `VERSION=2.25.0`: Sets the bundle version (otherwise defaults to Go version like 1.24.6)
- `IMG=$REGISTRY/rhods-operator:v2.25.0`: Specifies operator image in CSV (otherwise defaults to quay.io)
- `PLATFORM=linux/amd64`: Overrides the container's `PLATFORM=el9` environment variable
- `ODH_PLATFORM_TYPE=rhoai`: Builds RHOAI bundle (bundle.Dockerfile) instead of ODH bundle

Navigate to the stable-2.x directory:

```bash
cd src/opendatahub-io/opendatahub-operator.stable-2.x
```

**Build using the Go 1.24 container (recommended):**

```bash
# Build and push operator image
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  olm-build-env:go1.24 \
  bash -c "make image-build IMG=$REGISTRY/rhods-operator:v2.25.0 PLATFORM=linux/amd64 && \
           make image-push IMG=$REGISTRY/rhods-operator:v2.25.0"

# Build and push bundle
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  olm-build-env:go1.24 \
  bash -c "make bundle VERSION=2.25.0 IMG=$REGISTRY/rhods-operator:v2.25.0 BUNDLE_IMG=$REGISTRY/rhods-operator-bundle:v2.25.0 PLATFORM=linux/amd64 ODH_PLATFORM_TYPE=rhoai && \
           podman build --no-cache -f Dockerfiles/bundle.Dockerfile -t $REGISTRY/rhods-operator-bundle:v2.25.0 . && \
           podman push $REGISTRY/rhods-operator-bundle:v2.25.0"
```

**What gets built:**
- Operator image: `registry.tannerjc.net/opendatahub/rhods-operator:v2.25.0`
- Bundle image: `registry.tannerjc.net/opendatahub/rhods-operator-bundle:v2.25.0`

**Verify the bundle before installing:**

```bash
# Check version and image in the generated bundle
grep -E "^  version:|^\s+image: registry" bundle/manifests/rhods-operator.clusterserviceversion.yaml

# Should show:
#   image: registry.tannerjc.net/opendatahub/rhods-operator:v2.25.0
#   version: 2.25.0
```


### Step 4: Install v2.25.0 Using `operator-sdk`

```bash
operator-sdk run bundle $REGISTRY/rhods-operator-bundle:v2.25.0 \
  -n redhat-ods-operator
```

**What this does:**
1. Creates a temporary CatalogSource pointing to your bundle image
2. Creates a Subscription for the operator
3. OLM creates an InstallPlan with all the upgrade steps
4. OLM installs the operator following the full process:
   - Installs CRDs
   - Creates RBAC resources
   - Deploys the operator pod

**Watch the installation:**

```bash
# Watch CSV status
oc get csv -n redhat-ods-operator -w

# In another terminal, watch pods
oc get pods -n redhat-ods-operator -w
```

Wait for the CSV to reach `Succeeded` phase.

### Step 5: Build and Push v3.0.0 Operator and Bundle

**Note**: The main branch defaults to VERSION=3.3.0. We'll use 3.0.0 for this upgrade demo, but adjust as needed.

**CRITICAL**:
- You must specify `VERSION=3.0.0`, `IMG=$REGISTRY/rhods-operator:v3.0.0`, `PLATFORM=linux/amd64`, and `ODH_PLATFORM_TYPE=rhoai` when building
- Build the **RHOAI** bundle (not ODH bundle) to match the v2.25.0 installation (package name: rhods-operator)
- Main branch requires Go 1.25, so use the containerized build environment

```bash
cd ../opendatahub-operator.main
```

#### Build operator image and RHOAI bundle using containerized environment:

```bash
# Step 5a: Build and push v3.0.0 operator image
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  olm-build-env:go1.25 \
  bash -c "make image-build IMG=$REGISTRY/rhods-operator:v3.0.0 PLATFORM=linux/amd64 && \
           make image-push IMG=$REGISTRY/rhods-operator:v3.0.0"

# Step 5b: Build and push v3.0.0 RHOAI bundle (includes replaces field from Step 1)
podman run --rm --user root \
  -v $(pwd):/workspace:Z \
  --security-opt label=disable \
  --privileged \
  olm-build-env:go1.25 \
  bash -c "export REGISTRY=registry.tannerjc.net/opendatahub && \
           make bundle VERSION=3.0.0 IMG=\$REGISTRY/rhods-operator:v3.0.0 BUNDLE_IMG=\$REGISTRY/rhods-operator-bundle:v3.0.0 PLATFORM=linux/amd64 ODH_PLATFORM_TYPE=rhoai && \
           podman build --no-cache -f Dockerfiles/rhoai-bundle.Dockerfile -t \$REGISTRY/rhods-operator-bundle:v3.0.0 . && \
           podman push \$REGISTRY/rhods-operator-bundle:v3.0.0"
```

**What gets built:**
- Operator image: `registry.tannerjc.net/opendatahub/rhods-operator:v3.0.0`
- RHOAI Bundle image: `registry.tannerjc.net/opendatahub/rhods-operator-bundle:v3.0.0` (with `replaces: rhods-operator.v2.25.0`)

**Key parameters explained:**
- `VERSION=3.0.0`: Sets the bundle version
- `IMG=$REGISTRY/rhods-operator:v3.0.0`: Specifies the operator image to reference in the CSV
- `PLATFORM=linux/amd64`: Overrides the container's `PLATFORM=el9` environment variable
- `ODH_PLATFORM_TYPE=rhoai`: Builds the RHOAI-flavored bundle (rhods-operator) instead of ODH bundle (opendatahub-operator)
- `Dockerfiles/rhoai-bundle.Dockerfile`: Use the RHOAI bundle Dockerfile, not the ODH one

**Verify the bundle before upgrading:**

```bash
# Check the CSV in the workspace
grep -E "^  version:|replaces:|^\s+image: registry" rhoai-bundle/manifests/rhods-operator.clusterserviceversion.yaml

# Should show:
#   image: registry.tannerjc.net/opendatahub/rhods-operator:v3.0.0
#   replaces: rhods-operator.v2.25.0
#   version: 3.0.0
```

### Step 6: Upgrade to v3.0.0

```bash
operator-sdk run bundle-upgrade $REGISTRY/rhods-operator-bundle:v3.0.0 \
  -n redhat-ods-operator
```

**What this does:**
1. Updates the CatalogSource with the new bundle image
2. OLM detects the upgrade via the `replaces: rhods-operator.v2.25.0` field
3. OLM performs the full upgrade process described in ODH-UPGRADE-HYPOTHESIS.md:
   - Pre-upgrade validation (CRD storage versions, CR validation)
   - Creates InstallPlan with all upgrade steps
   - Dual-CSV operation (both v2.25.0 and v3.0.0 run briefly)
   - CRD updates (5 new CRDs, 3 with version additions)
   - RBAC cleanup (removes 9 old roles)
   - Deployment update
   - CSV transition (Replacing → Installing → Succeeded)

**Watch the upgrade in real-time:**

```bash
# Watch CSV transitions (you'll see BOTH CSVs during transition)
oc get csv -n redhat-ods-operator -w

# Expected output:
# NAME                      DISPLAY                 VERSION   REPLACES                  PHASE
# rhods-operator.v2.25.0    Red Hat OpenShift AI    2.25.0                              Replacing
# rhods-operator.v3.0.0     Red Hat OpenShift AI    3.0.0     rhods-operator.v2.25.0    Installing
# ...
# rhods-operator.v3.0.0     Red Hat OpenShift AI    3.0.0     rhods-operator.v2.25.0    Succeeded
```

## Verification

Check all the OLM resources to verify the upgrade:

```bash
# Check final CSV status
oc get csv -n redhat-ods-operator

# Check subscription status
oc get subscription -n redhat-ods-operator -o yaml

# View install plans (you'll see plans for both install and upgrade)
oc get installplan -n redhat-ods-operator

# See the catalog source created by operator-sdk
oc get catalogsource -n redhat-ods-operator

# Check operator pod (new v3.0.0 pod should be running)
oc get pods -n redhat-ods-operator

# Verify new CRDs were installed
oc get crds | grep opendatahub

# Check for new CRDs specific to v3.0.0
oc get crd gatewayconfigs.services.platform.opendatahub.io
oc get crd mlflowoperators.components.platform.opendatahub.io
oc get crd modelsasservices.components.platform.opendatahub.io
oc get crd sparkoperators.components.platform.opendatahub.io
oc get crd trainers.components.platform.opendatahub.io

# Check for multi-version CRDs
oc get crd datascienceclusters.datasciencecluster.opendatahub.io -o jsonpath='{.spec.versions[*].name}'
# Should show: v1 v2

# Verify subscription is tracking the upgrade
oc get subscription -n redhat-ods-operator -o jsonpath='{.items[0].status}' | jq
```

Expected subscription status:
```json
{
  "installPlanRef": {
    "name": "install-xxxxx"
  },
  "installedCSV": "rhods-operator.v3.0.0",
  "state": "AtLatestKnown"
}
```

## What You'll Observe During Upgrade

All the OLM upgrade mechanisms described in OLM-UPGRADES.md:

1. ✅ **CRD Storage Version Validation**: OLM validates existing CRDs before upgrade
2. ✅ **Existing CR Validation**: All existing Custom Resources validated against new schemas
3. ✅ **Dual-CSV Operation**: Both v2.25.0 and v3.0.0 CSVs running simultaneously during transition
4. ✅ **Atomic InstallPlan**: All resources created together via InstallPlan
5. ✅ **Dependency Resolution**: OLM ensures all required APIs available
6. ✅ **RBAC Updates**: Old roles removed, new roles created
7. ✅ **Webhook Preservation**: Admission control continues during upgrade
8. ✅ **Owner Reference Transfer**: Resources gradually transferred from old to new CSV

See **ODH-UPGRADE-HYPOTHESIS.md** for detailed breakdown of what changes during the v2.25.0 → v3.0.0 upgrade.

## Cleanup

To remove the operator and start over:

```bash
# Remove the operator bundle (cleanest method)
operator-sdk cleanup rhods-operator -n redhat-ods-operator

# Or manually delete resources
oc delete csv rhods-operator.v3.0.0 -n redhat-ods-operator
oc delete subscription -l operators.coreos.com/rhods-operator.redhat-ods-operator -n redhat-ods-operator
oc delete catalogsource -l operators.coreos.com/rhods-operator.redhat-ods-operator -n redhat-ods-operator

# CRDs are NOT automatically deleted by OLM
# Delete them manually if needed (WARNING: deletes all CRs too!)
oc get crds | grep opendatahub | awk '{print $1}' | xargs oc delete crd

# Or delete specific CRDs
oc delete crd datascienceclusters.datasciencecluster.opendatahub.io
oc delete crd dscinitializations.dscinitialization.opendatahub.io
# ... etc
```

## Advanced: Create a Full Catalog (Optional)

If you want to go even further and create a real catalog image with multiple versions for a more production-like setup:

### Step 1: Build Catalog Image

```bash
cd src/opendatahub-io/opendatahub-operator.main

# Create a catalog with both bundles
make catalog-build \
  BUNDLE_IMGS=$REGISTRY/rhods-operator-bundle:v2.25.0,$REGISTRY/rhods-operator-bundle:v3.0.0 \
  CATALOG_IMG=$REGISTRY/rhods-operator-catalog:latest

# Push catalog
make catalog-push CATALOG_IMG=$REGISTRY/rhods-operator-catalog:latest
```

### Step 2: Create a CatalogSource

Create `catalogsource.yaml`:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhods-catalog
  namespace: redhat-ods-operator
spec:
  sourceType: grpc
  image: registry.tannerjc.net/opendatahub/rhods-operator-catalog:latest
  displayName: RHODS Development Catalog
  publisher: Local Development
  updateStrategy:
    registryPoll:
      interval: 10m
```

Apply it:

```bash
oc create namespace redhat-ods-operator
oc apply -f catalogsource.yaml
```

### Step 3: Create a Subscription

Create `subscription.yaml`:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: stable
  name: rhods-operator
  source: rhods-catalog
  sourceNamespace: redhat-ods-operator
  installPlanApproval: Automatic
  startingCSV: rhods-operator.v2.25.0
```

Apply it:

```bash
oc apply -f subscription.yaml
```

### Step 4: Watch Automatic Upgrade

With a real catalog, OLM will **automatically detect** and upgrade to v3.0.0:

```bash
# Watch OLM detect and upgrade automatically
oc get csv -n redhat-ods-operator -w

# You'll see:
# 1. v2.25.0 installs and reaches Succeeded
# 2. OLM detects v3.0.0 in catalog (with replaces: v2.25.0)
# 3. OLM automatically creates InstallPlan for upgrade
# 4. Upgrade happens automatically (unless installPlanApproval: Manual)
```

This gives you the **full production OLM experience** with automatic upgrades!

## Debugging Bundle Images

Since bundles are in your registry, you can inspect them:

```bash
# Pull and inspect bundle
podman pull $REGISTRY/rhods-operator-bundle:v3.0.0

# Run bundle validation
operator-sdk bundle validate $REGISTRY/rhods-operator-bundle:v3.0.0

# Extract bundle to filesystem
mkdir -p /tmp/bundle-v3.0.0
podman run --rm $REGISTRY/rhods-operator-bundle:v3.0.0 ls -R /manifests
podman create --name bundle-temp $REGISTRY/rhods-operator-bundle:v3.0.0
podman cp bundle-temp:/manifests /tmp/bundle-v3.0.0/
podman rm bundle-temp

# Inspect CSV
cat /tmp/bundle-v3.0.0/manifests/rhods-operator.clusterserviceversion.yaml | grep -A5 replaces
```

## Troubleshooting

### Bundle Image Won't Push

```bash
# Ensure you're logged into your registry
podman login registry.tannerjc.net

# Check credentials
podman login --get-login registry.tannerjc.net
```

### operator-sdk Can't Pull Bundle

```bash
# Ensure cluster can pull from your registry
# Create pull secret if needed
oc create secret docker-registry regcred \
  --docker-server=registry.tannerjc.net \
  --docker-username=<username> \
  --docker-password=<password> \
  -n redhat-ods-operator

# Link to service account
oc secrets link default regcred --for=pull -n redhat-ods-operator
```

### Upgrade Not Detected

Check that the `replaces` field is in the v3.0.0 CSV:

```bash
# Pull bundle and check CSV
podman run --rm $REGISTRY/rhods-operator-bundle:v3.0.0 \
  cat /manifests/rhods-operator.clusterserviceversion.yaml | grep replaces

# Should show:
# replaces: rhods-operator.v2.25.0
```

If missing, rebuild the bundle after adding the `replaces` field to the CSV base.

### Wrong CSV Version Installed

If `operator-sdk run bundle` installs the wrong version (e.g., shows v1.24.6 instead of v2.25.0):

**Cause**: The bundle was built without specifying the VERSION parameter.

**Solution**:
1. Clean up the failed installation:
   ```bash
   operator-sdk cleanup rhods-operator -n redhat-ods-operator
   ```

2. Rebuild the bundle with VERSION specified:
   ```bash
   make bundle VERSION=2.25.0 BUNDLE_IMG=$REGISTRY/rhods-operator-bundle:v2.25.0
   ```

3. Rebuild and push the bundle image:
   ```bash
   podman build -f Dockerfiles/bundle.Dockerfile -t $REGISTRY/rhods-operator-bundle:v2.25.0 .
   podman push $REGISTRY/rhods-operator-bundle:v2.25.0
   ```

4. Verify the version before installing:
   ```bash
   podman run --rm $REGISTRY/rhods-operator-bundle:v2.25.0 \
     cat /manifests/rhods-operator.clusterserviceversion.yaml | grep "^  version:"
   ```

### Operator Pods Crashing with "no matches for kind" Error

If operator pods are in CrashLoopBackOff with errors like:

```
unable to get deployed release version: no matches for kind "DSCInitialization" in version "dscinitialization.opendatahub.io/v2"
```

**Cause**: The bundle CSV is referencing the wrong operator image. If you didn't specify `IMG=` when building the bundle, it defaults to `quay.io/opendatahub/opendatahub-operator:latest` which may be from a different branch/version that expects different API versions than the CRDs in your bundle.

**Solution**:
1. Clean up the failed installation:
   ```bash
   operator-sdk cleanup rhods-operator -n redhat-ods-operator
   ```

2. Rebuild the bundle with **both VERSION and IMG** specified:
   ```bash
   cd src/opendatahub-io/opendatahub-operator.stable-2.x
   make bundle VERSION=2.25.0 IMG=$REGISTRY/rhods-operator:v2.25.0 BUNDLE_IMG=$REGISTRY/rhods-operator-bundle:v2.25.0
   ```

3. Verify the CSV references your image:
   ```bash
   grep "image:" bundle/manifests/rhods-operator.clusterserviceversion.yaml | grep -v base64
   # Should show: image: registry.tannerjc.net/opendatahub/rhods-operator:v2.25.0
   # NOT: image: quay.io/opendatahub/opendatahub-operator:latest
   ```

4. Rebuild and push the bundle image, then reinstall:
   ```bash
   make bundle-build bundle-push BUNDLE_IMG=$REGISTRY/rhods-operator-bundle:v2.25.0
   operator-sdk run bundle $REGISTRY/rhods-operator-bundle:v2.25.0 -n redhat-ods-operator
   ```

### Namespace Not Found

If `operator-sdk run bundle` fails with "namespaces \"redhat-ods-operator\" not found":

```bash
# Create the namespace first
oc create namespace redhat-ods-operator

# Then retry the installation
operator-sdk run bundle $REGISTRY/rhods-operator-bundle:v2.25.0 -n redhat-ods-operator
```

### Podman Signature Verification Errors in Nested Builds

If you encounter signature verification errors when building operator images inside the containerized environment:

```
Error: creating build container: unable to copy from source docker://registry.access.redhat.com/ubi9/go-toolset:1.25:
copying system image from manifest list: Source image rejected: None of the signatures were accepted
```

**Cause**: The inner podman (running inside the build container) is enforcing GPG signature verification for Red Hat registries, which can fail in nested podman scenarios.

**Solution**: Rebuild the Go 1.25 container with a relaxed signature policy (already included in the Dockerfile above):

```bash
# The updated Dockerfile includes this policy configuration:
RUN cat > /etc/containers/policy.json << 'POLICY'
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ],
    "transports": {
        "docker-daemon": {
            "": [
                {
                    "type": "insecureAcceptAnything"
                }
            ]
        }
    }
}
POLICY
```

This allows the nested podman to pull images without strict signature verification, resolving the build failure.

### PLATFORM Environment Variable Override

If you see errors about `--platform="el9"` being invalid:

```
Error: invalid platform syntax for --platform="el9"
```

**Cause**: The ubi9/go-toolset container sets `PLATFORM=el9` as an environment variable, which overrides the Makefile's default `PLATFORM ?= linux/amd64`.

**Solution**: Always specify `PLATFORM=linux/amd64` when running make commands inside the container:

```bash
make image-build IMG=$REGISTRY/rhods-operator:v3.0.0 PLATFORM=linux/amd64
```

## References

- **OLM-UPGRADES.md**: How OLM upgrades work internally
- **ODH-UPGRADE-HYPOTHESIS.md**: Specific upgrade behavior from v2.25.0 to v3.0.0
- [operator-sdk bundle documentation](https://sdk.operatorframework.io/docs/olm-integration/tutorial-bundle/)
- [OLM architecture documentation](https://olm.operatorframework.io/docs/)
