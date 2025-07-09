# Open Data Hub Projects Overview

This workspace contains two related but distinct projects that work together to provide notebook management capabilities in the Open Data Hub (ODH) ecosystem.

## Terminology

### Notebook
A **notebook** refers to an individual Jupyter notebook instance - a running containerized environment where data scientists can execute code, create visualizations, and develop models. In Kubernetes terms:
- Managed by a `Notebook` custom resource
- Deployed as a StatefulSet with persistent storage
- Accessible via a web interface through a Service
- Can be automatically culled when idle to save resources

### Workbench  
A **workbench** is a higher-level concept that encompasses the entire notebook management infrastructure and capabilities. In the ODH context:
- Represents the complete notebook ecosystem (controllers, images, configurations)
- Managed by the "workbenches" controller in opendatahub-operator
- Includes both the ODH and Kubeflow notebook controllers
- Provides the platform capabilities that enable users to create and manage notebooks
- Think of it as the "notebook service" that makes individual notebooks possible

**Analogy**: If a notebook is like a single running application, then a workbench is like the entire application platform that hosts and manages those applications.

## ODH Platform Components

The Open Data Hub platform consists of 16 discrete components, each serving specific roles in the data science workflow:

### **Workbenches & Notebooks**

#### **KF Notebook Controller**
The original Kubeflow notebook controller that manages individual Jupyter notebook instances. Handles basic notebook lifecycle operations like creation, deletion, and resource management.

#### **ODH Notebook Controller** 
Enhanced version of the notebook controller with OAuth integration, improved security, and ODH-specific features. Provides seamless authentication and authorization for notebook access.

#### **Notebooks**
Pre-built notebook images and configurations containing popular data science tools, libraries, and frameworks. Provides ready-to-use environments for different types of data science work.

### **Dashboard & UI**

#### **Dashboard**
Central web interface for the Open Data Hub platform. Provides a unified view of all available services, enables easy navigation between components, and offers administration capabilities.

### **Model Serving & Management**

#### **ModelMesh Serving**
High-performance model serving platform optimized for serving multiple models efficiently. Provides intelligent model placement, auto-scaling, and resource optimization for production model deployments.

#### **KServe**
Kubernetes-native model serving platform that provides serverless inferencing for machine learning models. Supports multiple ML frameworks and provides features like auto-scaling, canary deployments, and traffic splitting.

#### **Model Registry**
Centralized repository for managing machine learning model metadata, versions, and lifecycle. Provides model versioning, lineage tracking, and governance capabilities.

#### **Model Controller**
Manages the deployment and lifecycle of models in the ODH platform. Orchestrates model serving infrastructure and handles model deployment workflows.

### **Distributed Computing & Job Management**

#### **CodeFlare**
Distributed computing framework for running machine learning workloads at scale. Provides job scheduling, resource management, and distributed training capabilities.

#### **Ray**
Distributed computing framework that simplifies the deployment of distributed applications. Enables parallel processing, distributed training, and hyperparameter tuning.

#### **Kueue**
Job queueing system for Kubernetes that manages resource allocation and job scheduling. Provides fair sharing, priority-based scheduling, and resource quotas.

#### **Training Operator**
Kubernetes operator for managing distributed machine learning training jobs. Supports various ML frameworks like TensorFlow, PyTorch, and MPI for distributed training.

### **Data Pipelines & Processing**

#### **Data Science Pipelines**
Pipeline orchestration platform for end-to-end MLOps workflows. Provides pipeline authoring, scheduling, and monitoring capabilities with support for Kubeflow Pipelines SDK and Argo Workflows.

#### **Feast Operator**
Manages Feast feature stores for machine learning feature management. Provides feature versioning, serving, and discovery capabilities for ML feature engineering.

### **AI/ML Specialized Services**

#### **TrustyAI**
Explainable AI service that provides model interpretability and fairness analysis. Offers insights into model decisions, bias detection, and compliance reporting.

#### **Llama Stack Operator**
Manages deployment and scaling of Large Language Models (LLMs) using the Llama Stack framework. Provides LLM serving capabilities optimized for inference and fine-tuning workflows.

## Project Relationship

### kubeflow/ - Component Source Repository
- **ODH's fork** of the upstream Kubeflow project
- Contains the source code for notebook controllers used by ODH
- Provides two notebook controller implementations:
  - `components/notebook-controller/` - Original Kubeflow notebook controller
  - `components/odh-notebook-controller/` - ODH's enhanced version with OAuth support
- Serves as the **source of truth** for notebook-related components

### opendatahub-operator/ - Integration & Orchestration
- **Primary operator** for Open Data Hub
- Responsible for deploying and managing ODH components including notebook controllers
- Uses a **"workbenches" controller** that deploys both notebook controllers from the kubeflow repository
- Acts as the **integration point** for all ODH component manifests

## Dependency Architecture

The projects have a hierarchical dependency relationship:

```
opendatahub-operator (workbenches controller)
    ↓ fetches manifests from
kubeflow (notebook controllers)
    ↓ rebases from  
upstream kubeflow/kubeflow
```

## Integration Mechanisms

### 1. Manifest Fetching
The `opendatahub-operator/get_all_manifests.sh` script automatically fetches manifests from **16 different component repositories** to create a comprehensive data science platform:

#### **Workbenches & Notebooks**
```bash
["workbenches/kf-notebook-controller"]="opendatahub-io:kubeflow:main:components/notebook-controller/config"
["workbenches/odh-notebook-controller"]="opendatahub-io:kubeflow:main:components/odh-notebook-controller/config"
["workbenches/notebooks"]="opendatahub-io:notebooks:main:manifests"
```

#### **Dashboard & UI**
```bash
["dashboard"]="opendatahub-io:odh-dashboard:main:manifests"
```

#### **Model Serving & Management**
```bash
["modelmeshserving"]="opendatahub-io:modelmesh-serving:release-0.12.0-rc0:config"
["kserve"]="opendatahub-io:kserve:release-v0.15:config"
["modelregistry"]="opendatahub-io:model-registry-operator:main:config"
["modelcontroller"]="opendatahub-io:odh-model-controller:incubating:config"
```

### **Model Serving Platform Comparison**

The ODH platform includes three distinct model serving approaches, each optimized for different use cases:

#### **🦙 Llama Stack Operator + llamastack**
**Purpose**: Specialized for Large Language Models (LLMs), particularly Meta's Llama model family
- **Agent-centric architecture** designed for building intelligent, multi-step AI applications
- **Mixture of Experts (MoE) architecture** optimization for efficient LLM inference
- **Native multimodality** with early fusion of text, image, and video processing
- **Extended context windows** (up to 10 million tokens in Llama 4 Scout)
- **Built-in agent capabilities** for autonomous multi-step reasoning
- **Integrated safety guardrails** and content moderation
- **Best for**: Conversational AI agents, multi-step reasoning applications, creative writing, specialized LLM workloads requiring agent-based behavior

#### **🕸️ ModelMesh Serving**
**Purpose**: High-performance model serving platform optimized for efficiently serving multiple models simultaneously
- **Model mesh architecture** that dynamically places models across nodes
- **Efficient resource sharing** between multiple models
- **Automatic model loading/unloading** based on demand
- **Built-in model routing** and load balancing
- **Optimized for high throughput** and multi-tenancy
- **Multi-framework support** with focus on operational efficiency
- **Best for**: Organizations serving many different models simultaneously, multi-tenant environments, efficient resource utilization across diverse model types

#### **⚡ KServe**
**Purpose**: Serverless inference platform built on Kubernetes with auto-scaling capabilities
- **Serverless auto-scaling** - scales to zero when not in use
- **Framework-agnostic** approach supporting TensorFlow, PyTorch, Scikit-learn, XGBoost, and more
- **Canary deployments** and A/B testing support
- **Traffic splitting** for gradual rollouts
- **Multiple deployment modes** (Serverless via Knative, Raw Kubernetes deployments)
- **Integrated with Istio** for advanced networking and security
- **Standardized APIs** with OpenAPI compatibility
- **Best for**: Production ML deployments requiring auto-scaling, canary deployments, cost-sensitive deployments benefiting from scale-to-zero

#### **Decision Matrix**

| **Aspect** | **Llama Stack** | **ModelMesh** | **KServe** |
|------------|-----------------|---------------|------------|
| **Specialization** | LLM-focused, agent-centric | Multi-model efficiency | Framework-agnostic, serverless |
| **Architecture** | MoE-optimized, multimodal | Model mesh with intelligent placement | Serverless with auto-scaling |
| **Primary Use** | Conversational AI, agents | Multi-tenant model serving | Production ML deployments |
| **Scaling** | Efficient LLM inference | Resource optimization across models | Auto-scaling, scale-to-zero |
| **Deployment** | Specialized for Llama models | Multi-model placement | Flexible deployment modes |
| **Context** | Extended context windows | Efficient multi-model serving | Standard ML serving patterns |

**When to Choose Which?**
- **Choose Llama Stack** when building LLM-powered applications requiring agent behavior, extended context, or multimodal capabilities
- **Choose ModelMesh** when you need to serve multiple different models efficiently with intelligent resource management  
- **Choose KServe** when you need a production-ready, framework-agnostic serving platform with auto-scaling and advanced deployment features

#### **Distributed Computing & Job Management**
```bash
["codeflare"]="opendatahub-io:codeflare-operator:main:config"
["ray"]="opendatahub-io:kuberay:dev:ray-operator/config"
["kueue"]="opendatahub-io:kueue:dev:config"
["trainingoperator"]="opendatahub-io:training-operator:dev:manifests"
```

#### **Data Pipelines & Processing**
```bash
["datasciencepipelines"]="opendatahub-io:data-science-pipelines-operator:main:config"
["feastoperator"]="opendatahub-io:feast:stable:infra/feast-operator/config"
```

#### **AI/ML Specialized Services**
```bash
["trustyai"]="trustyai-explainability:trustyai-service-operator:main:config"
["llamastackoperator"]="opendatahub-io:llama-stack-k8s-operator:odh:config"
```

The opendatahub-operator acts as a **manifest aggregator** that fetches configuration from these diverse component repositories and integrates them into a unified deployment through the DataScienceCluster API.

#### **Component Types**
The fetched manifests represent different types of components, not just operators:

**🔧 Operators** (Kubernetes operators that manage custom resources):
- `codeflare-operator` - Distributed computing job management
- `training-operator` - ML training job orchestration  
- `data-science-pipelines-operator` - Pipeline workflow management
- `model-registry-operator` - Model metadata and lifecycle management
- `trustyai-service-operator` - AI explainability service management
- `feast-operator` - Feature store management
- `llama-stack-k8s-operator` - LLM deployment management

**🎮 Controllers** (Kubernetes controllers that manage specific resources):
- `kf-notebook-controller` - Jupyter notebook lifecycle management
- `odh-notebook-controller` - Enhanced notebook controller with OAuth
- `odh-model-controller` - Model deployment orchestration

**📱 Applications** (Web applications and user interfaces):
- `odh-dashboard` - Central web interface and navigation

**⚙️ Infrastructure Components** (Kubernetes-native services):
- `modelmesh-serving` - High-performance model serving platform
- `kserve` - Serverless model inference platform
- `kueue` - Job queueing and resource management
- `kuberay` - Ray distributed computing framework

**🖼️ Images & Configurations** (Container images and deployment configurations):
- `notebooks` - Pre-built notebook images and environments

Each component type is deployed and managed differently by the opendatahub-operator, but all are orchestrated through the unified DataScienceCluster API.

### 2. Workbenches Controller
The workbenches controller in opendatahub-operator:
- Deploys **both** notebook controllers from the kubeflow repository
- Manages the infrastructure and configuration needed for notebook controllers to operate
- Handles component-level concerns (installation, configuration, status reporting)

### 3. No Direct Code Dependencies
- Neither project has direct Go module dependencies on each other
- Integration occurs through **manifest consumption** and **runtime deployment**
- This allows for independent development and versioning of each component

## Functional Roles

### kubeflow/notebook-controller
**Purpose**: Individual notebook instance management
- Manages `Notebook` custom resources
- Creates StatefulSets and Services for Jupyter notebooks
- Handles notebook lifecycle (creation, deletion, updates)
- Implements notebook culling for idle instances
- Focuses on **application-level concerns**

### opendatahub-operator/workbenches controller
**Purpose**: System-level orchestration
- Manages the **deployment of notebook controllers themselves**
- Handles component installation, configuration, and status
- Provides unified API through DataScienceCluster CRD
- Manages dependencies and integration with other ODH components
- Focuses on **infrastructure-level concerns**

## Development Workflow

### kubeflow Repository
1. **Upstream Synchronization**: Automatically rebases from upstream Kubeflow via Pull GitHub App
2. **Component Development**: Develops and maintains notebook controller implementations
3. **Release Management**: Publishes container images and configuration manifests
4. **Integration Testing**: Tests notebook controller functionality

### opendatahub-operator Repository
1. **Manifest Integration**: Fetches latest manifests from kubeflow repository
2. **Operator Development**: Develops workbenches controller and other component controllers
3. **System Integration**: Ensures all ODH components work together
4. **End-to-End Testing**: Tests complete ODH deployment scenarios

## Key Files and Directories

### kubeflow/
- `components/notebook-controller/` - Original Kubeflow notebook controller
- `components/odh-notebook-controller/` - ODH-enhanced notebook controller with OAuth
- `REBASE.md` - Instructions for rebasing from upstream
- `DEPENDENCIES.md` - Dependency management guidelines

### opendatahub-operator/
- `internal/controller/components/workbenches/` - Workbenches controller implementation
- `get_all_manifests.sh` - Script to fetch component manifests
- `api/datasciencecluster/v1/` - DataScienceCluster CRD definition
- `docs/COMPONENT_INTEGRATION.md` - Component integration guidelines

## Architectural Pattern

This follows a common Kubernetes operator pattern:
- **Lower-level controllers** (notebook-controller) manage application instances
- **Higher-level operators** (opendatahub-operator) manage the deployment and configuration of those controllers
- The **workbenches controller** acts as a "controller of controllers"

## Getting Started

### For Notebook Controller Development
```bash
cd kubeflow/components/notebook-controller
make run
```

### For ODH Operator Development
```bash
cd opendatahub-operator
make get-manifests  # Fetches latest manifests from kubeflow
make run
```

## Monitoring and Observability

Both projects include comprehensive monitoring:
- **Prometheus metrics** for notebook controller performance
- **Alerting rules** for operational issues
- **Status reporting** through Kubernetes custom resource status fields

## Contributing

- **kubeflow/**: Follow Kubeflow community guidelines and ODH-specific requirements
- **opendatahub-operator/**: Follow ODH operator development guidelines and component integration patterns

For detailed contribution guidelines, see the respective CONTRIBUTING.md files in each project. 