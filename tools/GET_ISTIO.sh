#!/bin/bash

URL="https://github.com/istio/istio/releases/download/1.26.2/istio-1.26.2-linux-amd64.tar.gz"
TARBALL=$(basename $URL)

if [[ ! -d bin ]]; then
    mkdir -p bin
fi 

if [[ ! -d tarballs ]]; then
    mkdir -p tarballs
fi

if [[ ! -f tarballs/$TARBALL ]]; then
    curl -L -o tarballs/$TARBALL $URL
fi

if [[ ! -f bin/istioctl ]]; then
    tar xzvf tarballs/$TARBALL istio-1.26.2/bin/istioctl
    mv istio-1.26.2/bin/istioctl bin/.
    rm -rf istio-1.26.2
fi
