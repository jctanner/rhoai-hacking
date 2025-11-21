# RHOAI/ODH Documentation Index

This directory contains comprehensive documentation about Red Hat OpenShift AI (RHOAI) and Open Data Hub (ODH) components, authentication patterns, and infrastructure integrations.

## Table of Contents

- [Platform Architecture](#platform-architecture)
- [Authentication & Authorization](#authentication--authorization)
- [Gateway & Service Mesh](#gateway--service-mesh)
- [Components & Operators](#components--operators)
- [Infrastructure & Tooling](#infrastructure--tooling)
- [Examples](#examples)

---

## Platform Architecture

### [DSCI_AND_DSC.md](DSCI_AND_DSC.md)
**DSCInitialization and DataScienceCluster Resources**

Explains the two core custom resources managed by the OpenDataHub operator:
- `DSCInitialization (DSCI)` - Platform foundation and common infrastructure setup
- `DataScienceCluster (DSC)` - Component management and configuration
- Resource relationship diagrams and controller workflows

### [IMAGES.md](IMAGES.md)
**OpenDataHub Platform Docker Images Catalog**

Comprehensive catalog of all Docker images used across the ODH platform:
- Image management system using environment variable substitution
- Parameter mappings and template substitution
- Categorized listings (operators, notebooks, ML frameworks, serving, etc.)
- Repository references

---

## Authentication & Authorization

### [OPENSHIFT_AUTH_MODE.md](OPENSHIFT_AUTH_MODE.md)
**OpenShift Authentication Modes**

Different authentication modes available in OpenShift:
- `IntegratedOAuth` mode using OpenShift OAuth server
- `OIDC` mode for direct external identity provider integration
- Feature gates and migration paths
- Architecture diagrams for each mode

### [OPENSHIFT-OAUTH-SERVER.md](OPENSHIFT-OAUTH-SERVER.md)
**OpenShift OAuth Server Documentation**

Architecture and implementation of OpenShift's OAuth server:
- Core components and HTTP request flow
- Username/password authentication vs token-based auth
- Integration with oauth-proxy sidecars
- Source code structure analysis

### [OIDC_OAUTH.md](OIDC_OAUTH.md)
**OIDC and OAuth Exploration**

Fundamental concepts in identity and access management:
- Realms and clients explained
- Keycloak-specific terminology
- Comparison across different identity providers
- Multi-tenant isolation patterns

### [K8S-OPENSHIFT-DIRECT-OIDC-GROUPS.md](K8S-OPENSHIFT-DIRECT-OIDC-GROUPS.md)
**Managing Groups with OIDC in Kubernetes**

Guidance for migrating from OpenShift-managed groups to direct OIDC authentication:
- User authentication flow
- Group management in external IDPs
- IdP group APIs (Keycloak, Microsoft Entra)
- RBAC integration patterns

### [OPENSHIFT-RBAC.md](OPENSHIFT-RBAC.md)
**OpenShift Authorization: RBAC and Security**

Comprehensive guide to Role-Based Access Control:
- RBAC fundamentals and security stack positioning
- Kubernetes RBAC primitives (Roles, RoleBindings, ClusterRoles)
- OpenShift RBAC extensions
- Practical implementation examples
- Security considerations and best practices

### [ODH-AUTH-CONTROLLER.md](ODH-AUTH-CONTROLLER.md)
**OpenDataHub Auth Controller Guide**

RBAC management system for ODH/RHOAI platform:
- Authorization controller (not authentication)
- Platform-aware RBAC management
- Group permissions handling
- Security-first design preventing privilege escalation

### [KUBE-RBAC-PROXY.md](KUBE-RBAC-PROXY.md)
**Comparing kube-rbac-proxy and oauth-proxy**

Analysis of two proxy solutions for Kubernetes RBAC:
- `kube-rbac-proxy` - Lightweight, per-request RBAC enforcement
- `oauth-proxy` - User-facing authentication with session management
- Architecture comparisons
- Use case recommendations

### [SCALABLE-OIDC-AUTHENTICATION.md](SCALABLE-OIDC-AUTHENTICATION.md)
**Scalable OIDC Authentication with Centralized Gateway Broker**

Superior architectural pattern using centralized authentication:
- Problems with per-application oauth-proxy sidecars
- Authorino and Gateway API solution
- Does not require service mesh
- Integration with external OIDC IDPs

---

## Gateway & Service Mesh

### [OCP_GATEWAY_HOWTO.md](OCP_GATEWAY_HOWTO.md)
**OpenShift Gateway API: Practical Usage Guide**

Implementation guide focused on using Gateway API in OpenShift:
- Understanding the 4 cluster-ingress-operator controllers
- Manual GatewayClass creation and namespace requirements
- Envoy Filter capabilities in gateway-only mode
- Single-node environment workarounds (SNO/CRC with Route bridge)
- DNS management details (listeners vs HTTPRoutes)
- Troubleshooting and debugging commands

### [OCP_GATEWAY_ARCHITECTURE.md](OCP_GATEWAY_ARCHITECTURE.md)
**Gateway API Architecture in OpenShift**

Complete architectural reference covering the full Gateway API stack:
- 3-layer architecture (cluster-ingress-operator → sail-operator → Istio)
- End-to-end data flows with diagrams
- Gateway address population from cloud load balancers
- DNS management flow across all layers
- Bare metal deployment scenarios and solutions
- File references with exact line numbers

### [GATEWAY_WASM.md](GATEWAY_WASM.md)
**Gateway API and WASM Extensions: Complete Implementation Guide**

Complete guide to extending Gateway API with WebAssembly:
- WASM extension architecture
- Building and deploying WASM plugins
- Integration with Istio and Envoy
- Kuadrant architecture deep dive
- Security considerations

### [BYOIDC_WASM_PLUGIN_DESIGN_DOC.md](BYOIDC_WASM_PLUGIN_DESIGN_DOC.md)
**BYOIDC WASM Plugin Design Document**

Design for custom WASM plugin bridging Istio Gateway API with existing OIDC services:
- Integration with kube-auth-proxy for ODH/RHOAI
- No service mesh requirement (Istio only for WasmPlugin CRD)
- Architecture and implementation approach
- FIPS-compliant authentication proxy patterns

### [ENVOY_AUTH.md](ENVOY_AUTH.md)
**Gateway API - OIDC/OAuth Authentication with Envoy Filters**

Sophisticated authentication capabilities in Envoy:
- OIDC/OAuth flows with external Identity Providers
- Redirect flows and token exchange
- Session cookie management
- JWT validation
- Integration examples

### [ENVOY-FILTER-OPENSHIFT-OAUTH-SERVICE.md](ENVOY-FILTER-OPENSHIFT-OAUTH-SERVICE.md)
**Using Envoy Auth Filter with OpenShift OAuth Server**

Analysis of integrating Envoy with OpenShift OAuth:
- Why direct integration with `oauth2` filter doesn't work
- `ext_authz` bridge service approach
- Comparison with oauth-proxy sidecar pattern
- Recommendations for different use cases

### [AUTHORINO.md](AUTHORINO.md)
**Authorino Integration in OpenDataHub Operator**

Optional authorization provider for Service Mesh functionality:
- JWT-based authentication and authorization
- External authorization for Istio/Maistra
- Conditional installation through DSC Initialization
- Integration points and feature management

### [ISTIO_ECOSYSTEM_AUTHSERVICE.md](ISTIO_ECOSYSTEM_AUTHSERVICE.md)
**Istio Ecosystem AuthService Deep Dive**

Sophisticated OIDC-aware external authorization server:
- Full OIDC Authorization Code Grant Flow handling
- Centralized OIDC login management
- Session management with pluggable stores
- Transparent token refresh
- Dynamic configuration and secrets

### [KUADRANT.md](KUADRANT.md)
**Kuadrant API Security Platform**

Kubernetes-native API security extending Gateway API:
- Platform architecture (Kuadrant Operator, Authorino, Limitador, WASM Shim)
- Works with Gateway API providers (Istio Gateway, Envoy Gateway)
- Policy attachment patterns
- Rate limiting and authentication integration
- Does not require full service mesh

---

## Components & Operators

### [KSERVE.md](KSERVE.md)
**KServe Component Deep Dive**

Machine learning model serving component:
- DSC schema configuration
- Integration with Istio Service Mesh and Serverless
- Deployment process and topology
- Traffic management and autoscaling features
- Sub-component architecture

### [WORKBENCHES_AND_NOTEBOOKS.md](WORKBENCHES_AND_NOTEBOOKS.md)
**Open Data Hub Projects Overview**

Notebook management capabilities in ODH ecosystem:
- Terminology: Notebooks vs Workbenches
- Individual Jupyter notebook instances
- Notebook infrastructure and controllers
- Resource management and culling
- Platform capabilities

### [RHOAI-MODEL-TESTING.md](RHOAI-MODEL-TESTING.md)
**RHOAI Model Testing**

Quick guide for creating and testing small predictive models:
- Workflow from dashboard to deployment
- PyTorch workbench setup
- S3 bucket configuration
- Training and prediction without GPU requirements

---

## Infrastructure & Tooling

### [CERT-MANAGER.md](CERT-MANAGER.md)
**Cert-Manager in OpenDataHub**

Native Kubernetes certificate management:
- Architecture and core components using cert-manager
- TLS certificate provisioning for ODH components
- Webhook configurations
- Integration patterns across the ecosystem

### [ODH-CERTIFICATE-MANAGEMENT.md](ODH-CERTIFICATE-MANAGEMENT.md)
**ODH Operator Certificate Management**

Comprehensive certificate management systems in ODH operator:
- TLS Certificate Management for KServe
- Trusted CA Bundle Management (certconfigmapgenerator)
- Component-specific TLS configurations
- User-provided certificate options

### [KEYCLOAK-GUIDANCE.md](KEYCLOAK-GUIDANCE.md)
**Keycloak Integration Guide**

Setting up Keycloak as an identity provider:
- Container setup (with and without external database)
- Realm and client configuration
- OpenShift BYOIDC integration
- ROSA (Red Hat OpenShift on AWS) integration
- ODH client configuration

### [CLAUDE_MCP_GUIDE.md](CLAUDE_MCP_GUIDE.md)
**MCP Server Guide**

Model Context Protocol for AI application integrations:
- Core concepts (Tools, Resources, Prompts)
- Building MCP servers
- Client integration patterns
- Common use cases and examples

---

## Examples

The [examples/](examples/) directory contains practical implementations and sample configurations referenced throughout the documentation.

---

## Document Generation

Most documents in this directory were created through AI-assisted source code analysis using Claude (Cursor.ai) in agent mode. The AI automatically parsed codebases, understood architecture patterns, and generated comprehensive documentation including diagrams, code references, and implementation details.

## Related Resources

- [OpenDataHub Documentation](https://opendatahub.io/docs.html)
- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Kuadrant Documentation](https://docs.kuadrant.io/)
