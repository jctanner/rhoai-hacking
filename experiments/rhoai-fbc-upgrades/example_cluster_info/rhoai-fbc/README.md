# RHOAI FBC and Bundle Archive

## Quick Reference

This directory contains everything needed to understand and recreate the RHOAI operator's FBC (File-Based Catalog).

### Key Files

| File | Description | Size |
|------|-------------|------|
| `catalog.yaml` | Complete FBC with 80 YAML documents | 1.5 MB |
| `ANALYSIS.txt` | Upgrade path analysis | 1.1 KB |
| `BUNDLE_STRUCTURE.md` | How to build FBC from source | Documentation |
| `csv-3.3.0.yaml` | ClusterServiceVersion v3.3.0 | 151 KB |
| `csv-2.25.2.yaml` | ClusterServiceVersion v2.25.2 | 108 B |
| `crds-all.yaml` | All cluster CRDs | 28 MB |
| `bundles/3.3.0/` | Complete bundle for v3.3.0 | 1.1 MB |

## What's Included

### FBC Catalog (`catalog.yaml`)
- **1 Package**: rhods-operator
- **18 Channels**: stable, fast, alpha, eus-2.25, etc.
- **62 Bundles**: Versions from 1.20.1-8 through 3.3.0

### Bundle v3.3.0 (`bundles/3.3.0/`)
Complete operator bundle extracted from cluster:
- **1 CSV** (ClusterServiceVersion)
- **37 CRDs** (CustomResourceDefinitions)
- **Bundle metadata** (annotations.yaml)

All files ready to rebuild bundle and catalog images.

## Bundle Images

**v3.3.0:**
```
registry.redhat.io/rhoai/odh-operator-bundle@sha256:6a04d95b8069f3a9e0f3868e565c1b3beac16ab3fce3263cdba1c2bb3340c2f7
```

**v2.25.2:**
```
registry.redhat.io/rhoai/odh-operator-bundle@sha256:328d16d24da1d2cb17928bc7a575f892b4e1c3455d118714483c57060292644e
```

## Upgrade Path (2.25.2 → 3.3.0)

From `catalog.yaml`:
```yaml
name: rhods-operator.3.3.0
replaces: rhods-operator.2.25.2
skipRange: '>=2.25.0 <3.3.0'
```

This configuration enabled the direct upgrade observed on the dbasung cluster.

## Quick Start

**View upgrade graph:**
```bash
yq eval 'select(.schema == "olm.channel" and .name == "stable") | .entries[]' catalog.yaml
```

**List all bundles:**
```bash
yq eval 'select(.schema == "olm.bundle") | .name' catalog.yaml
```

**Inspect bundle properties:**
```bash
yq eval 'select(.schema == "olm.bundle" and .name == "rhods-operator.3.3.0") | .properties' catalog.yaml
```

**View CRDs in bundle:**
```bash
ls -1 bundles/3.3.0/manifests/*.yaml | grep -v clusterserviceversion
```

## Building Your Own FBC

See `BUNDLE_STRUCTURE.md` for three methods:
1. **From existing bundle images** - Quickest method
2. **From operator source code** - Most flexible
3. **Manual assembly** - Using files in this directory

## CRDs Managed by Operator

37 CRDs across multiple API groups:
- `components.platform.opendatahub.io` - Component CRs (Dashboard, Kserve, Ray, etc.)
- `datasciencecluster.opendatahub.io` - DataScienceCluster CR
- `dscinitialization.opendatahub.io` - DSCInitialization CR
- `dashboard.opendatahub.io` - Dashboard configs and profiles
- `trustyai.opendatahub.io` - TrustyAI CRs
- `services.platform.opendatahub.io` - Service configs
- `modelregistry.opendatahub.io` - Model registry
- And more...

Full list:
```bash
ls -1 bundles/3.3.0/manifests/*.yaml | sed 's/.*\///' | sed 's/\.yaml$//'
```

## Operator Images

**Operator container (v3.3.0):**
```
registry.redhat.io/rhoai/odh-rhel9-operator@sha256:e19cf86e83c4c45844b4257dccadeb97a686f99eed9527a0b317257643a56f9e
```

From CSV metadata annotation: `containerImage`

## How This Was Collected

1. **FBC catalog**: Extracted from catalog pod
   ```bash
   oc cp openshift-marketplace/rhoai-catalog-dev-mn7dk:/configs/rhods-operator/catalog.yaml catalog.yaml
   ```

2. **CSV**: Retrieved from cluster
   ```bash
   oc get csv rhods-operator.3.3.0 -n redhat-ods-operator -o yaml > csv-3.3.0.yaml
   ```

3. **CRDs**: Extracted all opendatahub.io CRDs
   ```bash
   for crd in $(oc get crds -o json | jq -r '.items[] | select(.spec.group | contains("opendatahub.io"))'); do
     oc get crd $crd -o yaml > bundles/3.3.0/manifests/$crd.yaml
   done
   ```

4. **Bundle metadata**: Created from standard OLM bundle format

## Use Cases

### 1. Create Custom Catalog with Modified Upgrade Path
Edit `catalog.yaml` channel entries to change upgrade semantics, then build custom catalog image.

### 2. Pin to Specific Version
Create FBC with only desired versions to prevent unwanted upgrades.

### 3. Offline Installation
Bundle all images referenced in FBC for disconnected environments.

### 4. Development Testing
Create dev catalog with custom bundle images for testing operator changes.

### 5. Understand Operator Evolution
Compare CSVs across versions to see feature additions and changes.

## Related Documentation

- Main cluster inventory: `../README.md`
- Cluster upgrade timeline: `../upgrade-timeline.txt`
- Operator configuration: `../operator-details.txt`
- Full cluster summary: `../summary.txt`

## Tools Required

To work with this content:
- **yq** - YAML processor
- **jq** - JSON processor
- **opm** - Operator Package Manager (for building catalogs)
- **podman/docker** - Container build
- **operator-sdk** - Bundle validation (optional)

## Size Information

```
1.5M  catalog.yaml
28M   crds-all.yaml
151K  csv-3.3.0.yaml
1.1M  bundles/3.3.0/
```

Total: ~30 MB of FBC/bundle data
