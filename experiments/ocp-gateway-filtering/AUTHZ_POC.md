# OpenShift Gateway API Authorization Proof of Concept

> **Objective**: Validate that Envoy filters work with OpenShift's lightweight Gateway API implementation by creating a header-based authorization filter that denies traffic unless a `FOO: BAR` header is present.

## Overview

This POC demonstrates:
1. **GatewayClass + Gateway + HTTPRoute** setup
2. **Echo server** deployment for testing
3. **EnvoyFilter** for custom authorization logic
4. **Validation** via curl testing

Expected outcome: Requests without `FOO: BAR` header are denied (403), requests with the header succeed (200).

## Prerequisites

- OpenShift cluster with Gateway API feature gates enabled (tested on CRC)
- `oc` CLI access with cluster-admin privileges
- Gateway API CRDs installed (should be automatic with feature gates)

## CRC-Specific Setup

If using Code Ready Containers (CRC), you'll need to add `127.0.0.1 authztest.apps-crc.testing` to your `/etc/hosts` file for local DNS resolution. This works because CRC uses a vsock interface that allows local resolution to reach the CRC cluster.

## Namespace Setup

Create the `authztest` namespace for our POC resources:

```bash
oc create namespace authztest
```

## DNS Strategy Choice

You have two options for external access:

### Option A: Gateway API DNS (Requires openshift-ingress)
- Gateway in `openshift-ingress` namespace for automatic DNS record creation
- Uses cloud provider load balancers directly
- Requires external load balancer support

### Option B: OpenShift Route Bridge (Gateway can be in authztest)
- Gateway in `authztest` namespace
- Create OpenShift Route pointing to Gateway service  
- Uses OpenShift's built-in router (HAProxy) for external access
- Works in SNO/CRC environments without external load balancers

**This POC will show Option B** - Gateway in `authztest` namespace with Route bridge.

## Step 1: Create GatewayClass

First, create the required GatewayClass resource:

```yaml
# gatewayclass.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: authztest-gateway-class
spec:
  controllerName: openshift.io/gateway-controller/v1
  description: "OpenShift Gateway API implementation for authorization POC"
```

Apply:
```bash
oc apply -f gatewayclass.yaml
```

Verify:
```bash
oc get gatewayclass authztest-gateway-class
# Should show Accepted=True after a few moments
```

## Step 2: Create Gateway

Create a Gateway in the `authztest` namespace (since we'll use Route for external access):

```yaml
# gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: authztest-gateway
  namespace: authztest  # Can be in authztest since we're using Route for external access
spec:
  gatewayClassName: authztest-gateway-class
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "authztest.apps-crc.testing"  # CRC domain
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "authztest.apps-crc.testing"  # CRC domain
    tls:
      mode: Terminate
```

Apply:
```bash
oc apply -f gateway.yaml
```

Verify:
```bash
oc get gateway authztest-gateway -n authztest
# Should show Programmed=True and an address after Istio processes it

# Check the underlying service created by Istio
oc get services -n authztest -l gateway.networking.k8s.io/gateway-name=authztest-gateway
```

## Step 3: Deploy Echo Server

Deploy a simple echo server for testing that returns all received headers in plaintext format:

```yaml
# echo-server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-server
  namespace: authztest
  labels:
    app: echo-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-server
  template:
    metadata:
      labels:
        app: echo-server
    spec:
      containers:
      - name: echo-server
        image: ghcr.io/aslafy-z/echo-headers:latest
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
---
apiVersion: v1
kind: Service
metadata:
  name: echo-server
  namespace: authztest
spec:
  selector:
    app: echo-server
  ports:
  - name: http
    port: 80
    targetPort: 8080
  type: ClusterIP
```

Apply:
```bash
oc apply -f echo-server.yaml
```

Verify:
```bash
oc get pods -l app=echo-server -n authztest
oc get service echo-server -n authztest
```

## Step 4: Create HTTPRoute

Create an HTTPRoute to connect the Gateway to the echo server:

```yaml
# httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: authztest-route
  namespace: authztest
spec:
  parentRefs:
  - name: authztest-gateway
    # No namespace needed - same namespace as HTTPRoute
  hostnames:
  - "authztest.apps-crc.testing"  # Must match Gateway hostname
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: echo-server
      port: 80
```

Apply:
```bash
oc apply -f httproute.yaml
```

Verify:
```bash
oc get httproute authztest-route -n authztest
# Should show Accepted=True and parents properly referenced
```

## Step 5: Create OpenShift Route for External Access

Create an OpenShift Route that points to the Gateway service for external access:

```yaml
# gateway-route.yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: authztest-gateway-route
  namespace: authztest
spec:
  host: authztest.apps-crc.testing  # CRC domain
  to:
    kind: Service
    name: istio-gateway-authztest-gateway  # Istio-created service name
    weight: 100
  port:
    targetPort: http  # Target the Gateway's HTTP port
  tls:
    termination: edge  # Terminate TLS at the Route level
    insecureEdgeTerminationPolicy: Redirect
```

Apply:
```bash
oc apply -f gateway-route.yaml
```

Verify:
```bash
oc get route authztest-gateway-route -n authztest
# Should show the route hostname assigned by OpenShift
```

## Step 6: Test Basic Connectivity (Pre-Filter)

Before adding the authorization filter, verify basic connectivity:

```bash
# Get the Route's hostname (should be authztest.apps-crc.testing)
ROUTE_HOSTNAME=$(oc get route authztest-gateway-route -n authztest -o jsonpath='{.spec.host}')
echo "Route hostname: $ROUTE_HOSTNAME"
# Expected: authztest.apps-crc.testing

# Test basic connectivity (should work)
curl -kL http://$ROUTE_HOSTNAME/
# Should return plaintext response showing all received headers
# May redirect from HTTP to HTTPS first
```

## Step 7: Create Authorization EnvoyFilter

Create an EnvoyFilter that denies requests unless they contain `FOO: BAR` header:

```yaml
# authz-filter.yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: authztest-header-filter
  namespace: authztest  # MUST be same namespace as Gateway
spec:
  workloadSelector:
    labels:
      gateway.networking.k8s.io/gateway-name: "authztest-gateway"
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.lua
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
          inline_code: |
            function envoy_on_request(request_handle)
              -- Get the FOO header
              local foo_header = request_handle:headers():get("foo")
              
              -- Check if header exists and equals "BAR"
              if foo_header == nil or foo_header ~= "BAR" then
                -- Deny the request
                request_handle:respond({
                  [":status"] = "403",
                  ["content-type"] = "text/plain"
                }, "Access denied: Missing or invalid FOO header. Expected FOO: BAR")
                return
              end
              
              -- Allow the request to continue
              request_handle:logInfo("Authorization successful: FOO header validated")
            end
```

Apply:
```bash
oc apply -f authz-filter.yaml
```

Verify the EnvoyFilter was applied:
```bash
oc get envoyfilter authztest-header-filter -n authztest
oc describe envoyfilter authztest-header-filter -n authztest
```

## Step 8: Test Authorization Filter

### Test 1: Request WITHOUT Required Header (Should Fail)

```bash
# This should return 403 Forbidden
# Using -kLv: follow redirects (-L), skip cert verification (-k), verbose (-v)
curl -kLv http://$ROUTE_HOSTNAME/

# Expected output (after any redirects):
# < HTTP/1.1 403 Forbidden
# < content-type: text/plain
# Access denied: Missing or invalid FOO header. Expected FOO: BAR
```

### Test 2: Request WITH Wrong Header Value (Should Fail)

```bash
# This should also return 403 Forbidden
curl -kLv -H "FOO: WRONG" http://$ROUTE_HOSTNAME/

# Expected output (after any redirects):
# < HTTP/1.1 403 Forbidden
# Access denied: Missing or invalid FOO header. Expected FOO: BAR
```

### Test 3: Request WITH Correct Header (Should Succeed)

```bash
# This should return 200 OK and echo server response
curl -kLv -H "FOO: BAR" http://$ROUTE_HOSTNAME/

# Expected output (after any redirects):
# < HTTP/1.1 200 OK
# Host: [route hostname]
# Foo: BAR
# User-Agent: curl/7.68.0
# Accept: */*
# [All other headers in plaintext format]
```

### Test 4: Test Different Paths

```bash
# Test different paths - all should require the header
curl -kL -H "FOO: BAR" http://$ROUTE_HOSTNAME/api/test
curl -kL -H "FOO: BAR" http://$ROUTE_HOSTNAME/health
```

**Note**: OpenShift Routes often redirect HTTP to HTTPS (302 redirects). The curl flags handle this:
- `-L`: Follow redirects automatically
- `-k`: Skip SSL certificate verification (for self-signed certs)  
- `-v`: Show verbose output including redirect flow

## Step 9: Troubleshooting

### CRC-Specific Issues

**DNS Resolution Failures**:
If curl fails with DNS resolution errors, verify your `/etc/hosts` entry is correct. You can also test direct IP access if needed:

```bash
# Get CRC IP for direct access if DNS fails
CRC_IP=$(crc ip)
echo "CRC IP: $CRC_IP"
# You can access directly via IP if needed (though this bypasses the Route)
```

### Check Gateway Pod Logs

```bash
# Find the Gateway pod
GATEWAY_POD=$(oc get pods -n authztest -l gateway.networking.k8s.io/gateway-name=authztest-gateway -o jsonpath='{.items[0].metadata.name}')
echo "Gateway Pod: $GATEWAY_POD"

# Check Envoy access logs
oc logs -n authztest $GATEWAY_POD -c istio-proxy | tail -20

# Check for Lua script logs
oc logs -n authztest $GATEWAY_POD -c istio-proxy | grep "Authorization successful"
```

### Verify EnvoyFilter Configuration

```bash
# Dump Envoy configuration to verify filter was applied
oc exec -n authztest $GATEWAY_POD -c istio-proxy -- curl -s localhost:15000/config_dump | jq '.configs[2].dynamic_listeners[].active_state.listener.filter_chains[].filters[] | select(.name == "envoy.filters.network.http_connection_manager") | .typed_config.http_filters[] | select(.name == "envoy.filters.http.lua")'
```

### Check EnvoyFilter Status

```bash
# Verify the EnvoyFilter is being processed
oc get envoyfilter -n authztest
oc describe envoyfilter authztest-header-filter -n authztest

# Check if there are any errors in the Istio control plane
oc logs -n openshift-ingress -l app=istiod | grep -i error
```

## Step 10: Advanced Testing

### Test Case Sensitivity

```bash
# Test if header matching is case sensitive
curl -kL -H "foo: bar" http://$ROUTE_HOSTNAME/
curl -kL -H "FOO: bar" http://$ROUTE_HOSTNAME/
curl -kL -H "Foo: Bar" http://$ROUTE_HOSTNAME/
```

### Test Multiple Headers

```bash
# Test with multiple headers including the required one
curl -kL -H "FOO: BAR" \
     -H "Authorization: Bearer token123" \
     -H "X-User-ID: testuser" \
     http://$ROUTE_HOSTNAME/
```

### Performance Test

```bash
# Simple performance test to see filter overhead
time for i in {1..10}; do
  curl -kLs -H "FOO: BAR" http://$ROUTE_HOSTNAME/ > /dev/null
done
```

## Expected Results

✅ **Success Criteria**:
1. Requests without `FOO: BAR` header return **403 Forbidden**
2. Requests with wrong header value return **403 Forbidden**  
3. Requests with correct `FOO: BAR` header return **200 OK** with echo server response
4. EnvoyFilter successfully integrates with Gateway API without conflicts
5. Authorization logic executes at the gateway level before reaching backend

❌ **Failure Indicators**:
- All requests succeed regardless of headers (filter not applied)
- EnvoyFilter resource shows errors or isn't accepted
- Gateway pod crashes or shows Lua script errors
- Requests fail with 500 errors (configuration issue)

## Cleanup

```bash
# Remove all POC resources
oc delete route authztest-gateway-route -n authztest
oc delete httproute authztest-route -n authztest
oc delete envoyfilter authztest-header-filter -n authztest
oc delete gateway authztest-gateway -n authztest
oc delete gatewayclass authztest-gateway-class
oc delete -f echo-server.yaml
oc delete namespace authztest
```

## Alternative: ext_authz Version

For a more production-like setup, you could replace the Lua filter with an `ext_authz` filter:

```yaml
# authz-external-filter.yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: authztest-ext-authz-filter
  namespace: authztest
spec:
  workloadSelector:
    labels:
      gateway.networking.k8s.io/gateway-name: "authztest-gateway"
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.ext_authz
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
          http_service:
            server_uri:
              uri: http://auth-service.auth.svc.cluster.local:8080
              cluster: outbound|8080||auth-service.auth.svc.cluster.local
              timeout: 5s
            authorization_request:
              allowed_headers:
                patterns:
                - exact: "foo"
                - exact: "authorization"
          failure_mode_allow: false
```

This would require deploying a separate authorization service, but provides more flexibility and production readiness.

## Conclusion

This POC validates that **Envoy filters work correctly with OpenShift's lightweight Gateway API implementation**, demonstrating that you can leverage Envoy's powerful filtering capabilities while using the simpler Gateway API for traffic routing. The plaintext header output from the echo server makes it easy to verify that authorized requests pass through with the required `FOO: BAR` header intact.

The key insights:
- ✅ EnvoyFilter resources integrate seamlessly with Gateway-created Envoy proxies
- ✅ Custom authorization logic can be implemented at the gateway level
- ✅ Gateway API and Istio EnvoyFilter can coexist without conflicts
- ✅ Advanced Envoy features remain available despite the lightweight service mesh deployment

### Namespace Architecture with Route Bridge

This POC demonstrates a flexible namespace architecture using OpenShift Route bridge:

- **Gateway**: Can be in any namespace (`authztest`) since we use Route for external access
- **EnvoyFilter**: Must be in same namespace as Gateway (`authztest`)
- **HTTPRoute**: Same namespace as Gateway (`authztest`) for simplicity
- **OpenShift Route**: Same namespace as Gateway (`authztest`)
- **Application Services**: Same namespace as Gateway (`authztest`)
- **GatewayClass**: Cluster-scoped resource, no namespace

This approach allows you to **organize all related resources in a single namespace** while **using OpenShift Routes for external access**. This is especially useful for:
- **SNO/CRC environments** without external load balancers
- **Development clusters** where DNS management is complex
- **Multi-tenant scenarios** where each team manages their own namespace

### CRC-Specific Benefits

Using this Route bridge approach in CRC provides several advantages:
- ✅ **No external load balancer required** - uses CRC's built-in router
- ✅ **Simple DNS setup** - just add one line to `/etc/hosts`
- ✅ **Complete local testing** - entire flow works on a laptop
- ✅ **Identical behavior** to production OpenShift clusters (just different external access method)
- ✅ **Easy debugging** - all components in one namespace, simple curl testing 