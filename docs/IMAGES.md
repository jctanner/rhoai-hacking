# OpenDataHub Platform Docker Images Catalog

This document provides a comprehensive catalog of all Docker images used across the OpenDataHub (ODH) platform, including their origins, repositories, and parameter mappings.

## Image Management System

OpenDataHub uses a sophisticated image management system based on **environment variable substitution** and **parameter mapping**:

1. **RELATED_IMAGE_*** environment variables contain the actual image references
2. **Parameter mappings** in component controllers link template parameters to RELATED_IMAGE variables
3. **Template substitution** replaces `$(parameter-name)` with actual image values during deployment

## Image Categories

### 1. **Operator Images**
Images for Kubernetes operators that manage ODH components.

#### **Core OpenDataHub Operator**
- **Image**: `quay.io/opendatahub/opendatahub-operator:v2.x.x`
- **Repository**: `opendatahub-io/opendatahub-operator`
- **Location**: `/Dockerfile`
- **Purpose**: Main operator that manages all ODH components

#### **Component Operators**
| Component | Image Repository | RELATED_IMAGE Parameter | Source Repository |
|-----------|------------------|-------------------------|-------------------|
| **CodeFlare Operator** | `quay.io/opendatahub/codeflare-operator:vX.X.X` | `RELATED_IMAGE_ODH_CODEFLARE_OPERATOR_IMAGE` | `opendatahub-io/codeflare-operator` |
| **Training Operator** | `quay.io/opendatahub/training-operator:vX.X.X` | `RELATED_IMAGE_ODH_TRAINING_OPERATOR_IMAGE` | `opendatahub-io/training-operator` |
| **Data Science Pipelines Operator** | `quay.io/opendatahub/data-science-pipelines-operator:vX.X.X` | `RELATED_IMAGE_ODH_DATA_SCIENCE_PIPELINES_OPERATOR_CONTROLLER_IMAGE` | `opendatahub-io/data-science-pipelines-operator` |
| **Model Registry Operator** | `quay.io/opendatahub/model-registry-operator:vX.X.X` | `RELATED_IMAGE_ODH_MODEL_REGISTRY_OPERATOR_IMAGE` | `opendatahub-io/model-registry-operator` |
| **TrustyAI Service Operator** | `quay.io/opendatahub/trustyai-service-operator:vX.X.X` | `RELATED_IMAGE_ODH_TRUSTYAI_SERVICE_OPERATOR_IMAGE` | `trustyai-explainability/trustyai-service-operator` |
| **Feast Operator** | `quay.io/opendatahub/feast-operator:vX.X.X` | `RELATED_IMAGE_ODH_FEAST_OPERATOR_IMAGE` | `opendatahub-io/feast/infra/feast-operator` |
| **Llama Stack Operator** | `quay.io/opendatahub/llama-stack-k8s-operator:vX.X.X` | `RELATED_IMAGE_ODH_LLAMA_STACK_K8S_OPERATOR_IMAGE` | `opendatahub-io/llama-stack-k8s-operator` |

### 2. **Controller Images**
Images for Kubernetes controllers that manage specific resources.

#### **Notebook Controllers**
| Controller | Image Repository | RELATED_IMAGE Parameter | Source Repository |
|------------|------------------|-------------------------|-------------------|
| **ODH Notebook Controller** | `quay.io/opendatahub/odh-notebook-controller:vX.X.X` | `RELATED_IMAGE_ODH_NOTEBOOK_CONTROLLER_IMAGE` | `opendatahub-io/kubeflow/components/odh-notebook-controller` |
| **KF Notebook Controller** | `quay.io/opendatahub/kf-notebook-controller:vX.X.X` | `RELATED_IMAGE_ODH_KF_NOTEBOOK_CONTROLLER_IMAGE` | `opendatahub-io/kubeflow/components/notebook-controller` |

#### **Other Controllers**
| Controller | Image Repository | RELATED_IMAGE Parameter | Source Repository |
|------------|------------------|-------------------------|-------------------|
| **ODH Model Controller** | `quay.io/opendatahub/odh-model-controller:vX.X.X` | `RELATED_IMAGE_ODH_MODEL_CONTROLLER_IMAGE` | `opendatahub-io/odh-model-controller` |
| **Kueue Controller** | `quay.io/opendatahub/kueue-controller:vX.X.X` | `RELATED_IMAGE_ODH_KUEUE_CONTROLLER_IMAGE` | `opendatahub-io/kueue` |
| **KubeRay Operator** | `quay.io/opendatahub/kuberay-operator:vX.X.X` | `RELATED_IMAGE_ODH_KUBERAY_OPERATOR_CONTROLLER_IMAGE` | `opendatahub-io/kuberay` |

### 3. **Application Images**
Images for web applications and user interfaces.

#### **Dashboard**
- **Image**: `quay.io/opendatahub/odh-dashboard:vX.X.X`
- **RELATED_IMAGE**: `RELATED_IMAGE_ODH_DASHBOARD_IMAGE`
- **Repository**: `opendatahub-io/odh-dashboard`
- **Location**: `/Dockerfile`
- **Purpose**: Main web interface for ODH platform

### 4. **Model Serving Runtime Images**
Images for serving ML models with different runtimes.

#### **vLLM Runtime Images**
| Runtime | Image Repository | Template Parameter | Source Repository |
|---------|------------------|-------------------|-------------------|
| **vLLM CUDA (NVIDIA)** | `quay.io/opendatahub/vllm-cuda:vX.X.X` | `$(vllm-cuda-image)` | `opendatahub-io/vllm` |
| **vLLM ROCm (AMD)** | `quay.io/opendatahub/vllm-rocm:vX.X.X` | `$(vllm-rocm-image)` | `opendatahub-io/vllm` |
| **vLLM Gaudi (Intel)** | `quay.io/opendatahub/vllm-gaudi:vX.X.X` | `$(vllm-gaudi-image)` | `opendatahub-io/vllm` |
| **vLLM Spyre** | `quay.io/opendatahub/vllm-spyre:vX.X.X` | `$(vllm-spyre-image)` | `opendatahub-io/vllm` |

#### **CAIKIT Runtime Images**
| Runtime | Image Repository | Template Parameter | Source Repository |
|---------|------------------|-------------------|-------------------|
| **CAIKIT TGIS** | `quay.io/opendatahub/caikit-tgis:vX.X.X` | `$(caikit-tgis-image)` | `opendatahub-io/caikit-tgis-serving` |
| **TGIS (Text Generation Inference Server)** | `quay.io/opendatahub/tgis:vX.X.X` | `$(tgis-image)` | `opendatahub-io/tgis-serving` |
| **CAIKIT Standalone** | `quay.io/opendatahub/caikit-standalone:vX.X.X` | `$(caikit-standalone-image)` | `opendatahub-io/caikit-standalone` |

#### **Other Runtime Images**
| Runtime | Image Repository | Template Parameter | Source Repository |
|---------|------------------|-------------------|-------------------|
| **OpenVINO Model Server** | `quay.io/opendatahub/openvino-model-server:vX.X.X` | `$(ovms-image)` | `opendatahub-io/openvino-model-server` |
| **HuggingFace Detector** | `quay.io/opendatahub/guardrails-detector-huggingface:vX.X.X` | `$(guardrails-detector-huggingface-runtime-image)` | `opendatahub-io/guardrails-detector` |

### 5. **ModelMesh Serving Images**
Images for the ModelMesh multi-model serving platform.

| Component | Image Repository | RELATED_IMAGE Parameter | Source Repository |
|-----------|------------------|-------------------------|-------------------|
| **ModelMesh** | `quay.io/opendatahub/modelmesh:vX.X.X` | `RELATED_IMAGE_ODH_MODELMESH_IMAGE` | `opendatahub-io/modelmesh-serving` |
| **ModelMesh Controller** | `quay.io/opendatahub/modelmesh-controller:vX.X.X` | `RELATED_IMAGE_ODH_MODELMESH_CONTROLLER_IMAGE` | `opendatahub-io/modelmesh-serving` |
| **ModelMesh Runtime Adapter** | `quay.io/opendatahub/modelmesh-runtime-adapter:vX.X.X` | `RELATED_IMAGE_ODH_MODELMESH_RUNTIME_ADAPTER_IMAGE` | `opendatahub-io/modelmesh-serving` |
| **ModelMesh REST Proxy** | `quay.io/opendatahub/modelmesh-rest-proxy:vX.X.X` | `RELATED_IMAGE_ODH_MM_REST_PROXY_IMAGE` | `opendatahub-io/modelmesh-serving` |

### 6. **Data Science Pipelines Images**
Images for ML pipeline orchestration and execution.

| Component | Image Repository | RELATED_IMAGE Parameter | Source Repository |
|-----------|------------------|-------------------------|-------------------|
| **API Server** | `quay.io/opendatahub/ds-pipelines-api-server:vX.X.X` | `RELATED_IMAGE_ODH_ML_PIPELINES_API_SERVER_V2_IMAGE` | `opendatahub-io/data-science-pipelines` |
| **Persistence Agent** | `quay.io/opendatahub/ds-pipelines-persistenceagent:vX.X.X` | `RELATED_IMAGE_ODH_ML_PIPELINES_PERSISTENCEAGENT_V2_IMAGE` | `opendatahub-io/data-science-pipelines` |
| **Scheduled Workflow** | `quay.io/opendatahub/ds-pipelines-scheduledworkflow:vX.X.X` | `RELATED_IMAGE_ODH_ML_PIPELINES_SCHEDULEDWORKFLOW_V2_IMAGE` | `opendatahub-io/data-science-pipelines` |
| **Frontend** | `quay.io/opendatahub/ds-pipelines-frontend:vX.X.X` | `RELATED_IMAGE_ODH_DS_PIPELINES_FRONTEND_IMAGE` | `opendatahub-io/data-science-pipelines` |
| **Workflow Controller** | `quay.io/opendatahub/ds-pipelines-argo-workflowcontroller:vX.X.X` | `RELATED_IMAGE_ODH_DATA_SCIENCE_PIPELINES_ARGO_WORKFLOWCONTROLLER_IMAGE` | `opendatahub-io/data-science-pipelines` |
| **Argo Exec** | `quay.io/opendatahub/ds-pipelines-argo-argoexec:vX.X.X` | `RELATED_IMAGE_ODH_DATA_SCIENCE_PIPELINES_ARGO_ARGOEXEC_IMAGE` | `opendatahub-io/data-science-pipelines` |
| **Driver** | `quay.io/opendatahub/ds-pipelines-driver:vX.X.X` | `RELATED_IMAGE_ODH_ML_PIPELINES_DRIVER_IMAGE` | `opendatahub-io/data-science-pipelines` |
| **Launcher** | `quay.io/opendatahub/ds-pipelines-launcher:vX.X.X` | `RELATED_IMAGE_ODH_ML_PIPELINES_LAUNCHER_IMAGE` | `opendatahub-io/data-science-pipelines` |
| **Runtime Generic** | `quay.io/opendatahub/ds-pipelines-runtime-generic:vX.X.X` | `RELATED_IMAGE_ODH_ML_PIPELINES_RUNTIME_GENERIC_IMAGE` | `opendatahub-io/data-science-pipelines` |

### 7. **Notebook Images**
Pre-built notebook environments for data science work.

#### **Jupyter Workbench Images**
| Notebook Type | Image Repository | Source Repository |
|---------------|------------------|-------------------|
| **Minimal CPU** | `quay.io/opendatahub/workbench-images:jupyter-minimal-cpu-py311-ubi9` | `opendatahub-io/notebooks/jupyter/minimal` |
| **DataScience CPU** | `quay.io/opendatahub/workbench-images:jupyter-datascience-cpu-py311-ubi9` | `opendatahub-io/notebooks/jupyter/datascience` |
| **DataScience GPU** | `quay.io/opendatahub/workbench-images:jupyter-datascience-gpu-py311-ubi9` | `opendatahub-io/notebooks/jupyter/datascience` |
| **TensorFlow CPU** | `quay.io/opendatahub/workbench-images:jupyter-tensorflow-cpu-py311-ubi9` | `opendatahub-io/notebooks/jupyter/tensorflow` |
| **TensorFlow GPU** | `quay.io/opendatahub/workbench-images:jupyter-tensorflow-gpu-py311-ubi9` | `opendatahub-io/notebooks/jupyter/tensorflow` |
| **PyTorch CPU** | `quay.io/opendatahub/workbench-images:jupyter-pytorch-cpu-py311-ubi9` | `opendatahub-io/notebooks/jupyter/pytorch` |
| **PyTorch GPU** | `quay.io/opendatahub/workbench-images:jupyter-pytorch-gpu-py311-ubi9` | `opendatahub-io/notebooks/jupyter/pytorch` |
| **TrustyAI CPU** | `quay.io/opendatahub/workbench-images:jupyter-trustyai-cpu-py311-ubi9` | `opendatahub-io/notebooks/jupyter/trustyai` |
| **TensorFlow ROCm** | `quay.io/opendatahub/workbench-images:jupyter-tensorflow-rocm-py311-ubi9` | `opendatahub-io/notebooks/jupyter/tensorflow` |

#### **RStudio Images**
| Notebook Type | Image Repository | Source Repository |
|---------------|------------------|-------------------|
| **RStudio CPU** | `quay.io/opendatahub/workbench-images:rstudio-cpu-py311-ubi9` | `opendatahub-io/notebooks/rstudio` |
| **RStudio GPU** | `quay.io/opendatahub/workbench-images:rstudio-gpu-py311-ubi9` | `opendatahub-io/notebooks/rstudio` |

#### **Code Server Images**
| Notebook Type | Image Repository | Source Repository |
|---------------|------------------|-------------------|
| **Code Server CPU** | `quay.io/opendatahub/workbench-images:code-server-cpu-py311-ubi9` | `opendatahub-io/notebooks/codeserver` |
| **Code Server GPU** | `quay.io/opendatahub/workbench-images:code-server-gpu-py311-ubi9` | `opendatahub-io/notebooks/codeserver` |

### 8. **Feature Store Images**
Images for Feast feature store components.

| Component | Image Repository | RELATED_IMAGE Parameter | Source Repository |
|-----------|------------------|-------------------------|-------------------|
| **Feast Feature Server** | `quay.io/opendatahub/feature-server:vX.X.X` | `RELATED_IMAGE_ODH_FEATURE_SERVER_IMAGE` | `opendatahub-io/feast` |
| **Feast Operator** | `quay.io/opendatahub/feast-operator:vX.X.X` | `RELATED_IMAGE_ODH_FEAST_OPERATOR_IMAGE` | `opendatahub-io/feast/infra/feast-operator` |

### 9. **AI/ML Service Images**
Images for specialized AI/ML services.

| Service | Image Repository | RELATED_IMAGE Parameter | Source Repository |
|---------|------------------|-------------------------|-------------------|
| **TrustyAI Service** | `quay.io/opendatahub/trustyai-service:vX.X.X` | `RELATED_IMAGE_ODH_TRUSTYAI_SERVICE_IMAGE` | `trustyai-explainability/trustyai-service` |
| **Model Registry** | `quay.io/opendatahub/model-registry:vX.X.X` | `RELATED_IMAGE_ODH_MODEL_REGISTRY_IMAGE` | `opendatahub-io/model-registry` |

### 10. **Infrastructure Images**
Images for supporting infrastructure and services.

#### **Database Images**
| Database | Image Repository | Usage |
|----------|------------------|-------|
| **PostgreSQL** | `postgres:16-alpine` | Model Registry, Feast, general database needs |
| **MariaDB** | `registry.redhat.io/rhel8/mariadb-103:1-188` | Data Science Pipelines metadata |
| **Redis** | `quay.io/sclorg/redis-7-c9s` | Feature store online storage |
| **MySQL** | `mysql:8.3.0` | Alternative database for various services |

#### **Storage Images**
| Storage | Image Repository | Usage |
|---------|------------------|-------|
| **MinIO** | `quay.io/opendatahub/minio:RELEASE.2019-08-14T20-37-41Z-license-compliance` | S3-compatible object storage |

#### **Metadata and ML Infrastructure**
| Component | Image Repository | RELATED_IMAGE Parameter | Usage |
|-----------|------------------|-------------------------|-------|
| **ML Metadata GRPC** | `quay.io/opendatahub/ds-pipelines-metadata-grpc:vX.X.X` | `RELATED_IMAGE_ODH_MLMD_GRPC_SERVER_IMAGE` | ML metadata management |
| **ML Metadata Envoy** | `quay.io/opendatahub/ds-pipelines-metadata-envoy:vX.X.X` | `RELATED_IMAGE_DSP_PROXYV2_IMAGE` | Metadata service proxy |
| **OAuth Proxy** | `registry.redhat.io/openshift4/ose-oauth-proxy:vX.X` | `RELATED_IMAGE_OSE_OAUTH_PROXY_IMAGE` | Authentication proxy |

### 11. **Sidecar Container Images**
Images used as sidecar containers for authentication, networking, and monitoring.

#### **OAuth Authentication Sidecars**
| Sidecar | Image Repository | RELATED_IMAGE Parameter | Usage |
|---------|------------------|-------------------------|-------|
| **OAuth Proxy** | `registry.redhat.io/openshift4/ose-oauth-proxy:vX.X` | `RELATED_IMAGE_OSE_OAUTH_PROXY_IMAGE` | OpenShift OAuth authentication proxy |

**Where OAuth Proxy Sidecars are Used:**
- **Notebook Containers**: Every Jupyter notebook gets an OAuth proxy sidecar for authentication
- **Data Science Pipelines**: API server, UI, and metadata services have OAuth proxy sidecars
- **Model Serving**: ModelMesh serving runtimes include OAuth proxy sidecars
- **Monitoring**: Prometheus and Alertmanager have OAuth proxy sidecars
- **TrustyAI Service**: Includes OAuth proxy sidecar for secure access
- **Model Registry**: Uses OAuth proxy for authentication
- **Dashboard**: Protected by OAuth proxy sidecar

#### **Istio Service Mesh Sidecars**
| Sidecar | Image Repository | Usage |
|---------|------------------|-------|
| **Istio Proxy (Envoy)** | `Automatically injected by Istio` | Service mesh proxy for mTLS, traffic management, and observability |

**Istio Sidecar Injection Control:**
```yaml
# Enable Istio sidecar injection
annotations:
  sidecar.istio.io/inject: "true"
  sidecar.istio.io/rewriteAppHTTPProbers: "true"

# Disable Istio sidecar injection
annotations:
  sidecar.istio.io/inject: "false"
```

**Where Istio Sidecars are Used:**
- **KServe Model Serving**: InferenceService pods automatically get Istio sidecars when ServiceMesh is enabled
- **TrustyAI Service**: Uses Istio sidecars for secure communication
- **Model Serving Runtime Pods**: All model serving pods in Serverless mode get Istio sidecars
- **Authorino**: Authorization service can be injected with Istio sidecars

**Where Istio Sidecars are Explicitly Disabled:**
- **Data Science Pipelines**: ML metadata services disable Istio injection
- **Training Jobs**: PyTorch and other training workloads disable Istio injection
- **Database Pods**: PostgreSQL, MariaDB, and Redis disable Istio injection
- **KServe Controller**: The controller itself disables Istio injection
- **Performance Testing**: Benchmark workloads disable Istio injection

#### **Envoy Proxy Sidecars**
| Sidecar | Image Repository | Usage |
|---------|------------------|-------|
| **ML Metadata Envoy** | `quay.io/opendatahub/ds-pipelines-metadata-envoy:vX.X.X` | Proxy for ML metadata services in Data Science Pipelines |

**Multi-Container Model Serving Examples:**

**CAIKIT + TGIS Runtime (2 main containers):**
```yaml
containers:
  - name: kserve-container  # TGIS inference engine
    image: $(tgis-image)
  - name: transformer-container  # CAIKIT framework
    image: $(caikit-tgis-image)
```

**vLLM Multi-node (2 main containers + sidecars):**
```yaml
containers:
  - name: vllm-launcher  # Head node
    image: $(vllm-cuda-image)
  - name: vllm-worker    # Worker node
    image: $(vllm-cuda-image)
```

#### **Monitoring Sidecars**
Complex monitoring deployments use multiple containers and sidecars:

**Prometheus Deployment (4-container setup):**
| Container | Image Repository | Purpose |
|-----------|------------------|---------|
| **prometheus-proxy** | `registry.redhat.io/openshift4/ose-oauth-proxy:vX.X` | OAuth proxy for Prometheus UI access |
| **prometheus** | `registry.redhat.io/openshift4/ose-prometheus:vX.X` | Main Prometheus monitoring service |
| **alertmanager-proxy** | `registry.redhat.io/openshift4/ose-oauth-proxy:vX.X` | OAuth proxy for Alertmanager UI access |
| **alertmanager** | `registry.redhat.io/openshift4/ose-prometheus-alertmanager:vX.X` | Alertmanager notification service |

**Data Science Pipelines ML Metadata (2-container setup):**
| Container | Image Repository | Purpose |
|-----------|------------------|---------|
| **envoy-proxy** | `quay.io/opendatahub/ds-pipelines-metadata-envoy:vX.X` | Envoy proxy for metadata service |
| **oauth-proxy** | `registry.redhat.io/openshift4/ose-oauth-proxy:vX.X` | OAuth authentication proxy |

### **Sidecar Injection Patterns**

#### **1. Automatic Injection (Istio)**
Istio sidecars are automatically injected when:
- Namespace has `istio-injection=enabled` label
- Pod has `sidecar.istio.io/inject: "true"` annotation
- ServiceMesh is configured in DSCI

#### **2. Manual Injection (OAuth Proxy)**
OAuth proxy sidecars are manually added by controllers:
- **Notebook Controller**: Adds OAuth proxy to every notebook pod
- **Data Science Pipelines Controller**: Adds OAuth proxy to API servers and UI
- **ModelMesh Controller**: Adds OAuth proxy to serving runtime pods
- **TrustyAI Controller**: Adds OAuth proxy to TrustyAI service pods

#### **3. Template-Based Injection (Multi-Container Runtimes)**
Model serving runtimes use templates to define multiple containers:
- **CAIKIT-TGIS**: Two cooperating containers for LLM serving
- **vLLM Multi-node**: Distributed inference across multiple containers
- **ML Metadata**: Envoy proxy + OAuth proxy for metadata services

### **Sidecar Configuration Examples**

#### **Jupyter Notebook with OAuth Proxy Sidecar:**
```yaml
containers:
  - name: jupyter-nb-user
    image: "workbench-image:latest"
    ports:
      - containerPort: 8888
  - name: oauth-proxy
    image: "registry.redhat.io/openshift4/ose-oauth-proxy:v4.10"
    args:
      - --provider=openshift
      - --https-address=:8443
      - --upstream=http://localhost:8888
    ports:
      - containerPort: 8443
        name: oauth-proxy
```

#### **InferenceService with Istio Sidecar (Automatic):**
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    sidecar.istio.io/inject: "true"
    sidecar.istio.io/rewriteAppHTTPProbers: "true"
spec:
  predictor:
    model:
      modelFormat:
        name: pytorch
# Istio automatically injects envoy proxy sidecar
```

### 12. **Utility Images**
Images for utility and operational tasks.

| Utility | Image Repository | Usage |
|---------|------------------|-------|
| **OpenShift CLI** | `quay.io/openshift/origin-cli:4.17` | CLI operations and automation |
| **Alpine** | `quay.io/rhoai-konflux/alpine:latest` | Lightweight utility operations |
| **Toolbox** | `quay.io/opendatahub/ds-pipelines-toolbox:vX.X.X` | Pipeline utilities and tools |

## Image Parameter Mapping System

The OpenDataHub operator uses a sophisticated parameter mapping system to inject the correct images into deployed resources:

### Component-Level Mappings

Each component controller defines its own `imageParamMap` that maps template parameters to RELATED_IMAGE environment variables:

```go
// Example from ModelController
var imageParamMap = map[string]string{
    "odh-model-controller": "RELATED_IMAGE_ODH_MODEL_CONTROLLER_IMAGE",
}

// Example from DataSciencePipelines
var imageParamMap = map[string]string{
    "IMAGES_DSPO": "RELATED_IMAGE_ODH_DATA_SCIENCE_PIPELINES_OPERATOR_CONTROLLER_IMAGE",
    "IMAGES_APISERVER": "RELATED_IMAGE_ODH_ML_PIPELINES_API_SERVER_V2_IMAGE",
    "IMAGES_PERSISTENCEAGENT": "RELATED_IMAGE_ODH_ML_PIPELINES_PERSISTENCEAGENT_V2_IMAGE",
    // ... more mappings
}
```

### Template Parameter Substitution

Runtime templates use parameter substitution syntax:

```yaml
# Example from vLLM CUDA template
containers:
  - name: kserve-container
    image: $(vllm-cuda-image)  # Replaced with actual image during deployment
```

### Environment Variable Resolution

The operator resolves RELATED_IMAGE environment variables at runtime:

1. **Environment Variables** are set in the operator deployment
2. **Parameter Mapping** links template parameters to environment variables
3. **Template Processing** substitutes actual image values
4. **Resource Deployment** creates resources with resolved image references

## Image Repositories by Organization

### OpenDataHub Core (`opendatahub-io/*`)
- **Primary Registry**: `quay.io/opendatahub/*`
- **Repositories**: 15+ repositories containing operators, controllers, and runtimes
- **Purpose**: Core ODH platform components

### Red Hat Images (`registry.redhat.io/*`)
- **Primary Registry**: `registry.redhat.io/*`
- **Images**: OAuth proxy, CLI tools, base images
- **Purpose**: Red Hat enterprise components

### Upstream Dependencies
- **PostgreSQL**: `postgres:*` (Docker Hub)
- **MariaDB**: `registry.redhat.io/rhel8/mariadb-103:*`
- **Redis**: `quay.io/sclorg/redis-7-c9s`
- **MinIO**: `quay.io/opendatahub/minio:*`

### Third-Party ML Infrastructure
- **ML Metadata**: `gcr.io/tfx-oss-public/ml_metadata_store_server:*`
- **Kubeflow Components**: Various `gcr.io/ml-pipeline/*` images
- **TrustyAI**: `trustyai-explainability/*` organization

## Image Build and Distribution

### Build Process
1. **Source Code** in component repositories
2. **Dockerfiles** define build contexts
3. **Tekton Pipelines** (.tekton/ directories) build images
4. **Quay.io** hosts the built images
5. **Operator** references images via RELATED_IMAGE parameters

### Version Management
- **Semantic Versioning**: Most images use semantic versioning (vX.Y.Z)
- **Branch-Based Tags**: Some images use branch names (main, dev, etc.)
- **SHA-Based Tags**: Some images use SHA hashes for immutable references

### Security and Scanning
- **Vulnerability Scanning**: All images undergo security scanning
- **Base Image Updates**: Regular updates to base images (UBI, Alpine)
- **Compliance**: Images meet enterprise security requirements

## Sidecar Architecture Impact

### **Security and Authentication**
The extensive use of OAuth proxy sidecars provides:
- **Unified Authentication**: All services use OpenShift OAuth for consistent access control
- **Zero-Trust Architecture**: Every component requires authentication
- **Session Management**: Centralized session handling across all ODH services
- **RBAC Integration**: Fine-grained access control using OpenShift RBAC

### **Service Mesh Integration**
Istio sidecars enable:
- **mTLS Encryption**: Automatic encryption between all mesh services
- **Traffic Management**: Sophisticated routing, load balancing, and failover
- **Observability**: Distributed tracing and metrics collection
- **Security Policies**: Network-level security enforcement

### **Resource Overhead**
Each sidecar adds resource overhead:
- **OAuth Proxy**: ~100m CPU, ~64-256Mi memory per pod
- **Istio Proxy**: ~100m CPU, ~128Mi memory per pod
- **Monitoring Proxies**: Variable based on traffic and configuration

### **Network Architecture**
```
[User] → [OAuth Proxy] → [Istio Proxy] → [Application Container]
   ↓            ↓              ↓              ↓
[HTTPS]    [Auth Check]   [mTLS + Routing]  [HTTP]
```

## Usage Examples

### Finding Image Information
```bash
# Check RELATED_IMAGE environment variables in operator
oc get deployment opendatahub-operator-controller-manager -o yaml | grep RELATED_IMAGE

# Check image parameters in component manifests
oc get servingruntime vllm-cuda-runtime -o yaml | grep image

# Check sidecar configurations in notebook pods
oc get notebook -o yaml | grep -A 5 -B 5 oauth-proxy

# Check Istio sidecar injection status
oc get pods -o jsonpath='{.items[*].metadata.annotations.sidecar\.istio\.io/status}'
```

### Customizing Images
```bash
# Override images via environment variables
oc set env deployment/opendatahub-operator-controller-manager \
  RELATED_IMAGE_ODH_DASHBOARD_IMAGE=quay.io/myorg/custom-dashboard:v1.0.0

# Override OAuth proxy image globally
oc set env deployment/opendatahub-operator-controller-manager \
  RELATED_IMAGE_OSE_OAUTH_PROXY_IMAGE=registry.redhat.io/openshift4/ose-oauth-proxy:v4.15

# Disable Istio injection for specific deployment
oc patch deployment my-deployment -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"false"}}}}}'
```

### Troubleshooting Sidecars
```bash
# Check OAuth proxy logs
oc logs <pod-name> -c oauth-proxy

# Check Istio proxy logs
oc logs <pod-name> -c istio-proxy

# Check sidecar resource usage
oc top pod <pod-name> --containers

# Debug OAuth proxy configuration
oc exec <pod-name> -c oauth-proxy -- cat /etc/proxy/secrets/session_secret
```

## References

- [OpenDataHub Operator Image Support](./src/opendatahub-operator/pkg/deploy/envParams.go)
- [Component Image Mappings](./src/opendatahub-operator/internal/controller/components/*/support.go)
- [Runtime Templates](./src/odh-model-controller/config/runtimes/)
- [Notebook Images](./src/notebooks/)
- [Build Pipelines](./src/*/tekton/)
- [Quay.io OpenDataHub Organization](https://quay.io/organization/opendatahub) 