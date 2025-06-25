#!/bin/bash

export TLS_CRT=$(base64 -w0 certs/dex/tls.crt)
export TLS_KEY=$(base64 -w0 certs/dex/tls.key)
export BASIC_PASSWORD_HASH=$(echo "password" | htpasswd -nBC 12 -i alice | head -n1 | cut -d: -f2)

envsubst < configs/dex.yaml.tpl | kubectl apply -f -
