#!/bin/bash

kind delete cluster --name kind-oidc

set -e 

./MAKE_CERTS.sh

cat <<EOF > kind-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kind-oidc
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        oidc-client-id: "kubernetes"
        oidc-username-claim: "email"
        oidc-groups-claim: "groups"
        oidc-issuer-url: "https://dex.dex.svc.cluster.local:5556"
        oidc-ca-file: "/etc/dex/ca.crt"
      extraVolumes:
      - name: dex-ca
        hostPath: /etc/dex
        mountPath: /etc/dex
        readOnly: true
        pathType: DirectoryOrCreate
  extraMounts:
  - hostPath: $(pwd)/certs/dex
    containerPath: /etc/dex
EOF

kind create cluster --config kind-cluster.yaml
