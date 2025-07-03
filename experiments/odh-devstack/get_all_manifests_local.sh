#!/usr/bin/env bash
set -e

# Change to the opendatahub-operator directory
cd src/opendatahub-operator

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

# Allow overwriting repo using flags component=repo
pattern="^[a-zA-Z0-9_.-]+:[a-zA-Z0-9_.-]+:[a-zA-Z0-9_.-]+:[a-zA-Z0-9_./-]+$"
if [ "$#" -ge 1 ]; then
    for arg in "$@"; do
        if [[ $arg == --* ]]; then
            arg="${arg:2}"  # Remove the '--' prefix
            IFS="=" read -r key value <<< "$arg"
            if [[ -n "${COMPONENT_MANIFESTS[$key]}" ]]; then
                if [[ ! $value =~ $pattern ]]; then
                    echo "ERROR: The value '$value' does not match the expected format 'repo-org:repo-name:ref-name:source-folder'."
                    continue
                fi
                COMPONENT_MANIFESTS["$key"]=$value
            else
                echo "ERROR: '$key' does not exist in COMPONENT_MANIFESTS, it will be skipped."
                echo "Available components are: [${!COMPONENT_MANIFESTS[@]}]"
                exit 1
            fi
        else
            echo "Warning: Argument '$arg' does not follow the '--key=value' format."
        fi
    done
fi

copy_local_manifest() {
    local key=$1
    local repo_info=$2
    echo -e "\033[32mCopying local manifests for \033[33m${key}\033[32m:\033[0m ${repo_info}"
    IFS=':' read -r -a repo_info <<< "${repo_info}"

    repo_org="${repo_info[0]}"
    repo_name="${repo_info[1]}"
    repo_ref="${repo_info[2]}"
    source_path="${repo_info[3]}"
    target_path="${key}"

    # Local repository path (relative to this script's location)
    local_repo_dir="../${repo_name}"
    
    # Check if local repository exists
    if [ ! -d "$local_repo_dir" ]; then
        echo "ERROR: Local repository not found at '$local_repo_dir'"
        echo "Please run the clone_all_repos.sh script first to set up local repositories"
        return 1
    fi
    
    # Check if source path exists in the local repository
    source_dir="${local_repo_dir}/${source_path}"
    if [ ! -d "$source_dir" ]; then
        echo "ERROR: Source path '$source_path' not found in local repository '$local_repo_dir'"
        echo "Available paths in $local_repo_dir:"
        ls -la "$local_repo_dir" | head -10
        return 1
    fi

    # Create target directory and copy files
    mkdir -p "./opt/manifests/${target_path}"
    
    # Copy all files and directories from source to target
    if cp -rf "${source_dir}"/* "./opt/manifests/${target_path}/" 2>/dev/null; then
        echo "  Successfully copied manifests from ${source_dir} to ./opt/manifests/${target_path}"
    else
        echo "WARNING: No files found to copy from ${source_dir}"
        return 1
    fi
}

# Track background job PIDs
declare -a pids=()

# Use parallel processing
for key in "${!COMPONENT_MANIFESTS[@]}"; do
    copy_local_manifest "$key" "${COMPONENT_MANIFESTS[$key]}" &
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
    echo "One or more manifest copies failed"
    exit 1
fi

echo -e "\033[32mAll local manifests copied successfully!\033[0m" 