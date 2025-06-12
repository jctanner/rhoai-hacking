#!/bin/bash

TOPDIR=$(pwd)

cd $TOPDIR/oidc-proxy
./BUILD.sh

cd $TOPDIR/src.odh/odh-dashboard
./BUILD.sh
