#!/bin/bash

URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.6.0/kustomize_v5.6.0_linux_amd64.tar.gz"
TARBALL=$(basename $URL)

if [[ ! -f $TARBALL ]]; then
    curl -k -L -o $TARBALL $URL
fi

if [[ ! -f kustomize ]]; then
    tar xzvf $TARBALL
fi
