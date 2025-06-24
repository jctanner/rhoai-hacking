#!/bin/bash

# set the pwd to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/CONFIG.sh
cd $SCRIPT_DIR

URL="https://github.com/openshift/oc"
TARBALL=$(basename $URL)


if [[ ! -d $TARCACHE/$TARBALL ]]; then
    git clone $URL $TARCACHE/$TARBALL
fi

rpm -q krb5-devel || sudo dnf -y install krb5-devel

cd $TARCACHE/$TARBALL
pwd
if [[ ! -f oc ]]; then
    make
fi
install oc $BINDIR/oc
