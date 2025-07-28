#!/bin/bash
#
# This script automates the setup of Authorino to protect an HTTPRoute
# using a full OIDC Authorization Code Flow with an external Identity Provider (IDP).
#
# This pattern is ideal for user-facing web applications. Unauthenticated users
# will be redirected to the IDP's login page.
#
# Prerequisites:
#   - You must be logged into an OpenShift cluster with cluster-admin privileges.
#   - The 'oc' and 'kubectl' CLIs must be installed.
#   - A Gateway API provider (like Istio or Envoy Gateway) must be installed.
#   - The Gateway and HTTPRoute you want to protect must already exist.
#   - You must have an OIDC client registered in your external IDP (e.g., Keycloak, Okta, Azure AD).

set -euo pipefail

# --- User-configurable variables ---
# Please edit these values to match your environment.

# 1. Gateway and Route Information
GATEWAY_NAME="my-gateway"
GATEWAY_NAMESPACE="default"
HTTPROUTE_NAME="my-app-route"
HTTPROUTE_NAMESPACE="default"

# 2. Application's Public Hostname
# This MUST match a hostname in your HTTPRoute and be resolvable.
# This is the URL users will visit in their browser.
APP_HOSTNAME="my-app.example.com"

# 3. External OIDC Provider Details
# The .well-known/openid-configuration endpoint of your IDP.
OIDC_ISSUER_URL="https://keycloak.mycompany.com/realms/my-realm"
# The Client ID you created in your IDP for this application.
OIDC_CLIENT_ID="my-kubernetes-gateway-client"
# The name of the Kubernetes secret that will store the client secret.
OIDC_CLIENT_SECRET_NAME="my-oidc-client-secret"

# --- Script configuration ---
AUTHORINO_OPERATOR_VERSION="v0.4.0"
AUTHORINO_NAMESPACE="authorino-system"

# --- 1. Prerequisite Checks ---
echo "🔎 Checking prerequisites..."

if ! command -v oc &> /dev/null; then echo "❌ Error: 'oc' command not found." >&2; exit 1; fi
if ! oc whoami &> /dev/null; then echo "❌ Error: Not logged into an OpenShift cluster." >&2; exit 1; fi
if ! oc get gateway "${GATEWAY_NAME}" -n "${GATEWAY_NAMESPACE}" &> /dev/null; then
    echo "❌ Error: Gateway '${GATEWAY_NAME}' not found in namespace '${GATEWAY_NAMESPACE}'." >&2
    exit 1
fi
if ! oc get httproute "${HTTPROUTE_NAME}" -n "${HTTPROUTE_NAMESPACE}" &> /dev/null; then
    echo "❌ Error: HTTPRoute '${HTTPROUTE_NAME}' not found in namespace '${HTTPROUTE_NAMESPACE}'." >&2
    exit 1
fi

echo "👍 Prerequisites met."
echo

# --- 2. Create OIDC Client Secret ---
echo "🔐 Creating a placeholder for the OIDC client secret..."
if oc get secret "${OIDC_CLIENT_SECRET_NAME}" -n "${HTTPROUTE_NAMESPACE}" &> /dev/null; then
    echo "   Secret '${OIDC_CLIENT_SECRET_NAME}' already exists. Skipping creation."
else
    kubectl create secret generic "${OIDC_CLIENT_SECRET_NAME}" \
      --from-literal=clientSecret="PLEASE_UPDATE_THIS_VALUE" \
      -n "${HTTPROUTE_NAMESPACE}"
fi
echo "   IMPORTANT: You must update the secret '${OIDC_CLIENT_SECRET_NAME}' in the '${HTTPROUTE_NAMESPACE}' namespace"
echo "   with the real client secret from your OIDC provider."
echo "   Example: kubectl patch secret ${OIDC_CLIENT_SECRET_NAME} -n ${HTTPROUTE_NAMESPACE} -p '{\"data\":{\"clientSecret\":\"\$(echo -n 'your-real-secret' | base64)\"}}'"
echo

# --- 3. Deploy Authorino Operator ---
echo "🚀 Deploying Authorino Operator..."
if oc get namespace "${AUTHORINO_NAMESPACE}" &> /dev/null; then
    echo "   Namespace '${AUTHORINO_NAMESPACE}' already exists."
else
    oc create namespace "${AUTHORINO_NAMESPACE}"
fi
oc apply -f "https://github.com/Kuadrant/authorino-operator/releases/download/${AUTHORINO_OPERATOR_VERSION}/authorino-operator.yaml"
echo "   Waiting for Authorino Operator to become available..."
kubectl wait --for=condition=Available -n "${AUTHORINO_NAMESPACE}" deployment/authorino-operator --timeout=300s
echo "👍 Authorino Operator is ready."
echo

# --- 4. Deploy Authorino Instance ---
echo "🚀 Deploying Authorino instance..."
cat <<EOF | oc apply -f -
apiVersion: operator.authorino.kuadrant.io/v1beta1
kind: Authorino
metadata:
  name: authorino
  namespace: ${AUTHORINO_NAMESPACE}
spec:
  listener:
    tls: { enabled: false }
  oidcServer:
    tls: { enabled: false }
EOF
echo "   Waiting for Authorino service to be ready..."
kubectl wait --for=condition=Available -n "${AUTHORINO_NAMESPACE}" deployment/authorino-authorino-authorization --timeout=300s
echo "👍 Authorino instance is ready."
echo

# --- 5. Create the OIDC AuthPolicy ---
echo "🔐 Creating AuthPolicy to enforce OIDC login flow..."

# This is the URL that Authorino will handle callbacks on.
# You MUST add this URL to the "Valid Redirect URIs" list in your OIDC client configuration.
REDIRECT_URL="https://${APP_HOSTNAME}/auth/callback"
echo "   IMPORTANT: Please ensure the following URL is added to your OIDC client's"
echo "   'Valid Redirect URIs' in your Identity Provider:"
echo "   ➡️   ${REDIRECT_URL}"
echo

cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1beta2
kind: AuthPolicy
metadata:
  name: protect-with-oidc-flow
  namespace: ${HTTPROUTE_NAMESPACE}
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: ${HTTPROUTE_NAME}
  
  rules:
    authentication:
      "my-company-sso":
        # This configures the full OIDC Authorization Code Flow for user login
        oidc:
          issuerUrl: "${OIDC_ISSUER_URL}"
          redirectUrl: "${REDIRECT_URL}"
          credentials:
            clientID:
              value: "${OIDC_CLIENT_ID}"
            clientSecret:
              valueFrom:
                secretKeyRef:
                  name: "${OIDC_CLIENT_SECRET_NAME}"
                  key: clientSecret
    
    response:
      success:
        headers:
          # On success, add the user's name as a header to the upstream request.
          "x-forwarded-user":
            selector: auth.identity.name
          # It's good practice to also forward the email or user ID
          "x-forwarded-email":
            selector: auth.identity.email
EOF

echo "👍 AuthPolicy 'protect-with-oidc-flow' created."
echo

# --- 6. Final Instructions ---
echo "------------------------------------------------------------------"
echo "✅ Setup Complete!"
echo "------------------------------------------------------------------"
echo
echo "   Your HTTPRoute '${HTTPROUTE_NAME}' is now protected by an OIDC login flow."
echo
echo "--- Final Manual Steps ---"
echo "1. ‼️  Update the client secret:"
echo "      kubectl patch secret ${OIDC_CLIENT_SECRET_NAME} -n ${HTTPROUTE_NAMESPACE} -p '{\"data\":{\"clientSecret\":\"\$(echo -n 'your-real-secret' | base64)\"}}'"
echo "2. ‼️  In your OIDC Provider, add this redirect URI to your client config:"
echo "      ${REDIRECT_URL}"
echo
echo "--- How to Test ---"
echo "1. Open a new private/incognito browser window."
echo "2. Navigate to your application's URL:"
echo "   https://${APP_HOSTNAME}/"
echo "3. You should be automatically redirected to your company's login page."
echo "4. After logging in, you should be redirected back to your application, fully authenticated."
echo
echo "--- How to Clean Up ---"
echo "Run the following commands to remove the resources created by this script:"
echo "   oc delete authpolicy protect-with-oidc-flow -n ${HTTPROUTE_NAMESPACE}"
echo "   oc delete secret ${OIDC_CLIENT_SECRET_NAME} -n ${HTTPROUTE_NAMESPACE}"
echo "   oc delete namespace ${AUTHORINO_NAMESPACE}"
echo
echo "------------------------------------------------------------------" 