FROM registry.access.redhat.com/ubi9/go-toolset:1.24

USER root

# Install podman and other needed tools
RUN dnf install -y podman make git && dnf clean all

# Configure podman to work in rootless mode
RUN mkdir -p /home/default/.config/containers && \
    echo 'unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]' > /etc/containers/registries.conf

WORKDIR /workspace

USER default
