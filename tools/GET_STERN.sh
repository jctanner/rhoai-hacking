#!/bin/bash

# set the pwd to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/CONFIG.sh
cd $SCRIPT_DIR

URL="https://github.com/stern/stern/releases/download/v1.32.0/stern_1.32.0_linux_amd64.tar.gz"
TARBALL=$(basename $URL)

if [[ -f $BINDIR/stern ]]; then
    exit 0
fi

if [[ ! -f $TARCACHE/$TARBALL ]]; then
    curl -k -L -o $TARCACHE/$TARBALL $URL
fi

tar xzvf $TARCACHE/$TARBALL stern
mv stern $BINDIR/.
