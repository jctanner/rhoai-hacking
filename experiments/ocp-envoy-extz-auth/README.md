# OCP Envoy External Authorization Demo

This project demonstrates how to use Envoy as a proxy in OpenShift, including a sophisticated example of using the `ext_authz` filter with `oauth2-proxy` to secure a backend service with OIDC.

There are three main components, each in its own directory under `src/`.

---

## 1. The Echo Service (`src/echo-server`)

This is a simple backend service used as the destination for our proxies.

### Components:
*   `app.py`: A simple Python Flask application that listens on any path and echoes back all the request headers it receives as a JSON response.
*   `Dockerfile`: A container image definition for the echo service.
*   `Makefile`: A helper to build and push the container image to `registry.tannerjc.net/echo-server:latest`.
*   `deployment.yaml`: A Kubernetes manifest that deploys the echo service into the `echo-server` namespace. It also creates a `Service` and a direct, unsecured OpenShift `Route` to expose it.

### Usage:
1.  Navigate to `src/echo-server`.
2.  Run `make build` and `make push` to build and publish the container image.
3.  Apply the manifest: `oc apply -f deployment.yaml`.
4.  The service will be accessible at `http://echo-direct.apps-crc.testing`.

---

## 2. Unauthenticated Envoy Proxy (`src/envoy-proxy`)

This is a basic example of an Envoy proxy that performs simple routing.

### Components:
*   `deployment.yaml`: A Kubernetes manifest containing:
    *   A `ConfigMap` with the Envoy configuration to listen for traffic and route all requests to the `echo-server` service.
    *   A `Deployment` for the Envoy proxy itself, using the Red Hat Service Mesh proxy image.
    *   A `Service` to expose the Envoy pod.
    *   An OpenShift `Route` to make the proxy publicly accessible.

### Usage:
1.  Apply the manifest: `oc apply -f src/envoy-proxy/deployment.yaml`.
2.  The proxy will be accessible at `http://echo-proxy.apps-crc.testing`.
3.  All traffic sent to this URL will be forwarded to the echo service.

---

## 3. Authenticated Envoy Proxy (`src/envoy-proxy-authenticated`)

This is the complete, secure setup demonstrating Envoy's external authorization capabilities with `oauth2-proxy` and an OIDC provider (Keycloak).

### How It Works:
1.  A request comes into the Envoy proxy.
2.  Envoy's `ext_authz` filter intercepts the request and sends a "check" request to the `oauth2-proxy` service.
3.  If the user is not authenticated, `oauth2-proxy` instructs Envoy to perform a `302 Redirect` to the Keycloak login page.
4.  After successful login, the user is redirected back. `oauth2-proxy` validates the OIDC token and responds `200 OK` to Envoy.
5.  With the `200 OK` from `oauth2-proxy`, Envoy forwards the original request to the `echo-server`.
6.  `oauth2-proxy` also attaches the user's identity information and access token as headers (`X-Auth-Request-*`), which Envoy forwards to the `echo-server`.

### Components:
*   `deployment.yaml`: A single, comprehensive manifest containing:
    *   A `Secret` to hold the OIDC client credentials for `oauth2-proxy`. **You must edit this file before applying it.**
    *   A `Deployment` and `Service` for `oauth2-proxy`, configured to use Keycloak and to act as a pure authorization service (`--upstream=static://200`).
    *   A `ConfigMap` with an advanced Envoy configuration that correctly routes `/oauth2/...` traffic to the proxy while protecting all other paths with the `ext_authz` filter.
    *   A `Deployment`, `Service`, and OpenShift `Route` (with explicit TLS edge termination) for the authenticated Envoy proxy.

### Usage:
1.  **IMPORTANT:** Edit `src/envoy-proxy-authenticated/deployment.yaml` and fill in the placeholder values in the `oauth2-proxy-creds` Secret with your Keycloak client details and a random cookie secret.
2.  Ensure your OIDC client in Keycloak has the valid redirect URI set to `https://echo-proxy-authenticated.apps-crc.testing/oauth2/callback`.
3.  Apply the manifest: `oc apply -f src/envoy-proxy-authenticated/deployment.yaml`.
4.  The authenticated proxy will be accessible at `https://echo-proxy-authenticated.apps-crc.testing`. Accessing this URL will trigger the full OIDC login flow.

