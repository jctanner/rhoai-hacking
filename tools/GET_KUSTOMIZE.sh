#!/bin/bash

URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.6.0/kustomize_v5.6.0_linux_amd64.tar.gz"
TARBALL=$(basename $URL)
BINDIR="${BINDIR:-./bin}"

if [[ ! -d $BINDIR ]]; then
    mkdir -p $BINDIR
fi

if [[ ! -d tarballs ]]; then
    mkdir -p tarballs
fi

if [[ ! -f tarballs/$TARBALL ]]; then
    curl -k -L -o tarballs/$TARBALL $URL
fi

if [[ ! -f $BINDIR/kustomize ]]; then
    tar xzvf tarballs/$TARBALL
fi

mv kustomize $BINDIR/.
