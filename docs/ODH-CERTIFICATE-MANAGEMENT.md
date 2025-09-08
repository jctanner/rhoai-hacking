# ODH Operator Certificate Management

This document provides a comprehensive overview of certificate management in the OpenDataHub (ODH) operator, covering the different certificate systems, their purposes, and how users can configure them.

## Overview

The ODH operator implements multiple certificate management systems serving different purposes:

1. **TLS Certificate Management** (`pkg/cluster/cert.go`) - For ML model serving (KServe only)
2. **Trusted CA Bundle Management** (`certconfigmapgenerator`) - System-wide CA certificate distribution
3. **Component-Specific TLS** - User-provided certificates for monitoring and other services

## 1. TLS Certificate Management (KServe)

### Purpose
Provides TLS certificates for KServe's Istio Service Mesh ingress gateways that handle external traffic to ML models.

### Location
- **Code**: `pkg/cluster/cert.go`
- **Usage**: `internal/controller/components/kserve/kserve_support.go`

### Core Functions

#### `CreateSelfSignedCertificate()`
- Generates RSA 2048-bit self-signed certificates
- 1-year validity period
- Supports both IP addresses and DNS names (including wildcards)
- Always includes "localhost" as additional DNS name
- Creates Kubernetes TLS secrets with proper ownership

#### `PropagateDefaultIngressCertificate()`
- Discovers OpenShift's default ingress controller
- Copies ingress certificates from `openshift-ingress` namespace
- Handles both custom certificates and default router certificates

### Certificate Types

Users can configure certificate type via the DataScienceCluster (DSC) custom resource:

```yaml
apiVersion: datasciencecluster.opendatahub.io/v1
kind: DataScienceCluster
spec:
  components:
    kserve:
      serving:
        ingressGateway:
          certificate:
            type: OpenshiftDefaultIngress    # Certificate type
            secretName: my-custom-cert       # Optional custom secret name
          domain: "*.apps.my-cluster.com"    # Optional custom domain
```

#### Available Types

| Type | Description | Use Case |
|------|-------------|----------|
| `OpenshiftDefaultIngress` | Uses OpenShift's existing ingress certificate | **Default** - Production OpenShift environments |
| `SelfSigned` | Generates self-signed certificate automatically | Development/testing environments |
| `Provided` | User provides their own certificate | Full control over certificate properties |

### Configuration Examples

**Self-Signed Certificate:**
```yaml
spec:
  components:
    kserve:
      serving:
        ingressGateway:
          certificate:
            type: SelfSigned
            secretName: my-self-signed-cert
          domain: "*.example.com"
```

**User-Provided Certificate:**
```yaml
spec:
  components:
    kserve:
      serving:
        ingressGateway:
          certificate:
            type: Provided
            secretName: my-existing-cert-secret
```

**OpenShift Default (Production):**
```yaml
spec:
  components:
    kserve:
      serving:
        ingressGateway:
          certificate:
            type: OpenshiftDefaultIngress  # This is the default
```

### Domain Resolution

Domain names for certificates are determined hierarchically:

1. **User-specified domain**: Explicitly configured in component spec
2. **OpenShift cluster domain**: Retrieved via `cluster.GetDomain()` from cluster's ingress configuration
3. **Wildcard conversion**: Automatically converts to wildcard format (`*.domain.com`)

### Default Values

- **Certificate type**: `OpenshiftDefaultIngress`
- **Secret name**: `knative-serving-cert`
- **Domain**: OpenShift cluster's ingress domain (auto-detected)

### OpenShift Default Ingress Certificate Logic

When `type: OpenshiftDefaultIngress` is configured, the system executes a multi-step process to discover and propagate OpenShift's ingress certificate:

#### Step 1: Discover the Ingress Controller
```go
// Location: openshift-ingress-operator/default
IngressControllerName = types.NamespacedName{
    Namespace: "openshift-ingress-operator",
    Name:      "default",
}
```

The system queries the default OpenShift ingress controller resource to understand the cluster's ingress configuration.

#### Step 2: Determine Certificate Secret Name
```go
func GetDefaultIngressCertSecretName(ingressCtrl *operatorv1.IngressController) string {
    if ingressCtrl.Spec.DefaultCertificate != nil {
        return ingressCtrl.Spec.DefaultCertificate.Name  // Custom certificate
    }
    return "router-certs-" + ingressCtrl.Name            // Default: "router-certs-default"
}
```

The certificate secret name is determined by:
- **Custom Certificate**: If a custom certificate is configured in the ingress controller, use that secret name
- **Default Certificate**: Otherwise, use the pattern `router-certs-{controller-name}` (typically `router-certs-default`)

#### Step 3: Retrieve the Certificate Secret
```go
// Source location: openshift-ingress namespace
const IngressNamespace = "openshift-ingress"
```

The system fetches the actual certificate secret from the `openshift-ingress` namespace using the determined secret name.

#### Step 4: Copy Certificate to Target Namespace
```go
func copySecretToNamespace(ctx context.Context, c client.Client, secret *corev1.Secret, newSecretName, namespace string) error {
    newSecret := &corev1.Secret{
        ObjectMeta: metav1.ObjectMeta{
            Name:      newSecretName,        // e.g., "knative-serving-cert"
            Namespace: namespace,            // e.g., "istio-system"
        },
        Data: secret.Data,                   // Copy certificate data
        Type: secret.Type,                   // Preserve secret type (kubernetes.io/tls)
    }
    // Apply with field ownership for proper resource management
}
```

The certificate is copied to the target namespace (typically the Service Mesh control plane namespace like `istio-system`) with:
- **New name**: As specified in the KServe configuration (default: `knative-serving-cert`)
- **Same data**: Exact copy of the certificate and private key
- **Proper ownership**: Managed by the ODH operator with field ownership

#### Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     OpenShift Default Ingress Certificate Flow              │
└─────────────────────────────────────────────────────────────────────────────┘

1. Query Ingress Controller
   ┌─────────────────────────────────┐
   │ openshift-ingress-operator/     │ ──┐
   │ IngressController "default"     │   │
   └─────────────────────────────────┘   │
                                         ▼
2. Determine Certificate Secret Name     │
   ┌─────────────────────────────────┐   │
   │ Check: spec.defaultCertificate  │◄──┘
   │ • Custom: use specified name    │
   │ • Default: "router-certs-default"│
   └─────────────────────────────────┘
                    │
                    ▼
3. Fetch Certificate Secret
   ┌─────────────────────────────────┐
   │ openshift-ingress/              │
   │ Secret "router-certs-default"   │
   │ • tls.crt (certificate)         │
   │ • tls.key (private key)         │
   └─────────────────────────────────┘
                    │
                    ▼
4. Copy to Target Namespace
   ┌─────────────────────────────────┐
   │ istio-system/                   │
   │ Secret "knative-serving-cert"   │
   │ • Same certificate data         │
   │ • ODH operator ownership        │
   └─────────────────────────────────┘
```

#### Implementation Notes

1. **Automatic Discovery**: No manual certificate configuration required
2. **Cluster Integration**: Uses the same certificates that secure the cluster's ingress traffic
3. **Certificate Rotation**: Automatically inherits any certificate updates from OpenShift
4. **Production Ready**: Leverages enterprise-grade certificate management

## 2. Trusted CA Bundle Management

### Purpose
Distributes trusted CA certificates across all namespaces in the cluster for secure communication between ODH components.

### Location
- **Code**: `internal/controller/services/certconfigmapgenerator/`
- **ConfigMap Name**: `odh-trusted-ca-bundle`

### Functionality

#### `CreateOdhTrustedCABundleConfigMap()`
- Creates/updates `odh-trusted-ca-bundle` ConfigMap in specified namespaces
- Combines custom CA certificates with OpenShift's cluster trusted CA bundle
- Uses OpenShift's Cluster Network Operator (CNO) for automatic CA injection

### Configuration

Configured via `DSCInitialization` custom resource:

```yaml
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
spec:
  trustedCABundle:
    customCABundle: |
      -----BEGIN CERTIFICATE-----
      ... custom CA certificate content ...
      -----END CERTIFICATE-----
```

### ConfigMap Structure

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: odh-trusted-ca-bundle
  labels:
    config.openshift.io/inject-trusted-cabundle: "true"  # Enables CNO injection
data:
  odh-ca-bundle.crt: |    # Custom CA certificates
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  ca-bundle.crt: |        # Auto-injected by CNO (OpenShift cluster CAs)
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
```

## 3. Component-Specific TLS Configuration

### Monitoring Services

The monitoring service supports TLS but expects user-provided certificates:

```yaml
apiVersion: services.opendatahub.io/v1alpha1
kind: Monitoring
spec:
  traces:
    tls:
      enabled: true
      certificateSecret: my-tempo-cert-secret  # User must provide
      caConfigMap: my-ca-configmap            # User must provide
```

**Note**: Monitoring services do **not** use the certificate generation functions from `cert.go`.

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    ODH Certificate Management                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐ │
│  │   KServe TLS    │  │  Trusted CA      │  │ Component TLS   │ │
│  │  (cert.go)      │  │  Bundles         │  │ (User-provided) │ │
│  │                 │  │                  │  │                 │ │
│  │ • Self-signed   │  │ • System-wide    │  │ • Monitoring    │ │
│  │ • OpenShift     │  │ • All namespaces │  │ • Custom apps   │ │
│  │ • User-provided │  │ • CNO integration│  │                 │ │
│  └─────────────────┘  └──────────────────┘  └─────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Key Insights

1. **KServe-Specific**: The sophisticated certificate generation/propagation logic in `cert.go` is **only used by KServe** for ML model serving gateways.

2. **Multiple Systems**: ODH implements separate certificate management systems for different purposes rather than a unified approach.

3. **OpenShift Integration**: Heavy integration with OpenShift's certificate infrastructure (ingress certificates, CNO for CA bundles).

4. **User Flexibility**: Users can choose between automated certificate generation, OpenShift integration, or providing their own certificates.

5. **Production Ready**: Default configuration (`OpenshiftDefaultIngress`) is designed for production OpenShift deployments.

## Files Reference

### Core Certificate Management
- `pkg/cluster/cert.go` - Main certificate generation/propagation functions
- `internal/controller/components/kserve/kserve_support.go` - KServe certificate integration
- `api/infrastructure/v1/cert_types.go` - Certificate type definitions
- `api/infrastructure/v1/servicemesh_types.go` - Gateway and certificate specifications

### Trusted CA Bundle Management
- `internal/controller/services/certconfigmapgenerator/` - CA bundle distribution service
- `api/dscinitialization/v1/` - DSCInitialization API for CA configuration

### Configuration Examples
- `config/samples/datasciencecluster_v1_datasciencecluster.yaml` - Sample DSC configuration

### Testing
- `tests/e2e/kserve_test.go` - E2E tests for certificate functionality
