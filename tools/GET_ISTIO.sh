#!/bin/bash

# set the pwd to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/CONFIG.sh
cd $SCRIPT_DIR

URL="https://github.com/istio/istio/releases/download/1.26.2/istio-1.26.2-linux-amd64.tar.gz"
TARBALL=$(basename $URL)
BINDIR="${BINDIR:-$(pwd)/bin}"

if [[ ! -f $TARCACHE/$TARBALL ]]; then
    curl -L -o $TARCACHE/$TARBALL $URL
fi

if [[ ! -f $BINDIR/istioctl ]]; then
    tar xzvf $TARCACHE/$TARBALL istio-1.26.2/bin/istioctl
    mv istio-1.26.2/bin/istioctl $BINDIR/.
    rm -rf istio-1.26.2
fi
