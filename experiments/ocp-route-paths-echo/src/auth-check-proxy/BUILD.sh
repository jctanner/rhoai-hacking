#!/bin/bash

set -e

podman build -t registry.tannerjc.net/echo-route-paths/auth-check-proxy:latest .
podman push registry.tannerjc.net/echo-route-paths/auth-check-proxy:latest
