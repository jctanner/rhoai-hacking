#!/bin/bash
#
# This script automates the setup of Authorino to protect an HTTPRoute
# using OpenShift's built-in OAuth server for token introspection.
#
# Prerequisites:
#   - You must be logged into an OpenShift cluster with cluster-admin privileges.
#   - The 'oc' and 'kubectl' CLIs must be installed.
#   - A Gateway API provider (like Istio or Envoy Gateway) must be installed.
#   - The Gateway and HTTPRoute you want to protect must already exist.

set -euo pipefail

# --- User-configurable variables ---
# Please edit these values to match your environment.

# The Gateway API Gateway resource that manages traffic.
GATEWAY_NAME="my-gateway"
GATEWAY_NAMESPACE="default"

# The HTTPRoute you want to protect with OpenShift authentication.
HTTPROUTE_NAME="my-app-route"
HTTPROUTE_NAMESPACE="default"

# --- Script configuration ---
AUTHORINO_OPERATOR_VERSION="v0.4.0" # Use a specific, stable version of the operator
AUTHORINO_NAMESPACE="authorino-system"

# --- 1. Prerequisite Checks ---
echo "🔎 Checking prerequisites..."

if ! command -v oc &> /dev/null; then
    echo "❌ Error: 'oc' command not found. Please install the OpenShift CLI."
    exit 1
fi

if ! oc whoami &> /dev/null; then
    echo "❌ Error: Not logged into an OpenShift cluster. Please run 'oc login' first."
    exit 1
fi

if ! oc get gateway "${GATEWAY_NAME}" -n "${GATEWAY_NAMESPACE}" &> /dev/null; then
    echo "❌ Error: Gateway '${GATEWAY_NAME}' not found in namespace '${GATEWAY_NAMESPACE}'."
    echo "   Please check your variables at the top of the script."
    exit 1
fi

if ! oc get httproute "${HTTPROUTE_NAME}" -n "${HTTPROUTE_NAMESPACE}" &> /dev/null; then
    echo "❌ Error: HTTPRoute '${HTTPROUTE_NAME}' not found in namespace '${HTTPROUTE_NAMESPACE}'."
    echo "   Please check your variables at the top of the script."
    exit 1
fi

echo "👍 Prerequisites met."
echo

# --- 2. Deploy Authorino Operator ---
echo "🚀 Deploying Authorino Operator..."
if oc get namespace "${AUTHORINO_NAMESPACE}" &> /dev/null; then
    echo "   Namespace '${AUTHORINO_NAMESPACE}' already exists. Skipping creation."
else
    oc create namespace "${AUTHORINO_NAMESPACE}"
fi

# Deploy the operator and its CRDs
oc apply -f "https://github.com/Kuadrant/authorino-operator/releases/download/${AUTHORINO_OPERATOR_VERSION}/authorino-operator.yaml"

# Wait for the operator deployment to be ready
echo "   Waiting for Authorino Operator to become available..."
kubectl wait --for=condition=Available -n "${AUTHORINO_NAMESPACE}" deployment/authorino-operator --timeout=300s
echo "👍 Authorino Operator is ready."
echo

# --- 3. Deploy Authorino Instance ---
echo "🚀 Deploying Authorino instance..."

# We use a heredoc to define the Authorino instance YAML.
# This instance will be managed by the operator we just deployed.
cat <<EOF | oc apply -f -
apiVersion: operator.authorino.kuadrant.io/v1beta1
kind: Authorino
metadata:
  name: authorino
  namespace: ${AUTHORINO_NAMESPACE}
spec:
  listener:
    tls:
      enabled: false # Keep it simple for in-cluster communication
  oidcServer:
    tls:
      enabled: false
EOF

# Wait for the Authorino service to be created and available
echo "   Waiting for Authorino service to be ready..."
kubectl wait --for=condition=Available -n "${AUTHORINO_NAMESPACE}" deployment/authorino-authorino-authorization --timeout=300s
echo "👍 Authorino instance is ready."
echo

# --- 4. Create the AuthPolicy ---
echo "🔐 Creating AuthPolicy to enforce OpenShift authentication..."

# The OpenShift OAuth server's token introspection endpoint is stable and can be referenced
# via its internal service DNS name.
OPENSHIFT_OAUTH_INFO_ENDPOINT="https://oauth-openshift.openshift-authentication.svc:443/oauth/info"

# This AuthPolicy tells Authorino how to validate tokens.
# It uses OAuth2 Token Introspection against the OpenShift endpoint.
cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1beta2
kind: AuthPolicy
metadata:
  name: protect-with-openshift-oauth
  namespace: ${HTTPROUTE_NAMESPACE}
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: ${HTTPROUTE_NAME}
  
  rules:
    authentication:
      "openshift-token-introspection":
        # Use the standard OAuth2 Token Introspection method
        oauth2Introspection:
          endpoint: "${OPENSHIFT_OAUTH_INFO_ENDPOINT}"
          # The token is expected in the 'Authorization: Bearer <token>' header
          credentials:
            authorizationHeader:
              prefix: "Bearer"
    
    response:
      # On success, add a header with the username to the upstream request.
      # This is useful for the backend application.
      success:
        headers:
          "x-forwarded-user":
            selector: auth.identity.name
EOF

echo "👍 AuthPolicy '${HTTPROUTE_NAME}-openshift-oauth' created in namespace '${HTTPROUTE_NAMESPACE}'."
echo

# --- 5. Final Instructions ---
echo "------------------------------------------------------------------"
echo "✅ Setup Complete!"
echo "------------------------------------------------------------------"
echo
echo "   Your HTTPRoute '${HTTPROUTE_NAME}' is now protected."
echo "   Only requests with a valid OpenShift access token will be allowed."
echo
echo "--- How to Test ---"
echo "1. Get your OpenShift access token:"
echo "   TOKEN=\$(oc whoami --show-token)"
echo
echo "2. Get the hostname for your route:"
echo "   HOSTNAME=\$(oc get httproute ${HTTPROUTE_NAME} -n ${HTTPROUTE_NAMESPACE} -o jsonpath='{.spec.hostnames[0]}')"
echo
echo "3. Make a request **without** the token (should be denied with 401):"
echo "   curl -I -H \"Host: \${HOSTNAME}\" http://<YOUR_GATEWAY_IP>/"
echo
echo "4. Make a request **with** the token (should be allowed):"
echo "   curl -I -H \"Host: \${HOSTNAME}\" -H \"Authorization: Bearer \${TOKEN}\" http://<YOUR_GATEWAY_IP>/"
echo
echo "   (Replace <YOUR_GATEWAY_IP> with the external IP address of your gateway service)"
echo
echo "--- How to Clean Up ---"
echo "Run the following commands to remove the resources created by this script:"
echo "   oc delete authpolicy protect-with-openshift-oauth -n ${HTTPROUTE_NAMESPACE}"
echo "   oc delete namespace ${AUTHORINO_NAMESPACE}"
echo
echo "------------------------------------------------------------------" 