FROM registry.access.redhat.com/ubi9/go-toolset:1.25

USER root

# Install podman and build tools
RUN dnf install -y podman make git && dnf clean all

# Configure podman to skip signature verification for nested builds
RUN cat > /etc/containers/policy.json << 'EOF'
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ],
    "transports": {
        "docker-daemon": {
            "": [
                {
                    "type": "insecureAcceptAnything"
                }
            ]
        }
    }
}
EOF

# Configure podman registries
RUN mkdir -p /home/default/.config/containers && \
    echo 'unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]' > /etc/containers/registries.conf

WORKDIR /workspace
USER default
