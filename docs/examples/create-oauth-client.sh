#!/bin/bash
#
# This script creates a temporary OpenShift OAuthClient for testing purposes.
# It requires cluster-admin permissions and the 'oc' CLI.
#
# Usage:
#   ./create-oauth-client.sh [CLIENT_ID]
#
# If CLIENT_ID is not provided, "my-bash-test-client" will be used.

# --- Configuration ---
set -euo pipefail
CLIENT_ID=${1:-"my-bash-test-client"}

# --- Prerequisite Checks ---
if ! command -v oc &> /dev/null; then
    echo "❌ Error: 'oc' command not found. Please install the OpenShift CLI and log in."
    exit 1
fi

if ! oc whoami &> /dev/null; then
    echo "❌ Error: Not logged into an OpenShift cluster. Please run 'oc login' first."
    exit 1
fi

echo "👍 Pre-flight checks passed. Using Client ID: $CLIENT_ID"

# --- Get Cluster-Specific URLs ---
echo "🔎 Discovering cluster's OAuth endpoints..."
OAUTH_ROUTE_HOST=$(oc get route oauth-openshift -n openshift-authentication -o jsonpath='{.spec.host}')
if [ -z "$OAUTH_ROUTE_HOST" ]; then
    echo "❌ Error: Could not find the 'oauth-openshift' route in the 'openshift-authentication' namespace." >&2
    echo "   Please ensure you have the correct permissions." >&2
    exit 1
fi
# The token display page is a safe and convenient redirect URI for testing.
REDIRECT_URI="https://${OAUTH_ROUTE_HOST}/oauth/token/display"
AUTHORIZE_URL="https://${OAUTH_ROUTE_HOST}/oauth/authorize"
echo "   Redirect URI set to: $REDIRECT_URI"

# --- Generate Client Secret ---
echo "🔐 Generating a secure client secret..."
CLIENT_SECRET=$(openssl rand -base64 48 | tr -d '\n' | tr -dc 'a-zA-Z0-9' | head -c 40)

# --- Create OAuthClient Resource ---
echo "🚀 Creating OAuthClient resource..."

# Use a heredoc to pass the YAML directly to `oc apply`.
# This avoids creating temporary files.
oc apply -f - <<EOF
apiVersion: oauth.openshift.io/v1
kind: OAuthClient
metadata:
  name: ${CLIENT_ID}
# The secret is stored directly in the CR.
secret: "${CLIENT_SECRET}"
redirectURIs:
  - "${REDIRECT_URI}"
# 'prompt' forces the user to approve the grant, which is best for testing.
grantMethod: prompt
EOF

# --- Output Final Results ---
echo ""
echo "------------------------------------------------------------------"
echo "✅ OAuth Client '$CLIENT_ID' created successfully!"
echo "------------------------------------------------------------------"
echo ""
echo "   Client ID:      ${CLIENT_ID}"
echo "   Client Secret:  ${CLIENT_SECRET}"
echo ""
echo "--- How to Test ---"
echo "1. Visit the following authorization URL in your browser:"
echo "   (This URL uses the 'token' response type for simple testing)"
echo ""
echo "   ${AUTHORIZE_URL}?client_id=${CLIENT_ID}&response_type=token&redirect_uri=${REDIRECT_URI}"
echo ""
echo "2. Log into OpenShift and approve the permissions grant for the client."
echo "3. You will be redirected, and your new access token will be displayed on the screen."
echo ""
echo "--- How to Clean Up ---"
echo "When you are finished, run this command to delete the client:"
echo "   oc delete oauthclient ${CLIENT_ID}"
echo ""
echo "------------------------------------------------------------------" 