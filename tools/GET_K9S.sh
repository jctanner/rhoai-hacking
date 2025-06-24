#!/bin/bash

URL="https://github.com/derailed/k9s/releases/download/v0.50.6/k9s_Linux_amd64.tar.gz"
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

tar xzvf tarballs/$TARBALL k9s
mv k9s $BINDIR/.
chmod +x $BINDIR/k9s
