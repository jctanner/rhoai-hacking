#!/bin/bash

# set the pwd to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR

# run each script iteratively
for SCRIPTNAME in $(ls GET_*.sh | grep -v GET_ALL); do
    echo $SCRIPTNAME
    bash $SCRIPTNAME
done
