# OpenShift Ingress Operator Gateway API Implementation

## Overview

The OpenShift Cluster Ingress Operator provides a comprehensive Gateway API implementation that integrates with the OpenShift Service Mesh (Istio) to deliver cloud-native ingress capabilities. This implementation follows the Kubernetes Gateway API specification while providing OpenShift-specific integrations and enterprise features.

## Architecture

The Gateway API implementation consists of four main controllers that work together to provide a complete Gateway API experience:

### 1. Gateway API Controller (`gatewayapi`)
**Location**: `pkg/operator/controller/gatewayapi/`

The central orchestrator that manages the Gateway API ecosystem. This controller is responsible for:

- **CRD Management**: Creates and maintains Gateway API Custom Resource Definitions
- **RBAC Setup**: Ensures proper role-based access control for Gateway API resources
- **Feature Gate Monitoring**: Watches for Gateway API feature gate changes
- **Dependent Controller Orchestration**: Starts and manages other Gateway-related controllers
- **Status Reporting**: Updates the ingress cluster operator status with Gateway API information

**Managed CRDs**:
- `gatewayclasses.gateway.networking.k8s.io`
- `gateways.gateway.networking.k8s.io` 
- `httproutes.gateway.networking.k8s.io`
- `grpcroutes.gateway.networking.k8s.io`
- `referencegrants.gateway.networking.k8s.io`

**RBAC Resources**:
- `system:openshift:gateway-api:aggregate-to-admin` ClusterRole
- `system:openshift:gateway-api:aggregate-to-view` ClusterRole

### 2. Gateway Class Controller (`gatewayclass`)
**Location**: `pkg/operator/controller/gatewayclass/`

Manages GatewayClass resources and orchestrates the installation of the OpenShift Service Mesh (Istio) operator. This controller handles:

- **GatewayClass Lifecycle**: Watches for GatewayClass resources with the OpenShift controller name (`openshift.io/gateway-controller/v1`)
- **Service Mesh Operator Installation**: Creates and manages the ServiceMeshOperator subscription via OLM
- **InstallPlan Management**: Automatically approves InstallPlans for the Gateway API operator
- **Istio CR Management**: Creates and maintains the Istio custom resource for the service mesh deployment

**Key Constants**:
- Controller Name: `openshift.io/gateway-controller/v1`
- Default GatewayClass Name: `openshift-default`
- Istio CR Name: `openshift-gateway`

### 3. Gateway Labeler Controller (`gateway-labeler`)
**Location**: `pkg/operator/controller/gateway-labeler/`

Ensures that Gateway resources are properly labeled for Istio integration. This controller:

- **Label Management**: Adds the `istio.io/rev` label to Gateway resources
- **GatewayClass Association**: Only processes Gateways that reference a GatewayClass with the OpenShift controller name
- **Cross-Namespace Watching**: Monitors Gateways across all namespaces using a dedicated cache
- **Event-Driven Updates**: Responds to both GatewayClass and Gateway resource changes

### 4. Gateway Service DNS Controller (`gateway-service-dns`)
**Location**: `pkg/operator/controller/gateway-service-dns/`

Manages DNS records for services associated with Gateway resources. This controller provides:

- **Automatic DNS Record Creation**: Creates DNSRecord CRs for Gateway listener hostnames
- **Service Discovery**: Monitors services labeled with `gateway.istio.io/managed` that are created by Istio
- **Hostname Extraction**: Processes Gateway listener configurations to extract hostnames
- **DNS Policy Management**: Determines whether DNS should be managed or unmanaged based on platform configuration
- **Cleanup Operations**: Removes stale DNS records when Gateway listeners are modified

## Feature Gates and Prerequisites

The Gateway API implementation is controlled by two feature gates:

### GatewayAPI Feature Gate
- **Purpose**: Enables basic Gateway API CRD installation and RBAC setup
- **Effect**: When enabled, installs Gateway API CRDs and creates necessary RBAC resources
- **Required for**: Basic Gateway API resource creation and management

### GatewayAPIController Feature Gate  
- **Purpose**: Enables the full Gateway API controller functionality including Istio integration
- **Effect**: When enabled along with GatewayAPI, starts dependent controllers and enables Service Mesh integration
- **Required for**: Complete Gateway API implementation with traffic management

### Platform Capabilities Required
For full functionality, the following OpenShift cluster capabilities must be enabled:

- **OperatorLifecycleManager**: Required for ServiceMeshOperator installation
- **Marketplace**: Required for accessing operator catalogs and subscriptions

## Controller Name Coordination Architecture

### ❗ **Critical Understanding: `openshift.io/gateway-controller/v1` is Defined HERE**

The controller name `openshift.io/gateway-controller/v1` is **defined within this cluster-ingress-operator repository** and serves as the central coordination mechanism between OpenShift and Istio.

#### **Where It's Defined**
```go
// From pkg/operator/controller/names.go
const (
    // OpenShiftGatewayClassControllerName is the string by which a
    // gatewayclass identifies itself as belonging to OpenShift Istio.
    OpenShiftGatewayClassControllerName = "openshift.io/gateway-controller/v1"
)
```

#### **How OpenShift Controllers Use It**

**1. Gateway Class Controller** - Only processes GatewayClasses with this controller name:
```go
// pkg/operator/controller/gatewayclass/controller.go
func (r *reconciler) isOwnGatewayClass(class *gatewayapi_v1.GatewayClass) bool {
    return class.Spec.ControllerName == operatorcontroller.OpenShiftGatewayClassControllerName
}
```

**2. Gateway Labeler Controller** - Only labels Gateways that reference "our" GatewayClasses:
```go
// pkg/operator/controller/gateway-labeler/controller.go
if gatewayClass.Spec.ControllerName == operatorcontroller.OpenShiftGatewayClassControllerName {
    // Add istio.io/rev label to Gateway
}
```

**3. DNS Controller** - Only creates DNS records for Gateways using OpenShift's GatewayClasses

#### **How OpenShift Coordinates with Istio**

OpenShift passes this controller name to Istio via environment variables:

```go
// pkg/operator/controller/gatewayclass/istio.go
"PILOT_GATEWAY_API_CONTROLLER_NAME": controller.OpenShiftGatewayClassControllerName,
```

This tells Istio: **"Only manage Gateway resources that reference GatewayClasses with controller name `openshift.io/gateway-controller/v1`"**

#### **Division of Responsibilities**

| Component | Responsibility | Uses Controller Name For |
|---|---|---|
| **OpenShift Controllers** | Orchestration, DNS, Labeling | Filtering which GatewayClasses to process |
| **Istio** | Actual traffic management, status updates | Filtering which Gateways to manage |

```
┌─────────────────┐    Controller Name    ┌──────────────────┐
│ OpenShift       │◄──────────────────────►│ Istio            │
│ • DNS Records   │  "openshift.io/       │ • Gateway Status │
│ • Labeling      │   gateway-controller  │ • Traffic Rules  │  
│ • Orchestration │   /v1"                │ • Service Mesh   │
└─────────────────┘                       └──────────────────┘
```

#### **Multi-Implementation Support**

This architecture enables multiple Gateway API implementations to coexist:

```yaml
# OpenShift's GatewayClass
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1  # OpenShift handles this

---
# Hypothetical other implementation  
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller  # Other controller handles this
```

**Result**: Each implementation only processes resources it's responsible for, preventing conflicts.

## Integration with OpenShift Service Mesh

### ❗ **Critical Understanding: This is NOT a Full Service Mesh Deployment**

**Common misconception**: OpenShift Gateway API uses the full OpenShift Service Mesh.  
**Reality**: OpenShift installs the Service Mesh 3.0 operator but configures Istio in a **lightweight, gateway-only mode** - essentially just a reverse proxy.

#### **What Gets Installed vs. What Gets Used**

**Installed**:
- ✅ OpenShift Service Mesh 3.0 operator (`servicemeshoperator3`)  
- ✅ Istio control plane (Pilot/Istiod)
- ✅ Istio gateway components (Envoy proxies)

**NOT Used** (Explicitly Disabled):
- ❌ **Sidecar injection**: `EnableNamespacesByDefault: false`
- ❌ **CNI integration**: `Cni.Enabled: false`  
- ❌ **Ingress controller mode**: `IngressControllerMode: Off`
- ❌ **Service mesh features**: No mesh traffic management between services

#### **Istio Configuration Analysis**

From the code (`pkg/operator/controller/gatewayclass/istio.go`):

```go
// Service mesh features explicitly disabled
SidecarInjectorWebhook: &sailv1.SidecarInjectorConfig{
    EnableNamespacesByDefault: ptr.To(false),  // No automatic sidecar injection
},
Pilot: &sailv1.PilotConfig{
    Cni: &sailv1.CNIUsageConfig{
        Enabled: ptr.To(false),  // No CNI integration
    },
},
MeshConfig: &sailv1.MeshConfig{
    IngressControllerMode: sailv1.MeshConfigIngressControllerModeOff,  // No ingress mode
},

// Only Gateway API features enabled
pilotContainerEnv := map[string]string{
    "PILOT_ENABLE_GATEWAY_API": "true",                           // ✅ Gateway API only
    "PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER": "true",     // ✅ Create Envoy deployments
    "PILOT_ENABLE_GATEWAY_API_STATUS": "true",                    // ✅ Update Gateway status
    "PILOT_ENABLE_GATEWAY_API_GATEWAYCLASS_CONTROLLER": "false",  // ❌ OpenShift manages GatewayClass
}
```

#### **What You Actually Get**

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift Gateway API                    │
│                   (Lightweight Reverse Proxy)              │
├─────────────────────────────────────────────────────────────┤
│  ✅ HTTP/HTTPS termination and routing                     │
│  ✅ Gateway API resource management                        │  
│  ✅ Load balancer integration                              │
│  ✅ TLS certificate management                             │
│  ✅ Hostname-based routing via HTTPRoute                   │
├─────────────────────────────────────────────────────────────┤
│  ❌ NO sidecar proxies in application namespaces           │
│  ❌ NO service-to-service mesh traffic                     │
│  ❌ NO mutual TLS between services                         │
│  ❌ NO traffic policies (retry, circuit breaker, etc.)     │
│  ❌ NO observability mesh features                         │
│  ❌ NO service discovery mesh features                     │
└─────────────────────────────────────────────────────────────┘
```

#### **Why Use Service Mesh Operator for Just Gateway Functionality?**

1. **Code Reuse**: Leverages Istio's battle-tested Envoy proxy and Gateway API implementation
2. **Consistency**: Uses the same gateway technology as full Service Mesh deployments  
3. **Upgrade Path**: Users can potentially add full service mesh later
4. **Support**: Reuses Red Hat's supported Service Mesh operator infrastructure

This architecture gives you **modern Gateway API capabilities** without the complexity, resource overhead, or operational burden of a full service mesh deployment.

## Service Mesh Operator Installation Details

The Gateway API implementation integrates with OpenShift Service Mesh (Istio) by:

### Service Mesh Operator Installation
1. **Subscription Management**: Creates a Subscription CR for `servicemeshoperator3` in the `openshift-operators` namespace
2. **Automatic Approval**: Monitors and automatically approves InstallPlans for the specified operator version
3. **Version Control**: Uses configurable operator channel and version (default: `stable` channel, `servicemeshoperator3.v3.0.1`)

### Istio Configuration
1. **Istio CR Creation**: Creates an Istio custom resource named `openshift-gateway` 
2. **Namespace Management**: Deploys Istio components to the `openshift-ingress` namespace
3. **Dynamic Watching**: Establishes watches for Istio resources only after the Service Mesh operator is installed

### Gateway Integration
1. **Label Injection**: Automatically adds `istio.io/rev: openshift-gateway` labels to Gateway resources
2. **Service Association**: Monitors services with the `gateway.networking.k8s.io/gateway-name` label
3. **Resource Ownership**: Manages resources created by Istio for Gateway workloads

## DNS Management

The Gateway API implementation provides comprehensive DNS management:

### DNS Record Lifecycle
1. **Hostname Extraction**: Parses Gateway listener configurations to identify hostnames
2. **Record Creation**: Creates DNSRecord CRs in the gateway's namespace for each hostname
3. **Naming Convention**: Uses the format `{gateway-name}-{hostname-hash}-wildcard`
4. **Policy Determination**: Automatically determines if DNS should be managed based on platform and domain configuration

### DNS Policy Types
- **Managed DNS**: For domains that match the cluster's DNS configuration
- **Unmanaged DNS**: For external domains or custom DNS setups

### Cleanup and Maintenance
- **Stale Record Removal**: Automatically removes DNS records when Gateway listeners are updated or removed
- **Listener Monitoring**: Watches for changes to Gateway listener hostnames and updates DNS records accordingly

## Controller Startup and Lifecycle

### Initialization Flow
1. **Feature Gate Check**: Gateway API controller monitors the cluster's FeatureGate configuration
2. **CRD Installation**: When GatewayAPI feature gate is enabled, installs required CRDs and RBAC
3. **Controller Startup**: When GatewayAPIController feature gate is enabled, starts dependent controllers
4. **Capability Validation**: Ensures required platform capabilities (OLM, Marketplace) are available

### Controller Management
- **Unmanaged Controllers**: GatewayClass, Gateway-Labeler, and Gateway-Service-DNS controllers are unmanaged
- **Controlled Startup**: The Gateway API controller starts dependent controllers using `sync.Once` for thread safety
- **Error Handling**: Provides comprehensive error handling and logging throughout the startup process

## Status and Monitoring

### Cluster Operator Integration
The Gateway API implementation reports status through the ingress cluster operator:

- **Unmanaged CRD Tracking**: Reports names of unmanaged Gateway API CRDs in the cluster
- **Extension Status**: Uses the cluster operator's status extension to provide detailed information
- **Health Monitoring**: Integrates with OpenShift's operator health monitoring systems

### Resource Monitoring
- **CRD Watching**: Monitors Gateway API CRDs for external changes
- **Service Mesh Status**: Tracks Service Mesh operator and Istio installation status
- **DNS Record Status**: Monitors DNS record creation and management

## User Setup Requirements

### ⚠️ **Important: No Automatic GatewayClass Creation**

**OpenShift does NOT automatically create any GatewayClass resources.** Before users can create Gateway resources, a cluster administrator must manually create at least one GatewayClass.

### Manual GatewayClass Creation Required

Users must create a GatewayClass with the specific OpenShift controller name before they can create Gateway resources:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default  # Can be any name, but this is the expected default
spec:
  controllerName: openshift.io/gateway-controller/v1  # REQUIRED: Must be exactly this value
  description: "OpenShift Gateway API implementation using Istio"
```

**Critical Requirements:**
- **Controller Name**: Must be exactly `openshift.io/gateway-controller/v1`
- **Any other controller name will be ignored by OpenShift**
- **Cluster-scoped resource**: GatewayClass is a cluster-level resource that affects all namespaces

### User Workflow

1. **Administrator Creates GatewayClass**:
   ```bash
   oc apply -f - <<EOF
   apiVersion: gateway.networking.k8s.io/v1
   kind: GatewayClass
   metadata:
     name: openshift-default
   spec:
     controllerName: openshift.io/gateway-controller/v1
     description: "OpenShift default Gateway API implementation"
   EOF
   ```

2. **System Installs Service Mesh**: Once the GatewayClass exists, OpenShift automatically installs the Service Mesh operator and Istio

3. **Users Create Gateways** (must be in `openshift-ingress` namespace):
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: Gateway
   metadata:
     name: my-gateway
     namespace: openshift-ingress  # REQUIRED: Must be in this namespace for DNS to work
   spec:
     gatewayClassName: openshift-default  # Must reference an existing GatewayClass
     listeners:
     - name: http
       port: 80
       protocol: HTTP
       hostname: myapp.example.com
   ```

### Why No Automatic GatewayClass?

This design choice provides several benefits:
- **Administrative Control**: Only cluster administrators can define available gateway implementations
- **Security**: Prevents unauthorized gateway controller installations
- **Flexibility**: Administrators can create multiple GatewayClasses with different configurations
- **Policy Enforcement**: Enables organizational policies around gateway usage

## Gateway Namespace Requirements

### ⚠️ **Critical: Gateway Resources Must Be Created in `openshift-ingress`**

While Gateway resources are technically namespace-scoped and can be created in any namespace, **they will only function properly when created in the `openshift-ingress` namespace**.

**Why This Restriction Exists:**
- **DNS Controller Limitation**: The Gateway Service DNS controller only watches for Gateway resources in the `openshift-ingress` namespace
- **Service Co-location**: Istio creates Services in the same namespace as the Gateway
- **DNS Record Creation**: DNS records are only created for Gateways in the operand namespace

### What Happens in Different Namespaces

| Gateway Location | Istio Labels | Service Creation | DNS Records | HTTPRoute Attachment | External DNS Resolution |
|---|---|---|---|---|---|
| **`openshift-ingress`** | ✅ Applied | ✅ Created | ✅ Created | ✅ Works | ✅ Works |
| **Other namespaces** | ✅ Applied | ✅ Created | ❌ **NOT created** | ✅ **Still works** | ❌ **No automatic DNS** |

### ⚠️ **Important: HTTPRoutes Work Regardless of Namespace**

**Common misconception**: If a Gateway is in the wrong namespace, HTTPRoutes won't work.  
**Reality**: HTTPRoutes work perfectly - the issue is purely DNS resolution for external clients.

#### **What Still Works in Other Namespaces:**
- ✅ Gateway gets labeled and managed by Istio
- ✅ Istio creates Service (LoadBalancer) and Deployment
- ✅ HTTPRoutes attach to Gateway via `parentRefs`
- ✅ All routing logic (path matching, host headers, backends) functions normally
- ✅ Traffic reaching the LoadBalancer IP is routed correctly

#### **What Doesn't Work:**
- ❌ Automatic DNS records (no `*.example.com` → LoadBalancer IP mapping)
- ❌ External clients can't resolve hostnames without manual DNS setup

#### **Manual Workarounds for Other Namespaces:**
```bash
# 1. Get LoadBalancer IP from Gateway's Service
oc get service istio-gateway-my-gateway -n my-app
# NAME                     EXTERNAL-IP    PORT(S)
# istio-gateway-my-gateway 203.0.113.10   80:32000/TCP

# 2. Direct IP access works (HTTPRoutes process normally)
curl -H "Host: myapp.example.com" http://203.0.113.10/api
# ✅ Routes to backends based on HTTPRoute rules

# 3. Manual DNS record (external to OpenShift)
# Create: myapp.example.com → 203.0.113.10
# Then: curl http://myapp.example.com/api  # Works normally

# 4. Local testing override
echo "203.0.113.10 myapp.example.com" >> /etc/hosts
curl http://myapp.example.com/api  # Works with HTTPRoute rules
```

### Example: Correct Gateway Placement

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: openshift-ingress  # REQUIRED for DNS functionality
spec:
  gatewayClassName: openshift-default
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: myapp.example.com
```

### Controller Behavior by Namespace

**Gateway-Labeler Controller**: Watches all namespaces
- Adds `istio.io/rev: openshift-gateway` labels to any Gateway with the correct GatewayClass

**Gateway-Service-DNS Controller**: Only watches `openshift-ingress`
- Creates DNS records only for Gateways in the `openshift-ingress` namespace
- Ignores Gateways in all other namespaces

**Result**: Gateways outside `openshift-ingress` will be managed by Istio but will have no DNS records, making them unreachable from external traffic.

## Configuration

### Default Configuration
```go
// Default values used by the Gateway API implementation
const (
    DefaultGatewayAPIOperatorChannel = "stable"
    DefaultGatewayAPIOperatorVersion = "servicemeshoperator3.v3.0.1"
    OpenShiftGatewayClassControllerName = "openshift.io/gateway-controller/v1"
    OpenShiftDefaultGatewayClassName = "openshift-default"
    DefaultOperandNamespace = "openshift-ingress"
)
```

### Runtime Configuration
- **Operator Channel**: Configurable release channel for the Service Mesh operator
- **Operator Version**: Specific version of the Service Mesh operator to install
- **Namespace Configuration**: Operator and operand namespaces are configurable

## DNS Record Management Deep Dive

### ❗ **Critical Understanding: DNS is NOT About HTTPRoutes**

Many users assume DNS records are created based on HTTPRoute hostnames, but this is **completely incorrect**. Here's how DNS actually works in OpenShift's Gateway API:

#### **DNS Source: Gateway Listeners Only**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: openshift-ingress  # REQUIRED for DNS
spec:
  listeners:
  - name: https
    hostname: "*.example.com"    # ← THIS creates DNS records
    port: 443
    protocol: HTTPS
```

#### **HTTPRoute Hostnames Do NOT Create DNS**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  hostnames:
  - "app.example.com"    # ← This does NOT create DNS records!
  # This is only used for routing within the mesh
```

### How DNS Actually Works

#### **1. Gateway Listener Monitoring**
The Gateway Service DNS Controller:
- **Watches**: Only Gateway resources in `openshift-ingress` namespace
- **Triggers on**: Changes to Gateway `spec.listeners[].hostname` fields  
- **Ignores**: HTTPRoute resources entirely for DNS purposes
- **Creates**: OpenShift-specific DNSRecord custom resources

#### **2. DNSRecord Custom Resource Creation**
For each Gateway listener hostname, a DNSRecord CR is created:

```yaml
apiVersion: ingress.operator.openshift.io/v1
kind: DNSRecord
metadata:
  name: my-gateway-7bdcfc8f68-wildcard  # Hash-based naming
  namespace: openshift-ingress
spec:
  dnsName: "*.example.com."              # From Gateway listener (with trailing dot)
  targets: ["lb-12345.elb.amazonaws.com"] # From Gateway Service LoadBalancer status
  recordType: "CNAME"                    # Or "A" depending on cloud provider
  recordTTL: 30                          # Default 30 seconds
  dnsManagementPolicy: "Managed"         # Or "Unmanaged" for external domains
```

#### **3. External DNS Provider Integration**
A separate DNS controller processes DNSRecord CRs and creates actual DNS entries in:

**AWS Route53**:
- Creates A records with alias targets (most efficient)
- Falls back to CNAME records in GovCloud regions
- Automatically discovers ELB hosted zone IDs

**Google Cloud DNS**:
- Creates A records pointing to load balancer IPs
- Handles both public and private zones

**Azure DNS**:
- Creates A records in Azure DNS zones
- Supports both public and private DNS zones

**IBM Cloud DNS**:
- Supports both public (CIS) and private (DNS Services) providers
- Creates A or CNAME records based on target type

#### **4. Load Balancer Target Resolution**
DNS records point to the Gateway's Istio-managed Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: istio-gateway-my-gateway  # Created by Istio
  namespace: openshift-ingress
  labels:
    gateway.istio.io/managed: "openshift.io-gateway-controller"
    gateway.networking.k8s.io/gateway-name: "my-gateway"
status:
  loadBalancer:
    ingress:
    - hostname: "lb-12345.elb.amazonaws.com"  # ← DNS record target
```

### DNS Record Lifecycle

#### **Creation**
```go
// DNS record name format (from code)
fmt.Sprintf("%s-%s-wildcard", gateway.Name, util.Hash(hostname))
// Example: "my-gateway-7bdcfc8f68-wildcard"

// Automatic trailing dot addition
if !strings.HasSuffix(domain, ".") {
    domain = domain + "."
}
```

#### **Updates**
- DNS records are updated when Gateway listener hostnames change
- Stale DNS records are automatically deleted when hostnames are removed
- Load balancer target changes trigger DNS record updates

#### **Managed vs Unmanaged DNS Policy**
```go
// From ManageDNSForDomain function
func ManageDNSForDomain(domain string, platformStatus *configv1.PlatformStatus, dnsConfig *configv1.DNS) bool {
    // For AWS/GCP: only manage if domain is subdomain of cluster base domain
    // For other platforms: manage all domains
    return strings.HasSuffix(domain, "."+dnsConfig.Spec.BaseDomain)
}
```

## Gateway API in Single-Node Environments (SNO/CRC)

### ⚠️ **Problem: No External Load Balancers**

In single-node OpenShift (SNO) or Code Ready Containers (CRC) environments, there's no cloud provider to assign external IPs to LoadBalancer services. This creates a problem:

```bash
# Gateway Service stays in <pending> state
oc get service istio-gateway-my-gateway -n openshift-ingress
# NAME                     TYPE           EXTERNAL-IP   PORT(S)        AGE
# istio-gateway-my-gateway LoadBalancer   <pending>     80:32156/TCP   5m

# Gateway status shows Programmed=False
oc get gateway my-gateway -n openshift-ingress  
# NAME         CLASS              ADDRESS   PROGRAMMED   AGE
# my-gateway   openshift-default  <none>    False        5m
```

### ✅ **Solution: OpenShift Route Bridge**

You can create an OpenShift Route that points to the Gateway's service, effectively using OpenShift's built-in router (HAProxy) as the external entry point:

#### **Step 1: Create Gateway (as normal)**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-default
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: myapp.example.com
    tls:
      mode: Terminate
```

#### **Step 2: Create Route to Gateway Service**
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: gateway-bridge
  namespace: openshift-ingress
spec:
  host: myapp.example.com                    # Same hostname as Gateway listener
  to:
    kind: Service
    name: istio-gateway-my-gateway           # Istio-created service
    weight: 100
  port:
    targetPort: https                        # Target the Gateway's HTTPS port
  tls:
    termination: passthrough                 # Let Gateway handle TLS
    insecureEdgeTerminationPolicy: Redirect
```

#### **Step 3: Test the Flow**
```bash
# Route gets external hostname from OpenShift router
oc get route gateway-bridge -n openshift-ingress
# NAME             HOST/PORT                                    PATH   SERVICES                 PORT    TERMINATION     WILDCARD
# gateway-bridge   myapp.example.com                                   istio-gateway-my-gateway https   passthrough     None

# HTTPRoutes work normally through the Gateway
curl -k https://myapp.example.com/api
# ✅ Request flows: Route → Gateway Service → Istio Gateway → HTTPRoute backends
```

### **Why This Works**

1. **OpenShift Route** provides external access (via the cluster's *.apps domain)
2. **TLS Passthrough** means the Route just forwards encrypted traffic to the Gateway
3. **Gateway processes normally** - handles TLS termination, matches HTTPRoutes, etc.
4. **HTTPRoute rules work unchanged** - all Gateway API functionality is preserved

### **Limitations of Route Bridge**

❌ **Single hostname per Route**: Each Route can only handle one hostname  
❌ **No wildcard support**: Routes don't support wildcard hostnames like `*.example.com`  
❌ **Extra DNS step**: Need to point your DNS to the Route's hostname, not directly to a load balancer  
❌ **OpenShift-specific**: This workaround only works in OpenShift, not vanilla Kubernetes

### **Alternative: NodePort Access**

For development/testing, you can also access the Gateway directly via NodePort:

```bash
# Get NodePort from Gateway service
oc get service istio-gateway-my-gateway -n openshift-ingress
# NAME                     TYPE           PORT(S)                      
# istio-gateway-my-gateway LoadBalancer   80:32156/TCP,443:31234/TCP

# Access directly via node IP and NodePort
curl -k -H "Host: myapp.example.com" https://NODE_IP:31234/api
# ✅ Works but requires port specification and Host header
```

## Gateway Status Management

### ❗ **Critical Understanding: Istio Manages Gateway Status, Not OpenShift**

A common misconception is that OpenShift controllers update Gateway status. **This is incorrect.** OpenShift only manages DNS records - **Istio updates all Gateway status fields**.

#### **Gateway Status Flow**
```
1. Gateway created in openshift-ingress namespace
2. OpenShift gateway-labeler adds istio.io/rev=openshift-gateway label  
3. Istio sees labeled Gateway and creates:
   - Deployment (Envoy proxy pods)
   - Service (LoadBalancer type)
4. Cloud provider assigns external IP/hostname to Service
5. Istio updates Gateway status with:
   - status.addresses[]: [LoadBalancer IP/hostname]
   - status.conditions[]: Programmed=True (when ready)
6. OpenShift DNS controller sees Service LoadBalancer status
7. OpenShift creates DNSRecord CRs pointing to LoadBalancer
```

#### **Istio Configuration (from OpenShift code)**
```go
// Enable Istio to update status of Gateway API resources
"PILOT_ENABLE_GATEWAY_API_STATUS": "true"

// Enable automated deployment - Istio creates Services/Deployments  
"PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER": "true"
```

#### **Example Gateway Status**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: openshift-ingress
status:
  addresses:
  - type: IPAddress
    value: "203.0.113.10"                    # From cloud load balancer
  # OR for hostname-based load balancers (like AWS ELB):
  - type: Hostname  
    value: "lb-12345.elb.amazonaws.com"      # From AWS ELB
  conditions:
  - type: Accepted
    status: "True"
    reason: Accepted
    message: "Gateway has been accepted"
  - type: Programmed
    status: "True"                           # Set by Istio when LB is ready
    reason: Programmed
    message: "Gateway successfully programmed"
```

#### **"Programmed" Condition Details**
- **Set by**: Istio control plane (Pilot), NOT OpenShift
- **When**: After Istio creates the Service and it gets an external endpoint
- **Means**: Gateway infrastructure is ready to handle traffic
- **Required for**: OpenShift DNS controller to create DNS records (uses Service status)

#### **Checking Gateway Status**
```bash
# View Gateway status
oc get gateway my-gateway -n openshift-ingress -o yaml

# Quick status check (using print columns)  
oc get gateways -n openshift-ingress
# NAME         CLASS              ADDRESS                    PROGRAMMED   AGE
# my-gateway   openshift-default  lb-12345.elb.amazonaws.com True         5m

# Check the underlying Service Istio created
oc get services -n openshift-ingress -l gateway.networking.k8s.io/gateway-name=my-gateway
```

### Traffic Flow with DNS

#### **External Client Request**
```
1. Client makes request to app.example.com
2. DNS resolution: app.example.com → lb-12345.elb.amazonaws.com → 203.0.113.10
3. Request reaches cloud load balancer
4. Load balancer forwards to Istio Gateway Service  
5. Istio Gateway examines Host header and matches HTTPRoute
6. Request routed to application backend
```

#### **DNS Resolution Example**
```bash
$ dig app.example.com
;; ANSWER SECTION:
app.example.com.        30    IN    CNAME    lb-12345.elb.amazonaws.com.
lb-12345.elb.amazonaws.com. 60    IN    A        203.0.113.10

# Or with Route53 alias records:
app.example.com.        30    IN    A        203.0.113.10
```

### DNS Debugging

#### **Check DNSRecord Resources**
```bash
# List all DNS records
oc get dnsrecords -n openshift-ingress

# Examine specific DNS record
oc describe dnsrecord my-gateway-7bdcfc8f68-wildcard -n openshift-ingress

# Check DNS record status
oc get dnsrecord my-gateway-7bdcfc8f68-wildcard -n openshift-ingress -o yaml
```

#### **Verify Gateway Service**
```bash
# Check if Gateway service has load balancer endpoint
oc get services -n openshift-ingress -l gateway.networking.k8s.io/gateway-name=my-gateway

# Verify load balancer status
oc get service istio-gateway-my-gateway -n openshift-ingress -o jsonpath='{.status.loadBalancer}'
```

#### **Test DNS Resolution**
```bash
# Test external DNS resolution
dig +short app.example.com
nslookup app.example.com

# Check from inside cluster (should work even without external DNS)
oc run test-pod --image=curlimages/curl -it --rm -- curl -v http://app.example.com
```

#### **DNS Record Troubleshooting**
```bash
# Check if DNS controller is processing records
oc logs -n openshift-ingress-operator deployment/ingress-operator -c manager | grep -i dns

# Verify DNS configuration
oc get dns cluster -o yaml

# Check platform configuration
oc get infrastructure cluster -o jsonpath='{.status.platformStatus}'
```

## Security Considerations

### RBAC Implementation
- **Principle of Least Privilege**: ClusterRoles provide minimal necessary permissions
- **Role Aggregation**: Integrates with OpenShift's admin and view role aggregation
- **Resource Scoping**: Permissions are scoped to Gateway API resources only

### Network Security
- **Namespace Isolation**: Components are deployed in dedicated namespaces
- **Service Mesh Integration**: Leverages Istio's security features for traffic encryption and authentication
- **DNS Security**: Ensures DNS records are created with appropriate ownership and lifecycle management

## Troubleshooting

### Common Issues

1. **No GatewayClass Available (Most Common)**
   - **Symptom**: Cannot create Gateway resources, or Gateways remain in "Accepted: False" state
   - **Cause**: No GatewayClass exists with the correct controller name
   - **Solution**: Create a GatewayClass as shown in the User Setup Requirements section above
   - **Check**: `oc get gatewayclass` should show at least one GatewayClass with controller `openshift.io/gateway-controller/v1`

2. **Gateway in Wrong Namespace (Very Common)**
   - **Symptom**: Gateway appears to be working (has Istio labels) but external traffic doesn't reach applications
   - **Cause**: Gateway created outside the `openshift-ingress` namespace - no DNS records are created
   - **Solution**: Move the Gateway to the `openshift-ingress` namespace or recreate it there
   - **Check**: `oc get gateways -n openshift-ingress` and `oc get dnsrecords -n openshift-ingress`

3. **Feature Gates Not Enabled**
   - Check cluster FeatureGate configuration
   - Verify both GatewayAPI and GatewayAPIController gates are enabled

4. **Service Mesh Operator Installation Failures**
   - Verify OperatorLifecycleManager and Marketplace capabilities are enabled
   - Check for conflicting Service Mesh operator installations
   - Review InstallPlan approval status

5. **Gateway Resources Not Reconciled**
   - Verify Istio labels are present on Gateway resources (`istio.io/rev: openshift-gateway`)
   - Check GatewayClass controller name matches `openshift.io/gateway-controller/v1`
   - Ensure Istio control plane is running and healthy

6. **DNS Record Issues**
   - **Symptom**: External DNS resolution fails, traffic doesn't reach Gateway
   - **Cause**: DNSRecord CRs not created, incorrect DNS policy, or load balancer issues
   - **Solution**: Check Gateway listener hostnames, verify service LoadBalancer status, review DNS configuration
   - **Check**: `oc get dnsrecords -n openshift-ingress` and `oc get services -n openshift-ingress`

7. **HTTPRoute Hostnames Not Working (Common Misconception)**
   - **Symptom**: Created HTTPRoute with hostnames but DNS resolution fails
   - **Cause**: HTTPRoute hostnames do NOT create DNS records - only Gateway listener hostnames do
   - **Solution**: Ensure Gateway listeners have the correct hostnames configured
   - **Check**: Verify Gateway `spec.listeners[].hostname` matches your desired DNS name

8. **Gateway Status Shows Programmed=False**
   - **Symptom**: Gateway exists but status shows `Programmed: False` or `Unknown`
   - **Cause**: Istio hasn't successfully created the underlying Service/Deployment, or load balancer isn't ready
   - **Solution**: Check Istio deployment, Service status, and cloud provider load balancer
   - **Check**: `oc describe gateway my-gateway -n openshift-ingress` and `oc get services -n openshift-ingress`

9. **Gateway Has No Address in Status**
   - **Symptom**: Gateway shows `Programmed: True` but no addresses in status
   - **Cause**: Service LoadBalancer hasn't received external IP/hostname from cloud provider
   - **Solution**: Check cloud provider quotas, permissions, and Service events
   - **Check**: `oc describe service istio-gateway-my-gateway -n openshift-ingress`

10. **Expecting Full Service Mesh Features (Common Misconception)**
   - **Symptom**: No sidecar injection, no service-to-service mesh features
   - **Cause**: OpenShift Gateway API is NOT a full service mesh - it's lightweight gateway-only
   - **Reality**: Only provides HTTP/HTTPS ingress functionality, no mesh between services
   - **Solution**: Use OpenShift Service Mesh separately if you need full mesh capabilities

### Debugging Commands

```bash
# Check feature gate status
oc get featuregates.config.openshift.io cluster -o yaml

# Verify Gateway API CRDs
oc get crd | grep gateway.networking.k8s.io

# Check Service Mesh operator status
oc get subscription -n openshift-operators servicemeshoperator3

# Verify Istio installation
oc get istio openshift-gateway

# Check Gateway resources and labels
oc get gateways -A --show-labels

# Check Gateway status (addresses and conditions)
oc get gateways -n openshift-ingress
oc describe gateway YOUR_GATEWAY_NAME -n openshift-ingress

# Check Istio-created Service for Gateway
oc get services -n openshift-ingress -l gateway.networking.k8s.io/gateway-name=YOUR_GATEWAY_NAME
oc describe service istio-gateway-YOUR_GATEWAY_NAME -n openshift-ingress

# Review DNS records and their status
oc get dnsrecords -A
oc describe dnsrecords -n openshift-ingress

# Test DNS resolution from external
dig +short your-gateway-hostname.example.com
nslookup your-gateway-hostname.example.com

# Verify DNS controller logs
oc logs -n openshift-ingress-operator deployment/ingress-operator -c manager | grep -i dns

# Check Istio control plane health
oc get pods -n openshift-ingress -l app=istiod
```

This implementation provides a robust, enterprise-ready Gateway API solution that integrates seamlessly with OpenShift's existing infrastructure while providing the flexibility and power of the Kubernetes Gateway API specification. 