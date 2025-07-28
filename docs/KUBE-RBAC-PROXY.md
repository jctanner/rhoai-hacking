# Kube-RBAC-Proxy: How it Works

This document outlines the architecture and functionality of the `kube-rbac-proxy`.

## Overview

`kube-rbac-proxy` is a small, security-focused HTTP proxy designed to sit in front of an application or service running in Kubernetes. Its primary purpose is to protect services by offloading authentication and authorization to the Kubernetes API.

Before a request is allowed to reach the upstream application, the proxy intercepts it and performs two critical checks:

1.  **Authentication (AuthN):** It identifies *who* is making the request.
2.  **Authorization (AuthZ):** It determines if the identified user has permission to make that specific request.

## Core Components and Flow

The application is initialized in `cmd/kube-rbac-proxy/main.go`, which uses `k8s.io/component-base/cli` to set up a `cobra` command. The core logic resides in `cmd/kube-rbac-proxy/app/kube-rbac-proxy.go`.

The proxy works by chaining together a series of HTTP middleware filters, defined in `pkg/filters/auth.go`. For any incoming request, the flow is as follows:

1.  The `WithAuthentication` filter is executed first.
2.  If authentication is successful, the `WithAuthorization` filter is executed.
3.  If authorization is successful, the request is forwarded to the upstream application via a reverse proxy.

If either check fails, the proxy immediately rejects the request with a `401 Unauthorized` or `403 Forbidden` status code.

### 1. Authentication: Identifying the User

The proxy determines the user's identity from the incoming request using one of three methods. This logic is handled by an `authenticator.Request` object.

-   **Bearer Tokens:** The proxy inspects the `Authorization: Bearer <token>` header. It then sends this token to the main Kubernetes API server by creating a `TokenReview` object. The API server validates the token and returns the user's identity (e.g., `system:serviceaccount:my-ns:my-sa`).
-   **TLS Client Certificates:** The proxy can be configured to trust a specific Certificate Authority (CA). If an incoming request presents a valid client certificate signed by that CA, the user's identity is extracted from the certificate's Subject field (`Common Name` for username, `Organization` for groups).
-   **OIDC (OpenID Connect):** For human user authentication, the proxy can be configured as an OIDC client. It validates JWTs from an OIDC provider and extracts user claims (like `email` and `groups`) to establish identity.

Upon successful authentication, the user's information (`user.Info`) is attached to the request's context.

### 2. Authorization: Checking Permissions

Once the user is known, the `WithAuthorization` filter takes over.

1.  **Extract User:** It retrieves the user's identity from the request context, where the authentication filter placed it.
2.  **Build Attributes:** It combines the user's identity with details from the HTTP request (e.g., `GET`, `/metrics`, `pods`) to create a set of `authorizer.Attributes`.
3.  **Perform `SubjectAccessReview`:** It sends these attributes to the main Kubernetes API server in a `SubjectAccessReview` (SAR) request. The SAR asks the API, "Is this user allowed to perform this action on this resource?"
4.  **Enforce Decision:** The API server, which has the complete picture of all Roles and RoleBindings in the cluster, returns a simple "yes" or "no."
    -   If "yes" (`authorizer.DecisionAllow`), the request is passed along to the next handler.
    -   If "no," the request is immediately rejected with a `403 Forbidden` error.

This architecture allows for fine-grained access control to services without having to build complex authentication and authorization logic into the services themselves. Access can be managed dynamically using standard Kubernetes RBAC resources.

## Use Case: Integration with OpenShift OAuth Proxy

A common and robust real-world use case involves integrating `kube-rbac-proxy` within a larger authentication flow, such as with OpenShift's `oauth-proxy`. This pattern is effective for protecting services that need to serve both human users (via a browser) and programmatic clients.

Consider the following topology:

`OpenShift Route` -> `oauth-proxy` -> `Gateway API` -> `kube-rbac-proxy` -> `Upstream Container`

This flow works as follows:

1.  **User Authentication (`oauth-proxy`):** A user first hits the OpenShift Route, and the request is directed to the `oauth-proxy`. This component handles the entire interactive login flow with the user, redirecting them to the OpenShift login page if necessary. Upon successful authentication, `oauth-proxy` obtains the user's access token from the OpenShift OAuth server.

2.  **The Secure Hand-off:** The critical step is how `oauth-proxy` communicates the user's identity to `kube-rbac-proxy`. For this to work securely, `oauth-proxy` must be configured to pass the user's access token upstream by setting the `Authorization: Bearer <users-openshift-token>` header on the requests it forwards.

3.  **Networking (`Gateway API`):** The Gateway API resource routes the request from `oauth-proxy` to the correct backend service where `kube-rbac-proxy` is running as a sidecar. It should be configured to pass the `Authorization` header through transparently.

4.  **Per-Request Authorization (`kube-rbac-proxy`):**
    -   `kube-rbac-proxy` receives the request containing the user's OpenShift token.
    -   Its `WithAuthentication` filter extracts the token and performs a `TokenReview` against the OpenShift API server.
    -   The OpenShift API validates the token and returns the user's verified identity.
    -   `kube-rbac-proxy` then proceeds with the `SubjectAccessReview` to authorize the request for that specific user.

This pattern creates a powerful, layered security model. `oauth-proxy` manages the session and user-facing login, while `kube-rbac-proxy` enforces fine-grained, per-request RBAC, leveraging native platform security features without trusting insecure headers. In this scenario, `kube-rbac-proxy`'s OIDC flags are not needed, as the `TokenReview` mechanism provides the correct integration.

## Example: Sidecar Deployment

Here is a complete example of how to use `kube-rbac-proxy` as a sidecar to protect an application's `/metrics` endpoint.

In this scenario, only users who have permission to `get` the `services/metrics` resource will be able to access the endpoint. All traffic must go through the proxy on port `8443`.

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

## Choosing the Right Tool: Is kube-rbac-proxy Always the Answer?

While `kube-rbac-proxy` is a powerful tool, it's not always the best fit for every use case. A common question is whether to place it in front of a service, like a dashboard, that should be accessible to "all users". The answer depends entirely on the definition of "all users".

### Case 1: A Truly Public, Unauthenticated Service

If "all users" means **anyone on the internet, without requiring a login**, then `kube-rbac-proxy` is the wrong tool. Its primary function is to *enforce* authentication and then check RBAC permissions. It will reject unauthenticated requests by default.

**Recommendation:** For truly public services, expose them directly via a standard Kubernetes Ingress, OpenShift Route, or Gateway API resource without an authentication proxy.

### Case 2: Any User Authenticated to the Cluster

If "all users" means **any user who can successfully log in to the Kubernetes/OpenShift cluster**, `kube-rbac-proxy` can work, but may be inefficient.

It would require creating a `ClusterRoleBinding` that grants access to the `system:authenticated` group. However, this means `kube-rbac-proxy` will perform a `SubjectAccessReview` *for every single HTTP request* to the dashboard (including CSS, JS, images, etc.), which can create unnecessary load on the Kubernetes API server.

**Recommendation:** For services that only need to verify that a user is logged in, a session-based tool like `oauth-proxy` is often a more efficient choice. It authenticates the user once, establishes a session cookie, and allows subsequent requests based on that session, avoiding constant checks against the API server.

### Case 3: A Broad but Defined Group of Authenticated Users

If "all users" means **all members of a specific, but potentially large, group** (e.g., all employees, all members of the `developers` team), then `kube-rbac-proxy` is an excellent choice.

**Recommendation:** This is the ideal use case for `kube-rbac-proxy`. It allows you to manage access declaratively using standard Kubernetes RBAC resources. You can grant access to a specific group, and all permissions are handled centrally through the Kubernetes API, providing a consistent and secure access control model. 