# Base Images

This directory contains Dockerfiles for base images used by the ODH Gateway system components. By maintaining our own base images, we avoid Docker Hub rate limits and have better control over our build dependencies.

## Available Images

| Image                          | Tag         | Source             | Used By                        |
| ------------------------------ | ----------- | ------------------ | ------------------------------ |
| `registry.tannerjc.net/golang` | `1.23`      | `golang:1.23`      | ODH Gateway Operator           |
| `registry.tannerjc.net/golang` | `1.24`      | `golang:1.24`      | Notebook Operator, ODH Gateway |
| `registry.tannerjc.net/python` | `3.11-slim` | `python:3.11-slim` | ODH Dashboard                  |

## Building and Pushing Base Images

### Build All Images

```bash
cd src/baseimages
make build
```

### Push All Images to Registry

```bash
cd src/baseimages
make push
```

### Build and Push Everything

```bash
cd src/baseimages
make all
```

### Build Individual Images

```bash
cd src/baseimages
make golang-1.23
make golang-1.24
make python-3.11
```

### Push Individual Images

```bash
cd src/baseimages
make push-golang-1.23
make push-golang-1.24
make push-python-3.11
```

## Configuration

You can override the registry and container tool:

```bash
make all REGISTRY=your-registry.com CONTAINER_TOOL=docker
```

## First Time Setup

1. Build and push all base images:

   ```bash
   cd src/baseimages
   make all
   ```

2. The base images will be available for use by other components.

## Maintenance

- **Update Go versions**: Edit `Dockerfile.golang-1.23` or `Dockerfile.golang-1.24` and rebuild
- **Update Python version**: Edit `Dockerfile.python-3.11` and rebuild
- **Add new base images**: Create new `Dockerfile.name` and add targets to `Makefile`

## Benefits

- ✅ No Docker Hub rate limits
- ✅ Consistent base images across all builds
- ✅ Controlled updates and security patches
- ✅ Faster builds (cached in our registry)
- ✅ Independence from external registries
