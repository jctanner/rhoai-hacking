#!/bin/bash

BINDIR="${BINDIR:-./bin}"

if [[ ! -d $BINDIR ]]; then
    mkdir -p $BINDIR
fi 

if [[ ! -d tarballs ]]; then
    mkdir -p tarballs
fi

if [[ ! -f $BINDIR/kind ]]; then
    [ $(uname -m) = x86_64 ] && curl -Lo $BINDIR/kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
fi

chmod +x $BINDIR/kind
