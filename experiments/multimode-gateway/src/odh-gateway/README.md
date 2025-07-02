# ODH Gateway

A lightweight, configurable reverse proxy designed for Open Data Hub (ODH) and Kubernetes environments. The gateway dynamically routes incoming HTTP requests to upstream services based on path prefixes defined in a YAML configuration file.

## Features

- **Dynamic Routing**: Route requests to different upstream services based on URL path prefixes
- **Hot Reload**: Automatically reload configuration changes without restarting the service
- **ConfigMap Integration**: Designed to work with Kubernetes ConfigMaps for configuration management
- **Request Logging**: Comprehensive logging of all incoming requests
- **Containerized**: Ready-to-deploy Docker container with multi-stage build
- **Symlink Support**: Properly handles symlinked configuration files (important for Kubernetes mounts)

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client        │──▶│   ODH Gateway   │──▶│   Upstream      │
│   Request       │    │   (Reverse      │    │   Services      │
│                 │    │    Proxy)       │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  Configuration  │
                       │  YAML File      │
                       │  (ConfigMap)    │
                       └─────────────────┘
```

The gateway consists of three main components:

1. **Configuration Management** (`pkg/config/`): Loads and parses YAML routing configuration
2. **Proxy Server** (`internal/proxy/`): HTTP reverse proxy with routing logic and hot-reload capability
3. **Main Application** (`cmd/odh-gateway/`): Entry point that starts the server

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GATEWAY_CONFIG` | `/etc/odh-gateway/config.yaml` | Path to the configuration file |
| `GATEWAY_PORT` | `8080` | Port for the gateway to listen on |

### Configuration File Format

The gateway reads its routing configuration from a YAML file with the following structure:

```yaml
routes:
  - path: "/jupyter/"
    upstream: "http://jupyter-service:8888"
  - path: "/mlflow/"
    upstream: "http://mlflow-service:5000"
  - path: "/tensorboard/"
    upstream: "http://tensorboard-service:6006"
```

#### Route Configuration

- **`path`**: URL path prefix to match (automatically normalized to end with `/`)
- **`upstream`**: Target service URL to proxy requests to

#### Fallback Route Support

The gateway supports using `"/"` as a catchall fallback route for any requests that don't match more specific path prefixes. This is useful for handling static assets, health checks, or providing a default service.

**Example with fallback:**
```yaml
routes:
  - path: "/jupyter/"
    upstream: "http://jupyter-service:8888"
  - path: "/mlflow/"
    upstream: "http://mlflow-service:5000"
  - path: "/"
    upstream: "http://default-service:8080"  # Handles all other requests
```

**Request routing behavior:**
- `GET /jupyter/lab` → `http://jupyter-service:8888/jupyter/lab`
- `GET /mlflow/experiments` → `http://mlflow-service:5000/mlflow/experiments`
- `GET /unknown/path` → `http://default-service:8080/unknown/path` (fallback)
- `GET /favicon.ico` → `http://default-service:8080/favicon.ico` (fallback)

**Important notes:**
- List more specific routes before the `"/"` fallback in your configuration
- The full original path is preserved when forwarding to upstream services
- Only one `"/"` route should be configured (last one wins if multiple are defined)

### Example Kubernetes ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: odh-gateway-config
data:
  config.yaml: |
    routes:
      - path: "/jupyter/"
        upstream: "http://jupyter-notebook-service:8888"
      - path: "/mlflow/"
        upstream: "http://mlflow-tracking-service:5000"
      - path: "/tensorboard/"
        upstream: "http://tensorboard-service:6006"
```

## Hot Reload Mechanism

The gateway implements a dual approach for configuration reloading:

1. **File System Watching**: Uses `fsnotify` to watch for changes in the configuration file directory
2. **Polling**: Every 2 seconds, checks the file's SHA256 hash for changes as a fallback mechanism

This approach ensures configuration changes are picked up reliably, even in environments where file system events might be unreliable (like some Kubernetes setups).

## Building and Deployment

### Local Development

```bash
# Install dependencies
go mod download

# Run locally
export GATEWAY_CONFIG=./config.yaml
export GATEWAY_PORT=8080
go run cmd/odh-gateway/main.go
```

### Docker Build

```bash
# Build the container
docker build -t odh-gateway:latest .

# Run the container
docker run -p 8080:8080 -v $(pwd)/config.yaml:/etc/odh-gateway/config.yaml odh-gateway:latest
```

### Automated Build Script

The project includes a build script for automated deployment:

```bash
./BUILD_AND_PUBLISH.sh
```

This script builds and pushes the image to `registry.tannerjc.net/odh-proxy:latest`.

## Kubernetes Deployment

### Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: odh-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: odh-gateway
  template:
    metadata:
      labels:
        app: odh-gateway
    spec:
      containers:
      - name: odh-gateway
        image: registry.tannerjc.net/odh-proxy:latest
        ports:
        - containerPort: 8080
        env:
        - name: GATEWAY_CONFIG
          value: "/etc/odh-gateway/config.yaml"
        - name: GATEWAY_PORT
          value: "8080"
        volumeMounts:
        - name: config-volume
          mountPath: /etc/odh-gateway
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      volumes:
      - name: config-volume
        configMap:
          name: odh-gateway-config
---
apiVersion: v1
kind: Service
metadata:
  name: odh-gateway-service
spec:
  selector:
    app: odh-gateway
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

## Request Flow

1. **Client Request**: A client sends an HTTP request to the gateway
2. **Path Matching**: The gateway examines the request path and matches it against configured route prefixes
3. **Upstream Forwarding**: The request is forwarded to the appropriate upstream service
4. **Response Relay**: The upstream response is relayed back to the client
5. **Logging**: All requests are logged with client IP, method, and URL

## Logging

The gateway provides comprehensive request logging:

```
2024/01/15 10:30:45 Listening on :8080
2024/01/15 10:30:45 Routing /jupyter/ -> http://jupyter-service:8888
2024/01/15 10:30:45 Routing /mlflow/ -> http://mlflow-service:5000
2024/01/15 10:31:02 192.168.1.100:54321 GET /jupyter/lab
2024/01/15 10:31:15 192.168.1.100:54322 POST /mlflow/api/2.0/mlflow/experiments/create
```

## Dependencies

- **Go 1.24+**: Programming language
- **gopkg.in/yaml.v3**: YAML configuration parsing
- **github.com/fsnotify/fsnotify**: File system event monitoring

## Use Cases

This gateway is particularly useful for:

- **Multi-service ODH deployments** where different tools need to be accessible under different paths
- **Kubernetes environments** where services need dynamic routing configuration
- **Development environments** where routing needs to change frequently
- **Microservice architectures** requiring a simple, lightweight reverse proxy

## Security Considerations

- The gateway currently does not implement authentication or authorization
- SSL/TLS termination should be handled by an ingress controller or load balancer
- Network policies should be used to restrict access to upstream services
- Configuration files may contain sensitive upstream URLs and should be protected accordingly

## Future Enhancements

The configuration structure includes commented fields for potential future features:

- Authentication requirements per route
- Advanced routing rules (headers, query parameters)
- Load balancing across multiple upstreams
- Health checking of upstream services
- Metrics and monitoring integration 