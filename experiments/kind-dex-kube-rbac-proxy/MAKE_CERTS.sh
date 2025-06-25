#!/bin/bash

set -e

mkdir -p certs/dex
mkdir -p certs/echo

### --- DEX CERTS --- ###

if [[ ! -f certs/dex/ca.key ]]; then
    openssl genrsa -out certs/dex/ca.key 4096
    openssl req -x509 -new -nodes -key certs/dex/ca.key -sha256 -days 3650 \
      -out certs/dex/ca.crt -subj "/CN=Dex CA"
fi

if [[ ! -f certs/dex/tls.key ]]; then
    openssl genrsa -out certs/dex/tls.key 2048
    openssl req -new -key certs/dex/tls.key -out certs/dex/tls.csr -subj "/CN=dex.dex.svc.cluster.local"
fi

cat > certs/dex/csr.conf <<EOF
[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = dex.dex.svc.cluster.local

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = dex
DNS.2 = dex.dex
DNS.3 = dex.dex.svc
DNS.4 = dex.dex.svc.cluster.local
EOF

if [[ ! -f certs/dex/tls.crt ]]; then
    openssl x509 -req -in certs/dex/tls.csr \
      -CA certs/dex/ca.crt -CAkey certs/dex/ca.key -CAcreateserial \
      -out certs/dex/tls.crt -days 365 -sha256 \
      -extfile certs/dex/csr.conf -extensions v3_req
fi

### --- ECHO CERTS --- ###

if [[ ! -f certs/echo/tls.key ]]; then
    openssl genrsa -out certs/echo/tls.key 2048
    openssl req -new -key certs/echo/tls.key -out certs/echo/tls.csr -subj "/CN=echo.echo.svc.cluster.local"
fi

cat > certs/echo/csr.conf <<EOF
[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = echo.echo.svc.cluster.local

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = echo
DNS.2 = echo.echo
DNS.3 = echo.echo.svc
DNS.4 = echo.echo.svc.cluster.local
EOF

if [[ ! -f certs/echo/tls.crt ]]; then
    openssl x509 -req -in certs/echo/tls.csr \
      -CA certs/dex/ca.crt -CAkey certs/dex/ca.key -CAcreateserial \
      -out certs/echo/tls.crt -days 365 -sha256 \
      -extfile certs/echo/csr.conf -extensions v3_req
fi

echo "✅ Certificates generated for Dex and Echo."

