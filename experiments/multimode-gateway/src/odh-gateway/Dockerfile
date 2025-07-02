# syntax=docker/dockerfile:1

# Stage 1: Build
FROM registry.tannerjc.net/golang:1.24 AS builder

WORKDIR /app

# Copy go.mod and go.sum first for caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -o odh-gateway-server ./cmd/odh-gateway

# Stage 2: Final image
FROM registry.access.redhat.com/ubi9/ubi:latest

WORKDIR /

COPY --from=builder /app/odh-gateway-server /odh-gateway-server

ENTRYPOINT ["/odh-gateway-server"]