#!/bin/bash

podman build -t registry.tannerjc.net/echo-route-paths/redirect-handler:latest .
podman push registry.tannerjc.net/echo-route-paths/redirect-handler:latest
