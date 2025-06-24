#!/bin/bash

# set the pwd to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/CONFIG.sh
cd $SCRIPT_DIR

URL="https://github.com/derailed/k9s/releases/download/v0.50.6/k9s_Linux_amd64.tar.gz"
TARBALL=$(basename $URL)

if [[ ! -f $TARCACHE/$TARBALL ]]; then
    curl -k -L -o $TARCACHE/$TARBALL $URL
fi

tar xzvf $TARCACHE/$TARBALL k9s
mv k9s $BINDIR/.
chmod +x $BINDIR/k9s
