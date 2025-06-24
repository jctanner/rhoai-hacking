#!/bin/bash

# kubectl -n ns-a port-forward service/echo-a 8443:443

TOKEN=$(kubectl -n ns-a create token alice)
curl -v -k -H "Authorization: Bearer ${TOKEN}" https://localhost:8443 | jq .

