#!/bin/bash

kind delete cluster --name notebook-test
kind create cluster --name notebook-test --config cluster.yaml

# Install upstream Gateway API CRDs manually
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml

istioctl install --set profile=ambient -y
# kubectl label namespace default istio-injection=enabled
kubectl label namespace default  istio.io/dataplane-mode=ambient

## SETUP NOTEBOOK STUFF
# kubectl create ns notebooks
# kubectl label namespace notebooks istio-injection=enabled
# cd src/notebook-operator
# make manifests && make generate && make install && make run
# kubectl apply -f config/samples/ds_v1alpha1_notebook.yaml
# kubectl get notebooks
# kubectl get svc
# kubectl get httproute

# SETUP THE GATEWAY AND PORT FORWARD
# istioctl waypoint generate --namespace default | kubectl apply -f -
# istioctl waypoint apply -n default --enroll-namespace
