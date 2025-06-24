#!/bin/bash

BINDIR="${BINDIR:-./bin}"

if [[ ! -d $BINDIR ]]; then
    mkdir -p $BINDIR
fi 

if [[ ! -d tarballs ]]; then
    mkdir -p tarballs
fi

if [[ ! -f $BINDIR/kubectl ]]; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
fi

mv kubectl $BINDIR/.
chmod +x $BINDIR/kubectl
