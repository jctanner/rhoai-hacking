# OLM Upgrade Experiments for OpenDataHub/RHOAI

Experimental repository for testing and understanding Operator Lifecycle Manager (OLM) upgrade processes, with a specific focus on the OpenDataHub (ODH) and Red Hat OpenShift AI (RHOAI) operator upgrades from v2.25.0 to v3.0.0.

## Overview

This project provides tools, scripts, and documentation for:

- Understanding how OLM handles operator upgrades internally
- Testing ODH/RHOAI operator upgrades in development environments
- Analyzing upgrade paths, CRD migrations, and component changes
- Cleaning up and verifying cluster state between upgrade experiments
- Documenting findings and hypotheses about upgrade behavior

## Project Structure

```
.
├── patches/              # Source code patches applied during builds
├── scripts/              # Automation scripts for build, install, upgrade, and cleanup
├── src/                  # Source code repositories (OLM and ODH operator)
├── *.md                  # Documentation files
└── README.md            # This file
```

### Source Code Patches

The `patches/` directory contains git patches that are automatically applied during the build process:

- **`stable-2.x-csv.patch`** - Fixes CSV image references for v2.25.0 builds
- **`main-upgrade-fixes.patch`** - Adds upgrade path declaration and OdhDashboardConfig error handling for v3.0.0

These patches are necessary because the source checkouts in `src/` are ephemeral (not tracked in this repo). The build scripts automatically:
1. Reset the working tree to clean state
2. Apply relevant patches
3. Parameterize registry paths
4. Verify patches applied correctly
5. Continue with the build

This ensures reproducible builds without requiring manual edits to the source code.

## Documentation

### Core Guides

- **[OLM-UPGRADES.md](./OLM-UPGRADES.md)** - Deep dive into OLM's internal upgrade mechanisms
  - Upgrade discovery and orchestration
  - CRD validation and storage version safety
  - Dependency resolution algorithms
  - CSV state transitions
  - Rollback and failure handling

- **[ODH-UPGRADE-HYPOTHESIS.md](./ODH-UPGRADE-HYPOTHESIS.md)** - Analysis of ODH v2.25.0 → v3.0.0 upgrade
  - CRD additions, updates, and deprecations
  - Component state changes
  - RBAC modifications
  - Breaking changes and migration requirements

- **[UPGRADE-HACK.md](./UPGRADE-HACK.md)** - Quick reference for choosing an upgrade testing approach
  - With registry (recommended for production-like testing)
  - Without registry (quick local testing)

### Detailed Approach Guides

- **[UPGRADE-HACK-REGISTRY.md](./UPGRADE-HACK-REGISTRY.md)** - Registry-based upgrade testing workflow
- **[UPGRADE-HACK-NO-REGISTRY.md](./UPGRADE-HACK-NO-REGISTRY.md)** - Local upgrade testing without registry

### Cleanup and Maintenance

- **[CLEANUP-SCRIPTS-README.md](./CLEANUP-SCRIPTS-README.md)** - Comprehensive cleanup documentation
  - Complete ODH/RHOAI removal from clusters
  - etcd cache verification and cleanup
  - Troubleshooting stuck resources

### Test Results

- **[UPGRADE-TEST-RESULTS.md](./UPGRADE-TEST-RESULTS.md)** - Detailed upgrade test execution logs
- **[UPGRADE-TEST-RESULTS-20260129_221126.md](./UPGRADE-TEST-RESULTS-20260129_221126.md)** - Timestamped test run
- **[BUG-DASHBOARDCONFIG.md](./BUG-DASHBOARDCONFIG.md)** - Analysis of specific upgrade issues

## Scripts

All scripts are located in the `scripts/` directory.

### Build and Push

| Script | Purpose | Patches Applied |
|--------|---------|-----------------|
| `build-and-push-v2.25.0.sh` | Build and push ODH operator v2.25.0 bundle | `stable-2.x-csv.patch` |
| `build-and-push-v3.0.0.sh` | Build and push ODH operator v3.0.0 bundle | `main-upgrade-fixes.patch` |

**Note:** Build scripts automatically reset source trees and apply patches before building.

### Install and Upgrade

| Script | Purpose |
|--------|---------|
| `install-v2.25.0.sh` | Install ODH operator v2.25.0 using operator-sdk |
| `upgrade-to-v3.0.0.sh` | Upgrade from v2.25.0 to v3.0.0 using operator-sdk |

### Cleanup and Verification

| Script | Purpose |
|--------|---------|
| `cleanup-odh-complete.sh` | Complete removal of all ODH/RHOAI resources |
| `verify-etcd-clean.sh` | Verify etcd cache is clear of ODH data |
| `clean-etcd-keys.sh` | Directly remove orphaned ODH keys from etcd |
| `check-cluster-resources.sh` | Check current cluster state for ODH resources |

## Quick Start

### Prerequisites

- OpenShift 4.x cluster with cluster-admin access
- `operator-sdk` CLI installed
- `oc` (OpenShift CLI) configured
- Container registry access (for registry-based approach)
- `podman` or `docker` for building images

### Basic Workflow

1. **Clean up any existing installation:**
   ```bash
   ./scripts/cleanup-odh-complete.sh
   ./scripts/verify-etcd-clean.sh
   ```

2. **Build and push operator bundles** (if using personal registry):
   ```bash
   ./scripts/build-and-push-v2.25.0.sh
   ./scripts/build-and-push-v3.0.0.sh
   ```

3. **Install v2.25.0:**
   ```bash
   ./scripts/install-v2.25.0.sh
   ```

4. **Verify installation:**
   ```bash
   oc get csv,pods -n redhat-ods-operator
   oc get dscinitializations -A
   ```

5. **Upgrade to v3.0.0:**
   ```bash
   ./scripts/upgrade-to-v3.0.0.sh
   ```

6. **Monitor upgrade:**
   ```bash
   oc get csv -n redhat-ods-operator -w
   oc logs -n redhat-ods-operator -l app.kubernetes.io/name=rhods-operator -f
   ```

7. **Clean up after testing:**
   ```bash
   ./scripts/cleanup-odh-complete.sh
   ./scripts/verify-etcd-clean.sh
   # If verification fails:
   ./scripts/clean-etcd-keys.sh
   ```

## Key Findings

### Required Source Code Patches

To enable v2.25.0 → v3.0.0 upgrades, two patches are required:

**1. stable-2.x-csv.patch (v2.25.0)**
- Replaces placeholder `REPLACE_IMAGE:latest` with actual operator image reference
- Ensures the CSV contains the correct container image path
- Applied automatically during v2.25.0 build

**2. main-upgrade-fixes.patch (v3.0.0)**
- Adds `replaces: rhods-operator.v2.25.0` to enable OLM upgrade path
- Fixes OdhDashboardConfig error handling to prevent crashes during upgrade
- Handles both "not found" instances and missing CRD scenarios
- Applied automatically during v3.0.0 build

See [BUG-DASHBOARDCONFIG.md](./BUG-DASHBOARDCONFIG.md) for details on the dashboard config fix.

### What OLM Does Beyond Pod Replacement

Based on codebase analysis and testing:

1. **CRD Storage Version Validation** - Prevents data loss during CRD migrations
2. **Existing CR Schema Validation** - Ensures all existing resources remain valid
3. **Dual-CSV Operation** - Both old and new operators run simultaneously during transition
4. **Atomic InstallPlan Execution** - All resources created together or none
5. **Dependency Graph Resolution** - Ensures all required APIs are available
6. **Owner Reference Tracking** - Enables proper resource cleanup
7. **Webhook Preservation** - Admission control continues during upgrade

### ODH v2.25.0 → v3.0.0 Upgrade Changes

**New CRDs (5):**
- GatewayConfig, MLflowOperator, ModelsAsService, SparkOperator, Trainer

**Multi-Version API Support (3):**
- DataScienceCluster (v1 + v2)
- DSCInitialization (v1 + v2)
- HardwareProfile (v1alpha1 + v1)

**Deprecated Components:**
- CodeFlare (removed from RHOAI v3.0)
- ModelMeshServing (removed from RHOAI v3.0)
- TrainingOperator (replaced by Trainer)

**Important:** Deprecated components remain on the cluster but are no longer managed by the operator.

## Understanding etcd Corruption

### Symptoms
- Error: `request to convert CR from an invalid group/version`
- Operator pods crash-looping
- CSV stuck in Installing phase
- Resources can't be queried even after CRD deletion

### Root Cause
- CRD deletion removes schema but not etcd data
- API server cache serves stale data
- etcd keys persist after CRD removal

### Solution
1. Delete all instances first (`cleanup-odh-complete.sh`)
2. Delete CRDs
3. Verify etcd is clean (`verify-etcd-clean.sh`)
4. Remove orphaned keys if found (`clean-etcd-keys.sh`)

## Configuration

Scripts use the following default configuration:

- **Registry:** `registry.tannerjc.net/opendatahub` (update in scripts for your registry)
- **Namespace:** `redhat-ods-operator`
- **Platform:** `linux/amd64`
- **Build Environment:** `olm-build-env:go1.24`

Edit the scripts to customize for your environment.

## Safety Notes

- These tools are designed for development and testing clusters
- Direct etcd manipulation should only be done on non-production clusters
- Always take backups before performing upgrades or cleanups
- Test upgrade procedures in non-production environments first

## Troubleshooting

### Script hangs during CRD deletion
Scripts automatically remove finalizers and use `--force --grace-period=0`

### Still seeing v2 errors after cleanup
Run `clean-etcd-keys.sh` to remove orphaned etcd keys

### Cannot access etcd pods
Requires cluster-admin or openshift-etcd namespace access

### Namespaces stuck in Terminating
Wait for cleanup script to complete (removes finalizers automatically)

## References

- [Operator Lifecycle Manager (OLM)](https://github.com/operator-framework/operator-lifecycle-manager)
- [OpenDataHub Operator](https://github.com/opendatahub-io/opendatahub-operator)
- [Operator SDK Documentation](https://sdk.operatorframework.io/)
- [Red Hat OpenShift AI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed)

## Contributing

This is an experimental repository for testing and documentation purposes. Feel free to:

- Report issues or findings
- Submit improvements to scripts or documentation
- Share upgrade test results
- Propose additional experiments

## License

This project follows the licensing of its source dependencies (OLM and ODH operator repositories).
