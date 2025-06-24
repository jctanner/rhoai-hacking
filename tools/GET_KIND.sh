#!/bin/bash

# set the pwd to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/CONFIG.sh
cd $SCRIPT_DIR

if [[ ! -f $BINDIR/kind ]]; then
    [ $(uname -m) = x86_64 ] && curl -Lo $BINDIR/kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
fi

chmod +x $BINDIR/kind
