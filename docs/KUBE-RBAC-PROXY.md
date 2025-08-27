# Comparing kube-rbac-proxy and oauth-proxy for Kubernetes RBAC

This document explores two popular proxy solutions used in Kubernetes and OpenShift environments, `kube-rbac-proxy` and `oauth-proxy`, with a focus on how they handle authentication (AuthN) and authorization (AuthZ), particularly Role-Based Access Control (RBAC).

## Overview

Both `kube-rbac-proxy` and `oauth-proxy` are security-enhancing HTTP proxies that can be deployed in front of applications running in Kubernetes. While they share the common goal of protecting services, they have different primary functions and design philosophies.

-   **`kube-rbac-proxy`** is a specialized, lightweight proxy designed for one primary task: enforcing Kubernetes RBAC permissions for every single request. It integrates deeply with the Kubernetes API to perform `SubjectAccessReview` checks, making it ideal for granular, per-request authorization for APIs and services. It is stateless and focuses purely on AuthZ.

-   **`oauth-proxy`** (specifically the OpenShift variant) is a more general-purpose authentication proxy. Its main strength lies in handling the entire user-facing authentication flow using OAuth2 and OIDC. It establishes a user session, typically via a cookie, and can then protect backend services. While its primary role is AuthN, it also has capabilities to perform RBAC checks, making it a versatile tool for protecting both UIs and APIs.

This document will compare their core mechanics, typical use cases, and provide guidance on when to choose one over the other, or how to use them together.

## Core Authorization Flows

### `kube-rbac-proxy`: Per-Request RBAC Enforcement

The `kube-rbac-proxy` operates on a simple, stateless principle: check every request.

The application is initialized in `cmd/kube-rbac-proxy/main.go`, and the core logic resides in a series of chained HTTP middleware filters defined in `pkg/filters/auth.go`. For any incoming request, the flow is as follows:

1.  **Authentication (`WithAuthentication`):** The proxy first determines the user's identity. It does this by inspecting the `Authorization: Bearer <token>` header and validating the token against the Kubernetes API via a `TokenReview`. It can also authenticate via client certificates. Upon success, the user's information (`user.Info`) is attached to the request's context.
2.  **Authorization (`WithAuthorization`):** With the user identified, the proxy constructs a `SubjectAccessReview` (SAR) request. This request combines the user's identity with details from the HTTP request (e.g., verb `GET`, resource `/metrics`) and sends it to the Kubernetes API.
3.  **Enforcement:** The API server responds with a simple "yes" or "no."
    -   If "yes," the request is forwarded to the upstream application.
    -   If "no," the proxy immediately rejects the request with a `403 Forbidden` status code.

This entire process happens for every single HTTP request that passes through the proxy, ensuring that access control is always up-to-date with the latest RBAC policies in the cluster.

### `oauth-proxy`: Session-Based Authentication with Optional RBAC

The `oauth-proxy` flow is primarily session-based, designed to handle interactive user logins.

1.  **Initial Request:** An unauthenticated user makes a request to a protected service.
2.  **OAuth Redirect:** The `oauth-proxy` intercepts the request. Seeing no valid session cookie, it redirects the user's browser to the configured OpenID Connect (OIDC) provider (e.g., the built-in OpenShift OAuth server, Google, Okta).
3.  **User Login:** The user authenticates with the OIDC provider.
4.  **Callback and Session Creation:** After successful login, the provider redirects the user back to the `oauth-proxy` with an authorization code. The proxy exchanges this code for an access token and user identity information. It then creates a secure, encrypted session cookie in the user's browser.
5.  **Authorization (Optional):** This is a critical step where `oauth-proxy` can perform RBAC. If configured with flags like `--openshift-sar`, it will use the user's token to perform a `SubjectAccessReview` against the Kubernetes API *at login time*. If the SAR fails, the login is rejected, and no session is created.
6.  **Authenticated Proxying:** For all subsequent requests, the user's browser presents the session cookie. The `oauth-proxy` validates the cookie and, if valid, proxies the request to the upstream application without needing to contact the OIDC provider or the Kubernetes API again.

The key difference is that the `SubjectAccessReview` check happens **once at login**, not on every request. This makes it highly efficient for protecting user interfaces, but less suitable for fine-grained, per-request API authorization where a user's permissions might change during their session.

## Combining Strengths: A Hybrid Approach

A common and robust real-world pattern involves integrating `kube-rbac-proxy` and `oauth-proxy` to create a layered security model. This approach is highly effective for protecting services that need to serve both human users (via a browser) and programmatic clients (like `curl` or `kubectl`).

Consider the following topology:

`OpenShift Route` -> `oauth-proxy` -> `kube-rbac-proxy` -> `Upstream Container`

This flow works by assigning each proxy a distinct responsibility:

1.  **User Authentication (`oauth-proxy`):** The `oauth-proxy` sits at the edge and handles the entire interactive login flow. It authenticates the user with the OIDC provider and establishes a session. Its primary job is to answer the question: "Is this a valid, logged-in user?"

2.  **The Secure Hand-off:** For this pattern to work, `oauth-proxy` must be configured to securely pass the user's identity to `kube-rbac-proxy`. It does this by setting the `--pass-user-bearer-token=true` flag, which causes it to forward the user's OIDC access token in the `Authorization: Bearer <token>` header on every upstream request.

3.  **Per-Request Authorization (`kube-rbac-proxy`):** The `kube-rbac-proxy` sits in front of the application as a sidecar. It receives the request from `oauth-proxy`, extracts the bearer token, and performs a `TokenReview` and `SubjectAccessReview` for that specific user and that specific request. Its job is to answer the question: "Is this logged-in user allowed to perform *this specific action* right now?"

This pattern creates a powerful, layered security model. `oauth-proxy` manages the user-facing session, while `kube-rbac-proxy` enforces fine-grained, stateless, per-request RBAC. This leverages native platform security features and provides the best of both worlds: efficient session management for UIs and rigorous, real-time authorization for APIs.

## Example: `kube-rbac-proxy` Sidecar for API Authorization

Here is a complete example of how to use `kube-rbac-proxy` as a sidecar to protect an application's `/metrics` endpoint. This demonstrates its role in fine-grained API protection.

In this scenario, only users who have permission to `get` the `services/metrics` resource will be able to access the endpoint. All traffic must go through the proxy on port `8443`. Note that this example focuses on the `kube-rbac-proxy` deployment; the `oauth-proxy` would be deployed as a separate service in the cluster, configured to forward requests to the `my-app-metrics` Service.

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
---
# This ClusterRole defines the permission a user needs to have
# in order to access the metrics.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: my-app-metrics-reader
rules:
- apiGroups: [""]
  resources: ["services"]
  # The "resourceName" must match the name of the Service that exposes the metrics.
  resourceNames: ["my-app-metrics"]
  verbs: ["get"]
---
# Grant a specific user (e.g., prometheus-user) the ability
# to read the metrics.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-my-app-metrics
subjects:
- kind: User
  name: "prometheus-user"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: my-app-metrics-reader
  apiGroup: rbac.authorization.k8s.io
---
# The Service exposes the proxy's secure port (8443), not the
# application's port. All traffic must go through the proxy.
apiVersion: v1
kind: Service
metadata:
  name: my-app-metrics
  labels:
    app: my-app
spec:
  ports:
  - name: https
    port: 8443
    targetPort: 8443
  selector:
    app: my-app
---
# This ConfigMap holds the configuration for kube-rbac-proxy.
# It tells the proxy what authorization checks to perform.
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-rbac-proxy-config
data:
  config.yaml: |
    authorization:
      resourceAttributes:
        # For an incoming request, the proxy will check if the user
        # has the "get" verb on the "services" resource.
        verb: "get"
        resource: "services"
        # The API group and resource name should match the target Service.
        apiGroup: ""
        resourceName: "my-app-metrics"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      serviceAccountName: my-app-sa
      containers:
      # This is the main application container.
      # It runs on port 8080 and is only reachable from within the Pod.
      - name: my-app
        image: instrumentisto/go-http-server
        args:
          - "-p=8080"
          - "--response-body=Hello from my-app!"
        ports:
        - name: http
          containerPort: 8080

      # This is the kube-rbac-proxy sidecar.
      # It listens on port 8443, performs AuthN/AuthZ, and
      # forwards valid requests to the application on port 8080.
      - name: kube-rbac-proxy
        image: quay.io/brancz/kube-rbac-proxy:v0.15.0
        args:
        - "--secure-listen-address=0.0.0.0:8443"
        - "--upstream=http://127.0.0.1:8080/"
        - "--config-file=/etc/kube-rbac-proxy/config.yaml"
        - "--logtostderr=true"
        ports:
        - name: https
          containerPort: 8443
        volumeMounts:
        - name: config
          mountPath: /etc/kube-rbac-proxy
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: kube-rbac-proxy-config
```

### Breakdown of the Components

1.  **ServiceAccount (`my-app-sa`):** Provides an identity for the Pod itself.
2.  **ClusterRole (`my-app-metrics-reader`):** This is **not** for the Pod, but for the *user*. It defines the permission that `kube-rbac-proxy` will check for. Any user who wants to access the metrics needs this role.
3.  **ClusterRoleBinding (`read-my-app-metrics`):** This grants the `my-app-metrics-reader` role to a user named `prometheus-user`. This is how you control who has access.
4.  **Service (`my-app-metrics`):** This exposes the `kube-rbac-proxy`'s secure port (`8443`) to the cluster. It's crucial that the service targets the proxy, not the application container directly.
5.  **ConfigMap (`kube-rbac-proxy-config`):** This file tells `kube-rbac-proxy` what check to perform. The `resourceAttributes` section instructs it to fire a `SubjectAccessReview` for the `get` verb on the `services` resource with the name `my-app-metrics`.
6.  **Deployment (`my-app`):**
    *   The `my-app` container runs the actual application, listening on `localhost:8080`, so it cannot be accessed directly from outside the Pod.
    *   The `kube-rbac-proxy` container listens on port `8443`, mounts the `ConfigMap`, and is configured with the `--upstream=http://127.0.0.1:8080/` flag to forward authorized requests to the application container.

## When to Use Which Proxy

While both proxies can perform authorization, their different designs make them suitable for different tasks.

### Use `oauth-proxy` when:

-   You need to protect a **user-facing web application** (e.g., a dashboard).
-   Your primary requirement is **authentication**—ensuring a user is logged in.
-   You need to establish a **session** (via cookies) for a user's browser.
-   Authorization checks can be performed **once at login time**, rather than on every single API call. This is more efficient for UIs that make many requests for assets (CSS, JS, images).
-   You need to support various OAuth2/OIDC providers.

### Use `kube-rbac-proxy` when:

-   You need to protect an **API or a service endpoint** that is consumed programmatically.
-   Your primary requirement is **authorization**—enforcing fine-grained, real-time permissions.
-   Access must be re-evaluated for **every single request** based on the latest cluster RBAC policies.
-   The service is **stateless** and relies on bearer tokens for authentication.
-   You need a lightweight, minimal-footprint sidecar focused solely on RBAC.

### Use Both When:

-   You have a web application with a UI and a backend API.
-   You want to provide a smooth, session-based login experience for the UI (`oauth-proxy`).
-   You also need to enforce strict, per-request RBAC checks for the backend API (`kube-rbac-proxy`).
-   This hybrid model provides layered security, leveraging the strengths of both tools.

## Appendix: RBAC Configuration Comparison

While both proxies can interact with the Kubernetes RBAC system, they are configured in fundamentally different ways, reflecting their core design philosophies.

### `kube-rbac-proxy`

For `kube-rbac-proxy`, RBAC enforcement is its sole purpose. As such, its configuration is centered on defining the `SubjectAccessReview` (SAR) to be performed. This is not typically done with a single command-line flag, but through a configuration file specified by the `--config-file` argument.

The key RBAC-related flag is:

-   `--config-file`: Points to a YAML file that defines the authorization check.

Inside this file, the `authorization.resourceAttributes` section dictates the SAR request. For example:

```yaml
authorization:
  resourceAttributes:
    verb: "get"
    resource: "services"
    resourceName: "my-app-metrics"
```

This instructs the proxy to check if the authenticated user has the `get` permission on the `services` resource named `my-app-metrics` for every incoming request.

### `oauth-proxy`

For `oauth-proxy`, RBAC is an optional, secondary feature performed *after* authentication, typically only at login time. It offers several flags to enable different kinds of authorization checks:

-   `--openshift-sar`: This is the most direct equivalent to `kube-rbac-proxy`'s functionality. It takes a JSON-formatted `SubjectAccessReview` spec. If the user making the request cannot satisfy this SAR check at login time, their login is denied.
    -   Example: `--openshift-sar='{"namespace":"app-dev","resource":"pods","verb":"list"}'`
-   `--openshift-delegate-urls`: This provides a more advanced mapping, where different URL paths within the upstream application can be gated by different `SubjectAccessReview` checks.
-   `--openshift-group`: This provides a simpler, non-SAR-based authorization check. It restricts logins to members of a specific OpenShift group or list of groups. This is a simple group membership check, not a full RBAC role check.

### Key Differences Summarized

| Feature                  | `kube-rbac-proxy`                                     | `oauth-proxy`                                                       |
| ------------------------ | ----------------------------------------------------- | ------------------------------------------------------------------- |
| **When is RBAC checked?**  | On **every** HTTP request.                            | **Once** at user login time.                                        |
| **Primary Configuration**  | Via a YAML file (`--config-file`)                     | Via direct CLI flags (`--openshift-sar`, `--openshift-group`, etc.) |
| **Simple Group Check?**    | No (must use a proper Role/RoleBinding for groups)    | Yes (`--openshift-group`)                                           |
| **Granularity**          | Extremely high (per-request, per-path)                | Lower (gates the entire session based on one check)                 |

## Migration Guide: From `--openshift-sar` to `kube-rbac-proxy`

If you are currently using `oauth-proxy` with the `--openshift-sar` flag and wish to migrate to `kube-rbac-proxy` for per-request authorization, the conversion is straightforward.

The `--openshift-sar` flag accepts a JSON object that directly corresponds to the `resourceAttributes` in a `SubjectAccessReview`. The goal is to translate this JSON object into the YAML format used by `kube-rbac-proxy`'s `--config-file`.

### Step 1: Understand the `oauth-proxy` Configuration

Imagine your `oauth-proxy` is configured with the following flag:

```bash
--openshift-sar='{"namespace":"app-dev","resource":"services","resourceName":"my-app","verb":"get"}'
```

This configuration checks at login time if the user has permission to `get` the `my-app` service in the `app-dev` namespace.

### Step 2: Create the `kube-rbac-proxy` Configuration File

Create a new configuration file (e.g., `rbac-config.yaml` or `rbac-config.json`). The format can be either YAML or JSON, as `kube-rbac-proxy` can parse both. The goal is to translate the `oauth-proxy` JSON attributes into the `resourceAttributes` section. The mapping is direct.

**Option A: YAML Configuration (`rbac-config.yaml`)**

```yaml
authorization:
  resourceAttributes:
    namespace: "app-dev"
    resource: "services"
    resourceName: "my-app"
    verb: "get"
```

**Option B: JSON Configuration (`rbac-config.json`)**

You can also structure the configuration as a JSON file. This structure directly mirrors the YAML.

```json
{
  "authorization": {
    "resourceAttributes": {
      "namespace": "app-dev",
      "resource": "services",
      "resourceName": "my-app",
      "verb": "get"
    }
  }
}
```

### Step 3: Launch `kube-rbac-proxy`

Now, launch `kube-rbac-proxy` pointing to your chosen configuration file. The command is the same for either format.

```bash
# Using the YAML file
kube-rbac-proxy --config-file=rbac-config.yaml ...

# Or, using the JSON file
kube-rbac-proxy --config-file=rbac-config.json ...
```

With this configuration, `kube-rbac-proxy` will now perform the *exact same RBAC check* as `oauth-proxy` did, but it will do so for **every single request**, providing continuous, real-time authorization.

## Appendix: Command-Line Options

### `kube-rbac-proxy`

```
--allow-paths strings                        Comma-separated list of paths against which kube-rbac-proxy pattern-matches the incoming request. If the request doesn't match, kube-rbac-proxy responds with a 404 status code. If omitted, the incoming request path isn't checked. Cannot be used with --ignore-paths.
--auth-header-fields-enabled                 When set to true, kube-rbac-proxy adds auth-related fields to the headers of http requests sent to the upstream
--auth-header-groups-field-name string       The name of the field inside a http(2) request header to tell the upstream server about the user's groups (default "x-remote-groups")
--auth-header-groups-field-separator string  The separator string used for concatenating multiple group names in a groups header field's value (default "|")
--auth-header-user-field-name string         The name of the field inside a http(2) request header to tell the upstream server about the user's name (default "x-remote-user")
--auth-token-audiences strings               Comma-separated list of token audiences to accept. By default a token does not have to have any specific audience. It is recommended to set a specific audience.
--client-ca-file string                      If set, any request presenting a client certificate signed by one of the authorities in the client-ca-file is authenticated with an identity corresponding to the CommonName of the client certificate.
--config-file string                         Configuration file to configure kube-rbac-proxy.
--http2-disable                              Disable HTTP/2 support
--http2-max-concurrent-streams uint32        The maximum number of concurrent streams per HTTP/2 connection. (default 100)
--http2-max-size uint32                      The maximum number of bytes that the server will accept for frame size and buffer per stream in a HTTP/2 request. (default 262144)
--ignore-paths strings                       Comma-separated list of paths against which kube-rbac-proxy pattern-matches the incoming request. If the requst matches, it will proxy the request without performing an authentication or authorization check. Cannot be used with --allow-paths.
--insecure-listen-address string             [DEPRECATED] The address the kube-rbac-proxy HTTP server should listen on.
--kube-api-burst int                         kube-api burst value; needed when kube-api-qps is set
--kube-api-qps float32                       queries per second to the api, kube-client starts client-side throttling, when breached
--kubeconfig string                          Path to a kubeconfig file, specifying how to connect to the API server. If unset, in-cluster configuration will be used
--oidc-ca-file string                        If set, the OpenID server's certificate will be verified by one of the authorities in the oidc-ca-file, otherwise the host's root CA set will be used.
--oidc-clientID string                       The client ID for the OpenID Connect client, must be set if oidc-issuer-url is set.
--oidc-groups-claim string                   Identifier of groups in JWT claim, by default set to 'groups' (default "groups")
--oidc-groups-prefix string                  If provided, all groups will be prefixed with this value to prevent conflicts with other authentication strategies.
--oidc-issuer string                         The URL of the OpenID issuer, only HTTPS scheme will be accepted. If set, it will be used to verify the OIDC JSON Web Token (JWT).
--oidc-sign-alg strings                      Supported signing algorithms, default RS256 (default [RS256])
--oidc-username-claim string                 Identifier of the user in JWT claim, by default set to 'email' (default "email")
--oidc-username-prefix string                If provided, the username will be prefixed with this value to prevent conflicts with other authentication strategies.
--proxy-endpoints-port int                   The port to securely serve proxy-specific endpoints (such as '/healthz'). Uses the host from the '--secure-listen-address'.
--secure-listen-address string               The address the kube-rbac-proxy HTTPs server should listen on.
--tls-cert-file string                       File containing the default x509 Certificate for HTTPS. (CA cert, if any, concatenated after server cert)
--tls-cipher-suites strings                  Comma-separated list of cipher suites for the server. Values are from tls package constants (https://golang.org/pkg/crypto/tls/#pkg-constants). If omitted, the default Go cipher suites will be used
--tls-min-version string                     Minimum TLS version supported. Value must match version names from https://golang.org/pkg/crypto/tls/#pkg-constants. (default "VersionTLS12")
--tls-private-key-file string                File containing the default x509 private key matching --tls-cert-file.
--tls-reload-interval duration               [DEPRECATED] The interval at which to watch for TLS certificate changes, by default set to 1 minute. (default 1m0s)
--upstream string                            The upstream URL to proxy to once requests have successfully been authenticated and authorized.
--upstream-ca-file string                    The CA the upstream uses for TLS connection. This is required when the upstream uses TLS and its own CA certificate
--upstream-client-cert-file string           If set, the client will be used to authenticate the proxy to upstream. Requires --upstream-client-key-file to be set, too.
--upstream-client-key-file string            The key matching the certificate from --upstream-client-cert-file. If set, requires --upstream-client-cert-file to be set, too.
--upstream-force-h2c                         Force h2c to communiate with the upstream. This is required when the upstream speaks h2c(http/2 cleartext - insecure variant of http/2) only. For example, go-grpc server in the insecure mode, such as helm's tiller w/o TLS, speaks h2c only
```

### `oauth-proxy`

```
-approval-prompt string         OAuth approval_prompt (default "force")
-authenticated-emails-file stringauthenticate against emails via file (one per line)
-basic-auth-password string     the password to set when passing the HTTP Basic Auth header
-bypass-auth-except-for value   provide authentication ONLY for request paths under proxy-prefix and those that match the given regex (may be given multiple times). Cannot be set with -skip-auth-regex/-bypass-auth-for
-bypass-auth-for value          alias for skip-auth-regex
-client-id string               the OAuth Client ID: ie: "123456.apps.googleusercontent.com"
-client-secret string           the OAuth Client Secret
-client-secret-file string      a file containing the client-secret
-config string                  path to config file
-cookie-domain string           an optional cookie domain to force cookies to (ie: .yourcompany.com)*
-cookie-expire duration         expire timeframe for cookie (default 168h0m0s)
-cookie-httponly                set HttpOnly cookie flag (default true)
-cookie-name string             the name of the cookie that the oauth_proxy creates (default "_oauth_proxy")
-cookie-refresh duration        refresh the cookie after this duration; 0 to disable
-cookie-samesite string         set SameSite cookie attribute (ie: "lax", "strict", "none", or "").
-cookie-secret string           the seed string for secure cookies (optionally base64 encoded)
-cookie-secret-file string      a file containing a cookie-secret
-cookie-secure                  set secure (HTTPS) cookie flag (default true)
-custom-templates-dir string    path to custom html templates
-debug-address string           [http://]<addr>:<port> or unix://<path> to listen on for debug and requests
-display-htpasswd-form          display username / password login form if an htpasswd file is provided (default true)
-email-domain value             authenticate emails with the specified domain (may be given multiple times). Use * to authenticate any email
-footer string                  custom footer string. Use "-" to disable default footer.
-htpasswd-file string           additionally authenticate against a htpasswd file. Entries must be created with "htpasswd -s" for SHA password hashes or "htpasswd -B" for bcrypt hashes
-http-address string            [http://]<addr>:<port> or unix://<path> to listen on for HTTP clients (default "127.0.0.1:4180")
-https-address string           <addr>:<port> to listen on for HTTPS clients (default ":8443")
-login-url string               Authentication endpoint
-logout-url string              absolute URL to redirect web browsers to after logging out of openshift oauth server
-openshift-ca value             paths to CA roots for the OpenShift API (may be given multiple times, defaults to /var/run/secrets/kubernetes.io/serviceaccount/ca.crt).
-openshift-delegate-urls string If set, perform delegated authorization against the OpenShift API server. Value is a JSON map of path prefixes to v1beta1.ResourceAttribute records that must be granted to the user to continue. E.g. {"/":{"resource":"pods","namespace":"default","name":"test"}} only allows users who can see the pod test in namespace default.
-openshift-group string         restrict logins to members of this group (or groups, if encoded as a JSON array).
-openshift-review-url string    Permission check endpoint (defaults to the subject access review endpoint)
-openshift-sar string           require this encoded subject access review to authorize (may be a JSON list).
-openshift-sar-by-host string   require this encoded subject access review to authorize (must be a JSON array).
-openshift-service-account stringAn optional name of an OpenShift service account to act as. If set, the injected service account info will be used to determine the client ID and client secret.
-pass-access-token              pass OAuth access_token to upstream via X-Forwarded-Access-Token header
-pass-basic-auth                pass HTTP Basic Auth, X-Forwarded-User and X-Forwarded-Email information to upstream (default true)
-pass-host-header               pass the request Host Header to upstream (default true)
-pass-user-bearer-token         pass OAuth access token received from the client to upstream via X-Forwarded-Access-Token header
-pass-user-headers              pass X-Forwarded-User and X-Forwarded-Email information to upstream (default true)
-profile-url string             Profile access endpoint
-provider string                OAuth provider (default "openshift")
-proxy-prefix string            the url root path that this proxy should be nested under (e.g. /<oauth2>/sign_in) (default "/oauth")
-proxy-websockets               enables WebSocket proxying (default true)
-redirect-url string            the OAuth Redirect URL. ie: "https://internalapp.yourcompany.com/oauth/callback"
-redeem-url string              Token redemption endpoint
-request-logging                Log requests to stdout
-scope string                   OAuth scope specification
-set-xauthrequest               set X-Auth-Request-User and X-Auth-Request-Email response headers (useful in Nginx auth_request mode)
-signature-key string           GAP-Signature request signature key (algorithm:secretkey)
-skip-auth-preflight            will skip authentication for OPTIONS requests
-skip-auth-regex value          bypass authentication for request paths that match (may be given multiple times). Cannot be set with -bypass-auth-except-for. Alias for -bypass-auth-for
-skip-provider-button           will skip sign-in-page to directly reach the next step: oauth/start
-ssl-insecure-skip-verify       skip validation of certificates presented when using HTTPS
-tls-cert string                path to certificate file
-tls-client-ca string           path to a CA file for admitting client certificates.
-tls-key string                 path to private key file
-upstream value                 the http url(s) of the upstream endpoint or file:// paths for static files. Routing is based on the path
-upstream-ca value              paths to CA roots for the Upstream (target) Server (may be given multiple times, defaults to system trust store).
-upstream-flush duration        force flush upstream responses after this duration(useful for streaming responses). 0 to never force flush. Defaults to 5ms (default 5ms)
-upstream-timeout duration      maximum amount of time the server will wait for a response from the upstream (default 30s)
-validate-url string            Access token validation endpoint
-version                        print version string
```
