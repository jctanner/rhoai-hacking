#!/usr/bin/env python3
"""
OpenDataHub Operator Build and Deploy Script

This script simplifies the process of building, pushing, and deploying
the OpenDataHub operator to an OpenShift cluster.
"""

import subprocess
import sys
import os
import argparse
from pathlib import Path

# =============================================================================
# CONFIGURATION CONSTANTS - Edit these for your environment
# =============================================================================

# Registry configuration
REGISTRY_URL = "registry.tannerjc.net"
REGISTRY_NAMESPACE = "odh"

# Image names and tags
OPERATOR_IMAGE = f"{REGISTRY_URL}/{REGISTRY_NAMESPACE}/opendatahub-operator"
BUNDLE_IMAGE = f"{REGISTRY_URL}/{REGISTRY_NAMESPACE}/opendatahub-operator-bundle"
CATALOG_IMAGE = f"{REGISTRY_URL}/{REGISTRY_NAMESPACE}/opendatahub-operator-catalog"

# Default image tag
DEFAULT_TAG = "latest"

# Operator source directory
OPERATOR_DIR = "src/opendatahub-operator"

# Container builder (podman or docker)
CONTAINER_BUILDER = "podman"

# OpenShift/Kubernetes configuration
OPERATOR_NAMESPACE = "opendatahub-operator-system"
APPLICATIONS_NAMESPACE = "opendatahub"

# Platform
PLATFORM = "linux/amd64"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def run_command(cmd, cwd=None, check=True, capture_output=False, env=None):
    """Run a shell command and handle errors."""
    print(f"Running: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    try:
        result = subprocess.run(
            cmd,
            shell=isinstance(cmd, str),
            cwd=cwd,
            check=check,
            capture_output=capture_output,
            text=True,
            env=env
        )
        if capture_output:
            return result.stdout.strip()
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {e}")
        return False

def check_prerequisites():
    """Check if required tools are available."""
    tools = [CONTAINER_BUILDER, "make", "kubectl", "oc"]
    missing = []
    
    for tool in tools:
        if not run_command(f"which {tool}", check=False, capture_output=True):
            missing.append(tool)
    
    if missing:
        print(f"Missing required tools: {', '.join(missing)}")
        return False
    return True

def get_operator_version():
    """Get the current operator version from the Makefile."""
    makefile_path = Path(OPERATOR_DIR) / "Makefile"
    if not makefile_path.exists():
        return "unknown"
    
    with open(makefile_path, 'r') as f:
        for line in f:
            if line.startswith("VERSION ?="):
                return line.split("=")[1].strip()
    return "unknown"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

def prepare_local_manifests():
    """Prepare local manifests using get_all_manifests_local.sh script."""
    print("Preparing local manifests...")
    
    # First check if the script exists
    manifest_script = Path("get_all_manifests_local.sh")
    if not manifest_script.exists():
        print("Warning: get_all_manifests_local.sh not found, will fetch manifests during build")
        return False
    
    # Run the local manifest collection script
    return run_command(
        ["./get_all_manifests_local.sh"],
        cwd="."
    )

def build_operator_image(tag=DEFAULT_TAG, use_local_manifests=True):
    """Build the operator image."""
    print(f"Building operator image: {OPERATOR_IMAGE}:{tag}")
    
    if use_local_manifests:
        print("  Using local manifests (USE_LOCAL=true)")
    else:
        print("  Fetching fresh manifests (USE_LOCAL=false)")
    
    env = os.environ.copy()
    env.update({
        'IMG': f"{OPERATOR_IMAGE}:{tag}",
        'IMAGE_BUILDER': CONTAINER_BUILDER,
        'PLATFORM': PLATFORM
    })
    
    # Pass USE_LOCAL as a make variable, not just environment variable
    make_cmd = [
        "make", "image-build",
        f"USE_LOCAL={str(use_local_manifests).lower()}"
    ]
    
    return run_command(
        make_cmd,
        cwd=OPERATOR_DIR,
        env=env
    )

def build_bundle_image(tag=DEFAULT_TAG):
    """Build the operator bundle image."""
    print(f"Building bundle image: {BUNDLE_IMAGE}:{tag}")
    
    version = get_operator_version()
    env = os.environ.copy()
    env.update({
        'BUNDLE_IMG': f"{BUNDLE_IMAGE}:{tag}",
        'IMAGE_BUILDER': CONTAINER_BUILDER,
        'PLATFORM': PLATFORM,
        'VERSION': version
    })
    
    return run_command(
        ["make", "bundle-build"],
        cwd=OPERATOR_DIR,
        env=env
    )

def build_catalog_image(tag=DEFAULT_TAG):
    """Build the operator catalog image."""
    print(f"Building catalog image: {CATALOG_IMAGE}:{tag}")
    
    version = get_operator_version()
    env = os.environ.copy()
    env.update({
        'CATALOG_IMG': f"{CATALOG_IMAGE}:{tag}",
        'BUNDLE_IMG': f"{BUNDLE_IMAGE}:{tag}",
        'IMAGE_BUILDER': CONTAINER_BUILDER,
        'PLATFORM': PLATFORM,
        'VERSION': version
    })
    
    return run_command(
        ["make", "catalog-build"],
        cwd=OPERATOR_DIR,
        env=env
    )

# =============================================================================
# PUSH FUNCTIONS
# =============================================================================

def push_operator_image(tag=DEFAULT_TAG):
    """Push the operator image to registry."""
    print(f"Pushing operator image: {OPERATOR_IMAGE}:{tag}")
    
    env = os.environ.copy()
    env.update({
        'IMG': f"{OPERATOR_IMAGE}:{tag}",
        'IMAGE_BUILDER': CONTAINER_BUILDER
    })
    
    return run_command(
        ["make", "image-push"],
        cwd=OPERATOR_DIR,
        env=env
    )

def push_bundle_image(tag=DEFAULT_TAG):
    """Push the bundle image to registry."""
    print(f"Pushing bundle image: {BUNDLE_IMAGE}:{tag}")
    
    env = os.environ.copy()
    env.update({
        'BUNDLE_IMG': f"{BUNDLE_IMAGE}:{tag}",
        'IMAGE_BUILDER': CONTAINER_BUILDER
    })
    
    return run_command(
        ["make", "bundle-push"],
        cwd=OPERATOR_DIR,
        env=env
    )

def push_catalog_image(tag=DEFAULT_TAG):
    """Push the catalog image to registry."""
    print(f"Pushing catalog image: {CATALOG_IMAGE}:{tag}")
    
    env = os.environ.copy()
    env.update({
        'CATALOG_IMG': f"{CATALOG_IMAGE}:{tag}",
        'IMAGE_BUILDER': CONTAINER_BUILDER
    })
    
    return run_command(
        ["make", "catalog-push"],
        cwd=OPERATOR_DIR,
        env=env
    )

# =============================================================================
# DEPLOY FUNCTIONS
# =============================================================================

def check_operator_installed():
    """Check if the operator is already installed."""
    result = run_command(
        ["kubectl", "get", "deployment", "-n", OPERATOR_NAMESPACE, "-o", "name"],
        check=False,
        capture_output=True
    )
    return "deployment" in result if result else False

def uninstall_operator():
    """Uninstall the operator from the cluster."""
    print("Uninstalling operator...")
    
    env = os.environ.copy()
    env.update({
        'OPERATOR_NAMESPACE': OPERATOR_NAMESPACE
    })
    
    return run_command(
        ["make", "undeploy"],
        cwd=OPERATOR_DIR,
        env=env
    )

def uninstall_crds():
    """Uninstall the Custom Resource Definitions."""
    print("Uninstalling CRDs...")
    
    env = os.environ.copy()
    env.update({
        'OPERATOR_NAMESPACE': OPERATOR_NAMESPACE
    })
    
    return run_command(
        ["make", "uninstall"],
        cwd=OPERATOR_DIR,
        env=env
    )

def install_crds():
    """Install the Custom Resource Definitions."""
    print("Installing CRDs...")
    
    env = os.environ.copy()
    env.update({
        'OPERATOR_NAMESPACE': OPERATOR_NAMESPACE
    })
    
    return run_command(
        ["make", "install"],
        cwd=OPERATOR_DIR,
        env=env
    )

def deploy_operator(tag=DEFAULT_TAG):
    """Deploy the operator to the cluster."""
    print(f"Deploying operator: {OPERATOR_IMAGE}:{tag}")
    
    env = os.environ.copy()
    env.update({
        'IMG': f"{OPERATOR_IMAGE}:{tag}",
        'OPERATOR_NAMESPACE': OPERATOR_NAMESPACE
    })
    
    return run_command(
        ["make", "deploy"],
        cwd=OPERATOR_DIR,
        env=env
    )

def deploy_bundle(tag=DEFAULT_TAG):
    """Deploy the operator using the bundle."""
    print(f"Deploying operator bundle: {BUNDLE_IMAGE}:{tag}")
    
    env = os.environ.copy()
    env.update({
        'BUNDLE_IMG': f"{BUNDLE_IMAGE}:{tag}",
        'OPERATOR_NAMESPACE': OPERATOR_NAMESPACE
    })
    
    return run_command(
        ["make", "deploy-bundle"],
        cwd=OPERATOR_DIR,
        env=env
    )

def clean_existing_resources():
    """Clean existing DSCI and DSC resources."""
    print("Cleaning existing DSCI and DSC resources...")
    
    # Delete existing DSC instances
    run_command(
        ["kubectl", "delete", "datasciencecluster", "--all", "--ignore-not-found=true"],
        check=False
    )
    
    # Delete existing DSCI instances
    run_command(
        ["kubectl", "delete", "dscinitialization", "--all", "--ignore-not-found=true"],
        check=False
    )
    
    # Wait for resources to be fully deleted
    print("Waiting for resources to be cleaned up...")
    run_command(["sleep", "10"])

def apply_sample_configs():
    """Apply the sample DSCI and DSC configurations."""
    print("Applying sample configurations...")
    
    configs = ["config/dsci.yaml", "config/dsc.yaml"]
    for config in configs:
        if Path(config).exists():
            print(f"Applying {config}...")
            run_command(["kubectl", "apply", "-f", config])
        else:
            print(f"Warning: {config} not found, skipping...")

def clean_deploy_operator(tag=DEFAULT_TAG):
    """Clean deploy: uninstall existing operator and deploy fresh."""
    print(f"Clean deploying operator: {OPERATOR_IMAGE}:{tag}")
    
    # Check if operator is installed
    if check_operator_installed():
        print("Existing operator installation detected")
        
        # Clean existing resources first
        clean_existing_resources()
        
        # Uninstall operator
        uninstall_operator()
        
        # Wait for cleanup
        print("Waiting for operator cleanup...")
        run_command(["sleep", "15"])
    
    # Install/reinstall CRDs
    if not install_crds():
        print("Failed to install CRDs")
        return False
    
    # Deploy operator
    if not deploy_operator(tag):
        print("Failed to deploy operator")
        return False
    
    print("Clean deployment completed successfully!")
    return True

def reinstall_operator(tag=DEFAULT_TAG):
    """Reinstall the operator (clean uninstall + fresh install)."""
    print(f"Reinstalling operator: {OPERATOR_IMAGE}:{tag}")
    
    # Clean existing resources
    clean_existing_resources()
    
    # Uninstall operator
    if check_operator_installed():
        uninstall_operator()
    
    # Uninstall CRDs
    uninstall_crds()
    
    # Wait for cleanup
    print("Waiting for complete cleanup...")
    run_command(["sleep", "20"])
    
    # Fresh install
    if not install_crds():
        print("Failed to install CRDs")
        return False
    
    if not deploy_operator(tag):
        print("Failed to deploy operator")
        return False
    
    print("Reinstallation completed successfully!")
    return True

# =============================================================================
# MAIN WORKFLOWS
# =============================================================================

def full_workflow(tag=DEFAULT_TAG, include_bundle=False, include_catalog=False, clean_install=False, use_local_manifests=True):
    """Run the complete build, push, and deploy workflow."""
    print(f"Starting full workflow with tag: {tag}")
    
    if not check_prerequisites():
        return False
    
    # Prepare local manifests if using them
    if use_local_manifests:
        if not prepare_local_manifests():
            print("Failed to prepare local manifests, continuing with fresh fetch...")
            use_local_manifests = False
    
    # Build images
    if not build_operator_image(tag, use_local_manifests):
        print("Failed to build operator image")
        return False
    
    if include_bundle:
        if not build_bundle_image(tag):
            print("Failed to build bundle image")
            return False
    
    if include_catalog:
        if not build_catalog_image(tag):
            print("Failed to build catalog image")
            return False
    
    # Push images
    if not push_operator_image(tag):
        print("Failed to push operator image")
        return False
    
    if include_bundle:
        if not push_bundle_image(tag):
            print("Failed to push bundle image")
            return False
    
    if include_catalog:
        if not push_catalog_image(tag):
            print("Failed to push catalog image")
            return False
    
    # Deploy - choose clean or regular deployment
    if clean_install:
        if not clean_deploy_operator(tag):
            print("Failed to clean deploy operator")
            return False
    else:
        if not install_crds():
            print("Failed to install CRDs")
            return False
        
        if not deploy_operator(tag):
            print("Failed to deploy operator")
            return False
    
    # Apply sample configs
    apply_sample_configs()
    
    print("Full workflow completed successfully!")
    return True

def cleanup_all():
    """Clean up everything - operator, CRDs, and resources."""
    print("Cleaning up all OpenDataHub operator resources...")
    
    # Clean existing resources
    clean_existing_resources()
    
    # Uninstall operator if installed
    if check_operator_installed():
        uninstall_operator()
    
    # Uninstall CRDs
    uninstall_crds()
    
    print("Cleanup completed!")

def show_status():
    """Show the current installation status."""
    print("Current Installation Status:")
    
    # Check operator installation
    if check_operator_installed():
        print("  ✓ Operator: INSTALLED")
        # Get operator image
        result = run_command(
            ["kubectl", "get", "deployment", "-n", OPERATOR_NAMESPACE, "-o", 
             "jsonpath={.items[0].spec.template.spec.containers[0].image}"],
            check=False, capture_output=True
        )
        if result:
            print(f"    Image: {result}")
    else:
        print("  ✗ Operator: NOT INSTALLED")
    
    # Check CRDs
    crds = ["datascienceclusters.datasciencecluster.opendatahub.io", 
           "dscinitializations.dscinitialization.opendatahub.io"]
    crd_installed = True
    for crd in crds:
        result = run_command(
            ["kubectl", "get", "crd", crd],
            check=False, capture_output=True
        )
        if not result:
            crd_installed = False
            break
    
    if crd_installed:
        print("  ✓ CRDs: INSTALLED")
    else:
        print("  ✗ CRDs: NOT INSTALLED")
    
    # Check DSCI
    result = run_command(
        ["kubectl", "get", "dscinitialization", "-o", "name"],
        check=False, capture_output=True
    )
    if result:
        print(f"  ✓ DSCI: {result}")
    else:
        print("  ✗ DSCI: NOT FOUND")
    
    # Check DSC
    result = run_command(
        ["kubectl", "get", "datasciencecluster", "-o", "name"],
        check=False, capture_output=True
    )
    if result:
        print(f"  ✓ DSC: {result}")
    else:
        print("  ✗ DSC: NOT FOUND")

def show_config():
    """Show the current configuration."""
    print("Current Configuration:")
    print(f"  Registry URL: {REGISTRY_URL}")
    print(f"  Registry Namespace: {REGISTRY_NAMESPACE}")
    print(f"  Operator Image: {OPERATOR_IMAGE}")
    print(f"  Bundle Image: {BUNDLE_IMAGE}")
    print(f"  Catalog Image: {CATALOG_IMAGE}")
    print(f"  Default Tag: {DEFAULT_TAG}")
    print(f"  Container Builder: {CONTAINER_BUILDER}")
    print(f"  Operator Namespace: {OPERATOR_NAMESPACE}")
    print(f"  Applications Namespace: {APPLICATIONS_NAMESPACE}")
    print(f"  Platform: {PLATFORM}")
    print(f"  Operator Version: {get_operator_version()}")
    print(f"  Local Manifests Script: {'✓' if Path('get_all_manifests_local.sh').exists() else '✗'}")
    print(f"  Local Manifests Available: {'✓' if Path(OPERATOR_DIR + '/opt/manifests').exists() else '✗'}")

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="OpenDataHub Operator Build and Deploy Tool"
    )
    parser.add_argument(
        "--tag", 
        default=DEFAULT_TAG, 
        help=f"Image tag to use (default: {DEFAULT_TAG})"
    )
    parser.add_argument(
        "--config", 
        action="store_true", 
        help="Show current configuration"
    )
    parser.add_argument(
        "--status", 
        action="store_true", 
        help="Show current installation status"
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Build commands
    build_parser = subparsers.add_parser("build", help="Build images")
    build_parser.add_argument("--bundle", action="store_true", help="Also build bundle image")
    build_parser.add_argument("--catalog", action="store_true", help="Also build catalog image")
    build_parser.add_argument("--no-local", action="store_true", help="Don't use local manifests, fetch fresh")
    
    # Push commands
    push_parser = subparsers.add_parser("push", help="Push images")
    push_parser.add_argument("--bundle", action="store_true", help="Also push bundle image")
    push_parser.add_argument("--catalog", action="store_true", help="Also push catalog image")
    
    # Deploy commands
    subparsers.add_parser("deploy", help="Deploy operator")
    subparsers.add_parser("deploy-bundle", help="Deploy using bundle")
    subparsers.add_parser("clean-deploy", help="Clean deploy (uninstall first, then deploy)")
    subparsers.add_parser("reinstall", help="Complete reinstall (remove CRDs and operator)")
    subparsers.add_parser("install-crds", help="Install CRDs only")
    subparsers.add_parser("uninstall", help="Uninstall operator only")
    subparsers.add_parser("uninstall-crds", help="Uninstall CRDs only")
    subparsers.add_parser("cleanup", help="Clean up everything (operator, CRDs, resources)")
    subparsers.add_parser("apply-configs", help="Apply sample configurations")
    subparsers.add_parser("clean-resources", help="Clean existing DSCI/DSC resources")
    subparsers.add_parser("prepare-manifests", help="Prepare local manifests from cloned repos")
    
    # Full workflow
    full_parser = subparsers.add_parser("full", help="Run complete workflow")
    full_parser.add_argument("--bundle", action="store_true", help="Include bundle images")
    full_parser.add_argument("--catalog", action="store_true", help="Include catalog images")
    full_parser.add_argument("--clean", action="store_true", help="Use clean deployment (uninstall first)")
    full_parser.add_argument("--no-local", action="store_true", help="Don't use local manifests, fetch fresh")
    
    args = parser.parse_args()
    
    if args.config:
        show_config()
        return
    
    if args.status:
        show_status()
        return
    
    if not args.command:
        parser.print_help()
        return
    
    success = True
    
    if args.command == "build":
        use_local = not args.no_local
        if use_local and not prepare_local_manifests():
            print("Failed to prepare local manifests, continuing with fresh fetch...")
            use_local = False
        success = build_operator_image(args.tag, use_local)
        if success and args.bundle:
            success = build_bundle_image(args.tag)
        if success and args.catalog:
            success = build_catalog_image(args.tag)
    
    elif args.command == "push":
        success = push_operator_image(args.tag)
        if success and args.bundle:
            success = push_bundle_image(args.tag)
        if success and args.catalog:
            success = push_catalog_image(args.tag)
    
    elif args.command == "deploy":
        success = deploy_operator(args.tag)
    
    elif args.command == "deploy-bundle":
        success = deploy_bundle(args.tag)
    
    elif args.command == "clean-deploy":
        success = clean_deploy_operator(args.tag)
    
    elif args.command == "reinstall":
        success = reinstall_operator(args.tag)
    
    elif args.command == "install-crds":
        success = install_crds()
    
    elif args.command == "uninstall":
        success = uninstall_operator()
    
    elif args.command == "uninstall-crds":
        success = uninstall_crds()
    
    elif args.command == "cleanup":
        cleanup_all()
    
    elif args.command == "apply-configs":
        apply_sample_configs()
    
    elif args.command == "clean-resources":
        clean_existing_resources()
    
    elif args.command == "prepare-manifests":
        success = prepare_local_manifests()
    
    elif args.command == "full":
        use_local = not args.no_local
        success = full_workflow(args.tag, args.bundle, args.catalog, args.clean, use_local)
    
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main() 