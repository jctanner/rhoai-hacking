# Multi-stage Dockerfile for Console Auth Proxy

# Build stage
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /src

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build arguments for version information
ARG VERSION=dev
ARG GIT_COMMIT=unknown
ARG BUILD_DATE=unknown

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s \
    -X github.com/your-org/console-auth-proxy/internal/version.Version=${VERSION} \
    -X github.com/your-org/console-auth-proxy/internal/version.GitCommit=${GIT_COMMIT} \
    -X github.com/your-org/console-auth-proxy/internal/version.BuildDate=${BUILD_DATE}" \
    -o console-auth-proxy \
    ./cmd/console-auth-proxy

# Final stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user
RUN addgroup -g 65532 -S proxy && \
    adduser -u 65532 -S proxy -G proxy

# Create directories
RUN mkdir -p /etc/console-auth-proxy /var/log/console-auth-proxy && \
    chown -R proxy:proxy /etc/console-auth-proxy /var/log/console-auth-proxy

# Copy binary from builder stage
COPY --from=builder /src/console-auth-proxy /usr/local/bin/console-auth-proxy

# Copy default configuration
COPY --from=builder /src/configs/production.yaml /etc/console-auth-proxy/config.yaml

# Set ownership and permissions
RUN chown proxy:proxy /usr/local/bin/console-auth-proxy && \
    chmod +x /usr/local/bin/console-auth-proxy

# Switch to non-root user
USER proxy

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/console-auth-proxy --help > /dev/null || exit 1

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/console-auth-proxy"]

# Default command
CMD ["--config", "/etc/console-auth-proxy/config.yaml"]

# Labels
LABEL org.opencontainers.image.title="Console Auth Proxy"
LABEL org.opencontainers.image.description="Standalone authentication reverse proxy using OpenShift Console auth module"
LABEL org.opencontainers.image.vendor="Console Auth Proxy"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/your-org/console-auth-proxy"