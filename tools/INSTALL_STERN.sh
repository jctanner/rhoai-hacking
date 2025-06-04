#!/bin/bash

URL="https://github.com/stern/stern/releases/download/v1.32.0/stern_1.32.0_linux_amd64.tar.gz"
TARBALL=$(basename $URL)
CMD="~/bin/stern"

if [[ -f $CMD ]]; then
    exit 0
fi

rm -rf /tmp/stern.install
mkdir -p /tmp/stern.install
cd /tmp/stern.install
curl -L -k -o $TARBALL $URL
tar xzvf $TARBALL

ls -al

install stern ~/bin/.
