REGISTRY ?= registry.tannerjc.net
CONTAINER_TOOL ?= podman

.PHONY: all build push golang-1.23 golang-1.24 python-3.11 clean

# Build and push all base images
all: build push

# Build all base images
build: golang-1.23 golang-1.24 python-3.11

# Push all base images
push: push-golang-1.23 push-golang-1.24 push-python-3.11

# Build Go 1.23 base image
golang-1.23:
	$(CONTAINER_TOOL) build --no-cache -f Dockerfile.golang-1.23 -t $(REGISTRY)/golang:1.23 .

# Build Go 1.24 base image  
golang-1.24:
	$(CONTAINER_TOOL) build --no-cache -f Dockerfile.golang-1.24 -t $(REGISTRY)/golang:1.24 .

# Build Python 3.11 base image
python-3.11:
	$(CONTAINER_TOOL) build --no-cache -f Dockerfile.python-3.11 -t $(REGISTRY)/python:3.11-slim .

# Push Go 1.23 base image
push-golang-1.23: golang-1.23
	$(CONTAINER_TOOL) push $(REGISTRY)/golang:1.23

# Push Go 1.24 base image
push-golang-1.24: golang-1.24
	$(CONTAINER_TOOL) push $(REGISTRY)/golang:1.24

# Push Python 3.11 base image
push-python-3.11: python-3.11
	$(CONTAINER_TOOL) push $(REGISTRY)/python:3.11-slim

# Clean up local images
clean:
	$(CONTAINER_TOOL) rmi $(REGISTRY)/golang:1.23 || true
	$(CONTAINER_TOOL) rmi $(REGISTRY)/golang:1.24 || true
	$(CONTAINER_TOOL) rmi $(REGISTRY)/python:3.11-slim || true

# Show help
help:
	@echo "Available targets:"
	@echo "  all             - Build and push all base images"
	@echo "  build           - Build all base images locally"
	@echo "  push            - Push all base images to registry"
	@echo "  golang-1.23     - Build Go 1.23 base image"
	@echo "  golang-1.24     - Build Go 1.24 base image"
	@echo "  python-3.11     - Build Python 3.11 base image"
	@echo "  clean           - Remove local base images"
	@echo "  help            - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY        - Registry to push to (default: $(REGISTRY))"
	@echo "  CONTAINER_TOOL  - Container tool to use (default: $(CONTAINER_TOOL)) 
