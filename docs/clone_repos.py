#!/usr/bin/env python3
"""
Clone all repositories referenced in the OpenDataHub operator's get_all_manifests.sh script.
"""

import os
import sys
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# Configuration
GITHUB_URL = "https://github.com"
SRC_DIR = "src"

# Repository information extracted from get_all_manifests.sh
# Format: "repo-org:repo-name:ref-name"
REPOS = {
    "odh-dashboard": "opendatahub-io:odh-dashboard:main",
    "kubeflow": "opendatahub-io:kubeflow:main",
    "notebooks": "opendatahub-io:notebooks:main",
    "modelmesh-serving": "opendatahub-io:modelmesh-serving:release-0.12.0-rc0",
    "kserve": "opendatahub-io:kserve:release-v0.15",
    "kueue": "opendatahub-io:kueue:dev",
    "codeflare-operator": "opendatahub-io:codeflare-operator:main",
    "kuberay": "opendatahub-io:kuberay:dev",
    "trustyai-service-operator": "trustyai-explainability:trustyai-service-operator:main",
    "model-registry-operator": "opendatahub-io:model-registry-operator:main",
    "training-operator": "opendatahub-io:training-operator:dev",
    "data-science-pipelines-operator": "opendatahub-io:data-science-pipelines-operator:main",
    "odh-model-controller": "opendatahub-io:odh-model-controller:incubating",
    "feast": "opendatahub-io:feast:stable",
    "llama-stack-k8s-operator": "opendatahub-io:llama-stack-k8s-operator:odh",
}

# Color codes for output
class Colors:
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    RED = '\033[31m'
    RESET = '\033[0m'


def run_command(cmd, cwd=None, check=True):
    """Run a command and return the result."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            check=check,
            capture_output=True,
            text=True
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.CalledProcessError as e:
        return False, e.stdout, e.stderr


def clone_repo(repo_name, repo_info):
    """Clone or update a single repository."""
    print(f"{Colors.GREEN}Cloning repository {Colors.YELLOW}{repo_name}{Colors.GREEN}:{Colors.RESET} {repo_info}")
    
    repo_parts = repo_info.split(':')
    repo_org = repo_parts[0]
    repo_repo = repo_parts[1]
    repo_ref = repo_parts[2]
    
    repo_url = f"{GITHUB_URL}/{repo_org}/{repo_repo}"
    target_dir = Path(SRC_DIR) / repo_repo
    
    try:
        # Check if directory already exists
        if target_dir.exists():
            print(f"Directory {target_dir} already exists. Updating...")
            
            # Fetch all branches and tags
            success, stdout, stderr = run_command("git fetch --all --tags", cwd=target_dir)
            if not success:
                print(f"{Colors.RED}Failed to fetch updates for {repo_name}: {stderr}{Colors.RESET}")
                return False
            
            # Checkout the desired ref
            success, stdout, stderr = run_command(f"git checkout {repo_ref}", cwd=target_dir)
            if not success:
                # Try to create and checkout a new branch
                success, stdout, stderr = run_command(f"git checkout -b {repo_ref} origin/{repo_ref}", cwd=target_dir)
                if not success:
                    print(f"{Colors.RED}Failed to checkout {repo_ref} for {repo_name}: {stderr}{Colors.RESET}")
                    return False
            
            # Try to pull latest changes
            run_command(f"git pull origin {repo_ref}", cwd=target_dir, check=False)
            
        else:
            # Clone the repository
            success, stdout, stderr = run_command(f"git clone {repo_url} {target_dir}")
            if not success:
                print(f"{Colors.RED}Failed to clone {repo_name}: {stderr}{Colors.RESET}")
                return False
            
            # Checkout the desired ref
            success, stdout, stderr = run_command(f"git checkout {repo_ref}", cwd=target_dir)
            if not success:
                # Try to create and checkout a new branch
                success, stdout, stderr = run_command(f"git checkout -b {repo_ref} origin/{repo_ref}", cwd=target_dir)
                if not success:
                    print(f"{Colors.RED}Failed to checkout {repo_ref} for {repo_name}: {stderr}{Colors.RESET}")
                    return False
        
        print(f"{Colors.GREEN}Successfully processed {repo_name}{Colors.RESET}")
        return True
        
    except Exception as e:
        print(f"{Colors.RED}Error processing {repo_name}: {str(e)}{Colors.RESET}")
        return False


def main():
    """Main function to clone all repositories."""
    print(f"{Colors.GREEN}Starting repository cloning process...{Colors.RESET}")
    
    # Create src directory if it doesn't exist
    Path(SRC_DIR).mkdir(exist_ok=True)
    
    # Use ThreadPoolExecutor for parallel cloning
    failed_repos = []
    
    with ThreadPoolExecutor(max_workers=8) as executor:
        # Submit all clone tasks
        future_to_repo = {
            executor.submit(clone_repo, repo_name, repo_info): repo_name
            for repo_name, repo_info in REPOS.items()
        }
        
        # Wait for all tasks to complete
        for future in as_completed(future_to_repo):
            repo_name = future_to_repo[future]
            try:
                success = future.result()
                if not success:
                    failed_repos.append(repo_name)
            except Exception as e:
                print(f"{Colors.RED}Exception occurred for {repo_name}: {str(e)}{Colors.RESET}")
                failed_repos.append(repo_name)
    
    # Report results
    if failed_repos:
        print(f"{Colors.RED}Failed to clone the following repositories: {', '.join(failed_repos)}{Colors.RESET}")
        sys.exit(1)
    else:
        print(f"{Colors.GREEN}All repositories have been successfully cloned to the src directory!{Colors.RESET}")
        print("Available repositories:")
        for repo_name, repo_info in REPOS.items():
            repo_parts = repo_info.split(':')
            repo_repo = repo_parts[1]
            print(f"  - {SRC_DIR}/{repo_repo}")


if __name__ == "__main__":
    main() 