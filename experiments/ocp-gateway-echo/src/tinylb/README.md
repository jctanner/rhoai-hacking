# TinyLB - Kubernetes LoadBalancer Bridge for Single-Node Environments

[![Go Report Card](https://goreportcard.com/badge/github.com/jctanner/tinylb)](https://goreportcard.com/report/github.com/jctanner/tinylb)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.11%2B-brightgreen.svg)](https://kubernetes.io/)

**TinyLB** is a minimal Kubernetes controller that enables Gateway API functionality on single-node environments (CRC, SNO, kind, minikube) by bridging LoadBalancer services to platform-specific external access mechanisms.

## 🎯 Problem Statement

Gateway API implementations like Istio create LoadBalancer services that cannot get external IPs in single-node development environments. This causes Gateways to remain in `PROGRAMMED: False` state, blocking Gateway API functionality.

**Before TinyLB:**
```bash
# LoadBalancer service stuck in pending state
kubectl get svc echo-gateway-istio
NAME                EXTERNAL-IP   PORT(S)
echo-gateway-istio  <pending>     80:32273/TCP

# Gateway cannot be programmed
kubectl get gateway echo-gateway
NAME           CLASS   ADDRESS   PROGRAMMED   AGE
echo-gateway   istio   (none)    False        5m
```

**After TinyLB:**
```bash
# LoadBalancer service gets external address
kubectl get svc echo-gateway-istio
NAME                EXTERNAL-IP                                    PORT(S)
echo-gateway-istio  echo-gateway-istio-echo-test.apps-crc.testing  80:32273/TCP

# Gateway becomes programmed and ready
kubectl get gateway echo-gateway
NAME           CLASS   ADDRESS                                        PROGRAMMED   AGE
echo-gateway   istio   echo-gateway-istio-echo-test.apps-crc.testing  True         5m
```

## 🚀 How It Works

TinyLB acts as a bridge between Kubernetes LoadBalancer services and platform-specific external access:

1. **Service Watcher**: Monitors LoadBalancer services with empty `status.loadBalancer.ingress`
2. **External Access Creator**: Creates platform-specific external access (OpenShift Routes, Ingress, etc.)
3. **Status Updater**: Updates LoadBalancer service status with external address
4. **Gateway Enabler**: Allows Gateway API controllers to complete configuration

## 🏗️ Architecture

```
Gateway API Controller → LoadBalancer Service → TinyLB → Platform External Access
        ↓                       ↓                ↓              ↓
   Creates Service         Stuck <pending>    Watches &     Route/Ingress
   Expects External IP                        Creates       Created
        ↓                                        ↓              ↓
   Waits for Address  ←────────────────────── Updates ←────── External Address
        ↓                                    Service Status    Available
   Gateway PROGRAMMED: True
```

## 📦 Installation

### Prerequisites
- Kubernetes 1.11.3+
- kubectl configured for your cluster
- Platform-specific requirements:
  - **OpenShift/CRC**: Routes API available
  - **Standard Kubernetes**: Ingress controller installed

### Quick Install

```bash
# Install TinyLB
kubectl apply -f https://raw.githubusercontent.com/jctanner/tinylb/main/dist/install.yaml

# Verify installation
kubectl get pods -n tinylb-system
NAME                               READY   STATUS    RESTARTS   AGE
tinylb-controller-manager-xxx      2/2     Running   0          1m
```

### Helm Installation

```bash
# Add TinyLB Helm repository
helm repo add tinylb https://jctanner.github.io/tinylb
helm repo update

# Install TinyLB
helm install tinylb tinylb/tinylb -n tinylb-system --create-namespace

# Verify installation
helm status tinylb -n tinylb-system
```

## 🔧 Configuration

TinyLB is configured via environment variables in the deployment:

```yaml
env:
# Platform-specific settings
- name: PLATFORM
  value: "openshift"  # openshift, kubernetes, auto

# Hostname pattern for external access
- name: HOSTNAME_PATTERN
  value: "{service}-{namespace}.apps-crc.testing"

# Namespace filtering (empty = all namespaces)
- name: WATCH_NAMESPACES
  value: "default,echo-test"

# Logging configuration
- name: LOG_LEVEL
  value: "info"
```

## 🎯 Use Cases

### Service Mesh + Gateway API
Enable Istio Gateway API on single-node environments:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio
  listeners:
  - name: default
    hostname: "*.apps-crc.testing"
    port: 80
    protocol: HTTP
```

### Development Environments
- **CodeReady Containers (CRC)**: OpenShift development
- **kind**: Kubernetes in Docker
- **minikube**: Local Kubernetes development
- **Single Node OpenShift (SNO)**: Edge computing scenarios

### CI/CD Integration
Use TinyLB in automated testing pipelines requiring Gateway API functionality.

## 🔒 Security Features

### TLS/mTLS Support
TinyLB works seamlessly with Service Mesh security:

```yaml
# Automatic TLS termination via OpenShift Routes
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: tinylb-my-service
spec:
  host: my-service-default.apps-crc.testing
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

### RBAC
TinyLB requires minimal RBAC permissions:
- `services`: get, list, watch, update
- `routes.route.openshift.io`: get, list, watch, create, update, delete
- `ingresses.networking.k8s.io`: get, list, watch, create, update, delete

## 📊 Monitoring

TinyLB exposes Prometheus metrics:

```
# Service processing metrics
tinylb_services_processed_total{platform="openshift"} 5
tinylb_services_current{platform="openshift"} 3

# Error metrics
tinylb_errors_total{type="route_creation"} 0
tinylb_errors_total{type="status_update"} 0
```

## 🔍 Troubleshooting

### Common Issues

**Gateway remains `PROGRAMMED: False`**
```bash
# Check TinyLB logs
kubectl logs -n tinylb-system deployment/tinylb-controller-manager

# Verify service status
kubectl get svc -A | grep LoadBalancer
```

**Route/Ingress not created**
```bash
# Check RBAC permissions
kubectl auth can-i create routes.route.openshift.io --as=system:serviceaccount:tinylb-system:tinylb-controller-manager

# Verify TinyLB configuration
kubectl get configmap tinylb-config -n tinylb-system -o yaml
```

### Debug Mode
Enable debug logging:
```bash
kubectl patch deployment tinylb-controller-manager -n tinylb-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"manager","env":[{"name":"LOG_LEVEL","value":"debug"}]}]}}}}'
```

## 🛠️ Development

### Building from Source
```bash
# Clone repository
git clone https://github.com/jctanner/tinylb.git
cd tinylb

# Build binary
make build

# Build container image
make docker-build IMG=tinylb:latest
```

### Testing
```bash
# Run unit tests
make test

# Run integration tests
make test-integration

# Run e2e tests (requires cluster)
make test-e2e
```

### Local Development
```bash
# Run controller locally
make run

# Deploy to cluster
make deploy IMG=tinylb:latest
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Process
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for your changes
5. Run tests (`make test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Code of Conduct
This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## 📋 Roadmap

- [ ] **Multi-platform Support**: Kubernetes Ingress, AWS ALB, GCP Load Balancer
- [ ] **Advanced Routing**: Path-based routing, weighted traffic splitting
- [ ] **Observability**: Enhanced metrics, tracing, health checks
- [ ] **Security**: Certificate management, policy enforcement
- [ ] **Performance**: Optimized reconciliation, caching

## 🎉 Success Stories

TinyLB has enabled Gateway API functionality in:
- **Red Hat OpenShift Service Mesh 3.0** on CRC environments
- **Istio Gateway API** deployments on kind clusters
- **CI/CD pipelines** requiring Gateway API testing
- **Edge computing** scenarios with Single Node OpenShift

## 📚 Documentation

- [Installation Guide](docs/installation.md)
- [Configuration Reference](docs/configuration.md)
- [Platform Support](docs/platforms.md)
- [Security Guide](docs/security.md)
- [API Reference](docs/api.md)

## 🔗 Related Projects

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Istio](https://istio.io/)
- [OpenShift Service Mesh](https://docs.openshift.com/container-platform/latest/service_mesh/v2x/ossm-about.html)
- [OpenShift Routes](https://docs.openshift.com/container-platform/latest/networking/routes/route-configuration.html)

## 📄 License

Copyright 2025 TinyLB Contributors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## 🙏 Acknowledgments

- **kubebuilder** for the excellent controller framework
- **OpenShift** for the Route API inspiration
- **Istio** for Gateway API leadership
- **Kubernetes SIG-Network** for the Gateway API specification

---

⭐ **Star this project** if TinyLB helped enable Gateway API in your environment!

🐛 **Found a bug?** [Open an issue](https://github.com/jctanner/tinylb/issues/new/choose)

💡 **Have an idea?** [Start a discussion](https://github.com/jctanner/tinylb/discussions)

