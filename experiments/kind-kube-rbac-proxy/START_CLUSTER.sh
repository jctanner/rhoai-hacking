#!/bin/bash

kind delete cluster --name echo-access
kind create cluster --config kind-cluster.yaml

cd configs
kubectl apply -f namespace-a.yaml

cd ..
./CREATE_SECRET.sh

cd configs
sleep 2
kubectl apply -f .
