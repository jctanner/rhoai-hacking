#!/bin/bash

set -e

export ECHO_NAME=echo-a
export ECHO_NAMESPACE=echo

envsubst < configs/echo-namespace.tpl | kubectl apply -f -

kubectl apply -f configs/echo-auth-proxy-sa.yaml

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-rbac-proxy-sar
rules:
- apiGroups: ["authentication.k8s.io"]
  resources: ["tokenreviews"]
  verbs: ["create"]
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
  name: echo-auth-proxy
  namespace: echo
EOF


TOKEN=$(kubectl create token echo-auth-proxy -n echo)
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_CERT=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Create kubeconfig file
mkdir -p certs/echo
cat <<EOF > certs/echo/kubeconfig
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA_CERT}
    server: ${APISERVER}
  name: kind
contexts:
- context:
    cluster: kind
    user: echo-auth-proxy
  name: kind
current-context: kind
users:
- name: echo-auth-proxy
  user:
    token: ${TOKEN}
EOF

#export ECHO_NAME=echo-a
#export ECHO_NAMESPACE=echo
export ECHO_TLS_CRT_BASE64=$(base64 -w0 certs/echo/tls.crt)
export ECHO_TLS_KEY_BASE64=$(base64 -w0 certs/echo/tls.key)
export TLS_SECRET_NAME=echo-a-tls
#export KUBECONFIG_SECRET_NAME=echo-a-auth-proxy-kubeconfig
export KUBECONFIG_SECRET_NAME=kube-rbac-proxy-kubeconfig
export KUBECONFIG_BASE64=$(base64 -w0 certs/echo/kubeconfig)
export BASIC_PASSWORD_HASH=$(echo "password" | htpasswd -nBC 12 -i alice | head -n1 | cut -d: -f2)
export DEX_CA_CRT_BASE64=$(base64 -w0 certs/dex/ca.crt)

envsubst < configs/echo-service.yaml.tpl | kubectl apply -f -
