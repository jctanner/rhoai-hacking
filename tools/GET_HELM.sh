#!/bin/bash

URL="https://get.helm.sh/helm-v3.17.3-linux-amd64.tar.gz"
TARBALL=$(basename $URL)
BINDIR="${BINDIR:-./bin}"

if [[ ! -d $BINDIR ]]; then
    mkdir -p $BINDIR
fi

if [[ ! -d tarballs ]]; then
    mkdir -p tarballs
fi

if [[ ! -f tarballs/$TARBALL ]]; then
    curl -o tarballs/$TARBALL $URL
fi

if [[ ! -f $BINDIR/helm ]]; then
    tar xzvf tarballs/$TARBALL linux-amd64/helm
    mv linux-amd64/helm $BINDIR/.
    rm -rf linux-amd64
fi
