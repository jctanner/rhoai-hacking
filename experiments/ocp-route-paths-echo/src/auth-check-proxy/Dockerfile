# Stage 1: Build
FROM golang:1.24-alpine AS builder

WORKDIR /app
COPY auth-check-proxy.go .
RUN go build -ldflags="-s -w" -o auth-check-proxy auth-check-proxy.go

# Stage 2: Runtime
FROM alpine:latest

RUN apk add --no-cache ca-certificates
WORKDIR /app

COPY --from=builder /app/auth-check-proxy .

ENV UPSTREAM_URL=http://localhost:5000
ENV ROUTE_PREFIX=/echo/a
ENV LOGIN_PATH=/login

EXPOSE 8080
ENTRYPOINT ["./auth-check-proxy"]
