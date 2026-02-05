# RHOAI Operator Bundle Structure

## Overview

This directory contains extracted FBC (File-Based Catalog) and bundle information for the RHOAI operator.

## Directory Structure

```
rhoai-fbc/
├── catalog.yaml              # Full FBC catalog (80 YAML documents)
├── ANALYSIS.txt             # Analysis of upgrade paths
├── csv-3.3.0.yaml          # ClusterServiceVersion for v3.3.0
├── csv-2.25.2.yaml         # ClusterServiceVersion for v2.25.2 (if available)
├── crds-all.yaml           # All CRDs from cluster
├── bundle-3.3.0-entry.yaml # Bundle entry from FBC
├── bundles/
│   ├── 3.3.0/
│   │   ├── manifests/      # Bundle manifests (CSV + CRDs)
│   │   └── metadata/       # Bundle metadata (annotations.yaml)
│   └── 2.25.2/
│       ├── manifests/
│       └── metadata/
└── BUNDLE_STRUCTURE.md     # This file
```

## Bundle Content (v3.3.0)

### Manifests Directory
Contains 38 files:
- **1 ClusterServiceVersion (CSV)**: `rhods-operator.clusterserviceversion.yaml`
- **37 CustomResourceDefinitions (CRDs)**: All CRDs for opendatahub.io and platform.opendatahub.io groups

### Metadata Directory
- `annotations.yaml`: Bundle metadata with channel and package information

## Bundle Images

From the FBC catalog:

**Version 3.3.0:**
```
registry.redhat.io/rhoai/odh-operator-bundle@sha256:6a04d95b8069f3a9e0f3868e565c1b3beac16ab3fce3263cdba1c2bb3340c2f7
```

**Version 2.25.2:**
```
(See catalog.yaml for reference)
```

**Note:** Bundle images are not directly pullable from the registry. Bundle content was extracted from the running cluster instead.

## Building an FBC from Source

### Prerequisites
1. **opm CLI** - Operator Package Manager
2. **podman or docker** - Container build tool
3. **Operator bundle** - Built from operator source code

### Method 1: From Existing Bundle (Recommended)

If you have bundle images available:

```bash
# 1. Initialize FBC
opm init rhods-operator --default-channel=stable --output yaml > catalog.yaml

# 2. Render bundle to FBC format
opm render registry.redhat.io/rhoai/odh-operator-bundle:v3.3.0 --output yaml >> catalog.yaml

# 3. Add channel entry
cat >> catalog.yaml << EOF
---
schema: olm.channel
package: rhods-operator
name: stable
entries:
  - name: rhods-operator.3.3.0
EOF

# 4. Validate FBC
opm validate catalog

# 5. Build catalog image
podman build -f catalog.Dockerfile -t quay.io/yourorg/rhoai-catalog:latest .
```

### Method 2: From Operator Source Code

If building from the opendatahub-operator repository:

```bash
# 1. Build operator bundle
cd opendatahub-operator
make bundle IMG=quay.io/yourorg/odh-operator:v3.3.0

# 2. Build and push bundle image
make bundle-build bundle-push BUNDLE_IMG=quay.io/yourorg/odh-operator-bundle:v3.3.0

# 3. Create FBC from bundle
opm init rhods-operator --default-channel=stable --output yaml > custom-catalog/catalog.yaml
opm render quay.io/yourorg/odh-operator-bundle:v3.3.0 --output yaml >> custom-catalog/catalog.yaml

# 4. Add channel
cat >> custom-catalog/catalog.yaml << EOF
---
schema: olm.channel
package: rhods-operator
name: stable
entries:
  - name: rhods-operator.3.3.0
EOF

# 5. Build catalog image
cd custom-catalog
cat > catalog.Dockerfile << EOF
FROM registry.redhat.io/openshift4/ose-operator-registry:v4.20
ADD catalog /configs
EOF
podman build -f catalog.Dockerfile -t quay.io/yourorg/rhoai-catalog:latest .
podman push quay.io/yourorg/rhoai-catalog:latest
```

### Method 3: Manual Assembly (From This Directory)

Using the extracted bundle content in `bundles/3.3.0/`:

```bash
# 1. Create minimal FBC
cat > custom-catalog.yaml << EOF
---
defaultChannel: stable
name: rhods-operator
schema: olm.package
---
schema: olm.channel
package: rhods-operator
name: stable
entries:
  - name: rhods-operator.3.3.0
---
schema: olm.bundle
name: rhods-operator.3.3.0
package: rhods-operator
image: quay.io/yourorg/odh-operator-bundle:v3.3.0
properties:
  - type: olm.package
    value:
      packageName: rhods-operator
      version: 3.3.0
EOF

# 2. Build custom bundle image from manifests
cd bundles/3.3.0
cat > bundle.Dockerfile << EOF
FROM scratch
COPY manifests /manifests/
COPY metadata /metadata/
EOF
podman build -f bundle.Dockerfile -t quay.io/yourorg/odh-operator-bundle:v3.3.0 .
podman push quay.io/yourorg/odh-operator-bundle:v3.3.0

# 3. Build catalog image
mkdir -p catalog-build/configs/rhods-operator
cp custom-catalog.yaml catalog-build/configs/rhods-operator/catalog.yaml
cd catalog-build
cat > catalog.Dockerfile << EOF
FROM registry.redhat.io/openshift4/ose-operator-registry:v4.20
ADD configs /configs
EOF
podman build -f catalog.Dockerfile -t quay.io/yourorg/rhoai-catalog:latest .
podman push quay.io/yourorg/rhoai-catalog:latest
```

## Creating a CatalogSource

Once you have a catalog image:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: custom-rhoai-catalog
  namespace: openshift-marketplace
spec:
  displayName: Custom RHOAI Catalog
  sourceType: grpc
  image: quay.io/yourorg/rhoai-catalog:latest
  publisher: Custom
  updateStrategy:
    registryPoll:
      interval: 10m
```

## Upgrade Paths

To create upgrade paths, use `replaces` and `skipRange` in channel entries:

```yaml
schema: olm.channel
package: rhods-operator
name: stable
entries:
  - name: rhods-operator.2.25.2
  - name: rhods-operator.3.3.0
    replaces: rhods-operator.2.25.2
    skipRange: '>=2.25.0 <3.3.0'
```

This allows upgrades from any 2.25.x version directly to 3.3.0.

## Useful Commands

**Inspect FBC:**
```bash
yq eval 'select(.schema == "olm.package")' catalog.yaml
yq eval 'select(.schema == "olm.channel")' catalog.yaml
yq eval 'select(.schema == "olm.bundle" and .name == "rhods-operator.3.3.0")' catalog.yaml
```

**Validate bundle:**
```bash
operator-sdk bundle validate bundles/3.3.0/
```

**Extract bundle from image:**
```bash
oc image extract <bundle-image> --path /manifests:./manifests --confirm
oc image extract <bundle-image> --path /metadata:./metadata --confirm
```

## References

- [OLM File-Based Catalog Documentation](https://olm.operatorframework.io/docs/reference/file-based-catalogs/)
- [OPM CLI Reference](https://github.com/operator-framework/operator-registry/blob/master/docs/design/opm-tooling.md)
- [Operator SDK Bundle Guide](https://sdk.operatorframework.io/docs/olm-integration/tutorial-bundle/)
