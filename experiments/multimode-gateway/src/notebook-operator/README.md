# Notebook Operator

A Kubernetes operator that manages Jupyter notebook instances and automatically integrates them with the ODH Gateway for centralized access and authentication.

## Overview

The Notebook Operator simplifies the deployment and management of Jupyter notebooks in Kubernetes by:

- **Automated Deployment**: Creates notebook pods and services from simple custom resources
- **Gateway Integration**: Automatically annotates services for ODH Gateway discovery
- **Routing Configuration**: Sets up proper base URLs and paths for notebook access
- **Resource Management**: Handles persistent storage, resource limits, and container configuration
- **Service Discovery**: Makes notebooks discoverable through the centralized gateway

## How It Works

When you create a `Notebook` custom resource, the operator:

1. **Creates a Pod** running the specified Jupyter notebook image
2. **Configures the Notebook** with proper base URL and authentication settings
3. **Creates a Service** to expose the notebook pod
4. **Adds Annotations** to the service for ODH Gateway discovery (`odhgateway.opendatahub.io/enabled: "true"`)
5. **Sets up Routing** by defining the route path in service annotations

The ODH Gateway Operator automatically discovers these annotated services and updates the gateway's routing configuration, making the notebooks accessible through the centralized gateway with authentication.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Notebook CR   │──▶│  Notebook       │──▶│   Jupyter       │
│   (User Input)  │    │  Operator       │    │   Pod + Svc     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                         │
                              ▼                         ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │  Service        │    │  ODH Gateway    │
                       │  Annotations    │──▶│  Discovery      │
                       │  (Gateway Tags) │    │  (Auto-routing) │
                       └─────────────────┘    └─────────────────┘
```

## Notebook Custom Resource

### API Reference

The `Notebook` custom resource uses the API group `ds.example.com/v1alpha1` and supports the following specification:

```yaml
apiVersion: ds.example.com/v1alpha1
kind: Notebook
metadata:
  name: my-notebook
  namespace: notebooks
spec:
  # Required: Jupyter notebook image to run
  image: "jupyter/scipy-notebook:latest"
  
  # Optional: Port the notebook server runs on (default: 8888)
  port: 8888
  
  # Optional: Name of PVC for persistent storage
  pvcName: "my-notebook-storage"
  
  # Optional: Resource requirements
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image` | string | Yes | Container image for the Jupyter notebook (e.g., `jupyter/scipy-notebook:latest`) |
| `port` | int32 | No | Port number for the notebook server (default: 8888) |
| `pvcName` | string | No | Name of a PersistentVolumeClaim for notebook storage |
| `resources` | ResourceRequirements | No | CPU and memory requests/limits for the notebook pod |

### Status Fields

The operator updates the notebook status with:

| Field | Description |
|-------|-------------|
| `podName` | Name of the created pod |
| `phase` | Current phase of the notebook (Creating, Running, Failed, etc.) |

## Examples

### Basic Notebook

```yaml
apiVersion: ds.example.com/v1alpha1
kind: Notebook
metadata:
  name: data-science-notebook
  namespace: user-workspaces
spec:
  image: "jupyter/datascience-notebook:latest"
```

This creates a basic data science notebook accessible at `/notebooks/data-science-notebook` through the ODH Gateway.

### Notebook with Persistent Storage

```yaml
apiVersion: ds.example.com/v1alpha1
kind: Notebook
metadata:
  name: research-notebook
  namespace: research-team
spec:
  image: "jupyter/tensorflow-notebook:latest"
  pvcName: "research-data"
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
```

### Custom Port Configuration

```yaml
apiVersion: ds.example.com/v1alpha1
kind: Notebook
metadata:
  name: custom-notebook
  namespace: default
spec:
  image: "my-registry/custom-jupyter:v1.0"
  port: 9999
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
```

## Automatic Gateway Integration

When the operator creates a notebook, it automatically adds the following annotations to the service:

```yaml
annotations:
  odhgateway.opendatahub.io/enabled: "true"
  odhgateway.opendatahub.io/route-path: "/notebooks/<notebook-name>"
```

This makes the notebook discoverable by the ODH Gateway Operator, which will:
1. Add the notebook to the gateway's routing configuration
2. Make it accessible through the centralized gateway
3. Apply authentication policies based on the gateway configuration

## Notebook Configuration

The operator automatically configures notebooks with:

- **Base URL**: Set to `/notebooks/<notebook-name>` for proper routing through the gateway
- **Authentication**: Disabled token/password authentication (handled by gateway)
- **Port Binding**: Configured to listen on the specified port
- **Service Labels**: Added for proper pod selection

## Development

### Prerequisites

- Go 1.23.0+
- Docker 17.03+
- kubectl v1.11.3+
- Access to a Kubernetes v1.11.3+ cluster

### Building and Running

1. **Install CRDs**:
```bash
make install
```

2. **Run locally** (against configured cluster):
```bash
make run
```

3. **Build and deploy**:
```bash
make docker-build docker-push IMG=<registry>/notebook-operator:tag
make deploy IMG=<registry>/notebook-operator:tag
```

### Testing

Create a test notebook:

```bash
kubectl apply -f - <<EOF
apiVersion: ds.example.com/v1alpha1
kind: Notebook
metadata:
  name: test-notebook
  namespace: default
spec:
  image: "jupyter/minimal-notebook:latest"
EOF
```

Check the created resources:

```bash
# Check the notebook status
kubectl get notebooks

# Check the created pod
kubectl get pods -l notebook=test-notebook

# Check the service and its annotations
kubectl get svc test-notebook-svc -o yaml
```

## Monitoring and Troubleshooting

### Check Notebook Status

```bash
kubectl get notebooks -A
kubectl describe notebook <notebook-name>
```

### View Operator Logs

```bash
kubectl logs -n notebook-operator-system deployment/notebook-operator-controller-manager
```

### Common Issues

1. **Pod Not Starting**: Check image name and resource availability
2. **Service Not Discovered**: Verify annotations are present on the service
3. **Gateway Routing Issues**: Ensure ODH Gateway Operator is running and watching the correct namespaces

## Integration with ODH Gateway

This operator is designed to work with the ODH Gateway system:

1. **ODH Gateway Operator** watches for services with `odhgateway.opendatahub.io/enabled: "true"`
2. **Notebook Operator** automatically adds these annotations when creating services
3. **ODH Gateway** provides centralized authentication and routing for all notebooks

See the main project README for complete setup instructions.

## License

Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

