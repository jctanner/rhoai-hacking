#!/bin/bash

set -e

date

podman build -t registry.tannerjc.net/oidc-proxy:latest .
podman push registry.tannerjc.net/oidc-proxy:latest
