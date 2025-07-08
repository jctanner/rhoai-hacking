#!/bin/bash
set -euo pipefail

NAMESPACE="echo-test"
APP_NAME="echo"
HOST="echo.apps-crc.testing"
ECHO_IMAGE="hashicorp/http-echo"
ECHO_TEXT="Hello from Gateway API"

# Function to check if Service Mesh 3.0 is ready
check_service_mesh() {
    echo "🔍 Checking Service Mesh 3.0 status..."
    
    # Check if Istio pods are running
    if ! oc get pods -n istio-system --no-headers 2>/dev/null | grep -q "Running"; then
        echo "⚠️  Warning: No Istio pods found in istio-system namespace"
        echo "   Service Mesh 3.0 control plane may not be ready"
    else
        echo "✅ Istio control plane pods found"
    fi
    
    # Check available GatewayClasses
    echo "🔍 Checking available GatewayClasses..."
    if ! oc get gatewayclass --no-headers 2>/dev/null | head -5; then
        echo "⚠️  Warning: No GatewayClasses found"
        echo "   Service Mesh 3.0 may not be providing Gateway API support yet"
    fi
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

echo "🚀 Service Mesh 3.0 Gateway API Deployment"
echo "=============================================="

# Pre-flight checks
check_service_mesh

# Determine GatewayClass
GATEWAY_CLASS_NAME=$(get_gateway_class)
echo "🎯 Using GatewayClass: $GATEWAY_CLASS_NAME"

echo ""
echo "🔧 Creating namespace..."
oc new-project $NAMESPACE || true

echo "📦 Deploying echo server..."
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

echo "🔗 Creating service..."
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

echo "🌐 Creating Gateway and HTTPRoute..."
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
---
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

echo "⏳ Waiting for pods to be ready..."
oc wait --for=condition=ready pod -l app=$APP_NAME -n $NAMESPACE --timeout=90s

echo ""
echo "📊 Deployment Status:"
echo "====================="
echo "Pods:"
oc get pods -n $NAMESPACE -l app=$APP_NAME

echo ""
echo "Service:"
oc get svc -n $NAMESPACE -l app=$APP_NAME

echo ""
echo "Gateway:"
oc get gateway -n $NAMESPACE

echo ""
echo "HTTPRoute:"
oc get httproute -n $NAMESPACE

echo ""
echo "GatewayClass Status:"
oc get gatewayclass $GATEWAY_CLASS_NAME -o wide 2>/dev/null || echo "⚠️  GatewayClass '$GATEWAY_CLASS_NAME' not found"

echo ""
echo "✅ Deployment Complete!"
echo "======================="
echo "🌐 Try accessing the echo server:"
echo "   curl http://$HOST"
echo ""
echo "🔍 To debug issues:"
echo "   oc describe gateway echo-gateway -n $NAMESPACE"
echo "   oc describe httproute echo-route -n $NAMESPACE"
echo "   oc get events -n $NAMESPACE --sort-by='.lastTimestamp'"

