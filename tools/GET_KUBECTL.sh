#!/bin/bash

if [[ ! -d bin ]]; then
    mkdir -p bin
fi 

if [[ ! -d tarballs ]]; then
    mkdir -p tarballs
fi

if [[ ! -f bin/kubectl ]]; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
fi

mv kubectl bin/.
chmod +x bin/kubectl
