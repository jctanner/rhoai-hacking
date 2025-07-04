# ODH Gateway Makefile

# Configuration variables
REGISTRY ?= registry.tannerjc.net
IMAGE_NAME ?= odh/odh-gateway
TAG ?= latest
FULL_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(TAG)

# Go configuration
GO_VERSION := 1.24
BINARY_NAME := odh-gateway-server
BUILD_DIR := ./bin

# Default target
.PHONY: all
all: build

# Build the container image
.PHONY: build
build:
	podman build -t $(FULL_IMAGE) .
	@echo "Built image: $(FULL_IMAGE)"

# Push the container image to registry
.PHONY: push
push:
	podman push $(FULL_IMAGE)
	@echo "Pushed image: $(FULL_IMAGE)"

# Build and push the container image
.PHONY: publish
publish: build push

# Build the Go binary locally
.PHONY: build-binary
build-binary:
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=linux go build -a -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/odh-gateway
	@echo "Binary built: $(BUILD_DIR)/$(BINARY_NAME)"

# Run tests
.PHONY: test
test:
	go test -v ./...

# Run the application locally
.PHONY: run
run:
	go run ./cmd/odh-gateway/main.go

# Clean up build artifacts
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	rm -f cert.pem cert.key
	podman rmi $(FULL_IMAGE) 2>/dev/null || true
	@echo "Cleaned up build artifacts, certificates, and local images"

# Download Go dependencies
.PHONY: deps
deps:
	go mod download
	go mod tidy

# Format Go code
.PHONY: fmt
fmt:
	go fmt ./...

# Run Go linter
.PHONY: lint
lint:
	@which golangci-lint > /dev/null || (echo "golangci-lint not installed. Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; exit 1)
	golangci-lint run

# Show image information
.PHONY: info
info:
	@echo "Registry: $(REGISTRY)"
	@echo "Image Name: $(IMAGE_NAME)"
	@echo "Tag: $(TAG)"
	@echo "Full Image: $(FULL_IMAGE)"
	@echo "Binary Name: $(BINARY_NAME)"
	@echo "Build Directory: $(BUILD_DIR)"

# Development target - build binary and run locally
.PHONY: dev
dev: build-binary
	$(BUILD_DIR)/$(BINARY_NAME)

# Development target with TLS (requires cert files)
.PHONY: dev-tls
dev-tls: build-binary
	$(BUILD_DIR)/$(BINARY_NAME) \
		--tls-cert-file=./cert.pem \
		--tls-key-file=./cert.key

# Generate self-signed certificates for development
.PHONY: gen-certs
gen-certs:
	@echo "Generating self-signed certificates..."
	openssl genrsa -out cert.key 2048
	openssl req -new -x509 -key cert.key -out cert.pem -days 365 \
		-subj "/C=US/ST=State/L=City/O=ODH-Gateway/CN=localhost"
	@echo "Generated cert.pem and cert.key"

# Run integration tests with docker-compose
.PHONY: test-integration
test-integration:
	@echo "Running integration tests..."
	docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from test-runner
	docker-compose -f docker-compose.test.yml down

# Build and run integration tests (clean slate)
.PHONY: test-integration-clean
test-integration-clean:
	@echo "Running integration tests (clean build)..."
	docker-compose -f docker-compose.test.yml down --volumes --remove-orphans || true
	docker-compose -f docker-compose.test.yml build --no-cache
	docker-compose -f docker-compose.test.yml up --abort-on-container-exit --exit-code-from test-runner
	docker-compose -f docker-compose.test.yml down

# OIDC integration tests
.PHONY: test-integration-oidc
test-integration-oidc:
	@echo "Running OIDC integration tests..."
	docker-compose -f docker-compose.oidc-test.yml up --build --abort-on-container-exit --exit-code-from oidc-test-runner
	docker-compose -f docker-compose.oidc-test.yml down

# Build and run OIDC integration tests (clean slate)
.PHONY: test-integration-oidc-clean
test-integration-oidc-clean:
	@echo "Running OIDC integration tests (clean build)..."
	docker-compose -f docker-compose.oidc-test.yml down --volumes --remove-orphans || true
	docker-compose -f docker-compose.oidc-test.yml build --no-cache
	docker-compose -f docker-compose.oidc-test.yml up --abort-on-container-exit --exit-code-from oidc-test-runner
	docker-compose -f docker-compose.oidc-test.yml down

# Run all integration tests
.PHONY: test-integration-all
test-integration-all: test-integration test-integration-oidc

# View integration test logs
.PHONY: test-logs
test-logs:
	docker-compose -f docker-compose.test.yml logs

# View OIDC integration test logs
.PHONY: test-integration-oidc-logs
test-integration-oidc-logs:
	docker-compose -f docker-compose.oidc-test.yml logs

# Clean up integration test resources
.PHONY: test-integration-clean
test-integration-clean:
	docker-compose -f docker-compose.test.yml down --volumes --remove-orphans
	docker-compose -f docker-compose.oidc-test.yml down --volumes --remove-orphans || true
	#docker system prune -f

# Help target
.PHONY: help
help:
	@echo "ODH Gateway Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  all          - Build the container image (default)"
	@echo "  build        - Build the container image"
	@echo "  push         - Push the container image to registry"
	@echo "  publish      - Build and push the container image"
	@echo "  build-binary - Build the Go binary locally"
	@echo "  test         - Run Go tests"
	@echo "  run          - Run the application locally with go run"
	@echo "  dev          - Build binary and run locally"
	@echo "  dev-tls      - Build binary and run locally with TLS"
	@echo "  gen-certs    - Generate self-signed certificates for development"
	@echo "  test-integration - Run integration tests with docker-compose"
	@echo "  test-integration-clean - Run integration tests with clean build"
	@echo "  test-integration-oidc - Run OIDC integration tests"
	@echo "  test-integration-oidc-clean - Run OIDC integration tests with clean build"
	@echo "  test-integration-all - Run all integration tests (basic + OIDC)"
	@echo "  test-logs    - View integration test logs"
	@echo "  test-integration-oidc-logs - View OIDC integration test logs"
	@echo "  test-integration-clean - Clean up integration test resources"
	@echo "  clean        - Clean up build artifacts and local images"
	@echo "  deps         - Download and tidy Go dependencies"
	@echo "  fmt          - Format Go code"
	@echo "  lint         - Run Go linter (requires golangci-lint)"
	@echo "  info         - Show build configuration"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Configuration variables:"
	@echo "  REGISTRY     - Container registry (default: $(REGISTRY))"
	@echo "  IMAGE_NAME   - Container image name (default: $(IMAGE_NAME))"
	@echo "  TAG          - Container image tag (default: $(TAG))"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make publish"
	@echo "  make test-integration"
	@echo "  make test-integration-oidc"
	@echo "  make test-integration-all"
	@echo "  make gen-certs && make dev-tls"
	@echo "  make build REGISTRY=my-registry.com IMAGE_NAME=my-proxy TAG=v1.0.0"
	@echo "  make publish TAG=latest" 