#!/bin/bash

for SCRIPTNAME in $(ls GET_*.sh | grep -v GET_ALL); do
    echo $SCRIPTNAME
    bash $SCRIPTNAME
done