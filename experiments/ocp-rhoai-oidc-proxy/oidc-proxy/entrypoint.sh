#!/bin/sh

echo "[entrypoint] Waiting for Keycloak at $OIDC_ISSUER_INTERNAL"

until curl -k -v --fail "$OIDC_ISSUER_INTERNAL/.well-known/openid-configuration"; do
  echo "[entrypoint] Keycloak not ready, retrying in 2s..."
  sleep 2
done

echo "[entrypoint] Keycloak is up! Starting proxy..."
exec /app/oidc-proxy.bin
