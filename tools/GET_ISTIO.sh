#!/bin/bash

URL="https://github.com/istio/istio/releases/download/1.25.1/istio-1.25.1-linux-amd64.tar.gz"
TARBALL=$(basename $URL)

if [[ ! -f $TARBALL ]]; then
    curl -L -o $TARBALL $URL
fi

if [[ ! -f istioctl ]]; then
    tar xzvf $TARBALL istio-1.25.1/bin/istioctl
    mv istio-1.25.1/bin/istioctl .
    rm -rf istio-1.25.1
fi
