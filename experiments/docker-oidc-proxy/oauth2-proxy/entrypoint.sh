#!/bin/sh

echo "[entrypoint] Waiting for Keycloak at $OAUTH2_PROXY_OIDC_ISSUER_URL..."

until curl -sf "${OAUTH2_PROXY_OIDC_ISSUER_URL}/.well-known/openid-configuration" > /dev/null; do
  echo "[entrypoint] Keycloak not ready, retrying in 2s..."
  sleep 2
done

echo "[entrypoint] Keycloak is up. Starting oauth2-proxy..."
exec /bin/oauth2-proxy "$@"