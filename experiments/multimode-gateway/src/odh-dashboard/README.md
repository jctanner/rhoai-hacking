# ODH Dashboard

A Flask-based web dashboard that serves as the centralized landing page for the ODH Gateway system. This dashboard automatically discovers and displays all available services in your Open Data Hub environment.

## Overview

The ODH Dashboard is designed to be the **fallback route** (`/`) for the ODH Gateway, providing users with:

- **Service Directory**: Automatically displays all services discovered by the ODH Gateway
- **Centralized Access**: Single entry point for all ODH tools and services
- **Status Monitoring**: Real-time health status of services
- **User-Friendly Interface**: Clean, responsive design built with Bootstrap 5
- **Gateway Integration**: Seamlessly integrates with the ODH Gateway authentication system

## Features

### 🎯 Core Features
- **Automatic Service Discovery**: Displays services annotated for ODH Gateway discovery
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Real-time Updates**: Service status updates every 30 seconds
- **Health Monitoring**: Built-in health check endpoint for Kubernetes probes
- **Keyboard Shortcuts**: Alt+H (home), Alt+A (about), Alt+R (refresh)

### 🔒 Security
- **Non-root Container**: Runs as unprivileged user (UID 1000)
- **Security Context**: Drops all capabilities, prevents privilege escalation
- **Production Ready**: Uses Gunicorn WSGI server for production deployments

### 🚀 Performance
- **Lightweight**: Minimal dependencies, fast startup time
- **Caching**: Static assets served efficiently
- **Scalable**: Horizontal pod autoscaling ready

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Users         │──▶│   ODH Gateway   │──▶│   ODH Dashboard │
│   (Browser)     │    │   (Route "/")   │    │   (Flask App)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                         │
                              ▼                         ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │  Service        │    │  Service Data   │
                       │  Discovery      │    │  & Health       │
                       │  (Annotations)  │    │  Monitoring     │
                       └─────────────────┘    └─────────────────┘
```

## Quick Start

### Prerequisites

- Python 3.11+
- Docker (for containerization)
- Kubernetes cluster (for deployment)
- ODH Gateway Operator running in the cluster

### Local Development

1. **Clone and setup**:
```bash
cd src/odh-dashboard
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

2. **Run locally**:
```bash
export FLASK_DEBUG=true
python app.py
```

3. **Access dashboard**:
Open http://localhost:5000 in your browser

### Docker Build

```bash
# Build the image
docker build -t odh-dashboard:latest .

# Run container
docker run -p 5000:5000 odh-dashboard:latest
```

### Kubernetes Deployment

1. **Update image reference** in `k8s/deployment.yaml`:
```yaml
image: your-registry.com/odh-dashboard:latest
```

2. **Deploy to cluster**:
```bash
kubectl apply -k k8s/
```

3. **Verify deployment**:
```bash
kubectl get pods -l app=odh-dashboard
kubectl get svc odh-dashboard-svc
```

The service will be automatically discovered by the ODH Gateway Operator due to its annotations:
```yaml
annotations:
  odhgateway.opendatahub.io/enabled: "true"
  odhgateway.opendatahub.io/route-path: "/"
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLASK_DEBUG` | `False` | Enable debug mode for development |
| `SECRET_KEY` | `dev-secret-key-change-in-prod` | Flask secret key for sessions |
| `HOST` | `0.0.0.0` | Host to bind the server to |
| `PORT` | `5000` | Port to run the server on |

### Customization

#### Adding Custom Services

To display additional services, modify the `SAMPLE_SERVICES` list in `app.py`:

```python
SAMPLE_SERVICES = [
    {
        'name': 'Your Service',
        'description': 'Description of your service',
        'path': '/your-service',
        'icon': '🔧',
        'status': 'healthy'
    }
]
```

#### Styling

Custom CSS can be added to `static/css/dashboard.css`. The dashboard uses Bootstrap 5 with custom ODH-themed colors.

#### Templates

HTML templates are in the `templates/` directory:
- `base.html` - Base template with navigation and layout
- `dashboard.html` - Main dashboard page
- `about.html` - About page explaining the system
- `404.html`, `500.html` - Error pages

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Main dashboard page |
| `/about` | GET | About page |
| `/health` | GET | Health check endpoint (JSON) |
| `/api/services` | GET | Get services list (JSON) |

### Health Check Response

```json
{
  "status": "healthy",
  "timestamp": "2025-01-XX...",
  "service": "odh-dashboard"
}
```

## Integration with ODH Gateway

### Service Discovery

The dashboard automatically becomes the fallback route for the ODH Gateway through Kubernetes service annotations:

```yaml
metadata:
  annotations:
    odhgateway.opendatahub.io/enabled: "true"
    odhgateway.opendatahub.io/route-path: "/"
```

This means:
1. When users visit the gateway root URL, they see this dashboard
2. The dashboard displays all other discovered services
3. Users can click through to access specific tools
4. Authentication is handled by the gateway

### Route Priority

With the route sorting implemented in the ODH Gateway Operator:
- Specific routes (e.g., `/notebooks`, `/mlflow`) are matched first
- The dashboard's `/` route serves as the catch-all fallback
- This ensures proper routing while providing a useful landing page

## Development

### Project Structure

```
src/odh-dashboard/
├── app.py                 # Main Flask application
├── requirements.txt       # Python dependencies
├── Dockerfile            # Container image definition
├── templates/            # Jinja2 HTML templates
│   ├── base.html
│   ├── dashboard.html
│   ├── about.html
│   ├── 404.html
│   └── 500.html
├── static/               # Static assets
│   ├── css/
│   │   └── dashboard.css
│   └── js/
│       └── dashboard.js
└── k8s/                  # Kubernetes manifests
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml
```

### Adding Features

1. **New Pages**: Add routes in `app.py` and templates in `templates/`
2. **API Endpoints**: Add new routes with JSON responses
3. **Service Integration**: Modify service discovery logic
4. **Styling**: Update CSS in `static/css/dashboard.css`
5. **JavaScript**: Add interactivity in `static/js/dashboard.js`

### Testing

```bash
# Run with debug mode
export FLASK_DEBUG=true
python app.py

# Test health endpoint
curl http://localhost:5000/health

# Test API endpoint
curl http://localhost:5000/api/services
```

## Deployment Considerations

### Production Settings

- Set `FLASH_DEBUG=false` (default)
- Use a strong `SECRET_KEY`
- Configure proper resource limits
- Enable health checks
- Use HTTPS (handled by ODH Gateway)

### Scaling

The dashboard is stateless and can be horizontally scaled:

```yaml
spec:
  replicas: 3  # Increase as needed
```

### Monitoring

- Health checks: `/health` endpoint
- Logs: Standard Flask/Gunicorn logging
- Metrics: Can be extended with Prometheus metrics

## Troubleshooting

### Common Issues

1. **Dashboard not appearing in gateway**:
   - Check service annotations
   - Verify ODH Gateway Operator is running
   - Check gateway logs for service discovery

2. **Service list empty**:
   - Verify other services have proper annotations
   - Check if services are in the correct namespace
   - Review gateway operator namespace selector

3. **Styling issues**:
   - Check if static files are served correctly
   - Verify Bootstrap CDN is accessible
   - Check browser developer tools for errors

### Debugging

```bash
# Check pod logs
kubectl logs -l app=odh-dashboard

# Check service discovery
kubectl get svc -A -o jsonpath='{.items[?(@.metadata.annotations.odhgateway\.opendatahub\.io/enabled=="true")].metadata.name}'

# Test health endpoint
kubectl port-forward svc/odh-dashboard-svc 5000:80
curl http://localhost:5000/health
```

## Future Enhancements

- **Dynamic Service Discovery**: Real-time updates from Kubernetes API
- **User Management**: Integration with ODH user system
- **Metrics Dashboard**: Service usage and performance metrics
- **Theme Customization**: Multiple UI themes
- **Service Status**: Real health checks for backend services
- **Notifications**: Alert users to service status changes

## Contributing

This dashboard is part of the ODH Gateway experimental project. See the main project README for contribution guidelines.

## License

Same as the main ODH Gateway project - Apache License 2.0. 