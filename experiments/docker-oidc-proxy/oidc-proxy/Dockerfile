FROM golang:1.24 AS builder

WORKDIR /app
COPY . .

RUN go mod tidy && go build -o oidc-proxy.bin
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
