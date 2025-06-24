#!/bin/bash

URL="https://github.com/stern/stern/releases/download/v1.32.0/stern_1.32.0_linux_amd64.tar.gz"
TARBALL=$(basename $URL)
BINDIR="${BINDIR:-./bin}"

if [[ ! -d $BINDIR ]]; then
    mkdir -p $BINDIR
fi 

if [[ ! -d tarballs ]]; then
    mkdir -p tarballs
fi

if [[ -f $BINDIR/stern ]]; then
    exit 0
fi

if [[ ! -f $TARBALL ]]; then
    curl -k -L -o $TARBALL $URL
fi

tar xzvf $TARBALL stern
mv stern $BINDIR/.
