# ODH Gateway + Keycloak Demo

This example demonstrates the ODH Gateway with full OIDC authentication using Keycloak as the identity provider.

## 🚀 Quick Start

1. **Start the demo environment:**
   ```bash
   cd examples/keycloak-demo
   docker-compose up -d
   ```

2. **Wait for services to start:**
   ```bash
   # Check service health
   docker-compose ps
   
   # Watch logs (optional)
   docker-compose logs -f
   ```

3. **Access the services:**
   - **Gateway:** http://localhost:8080
   - **Keycloak Admin:** http://localhost:8090 (admin/admin)

## 🔐 Pre-configured Authentication

### Keycloak Configuration
- **Realm:** `odh`
- **Client ID:** `odh-gateway`
- **Client Secret:** `odh-gateway-secret-123`
- **Test User:** `testuser` / `password`

### Service Routes

| Route | Service | Authentication | Description |
|-------|---------|---------------|-------------|
| `/jupyter/` | Protected | ✅ Required | Jupyter Notebook service |
| `/mlflow/` | Protected | ✅ Required | MLflow tracking service |
| `/api/` | Protected | ✅ Required | Protected API service |
| `/docs/` | Public | ❌ None | Documentation service |
| `/health/` | Public | ❌ None | Health check service |
| `/` | Public | ❌ None | Welcome page |

## 🧪 Testing the Demo

### 1. Test Public Routes (No Auth Required)
```bash
# These should work without authentication
curl http://localhost:8080/docs/
curl http://localhost:8080/health/
curl http://localhost:8080/
```

### 2. Test Protected Routes (Auth Required)
```bash
# These should redirect to Keycloak login
curl -v http://localhost:8080/jupyter/
curl -v http://localhost:8080/mlflow/
curl -v http://localhost:8080/api/
```

### 3. Manual Browser Testing

1. **Access a public route:** http://localhost:8080/docs/
   - Should work immediately, showing echo service response

2. **Access a protected route:** http://localhost:8080/jupyter/
   - Should redirect to Keycloak login page
   - Login with: `testuser` / `password`
   - Should redirect back and show the service response

3. **Test SSO:** After logging in, visit http://localhost:8080/mlflow/
   - Should work without additional login (SSO)

## 🛠️ Keycloak Admin Interface

Access Keycloak admin at http://localhost:8090:
- **Username:** `admin`
- **Password:** `admin`

### Explore the Configuration
- **Realm:** ODH realm with pre-configured settings
- **Client:** `odh-gateway` client with correct redirect URIs
- **User:** `testuser` ready for testing

## 🔍 Troubleshooting

### Gateway Not Starting
```bash
# Check gateway logs
docker-compose logs odh-gateway

# Check if Keycloak is healthy
curl http://localhost:8090/realms/odh
```

### Authentication Issues
```bash
# Verify Keycloak realm endpoint
curl http://localhost:8090/realms/odh/.well-known/openid_configuration

# Check gateway OIDC configuration
docker-compose logs odh-gateway | grep -i oidc
```

### Service Connectivity
```bash
# Test individual services
docker-compose exec odh-gateway curl http://jupyter-service:80/
docker-compose exec odh-gateway curl http://keycloak:8090/realms/odh
```

## 🧹 Cleanup

```bash
# Stop and remove all containers
docker-compose down

# Remove volumes and networks
docker-compose down -v

# Clean up images (optional)
docker system prune
```

## 📝 Configuration Details

### Gateway Configuration (`config.yaml`)
- Mixed authentication requirements per route
- Echo services for easy testing
- Realistic service names (Jupyter, MLflow, etc.)

### Keycloak Realm (`keycloak-realm.json`)
- Pre-configured ODH realm
- OIDC client with proper redirect URIs
- Test user with simple credentials
- Standard OpenID Connect scopes

### Docker Compose Setup
- Health checks for all services
- Proper service dependencies
- Network isolation
- Volume mounts for configuration

## 🔧 Customization

### Adding New Routes
Edit `config.yaml`:
```yaml
routes:
  - path: /my-service/
    upstream: http://my-service:80
    authRequired: true  # or false for public
```

### Modifying Keycloak Settings
1. Use admin UI at http://localhost:8090
2. Or modify `keycloak-realm.json` and restart

### Changing Authentication Requirements
Update the `authRequired` field in `config.yaml` and restart the gateway:
```bash
docker-compose restart odh-gateway
```

This demo provides a complete, realistic OIDC authentication setup for testing and development! 🎉 