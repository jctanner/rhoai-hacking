#!/bin/bash

if [[ ! -d bin ]]; then
    mkdir -p bin
fi 

if [[ ! -d tarballs ]]; then
    mkdir -p tarballs
fi

if [[ ! -f bin/kind ]]; then
    [ $(uname -m) = x86_64 ] && curl -Lo ./bin/kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
fi

chmod +x bin/kind
