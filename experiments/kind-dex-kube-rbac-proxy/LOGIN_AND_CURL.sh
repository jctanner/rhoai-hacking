#!/bin/bash
set -euo pipefail

CLIENT_ID="echo"
CLIENT_SECRET="echo-secret"
ISSUER="https://localhost:5556"
REDIRECT_URI="http://localhost:8000/callback"
SCOPE="openid profile email groups offline_access"
ECHO_URL="https://localhost:8443/"

# Step 1: Start temporary local server to catch redirect
echo "Starting temporary HTTP callback listener..."
python3 -m http.server 8000 > /dev/null 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID" EXIT

# Step 2: Get Auth Code
AUTH_URL="$ISSUER/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=$(echo $SCOPE | tr ' ' '+')"
echo "Please log in at:"
echo "$AUTH_URL"
echo ""
echo "After login, copy the 'code' param from the redirected URL and paste it here:"
read -p "Code: " AUTH_CODE

# Step 3: Exchange Code for ID Token
echo "Requesting token..."
TOKEN_JSON=$(curl -s -k -X POST "$ISSUER/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code=${AUTH_CODE}&redirect_uri=${REDIRECT_URI}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}")

ID_TOKEN=$(echo "$TOKEN_JSON" | jq -r '.id_token')

if [[ "$ID_TOKEN" == "null" || -z "$ID_TOKEN" ]]; then
  echo "Failed to obtain ID token:"
  echo "$TOKEN_JSON"
  exit 1
fi

# Step 4: Use ID Token to access echo
echo "-------------------------------------------------------------------------------------"
echo "GET ROOT"
echo "-------------------------------------------------------------------------------------"
echo "Sending request to echo service with ID token..."
curl -k -v "$ECHO_URL" -H "Authorization: Bearer $ID_TOKEN" | jq .

# Step 5: Use ID Token to access echo's api endpint ...
echo "-------------------------------------------------------------------------------------"
echo "PASSTRHOUGH TO API"
echo "-------------------------------------------------------------------------------------"
echo "Sending request to echo service with ID token..."
curl -k -v "${ECHO_URL}api/k8s/foobar" -H "Authorization: Bearer $ID_TOKEN"  | jq .
