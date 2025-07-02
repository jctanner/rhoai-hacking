# ODH Multimode Gateway Experiment

This repository contains three interconnected Kubernetes operators and services designed to provide a centralized gateway for Open Data Hub (ODH) workloads:

1. **ODH Gateway** - A reverse proxy service that can operate in OIDC or OpenShift OAuth mode
2. **ODH Gateway Operator** - Kubernetes operator that manages ODH Gateway deployments and discovers services
3. **Notebook Operator** - Kubernetes operator that manages Jupyter notebook instances and automatically registers them with the gateway

## Architecture Overview

The system works by having the ODH Gateway Operator watch for services across the cluster that have specific annotations. When it finds annotated services, it automatically updates the gateway's routing configuration. The Notebook Operator creates notebook pods and services with the appropriate annotations for automatic discovery.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Users/Clients │──▶│   ODH Gateway   │──▶│   Backend       │
│                 │    │   (Reverse      │    │   Services      │
│                 │    │    Proxy)       │    │   (Notebooks,   │
└─────────────────┘    └─────────────────┘    │    etc.)        │
                              │                └─────────────────┘
                              ▼
                       ┌─────────────────┐
                       │  ODH Gateway    │
                       │  Operator       │
                       │  (Service       │
                       │   Discovery)    │
                       └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  Notebook       │
                       │  Operator       │
                       │  (Creates       │
                       │   Notebooks)    │
                       └─────────────────┘
```

## Projects

### 1. ODH Gateway (`src/odh-gateway/`)

A lightweight, configurable reverse proxy with the following features:
- **Dynamic Routing**: Routes requests based on URL path prefixes
- **Authentication**: Supports OIDC and OpenShift OAuth
- **Hot Reload**: Automatically reloads configuration changes
- **Kubernetes Integration**: Works with ConfigMaps for configuration

### 2. ODH Gateway Operator (`src/odh-gateway-operator/`)

A Kubernetes operator that:
- Manages ODH Gateway deployments based on `ODHGateway` custom resources
- Automatically discovers services with specific annotations
- Updates gateway routing configuration dynamically
- Handles TLS configuration and external routes

### 3. Notebook Operator (`src/notebook-operator/`)

A Kubernetes operator that:
- Creates and manages Jupyter notebook pods from `Notebook` custom resources
- Automatically creates services for notebook access
- Annotates services for ODH Gateway discovery
- Configures notebook base URLs for proper routing

## Quick Start

### Prerequisites
- Kubernetes cluster with administrative access
- Go 1.19+ for building from source
- kubectl configured to access your cluster

### Building and Running

1. **Build and deploy the ODH Gateway Operator:**
```bash
cd src/odh-gateway-operator
make manifests generate install run
```

2. **Build and deploy the Notebook Operator:**
```bash
cd src/notebook-operator
make manifests generate install run
```

3. **Build and publish the ODH Gateway image:**
```bash
cd src/odh-gateway
# Update the image in the Dockerfile or build script as needed
make build
```

4. **Create an ODH Gateway instance:**
```bash
kubectl apply -f configs/gateway.yaml
```

5. **Create notebook instances:**
```bash
kubectl apply -f configs/nb2.yaml
kubectl apply -f configs/nb3.yaml
kubectl apply -f configs/nb4.yaml
```

## Configuration

### ODH Gateway Custom Resource

The `ODHGateway` CR defines how the gateway should be deployed:

```yaml
apiVersion: gateway.opendatahub.io/v1alpha1
kind: ODHGateway
metadata:
  name: odhgateway-sample
  namespace: default
spec:
  mode: "oidc"  # Authentication mode: "oidc" or "openshift"
  hostname: "gateway.example.com"  # External hostname for the gateway
  configMapName: "odh-proxy-config"  # Name of the main proxy ConfigMap
  image: "registry.example.com/odh-proxy:latest"  # Proxy container image
  
  # OIDC Authentication Configuration
  oidc:
    issuerURL: "https://your-oidc-provider.com"
    clientID: "odh-gateway"
    clientSecretRef:
      name: "oidc-client-secret"
      key: "client-secret"
  
  # OpenShift OAuth Configuration (alternative to OIDC)
  openshift:
    clientID: "openshift-web-client"
    userInfoURL: "https://openshift.default.svc/apis/user.openshift.io/v1/users/~"
    oauthURL: "https://openshift.default.svc/oauth/authorize"
  
  # Route ConfigMap Configuration (optional - auto-generated if not specified)
  routeConfigMap:
    name: "odh-routes"
    managed: true
    key: "config.yaml"
  
  # Namespace selector to limit service discovery (optional)
  namespaceSelector:
    include:
      - "data-science"
      - "mlops"
      - "default"
```

### Notebook Custom Resource

The `Notebook` CR defines a Jupyter notebook instance:

```yaml
apiVersion: ds.example.com/v1alpha1
kind: Notebook
metadata:
  name: user-notebook
  namespace: notebooks
spec:
  image: "jupyter/scipy-notebook:latest"  # Jupyter image to use
  port: 8888  # Port the notebook server runs on (optional, defaults to 8888)
  pvcName: "user-notebook-storage"  # PVC for persistent storage (optional)
  resources:  # Resource requirements (optional)
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### Service Discovery

Services are automatically discovered by the ODH Gateway Operator when they have the correct annotations. The Notebook Operator automatically adds these annotations, but you can also add them manually to any service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: default
  annotations:
    # Enable discovery by ODH Gateway
    odhgateway.opendatahub.io/enabled: "true"
    # Define the route path for this service
    odhgateway.opendatahub.io/route-path: "/my-service"
    # Optional: authentication settings
    odhgateway.opendatahub.io/auth-required: "true"  # or "false"
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: my-app
```

**Important**: Use annotations, not labels, for service discovery. The operator looks for:
- `odhgateway.opendatahub.io/enabled: "true"` - Enables discovery
- `odhgateway.opendatahub.io/route-path: "/path"` - Defines the routing path
- `odhgateway.opendatahub.io/auth-required: "true|false"` - Optional authentication override

### Authentication

The gateway supports two authentication modes:

#### OIDC Mode
Requires an OIDC provider (like Keycloak):
```yaml
spec:
  mode: "oidc"
  oidc:
    issuerURL: "https://keycloak.example.com/realms/my-realm"
    clientID: "odh-gateway"
    clientSecretRef:
      name: "oidc-secret"
      key: "client-secret"
```

#### OpenShift OAuth Mode
Uses OpenShift's built-in OAuth:
```yaml
spec:
  mode: "openshift"
  openshift:
    clientID: "openshift-web-client"
    userInfoURL: "https://openshift.default.svc/apis/user.openshift.io/v1/users/~"
    oauthURL: "https://openshift.default.svc/oauth/authorize"
```

## How It Works

1. **Gateway Deployment**: The ODH Gateway Operator creates a deployment, service, and route for the gateway based on the `ODHGateway` CR
2. **Service Discovery**: The operator watches for services with `odhgateway.opendatahub.io/enabled: "true"` annotations
3. **Configuration Update**: When services are found, the operator updates the gateway's ConfigMap with routing rules
4. **Hot Reload**: The gateway automatically reloads its configuration when the ConfigMap changes
5. **Notebook Creation**: The Notebook Operator creates pods and services for `Notebook` CRs, automatically annotating them for discovery
6. **Request Routing**: The gateway routes incoming requests to the appropriate backend services based on path matching

## Development Status

This is an **experimental** project to validate the approach of using a centralized gateway with automatic service discovery for ODH workloads. The individual projects under `src/` may be moved to separate repositories if this approach is approved.

## Next Steps

- Evaluate the effectiveness of the centralized gateway approach
- Gather feedback from ODH community
- Consider splitting into separate repositories if approved
- Add additional authentication providers as needed
- Implement more sophisticated routing and load balancing features
