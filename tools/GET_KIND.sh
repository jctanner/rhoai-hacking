#!/bin/bash

if [[ ! -f kind ]]; then
    [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
fi

chmod +x kind
