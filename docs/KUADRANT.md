# Kuadrant API Security Platform

This document provides a comprehensive overview of how the Kuadrant components work together to provide API security and traffic management on Kubernetes using Gateway API.

## Overview

**Kuadrant** is a Kubernetes-native API security platform that extends Gateway API providers (like Istio and Envoy Gateway) with additional security features through policy attachment. The platform consists of four main components that work together to provide comprehensive API protection:

1. **Kuadrant Operator** - The main orchestrator that manages the entire platform
2. **Authorino** - Authentication and authorization service
3. **Limitador** - Rate limiting service  
4. **WASM Shim** - Envoy proxy extension that bridges Gateway API and services

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                 Kuadrant Platform                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                 │
│  │ Kuadrant        │    │ AuthPolicy      │    │ RateLimitPolicy │                 │
│  │ Operator        │────│ (CRD)           │    │ (CRD)           │                 │
│  │                 │    │                 │    │                 │                 │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                 │
│           │                       │                       │                        │
│           │                       │                       │                        │
│           ▼                       ▼                       ▼                        │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                 │
│  │ Gateway API     │    │ Authorino       │    │ Limitador       │                 │
│  │ Resources       │    │ (AuthConfig)    │    │ (Rate Limits)   │                 │
│  │ (Gateway/       │    │                 │    │                 │                 │
│  │  HTTPRoute)     │    │                 │    │                 │                 │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                 │
│           │                       │                       │                        │
│           │              ┌────────┴────────┐              │                        │
│           │              │                 │              │                        │
│           ▼              ▼                 ▼              ▼                        │
│  ┌─────────────────────────────────────────────────────────────────────────────────┤
│  │                              Envoy Proxy                                       │
│  │                                                                                │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐             │
│  │  │ WASM Shim       │    │ External Auth   │    │ Rate Limit      │             │
│  │  │ (Kuadrant       │────│ Filter          │    │ Filter          │             │
│  │  │  Extension)     │    │                 │    │                 │             │
│  │  └─────────────────┘    └─────────────────┘    └─────────────────┘             │
│  └─────────────────────────────────────────────────────────────────────────────────┤
│                                        │                                           │
│                                        ▼                                           │
│                           ┌─────────────────────────────┐                        │
│                           │     Upstream Services        │                        │
│                           │      (Your APIs)            │                        │
│                           └─────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Component Detailed Breakdown

### 1. **Kuadrant Operator** (`kuadrant-operator`)

**Purpose**: Main orchestrator that manages the entire Kuadrant platform

**Key Features**:
- Manages lifecycle of all Kuadrant components
- Provides Gateway API policy attachment mechanism
- Defines Custom Resource Definitions (CRDs) for policies
- Handles mTLS configuration between components
- Supports both Istio and Envoy Gateway providers

**Primary CRDs**:
- `Kuadrant` - Main configuration resource
- `AuthPolicy` - Authentication and authorization policies
- `RateLimitPolicy` - Rate limiting policies
- `DNSPolicy` - DNS management policies
- `TLSPolicy` - TLS/SSL certificate policies

**Architecture Role**: 
- Watches Gateway API resources (Gateway, HTTPRoute)
- Translates high-level policies into component-specific configurations
- Manages the deployment and configuration of Authorino and Limitador
- Configures WASM Shim for Envoy integration

### 2. **Authorino** (`authorino`)

**Purpose**: Kubernetes-native external authorization service that handles authentication and authorization

**Key Features**:
- Implements Envoy External Authorization (ExtAuthz) gRPC protocol
- Supports multiple authentication methods (JWT, API keys, mTLS, OAuth2, etc.)
- Flexible authorization policies (pattern matching, OPA/Rego, K8s RBAC)
- External metadata fetching from various sources
- Custom response injection and callbacks

**Core Components**:
- `AuthConfig` CRD - Defines authentication and authorization rules
- External Authorization Server - gRPC service for Envoy
- Policy Engine - Evaluates auth rules in a 5-phase pipeline

**Authentication Phase Pipeline**:
1. **Identity Verification** - Validates credentials (JWT, API keys, mTLS, etc.)
2. **External Metadata** - Fetches additional context from external sources
3. **Authorization** - Evaluates policies (pattern matching, OPA, K8s RBAC)
4. **Response** - Builds custom responses and injects headers
5. **Callbacks** - Sends notifications to external endpoints

**Integration Points**:
- Receives policies from Kuadrant Operator via `AuthConfig` resources
- Integrates with Envoy through External Authorization filter
- Can be deployed cluster-wide or namespace-scoped
- Supports both centralized and sidecar deployment topologies

### 3. **Limitador** (`limitador`)

**Purpose**: Generic rate-limiting service written in Rust

**Key Features**:
- High-performance rate limiting with configurable storage backends
- Supports Redis, in-memory, and disk-based storage
- Implements Envoy Rate Limit Service (RLS) v3 gRPC protocol
- Flexible counter definitions and rate limit rules
- Distributed rate limiting across multiple instances

**Core Components**:
- Rate Limit Server - gRPC service implementing Envoy RLS protocol
- Storage Engine - Pluggable backend for storing rate limit counters
- HTTP API - REST endpoints for management and observability

**Rate Limiting Features**:
- Multiple rate limit rules per service
- Complex counter expressions using CEL (Common Expression Language)
- Hierarchical rate limit policies
- Integration with authentication context from Authorino

**Integration Points**:
- Receives rate limit configurations from Kuadrant Operator
- Integrates with Envoy through Rate Limit filter
- Can use authentication context from Authorino for user-based limiting
- Supports both global and per-user rate limiting

### 4. **WASM Shim** (`wasm-shim`)

**Purpose**: Proxy-WASM module that acts as a bridge between Envoy and Kuadrant services

**Key Features**:
- Written in Rust and compiled to WebAssembly
- Handles the integration between Gateway API and Kuadrant services
- Manages the flow of requests through authentication and rate limiting
- Supports CEL expressions for dynamic rule evaluation
- Optimizes service calls based on request conditions

**Core Functionality**:
- Evaluates route-level conditions using CEL predicates
- Orchestrates calls to Authorino and Limitador based on policy configuration
- Handles service failures with configurable failure modes
- Manages request context and passes data between services

**Configuration Structure**:
```yaml
services:
  auth-service:
    type: auth
    endpoint: auth-cluster
    failureMode: deny
    timeout: 10ms
  ratelimit-service:
    type: ratelimit
    endpoint: ratelimit-cluster
    failureMode: allow
actionSets:
  - name: policy-name
    routeRuleConditions:
      hostnames: ["*.example.com"]
      predicates:
        - request.url_path.startsWith("/api")
    actions:
      - service: auth-service
        scope: auth-scope
      - service: ratelimit-service
        scope: ratelimit-scope
```

**Integration Points**:
- Deployed as Envoy WASM extension
- Configured by Kuadrant Operator based on policies
- Communicates with Authorino and Limitador via gRPC
- Processes Gateway API routing rules and policy attachments

## Request Flow Architecture

### End-to-End Request Processing

```
┌─────────────┐    ┌─────────────────────────────────────────────────────────────────┐
│   Client    │    │                        Envoy Proxy                              │
│             │    │                                                                 │
│   Request   │──▶ │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│             │    │  │ WASM Shim       │    │ External Auth   │    │ Rate Limit  │ │
│             │    │  │ (Route          │──▶ │ Filter          │──▶ │ Filter      │ │
│             │    │  │  Evaluation)    │    │ (Authorino)     │    │ (Limitador) │ │
│             │    │  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│             │    │                                 │                      │        │
│             │    │                                 ▼                      ▼        │
│             │    │                    ┌─────────────────┐    ┌─────────────────┐   │
│             │    │                    │ Authorino       │    │ Limitador       │   │
│             │    │                    │ Service         │    │ Service         │   │
│             │    │                    │ (gRPC)         │    │ (gRPC)         │   │
│             │    │                    └─────────────────┘    └─────────────────┘   │
│             │    └─────────────────────────────────────────────────────────────────┘
│             │                                        │
│             │                                        ▼
│             │                            ┌─────────────────────────────┐
│   Response  │◀───────────────────────────│      Upstream Service       │
│             │                            │        (Your API)           │
└─────────────┘                            └─────────────────────────────┘
```

### Detailed Request Flow

1. **Request Arrives at Envoy**
   - Client sends request to Gateway endpoint
   - Envoy receives request and begins filter chain processing

2. **WASM Shim Evaluation**
   - WASM Shim evaluates route conditions using CEL expressions
   - Determines which policies apply to this request
   - Decides whether to call Authorino and/or Limitador

3. **Authentication Phase (if configured)**
   - Envoy External Auth filter calls Authorino
   - Authorino executes 5-phase auth pipeline:
     - Identity verification (JWT, API key, mTLS, etc.)
     - External metadata fetching
     - Authorization policy evaluation
     - Response building (headers, metadata)
     - Callback execution
   - Returns auth decision to Envoy

4. **Rate Limiting Phase (if configured)**
   - Envoy Rate Limit filter calls Limitador
   - Limitador evaluates rate limit rules
   - Checks counters against configured limits
   - Returns rate limit decision to Envoy

5. **Request Forwarding**
   - If authorized and within rate limits, request proceeds to upstream
   - Envoy forwards request with any injected headers/metadata
   - Upstream service processes request and returns response

6. **Response Processing**
   - Envoy processes response from upstream
   - Any response modifications from auth policies are applied
   - Response is returned to client

## Policy Architecture

### Gateway API Policy Attachment

Kuadrant uses the Gateway API Policy Attachment pattern to attach security policies to Gateway and HTTPRoute resources:

```yaml
# AuthPolicy attached to HTTPRoute
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: my-auth-policy
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: my-route
  rules:
    authentication:
      "api-key":
        credentials:
          keySelector:
            matchLabels:
              app: myapp
        authRules:
          - hosts: ["*.example.com"]
            operators:
              - matches: "/api/*"
```

```yaml
# RateLimitPolicy attached to Gateway
apiVersion: kuadrant.io/v1
kind: RateLimitPolicy
metadata:
  name: my-rate-limit-policy
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: my-gateway
  limits:
    "global":
      rates:
        - limit: 100
          window: 60s
    "per-user":
      when:
        - predicate: auth.identity.username != ""
      counters:
        - expression: auth.identity.username
      rates:
        - limit: 10
          window: 60s
```

### Policy Hierarchy and Merging

Kuadrant supports policy hierarchy where policies can be attached at different levels:

1. **Gateway Level** - Applies to all routes through the gateway
2. **HTTPRoute Level** - Applies to specific routes
3. **Service Level** - Applies to specific services (future)

**Policy Merging Strategies**:
- **Atomic** - Replace entire policy (default)
- **Merge** - Combine policies with rules from more specific policies taking precedence

### Policy Translation Process

1. **Kuadrant Operator** watches Gateway API resources and policies
2. **Policy Attachment** resolves which policies apply to which routes
3. **Policy Translation** converts high-level policies to component-specific resources:
   - `AuthPolicy` → `AuthConfig` (Authorino)
   - `RateLimitPolicy` → Rate limit rules (Limitador)
4. **WASM Configuration** generates action sets for the WASM Shim
5. **Envoy Configuration** updates filter configurations

## Deployment Topologies

### 1. Centralized Gateway Topology

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                               Kuadrant Gateway                                      │
│                                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                 │
│  │ Envoy Gateway   │    │ Authorino       │    │ Limitador       │                 │
│  │ (with WASM)     │────│ (Centralized)   │    │ (Centralized)   │                 │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                 │
│           │                                                                        │
│           │                                                                        │
├───────────┼────────────────────────────────────────────────────────────────────────┤
│           │                     Cluster Services                                   │
│           │                                                                        │
│           ▼                                                                        │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                 │
│  │ Service A       │    │ Service B       │    │ Service C       │                 │
│  │                 │    │                 │    │                 │                 │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                 │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2. Sidecar Topology

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                Service A Pod                                        │
│                                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                 │
│  │ Envoy Sidecar   │    │ Authorino       │    │ Limitador       │                 │
│  │ (with WASM)     │────│ (Sidecar)       │    │ (Sidecar)       │                 │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                 │
│           │                                                                        │
│           ▼                                                                        │
│  ┌─────────────────┐                                                              │
│  │ Service A       │                                                              │
│  │ (Application)   │                                                              │
│  └─────────────────┘                                                              │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 3. Hybrid Topology

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                               Kuadrant Gateway                                      │
│                                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                 │
│  │ Envoy Gateway   │    │ Authorino       │    │ Limitador       │                 │
│  │ (with WASM)     │────│ (Centralized)   │    │ (Centralized)   │                 │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                 │
│           │                                                                        │
├───────────┼────────────────────────────────────────────────────────────────────────┤
│           │                     Service Mesh                                       │
│           │                                                                        │
│           ▼                                                                        │
│  ┌─────────────────────────────────────────────────────────────────────────────────┤
│  │                            Service A Pod                                       │
│  │                                                                                │
│  │  ┌─────────────────┐    ┌─────────────────┐                                    │
│  │  │ Envoy Sidecar   │    │ Service A       │                                    │
│  │  │ (with WASM)     │────│ (Application)   │                                    │
│  │  └─────────────────┘    └─────────────────┘                                    │
│  └─────────────────────────────────────────────────────────────────────────────────┤
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Security Features

### Authentication Methods

**Supported by Authorino**:
- **JWT/OIDC** - JSON Web Tokens with OpenID Connect Discovery
- **API Keys** - Static API keys stored in Kubernetes Secrets
- **mTLS** - Mutual TLS certificate authentication
- **OAuth 2.0** - Token introspection with OAuth providers
- **Kubernetes ServiceAccount** - Native K8s authentication
- **Anonymous** - Allow unauthenticated access with context

### Authorization Policies

**Supported by Authorino**:
- **Pattern Matching** - JSON path-based rules on request context
- **OPA/Rego** - Open Policy Agent with Rego policy language
- **Kubernetes RBAC** - Native K8s role-based access control
- **SpiceDB** - External authorization with SpiceDB
- **External HTTP** - Call external authorization services

### Rate Limiting Features

**Supported by Limitador**:
- **Request-based** - Limits based on request count
- **User-based** - Limits based on authenticated user identity
- **IP-based** - Limits based on client IP address
- **Header-based** - Limits based on HTTP headers
- **Custom Counters** - CEL expressions for complex counting logic

## Configuration Examples

### Basic Authentication with Rate Limiting

```yaml
# Gateway configuration
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "*.example.com"

---
# HTTPRoute configuration
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
  - name: my-gateway
  hostnames:
  - "api.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: my-service
      port: 8080

---
# AuthPolicy configuration
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: my-auth-policy
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: my-route
  rules:
    authentication:
      "api-key":
        credentials:
          keySelector:
            matchLabels:
              app: myapp
      "jwt":
        jwt:
          issuerUrl: "https://auth.example.com"
          audiences: ["my-api"]
    authorization:
      "admin-only":
        when:
        - predicate: auth.identity.admin == true
        patternMatching:
          patterns:
          - selector: context.request.http.path
            operator: matches
            value: ^/admin/.*

---
# RateLimitPolicy configuration
apiVersion: kuadrant.io/v1
kind: RateLimitPolicy
metadata:
  name: my-rate-limit-policy
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: my-route
  limits:
    "global":
      rates:
      - limit: 1000
        window: 60s
    "per-user":
      when:
      - predicate: auth.identity.username != ""
      counters:
      - expression: auth.identity.username
      rates:
      - limit: 100
        window: 60s
    "anonymous":
      when:
      - predicate: auth.identity.anonymous == true
      rates:
      - limit: 10
        window: 60s
```

### Multi-Environment Configuration

```yaml
# Production AuthPolicy
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: production-auth
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: production-gateway
  defaults:
    strategy: merge
    rules:
      authentication:
        "jwt":
          jwt:
            issuerUrl: "https://auth.production.com"
            audiences: ["production-api"]
      authorization:
        "rbac":
          kubernetesSubjectAccessReview:
            user:
              selector: auth.identity.username
            resourceAttributes:
              group: ""
              resource: "services"
              verb: "get"

---
# Development AuthPolicy (more permissive)
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: development-auth
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: development-gateway
  rules:
    authentication:
      "dev-key":
        credentials:
          keySelector:
            matchLabels:
              environment: development
      "anonymous":
        anonymous: {}
```

## Monitoring and Observability

### Metrics

**Kuadrant Operator**:
- Policy reconciliation status
- Component health status
- Configuration errors

**Authorino**:
- Authentication success/failure rates
- Authorization decision latency
- Policy evaluation metrics
- Request context processing time

**Limitador**:
- Rate limit enforcement metrics
- Counter usage statistics
- Storage backend performance
- Rule evaluation latency

**WASM Shim**:
- Filter execution time
- Service call success/failure rates
- CEL expression evaluation performance

### Logs

**Structured Logging**:
- JSON format for all components
- Correlation IDs for request tracing
- Configurable log levels
- Integration with observability platforms

### Tracing

**Distributed Tracing**:
- OpenTelemetry integration
- Request flow tracing across components
- Performance bottleneck identification
- Service dependency mapping

## Troubleshooting

### Common Issues

1. **Policy Not Applied**
   - Check policy target references
   - Verify Gateway API resource names
   - Review policy merge strategies

2. **Authentication Failures**
   - Verify JWT issuer configuration
   - Check API key secret labels
   - Review certificate trust chains

3. **Rate Limiting Not Working**
   - Check counter expressions
   - Verify rate limit rule conditions
   - Review Limitador storage backend

4. **WASM Shim Issues**
   - Check Envoy filter configuration
   - Review CEL expression syntax
   - Verify service endpoint connectivity

### Debug Commands

```bash
# Check Kuadrant operator status
kubectl get kuadrant -n kuadrant-system

# Review AuthPolicy status
kubectl get authpolicies -A -o wide

# Check RateLimitPolicy status
kubectl get ratelimitpolicies -A -o wide

# View Authorino logs
kubectl logs -n kuadrant-system deployment/authorino

# View Limitador logs
kubectl logs -n kuadrant-system deployment/limitador

# Check WASM shim configuration
kubectl get envoyfilter -n istio-system -o yaml
```

## Best Practices

### Security

1. **Use mTLS** between components in production
2. **Implement defense in depth** with multiple authentication methods
3. **Regular secret rotation** for API keys and certificates
4. **Principle of least privilege** for authorization policies

### Performance

1. **Cache authentication tokens** when possible
2. **Use appropriate rate limiting windows** to avoid thundering herd
3. **Monitor resource usage** of all components
4. **Tune timeout values** based on network latency

### Operations

1. **Use GitOps** for policy management
2. **Implement policy testing** in CI/CD pipelines
3. **Monitor policy effectiveness** with metrics
4. **Plan for disaster recovery** with backup/restore procedures

## Integration with Other Systems

### Service Mesh

**Istio Integration**:
- Automatic policy attachment to Istio VirtualServices
- mTLS configuration for secure service communication
- Integration with Istio's telemetry and observability

**Linkerd Integration**:
- Policy enforcement at service mesh layer
- Integration with Linkerd's policy framework

### CI/CD Pipelines

**GitOps Integration**:
- Policy as Code with Git repositories
- Automated policy testing and validation
- Rollback capabilities for policy changes

**Security Scanning**:
- Integration with security scanning tools
- Policy compliance checking
- Vulnerability assessment of configurations

### External Systems

**Identity Providers**:
- OIDC/OAuth integration with external IdPs
- LDAP/Active Directory integration
- Multi-factor authentication support

**Policy Engines**:
- Integration with external OPA instances
- Custom policy decision points
- Compliance and governance systems

## Future Roadmap

### Planned Features

1. **Advanced Rate Limiting**
   - Adaptive rate limiting based on service health
   - Distributed rate limiting across regions
   - Machine learning-based anomaly detection

2. **Enhanced Security**
   - Web Application Firewall (WAF) integration
   - DDoS protection capabilities
   - Advanced threat detection

3. **Improved Observability**
   - Real-time policy dashboards
   - Automated policy recommendations
   - Compliance reporting

4. **Extended Platform Support**
   - Support for more Gateway API providers
   - Integration with serverless platforms
   - Multi-cloud deployment scenarios

### Community and Support

- **GitHub**: All components are open source on GitHub
- **Slack**: Join the #kuadrant channel in Kubernetes Slack
- **Documentation**: Comprehensive docs at docs.kuadrant.io
- **Community Calls**: Regular community meetings and demos

---

This documentation provides a comprehensive overview of how the Kuadrant components work together to provide enterprise-grade API security and traffic management on Kubernetes. For the latest information and detailed configuration examples, please refer to the individual component documentation and the official Kuadrant website. 