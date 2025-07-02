#!/bin/bash

set -e

echo "🔍 Testing OIDC Authentication Configuration"
echo "==========================================="

# Get the API server endpoint
API_SERVER=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')
echo "📡 API Server: $API_SERVER"

# Check if OIDC is configured in API server
echo ""
echo "🔐 Checking OIDC configuration in API server..."
if docker exec odh-minimal-control-plane ps aux | grep -q "oidc-issuer-url"; then
    echo "✅ OIDC is configured in API server"
    echo "📋 OIDC Configuration:"
    docker exec odh-minimal-control-plane ps aux | grep kube-apiserver | tr ' ' '\n' | grep oidc- | head -10
else
    echo "❌ OIDC not found in API server configuration"
    exit 1
fi

# Test API server connectivity
echo ""
echo "🌐 Testing API server connectivity..."
if kubectl get --raw /api/v1 > /dev/null 2>&1; then
    echo "✅ API server is responding"
else
    echo "❌ API server is not responding"
    exit 1
fi

# Check RBAC bindings
echo ""
echo "👥 Checking RBAC bindings for OIDC users..."
kubectl get clusterrolebindings | grep -i oidc || echo "⚠️  No OIDC RBAC bindings found - apply rbac-oidc-users.yaml first"

# Test JWT validation (this will fail without a real JWT, but shows the flow)
echo ""
echo "🔑 Testing JWT authentication flow..."
echo "This will show how to test with a real JWT token:"
echo ""
echo "# Example 1: Test with curl (replace YOUR_JWT_TOKEN with actual token)"
echo "curl -k -H \"Authorization: Bearer YOUR_JWT_TOKEN\" \\"
echo "     $API_SERVER/api/v1/namespaces"
echo ""
echo "# Example 2: Test with kubectl (set up kubeconfig with JWT)"
echo "kubectl config set-credentials oidc-user \\"
echo "    --auth-provider=oidc \\"
echo "    --auth-provider-arg=idp-issuer-url=https://keycloak.tannerjc.net/realms/sno419 \\"
echo "    --auth-provider-arg=client-id=console-test \\"
echo "    --auth-provider-arg=id-token=YOUR_JWT_TOKEN"
echo ""
echo "kubectl config set-context oidc-context \\"
echo "    --cluster=kind-odh-minimal \\"
echo "    --user=oidc-user"
echo ""
echo "kubectl --context=oidc-context get pods"

# Show how to extract JWT from your dashboard
echo ""
echo "🖥️  Dashboard Integration:"
echo "In your dashboard, you can now use the JWT token to make authenticated API calls:"
echo ""
echo "Python example:"
echo "import requests"
echo "import json"
echo ""
echo "# Get JWT from user's session"
echo "jwt_token = request.headers.get('Authorization', '').replace('Bearer ', '')"
echo "# Or from cookie"
echo "jwt_token = request.cookies.get('auth_token', '')"
echo ""
echo "# Make authenticated API call"
echo "headers = {'Authorization': f'Bearer {jwt_token}'}"
echo "response = requests.get('$API_SERVER/api/v1/namespaces', headers=headers, verify=False)"
echo ""
echo "if response.status_code == 200:"
echo "    namespaces = response.json()"
echo "    print(f'Found {len(namespaces[\"items\"])} namespaces')"
echo "else:"
echo "    print(f'API call failed: {response.status_code}')"

echo ""
echo "🎉 OIDC configuration test completed!"
echo ""
echo "Next steps:"
echo "1. Apply RBAC bindings: kubectl apply -f rbac-oidc-users.yaml"
echo "2. Get a JWT token from your Keycloak login"
echo "3. Test API calls with the JWT token"
echo "4. Update your dashboard to use JWT for K8s API calls" 