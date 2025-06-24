#!/bin/bash

URL="https://github.com/derailed/k9s/releases/download/v0.50.6/k9s_Linux_amd64.tar.gz"
TARBALL=$(basename $URL)

if [[ ! -d bin ]]; then
    mkdir -p bin
fi

if [[ ! -d tarballs ]]; then
    mkdir -p tarballs
fi

if [[ ! -f tarballs/$TARBALL ]]; then
    curl -k -L -o tarballs/$TARBALL $URL
fi

tar xzvf tarballs/$TARBALL k9s
mv k9s bin/.
chmod +x bin/k9s