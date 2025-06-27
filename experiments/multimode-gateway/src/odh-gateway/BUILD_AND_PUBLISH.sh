#!/bin/bash

podman build -t registry.tannerjc.net/odh-proxy:latest .
podman push registry.tannerjc.net/odh-proxy:latest