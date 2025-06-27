# What?

A central gateway/proxy that can operate in oidc mode or openshift-oauth mode. It's driven by an operator that uses a CR to instantiate the proxy deployment, service and route.
It also uses labels from services across the cluster to auto-update the configmap for the gateway ... and potentially deploy [kube-]rbac-proxies if needed.

# Gateway CR Schema
```
apiVersion: odhgateway.example.com/v1alpha1
kind: ODHGateway
metadata:
  name: odh-gateway
  namespace: odh
spec:
  mode: oidc  # or "openshift"
  configMapName: oidc-proxy-config
  image: your-proxy-image:latest

  hostname: https://odhgateway.cluster.lab # defines the openshift route that would get created

  oidc:
    issuerURL: https://keycloak.example.com/realms/example
    clientID: central-dashboard
    clientSecretRef:
      name: central-dashboard-secret
      key: clientSecret

  openshift:
    clientID: openshift-web-client
    userInfoURL: https://openshift.default.svc/apis/user.openshift.io/v1/users/~
    oauthURL: https://openshift.default.svc/oauth/authorize

  # Optional: restrict which namespaces to watch for services
  namespaceSelector:
    include:
      - "*"                # default: watch all namespaces
      # - "notebooks-*"
      # - "user-*"

  routeConfigMap:
    name: odh-gateway-routes
    managed: true     # or false to allow for manual updates
    key: config.yaml  # optional: default could be 'config.yaml'
```

# Gateway routing configmap
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: odhgateway-config
  namespace: default
data:
  routes.yaml: |
    - path: /notebooks/user1
      upstream: http://notebook-user1.notebooks.svc.cluster.local:8888
      authn: true
      authz: true
    - path: /
      upstream: http://dashboard.default.svc.cluster.local:8080
      authn: false
      authz: false
```

# Service labeling
```
apiVersion: v1
kind: Service
metadata:
  name: notebook-user1
  namespace: notebooks
  labels:
    odh-gateway/enabled: "true"
    odh-gateway/path: "/notebooks/user1"
    odh-gateway/authn: "true"  # or false for unauthenticated
    odh-gateway/authz: "true"  # or false for no authz checks + no kube-rbac-proxy sidecar
```

# RUNNING

cd src/odh-gateway && ./BUILD_AND_PUBLISH.sh
cd src/odh-gateway-operator && make manifests && make generate && make install && make run

kubectl apply -f src/odh-gateway-operator/config/samples/gateway_v1alpha1_odhgateway.yaml
