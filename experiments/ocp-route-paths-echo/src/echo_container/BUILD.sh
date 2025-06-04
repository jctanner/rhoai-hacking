#!/bin/bash

podman build -t registry.tannerjc.net/echo-route-paths/echo-server:latest .
podman push registry.tannerjc.net/echo-route-paths/echo-server:latest
