# Variables
IMAGE_TAG = registry.tannerjc.net/xds-controller-test:latest
DOCKERFILE_PATH = ./src/xds-server

# Targets
.PHONY: all build push

all: build

# Build the OCI-compliant Docker image
build:
	@echo "Building OCI image: $(IMAGE_TAG)..."
	docker build -t $(IMAGE_TAG) $(DOCKERFILE_PATH)

# Push the Docker image to the registry
# This target depends on 'build' to ensure the image is built before pushing.
push: build
	@echo "Pushing image: $(IMAGE_TAG)..."
	docker push $(IMAGE_TAG)


