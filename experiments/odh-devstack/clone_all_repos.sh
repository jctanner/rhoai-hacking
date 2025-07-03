#!/usr/bin/env bash
set -e

GITHUB_URL="https://github.com"
SRC_DIR="src"

# Create src directory if it doesn't exist
mkdir -p "$SRC_DIR"

# COMPONENT_MANIFESTS is a list of components repositories info to fetch the manifests
# in the format of "repo-org:repo-name:ref-name:source-folder" and key is the target folder under manifests/
declare -A COMPONENT_MANIFESTS=(
    ["dashboard"]="opendatahub-io:odh-dashboard:main:manifests"
    ["workbenches/kf-notebook-controller"]="opendatahub-io:kubeflow:main:components/notebook-controller/config"
    ["workbenches/odh-notebook-controller"]="opendatahub-io:kubeflow:main:components/odh-notebook-controller/config"
    ["workbenches/notebooks"]="opendatahub-io:notebooks:main:manifests"
    ["modelmeshserving"]="opendatahub-io:modelmesh-serving:release-0.12.0-rc0:config"
    ["kserve"]="opendatahub-io:kserve:release-v0.15:config"
    ["kueue"]="opendatahub-io:kueue:dev:config"
    ["codeflare"]="opendatahub-io:codeflare-operator:main:config"
    ["ray"]="opendatahub-io:kuberay:dev:ray-operator/config"
    ["trustyai"]="trustyai-explainability:trustyai-service-operator:main:config"
    ["modelregistry"]="opendatahub-io:model-registry-operator:main:config"
    ["trainingoperator"]="opendatahub-io:training-operator:dev:manifests"
    ["datasciencepipelines"]="opendatahub-io:data-science-pipelines-operator:main:config"
    ["modelcontroller"]="opendatahub-io:odh-model-controller:incubating:config"
    ["feastoperator"]="opendatahub-io:feast:stable:infra/feast-operator/config"
    ["llamastackoperator"]="opendatahub-io:llama-stack-k8s-operator:odh:config"
)

# Extract unique repositories (some repos are used multiple times for different components)
declare -A UNIQUE_REPOS=()

for key in "${!COMPONENT_MANIFESTS[@]}"; do
    repo_info="${COMPONENT_MANIFESTS[$key]}"
    IFS=':' read -r -a repo_parts <<< "${repo_info}"
    
    repo_org="${repo_parts[0]}"
    repo_name="${repo_parts[1]}"
    repo_ref="${repo_parts[2]}"
    
    # Use repo_name as key to avoid duplicates
    UNIQUE_REPOS["$repo_name"]="$repo_org:$repo_name:$repo_ref"
done

clone_repo() {
    local repo_info=$1
    IFS=':' read -r -a repo_parts <<< "${repo_info}"
    
    repo_org="${repo_parts[0]}"
    repo_name="${repo_parts[1]}"
    repo_ref="${repo_parts[2]}"
    
    repo_url="${GITHUB_URL}/${repo_org}/${repo_name}"
    target_dir="${SRC_DIR}/${repo_name}"
    
    echo -e "\033[32mCloning repo \033[33m${repo_name}\033[32m:\033[0m ${repo_url} (ref: ${repo_ref})"
    
    if [ -d "$target_dir" ]; then
        echo "  Directory $target_dir already exists, skipping..."
        return 0
    fi
    
    # Clone the repository
    git clone -q "$repo_url" "$target_dir"
    
    # Checkout the specific ref
    pushd "$target_dir" &>/dev/null
    git checkout -q "$repo_ref" 2>/dev/null || {
        echo "  Warning: Could not checkout ref '$repo_ref', staying on default branch"
    }
    popd &>/dev/null
    
    echo "  Successfully cloned $repo_name"
}

# Track background job PIDs
declare -a pids=()

# Use parallel processing to clone repositories
for repo_name in "${!UNIQUE_REPOS[@]}"; do
    clone_repo "${UNIQUE_REPOS[$repo_name]}" &
    pids+=($!)
done

# Wait and check exit codes
failed=0
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        failed=1
    fi
done

if [ $failed -eq 1 ]; then
    echo "One or more clones failed"
    exit 1
fi

echo -e "\033[32mAll repositories cloned successfully!\033[0m"
echo "Repositories are located in the '$SRC_DIR' directory:"
ls -la "$SRC_DIR" 