#!/bin/bash

# set the pwd to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/CONFIG.sh
cd $SCRIPT_DIR

URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.6.0/kustomize_v5.6.0_linux_amd64.tar.gz"
TARBALL=$(basename $URL)

if [[ ! -f $TARCACHE/$TARBALL ]]; then
    curl -k -L -o $TARCACHE/$TARBALL $URL
fi

if [[ ! -f $BINDIR/kustomize ]]; then
    tar xzvf $TARCACHE/$TARBALL
fi

mv kustomize $BINDIR/.
