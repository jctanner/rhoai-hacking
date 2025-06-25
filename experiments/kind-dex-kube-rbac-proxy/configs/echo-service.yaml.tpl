---
apiVersion: v1
kind: Namespace
metadata:
  name: ${ECHO_NAMESPACE}

---
apiVersion: v1
kind: Secret
metadata:
  name: dex-ca-cert
  namespace: ${ECHO_NAMESPACE}
type: Opaque
data:
  ca.crt: ${DEX_CA_CRT_BASE64}  # Base64-encoded contents of certs/dex/ca.crt

---
apiVersion: v1
kind: Secret
metadata:
  name: ${TLS_SECRET_NAME}
  namespace: ${ECHO_NAMESPACE}
type: kubernetes.io/tls
data:
  tls.crt: ${ECHO_TLS_CRT_BASE64}
  tls.key: ${ECHO_TLS_KEY_BASE64}

---
apiVersion: v1
kind: Secret
metadata:
  name: kube-rbac-proxy-kubeconfig
  namespace: ${ECHO_NAMESPACE}
type: Opaque
data:
  kubeconfig: ${KUBECONFIG_BASE64}

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${ECHO_NAME}
  namespace: ${ECHO_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${ECHO_NAME}
  template:
    metadata:
      labels:
        app: ${ECHO_NAME}
    spec:
      containers:
      - name: kube-rbac-proxy
        image: gcr.io/kubebuilder/kube-rbac-proxy:v0.13.1
        args:
        - "--secure-listen-address=0.0.0.0:8443"
        - "--upstream=http://127.0.0.1:80/"
        - "--tls-cert-file=/certs/tls.crt"
        - "--tls-private-key-file=/certs/tls.key"
        - "--logtostderr=true"
        - "--v=10"
        - "--oidc-issuer=https://dex.dex.svc.cluster.local:5556"
        - "--oidc-clientID=echo"
        - "--oidc-ca-file=/etc/kube-rbac-proxy/ca/ca.crt"
        - "--oidc-username-claim=email"
        - "--auth-header-fields-enabled"
        - "--auth-header-user-field-name=x-remote-user"
        - "--auth-header-groups-field-name=x-remote-groups"
        - "--ignore-paths=/api/k8s/foobar"
        ports:
        - containerPort: 8443
          name: https
        volumeMounts:
        - mountPath: /certs
          name: tls
          readOnly: true
        - mountPath: /etc/kube-rbac-proxy
          name: kubeconfig
          readOnly: true
        - mountPath: /etc/kube-rbac-proxy/ca
          name: dex-ca
          readOnly: true
      - name: echo
        image: ealen/echo-server
        ports:
        - containerPort: 80
      volumes:
      - name: tls
        secret:
          secretName: ${TLS_SECRET_NAME}
      - name: kubeconfig
        secret:
          secretName: ${KUBECONFIG_SECRET_NAME}
      - name: dex-ca
        secret:
          secretName: dex-ca-cert

---
apiVersion: v1
kind: Service
metadata:
  name: echo
  namespace: ${ECHO_NAMESPACE}
spec:
  selector:
    app: ${ECHO_NAME}
  ports:
  - port: 443
    targetPort: https
    name: https

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-rbac-proxy-sar
rules:
- apiGroups: ["authorization.k8s.io"]
  resources: ["subjectaccessreviews"]
  verbs: ["create"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-rbac-proxy-sar
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-rbac-proxy-sar
subjects:
- kind: ServiceAccount
  name: default
  namespace: echo
