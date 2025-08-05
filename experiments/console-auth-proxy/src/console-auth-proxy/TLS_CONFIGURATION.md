# TLS Configuration Guide

This document describes the new TLS configuration options added to console-auth-proxy for handling self-signed certificates and SNI issues with both backend services and authentication providers.

## Overview

The console-auth-proxy now supports comprehensive TLS configuration for:
1. **Auth Provider Connections** (OIDC/OpenShift OAuth servers)
2. **Backend Service Connections** (the applications being protected)

## Configuration Options

### Auth Provider TLS Settings

Configure TLS settings for connections to your OIDC provider or OpenShift OAuth server:

```yaml
auth:
  # ... other auth settings ...
  tls:
    insecure_skip_verify: false  # Skip TLS certificate verification
    server_name: ""              # Override SNI server name
```

### Backend Service TLS Settings

Configure TLS settings for connections to your backend application:

```yaml
proxy:
  # ... other proxy settings ...
  tls:
    insecure_skip_verify: false  # Skip TLS certificate verification
    server_name: ""              # Override SNI server name
    ca_file: ""                  # Custom CA certificate file
    cert_file: ""                # Client certificate file
    key_file: ""                 # Client private key file
```

## Usage Examples

### 1. Skip Certificate Verification (Development Only)

**Via Configuration File:**
```yaml
auth:
  tls:
    insecure_skip_verify: true

proxy:
  tls:
    insecure_skip_verify: true
```

**Via CLI Flags:**
```bash
./console-auth-proxy \
  --auth-tls-insecure-skip-verify=true \
  --proxy-tls-insecure-skip-verify=true \
  --backend-url https://self-signed-app.internal \
  --issuer-url https://self-signed-oidc.internal
```

**Via Environment Variables:**
```bash
export CAP_AUTH_TLS_INSECURE_SKIP_VERIFY=true
export CAP_PROXY_TLS_INSECURE_SKIP_VERIFY=true
./console-auth-proxy
```

### 2. Override SNI Server Names

When the hostname in the URL doesn't match the certificate's Common Name:

**Via Configuration File:**
```yaml
auth:
  issuer_url: "https://192.168.1.100:8443"
  tls:
    server_name: "oidc-provider.internal"

proxy:
  backend:
    url: "https://10.0.0.50:8080"
  tls:
    server_name: "app.internal"
```

**Via CLI Flags:**
```bash
./console-auth-proxy \
  --issuer-url https://192.168.1.100:8443 \
  --auth-tls-server-name oidc-provider.internal \
  --backend-url https://10.0.0.50:8080 \
  --proxy-tls-server-name app.internal
```

**Via Environment Variables:**
```bash
export CAP_AUTH_TLS_SERVER_NAME=oidc-provider.internal
export CAP_PROXY_TLS_SERVER_NAME=app.internal
```

### 3. Custom CA Certificates

**For Backend Connections Only:**
```yaml
proxy:
  tls:
    ca_file: "/etc/ssl/ca/backend-ca.crt"
```

**For Auth Provider Connections:**
```yaml
auth:
  issuer_ca: "/etc/ssl/ca/auth-provider-ca.crt"
```

**Via CLI Flags:**
```bash
./console-auth-proxy \
  --proxy-tls-ca-file /etc/ssl/ca/backend-ca.crt \
  --issuer-ca /etc/ssl/ca/auth-provider-ca.crt
```

### 4. Client Certificate Authentication

**For Backend Connections:**
```yaml
proxy:
  tls:
    cert_file: "/etc/ssl/client/client.crt"
    key_file: "/etc/ssl/client/client.key"
    ca_file: "/etc/ssl/ca/backend-ca.crt"
```

**Via CLI Flags:**
```bash
./console-auth-proxy \
  --proxy-tls-cert-file /etc/ssl/client/client.crt \
  --proxy-tls-key-file /etc/ssl/client/client.key \
  --proxy-tls-ca-file /etc/ssl/ca/backend-ca.crt
```

## Complete CLI Reference

### Auth Provider TLS Options
| Flag | Environment Variable | Description |
|------|---------------------|-------------|
| `--auth-tls-insecure-skip-verify` | `CAP_AUTH_TLS_INSECURE_SKIP_VERIFY` | Skip TLS certificate verification for auth provider |
| `--auth-tls-server-name` | `CAP_AUTH_TLS_SERVER_NAME` | Override SNI server name for auth provider |

### Backend Proxy TLS Options  
| Flag | Environment Variable | Description |
|------|---------------------|-------------|
| `--proxy-tls-insecure-skip-verify` | `CAP_PROXY_TLS_INSECURE_SKIP_VERIFY` | Skip TLS certificate verification for backend |
| `--proxy-tls-server-name` | `CAP_PROXY_TLS_SERVER_NAME` | Override SNI server name for backend |
| `--proxy-tls-ca-file` | `CAP_PROXY_TLS_CA_FILE` | Custom CA file for backend connections |
| `--proxy-tls-cert-file` | `CAP_PROXY_TLS_CERT_FILE` | Client certificate file for backend |
| `--proxy-tls-key-file` | `CAP_PROXY_TLS_KEY_FILE` | Client private key file for backend |

## Real-World Examples

### Keycloak with Self-Signed Certificate
```bash
./console-auth-proxy \
  --backend-url https://app.internal:8080 \
  --issuer-url https://keycloak.internal:8443/auth/realms/myrealm \
  --client-id console-proxy \
  --client-secret mysecret \
  --redirect-url https://proxy.example.com/auth/callback \
  --auth-tls-insecure-skip-verify=true \
  --proxy-tls-insecure-skip-verify=true
```

### OpenShift OAuth with Custom SNI
```bash
./console-auth-proxy \
  --auth-source openshift \
  --backend-url https://10.0.0.100:8080 \
  --issuer-url https://oauth-openshift.apps.cluster.local \
  --auth-tls-server-name oauth-openshift.apps.cluster.example.com \
  --proxy-tls-server-name app.cluster.local
```

### Production Setup with Custom CAs
```yaml
auth:
  issuer_url: "https://corporate-sso.company.com"
  issuer_ca: "/etc/ssl/ca/corporate-ca.crt"
  
proxy:
  backend:
    url: "https://internal-app.company.com:8443"
  tls:
    ca_file: "/etc/ssl/ca/internal-ca.crt"
    cert_file: "/etc/ssl/client/proxy-client.crt"
    key_file: "/etc/ssl/client/proxy-client.key"
```

## Security Considerations

⚠️ **Warning:** The `insecure_skip_verify` option disables certificate verification and should **NEVER** be used in production environments. It's only suitable for development and testing.

### Recommended Production Settings:
1. **Always use valid certificates** with proper CA chains
2. **Use custom CA files** instead of skipping verification
3. **Ensure proper SNI configuration** rather than disabling verification
4. **Use client certificates** for mutual TLS when required

### Development vs Production:
- **Development:** `insecure_skip_verify: true` is acceptable for testing
- **Production:** Always use proper certificates and CA validation

## Troubleshooting

### Common Certificate Issues:
1. **"certificate signed by unknown authority"** → Use `ca_file` option
2. **"certificate is not valid for server name"** → Use `server_name` option  
3. **"TLS handshake timeout"** → Check network connectivity and certificate validity

### Debug Logging:
Enable debug logging to troubleshoot TLS issues:
```bash
export CAP_OBSERVABILITY_LOGGING_LEVEL=debug
```

## Migration Guide

If you were previously unable to connect to services with self-signed certificates, you can now:

1. **Enable insecure mode** for quick testing:
   ```bash
   --auth-tls-insecure-skip-verify=true --proxy-tls-insecure-skip-verify=true
   ```

2. **Provide custom CAs** for proper security:
   ```bash
   --issuer-ca /path/to/auth-ca.crt --proxy-tls-ca-file /path/to/backend-ca.crt
   ```

3. **Override SNI names** for IP-based connections:
   ```bash
   --auth-tls-server-name auth.internal --proxy-tls-server-name app.internal
   ```