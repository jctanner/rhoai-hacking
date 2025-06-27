#!/bin/bash

kind delete cluster --name odh-minimal
kind create cluster --name odh-minimal


# cd src/odh-gateway-operator/
# make manifests && make generate && make install && make run
#
# kubectl apply -f src/odh-gateway-operator/config/samples/gateway_v1alpha1_odhgateway.yaml
