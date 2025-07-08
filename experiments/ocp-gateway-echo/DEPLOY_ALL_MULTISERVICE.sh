#!/bin/bash

# Enhanced Gateway API Multi-Service Deployment Script
# This demonstrates path-based routing to different services

set -euo pipefail

echo "🚀 Starting Multi-Service Gateway API Deployment..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Check if running on OpenShift
if ! oc whoami &>/dev/null; then
    error "Not logged into OpenShift. Please run 'oc login' first."
    exit 1
fi

# Determine the best GatewayClass to use
get_gateway_class() {
    # Try to find Istio GatewayClass first
    if oc get gatewayclass istio --no-headers 2>/dev/null | grep -q "istio"; then
        echo "istio"
    elif oc get gatewayclass openshift-gateway --no-headers 2>/dev/null | grep -q "openshift-gateway"; then
        echo "openshift-gateway"
    else
        # Get the first available GatewayClass
        local first_class=$(oc get gatewayclass --no-headers -o custom-columns=":metadata.name" 2>/dev/null | head -1)
        if [ -n "$first_class" ]; then
            echo "$first_class"
        else
            echo "openshift-gateway"  # Fallback - will likely fail but provides clear error
        fi
    fi
}

# Create namespace
log "Creating namespace echo-test..."
oc new-project echo-test || oc project echo-test

# Configure Service Mesh mTLS
log "Configuring Service Mesh mTLS..."
log "📡 Enabling Istio sidecar injection..."
oc label namespace echo-test istio-injection=enabled --overwrite

log "🔒 Creating STRICT mTLS policy..."
cat <<EOF | oc apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: echo-test
spec:
  mtls:
    mode: STRICT
EOF

# Get the appropriate GatewayClass  
GATEWAY_CLASS=$(get_gateway_class)
log "Using GatewayClass: $GATEWAY_CLASS"

# Verify the GatewayClass exists and is accepted
if ! oc get gatewayclass "$GATEWAY_CLASS" --no-headers 2>/dev/null | grep -q "True"; then
    warn "⚠️  GatewayClass '$GATEWAY_CLASS' not found or not accepted"
    log "Available GatewayClasses:"
    oc get gatewayclass --no-headers 2>/dev/null || echo "   None found"
    error "Please ensure Gateway API controller is properly installed"
    exit 1
fi

# Deploy Gateway API CRDs if not present
log "Checking Gateway API CRDs..."
if ! oc get crd gateways.gateway.networking.k8s.io 2>/dev/null; then
    warn "Gateway API CRDs not found. Installing..."
    oc apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
fi

# Build and run TinyLB controller in background
log "Building and starting TinyLB controller..."
cd src/tinylb
make build

# Kill any existing TinyLB process
if [ -f /tmp/tinylb.pid ]; then
    OLD_PID=$(cat /tmp/tinylb.pid)
    if kill -0 $OLD_PID 2>/dev/null; then
        log "Stopping existing TinyLB controller (PID: $OLD_PID)"
        kill $OLD_PID
        sleep 2
    fi
fi

# Start TinyLB controller
log "Starting TinyLB controller..."
nohup make run > /tmp/tinylb.log 2>&1 &
echo $! > /tmp/tinylb.pid
log "TinyLB controller started (PID: $(cat /tmp/tinylb.pid))"

# Return to main directory
cd ../..

# Create certificates for Gateway API
log "Creating certificates for Gateway API..."
# Create self-signed certificate for Gateway API HTTPS with wildcard support
openssl req -x509 -newkey rsa:4096 -keyout /tmp/gateway-key.pem -out /tmp/gateway-cert.pem \
    -days 365 -nodes -subj "/CN=*.apps-crc.testing" \
    -addext "subjectAltName=DNS:*.apps-crc.testing,DNS:apps-crc.testing" 2>/dev/null

# Create Kubernetes TLS secret
oc create secret tls echo-tls-cert \
    --cert=/tmp/gateway-cert.pem \
    --key=/tmp/gateway-key.pem \
    -n echo-test --dry-run=client -o yaml | oc apply -f -

# Cleanup temporary files
rm -f /tmp/gateway-key.pem /tmp/gateway-cert.pem

# Deploy the original echo service
log "Deploying echo service..."
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
  namespace: echo-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo
        args:
        - "-text=Hello from Gateway API - Echo Service!"
        - "-listen=:8080"
        ports:
        - containerPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: echo
  namespace: echo-test
spec:
  selector:
    app: echo
  ports:
  - port: 80
    targetPort: 8080
EOF

# Deploy API service
log "Deploying API service..."
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: echo-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo
        args:
        - "-text=API Service Response - You hit /api/*"
        - "-listen=:8080"
        ports:
        - containerPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: echo-test
spec:
  selector:
    app: api-service
  ports:
  - port: 80
    targetPort: 8080
EOF

# Deploy static content service
log "Deploying static content service..."
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: static-service
  namespace: echo-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: static-service
  template:
    metadata:
      labels:
        app: static-service
    spec:
      containers:
      - name: static
        image: python:3.9-slim
        command: ["/bin/sh"]
        args: ["-c", "echo 'Static Content Service - You accessed /static/* path' > /tmp/response.txt && python -m http.server 8080 --directory /tmp --bind 0.0.0.0"]
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /response.txt
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10

---
apiVersion: v1
kind: Service
metadata:
  name: static-service
  namespace: echo-test
spec:
  selector:
    app: static-service
  ports:
  - port: 80
    targetPort: 8080
EOF

# Deploy foobar service
log "Deploying foobar service..."
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: foobar-service
  namespace: echo-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: foobar-service
  template:
    metadata:
      labels:
        app: foobar-service
    spec:
      containers:
      - name: foobar
        image: hashicorp/http-echo
        args:
        - "-text=FooBar Service - You hit exactly /foo/bar!"
        - "-listen=:8080"
        ports:
        - containerPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: foobar-service
  namespace: echo-test
spec:
  selector:
    app: foobar-service
  ports:
  - port: 80
    targetPort: 8080
EOF

# Wait for deployments to be ready
log "Waiting for deployments to be ready..."
oc wait --for=condition=available --timeout=300s deployment/echo -n echo-test
oc wait --for=condition=available --timeout=300s deployment/api-service -n echo-test
oc wait --for=condition=available --timeout=300s deployment/static-service -n echo-test
oc wait --for=condition=available --timeout=300s deployment/foobar-service -n echo-test

# Deploy Gateway API resources
log "Deploying Gateway API resources..."

# Create Gateway with both HTTP and HTTPS listeners
cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: echo-gateway
  namespace: echo-test
spec:
  gatewayClassName: $GATEWAY_CLASS
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "*.apps-crc.testing"
    allowedRoutes:
      namespaces:
        from: Same
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "*.apps-crc.testing"
    tls:
      mode: Terminate
      certificateRefs:
      - name: echo-tls-cert
    allowedRoutes:
      namespaces:
        from: Same
EOF

# Note: LoadBalancer service will be created automatically by the Gateway controller
# when it processes the Gateway resource. We don't create it manually.

# Create multi-path HTTPRoute
log "Creating multi-path HTTPRoute..."
cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: multi-path-route
  namespace: echo-test
spec:
  parentRefs:
  - name: echo-gateway
  hostnames:
  - "*.apps-crc.testing"
  rules:
  # Most specific first - exact match for /foo/bar
  - matches:
    - path:
        type: Exact
        value: /foo/bar
    backendRefs:
    - name: foobar-service
      port: 80
  
  # API routes - /api/*
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-service
      port: 80
  
  # Static content - /static/*  
  - matches:
    - path:
        type: PathPrefix
        value: /static
    backendRefs:
    - name: static-service
      port: 80
  
  # Default route - everything else goes to echo
  # Must be last due to catch-all nature
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: echo
      port: 80
EOF

# Wait for TinyLB to create routes
log "Waiting for TinyLB to create routes..."
sleep 30

# Get the hostname that TinyLB created automatically
TINYLB_HOSTNAME=$(oc get route -n echo-test -l tinylb.io/managed=true -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")

# Ensure TinyLB routes are configured for passthrough
log "Configuring TinyLB routes for TLS passthrough..."
if [ -n "$TINYLB_HOSTNAME" ]; then
    # Get the TinyLB route name
    TINYLB_ROUTE_NAME=$(oc get route -n echo-test -l tinylb.io/managed=true -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$TINYLB_ROUTE_NAME" ]; then
        log "🔄 Configuring route $TINYLB_ROUTE_NAME for TLS passthrough..."
        # Configure the route for passthrough TLS termination
        oc patch route "$TINYLB_ROUTE_NAME" -n echo-test --type='merge' \
            -p='{"spec":{"tls":{"termination":"passthrough","insecureEdgeTerminationPolicy":"None"}}}'
        
        # Update route to point to HTTPS port (443)
        oc patch route "$TINYLB_ROUTE_NAME" -n echo-test --type='merge' \
            -p='{"spec":{"port":{"targetPort":"443"}}}'
        
        log "✅ TinyLB route configured for TLS passthrough"
    else
        warn "⚠️  TinyLB route name not found"
    fi
else
    warn "⚠️  TinyLB hostname not found"
fi

# Check Gateway status
log "Checking Gateway status..."
oc get gateway echo-gateway -n echo-test -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "Gateway status not available yet"

# Test the multi-service setup
log "Testing multi-service routing..."

# Wait for DNS to be ready
sleep 10

echo ""
log "🎉 Multi-Service Gateway API deployment completed!"
echo ""

if [ -n "$TINYLB_HOSTNAME" ]; then
    log "✅ TinyLB created route with hostname: $TINYLB_HOSTNAME"
    echo ""
    log "Testing different paths:"
    echo ""

    # Test different paths
    warn "Testing default path (/):"
    echo "curl -k https://$TINYLB_HOSTNAME/"
    echo ""

    warn "Testing API path (/api):"
    echo "curl -k https://$TINYLB_HOSTNAME/api"
    echo ""

    warn "Testing static content (/static):"
    echo "curl -k https://$TINYLB_HOSTNAME/static"
    echo ""

    warn "Testing exact path (/foo/bar):"
    echo "curl -k https://$TINYLB_HOSTNAME/foo/bar"
    echo ""

    warn "Testing unmatched path (/foo/baz - should go to default):"
    echo "curl -k https://$TINYLB_HOSTNAME/foo/baz"
    echo ""
else
    warn "⚠️  TinyLB route not found. Check TinyLB logs:"
    echo "tail -f /tmp/tinylb.log"
    echo ""
fi

log "Gateway routing rules:"
echo "  /foo/bar (exact)  → foobar-service"
echo "  /api/*           → api-service"
echo "  /static/*        → static-service"
echo "  /*               → echo (default)"
echo ""

log "TinyLB controller log: /tmp/tinylb.log"
log "TinyLB controller PID: $(cat /tmp/tinylb.pid 2>/dev/null || echo 'not found')"
log "Available routes:"
oc get routes -n echo-test --no-headers 2>/dev/null | while read route host path admitted age; do
    echo "   $route -> $host"
done || echo "   No routes found yet"

echo ""
log "🔒 Security Validation..."

# Validate Service Mesh mTLS configuration
log "🔍 Validating Service Mesh mTLS configuration..."

# Check sidecar injection
log "📡 Checking sidecar injection..."
SIDECAR_PODS=$(oc get pods -n echo-test --no-headers 2>/dev/null | grep -c "2/2" || echo "0")
TOTAL_PODS=$(oc get pods -n echo-test --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$SIDECAR_PODS" -gt 0 ]; then
    log "✅ Sidecar injection working: $SIDECAR_PODS/$TOTAL_PODS pods have sidecars"
else
    warn "⚠️  Sidecar injection may not be working: $SIDECAR_PODS/$TOTAL_PODS pods have sidecars"
fi

# Check mTLS policy
log "🔒 Checking mTLS policy..."
if oc get peerauthentication default -n echo-test --no-headers 2>/dev/null | grep -q "default"; then
    log "✅ STRICT mTLS policy is active"
else
    warn "⚠️  STRICT mTLS policy not found"
fi

# Validate TLS configuration
log "🔍 Validating TLS configuration..."

# Check Gateway API certificate
log "🔐 Checking Gateway API certificate..."
if oc get secret echo-tls-cert -n echo-test --no-headers 2>/dev/null | grep -q "tls"; then
    log "✅ Gateway API TLS certificate exists"
else
    warn "⚠️  Gateway API TLS certificate not found"
fi

# Check TinyLB route passthrough configuration
log "🔄 Checking TinyLB route passthrough configuration..."
if [ -n "$TINYLB_ROUTE_NAME" ]; then
    ROUTE_TLS_TERMINATION=$(oc get route "$TINYLB_ROUTE_NAME" -n echo-test -o jsonpath='{.spec.tls.termination}' 2>/dev/null || echo "none")
    if [ "$ROUTE_TLS_TERMINATION" = "passthrough" ]; then
        log "✅ TinyLB route configured for TLS passthrough"
    else
        warn "⚠️  TinyLB route TLS termination: $ROUTE_TLS_TERMINATION (should be passthrough)"
    fi
else
    warn "⚠️  TinyLB route not found for validation"
fi

# Validate Gateway programming
log "🌐 Validating Gateway programming..."
GATEWAY_PROGRAMMED=$(oc get gateway echo-gateway -n echo-test -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "Unknown")
if [ "$GATEWAY_PROGRAMMED" = "True" ]; then
    log "✅ Gateway is programmed and ready"
else
    warn "⚠️  Gateway programming status: $GATEWAY_PROGRAMMED"
fi

echo ""
log "🎯 Security Test Commands:"
if [ -n "$TINYLB_HOSTNAME" ]; then
    echo ""
    log "Verify Gateway API TLS termination (not Router):"
    echo "curl -k https://$TINYLB_HOSTNAME/ -v 2>&1 | grep -E \"(subject|issuer|Certificate level)\""
    echo ""
    
    log "Verify HTTP/2 support (confirms Gateway API processing):"
    echo "curl -k https://$TINYLB_HOSTNAME/ -v 2>&1 | grep -E \"(ALPN|using HTTP/2)\""
    echo ""
    
    log "Check sidecar injection for all services:"
    echo "oc get pods -n echo-test -o wide"
    echo ""
    
    log "Verify mTLS policy is active:"
    echo "oc get peerauthentication -n echo-test"
    echo ""
    
    log "Check TinyLB route passthrough configuration:"
    echo "oc get route $TINYLB_ROUTE_NAME -n echo-test -o yaml | grep -A 5 -B 5 termination"
    echo ""
fi 