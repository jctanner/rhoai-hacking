# ODH Dashboard Makefile

# Variables
IMAGE_NAME ?= odh-dashboard
IMAGE_TAG ?= latest
REGISTRY ?= registry.tannerjc.net
FULL_IMAGE = $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
CONTAINER_TOOL ?= podman

# Python/Flask commands
.PHONY: install
install:  ## Install Python dependencies
	pip install -r requirements.txt

.PHONY: dev
dev:  ## Run in development mode
	export FLASK_DEBUG=true && python app.py

.PHONY: run
run:  ## Run in production mode
	python app.py

.PHONY: test
test:  ## Run basic tests
	@echo "Testing health endpoint..."
	@curl -f http://localhost:5000/health || echo "Service not running"

# Container commands
.PHONY: build
build:  ## Build container image
	$(CONTAINER_TOOL) build -t $(IMAGE_NAME):$(IMAGE_TAG) .

.PHONY: build-registry
build-registry:  ## Build container image with registry name
	$(CONTAINER_TOOL) build -t $(FULL_IMAGE) .

.PHONY: run-container
run-container:  ## Run container locally
	$(CONTAINER_TOOL) run -p 5000:5000 --rm $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: push
push:  ## Push container image to registry
	$(CONTAINER_TOOL) tag $(IMAGE_NAME):$(IMAGE_TAG) $(FULL_IMAGE)
	$(CONTAINER_TOOL) push $(FULL_IMAGE)

.PHONY: publish
publish: build-registry push  ## Build and push container image to registry

# Kubernetes commands
.PHONY: deploy
deploy:  ## Deploy to Kubernetes
	kubectl apply -k k8s/

.PHONY: undeploy
undeploy:  ## Remove from Kubernetes
	kubectl delete -k k8s/

.PHONY: status
status:  ## Check deployment status
	kubectl get pods -l app=odh-dashboard
	kubectl get svc odh-dashboard-svc

.PHONY: logs
logs:  ## View pod logs
	kubectl logs -l app=odh-dashboard --tail=100 -f

.PHONY: port-forward
port-forward:  ## Port forward to local machine
	kubectl port-forward svc/odh-dashboard-svc 5000:80

# Utility commands
.PHONY: clean
clean:  ## Clean up local artifacts
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	$(CONTAINER_TOOL) image prune -f

.PHONY: help
help:  ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Default target
.DEFAULT_GOAL := help 