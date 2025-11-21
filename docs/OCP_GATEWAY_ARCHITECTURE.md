# Gateway API Architecture in OpenShift

## Overview

This document describes the complete architectural flow for Gateway API implementation in OpenShift, including how Gateway resources are reconciled, how addresses are populated from cloud load balancers, and how DNS records are managed.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Details](#component-details)
3. [DNS Management Flow](#dns-management-flow)
4. [Gateway Address Population](#gateway-address-population)
5. [Complete Data Flow](#complete-data-flow)
6. [File References](#file-references)
7. [Bare Metal Deployments](#bare-metal-deployments-no-cloud-provider)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

The Gateway API implementation in OpenShift consists of three main layers:

### Layer 1: OpenShift Cluster Ingress Operator
**Repository**: `./src/openshift/cluster-ingress-operator`

Manages Gateway API CRDs, GatewayClass lifecycle, and DNS integration.

### Layer 2: Sail Operator
**Repository**: `./src/istio-ecosystem/sail-operator`

Manages Istio installation lifecycle via Helm charts.

### Layer 3: Istio (istiod)
**Repository**: `./src/istio/istio`

The actual Gateway API reconciliation happens inside istiod's control plane.

---

## Component Details

### 1. OpenShift Cluster Ingress Operator Components

#### 1.1 Gateway API Controller
**Location**: `pkg/operator/controller/gatewayapi/`

**Purpose**: Installs Gateway API CRDs and RBAC

**Responsibilities**:
- Watches `FeatureGate` resource to enable/disable Gateway API
- Installs standard Kubernetes Gateway API CRDs (v1.3.0)
- Manages RBAC for Gateway API resources
- Started when `FeatureGateGatewayAPI` is enabled

**CRDs Installed** (`pkg/manifests/assets/gateway-api/`):
- `gateway.networking.k8s.io_gatewayclasses.yaml`
- `gateway.networking.k8s.io_gateways.yaml`
- `gateway.networking.k8s.io_httproutes.yaml`
- `gateway.networking.k8s.io_grpcroutes.yaml`
- `gateway.networking.k8s.io_referencegrants.yaml`

#### 1.2 GatewayClass Controller
**Location**: `pkg/operator/controller/gatewayclass/`

**Purpose**: Manages GatewayClass resources and installs Istio

**Responsibilities**:
- Watches GatewayClass resources with controller name: `openshift.io/gateway-controller/v1`
- Creates Istio CR via sail-operator API
- Manages OSSM (OpenShift Service Mesh) subscription via OLM
- Configures Istio with Gateway API-specific environment variables

**Configuration** (`gatewayclass/istio.go:100-147`):
```go
pilotContainerEnv := map[string]string{
    // Enable Gateway API
    "PILOT_ENABLE_GATEWAY_API": "true",
    // Do not enable experimental Gateway API features
    "PILOT_ENABLE_ALPHA_GATEWAY_API": "false",
    // Enable Istio to update status of Gateway API resources
    "PILOT_ENABLE_GATEWAY_API_STATUS": "true",
    // Enable automated deployment (creates Envoy Deployment + Service for Gateways)
    "PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER": "true",
    // Disable Istio's gatewayclass controller (OpenShift manages GatewayClasses)
    "PILOT_ENABLE_GATEWAY_API_GATEWAYCLASS_CONTROLLER": "false",
    // Set default gatewayclass name
    "PILOT_GATEWAY_API_DEFAULT_GATEWAYCLASS_NAME": "openshift-default",
    // Only reconcile resources with OpenShift's controller name
    "PILOT_GATEWAY_API_CONTROLLER_NAME": "openshift.io/gateway-controller/v1",
    // Disable multi-network gateways
    "PILOT_MULTI_NETWORK_DISCOVER_GATEWAY_API": "false",
    // Only allow automated deployment (no manual service reuse)
    "ENABLE_GATEWAY_API_MANUAL_DEPLOYMENT": "false",
    // Only create CA Bundle in namespaces with Gateways
    "PILOT_ENABLE_GATEWAY_API_CA_CERT_ONLY": "true",
    // Don't copy labels/annotations to prevent config injection
    "PILOT_ENABLE_GATEWAY_API_COPY_LABELS_ANNOTATIONS": "false",
}
```

**Constants** (`names.go:65`):
- Controller name: `openshift.io/gateway-controller/v1`
- Default GatewayClass: `openshift-default`
- Istio CR name: `openshift-gateway`
- OSSM subscription: `servicemeshoperator3` in `openshift-operators` namespace

#### 1.3 Gateway Service DNS Controller
**Location**: `pkg/operator/controller/gateway-service-dns/`

**Purpose**: Creates DNS records for Gateway resources

**Responsibilities**:
- Watches Services with label `gateway.istio.io/managed` (created by Istio)
- Watches Gateway resources in `openshift-ingress` namespace
- Creates DNSRecord CRs for each Gateway listener hostname

**How It Works** (`controller.go:163-211`):
1. Gets the Service created by Istio
2. Finds parent Gateway via `gateway.networking.k8s.io/gateway-name` label
3. Extracts hostnames from `Gateway.Spec.Listeners[].Hostname`
4. For each hostname, creates a DNSRecord CR

#### 1.4 Gateway Labeler Controller
**Location**: `pkg/operator/controller/gateway-labeler/`

**Purpose**: Manages labels on Gateway resources (likely for `istio.io/rev` label)

#### 1.5 DNS Controller
**Location**: `pkg/operator/controller/dns/`

**Purpose**: Reconciles DNSRecord CRs with cloud provider DNS services

**Responsibilities**:
- Watches DNSRecord CRs
- Gets cloud provider type from `infrastructure.config.openshift.io/cluster`
- Creates DNS records in cloud provider (Route53, Cloud DNS, Azure DNS, IBM DNS)
- Updates DNSRecord status with success/failure

**Supported Cloud Providers**:
- AWS Route53 (`pkg/dns/aws/`)
- GCP Cloud DNS (`pkg/dns/gcp/`)
- Azure DNS (`pkg/dns/azure/`)
- IBM Cloud DNS (`pkg/dns/ibm/`)

---

### 2. Sail Operator Components

#### 2.1 Istio Controller
**Location**: `controllers/istio/`

**Purpose**: Manages Istio CR lifecycle

**Responsibilities**:
- Watches `Istio` CR created by cluster-ingress-operator
- Creates `IstioRevision` CR based on version and update strategy
- Manages revision lifecycle and pruning
- Supports two update strategies:
  - `InPlace`: Updates existing control plane
  - `RevisionBased`: Creates new control plane, allows gradual migration

**Istio CR Structure**:
```yaml
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: openshift-gateway
spec:
  namespace: istio-system
  updateStrategy:
    type: InPlace
  values:
    global:
      istioNamespace: istio-system
      priorityClassName: system-cluster-critical
    pilot:
      enabled: true
      env:
        PILOT_ENABLE_GATEWAY_API: "true"
        # ... (other env vars)
```

#### 2.2 IstioRevision Controller
**Location**: `controllers/istiorevision/`

**Purpose**: Installs Istio via Helm charts

**Responsibilities** (`istiorevision_controller.go:169-193`):
- Installs Istio using Helm charts: `istiod` and `base`
- Deploys istiod (Istio control plane) Deployment
- Configures istiod with Gateway API environment variables
- Manages Helm releases

**Charts Installed**:
- `istiod`: The Istio control plane (Deployment with istiod container)
- `base`: Base Istio resources (CRDs, ClusterRoles, etc.)

---

### 3. Istio (istiod) Components

The actual Gateway API reconciliation happens inside **istiod** (Istio's control plane).

#### 3.1 Gateway Controller
**Location**: `./src/istio/istio/pilot/pkg/config/kube/gateway/controller.go`

**Purpose**: Main Gateway API controller in istiod

**Responsibilities**:
- Watches Gateway API resources (Gateways, HTTPRoutes, GRPCRoutes, etc.)
- Translates Gateway API resources to Istio internal types (Gateway, VirtualService)
- Updates status on Gateway API resources
- Coordinates with deployment controller

#### 3.2 Deployment Controller
**Location**: `./src/istio/istio/pilot/pkg/config/kube/gateway/deploymentcontroller.go`

**Purpose**: Creates infrastructure for Gateway resources

**Responsibilities** (`deploymentcontroller.go:431-571`):
- Watches Gateway resources
- For each Gateway, creates:
  - **Deployment**: Envoy proxy pods
  - **Service**: LoadBalancer service (default) for external access
  - **ServiceAccount**: For the Envoy pods
  - **HorizontalPodAutoscaler**: (optional) For scaling
  - **PodDisruptionBudget**: (optional) For availability

**Service Configuration**:
- Type: `LoadBalancer` (default, configurable via annotation)
- Labels:
  - `gateway.istio.io/managed: <gateway-controller-name>`
  - `gateway.networking.k8s.io/gateway-name: <gateway-name>`
- Ports: Extracted from Gateway listeners

**Gateway Reconciliation Flow** (`deploymentcontroller.go:469-572`):
1. Check if Gateway class is managed by this controller
2. Check if Gateway revision matches (`istio.io/rev` label)
3. Render Kubernetes resources from Go templates
4. Apply resources using Server-Side Apply (SSA)
5. Service creation triggers cloud load balancer provisioning

---

## DNS Management Flow

### Step 1: Gateway Service DNS Controller Watches Services

**File**: `./src/openshift/cluster-ingress-operator/pkg/operator/controller/gateway-service-dns/controller.go:163-211`

**Process**:
1. Watches Services with label `gateway.istio.io/managed`
2. Gets parent Gateway resource via `gateway.networking.k8s.io/gateway-name` label
3. Extracts hostnames from `Gateway.Spec.Listeners[].Hostname`
4. For each hostname, creates a DNSRecord CR

**Example**:
```yaml
# Gateway has listener with hostname: *.apps.example.com
# Service has status.loadBalancer.ingress[0].hostname: a123.us-east-1.elb.amazonaws.com
# Creates DNSRecord:
apiVersion: operatoringress.operator.openshift.io/v1
kind: DNSRecord
metadata:
  name: gateway-xyz-abc123-wildcard
  namespace: openshift-ingress
spec:
  dnsName: "*.apps.example.com."
  targets:
    - "a123.us-east-1.elb.amazonaws.com"
  recordType: CNAME
  recordTTL: 30
  dnsManagementPolicy: Managed  # or Unmanaged
```

### Step 2: DNSRecord Creation Logic

**File**: `./src/openshift/cluster-ingress-operator/pkg/resources/dnsrecord/dns.go:134-177`

**Process**:
1. Check if `Service.Status.LoadBalancer.Ingress[0]` is populated
2. Extract target:
   - If `.Hostname` is set → RecordType: `CNAME`, Target: hostname
   - If `.IP` is set → RecordType: `A`, Target: IP
3. Determine DNS policy:
   - `Managed`: If hostname is subdomain of cluster baseDomain
   - `Unmanaged`: If hostname is external domain

**DNS Policy Logic** (`dns.go:237-258`):
```go
func ManageDNSForDomain(domain string, platformStatus *configv1.PlatformStatus, dnsConfig *configv1.DNS) bool {
    mustContain := "." + dnsConfig.Spec.BaseDomain

    switch platformStatus.Type {
    case configv1.AWSPlatformType, configv1.GCPPlatformType:
        // Only manage if subdomain of baseDomain
        return strings.HasSuffix(domain, mustContain)
    default:
        // Manage all domains on other platforms
        return true
    }
}
```

**Example**:
- Cluster baseDomain: `openshift.example.com`
- Gateway hostname: `*.apps.openshift.example.com` → **Managed**
- Gateway hostname: `myapp.external.com` → **Unmanaged** (AWS/GCP only)

### Step 3: DNS Controller Reconciles DNSRecord

**File**: `./src/openshift/cluster-ingress-operator/pkg/operator/controller/dns/controller.go:130-209`

**Process**:
1. Get DNSRecord CR
2. Skip if `dnsManagementPolicy: Unmanaged`
3. Get cloud provider type from `infrastructure.config.openshift.io/cluster`
4. Get cloud credentials from secret `cloud-credentials`
5. Create cloud-specific DNS provider client
6. Call `publishRecordToZones()` to create/update DNS records
7. Update `DNSRecord.Status.Zones` with result

**Cloud Provider Creation** (`controller.go:216-250`):
```go
switch platformStatus.Type {
case configv1.AWSPlatformType:
    provider = awsdns.NewProvider(credentials, platformStatus)
case configv1.GCPPlatformType:
    provider = gcpdns.NewProvider(credentials, platformStatus)
case configv1.AzurePlatformType:
    provider = azuredns.NewProvider(credentials, platformStatus)
case configv1.IBMCloudPlatformType:
    provider = ibmdns.NewProvider(credentials, platformStatus)
}
```

### Step 4: Cloud DNS Record Creation

**Example - AWS Route53**:

1. DNSRecord specifies:
   - `dnsName: "*.apps.example.com."`
   - `targets: ["a123.us-east-1.elb.amazonaws.com"]`
   - `recordType: CNAME`

2. DNS controller calls AWS Route53 API:
   ```
   aws route53 change-resource-record-sets --hosted-zone-id Z123ABC --change-batch '{
     "Changes": [{
       "Action": "UPSERT",
       "ResourceRecordSet": {
         "Name": "*.apps.example.com.",
         "Type": "CNAME",
         "TTL": 30,
         "ResourceRecords": [{"Value": "a123.us-east-1.elb.amazonaws.com"}]
       }
     }]
   }'
   ```

3. Updates `DNSRecord.Status.Zones`:
   ```yaml
   status:
     zones:
     - dnsZone:
         id: /hostedzone/Z123ABC
       conditions:
       - type: Published
         status: "True"
         message: "DNS record successfully published"
   ```

---

## Gateway Address Population

### Step 1: Istio Creates LoadBalancer Service

**File**: `./src/istio/istio/pilot/pkg/config/kube/gateway/deploymentcontroller.go:431-571`

**Process**:
1. User creates Gateway resource
2. istiod deployment controller reconciles Gateway
3. Creates Kubernetes resources:
   - **Deployment**: Envoy proxy pods
   - **Service**: Type `LoadBalancer` (default)

**Service Spec**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: gateway-xyz
  namespace: openshift-ingress
  labels:
    gateway.istio.io/managed: istio.io/gateway-controller
    gateway.networking.k8s.io/gateway-name: my-gateway
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 80
    protocol: TCP
  - name: https
    port: 443
    protocol: TCP
  selector:
    gateway.networking.k8s.io/gateway-name: my-gateway
```

### Step 2: Cloud Provider Allocates Load Balancer

**Process**:
1. Kubernetes cloud-controller-manager watches Service
2. Detects `type: LoadBalancer`
3. Calls cloud provider API to create load balancer:
   - **AWS**: Creates ELB/NLB/ALB
   - **GCP**: Creates TCP/HTTP(S) Load Balancer
   - **Azure**: Creates Azure Load Balancer
4. Waits for load balancer to become ready
5. Updates Service status:
   ```yaml
   status:
     loadBalancer:
       ingress:
       - hostname: a123456.us-east-1.elb.amazonaws.com  # AWS
       # OR
       - ip: 35.123.45.67  # GCP
   ```

**Platform-Specific Examples**:

**AWS**:
```yaml
status:
  loadBalancer:
    ingress:
    - hostname: a123456789abcdef-1234567890.us-east-1.elb.amazonaws.com
```

**GCP**:
```yaml
status:
  loadBalancer:
    ingress:
    - ip: 35.123.45.67
```

**Azure**:
```yaml
status:
  loadBalancer:
    ingress:
    - ip: 52.123.45.67
```

### Step 3: Istio Updates Gateway Status

**File**: `./src/istio/istio/pilot/pkg/config/kube/gateway/controller.go:82`

**Process**:
1. istiod watches Service resources it created
2. When `Service.Status.LoadBalancer.Ingress` is populated, triggers reconciliation
3. Status controller copies address to `Gateway.Status.Addresses`

**Gateway Status Update**:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
status:
  addresses:
  - type: Hostname  # or IPAddress
    value: a123456.us-east-1.elb.amazonaws.com
  conditions:
  - type: Programmed
    status: "True"
    reason: Programmed
  - type: Accepted
    status: "True"
    reason: Accepted
  listeners:
  - name: http
    supportedKinds:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
    conditions:
    - type: Programmed
      status: "True"
```

---

## Complete Data Flow

### End-to-End Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User creates Gateway with listener hostname                  │
│    hostname: *.apps.example.com                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. istiod deployment controller (Istio)                         │
│    - Creates Deployment (Envoy pods)                            │
│    - Creates Service (type: LoadBalancer)                       │
│    - Labels Service with:                                       │
│      gateway.istio.io/managed: istio.io/gateway-controller      │
│      gateway.networking.k8s.io/gateway-name: my-gateway         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Kubernetes cloud-controller-manager                          │
│    - Detects Service type: LoadBalancer                         │
│    - Creates cloud load balancer (AWS ELB/NLB)                  │
│    - Updates Service.Status.LoadBalancer.Ingress[0]:            │
│      hostname: a123.us-east-1.elb.amazonaws.com                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. istiod status controller (Istio)                             │
│    - Watches Service it created                                 │
│    - Copies Service address to Gateway.Status.Addresses:        │
│      - type: Hostname                                           │
│        value: a123.us-east-1.elb.amazonaws.com                  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. gateway-service-dns controller (cluster-ingress-operator)    │
│    - Watches Service with gateway.istio.io/managed label        │
│    - Gets Gateway.Spec.Listeners[].Hostname: *.apps.example.com │
│    - Gets Service.Status.LoadBalancer.Ingress[0].Hostname       │
│    - Creates DNSRecord CR:                                      │
│      dnsName: "*.apps.example.com."                             │
│      targets: ["a123.us-east-1.elb.amazonaws.com"]              │
│      recordType: CNAME                                          │
│      dnsManagementPolicy: Managed                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. dns controller (cluster-ingress-operator)                    │
│    - Gets DNSRecord CR                                          │
│    - Gets cloud credentials from secret                         │
│    - Creates AWS Route53 client                                 │
│    - Calls AWS API to create/update DNS record                  │
│    - Updates DNSRecord.Status.Zones[].Conditions: Published     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. AWS Route53                                                  │
│    - CNAME record created in hosted zone:                       │
│      *.apps.example.com -> a123.us-east-1.elb.amazonaws.com     │
│    - DNS propagates globally                                    │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. End User Access                                              │
│    curl https://myapp.apps.example.com                          │
│    ↓                                                            │
│    DNS resolves: myapp.apps.example.com                         │
│      -> *.apps.example.com (wildcard match)                     │
│      -> a123.us-east-1.elb.amazonaws.com (CNAME)                │
│      -> 52.1.2.3 (ELB IP)                                       │
│    ↓                                                            │
│    Traffic → AWS ELB → Envoy pods → Backend pods                │
└─────────────────────────────────────────────────────────────────┘
```

### Detailed Component Interaction

```
┌──────────────────┐
│ User             │
└────────┬─────────┘
         │ 1. Create GatewayClass
         │    controllerName: openshift.io/gateway-controller/v1
         ▼
┌──────────────────────────────────────────────────────────────┐
│ cluster-ingress-operator: gatewayclass controller           │
├──────────────────────────────────────────────────────────────┤
│ - Watches GatewayClass                                       │
│ - Creates OSSM subscription (if OLM enabled)                 │
│ - Creates Istio CR with Gateway API config                   │
└────────┬─────────────────────────────────────────────────────┘
         │ 2. Create Istio CR
         ▼
┌──────────────────────────────────────────────────────────────┐
│ sail-operator: istio controller                             │
├──────────────────────────────────────────────────────────────┤
│ - Watches Istio CR                                           │
│ - Creates IstioRevision CR                                   │
└────────┬─────────────────────────────────────────────────────┘
         │ 3. Create IstioRevision CR
         ▼
┌──────────────────────────────────────────────────────────────┐
│ sail-operator: istiorevision controller                     │
├──────────────────────────────────────────────────────────────┤
│ - Installs Istio via Helm                                    │
│ - Deploys istiod Deployment                                  │
└────────┬─────────────────────────────────────────────────────┘
         │ 4. istiod starts
         ▼
┌──────────────────────────────────────────────────────────────┐
│ istiod: Gateway API controllers running                     │
├──────────────────────────────────────────────────────────────┤
│ - Gateway controller                                         │
│ - Deployment controller                                      │
│ - Status controller                                          │
└────────┬─────────────────────────────────────────────────────┘
         │
         │ User creates Gateway
         ▼
┌──────────────────────────────────────────────────────────────┐
│ istiod: deployment controller                               │
├──────────────────────────────────────────────────────────────┤
│ - Creates Deployment (Envoy)                                 │
│ - Creates Service (LoadBalancer)                             │
└────────┬─────────────────────────────────────────────────────┘
         │ 5. Service created
         ▼
┌──────────────────────────────────────────────────────────────┐
│ Kubernetes cloud-controller-manager                         │
├──────────────────────────────────────────────────────────────┤
│ - Creates cloud load balancer                                │
│ - Updates Service.Status.LoadBalancer.Ingress               │
└────────┬─────────────────────────────────────────────────────┘
         │ 6. Service status updated
         ├────────────────────┬────────────────────────────────┐
         ▼                    ▼                                ▼
┌───────────────────┐ ┌──────────────────┐ ┌─────────────────────┐
│ istiod: status    │ │ cluster-ingress  │ │ User: HTTPRoute     │
│ controller        │ │ -operator:       │ │ references Gateway  │
│                   │ │ gateway-service  │ │                     │
│ Updates Gateway   │ │ -dns controller  │ │ istiod translates   │
│ .Status.Addresses │ │                  │ │ to Envoy config     │
│                   │ │ Creates DNSRecord│ │                     │
└───────────────────┘ └────────┬─────────┘ └─────────────────────┘
                               │ 7. DNSRecord created
                               ▼
                      ┌──────────────────────────────────────┐
                      │ cluster-ingress-operator:            │
                      │ dns controller                       │
                      ├──────────────────────────────────────┤
                      │ - Gets cloud credentials             │
                      │ - Creates DNS record in cloud        │
                      │ - Updates DNSRecord.Status           │
                      └──────────────────────────────────────┘
```

---

## File References

### OpenShift Cluster Ingress Operator

| Component | File Path | Lines |
|-----------|-----------|-----------|
| Gateway API CRD installation | `pkg/operator/controller/gatewayapi/controller.go` | 134-147 |
| GatewayClass controller | `pkg/operator/controller/gatewayclass/controller.go` | 79-150 |
| Istio CR creation | `pkg/operator/controller/gatewayclass/istio.go` | 29-64, 99-200 |
| Gateway Service DNS controller | `pkg/operator/controller/gateway-service-dns/controller.go` | 163-211 |
| DNSRecord spec builder | `pkg/resources/dnsrecord/dns.go` | 134-177 |
| DNS management policy | `pkg/resources/dnsrecord/dns.go` | 237-258 |
| DNS controller | `pkg/operator/controller/dns/controller.go` | 130-209 |
| Cloud DNS provider creation | `pkg/operator/controller/dns/controller.go` | 216-250 |
| Gateway API CRDs | `pkg/manifests/assets/gateway-api/*.yaml` | - |
| Controller constants/names | `pkg/operator/controller/names.go` | 61-81, 299-326 |

### Sail Operator

| Component | File Path | Lines |
|-----------|-----------|-----------|
| Istio CR types | `api/v1/istio_types.go` | 35-101 |
| Istio controller | `controllers/istio/istio_controller.go` | 72-102, 123-147 |
| IstioRevision CR types | `api/v1/istiorevision_types.go` | 28-46 |
| IstioRevision controller | `controllers/istiorevision/istiorevision_controller.go` | 106-125, 169-193 |
| Helm chart installation | `controllers/istiorevision/istiorevision_controller.go` | 169-193 |

### Istio

| Component | File Path | Lines |
|-----------|-----------|-----------|
| Gateway controller | `pilot/pkg/config/kube/gateway/controller.go` | 71-110 |
| Deployment controller setup | `pilot/pkg/config/kube/gateway/deploymentcontroller.go` | 92-115, 225-280 |
| Gateway reconciliation | `pilot/pkg/config/kube/gateway/deploymentcontroller.go` | 431-467 |
| Infrastructure creation | `pilot/pkg/config/kube/gateway/deploymentcontroller.go` | 469-572 |
| Class info configuration | `pilot/pkg/config/kube/gateway/deploymentcontroller.go` | 147-223 |

---

## Feature Gates

### OpenShift Feature Gates

**Location**: Checked in `pkg/operator/operator.go:136-137`

- **`FeatureGateGatewayAPI`**: Enables Gateway API CRD installation
- **`FeatureGateGatewayAPIController`**: Enables GatewayClass controller

### Istio Environment Variables

**Location**: Set in `pkg/operator/controller/gatewayclass/istio.go:100-147`

These are the critical environment variables that configure how istiod handles Gateway API:

| Variable | Value | Purpose |
|----------|-------|---------|
| `PILOT_ENABLE_GATEWAY_API` | `true` | Enable Gateway API support |
| `PILOT_ENABLE_ALPHA_GATEWAY_API` | `false` | Disable experimental features |
| `PILOT_ENABLE_GATEWAY_API_STATUS` | `true` | Enable status updates on Gateway resources |
| `PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER` | `true` | Enable automated Deployment/Service creation |
| `PILOT_ENABLE_GATEWAY_API_GATEWAYCLASS_CONTROLLER` | `false` | Disable built-in GatewayClass controller |
| `PILOT_GATEWAY_API_DEFAULT_GATEWAYCLASS_NAME` | `openshift-default` | Default GatewayClass name |
| `PILOT_GATEWAY_API_CONTROLLER_NAME` | `openshift.io/gateway-controller/v1` | Controller name to watch |
| `PILOT_MULTI_NETWORK_DISCOVER_GATEWAY_API` | `false` | Disable multi-network gateways |
| `ENABLE_GATEWAY_API_MANUAL_DEPLOYMENT` | `false` | Only allow automated deployment |
| `PILOT_ENABLE_GATEWAY_API_CA_CERT_ONLY` | `true` | Create CA bundle only where needed |
| `PILOT_ENABLE_GATEWAY_API_COPY_LABELS_ANNOTATIONS` | `false` | Prevent config injection via labels |

---

## Example: Complete Walkthrough

### Setup

1. **Cluster**: OpenShift 4.x on AWS
2. **DNS**: Cluster baseDomain: `openshift.example.com`
3. **Feature Gates**: GatewayAPI and GatewayAPIController enabled

### Step-by-Step

#### 1. Create GatewayClass

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1
  description: OpenShift default GatewayClass using Istio
```

**What happens**:
- cluster-ingress-operator `gatewayclass` controller detects GatewayClass
- Creates OSSM subscription (if OLM enabled)
- Creates Istio CR:
  ```yaml
  apiVersion: sailoperator.io/v1
  kind: Istio
  metadata:
    name: openshift-gateway
  spec:
    namespace: istio-system
    version: v1.28.0
    values:
      pilot:
        env:
          PILOT_ENABLE_GATEWAY_API: "true"
          # ... other env vars
  ```

#### 2. Istio Installation

**What happens**:
- sail-operator `istio` controller creates IstioRevision CR
- sail-operator `istiorevision` controller installs Istio via Helm
- istiod Deployment starts in `istio-system` namespace
- istiod starts Gateway API controllers

#### 3. Create Gateway

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: default
spec:
  gatewayClassName: openshift-default
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "*.apps.openshift.example.com"
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "*.apps.openshift.example.com"
    tls:
      mode: Terminate
      certificateRefs:
      - name: my-cert
```

**What happens**:
- istiod `deployment` controller creates:
  ```yaml
  # Deployment
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: my-gateway
    namespace: default
  spec:
    selector:
      matchLabels:
        gateway.networking.k8s.io/gateway-name: my-gateway
    template:
      spec:
        containers:
        - name: istio-proxy
          image: istio/proxyv2:1.28.0

  # Service
  apiVersion: v1
  kind: Service
  metadata:
    name: my-gateway
    namespace: default
    labels:
      gateway.istio.io/managed: istio.io/gateway-controller
      gateway.networking.k8s.io/gateway-name: my-gateway
  spec:
    type: LoadBalancer
    ports:
    - name: http
      port: 80
      protocol: TCP
    - name: https
      port: 443
      protocol: TCP
    selector:
      gateway.networking.k8s.io/gateway-name: my-gateway
  ```

#### 4. Load Balancer Provisioning

**What happens**:
- Kubernetes cloud-controller-manager detects Service type: LoadBalancer
- Creates AWS ELB
- Updates Service:
  ```yaml
  status:
    loadBalancer:
      ingress:
      - hostname: a1b2c3d4-1234567890.us-east-1.elb.amazonaws.com
  ```

#### 5. Gateway Status Update

**What happens**:
- istiod `status` controller watches Service
- Copies address to Gateway:
  ```yaml
  status:
    addresses:
    - type: Hostname
      value: a1b2c3d4-1234567890.us-east-1.elb.amazonaws.com
    conditions:
    - type: Programmed
      status: "True"
    - type: Accepted
      status: "True"
  ```

#### 6. DNS Record Creation

**What happens**:
- cluster-ingress-operator `gateway-service-dns` controller creates:
  ```yaml
  apiVersion: operatoringress.operator.openshift.io/v1
  kind: DNSRecord
  metadata:
    name: my-gateway-abc123-wildcard
    namespace: openshift-ingress
  spec:
    dnsName: "*.apps.openshift.example.com."
    targets:
    - "a1b2c3d4-1234567890.us-east-1.elb.amazonaws.com"
    recordType: CNAME
    recordTTL: 30
    dnsManagementPolicy: Managed
  ```

#### 7. Cloud DNS Update

**What happens**:
- cluster-ingress-operator `dns` controller:
  - Gets AWS credentials
  - Calls Route53 API
  - Creates CNAME: `*.apps.openshift.example.com` → `a1b2c3d4-1234567890.us-east-1.elb.amazonaws.com`
  - Updates DNSRecord:
    ```yaml
    status:
      zones:
      - dnsZone:
          id: /hostedzone/Z123ABC
        conditions:
        - type: Published
          status: "True"
          lastTransitionTime: "2025-01-15T10:00:00Z"
    ```

#### 8. Create HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: default
spec:
  parentRefs:
  - name: my-gateway
  hostnames:
  - "myapp.apps.openshift.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: my-app-service
      port: 8080
```

**What happens**:
- istiod `gateway` controller translates HTTPRoute to Envoy configuration
- Pushes config to Envoy proxies in Gateway Deployment
- HTTPRoute status updated with parent acceptance

#### 9. End User Access

```bash
curl https://myapp.apps.openshift.example.com
```

**What happens**:
1. DNS lookup: `myapp.apps.openshift.example.com`
   - Matches wildcard: `*.apps.openshift.example.com`
   - CNAME: `a1b2c3d4-1234567890.us-east-1.elb.amazonaws.com`
   - Resolves to ELB IPs: `52.1.2.3`, `52.1.2.4`
2. Client connects to `52.1.2.3:443`
3. AWS ELB forwards to Envoy pod
4. Envoy terminates TLS
5. Envoy routes to backend based on HTTPRoute
6. Request reaches `my-app-service:8080`

---

## Bare Metal Deployments (No Cloud Provider)

### The Challenge

On bare metal clusters (or virtualized environments without cloud integration), the Gateway API flow encounters two critical gaps:

1. **No LoadBalancer Implementation**: Kubernetes Services of type `LoadBalancer` remain in pending state indefinitely because there's no cloud-controller-manager to provision external load balancers.

2. **No DNS Management**: The DNS controller cannot publish records because there's no cloud DNS service (Route53, Cloud DNS, etc.) to integrate with.

### What Still Works

The OpenShift Gateway API implementation continues to function at the control plane level:

- **istiod deployment controller** still creates Deployments and Services
- **Gateway status** is updated by istiod
- **HTTPRoute reconciliation** works normally
- **Envoy configuration** is generated correctly
- **DNSRecord CRs** are created (but status shows "Unmanaged" or publish failures)

The traffic routing logic is intact - only the external connectivity and DNS are missing.

### What Breaks

#### 1. Service LoadBalancer Assignment

**Normal Cloud Flow**:
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer
status:
  loadBalancer:
    ingress:
    - hostname: a123.us-east-1.elb.amazonaws.com  # Populated by cloud-controller-manager
```

**Bare Metal Reality**:
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer
status:
  loadBalancer: {}  # Empty - no controller to populate this
```

**Impact**:
- `Gateway.Status.Addresses` remains empty
- DNSRecord targets have no value to point to
- External clients have no entry point

#### 2. DNS Record Publication

**Normal Cloud Flow**:
```yaml
apiVersion: operatoringress.operator.openshift.io/v1
kind: DNSRecord
status:
  zones:
  - conditions:
    - type: Published
      status: "True"
```

**Bare Metal Reality**:
```yaml
status:
  zones:
  - conditions:
    - type: Published
      status: "False"
      reason: NoDNSProvider
      message: "No DNS provider available for platform type None"
```

### Bare Metal Solutions

There are several approaches to make Gateway API work on bare metal:

#### Option 1: MetalLB + External DNS

**MetalLB** provides LoadBalancer IP assignment on bare metal:

```yaml
# MetalLB IPAddressPool
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: gateway-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.100-192.168.1.200
```

When MetalLB is installed:
1. MetalLB controller watches LoadBalancer Services
2. Assigns an IP from the pool to `Service.Status.LoadBalancer.Ingress[0].IP`
3. Announces the IP via ARP (Layer 2) or BGP (Layer 3)

**Result**:
```yaml
# Service now has an IP
status:
  loadBalancer:
    ingress:
    - ip: 192.168.1.100

# Gateway gets the address
status:
  addresses:
  - type: IPAddress
    value: 192.168.1.100
```

**External-DNS** can then publish DNS records:
- Watches Services and Gateways
- Publishes to external DNS providers (Cloudflare, AWS Route53, PowerDNS, etc.)
- Bypasses OpenShift's DNS controller entirely

**Limitations**:
- Still requires external DNS provider
- MetalLB IPs must be routable from clients
- No integration with OpenShift DNS controller

#### Option 2: NodePort Services + External Load Balancer

**Override Service Type**:

Use Gateway annotation to create NodePort instead of LoadBalancer:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  annotations:
    networking.istio.io/service-type: NodePort
spec:
  gatewayClassName: openshift-default
```

**Result**:
```yaml
# Service created with NodePort
apiVersion: v1
kind: Service
spec:
  type: NodePort
  ports:
  - port: 80
    nodePort: 30080
  - port: 443
    nodePort: 30443
```

**External Setup**:
1. Configure external hardware/software load balancer (HAProxy, NGINX, F5)
2. Point load balancer to all node IPs on NodePorts
3. Manually configure DNS to point to load balancer VIP

**Limitations**:
- Gateway.Status.Addresses remains empty (no controller to populate it)
- DNSRecord CRs created but unpublished
- Entirely manual external configuration
- No automation or integration

#### Option 3: HostNetwork Gateways

**Not officially supported**, but theoretically possible by modifying the deployment:

```yaml
# Gateway pod runs in host network namespace
spec:
  hostNetwork: true
  containers:
  - name: istio-proxy
    ports:
    - containerPort: 80
      hostPort: 80
    - containerPort: 443
      hostPort: 443
```

**Characteristics**:
- Envoy binds directly to node ports 80/443
- No Service needed
- Use node IPs directly
- Requires DaemonSet instead of Deployment for HA

**Limitations**:
- Not supported by istiod deployment controller
- Would require custom deployment controller
- Port conflicts if multiple gateways needed
- Security concerns (privileged ports)

#### Option 4: Manual DNS Management

For clusters where DNS cannot be automated:

**Set DNSRecord to Unmanaged**:

The `ManageDNSForDomain` function in `pkg/resources/dnsrecord/dns.go:237-258` already handles this for domains outside the cluster baseDomain. For bare metal, you could:

1. Use external domain names not matching cluster baseDomain
2. DNSRecord.Spec.dnsManagementPolicy automatically set to "Unmanaged"
3. Manually create DNS records pointing to Gateway entry points

**Example**:
```yaml
# Gateway with external domain
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
spec:
  listeners:
  - hostname: "*.myapp.example.com"  # Not a subdomain of cluster baseDomain
```

**Result**:
```yaml
# DNSRecord created but unmanaged
apiVersion: operatoringress.operator.openshift.io/v1
kind: DNSRecord
spec:
  dnsName: "*.myapp.example.com."
  dnsManagementPolicy: Unmanaged
```

**Manual Steps**:
1. Determine Gateway entry point (MetalLB IP, NodePort, etc.)
2. Manually create DNS A/CNAME record in your DNS server
3. Point `*.myapp.example.com` to the entry point

### Modified Data Flow for Bare Metal

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User creates Gateway with listener hostname                  │
│    hostname: *.apps.example.com                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. istiod deployment controller (Istio)                         │
│    - Creates Deployment (Envoy pods)                            │
│    - Creates Service (type: LoadBalancer)                       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. MetalLB controller (if installed)                            │
│    - Detects Service type: LoadBalancer                         │
│    - Assigns IP from pool: 192.168.1.100                        │
│    - Updates Service.Status.LoadBalancer.Ingress[0]:            │
│      ip: 192.168.1.100                                          │
│    - Announces IP via ARP/BGP                                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. istiod status controller (Istio)                             │
│    - Watches Service it created                                 │
│    - Copies Service IP to Gateway.Status.Addresses:             │
│      - type: IPAddress                                          │
│        value: 192.168.1.100                                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. gateway-service-dns controller (cluster-ingress-operator)    │
│    - Creates DNSRecord CR:                                      │
│      dnsName: "*.apps.example.com."                             │
│      targets: ["192.168.1.100"]                                 │
│      recordType: A                                              │
│      dnsManagementPolicy: Unmanaged (or Managed)                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. dns controller (cluster-ingress-operator)                    │
│    - Gets DNSRecord CR                                          │
│    - Platform type: None (or BareMetal)                         │
│    - No DNS provider available                                  │
│    - Updates DNSRecord.Status:                                  │
│      conditions:                                                │
│      - type: Published                                          │
│        status: "False"                                          │
│        reason: NoDNSProvider                                    │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. External DNS (if installed) OR Manual DNS                    │
│    Option A: External-DNS watches Gateway/Service               │
│      - Publishes A record to external provider                  │
│      - *.apps.example.com -> 192.168.1.100                      │
│                                                                 │
│    Option B: Manual DNS configuration                           │
│      - Admin creates A record in DNS server                     │
│      - *.apps.example.com -> 192.168.1.100                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. End User Access                                              │
│    curl https://myapp.apps.example.com                          │
│    ↓                                                            │
│    DNS resolves: myapp.apps.example.com                         │
│      -> *.apps.example.com (wildcard match)                     │
│      -> 192.168.1.100 (A record)                                │
│    ↓                                                            │
│    Traffic → MetalLB IP → Node → Envoy pods → Backend pods      │
└─────────────────────────────────────────────────────────────────┘
```

### Platform Type Detection

The OpenShift controllers determine the platform type from:

```yaml
apiVersion: config.openshift.io/v1
kind: Infrastructure
metadata:
  name: cluster
status:
  platformStatus:
    type: None  # or BareMetal, VSphere (without cloud integration)
```

When `platformStatus.type` is `None` or `BareMetal`:
- DNS controller skips cloud DNS provider initialization
- DNSRecord status shows publish failures
- Gateway functionality depends on alternative solutions

### Recommendations for Bare Metal

**Minimum Viable Setup**:
1. Install MetalLB for LoadBalancer IP assignment
2. Configure IP pool matching your network
3. Use NodePort as fallback if MetalLB unavailable
4. Manually manage DNS records

**Production Setup**:
1. MetalLB with BGP for high availability
2. External-DNS integrated with your DNS provider
3. External monitoring to verify DNS propagation
4. Document manual DNS procedures as backup

**Alternative Approach**:
- Don't use Gateway API on bare metal
- Use traditional Istio Gateway CRD with Ingress
- Use OpenShift Routes instead
- Wait for OpenShift to provide native bare metal integration

### Code References for Bare Metal Handling

| Location | File | Lines |
|----------|------|-------|
| Platform type check | `pkg/operator/controller/dns/controller.go` | 223-231 |
| DNS provider creation | `pkg/operator/controller/dns/controller.go` | 234-250 |
| DNS policy for domains | `pkg/resources/dnsrecord/dns.go` | 237-258 |
| LoadBalancer vs NodePort | Istio Gateway annotation `networking.istio.io/service-type` | - |

---

## Troubleshooting

### Gateway Not Getting Address

**Check**:
1. Is Service created? `kubectl get svc -l gateway.networking.k8s.io/gateway-name=my-gateway`
2. Does Service have type: LoadBalancer? `kubectl get svc <name> -o yaml | grep type:`
3. Is Service status populated? `kubectl get svc <name> -o yaml | grep -A5 loadBalancer:`
4. Check cloud-controller-manager logs

### DNS Record Not Created

**Check**:
1. Is gateway-service-dns controller running? Check cluster-ingress-operator logs
2. Does Service have required labels?
   - `gateway.istio.io/managed`
   - `gateway.networking.k8s.io/gateway-name`
3. Does Gateway have listener with hostname?
4. Is DNSRecord created? `kubectl get dnsrecord -n openshift-ingress`

### DNS Record Not Published to Cloud

**Check**:
1. Is DNSRecord.Spec.dnsManagementPolicy: Managed?
2. Check dns controller logs in cluster-ingress-operator
3. Are cloud credentials valid? `kubectl get secret cloud-credentials -n openshift-ingress-operator`
4. Check DNSRecord status: `kubectl get dnsrecord <name> -n openshift-ingress -o yaml`
5. Look for Published condition status and message

### Gateway Status Not Updated

**Check**:
1. Is `PILOT_ENABLE_GATEWAY_API_STATUS` set to "true"? Check Istio CR values
2. Check istiod logs for errors
3. Is istiod running? `kubectl get pods -n istio-system -l app=istiod`

---

## Additional Resources

- [Kubernetes Gateway API Specification](https://gateway-api.sigs.k8s.io/)
- [Istio Gateway API Documentation](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
- [OpenShift Service Mesh Documentation](https://docs.openshift.com/container-platform/latest/service_mesh/v2x/ossm-about.html)
- [Sail Operator GitHub](https://github.com/istio-ecosystem/sail-operator)
