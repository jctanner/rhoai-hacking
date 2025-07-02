# ODH Gateway System - Complete Deployment Guide

This guide shows you how to deploy the entire ODH Gateway system from scratch.

## 🚀 Quick Start (Deploy Everything)

```bash
# Make sure you have kind, kubectl, and docker installed and running
./DEPLOY_ALL.sh
```

This single command will:
1. ✅ Create a KIND cluster
2. ✅ Deploy ODH Gateway Operator
3. ✅ Deploy Notebook Operator  
4. ✅ Deploy ODH Dashboard
5. ✅ Create sample notebooks
6. ✅ Verify everything is working

**Total time: ~5-10 minutes** ⏱️

## 📋 Prerequisites

Before running the deployment script, ensure you have:

- **Docker** - Running and accessible
- **kubectl** - Kubernetes CLI tool
- **kind** - For local Kubernetes clusters
- **make** - Build automation (usually pre-installed)

### Installation (if needed):

```bash
# Install kind
go install sigs.k8s.io/kind@latest
# OR
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/

# Install kubectl
curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

## 🎯 Step-by-Step Deployment

If you want to deploy components individually:

### 1. Create Cluster Only
```bash
./DEPLOY_ALL.sh cluster
```

### 2. Deploy Operators Only
```bash
./DEPLOY_ALL.sh operators
```

### 3. Deploy Dashboard Only
```bash
./DEPLOY_ALL.sh dashboard
```

### 4. Create Sample Resources Only
```bash
./DEPLOY_ALL.sh samples
```

### 5. Verify Deployment
```bash
./DEPLOY_ALL.sh verify
```

## 🌐 Accessing Your Services

After deployment completes, you'll see instructions like this:

### 1. Port Forward the Gateway
```bash
kubectl port-forward svc/odhgateway-sample-svc 8080:80
```

### 2. Access the Services
- **Dashboard (fallback route)**: http://localhost:8080
- **Notebook 2 (scipy)**: http://localhost:8080/notebooks/notebook-sample2  
- **Notebook 3 (datascience)**: http://localhost:8080/notebooks/notebook-sample3
- **Notebook 4 (tensorflow)**: http://localhost:8080/notebooks/notebook-sample4

### 3. Direct Dashboard Access (bypass gateway)
```bash
kubectl port-forward svc/odh-dashboard-svc 5000:80
# Then visit: http://localhost:5000
```

## 🔍 Monitoring and Debugging

### Check All Resources
```bash
kubectl get all -A
```

### View Gateway Configuration
```bash
kubectl get configmap odhgateway-sample-routes -o yaml
```

### Check Operator Logs
```bash
# Gateway Operator
kubectl logs -n odh-gateway-operator-system deployment/odh-gateway-operator-controller-manager

# Notebook Operator  
kubectl logs -n notebook-operator-system deployment/notebook-operator-controller-manager
```

### Check Discovered Services
```bash
kubectl get svc -A -o jsonpath='{range .items[?(@.metadata.annotations.odhgateway\.opendatahub\.io/enabled=="true")]}{.metadata.name}{" ("}{.metadata.annotations.odhgateway\.opendatahub\.io/route-path}{")"}{"\n"}{end}'
```

## 🧹 Cleanup

### Delete Everything
```bash
./DEPLOY_ALL.sh clean
```

This removes the entire KIND cluster and all resources.

## 🛠️ What Gets Deployed

### System Components:
- **ODH Gateway Operator**: Manages gateway instances and service discovery
- **Notebook Operator**: Creates and manages Jupyter notebooks
- **ODH Dashboard**: Web UI showing all available services

### Sample Resources:
- **ODH Gateway Instance**: Central proxy with route sorting
- **3 Sample Notebooks**: Different Jupyter configurations
  - `notebook-sample2`: scipy-notebook (lightweight)
  - `notebook-sample3`: datascience-notebook (pandas, matplotlib, etc.)
  - `notebook-sample4`: tensorflow-notebook (ML/AI tools)

### Key Features Demonstrated:
- ✅ **Route Sorting**: Specific routes before fallback "/"
- ✅ **Service Discovery**: Automatic annotation-based discovery
- ✅ **Centralized Dashboard**: Shows all available services
- ✅ **Multiple Services**: Notebooks accessible through gateway
- ✅ **Health Monitoring**: All components have health checks

## 🎛️ Customization

### Adding More Notebooks
Create additional notebook YAML files in `configs/`:

```yaml
apiVersion: ds.example.com/v1alpha1
kind: Notebook
metadata:
  name: my-custom-notebook
  namespace: default
spec:
  image: "jupyter/minimal-notebook:latest"
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "250m"
```

Then apply:
```bash
kubectl apply -f configs/my-custom-notebook.yaml
```

### Modifying the Dashboard
Edit files in `src/odh-dashboard/` and redeploy:

```bash
./DEPLOY_ALL.sh dashboard
```

## 🐛 Troubleshooting

### Common Issues:

1. **"Docker not running"**
   ```bash
   sudo systemctl start docker
   ```

2. **"KIND cluster creation failed"**
   ```bash
   # Clean up and retry
   kind delete cluster --name odh-minimal
   ./DEPLOY_ALL.sh cluster
   ```

3. **"Pods not starting"**
   ```bash
   # Check pod status
   kubectl get pods -A
   kubectl describe pod <pod-name>
   ```

4. **"Service not accessible"**
   ```bash
   # Verify port forwarding
   kubectl get svc
   kubectl port-forward svc/odhgateway-sample-svc 8080:80
   ```

### Getting Help:
```bash
./DEPLOY_ALL.sh help
```

## 🎉 Success Indicators

You know everything is working when:

1. ✅ All pods are **Running**
2. ✅ Gateway config shows **sorted routes** (most specific first)
3. ✅ Dashboard shows **discovered services**
4. ✅ Notebooks are **accessible** through gateway URLs
5. ✅ Route **"/"** falls back to dashboard

Your ODH Gateway system is now ready for experimentation and development! 🚀 