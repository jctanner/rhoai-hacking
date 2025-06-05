#!/bin/bash

URL="https://get.helm.sh/helm-v3.17.3-linux-amd64.tar.gz"
TARBALL=$(basename $URL)

if [[ ! -f $TARBALL ]]; then
    curl -o $TARBALL $URL
fi

if [[ ! -f helm ]]; then
    tar xzvf $TARBALL linux-amd64/helm
    mv linux-amd64/helm .
    rm -rf linux-amd64
fi
