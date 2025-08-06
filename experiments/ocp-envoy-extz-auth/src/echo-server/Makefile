IMAGE = registry.tannerjc.net/echo-server:latest

.PHONY: all build push

all: build

build:
	docker buildx build --load -t $(IMAGE) .

push: build
	docker push $(IMAGE)
