#!/bin/bash

# set the pwd to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/CONFIG.sh
cd $SCRIPT_DIR

URL="https://get.helm.sh/helm-v3.17.3-linux-amd64.tar.gz"
TARBALL=$(basename $URL)

if [[ ! -f $TARCACHE/$TARBALL ]]; then
    curl -o $TARCACHE/$TARBALL $URL
fi

if [[ ! -f $BINDIR/helm ]]; then
    tar xzvf $TARCACHE/$TARBALL linux-amd64/helm
    mv linux-amd64/helm $BINDIR/.
    rm -rf linux-amd64
fi
