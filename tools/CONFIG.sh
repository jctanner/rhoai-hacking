#!/bin/bash

BINDIR="${BINDIR:-$(pwd)/bin}"
export BINDIR=$(realpath $BINDIR)
export TARCACHE="${TARCACHE:-/tmp/tarballs}"

echo "BINDIR: ${BINDIR}"
if [[ ! -d $BINDIR ]]; then
    mkdir -p $BINDIR
fi 

if [[ ! -d $TARCACHE ]]; then
    mkdir -p $TARCACHE
fi
