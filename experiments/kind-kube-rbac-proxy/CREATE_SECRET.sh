#!/bin/bash

if [[ ! -f tls.key ]]; then
    openssl req -x509 -newkey rsa:2048 \
        -keyout tls.key -out tls.crt -days 365 \
        -nodes -subj "/CN=echo-a"
fi

kubectl -n ns-a create secret tls echo-a-tls \
  --cert=tls.crt --key=tls.key
