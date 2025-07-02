# ODH Gateway Integration Tests

This directory contains docker-compose based integration tests for the ODH Gateway that validate basic proxy functionality without OIDC authentication.

## Test Architecture

The integration test setup includes:

- **ODH Gateway**: The service being tested
- **Multiple Upstream Services**: Simulated services (Jupyter, MLflow, Docs, API, Default)
- **Test Runner**: Automated test script that validates proxy behavior
- **Network Isolation**: All services run in an isolated Docker network

## Test Coverage

The integration tests validate:

1. **Basic Routing**: Each configured route properly forwards to upstream services
2. **Subpath Routing**: Requests to subpaths are correctly proxied
3. **Fallback Route**: Unknown paths are handled by the default service
4. **Path Normalization**: Routes work both with and without trailing slashes
5. **HTTP Response Validation**: Correct content is returned from upstream services

## Running Tests

### Quick Test Run
```bash
make test-integration
```

### Clean Build Test (recommended for CI)
```bash
make test-integration-clean
```

### Manual Docker Compose
```bash
# Build and run tests
docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit

# Clean up
docker-compose -f docker-compose.test.yml down
```

## Test Scenarios

| Test Case | URL | Expected Upstream | Validates |
|-----------|-----|-------------------|-----------|
| Jupyter service | `/jupyter/` | jupyter-service | Basic routing |
| Jupyter Lab | `/jupyter/lab` | jupyter-service | Subpath routing |
| MLflow service | `/mlflow/` | mlflow-service | Basic routing |
| MLflow experiments | `/mlflow/experiments` | mlflow-service | Subpath routing |
| Documentation | `/docs/` | docs-service | Basic routing |
| API docs | `/docs/api` | docs-service | Subpath routing |
| API service | `/api/` | api-service | Basic routing |
| API health | `/api/health` | api-service | Subpath routing |
| Root fallback | `/` | default-service | Fallback routing |
| Unknown path | `/unknown-path` | default-service | Fallback routing |
| No trailing slash | `/jupyter` | jupyter-service | Path normalization |

## Test Configuration

The test uses a dedicated configuration file at `test/config.yaml` with the following routes:

```yaml
routes:
  - path: "/jupyter/"
    upstream: "http://jupyter-service:80"
  - path: "/mlflow/"
    upstream: "http://mlflow-service:80"
  - path: "/docs/"
    upstream: "http://docs-service:80"
  - path: "/api/"
    upstream: "http://api-service:80"
  - path: "/"
    upstream: "http://default-service:80"
```

## Upstream Services

Each upstream service is implemented as an nginx container serving static HTML files that identify the service:

- **jupyter-service**: Serves Jupyter-related content
- **mlflow-service**: Serves MLflow-related content
- **docs-service**: Serves documentation content
- **api-service**: Serves API-related content
- **default-service**: Serves default/fallback content

## Test Output

The test runner provides colored output showing:
- ✅ **Green**: Passing tests
- ❌ **Red**: Failing tests
- 🟡 **Yellow**: Test information

Example output:
```
2024-01-15 10:30:45 === Starting ODH Gateway Integration Tests ===
2024-01-15 10:30:47 Testing: Jupyter service proxy
2024-01-15 10:30:47 ✓ PASS: Jupyter service proxy
2024-01-15 10:30:49 Testing: MLflow service proxy
2024-01-15 10:30:49 ✓ PASS: MLflow service proxy
...
2024-01-15 10:31:15 === Test Results ===
2024-01-15 10:31:15 Total tests: 11
2024-01-15 10:31:15 Passed: 11
2024-01-15 10:31:15 Failed: 0
2024-01-15 10:31:15 All tests passed! 🎉
```

## Debugging

### View logs from all services
```bash
make test-logs
```

### Debug individual services
```bash
# Start services without running tests
docker-compose -f docker-compose.test.yml up odh-gateway jupyter-service mlflow-service

# Test manually
curl http://localhost:8080/jupyter/
curl http://localhost:8080/mlflow/
```

### Clean up
```bash
make test-clean
```

## Extending Tests

To add new test scenarios:

1. Add a new upstream service to `docker-compose.test.yml`
2. Create HTML files in `test/your-service/`
3. Add the route to `test/config.yaml`
4. Add test cases to `test/run-tests.sh`

## CI/CD Integration

The tests are designed to work in CI/CD pipelines:

- **Exit Codes**: Tests return 0 on success, 1 on failure
- **Docker-based**: No local dependencies beyond Docker
- **Isolated**: Uses dedicated network and containers
- **Clean**: Automatically cleans up resources

Example GitHub Actions usage:
```yaml
- name: Run Integration Tests
  run: make test-integration-clean
``` 