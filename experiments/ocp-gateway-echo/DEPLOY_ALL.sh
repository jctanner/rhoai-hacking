#!/bin/bash
set -euo pipefail

NAMESPACE="echo-test"
APP_NAME="echo"
HOST="echo.apps-crc.testing"
ECHO_IMAGE="hashicorp/http-echo"
ECHO_TEXT="Hello from Gateway API"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}$1${NC}"; }
echo_success() { echo -e "${GREEN}$1${NC}"; }
echo_warning() { echo -e "${YELLOW}$1${NC}"; }
echo_error() { echo -e "${RED}$1${NC}"; }

# Function to check if Service Mesh 3.0 is ready
check_service_mesh() {
    echo_info "🔍 Checking Service Mesh 3.0 status..."
    
    # Check if Istio pods are running
    if ! oc get pods -n istio-system --no-headers 2>/dev/null | grep -q "Running"; then
        echo_warning "⚠️  Warning: No Istio pods found in istio-system namespace"
        echo_warning "   Service Mesh 3.0 control plane may not be ready"
        return 1
    else
        echo_success "✅ Istio control plane pods found"
    fi
    
    # Check available GatewayClasses
    echo_info "🔍 Checking available GatewayClasses..."
    if ! oc get gatewayclass --no-headers 2>/dev/null | head -5; then
        echo_warning "⚠️  Warning: No GatewayClasses found"
        echo_warning "   Service Mesh 3.0 may not be providing Gateway API support yet"
        return 1
    fi
    return 0
}

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

# Deploy TinyLB Controller
deploy_tinylb_controller() {
    echo_info "🤖 Deploying TinyLB Controller..."
    
    # Check if TinyLB source exists
    if [ ! -d "src/tinylb" ]; then
        echo_error "❌ TinyLB source not found at src/tinylb"
        echo_error "   Please ensure TinyLB controller is available"
        return 1
    fi
    
    # Build TinyLB if needed
    if [ ! -f "src/tinylb/bin/manager" ]; then
        echo_info "🔨 Building TinyLB controller..."
        cd src/tinylb
        make build
        cd ../..
    fi
    
    # Deploy TinyLB controller manifests
    echo_info "📦 Deploying TinyLB RBAC and controller..."
    cd src/tinylb
    oc apply -f config/rbac/ || true
    cd ../..
    
    # Start TinyLB controller in background
    echo_info "🚀 Starting TinyLB controller..."
    cd src/tinylb
    nohup make run > /tmp/tinylb.log 2>&1 &
    TINYLB_PID=$!
    echo $TINYLB_PID > /tmp/tinylb.pid
    cd ../..
    
    echo_success "✅ TinyLB controller started (PID: $TINYLB_PID)"
    echo_info "   Log: tail -f /tmp/tinylb.log"
}

# Create TLS certificates for Gateway API
create_certificates() {
    echo_info "🔒 Creating TLS certificates for Gateway API..."
    
    # Create self-signed certificate for Gateway API HTTPS
    openssl req -x509 -newkey rsa:4096 -keyout /tmp/gateway-key.pem -out /tmp/gateway-cert.pem \
        -days 365 -nodes -subj "/CN=$HOST" 2>/dev/null
    
    # Create Kubernetes TLS secret
    oc create secret tls echo-tls-cert \
        --cert=/tmp/gateway-cert.pem \
        --key=/tmp/gateway-key.pem \
        -n $NAMESPACE || true
    
    # Cleanup temporary files
    rm -f /tmp/gateway-key.pem /tmp/gateway-cert.pem
    
    echo_success "✅ TLS certificate created as echo-tls-cert"
}

# Configure Service Mesh mTLS
configure_service_mesh() {
    echo_info "🔐 Configuring Service Mesh mTLS..."
    
    # Enable sidecar injection for namespace
    echo_info "📡 Enabling Istio sidecar injection..."
    oc label namespace $NAMESPACE istio-injection=enabled --overwrite
    
    # Create strict mTLS policy
    echo_info "🔒 Creating STRICT mTLS policy..."
    cat <<EOF | oc apply -n $NAMESPACE -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: $NAMESPACE
spec:
  mtls:
    mode: STRICT
EOF
    
    echo_success "✅ Service Mesh mTLS configured"
}

# Create HTTPS Gateway with both HTTP and HTTPS listeners
create_https_gateway() {
    echo_info "🌐 Creating Gateway with HTTPS support..."
    
    cat <<EOF | oc apply -n $NAMESPACE -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: echo-gateway
  labels:
    app: $APP_NAME
spec:
  gatewayClassName: $GATEWAY_CLASS_NAME
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "$HOST"
    allowedRoutes:
      namespaces:
        from: Same
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "$HOST"
    tls:
      mode: "Terminate"
      certificateRefs:
      - name: echo-tls-cert
    allowedRoutes:
      namespaces:
        from: Same
EOF
    
    echo_success "✅ HTTPS Gateway created"
}

# Create OpenShift Routes with passthrough mode
create_routes() {
    echo_info "🛤️  Creating OpenShift Routes..."
    
    # Wait for TinyLB to create the LoadBalancer route
    echo_info "⏳ Waiting for TinyLB to create LoadBalancer route..."
    sleep 5
    
    # Create the Gateway API route for echo.apps-crc.testing
    echo_info "🌐 Creating Gateway API route..."
    oc expose service echo-gateway-istio --hostname=$HOST --name=echo-gateway-route --port=80 -n $NAMESPACE || true
    
    # Configure route for passthrough mode (Gateway API handles TLS)
    echo_info "🔄 Configuring route passthrough mode..."
    oc patch route echo-gateway-route -n $NAMESPACE --type='merge' \
        -p='{"spec":{"tls":{"termination":"passthrough","insecureEdgeTerminationPolicy":null}}}' || true
    
    # Update route to point to HTTPS port
    oc patch route echo-gateway-route -n $NAMESPACE --type='merge' \
        -p='{"spec":{"port":{"targetPort":"443"}}}' || true
    
    echo_success "✅ OpenShift Routes configured"
}

# Restart deployments to get sidecars
restart_deployments() {
    echo_info "🔄 Restarting deployments to inject sidecars..."
    
    # Restart echo deployment to get istio-proxy sidecar
    oc rollout restart deployment/$APP_NAME -n $NAMESPACE
    
    # Wait for rollout to complete
    echo_info "⏳ Waiting for deployment rollout..."
    oc rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=120s
    
    echo_success "✅ Deployments restarted with sidecars"
}

# Add DNS entry for TinyLB generated hostname
setup_dns() {
    echo_info "🌐 Setting up DNS for TinyLB hostname..."
    
    # Get the TinyLB generated hostname
    TINYLB_HOSTNAME=$(oc get route -n $NAMESPACE -o jsonpath='{.items[?(@.metadata.labels.tinylb\.io/managed=="true")].spec.host}' 2>/dev/null || echo "")
    
    if [ -n "$TINYLB_HOSTNAME" ]; then
        echo_info "📝 TinyLB hostname found: $TINYLB_HOSTNAME"
        echo_warning "⚠️  Add this to your /etc/hosts file:"
        echo_warning "   echo '127.0.0.1 $TINYLB_HOSTNAME' | sudo tee -a /etc/hosts"
    else
        echo_warning "⚠️  TinyLB hostname not found yet - check routes later"
    fi
}

# Validate deployment
validate_deployment() {
    echo_info "✅ Validating deployment..."
    
    echo_info "📊 Deployment Status:"
    echo "===================="
    
    echo_info "Pods:"
    oc get pods -n $NAMESPACE -l app=$APP_NAME
    
    echo_info "Services:"
    oc get svc -n $NAMESPACE
    
    echo_info "Gateway:"
    oc get gateway -n $NAMESPACE
    
    echo_info "HTTPRoute:"
    oc get httproute -n $NAMESPACE
    
    echo_info "Routes:"
    oc get routes -n $NAMESPACE
    
    echo_info "Certificates:"
    oc get secrets -n $NAMESPACE | grep tls
    
    echo_info "mTLS Policy:"
    oc get peerauthentication -n $NAMESPACE
    
    echo_info "TinyLB Status:"
    if [ -f /tmp/tinylb.pid ]; then
        local pid=$(cat /tmp/tinylb.pid)
        if kill -0 $pid 2>/dev/null; then
            echo_success "✅ TinyLB controller running (PID: $pid)"
        else
            echo_error "❌ TinyLB controller not running"
        fi
    else
        echo_warning "⚠️  TinyLB PID file not found"
    fi
}

# Test connectivity
test_connectivity() {
    echo_info "🧪 Testing connectivity..."
    
    echo_info "Testing HTTPS access to $HOST..."
    if curl -k -s --max-time 10 https://$HOST/ | grep -q "Hello from Gateway API"; then
        echo_success "✅ HTTPS access working!"
    else
        echo_warning "⚠️  HTTPS access test failed - may need DNS setup"
    fi
    
    echo_info "Testing HTTP access to $HOST..."
    if curl -s --max-time 10 http://$HOST/ | grep -q "Hello from Gateway API"; then
        echo_success "✅ HTTP access working!"
    else
        echo_warning "⚠️  HTTP access test failed - check routing"
    fi
}

# Cleanup function
cleanup() {
    echo_info "🧹 Cleaning up..."
    if [ -f /tmp/tinylb.pid ]; then
        local pid=$(cat /tmp/tinylb.pid)
        if kill -0 $pid 2>/dev/null; then
            echo_info "Stopping TinyLB controller..."
            kill $pid
            rm -f /tmp/tinylb.pid
        fi
    fi
    rm -f /tmp/gateway-*.pem
}

# Trap cleanup on exit
trap cleanup EXIT

# Main deployment
main() {
    echo_info "🚀 Complete Gateway API + TinyLB + Security Deployment"
    echo_info "======================================================="
    
    # Pre-flight checks
    if ! check_service_mesh; then
        echo_error "❌ Service Mesh 3.0 not ready. Please install and configure Service Mesh 3.0 first."
        exit 1
    fi
    
    # Determine GatewayClass
    GATEWAY_CLASS_NAME=$(get_gateway_class)
    echo_info "🎯 Using GatewayClass: $GATEWAY_CLASS_NAME"
    
    # Step 1: Create namespace
    echo_info "🔧 Creating namespace..."
    oc new-project $NAMESPACE || true
    
    # Step 2: Deploy TinyLB Controller
    deploy_tinylb_controller
    
    # Step 3: Create certificates
    create_certificates
    
    # Step 4: Configure Service Mesh
    configure_service_mesh
    
    # Step 5: Deploy echo server
    echo_info "📦 Deploying echo server..."
    cat <<EOF | oc apply -n $NAMESPACE -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  labels:
    app: $APP_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: echo
        image: $ECHO_IMAGE
        args:
        - "-text=$ECHO_TEXT"
        ports:
        - containerPort: 5678
          name: http
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF
    
    # Step 6: Create service
    echo_info "🔗 Creating service..."
    cat <<EOF | oc apply -n $NAMESPACE -f -
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME
  labels:
    app: $APP_NAME
spec:
  selector:
    app: $APP_NAME
  ports:
  - port: 80
    targetPort: 5678
    protocol: TCP
    name: http
EOF
    
    # Step 7: Create HTTPS Gateway
    create_https_gateway
    
    # Step 8: Create HTTPRoute
    echo_info "🛣️  Creating HTTPRoute..."
    cat <<EOF | oc apply -n $NAMESPACE -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: echo-route
  labels:
    app: $APP_NAME
spec:
  parentRefs:
  - name: echo-gateway
  hostnames:
  - "$HOST"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: $APP_NAME
      port: 80
EOF
    
    # Step 9: Wait for initial deployment
    echo_info "⏳ Waiting for pods to be ready..."
    oc wait --for=condition=ready pod -l app=$APP_NAME -n $NAMESPACE --timeout=90s
    
    # Step 10: Restart deployments for sidecars
    restart_deployments
    
    # Step 11: Wait for TinyLB to process LoadBalancer service
    echo_info "⏳ Waiting for TinyLB to process LoadBalancer service..."
    sleep 10
    
    # Step 12: Create routes
    create_routes
    
    # Step 13: Setup DNS
    setup_dns
    
    # Step 14: Final validation
    validate_deployment
    
    # Step 15: Test connectivity
    test_connectivity
    
    echo_success "✅ Complete Gateway API Deployment Finished!"
    echo_info "=============================================="
    echo_info "🌐 Access your application:"
    echo_info "   HTTPS: curl -k https://$HOST"
    echo_info "   HTTP:  curl http://$HOST"
    echo_info ""
    echo_info "🔍 Debug commands:"
    echo_info "   oc describe gateway echo-gateway -n $NAMESPACE"
    echo_info "   oc describe httproute echo-route -n $NAMESPACE"
    echo_info "   oc get routes -n $NAMESPACE"
    echo_info "   tail -f /tmp/tinylb.log"
    echo_info ""
    echo_info "🧹 To cleanup:"
    echo_info "   oc delete project $NAMESPACE"
    echo_info "   kill \$(cat /tmp/tinylb.pid) # Stop TinyLB controller"
}

# Run main function
main "$@"

