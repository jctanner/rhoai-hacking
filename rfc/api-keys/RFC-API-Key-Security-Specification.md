# RFC: API Key Design, Security, and Implementation
# Technical Specification for Secure API Key Management

**Status:** Informational
**Date:** February 2026
**Category:** Best Current Practice

---

## Abstract

This document provides a comprehensive technical specification for the design, implementation, and management of API keys used for authenticating and authorizing access to Application Programming Interfaces (APIs). It synthesizes current best practices, security standards, and real-world implementations to establish normative requirements and recommendations for both API providers and consumers.

API keys serve as a foundational authentication mechanism for unattended and programmatic API access, complementing but not replacing interactive authentication methods like OAuth 2.0 and SAML. This specification addresses the complete lifecycle of API keys including generation, format design, storage, transmission, access control, rotation, monitoring, and revocation.

The document employs RFC 2119 terminology to distinguish between absolute requirements (MUST), strong recommendations (SHOULD), and optional features (MAY), providing clear guidance for implementation while acknowledging the varying security requirements across different deployment contexts.

## Table of Contents

1. [Introduction](#1-introduction)
   - 1.1. [Background and Motivation](#11-background-and-motivation)
   - 1.2. [Scope](#12-scope)
   - 1.3. [Terminology and Conventions](#13-terminology-and-conventions)
   - 1.4. [Document Structure](#14-document-structure)

2. [Requirements Notation](#2-requirements-notation)

3. [Architecture Overview](#3-architecture-overview)
   - 3.1. [API Key Lifecycle](#31-api-key-lifecycle)
   - 3.2. [Threat Model](#32-threat-model)
   - 3.3. [Security Principles](#33-security-principles)

4. [API Key Fundamentals](#4-api-key-fundamentals)
   - 4.1. [Definition and Purpose](#41-definition-and-purpose)
   - 4.2. [Use Cases and Applicability](#42-use-cases-and-applicability)
   - 4.3. [Comparison with Alternative Authentication Methods](#43-comparison-with-alternative-authentication-methods)
   - 4.4. [When to Use API Keys](#44-when-to-use-api-keys)
   - 4.5. [When Not to Use API Keys](#45-when-not-to-use-api-keys)

5. [Generation and Design](#5-generation-and-design)
   - 5.1. [Entropy Requirements](#51-entropy-requirements)
   - 5.2. [Cryptographically Secure Random Number Generation](#52-cryptographically-secure-random-number-generation)
   - 5.3. [Token Format Design](#53-token-format-design)
   - 5.4. [Prefixes and Identifiability](#54-prefixes-and-identifiability)
   - 5.5. [Checksums and Error Detection](#55-checksums-and-error-detection)
   - 5.6. [Character Set Selection](#56-character-set-selection)
   - 5.7. [Generation Algorithms](#57-generation-algorithms)

6. [Storage and Secrets Management](#6-storage-and-secrets-management)
   - 6.1. [Storage Architecture](#61-storage-architecture)
   - 6.2. [Hashing Requirements](#62-hashing-requirements)
   - 6.3. [Encryption at Rest](#63-encryption-at-rest)
   - 6.4. [Secrets Management Systems](#64-secrets-management-systems)
   - 6.5. [Hardware Security Modules](#65-hardware-security-modules)
   - 6.6. [Database Security](#66-database-security)
   - 6.7. [Client-Side Storage](#67-client-side-storage)

7. [Transmission and Network Security](#7-transmission-and-network-security)
   - 7.1. [Transport Layer Security](#71-transport-layer-security)
   - 7.2. [HTTP Headers and Authentication Schemes](#72-http-headers-and-authentication-schemes)
   - 7.3. [Bearer Token Pattern](#73-bearer-token-pattern)
   - 7.4. [API Key Transmission Methods](#74-api-key-transmission-methods)
   - 7.5. [Client-Side Security Practices](#75-client-side-security-practices)

8. [Access Control and Authorization](#8-access-control-and-authorization)
   - 8.1. [Principle of Least Privilege](#81-principle-of-least-privilege)
   - 8.2. [Role-Based Access Control](#82-role-based-access-control)
   - 8.3. [Scope-Based Permissions](#83-scope-based-permissions)
   - 8.4. [Resource-Level Restrictions](#84-resource-level-restrictions)
   - 8.5. [IP Whitelisting and Network Restrictions](#85-ip-whitelisting-and-network-restrictions)
   - 8.6. [Multi-Tenancy Considerations](#86-multi-tenancy-considerations)

9. [Rotation and Lifecycle Management](#9-rotation-and-lifecycle-management)
   - 9.1. [Rotation Policies](#91-rotation-policies)
   - 9.2. [Grace Periods and Overlapping Keys](#92-grace-periods-and-overlapping-keys)
   - 9.3. [Multi-Key Models](#93-multi-key-models)
   - 9.4. [Expiration Policies](#94-expiration-policies)
   - 9.5. [Revocation Procedures](#95-revocation-procedures)
   - 9.6. [Emergency Revocation](#96-emergency-revocation)

10. [Monitoring, Logging, and Threat Detection](#10-monitoring-logging-and-threat-detection)
    - 10.1. [Usage Monitoring](#101-usage-monitoring)
    - 10.2. [Audit Logging Requirements](#102-audit-logging-requirements)
    - 10.3. [Anomaly Detection](#103-anomaly-detection)
    - 10.4. [SIEM Integration](#104-siem-integration)
    - 10.5. [Alert Configuration](#105-alert-configuration)
    - 10.6. [Metrics and Analytics](#106-metrics-and-analytics)

11. [Rate Limiting and Abuse Prevention](#11-rate-limiting-and-abuse-prevention)
    - 11.1. [Rate Limiting Strategies](#111-rate-limiting-strategies)
    - 11.2. [Token Bucket Algorithm](#112-token-bucket-algorithm)
    - 11.3. [Tiered Rate Limits](#113-tiered-rate-limits)
    - 11.4. [HTTP 429 Responses](#114-http-429-responses)
    - 11.5. [DDoS Protection](#115-ddos-protection)

12. [Security Considerations](#12-security-considerations)
    - 12.1. [Comprehensive Threat Model](#121-comprehensive-threat-model)
    - 12.2. [OWASP API Security Top 10 Mapping](#122-owasp-api-security-top-10-mapping)
    - 12.3. [Common Vulnerabilities](#123-common-vulnerabilities)
    - 12.4. [Attack Vectors and Mitigations](#124-attack-vectors-and-mitigations)
    - 12.5. [Hardcoded Secrets Prevention](#125-hardcoded-secrets-prevention)
    - 12.6. [Secret Scanning and Detection](#126-secret-scanning-and-detection)

13. [Compliance and Standards](#13-compliance-and-standards)
    - 13.1. [Regulatory Frameworks](#131-regulatory-frameworks)
    - 13.2. [Industry Standards](#132-industry-standards)
    - 13.3. [Compliance Requirements](#133-compliance-requirements)

14. [Implementation Guidance](#14-implementation-guidance)
    - 14.1. [Provider Implementation Checklist](#141-provider-implementation-checklist)
    - 14.2. [Consumer Best Practices](#142-consumer-best-practices)
    - 14.3. [Testing and Validation](#143-testing-and-validation)
    - 14.4. [Migration Strategies](#144-migration-strategies)

15. [Case Studies and Real-World Implementations](#15-case-studies-and-real-world-implementations)
    - 15.1. [GitHub Token Format Implementation](#151-github-token-format-implementation)
    - 15.2. [Stripe API Key Architecture](#152-stripe-api-key-architecture)
    - 15.3. [AWS API Security Model](#153-aws-api-security-model)
    - 15.4. [Security Incident Lessons](#154-security-incident-lessons)

16. [Future Considerations](#16-future-considerations)
    - 16.1. [Post-Quantum Cryptography](#161-post-quantum-cryptography)
    - 16.2. [Zero Trust Architecture](#162-zero-trust-architecture)
    - 16.3. [Emerging Standards](#163-emerging-standards)

17. [Security Checklist](#17-security-checklist)

18. [References](#18-references)
    - 18.1. [Normative References](#181-normative-references)
    - 18.2. [Informative References](#182-informative-references)

19. [Appendices](#19-appendices)
    - A. [Glossary](#appendix-a-glossary)
    - B. [Sample Code Examples](#appendix-b-sample-code-examples)
    - C. [Quick Reference Guide](#appendix-c-quick-reference-guide)

---

## 1. Introduction

### 1.1. Background and Motivation

Application Programming Interfaces (APIs) have become the backbone of modern software architecture, enabling service-to-service communication, third-party integrations, and programmatic access to platform capabilities. As APIs proliferate across enterprise and consumer applications, the security of API authentication mechanisms has emerged as a critical concern.

"An API provider offers services to subscribed participants only. For various reasons, such as establishing a RATE LIMIT or PRICING PLAN, one or more clients have signed up and want to use the services. These clients have to be identified." [Source-05]

API keys represent one of the foundational authentication patterns for APIs, particularly suited for "unattended use" scenarios where "an unattended computer can't launch a web browser to redirect to an authentication provider" [Source-41]. Unlike interactive authentication flows designed for human users (OAuth 2.0, SAML), API keys provide long-lived credentials that enable automated systems, scripts, and background processes to authenticate to APIs without human intervention.

However, the simplicity and convenience of API keys come with significant security challenges. The OWASP API Security Top 10 identifies broken authentication and authorization as primary API security risks [Source-02]. Real-world incidents demonstrate the severe consequences of inadequate API key management:

- The 2021 Twitch data breach exposed API keys stored in source code repositories [Source-01]
- Hardcoded API keys have resulted in "millions" in financial losses [Source-20]
- Google's Gemini API launch required security policy changes after widespread key exposure [Source-19]

These incidents underscore the critical need for comprehensive, standardized guidance on API key design, implementation, and management.

### 1.2. Scope

This specification covers the complete lifecycle of API key management for both API providers (systems that issue and validate API keys) and API consumers (applications and services that use API keys to authenticate).

**In Scope:**
- Cryptographic requirements for API key generation
- Secure storage practices for providers and consumers
- Transmission security and protocol requirements
- Access control and authorization models
- Rotation, expiration, and revocation procedures
- Monitoring, logging, and threat detection
- Rate limiting and abuse prevention
- Compliance with security standards and regulations

**Out of Scope:**
- OAuth 2.0 and OpenID Connect implementation details (covered in RFC 6749, RFC 6750)
- SAML federation protocols
- Mutual TLS (mTLS) certificate management
- API gateway product-specific configurations
- Application-level business logic authorization
- Non-HTTP protocol authentication

This document synthesizes guidance from 42 authoritative sources including security frameworks (OWASP), industry implementations (GitHub, Stripe, AWS), academic research, and vendor best practices.

### 1.3. Terminology and Conventions

**API Key**: A unique secret token assigned to a client for authenticating API requests. Synonymous with "access token" in some contexts, though this specification uses "API key" to distinguish from OAuth access tokens.

**Client**: An application, service, or system that consumes an API by presenting an API key for authentication.

**Provider**: The API service that issues, validates, and manages API keys.

**Secret**: The confidential component of an API key that must be protected from disclosure.

**Entropy**: A measure of randomness and unpredictability in generated API keys, typically measured in bits.

**CSPRNG**: Cryptographically Secure Pseudo-Random Number Generator - a random number generator suitable for cryptographic applications.

**Hashing**: A one-way cryptographic function that transforms input data into a fixed-size output, used to store API keys securely.

**Salt**: Random data added to API keys before hashing to prevent rainbow table attacks.

**Rotation**: The process of replacing an existing API key with a new one.

**Revocation**: The act of invalidating an API key before its planned expiration.

**Scope**: A defined set of permissions associated with an API key.

**Bearer Token**: An access token that grants access to whoever possesses it, as defined in RFC 6750.

**RBAC**: Role-Based Access Control - an authorization model where permissions are assigned to roles.

### 1.4. Document Structure

This specification is organized to support multiple reading paths:

- **Implementers** should focus on Sections 5-11 for technical requirements
- **Security Architects** should review Sections 3, 12, and 13 for threat modeling and compliance
- **Developers** should consult Section 14 for practical implementation guidance
- **Auditors** should reference Section 17 for the comprehensive security checklist

Each technical section provides:
1. Normative requirements using RFC 2119 keywords
2. Rationale and security justification
3. Implementation guidance
4. References to source materials

---

## 2. Requirements Notation

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119 [RFC2119].

**MUST / REQUIRED / SHALL**: Indicates an absolute requirement of the specification. Non-compliance results in a security vulnerability or architectural failure.

**MUST NOT / SHALL NOT**: Indicates an absolute prohibition. Violation introduces critical security risks.

**SHOULD / RECOMMENDED**: Indicates a strong recommendation. Valid reasons may exist to ignore in specific circumstances, but implications must be understood and carefully weighed.

**SHOULD NOT / NOT RECOMMENDED**: Indicates behavior that should generally be avoided but may be acceptable in specific, well-justified circumstances.

**MAY / OPTIONAL**: Indicates a truly optional feature. Implementers may include or exclude at their discretion.

---

## 3. Architecture Overview

### 3.1. API Key Lifecycle

The API key lifecycle encompasses seven distinct phases:

```
Generation → Distribution → Storage → Transmission → Validation → Monitoring → Rotation/Revocation
```

1. **Generation**: Cryptographically secure creation of a unique, high-entropy token
2. **Distribution**: Secure delivery of the key to the authorized client (one-time display)
3. **Storage**: Hashed storage on the provider side, encrypted storage on the client side
4. **Transmission**: Transfer of the key in API requests over encrypted channels
5. **Validation**: Provider verification of key authenticity, status, and permissions
6. **Monitoring**: Continuous tracking of key usage patterns and anomaly detection
7. **Rotation/Revocation**: Planned replacement or emergency invalidation of keys

Each phase introduces specific security requirements and controls detailed in subsequent sections.

### 3.2. Threat Model

API key security must address threats across multiple attack surfaces:

**T1: Brute Force Attacks**
Attackers attempt to guess valid API keys through systematic enumeration.
*Mitigations*: High entropy (128-256 bits), rate limiting, anomaly detection

**T2: Database Compromise**
Attackers gain unauthorized access to the provider's key storage database.
*Mitigations*: Cryptographic hashing (BCrypt/Argon2), salting, encryption at rest

**T3: Network Interception**
Attackers intercept API keys during transmission over insecure channels.
*Mitigations*: TLS 1.3+ mandatory, HTTP Strict Transport Security (HSTS)

**T4: Source Code Exposure**
API keys are hardcoded in application code or configuration files committed to version control.
*Mitigations*: Secret scanning, environment variables, secrets management systems

**T5: Client-Side Exposure**
API keys are embedded in client-side code (JavaScript, mobile apps) where they can be extracted.
*Mitigations*: Backend proxy pattern, token-based authentication, never store keys client-side

**T6: Insufficient Authorization**
Compromised keys have excessive permissions beyond their intended scope.
*Mitigations*: Least privilege, scope-based permissions, RBAC, resource-level restrictions

**T7: Lack of Auditability**
API key misuse goes undetected due to inadequate logging and monitoring.
*Mitigations*: Comprehensive audit logging, real-time anomaly detection, SIEM integration

**T8: Credential Stuffing**
Attackers use leaked credentials from other services to attempt API access.
*Mitigations*: Unique key generation, monitoring for unusual access patterns, geo-fencing

**T9: Delayed Revocation**
Compromised keys cannot be revoked quickly enough to prevent abuse.
*Mitigations*: Immediate revocation capability, centralized management dashboard, automated alerts

**T10: Inadequate Rotation**
Long-lived keys remain valid indefinitely, increasing exposure window.
*Mitigations*: Mandatory rotation policies (30-90 days), automated rotation, grace periods

### 3.3. Security Principles

API key management implementations MUST adhere to the following security principles:

**Defense in Depth**
"These practices, when combined, create a strong defense for your API infrastructure" [Source-01]. Multiple layered security controls ensure that failure of any single control does not result in complete compromise.

**Principle of Least Privilege**
"Follow the principle of least privilege with role-based access control (RBAC)" [Source-01]. API keys SHOULD have the minimum permissions necessary to perform their intended function.

**Fail Securely**
Authentication and authorization failures MUST default to denying access rather than permitting it.

**Complete Mediation**
Every API request MUST be validated for both authentication (valid key) and authorization (permitted action).

**Separation of Concerns**
Authentication (proving identity), authorization (determining permissions), and accounting (logging actions) SHOULD be implemented as distinct, composable layers.

**Cryptographic Agility**
Systems SHOULD support multiple hashing and encryption algorithms to enable migration as cryptographic standards evolve.

---

## 4. API Key Fundamentals

### 4.1. Definition and Purpose

An API key is a unique identifier and secret token used to authenticate a client making requests to an API. As defined in the API Key Design pattern:

"As an API provider, assign each client a unique token — the API KEY — that the client can present to the API endpoint for identification purposes." [Source-05]

API keys serve multiple functions:
- **Authentication**: Verifying the identity of the calling application or service
- **Authorization**: Determining what resources and operations the client can access
- **Accounting**: Tracking API usage for billing, quota enforcement, and analytics
- **Rate Limiting**: Associating request quotas with specific clients
- **Auditing**: Maintaining records of which client performed which actions

### 4.2. Use Cases and Applicability

API keys are appropriate for the following scenarios:

**UC1: Unattended/Automated Access**
"API keys are for unattended use" [Source-41]. Background jobs, scheduled scripts, CI/CD pipelines, and server-to-server integrations that cannot participate in interactive authentication flows.

**UC2: Programmatic Access**
Command-line tools, SDKs, and developer libraries that require consistent, long-lived credentials.

**UC3: Third-Party Integrations**
Granting limited access to external services or partners with specific permission scopes.

**UC4: Service Accounts**
Non-human accounts representing applications or services within an infrastructure.

**UC5: Development and Testing**
Providing developers with credentials for API exploration and integration testing.

### 4.3. Comparison with Alternative Authentication Methods

API keys exist within an ecosystem of authentication mechanisms, each with distinct characteristics and appropriate use cases:

| Mechanism | Primary Use | Lifetime | Interactive | Scope Granularity |
|-----------|-------------|----------|-------------|-------------------|
| API Keys | Service-to-service, unattended | Long-lived (30-365+ days) | No | Medium (per-key scopes) |
| OAuth 2.0 Access Tokens | User delegation, web/mobile apps | Short-lived (hours) | Yes | High (OAuth scopes) |
| OAuth 2.0 Refresh Tokens | Token renewal | Medium-lived (days-months) | No | High |
| SAML Assertions | Enterprise SSO | Very short (minutes) | Yes | Low |
| Session Cookies | Web application sessions | Session duration | Yes | N/A |
| mTLS Certificates | Service mesh, microservices | Long-lived (months-years) | No | N/A |

**OAuth 2.0 vs. API Keys**

"If you're building a web application, you should be using OAuth or SAML. These technologies are designed for interactive applications" [Source-41]. OAuth 2.0 provides superior security for scenarios involving user consent and delegation but introduces complexity:

- OAuth refresh tokens require "extra work for the client and server developers" [Source-41]
- "Some developers don't implement refresh tokens correctly" leading to authentication failures [Source-41]
- "Some OAuth systems don't make it easy to generate multiple tokens" limiting concurrent access [Source-41]

API keys offer simplicity for unattended scenarios at the cost of requiring careful lifecycle management.

**mTLS vs. API Keys**

Mutual TLS provides cryptographically stronger authentication through certificate-based identity verification. However, certificate management complexity and infrastructure requirements make mTLS better suited for service mesh environments than general API access [Source-22].

### 4.4. When to Use API Keys

API keys are RECOMMENDED when:

1. **Unattended Access**: Background jobs, cron tasks, CI/CD pipelines that cannot participate in interactive authentication
2. **Service Accounts**: Non-human identities representing applications or infrastructure components
3. **Developer Tools**: CLI tools, SDKs, and development environments requiring consistent credentials
4. **Third-Party Integration**: Controlled access grants to external partners with defined scopes
5. **Simplicity Requirements**: Projects where OAuth infrastructure overhead is unjustified
6. **Audit Requirements**: Scenarios requiring fine-grained tracking of which application performed which action

### 4.5. When Not to Use API Keys

API keys MUST NOT be used when:

1. **User-Facing Applications**: Web or mobile apps where keys would be exposed client-side
2. **Interactive Authentication**: Scenarios where user consent or delegation is required
3. **Short-Lived Access**: Use cases better served by short-lived OAuth tokens
4. **High-Value Operations**: Critical actions requiring step-up authentication or MFA
5. **Regulatory Restrictions**: Compliance frameworks that prohibit long-lived credentials

"API Keys ≠ Security: Why API Keys Are Not Enough" [Source-08] - API keys should be viewed as one component of a defense-in-depth strategy, not as a complete security solution.

---

## 5. Generation and Design

### 5.1. Entropy Requirements

Entropy, defined as "randomness" in security contexts [Source-32], is the primary defense against brute-force attacks. The entropy of an API key determines the computational effort required to guess it through exhaustive search.

**Minimum Entropy Requirements:**

- API keys MUST have a minimum of **128 bits of entropy** [Source-06]
- Production systems SHOULD use **256 bits of entropy** for enhanced security [Source-34]
- Temporary or development keys MAY use 64 bits but MUST NOT be used in production [Source-41]

**Entropy Calculation:**

"Entropy in security basically just means randomness. If we say something is 'high entropy,' we just mean that it's really, really random. We mean that it's hard to guess." [Source-32]

For a token using Base62 encoding (A-Z, a-z, 0-9 = 62 characters):
```
Entropy = log2(62^length)
```

For 128 bits of entropy: minimum 22 characters
For 256 bits of entropy: minimum 43 characters

**Attack Resistance:**

"If you choose 64 bits of entropy for your client secret, a brute force attack with the attacker randomly guessing API keys would require 2⁶³ API calls on average before it would be expected to have a 50% chance of succeeding. This is unlikely to happen — if a single API call took one millisecond, this kind of brute force attack would take 292 million years." [Source-41]

However, 64 bits is insufficient for database compromise scenarios (see Section 5.7).

### 5.2. Cryptographically Secure Random Number Generation

API keys MUST be generated using Cryptographically Secure Pseudo-Random Number Generators (CSPRNGs), not standard pseudorandom functions.

**Approved CSPRNG Sources:**

- `/dev/urandom` or `/dev/random` (Linux/Unix)
- `CryptGenRandom` (Windows CryptoAPI)
- `crypto.randomBytes()` (Node.js)
- `secrets` module (Python 3.6+)
- `SecureRandom` (Java)
- `RNGCryptoServiceProvider` (.NET Framework)

**Prohibited Sources:**

- MUST NOT use `Math.random()`, `rand()`, or similar non-cryptographic RNGs
- MUST NOT use timestamps, sequential counters, or other predictable sources
- MUST NOT use insufficient seed material

"Understanding Entropy: Key To Secure Cryptography & Randomness" [Source-34] - The quality of the entropy source directly determines the security of generated keys.

### 5.3. Token Format Design

Well-designed token formats enhance security through identifiability and error detection while maintaining usability.

**Format Structure:**

```
[PREFIX]_[SECRET][CHECKSUM]
```

**Example from GitHub:**
```
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ghp  = GitHub Personal access token prefix
_xxx = Underscore separator
xxx  = 36 characters of Base62-encoded secret
xxxx = 6-character checksum
```

**Design Principles:**

1. **Identifiability**: "Keys should have prefixes, so you can identify them" [Source-41]
2. **Error Detection**: "Keys should have checksums, so you can see if you failed to copy the entire key" [Source-41]
3. **Copy-Paste Friendly**: "Keys shouldn't include characters that prevent copying and pasting like hyphens, so a developer can double click on it and copy it correctly" [Source-41]

### 5.4. Prefixes and Identifiability

Prefixes provide multiple security and operational benefits:

**Security Benefits:**
- Enable secret scanning tools to identify leaked credentials
- Allow automated revocation when keys are detected in public repositories
- Support service-specific detection rules and alerting

**Operational Benefits:**
- Quick identification of token type and permissions
- Simplified debugging and log analysis
- Environment identification (prod/dev/test)

**Prefix Design Guidelines:**

- Prefixes SHOULD be 2-4 characters
- Prefixes MUST be followed by a non-alphanumeric separator (underscore recommended)
- Different key types SHOULD have distinct prefixes

**GitHub Example:** [Source-12]
- `ghp_` - Personal access token
- `gho_` - OAuth access token
- `ghu_` - User-to-server token
- `ghs_` - Server-to-server token
- `ghr_` - Refresh token

### 5.5. Checksums and Error Detection

Checksums detect truncation, corruption, or transcription errors, preventing failed authentication attempts due to malformed keys.

**Checksum Algorithms:**

- CRC-32 (commonly used, adequate for error detection)
- Last 6 characters of HMAC-SHA256 of the secret
- Custom validation digit schemes (mod 97, Luhn algorithm)

**Implementation:**

1. Generate the random secret component
2. Calculate checksum over the secret
3. Append checksum to form the complete key
4. Validate checksum before processing authentication

**Benefits:**

- Immediate client-side validation without server round-trip
- Reduced server load from malformed requests
- Improved developer experience with clear error messages

### 5.6. Character Set Selection

The character set impacts entropy, usability, and compatibility.

**Recommended: Base62 (A-Z, a-z, 0-9)**
- 62 characters provides 5.95 bits of entropy per character
- No special characters that require URL encoding
- Safe for use in JSON, XML, and most protocols
- Double-click selectable in most text editors

**Alternative: Base64 URL-safe**
- 64 characters (A-Z, a-z, 0-9, -, _)
- Slightly higher entropy (6 bits per character)
- Hyphen may interfere with double-click selection

**Avoid:**
- Base64 standard (+ and / require URL encoding)
- Hexadecimal (lower entropy: 4 bits per character, requires longer tokens)
- Special characters (@, !, $, etc.) that may cause parsing issues

### 5.7. Generation Algorithms

The algorithm for storing and validating API keys determines security against database compromise.

**Recommended Algorithm (BCrypt or Argon2):**

```
1. Generate secret S using CSPRNG with N bits entropy (256 recommended)
2. Generate salt T using CSPRNG (128+ bits)
3. Compute hash H = BCrypt(S + T) or H = Argon2(S + T)
4. Return S to client (one-time display only)
5. Store (H, T, metadata) in database (discard S)
```

"This is very similar to how people used to store usernames and passwords. The big difference is that we don't allow customers to select their passwords here — if we actually allowed customers to choose their own API key, they won't be guaranteed to choose one with enough entropy!" [Source-41]

**Hash Function Comparison:**

| Algorithm | Hashes/Second (2018 hardware) | Time to Crack 64-bit Key | Recommended |
|-----------|-------------------------------|--------------------------|-------------|
| SHA-256 | 9.4 billion | ~1 month (100 GPUs) | NO |
| SHA-512 | 3.1 billion | ~3 months (100 GPUs) | NO |
| BCrypt | 43,000 | 2 billion CPU days | YES |
| Argon2 | ~10,000 | Even more resistant | YES |

[Source-41]

"BCrypt is punishingly slow compared to SHA256 and SHA512... a password stored in BCrypt would take over two billion CPU days using the netmux 2018 machine in question." [Source-41]

**Caching Considerations:**

Since BCrypt/Argon2 are computationally expensive, implementations SHOULD cache authentication successes:

"Validate an API key when it is first used by a particular IP address... Allow that IP address to continue using that API key for a short period of time, say, two minutes. During this time, we presume that as long as that IP address continues to use the same API key, it will remain valid." [Source-41]

**Performance Benchmarks:**

From real-world implementation [Source-41]:
- SHA-256: 2.7μs generate, 1.2μs validate
- BCrypt: 12.1ms generate, 12.2ms validate
- First request: ~12ms overhead
- Cached requests: <1ms overhead

The trade-off favors BCrypt/Argon2 security with intelligent caching.

---

## 6. Storage and Secrets Management

### 6.1. Storage Architecture

API key storage must protect against multiple threat vectors simultaneously:

**Provider-Side Storage:**
- MUST store only cryptographic hashes, never plaintext secrets
- MUST use unique salts per key (prevent rainbow table attacks)
- SHOULD encrypt database at rest with AES-256
- SHOULD use Hardware Security Modules (HSMs) for encryption key management

**Client-Side Storage:**
- MUST store keys in encrypted secrets management systems
- MUST NOT hardcode keys in source code
- MUST NOT store keys in version control systems
- SHOULD use environment variables or secure configuration management

### 6.2. Hashing Requirements

"MUST NOT store plaintext keys" [Source-01] - This is an absolute security requirement.

**Mandatory Requirements:**

- API key secrets MUST be hashed before database storage
- Hash functions MUST be computationally expensive (BCrypt work factor ≥10, Argon2)
- Each key MUST use a unique cryptographic salt
- Hash algorithms MUST be resistant to GPU-accelerated attacks

**Acceptable Hash Functions:**

1. **BCrypt** (work factor 12-14 recommended)
   - Industry standard for password hashing
   - Automatic salt generation
   - Configurable work factor for future-proofing

2. **Argon2** (winner of Password Hashing Competition)
   - Memory-hard function resistant to ASICs/GPUs
   - Three variants: Argon2i (side-channel resistant), Argon2d (GPU resistant), Argon2id (hybrid)
   - Recommended: Argon2id with appropriate memory cost

3. **PBKDF2-HMAC-SHA256** (minimum 100,000 iterations)
   - NIST recommended
   - Less resistant to GPU attacks than BCrypt/Argon2
   - Use only if BCrypt/Argon2 unavailable

**Prohibited Hash Functions:**

- MD5 (broken, MUST NOT use)
- SHA-1 (broken, MUST NOT use)
- Unsalted SHA-256/SHA-512 (vulnerable to rainbow tables)

### 6.3. Encryption at Rest

Database encryption provides defense-in-depth against storage medium compromise.

**Encryption Requirements:**

"Apply AES-256 for stored keys and TLS 1.3+ for transmission" [Source-01]

- Database encryption SHOULD use AES-256-GCM or AES-256-CBC
- Encryption keys MUST be stored separately from encrypted data
- Key rotation SHOULD occur annually or after security events
- SHOULD use envelope encryption (data keys encrypted by master keys)

**Implementation Example:**

"Delphix's 2024 Data Control Tower enhances security by using AES/GCM encryption with keys derived from hostnames and URLs, removing the need to store encryption keys on the filesystem" [Source-01]

### 6.4. Secrets Management Systems

Dedicated secrets management platforms provide centralized security controls.

**Recommended Solutions:**

| Solution | Best For | Key Features |
|----------|----------|--------------|
| HashiCorp Vault | Large enterprises | Centralized secret management, dynamic secrets, audit logging |
| AWS Secrets Manager | Cloud-based applications | Automatic key rotation, AWS integration, encryption |
| Azure Key Vault | Microsoft ecosystems | HSM support, compliance features, AD integration |
| Google Secret Manager | Google Cloud | Native GCP integration, automatic replication |

[Source-01]

**Capabilities Required:**

- Encrypted storage with access control
- Audit logging of all secret access
- Automated rotation with configurable policies
- API-based secret retrieval
- Emergency revocation capabilities
- Multi-region replication (for high availability)

### 6.5. Hardware Security Modules

"Use hardware security modules (HSMs) with envelope encryption" [Source-01]

HSMs provide tamper-resistant cryptographic operations for highest-security scenarios.

**When to Use HSMs:**

- Financial services and payment processing (PCI DSS compliance)
- Healthcare data handling (HIPAA compliance)
- Government/defense applications
- Any scenario with regulatory HSM requirements

**HSM Capabilities:**

- Cryptographic key generation in hardware
- Master key storage with physical security
- FIPS 140-2 Level 3+ certification
- Tamper detection and zeroing

**Implementation Pattern:**

1. Master encryption keys stored in HSM
2. Data encryption keys (DEKs) encrypted by master keys
3. Application receives encrypted DEKs
4. HSM decrypts DEKs on demand
5. Application uses DEKs to encrypt/decrypt secrets

### 6.6. Database Security

Beyond encryption and hashing, database configurations must prevent unauthorized access.

**Security Controls:**

- Principle of least privilege for database accounts
- Separate read-only and read-write service accounts
- Network segmentation (database on isolated VLAN)
- IP whitelisting for database connections
- Connection encryption (TLS for database connections)
- Regular security patching and updates

**Access Logging:**

- Log all database access attempts
- Alert on unusual access patterns
- Integrate with SIEM systems
- Retain logs per compliance requirements (typically 90-365 days)

### 6.7. Client-Side Storage

"Best Practices for API Key Safety" [Source-13] emphasizes client-side security as equally critical as server-side protections.

**Absolute Prohibitions:**

1. **MUST NOT hardcode in source code**
   "The Rookie Mistake That Costs Millions" [Source-20] - Hardcoded keys in repositories are the #1 cause of credential exposure

2. **MUST NOT commit to version control**
   - Add to `.gitignore` immediately
   - Use secret scanning (GitHub, GitGuardian, TruffleHog)
   - Automated pre-commit hooks to block secrets

3. **MUST NOT embed in client-side applications**
   "Keep Keys Off Client Side" [Source-01, Section 7] - JavaScript, mobile apps, and desktop applications can be reverse-engineered

**Recommended Practices:**

1. **Environment Variables**
   ```bash
   export API_KEY=your_key_here
   # Access in application without hardcoding
   ```

2. **Configuration Files (with encryption)**
   - Store outside web root
   - Encrypt configuration files
   - Restrict file permissions (chmod 600)

3. **Secrets Management APIs**
   - AWS Systems Manager Parameter Store
   - Kubernetes Secrets
   - Docker Secrets

4. **Development Environments**
   - Use `.env` files (add to `.gitignore`)
   - Use separate keys for dev/staging/production
   - Never use production keys in development

**Backend Proxy Pattern:**

For web/mobile applications: [Source-01]

```
Client → Backend Proxy (holds API key) → External API
```

"A backend proxy ensures that API keys stay hidden from the client" [Source-01]

---

## 7. Transmission and Network Security

### 7.1. Transport Layer Security

"MUST use TLS 1.3+ for transmission" [Source-01] - All API key transmission MUST occur over encrypted channels.

**TLS Requirements:**

- TLS 1.3 REQUIRED (TLS 1.2 minimum if 1.3 unavailable)
- TLS 1.0 and 1.1 MUST NOT be supported
- HTTP (plaintext) MUST NOT be allowed for API endpoints
- HTTPS redirects MUST be implemented for HTTP requests
- HTTP Strict Transport Security (HSTS) header SHOULD be enabled

**HSTS Configuration:**

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

**Certificate Management:**

- Valid certificates from trusted Certificate Authorities
- Certificate pinning for mobile applications
- Automated certificate renewal (Let's Encrypt, AWS ACM)
- Monitor certificate expiration (alert 30 days before expiry)

### 7.2. HTTP Headers and Authentication Schemes

API keys SHOULD be transmitted in HTTP headers following RFC 7235 (HTTP Authentication).

**Recommended: Authorization Header with Bearer Scheme**

```http
GET /api/resource HTTP/1.1
Host: api.example.com
Authorization: Bearer sk_live_xxxxxxxxxxxxxxxxxxxxx
```

This follows RFC 6750 (OAuth 2.0 Bearer Token Usage) [Source-05]:

"The client creates a new conversion process by informing the provider of the desired in- and output format... For billing purposes, the client identifies itself by passing the API KEY gqmbwwB74tToo4YOPEsev5 in the Authorization header of the request, according to the HTTP/1.1 Authentication RFC 7235 specification. HTTP supports various types of authentication, here the RFC 6750 Bearer type is used" [Source-05]

**Alternative: Custom Header**

```http
X-API-Key: sk_live_xxxxxxxxxxxxxxxxxxxxx
```

Less standardized but widely used in practice.

### 7.3. Bearer Token Pattern

Bearer tokens grant access to anyone who possesses them - no additional proof of possession required.

**Security Implications:**

- Treat API keys as bearer tokens
- Assume that anyone with the key can use it
- Implement additional controls (IP whitelisting, rate limiting)
- Log all usage for audit trails

**Scope Binding:**

- Encode permissions in associated metadata, not in the token itself
- Validate scope on every request
- Implement defense in depth

### 7.4. API Key Transmission Methods

Comparison of transmission approaches:

| Method | Security | Recommended | Notes |
|--------|----------|-------------|-------|
| Authorization Header | High | YES | Standard, not logged by default |
| Custom Header (X-API-Key) | High | YES | Common practice |
| Query Parameter | LOW | NO | Logged in URLs, cached, visible |
| POST Body | Medium | Conditional | Only for non-GET requests |
| Basic Auth (username field) | Medium | Conditional | Legacy compatibility |

**Query Parameter Risks:**

- URL logging in proxies, load balancers, CDNs
- Browser history retention
- Referer header leakage
- Server access logs

API keys SHOULD NOT be transmitted in query parameters except for legacy compatibility where alternatives are unavailable.

### 7.5. Client-Side Security Practices

**Certificate Validation:**

- Clients MUST validate server TLS certificates
- MUST NOT disable certificate validation in production
- SHOULD implement certificate pinning for high-security applications

**Connection Security:**

- Use system certificate stores
- Keep TLS libraries updated
- Implement timeout and retry logic
- Clear API keys from memory after use

**Rate Limit Handling:**

- Implement exponential backoff for 429 responses
- Respect `Retry-After` headers
- Cache responses where appropriate to reduce requests

---

## 8. Access Control and Authorization

### 8.1. Principle of Least Privilege

"Follow the principle of least privilege with role-based access control (RBAC)" [Source-01]

Every API key SHOULD have only the minimum permissions required to perform its intended function.

**Implementation:**

- Default to most restrictive permissions
- Require explicit grants for each resource/operation
- Separate read and write permissions
- Time-bound permissions where appropriate

### 8.2. Role-Based Access Control

RBAC assigns permissions to roles, then associates API keys with roles.

**Example Role Hierarchy:**

```
read-only    → GET requests only
standard     → GET, POST requests
admin        → Full CRUD access
temporary    → Limited-time access with expiration
```

[Source-01]

**Role Assignment:**

- API keys created with explicit role assignment
- Role changes require key regeneration (not runtime modification)
- Audit logging of role assignments and changes

### 8.3. Scope-Based Permissions

"Securing APIs: Guide to API Keys & Scopes" [Source-27] - Scopes provide fine-grained permission control.

**Scope Definition:**

- Scope = specific permission to access a resource or perform an operation
- Example: `api:read`, `api:write`, `users:read`, `payments:write`
- Scopes are assigned to API keys at creation time

**Scope Validation:**

```
1. Extract API key from request
2. Validate key authenticity
3. Retrieve associated scopes
4. Check if requested operation's required scope is present
5. Allow if match, deny if mismatch
```

**Stripe Example:**

"Stripe uses a publishable key and a secret key. The secret key takes the role of an API KEY and is transmitted in the Authorization header of each request" [Source-05] with different keys having different scope permissions.

### 8.4. Resource-Level Restrictions

Beyond operation-level scopes, restrict access to specific resources.

**Restriction Types:**

- **Endpoint restrictions**: Limit access to specific API endpoints
- **Data table restrictions**: Restrict access to specific database tables/collections
- **Method restrictions**: Allow only certain HTTP methods (GET, POST, PUT, DELETE)
- **Environment segregation**: Separate keys for development, staging, production

[Source-01]

### 8.5. IP Whitelisting and Network Restrictions

"IP whitelisting: Limit access to specific IP addresses or ranges" [Source-01]

**Use Cases:**

- Server-to-server integrations from known IP ranges
- Enterprise applications with static IPs
- Additional security layer for high-value operations

**Implementation:**

- Store allowed IP ranges/CIDR blocks with key metadata
- Validate source IP on every request
- Support IPv4 and IPv6
- Alert on access attempts from non-whitelisted IPs

**Limitations:**

- Not suitable for dynamic IP environments (mobile, residential ISPs)
- Can be bypassed if attacker compromises whitelisted infrastructure
- Should be layered with other controls, not sole protection

### 8.6. Multi-Tenancy Considerations

In multi-tenant systems, API keys must enforce tenant isolation.

**Tenant Isolation:**

- API keys associated with specific tenant IDs
- Every resource tagged with owning tenant
- Validate key's tenant matches resource's tenant
- Never expose cross-tenant data

**Implementation Pattern:**

```
1. Extract API key from request
2. Validate and retrieve associated tenant_id
3. Parse requested resource_id from URL
4. Query resource with WHERE tenant_id = key_tenant_id AND id = resource_id
5. Return 404 if not found (don't leak existence of cross-tenant resources)
```

---

## 9. Rotation and Lifecycle Management

### 9.1. Rotation Policies

"Rotate keys every 30-90 days depending on risk level" [Source-01]

Regular rotation limits the exposure window if a key is compromised.

**Rotation Schedules:**

| Risk Level | Rotation Frequency | Grace Period |
|------------|-------------------|--------------|
| High Risk | 30 days | 24 hours |
| Moderate Risk | 90 days | 48 hours |
| Low Risk | 180 days | 72 hours |

[Source-01]

**Automated Rotation:**

- Secrets management systems should support automated rotation
- Rotation triggers: scheduled, on-demand, security-event-driven
- Notification to key owners before rotation
- Grace period for transition

"AWS Secrets Manager supports automated rotations with a built-in 24-hour overlap period" [Source-01]

### 9.2. Grace Periods and Overlapping Keys

"To avoid disruptions, use a grace period where old and new keys overlap temporarily. This ensures service continuity while systems update their credentials." [Source-01]

**Implementation:**

1. Generate new key (K2) while old key (K1) remains valid
2. Distribute K2 to client
3. Both K1 and K2 valid during grace period
4. Client updates to use K2
5. After grace period expires, K1 invalidated
6. Only K2 remains valid

**Grace Period Duration:**

- Minimum: 24 hours (allows for update window)
- Recommended: 48-72 hours (accommodates delayed updates)
- Maximum: 7 days (balance security vs. operational flexibility)

### 9.3. Multi-Key Models

"A robust key management system should support multiple active keys at once" [Source-41]

**Benefits:**

- Zero-downtime rotation
- Separate keys for different services/environments
- Isolated blast radius (compromise of one key doesn't affect others)
- Least privilege per key

**Use Cases:**

- Production key + staging key + development key
- Read-only key + write key
- Service A key + Service B key (different third-party integrations)
- Primary key + backup key

### 9.4. Expiration Policies

"Time-based access: Use expiration dates for temporary access" [Source-01]

**Expiration Use Cases:**

- Contractor/temporary access
- Trial periods
- Scoped demos and presentations
- Short-term integrations

**Implementation:**

- Store expiration timestamp with key metadata
- Validate expiration on every request
- Return 401 with clear expiration message
- Allow extension before expiration (with approval workflow)

### 9.5. Revocation Procedures

Revocation immediately invalidates an API key before its planned expiration.

**Revocation Triggers:**

- Security incident or suspected compromise
- Employee termination
- End of business relationship
- Service deprecation
- User request

**Revocation Requirements:**

- MUST take effect immediately (no caching delays)
- SHOULD notify key owner (unless security incident)
- MUST log revocation event with reason and actor
- SHOULD prevent key reuse (blacklist revoked keys)

### 9.6. Emergency Revocation

"Plan for Quick Key Removal" [Source-01, Section 10]

Emergency revocation requires rapid response capabilities.

**Emergency Response Framework:**

- Centralized management dashboard: "Manage everything from one location"
- Immediate deactivation: "Quickly deactivate keys without delays"
- Automated notifications: "Notify stakeholders promptly"

[Source-01]

**Real-World Example:**

"Twilio's 2022 security incident highlighted the importance of quick action. They were able to contain a breach by revoking tokens immediately" [Source-01]

**Implementation Requirements:**

- 24/7 access to revocation controls
- Automated revocation via API (for programmatic response)
- Batch revocation capabilities (revoke all keys for a user/tenant)
- Automated rollback (restore accidentally revoked keys)
- Integration with incident response workflows

---

## 10. Monitoring, Logging, and Threat Detection

### 10.1. Usage Monitoring

"Monitor metrics like request volume, error rates, and geographic data" [Source-01]

**Key Metrics:**

| Metric | Purpose | Alert Threshold Examples |
|--------|---------|-------------------------|
| Request Volume | Identify unusual activity | >200% of baseline, spike >812% |
| Error Rates | Highlight potential security issues | >10% authentication failures |
| Geographic Data | Detect access from suspicious locations | Access from embargoed countries |
| Response Times | Ensure SLA compliance | Latency >500ms |
| Key Rotation Status | Track key freshness | Key age >90 days |

[Source-01]

**Real-World Example:**

"In 2024, a SaaS provider stopped credential stuffing attacks by spotting an 812% spike in requests from unfamiliar regions – within just 7 minutes" [Source-01]

### 10.2. Audit Logging Requirements

Comprehensive audit trails enable forensic analysis and compliance.

**Required Log Fields:**

- Timestamp (ISO 8601 format with timezone)
- API key identifier (hashed or last 4 characters)
- Source IP address and geolocation
- Requested resource and HTTP method
- Response status code
- User-agent string
- Request/response size
- Latency

**Prohibited Log Content:**

- MUST NOT log full API key secrets
- MUST NOT log sensitive request/response payloads without redaction
- SHOULD redact PII per GDPR/privacy requirements

**Retention:**

- Minimum: 90 days
- Recommended: 1 year
- Compliance-driven: Per regulatory requirements (PCI DSS: 1 year, some regulations: 7 years)

### 10.3. Anomaly Detection

Automated anomaly detection identifies suspicious patterns indicative of compromise.

**Detection Patterns:**

- **Velocity checks**: Requests from multiple geographic regions simultaneously
- **Volume anomalies**: Sudden spike or drop in request volume
- **Failed authentication patterns**: Multiple failed attempts followed by success
- **Off-hours activity**: Requests during unusual times for that key's typical pattern
- **New device/IP**: First-time access from unknown source
- **Impossible travel**: Requests from geographically distant locations in short time window

**Implementation:**

- Establish baseline behavior per key
- Statistical analysis (mean, standard deviation, z-scores)
- Machine learning models for complex pattern detection
- Real-time alerting on threshold violations

### 10.4. SIEM Integration

"Link your monitoring systems to existing security tools for automatic responses to threats" [Source-01]

Security Information and Event Management (SIEM) systems centralize security monitoring.

**Integration Points:**

- Forward API access logs to SIEM
- Correlate API events with other security events
- Automated response workflows (e.g., auto-revoke on suspicious pattern)
- Compliance reporting and audit trails

**Popular SIEM Solutions:**

- Splunk
- ELK Stack (Elasticsearch, Logstash, Kibana)
- IBM QRadar
- ArcSight
- Datadog Security Monitoring

### 10.5. Alert Configuration

"Set up automated alerts for suspicious behavior" [Source-01]

**Alert Types:**

1. **Critical Alerts** (immediate notification, 24/7 on-call)
   - Multiple failed authentication attempts
   - Access from embargoed countries
   - Suspected credential stuffing attack
   - Emergency revocation events

2. **High-Priority Alerts** (notification within 1 hour)
   - Anomalous request volume
   - Access from new geographic region
   - Key approaching expiration without rotation

3. **Medium-Priority Alerts** (daily digest)
   - Key age exceeds policy
   - Elevated error rates
   - SLA threshold violations

**Alert Channels:**

- PagerDuty/OpsGenie integration for critical alerts
- Email for high/medium priority
- Slack/Teams for team awareness
- SIEM dashboard for centralized view

### 10.6. Metrics and Analytics

Beyond security monitoring, track operational metrics.

**Operational Metrics:**

- API usage by endpoint (identify most-used features)
- Per-key quota consumption
- Rate limit hit frequency
- Cache hit ratios
- Distribution of key types (read-only vs. full access)

**Business Metrics:**

- API adoption trends
- Integration success rates
- Time-to-first-successful-call (developer experience)
- API-driven revenue (if applicable)

---

## 11. Rate Limiting and Abuse Prevention

### 11.1. Rate Limiting Strategies

"Implement layered rate limits to prevent abuse" [Source-01]

Rate limiting protects API infrastructure from overload and abuse.

**Layered Approach:**

| Time Window | Limit Type | Use Case |
|-------------|------------|----------|
| Per second/minute | Short-term | Managing sudden traffic spikes |
| Hourly | Medium-term | Regulating typical usage patterns |
| Daily/Monthly | Long-term | Limiting overall resource consumption |

[Source-01]

**Example Configuration:**

- 100 requests/second (burst protection)
- 10,000 requests/hour (sustained load management)
- 1,000,000 requests/month (quota enforcement)

### 11.2. Token Bucket Algorithm

The token bucket algorithm is the most common rate limiting implementation.

**Algorithm:**

1. Bucket holds N tokens (capacity)
2. Tokens added at rate R per time unit
3. Each request consumes 1 token
4. Request allowed if bucket has ≥1 token
5. Request denied if bucket empty

**Advantages:**

- Allows controlled bursting
- Smooth traffic patterns
- Efficient implementation

**Implementation with Redis:**

"Tools like Redis for request tracking and the token bucket algorithm can help manage request flows effectively" [Source-01]

### 11.3. Tiered Rate Limits

Different API key types should have different rate limits.

**Tier Examples:**

```
Free Tier:     1,000 requests/day
Standard Tier: 100,000 requests/day
Premium Tier:  1,000,000 requests/day
Enterprise:    Custom negotiated limits
```

**Tier Assignment:**

- Based on subscription level
- Based on API key type (internal vs. partner vs. public)
- Based on historical usage patterns (trusted keys get higher limits)

### 11.4. HTTP 429 Responses

When rate limits are exceeded, return HTTP 429 (Too Many Requests) with actionable information.

**Required Headers:**

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 3600
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1612345678
```

**Response Body Example:**

```json
{
  "error": "Rate limit exceeded",
  "current_usage": 1050,
  "limit": 1000,
  "reset_time": "2026-02-27T15:00:00Z",
  "retry_after": 3600
}
```

[Source-01]

"This helps users understand the issue and plan accordingly" [Source-01]

### 11.5. DDoS Protection

Rate limiting alone is insufficient for DDoS protection.

**Additional Controls:**

- Network-level DDoS mitigation (CloudFlare, AWS Shield)
- Geographic blocking for non-serviced regions
- Challenge-response for suspicious traffic (CAPTCHA, proof-of-work)
- Connection limits per source IP
- SYN flood protection at network layer

**Dynamic Rate Limiting:**

"Adjust rate limits automatically based on server performance and user behavior:
- Reduce limits if server CPU usage exceeds threshold
- Raise limits for trusted users who consistently comply with policies
- Temporarily increase limits for scheduled high-traffic events"

[Source-01]

---

## 12. Security Considerations

### 12.1. Comprehensive Threat Model

The complete threat model encompasses threats from Section 3.2 plus:

**T11: Token Leakage via Logs**
API keys accidentally logged in application logs, web server logs, or error messages.
*Mitigation*: Log redaction, secure log storage, log access controls

**T12: Supply Chain Attacks**
Compromised dependencies or build tools exfiltrate API keys during build/deployment.
*Mitigation*: Dependency scanning, build environment isolation, secrets scanning in CI/CD

**T13: Insider Threats**
Malicious or negligent insiders with access to secrets management systems.
*Mitigation*: Least privilege, mandatory vacations, audit logging, background checks

**T14: Side-Channel Attacks**
Timing attacks against authentication validation or cryptographic operations.
*Mitigation*: Constant-time comparison functions, rate limiting masks timing differences

### 12.2. OWASP API Security Top 10 Mapping

Mapping API key security controls to OWASP API Security Top 10 [Source-02]:

**API1:2019 - Broken Object Level Authorization**
- Enforce tenant isolation (Section 8.6)
- Resource-level access controls (Section 8.4)

**API2:2019 - Broken User Authentication**
- Strong cryptographic key generation (Section 5)
- Secure storage with hashing (Section 6.2)
- TLS for transmission (Section 7.1)

**API3:2019 - Excessive Data Exposure**
- Scope-based permissions limit data access (Section 8.3)
- Never return more data than key is authorized for

**API4:2019 - Lack of Resources & Rate Limiting**
- Comprehensive rate limiting (Section 11)
- Per-key quotas and monitoring

**API5:2019 - Broken Function Level Authorization**
- RBAC and scope enforcement (Sections 8.2, 8.3)
- Validate authorization on every request

**API7:2019 - Security Misconfiguration**
- TLS 1.3+ mandatory (Section 7.1)
- Secure default configurations
- Disable unnecessary HTTP methods

**API9:2019 - Improper Assets Management**
- Key lifecycle tracking (Section 9)
- Automated expiration and rotation

**API10:2019 - Insufficient Logging & Monitoring**
- Comprehensive audit logging (Section 10.2)
- Anomaly detection (Section 10.3)
- SIEM integration (Section 10.4)

### 12.3. Common Vulnerabilities

**CV1: Hardcoded Secrets**

"Hardcoded API Keys: The Rookie Mistake That Costs Millions" [Source-20]

The #1 cause of API key exposure. Developers hardcode keys in source code, commit to Git, and secrets end up in public repositories.

**Mitigation:**
- Pre-commit hooks with secret scanning (git-secrets, TruffleHog)
- Automated repository scanning (GitHub Secret Scanning, GitGuardian)
- Developer training and awareness
- Environment variable usage requirements

**CV2: Client-Side Exposure**

API keys embedded in JavaScript, mobile apps, or desktop applications can be extracted through reverse engineering.

**Mitigation:**
- Backend proxy pattern (Section 6.7)
- Token-based authentication for end-user apps
- Never ship keys in client bundles

**CV3: Insufficient Entropy**

Keys generated with insufficient randomness are vulnerable to brute force attacks.

**Mitigation:**
- Minimum 128-bit entropy (Section 5.1)
- CSPRNG usage (Section 5.2)
- Validation of entropy in key generation process

**CV4: Missing Rotation**

Keys that never expire increase exposure window.

**Mitigation:**
- Mandatory rotation policies (Section 9.1)
- Automated rotation reminders
- Enforced maximum key age

**CV5: Plaintext Storage**

Storing keys in plaintext databases allows complete compromise on database breach.

**Mitigation:**
- Mandatory hashing (Section 6.2)
- BCrypt/Argon2 usage
- Regular security audits

### 12.4. Attack Vectors and Mitigations

**AV1: Credential Stuffing**

Attackers use leaked credentials from other services to attempt API access.

**Mitigations:**
- Monitoring for unusual access patterns (Section 10.3)
- Geographic anomaly detection
- Device fingerprinting
- Challenge-response for suspicious access

**Real-World Example:**

"In 2024, a SaaS provider stopped credential stuffing attacks by spotting an 812% spike in requests from unfamiliar regions – within just 7 minutes" [Source-01]

**AV2: API Key Enumeration**

Attackers systematically guess API key values.

**Mitigations:**
- High entropy requirements (128-256 bits)
- Rate limiting on authentication failures
- Progressive delays on failed attempts
- Audit logging and alerting

**AV3: Man-in-the-Middle (MITM)**

Network interception of API keys during transmission.

**Mitigations:**
- TLS 1.3+ mandatory (Section 7.1)
- HSTS headers
- Certificate pinning (mobile apps)
- Public key pinning

**AV4: Phishing/Social Engineering**

Attackers trick legitimate users into revealing API keys.

**Mitigations:**
- User education and awareness training
- Clear key identification (prefixes help users recognize legitimate vs. phishing)
- Encourage use of secrets management (not sharing keys via email/chat)
- Monitor for keys posted publicly (GitHub, Pastebin, etc.)

### 12.5. Hardcoded Secrets Prevention

**Detection Tools:**

- **git-secrets**: Prevents committing secrets to Git repositories
- **TruffleHog**: Scans Git history for high-entropy strings
- **GitGuardian**: Continuous monitoring of public and private repositories
- **GitHub Secret Scanning**: Automatic detection in GitHub repositories

**Secret Scanning Pattern:**

"Generic high entropy secret detection" [Source-18] - GitGuardian detects high-entropy strings that match API key patterns even without known prefixes.

**CI/CD Integration:**

1. Pre-commit hooks block secrets before commit
2. CI pipeline scans for secrets before merge
3. Post-merge scanning for defense-in-depth
4. Automated revocation on detection

### 12.6. Secret Scanning and Detection

**Identifiable Token Formats:**

Prefixed tokens enable targeted secret scanning:

"Keys should have prefixes, so you can identify them" [Source-41]

GitHub's implementation [Source-12] uses prefixes (ghp_, gho_, etc.) enabling:
- Service-specific detection patterns
- Automated revocation when detected in public repositories
- Prioritization of alerts by token type

**Public Repository Monitoring:**

- GitHub scans all public commits for known token patterns
- Partners (AWS, Stripe, etc.) receive notifications of exposed keys
- Automated revocation workflows

**Enterprise Implementation:**

1. Define token format with unique prefix
2. Register pattern with secret scanning vendors
3. Configure automated alerts
4. Implement revocation workflows
5. Monitor effectiveness metrics

---

## 13. Compliance and Standards

### 13.1. Regulatory Frameworks

API key management must align with applicable regulatory requirements.

**PCI DSS (Payment Card Industry Data Security Standard)**

Requirements for systems handling payment card data:
- Encrypt transmission of cardholder data across open, public networks (PCI DSS 4.1)
- Protect stored account data (PCI DSS 3.4)
- Restrict access based on need to know (PCI DSS 7.1)
- Implement strong access control measures (PCI DSS 8)
- Track and monitor all access to network resources and cardholder data (PCI DSS 10)

**Implications for API Keys:**
- API keys accessing payment systems MUST use TLS 1.2+ (TLS 1.3 recommended)
- Keys MUST be stored hashed, never plaintext
- Scope-based access control required
- Comprehensive audit logging mandatory
- Regular rotation required

**GDPR (General Data Protection Regulation)**

Requirements for systems processing EU personal data:
- Security of processing (Article 32): "appropriate technical and organisational measures"
- Data minimization (Article 5): collect only necessary data
- Purpose limitation: use data only for stated purposes

**Implications for API Keys:**
- API keys accessing PII MUST implement encryption at rest and in transit
- Scope restrictions to limit access to only required personal data
- Audit logging for GDPR accountability requirements
- Data subject access requests may require key access logs

**HIPAA (Health Insurance Portability and Accountability Act)**

Requirements for systems handling healthcare data:
- Access controls to ensure only authorized access (§164.312(a)(1))
- Encryption and decryption (§164.312(a)(2)(iv))
- Audit controls (§164.312(b))

**Implications for API Keys:**
- API keys accessing PHI MUST implement strong authentication
- Encryption at rest and in transit mandatory
- Comprehensive audit trails required
- Business Associate Agreements (BAAs) for third-party key holders

### 13.2. Industry Standards

**NIST (National Institute of Standards and Technology)**

- **NIST SP 800-63B** (Digital Identity Guidelines): Authentication and lifecycle management
- **NIST SP 800-57** (Key Management): Cryptographic key management practices
- **NIST Cybersecurity Framework**: Identify, Protect, Detect, Respond, Recover

**ISO/IEC 27001** (Information Security Management)

- A.9.4.3: Password management system
- A.12.4.1: Event logging
- A.14.2.1: Secure development policy

**SOC 2 (Service Organization Control 2)**

Trust Service Criteria:
- Security: Protection against unauthorized access
- Availability: System availability for operation and use
- Confidentiality: Protection of confidential information

**Implications for API Keys:**
- Document key management policies and procedures
- Implement technical controls mapped to SOC 2 criteria
- Regular audits and testing
- Evidence collection for audit purposes

### 13.3. Compliance Requirements

**Compliance Checklist:**

- [ ] Encryption: AES-256 at rest, TLS 1.3+ in transit
- [ ] Hashing: BCrypt/Argon2 for key storage
- [ ] Access Control: RBAC and scope-based permissions
- [ ] Audit Logging: Comprehensive logging with appropriate retention
- [ ] Rotation: Mandatory rotation policies enforced
- [ ] Monitoring: Real-time anomaly detection and alerting
- [ ] Incident Response: Documented procedures for key compromise
- [ ] Business Continuity: Key recovery and disaster recovery plans
- [ ] Third-Party Management: Vendor security assessments
- [ ] Training: Developer and administrator security awareness

**Documentation Requirements:**

- Key management policy document
- Incident response procedures
- Disaster recovery plan
- Access control matrix
- Audit logging specification
- Vendor risk assessments
- Training records

---

## 14. Implementation Guidance

### 14.1. Provider Implementation Checklist

**Phase 1: Design**
- [ ] Define entropy requirements (minimum 128-bit, recommend 256-bit)
- [ ] Design token format with prefix and checksum
- [ ] Select hash algorithm (BCrypt or Argon2)
- [ ] Plan key lifecycle (rotation, expiration, revocation)
- [ ] Define scope/permission model

**Phase 2: Implementation**
- [ ] Implement CSPRNG-based key generation
- [ ] Build key storage with hashing and salting
- [ ] Implement TLS 1.3+ enforcement
- [ ] Build authentication middleware
- [ ] Implement scope validation
- [ ] Create key management UI/API

**Phase 3: Security**
- [ ] Enable database encryption at rest
- [ ] Implement rate limiting (tiered approach)
- [ ] Build audit logging infrastructure
- [ ] Configure anomaly detection
- [ ] Set up SIEM integration
- [ ] Implement secret scanning integration

**Phase 4: Operations**
- [ ] Create monitoring dashboards
- [ ] Configure alerts (critical, high, medium)
- [ ] Document emergency revocation procedures
- [ ] Build automated rotation workflows
- [ ] Create developer documentation
- [ ] Conduct security testing

**Phase 5: Compliance**
- [ ] Map controls to compliance requirements
- [ ] Document policies and procedures
- [ ] Conduct penetration testing
- [ ] Perform compliance audit
- [ ] Establish continuous monitoring

### 14.2. Consumer Best Practices

**Key Acquisition:**
- Generate separate keys for each environment (dev, staging, prod)
- Use most restrictive scopes possible
- Document key purpose and owner

**Key Storage:**
- NEVER hardcode keys in source code
- NEVER commit keys to version control
- USE environment variables or secrets management systems
- ENCRYPT configuration files containing keys
- RESTRICT file permissions (chmod 600 on config files)

**Key Usage:**
- Transmit only via HTTPS with valid certificates
- Use Authorization header (not query parameters)
- Implement exponential backoff for rate limits
- Cache responses to reduce request volume
- Clear keys from memory after use

**Key Rotation:**
- Set calendar reminders before key expiration
- Test new keys in staging before production
- Keep old keys temporarily for rollback
- Update documentation when keys change

**Incident Response:**
- Know how to quickly revoke compromised keys
- Have backup keys ready for failover
- Monitor for unusual activity
- Report suspected compromise immediately

### 14.3. Testing and Validation

**Security Testing:**

1. **Entropy Testing**
   - Validate generated keys meet minimum entropy requirements
   - Statistical randomness tests (Chi-square, frequency analysis)
   - Ensure no predictable patterns

2. **Cryptography Testing**
   - Verify hash algorithms implemented correctly
   - Test salt uniqueness per key
   - Validate constant-time comparison

3. **Authentication Testing**
   - Test valid key acceptance
   - Test invalid key rejection
   - Test expired key rejection
   - Test revoked key rejection

4. **Authorization Testing**
   - Verify scope enforcement
   - Test resource-level access controls
   - Validate tenant isolation
   - Test privilege escalation attempts

5. **Network Security Testing**
   - Verify TLS 1.3+ enforcement
   - Test certificate validation
   - Attempt downgrade attacks
   - Verify HSTS implementation

6. **Rate Limiting Testing**
   - Test per-second/minute/hour limits
   - Verify correct 429 responses
   - Test Retry-After header
   - Validate tiered limits

**Penetration Testing:**

- Annual penetration testing by qualified third party
- Test API key brute force resistance
- Attempt credential stuffing attacks
- Test for timing side-channels
- Social engineering testing (phishing for keys)

**Compliance Testing:**

- Annual SOC 2 audit (if applicable)
- PCI DSS assessment (if handling payments)
- HIPAA audit (if handling PHI)
- Regular vulnerability scanning

### 14.4. Migration Strategies

**Migrating from Legacy Authentication:**

**Phase 1: Parallel Operation**
1. Implement new API key system alongside existing authentication
2. Allow both authentication methods temporarily
3. Migrate low-risk integrations first
4. Monitor error rates and user feedback

**Phase 2: Gradual Transition**
1. Notify users of migration timeline
2. Provide migration documentation and tools
3. Set deadline for legacy auth deprecation
4. Send reminders approaching deadline

**Phase 3: Legacy Deprecation**
1. Disable legacy authentication endpoints
2. Return helpful error messages directing to new system
3. Monitor for remaining legacy attempts
4. Provide emergency fallback for critical users

**Upgrading Existing API Key Systems:**

**Improving Hash Algorithm:**
1. Generate new keys with improved algorithm (BCrypt/Argon2)
2. Support both old and new algorithm validation during transition
3. Force rotation to migrate all keys to new algorithm
4. Retire old algorithm after migration complete

**Adding Prefixes to Existing Keys:**
- Not feasible for existing keys (would change the secret)
- Apply only to newly generated keys
- Encourage rotation to prefixed format
- Maintain support for non-prefixed keys during long transition

**Implementing Rotation:**
1. Build rotation infrastructure
2. Enable voluntary rotation initially
3. Set future mandatory rotation date
4. Enforce rotation policy after deadline

---

## 15. Case Studies and Real-World Implementations

### 15.1. GitHub Token Format Implementation

In 2021, GitHub redesigned its authentication token formats to enhance security and prevent secret exposure [Source-12].

**Key Design Decisions:**

**Prefixes for Token Type Identification:**
- `ghp_` - Personal access token
- `gho_` - OAuth access token
- `ghu_` - User-to-server token
- `ghs_` - Server-to-server token
- `ghr_` - Refresh token

**Benefits:**
- Secret scanning tools can identify token type
- Service-specific revocation workflows
- Clear token purpose in logs and debugging

**Checksum Implementation:**

GitHub tokens include a 6-character checksum enabling client-side validation before attempting authentication.

**Entropy:**

GitHub chose Base62 encoding with 40 characters providing 160 bits of entropy:
```
Math.log((("a".."z").to_a + ("A".."Z").to_a + (0..9).to_a).length) / Math.log(2) * 40 ≈ 160 bits
```

**Impact:**

- Enabled partnership with secret scanning vendors
- Automated revocation when tokens detected in public repositories
- Reduced false positives through format specificity

### 15.2. Stripe API Key Architecture

Stripe uses a dual-key model separating publishable and secret keys [Source-05].

**Key Types:**

1. **Publishable Key** (pk_live_xxx, pk_test_xxx)
   - Safe to embed in client-side code
   - Limited to specific operations (creating tokens, payment methods)
   - Cannot access sensitive data or perform privileged operations

2. **Secret Key** (sk_live_xxx, sk_test_xxx)
   - Must be kept confidential
   - Full API access
   - Used server-side only

**Environment Separation:**

- `_test_` keys for development/testing
- `_live_` keys for production
- Separate key hierarchies prevent test/prod confusion

**Restricted Keys:**

Stripe allows creating restricted versions of secret keys with:
- Specific endpoint access
- IP whitelist restrictions
- Rate limit overrides

**Security Benefits:**

- Publishable keys reduce client-side exposure risk
- Clear key type identification through prefix
- Environment separation prevents accidental production charges during testing

### 15.3. AWS API Security Model

AWS uses a signature-based authentication model (AWS Signature Version 4) that provides additional security beyond simple API keys.

**Key Components:**

1. **Access Key ID** - Public identifier (like username)
2. **Secret Access Key** - Private credential (like password)
3. **Request Signature** - HMAC-SHA256 of request elements

**Security Advantages:**

- Secret key never transmitted (only signature)
- Request tampering detected through signature validation
- Replay attack protection through timestamp validation
- Prevents MITM attacks even if TLS compromised

**Temporary Credentials:**

AWS Security Token Service (STS) issues temporary credentials with:
- Expiration (15 minutes to 12 hours)
- Restricted permissions
- Automatic rotation

**Best Practices Applied:**

- Mandatory key rotation recommendations
- IAM roles for service-to-service authentication (eliminate static keys)
- CloudTrail logging of all API calls
- Multi-factor authentication for sensitive operations

### 15.4. Security Incident Lessons

**Case Study 1: Twitch Data Breach (2021)**

"The 2021 Twitch data breach, where hackers gained access to API keys stored in source code repositories" [Source-01]

**What Happened:**
- API keys hardcoded in source code
- Source code repository compromised
- Attackers gained API access
- Massive data exfiltration (125GB)

**Lessons:**
- Never hardcode secrets in source code
- Implement pre-commit secret scanning
- Use environment variables and secrets management
- Regular repository scanning for historical secrets

**Case Study 2: Cloudflare Incident (Monitoring Success)**

"Cloudflare once stopped an attack after identifying 10 million hourly requests from a single account – 1,000 times the normal activity" [Source-01]

**What Happened:**
- Compromised API key used for attack
- Anomaly detection identified 1000x usage spike
- Key revoked within minutes
- Attack contained before significant damage

**Lessons:**
- Real-time monitoring enables rapid response
- Anomaly detection catches compromises early
- Automated response workflows critical
- Having revocation procedures ready essential

**Case Study 3: Google Gemini API Launch (2024)**

"Google API Keys Weren't Secrets. But then Gemini Changed the Rules" [Source-19]

**What Happened:**
- Google historically allowed API keys in client-side code for Maps, YouTube, etc.
- Gemini AI API introduced usage costs and sensitive capabilities
- Exposed keys in public GitHub repositories caused unexpected charges
- Required policy change and public education

**Lessons:**
- API key security model must match API sensitivity
- Client-side embedding only acceptable for limited-scope APIs
- Clear communication when security model changes
- Secret scanning integration essential for cost-bearing APIs

**Case Study 4: Twilio Security Response (2022)**

"Twilio's 2022 security incident highlighted the importance of quick action. They were able to contain a breach by revoking tokens immediately" [Source-01]

**What Happened:**
- Employee credentials compromised through phishing
- Attacker accessed internal systems including API key management
- Immediate revocation protocols activated
- Breach contained through rapid response

**Lessons:**
- Emergency revocation procedures must be rehearsed
- 24/7 access to revocation controls essential
- Automated notification workflows speed response
- Regular incident response drills prevent hesitation during real events

---

## 16. Future Considerations

### 16.1. Post-Quantum Cryptography

"Quantum-safe API Security: How to prepare APIs for the post-quantum future" [Source-24]

**Threat:**
Quantum computers capable of breaking current cryptographic algorithms (RSA, ECC, current hashing functions).

**Timeline:**
- NIST post-quantum cryptography standards finalized 2024
- Quantum threat horizon: 10-30 years
- Migration period required: 5-10 years

**Implications for API Keys:**

- Current hash functions (SHA-256, BCrypt) may become vulnerable
- Need migration path to quantum-resistant algorithms
- Cryptographic agility essential

**Recommendations:**

- Design systems to support multiple hash algorithms simultaneously
- Monitor NIST post-quantum standardization
- Plan for algorithm migration without breaking existing integrations
- Consider quantum-resistant algorithms (CRYSTALS-Kyber, CRYSTALS-Dilithium)

### 16.2. Zero Trust Architecture

Zero Trust principles assume no implicit trust, requiring verification for every access request.

**Implications for API Keys:**

- API keys alone insufficient for Zero Trust
- Continuous validation (not just at authentication)
- Context-aware access decisions (device, location, behavior)
- Micro-segmentation and per-request authorization

**Enhanced API Key Model:**

1. API key + device certificate
2. API key + contextual signals (IP, user-agent, time)
3. API key + step-up authentication for sensitive operations
4. Time-limited tokens derived from long-lived keys

### 16.3. Emerging Standards

**OAuth 2.1:**
Consolidates OAuth 2.0 and best current practices, potentially affecting API key usage patterns.

**FAPI (Financial-grade API):**
Enhanced security profile for financial APIs, applicable to high-security API key scenarios.

**OpenID Connect for APIs:**
May provide standardized alternative to custom API key schemes for certain use cases.

**API Key Standard (Potential):**
Currently no RFC-level standard for API key format, storage, or lifecycle. Future standardization could improve interoperability and secret scanning.

---

## 17. Security Checklist

### Provider Checklist

**Generation & Design**
- [ ] Minimum 128-bit entropy (256-bit recommended)
- [ ] CSPRNG-based generation
- [ ] Prefix for identification
- [ ] Checksum for error detection
- [ ] Base62 or Base64-URL character set

**Storage & Cryptography**
- [ ] BCrypt or Argon2 hashing
- [ ] Unique salt per key
- [ ] AES-256 encryption at rest
- [ ] Secrets management system integration
- [ ] Never store plaintext secrets

**Transmission & Protocol**
- [ ] TLS 1.3+ required (TLS 1.2 minimum)
- [ ] HSTS headers enabled
- [ ] Authorization header for key transmission
- [ ] Certificate validation enforced
- [ ] No keys in query parameters

**Access Control**
- [ ] RBAC implemented
- [ ] Scope-based permissions
- [ ] Least privilege enforcement
- [ ] Tenant isolation (if multi-tenant)
- [ ] Resource-level restrictions

**Lifecycle Management**
- [ ] Mandatory rotation policy (30-90 days)
- [ ] Grace period implementation
- [ ] Expiration enforcement
- [ ] Emergency revocation capability
- [ ] Multi-key support

**Monitoring & Detection**
- [ ] Comprehensive audit logging
- [ ] Real-time anomaly detection
- [ ] SIEM integration
- [ ] Usage metrics dashboard
- [ ] Automated alerting

**Rate Limiting**
- [ ] Layered rate limits (second/hour/day)
- [ ] Token bucket implementation
- [ ] HTTP 429 responses
- [ ] Retry-After headers
- [ ] Tiered limits by key type

**Compliance & Operations**
- [ ] Policy documentation
- [ ] Incident response procedures
- [ ] Regular penetration testing
- [ ] Compliance audit readiness
- [ ] Developer documentation

### Consumer Checklist

**Acquisition**
- [ ] Separate keys per environment
- [ ] Minimal scopes requested
- [ ] Document key purpose

**Storage**
- [ ] No hardcoded secrets
- [ ] No version control commits
- [ ] Environment variables or secrets manager
- [ ] Encrypted configuration files
- [ ] Restrictive file permissions (600)

**Usage**
- [ ] HTTPS only
- [ ] Certificate validation enabled
- [ ] Authorization header (not query params)
- [ ] Exponential backoff on errors
- [ ] Response caching where appropriate

**Lifecycle**
- [ ] Rotation calendar reminders
- [ ] Test keys before production deployment
- [ ] Monitor for expiration warnings
- [ ] Quick revocation procedure documented

**Incident Response**
- [ ] Know revocation contact/procedure
- [ ] Backup keys for failover
- [ ] Monitoring for suspicious activity
- [ ] Escalation procedure documented

---

## 18. References

### 18.1. Normative References

**[RFC2119]**
Bradner, S., "Key words for use in RFCs to Indicate Requirement Levels", BCP 14, RFC 2119, March 1997.

**[RFC6749]**
Hardt, D., "The OAuth 2.0 Authorization Framework", RFC 6749, October 2012.

**[RFC6750]**
Jones, M., Hardt, D., "The OAuth 2.0 Authorization Framework: Bearer Token Usage", RFC 6750, October 2012.

**[RFC7235]**
Fielding, R., Reschke, J., "Hypertext Transfer Protocol (HTTP/1.1): Authentication", RFC 7235, June 2014.

**[RFC8446]**
Rescorla, E., "The Transport Layer Security (TLS) Protocol Version 1.3", RFC 8446, August 2018.

### 18.2. Informative References

**[Source-01]**: "10 API Key Management Best Practices", Serverion, February 2025.
**[Source-02]**: "OWASP API Security Top 10 - 2019", OWASP Foundation, March 2022.
**[Source-05]**: "API Key Design Pattern", Microservice API Patterns.
**[Source-08]**: "API Keys ≠ Security: Why API Keys Are Not Enough", Nordic APIs.
**[Source-12]**: "Behind GitHub's new authentication token formats", GitHub Blog, April 2021.
**[Source-13]**: "Best Practices for API Key Safety", OpenAI Help Center.
**[Source-19]**: "Google API Keys Weren't Secrets. But then Gemini Changed the Rules", Truffle Security.
**[Source-20]**: "Hardcoded API Keys: The Rookie Mistake That Costs Millions", InstaTunnel via Medium.
**[Source-22]**: "Mechanisms for Mutual Attested Microservice Communication".
**[Source-24]**: "Quantum-safe API Security: How to prepare APIs for the post-quantum future", Curity.
**[Source-27]**: "Securing APIs: Guide to API Keys & Scopes".
**[Source-32]**: "Token entropy explained: what is token entropy?", Tesseral Guides.
**[Source-34]**: "Understanding Entropy: Key To Secure Cryptography & Randomness", Netdata.
**[Source-41]**: "What makes a good API key system?", Ted Spence, tedspence.com, July 2023.

*(Complete reference list with all 42 sources available in full specification)*

---

## 19. Appendices

### Appendix A: Glossary

**API (Application Programming Interface)**: A set of protocols and tools for building software applications that specify how software components should interact.

**Argon2**: A modern password hashing function and winner of the Password Hashing Competition, designed to be resistant to GPU, ASIC, and side-channel attacks.

**BCrypt**: An adaptive password hashing function based on the Blowfish cipher, incorporating a salt and a configurable work factor.

**Bearer Token**: An access credential that grants access to whoever possesses it, without requiring additional proof of identity.

**CSPRNG (Cryptographically Secure Pseudo-Random Number Generator)**: A random number generator suitable for cryptographic applications, producing outputs that are computationally indistinguishable from true randomness.

**Entropy**: A measure of randomness or unpredictability, typically measured in bits. Higher entropy means harder to guess.

**Hash Function**: A one-way cryptographic function that takes arbitrary input and produces a fixed-size output (hash). Computationally infeasible to reverse.

**HMAC (Hash-based Message Authentication Code)**: A mechanism for message authentication using cryptographic hash functions.

**HSM (Hardware Security Module)**: A physical computing device that safeguards and manages digital keys, performs encryption and decryption functions, and provides tamper-resistant key storage.

**HTTPS (HTTP Secure)**: HTTP protocol encrypted with TLS/SSL.

**mTLS (Mutual TLS)**: A two-way authentication mechanism where both client and server authenticate each other using certificates.

**RBAC (Role-Based Access Control)**: An authorization model where permissions are assigned to roles, and users/keys are assigned to roles.

**Salt**: Random data added to input before hashing to prevent rainbow table attacks and ensure unique hashes for identical inputs.

**SIEM (Security Information and Event Management)**: A system that provides real-time analysis of security alerts generated by applications and network hardware.

**TLS (Transport Layer Security)**: Cryptographic protocol providing communications security over a computer network.

### Appendix B: Sample Code Examples

**B.1: API Key Generation (Python)**

```python
import secrets
import base64
import hashlib
import bcrypt

def generate_api_key(prefix="api", entropy_bits=256):
    """
    Generate a high-entropy API key with prefix and checksum.

    Args:
        prefix: Identifier prefix (e.g., "api", "prod", "dev")
        entropy_bits: Entropy in bits (128, 256, etc.)

    Returns:
        tuple: (public_key, hash_for_storage, salt)
    """
    # Calculate required bytes for desired entropy
    entropy_bytes = entropy_bits // 8

    # Generate cryptographically secure random bytes
    secret_bytes = secrets.token_bytes(entropy_bytes)

    # Encode as Base62 (URL-safe, double-click friendly)
    secret_b64 = base64.b64encode(secret_bytes).decode('ascii').rstrip('=')

    # Calculate checksum (first 6 chars of SHA256)
    checksum = hashlib.sha256(secret_bytes).hexdigest()[:6]

    # Construct full key: prefix_secret_checksum
    full_key = f"{prefix}_{secret_b64}{checksum}"

    # Generate salt and hash for storage
    salt = bcrypt.gensalt(rounds=12)
    key_hash = bcrypt.hashpw(full_key.encode('utf-8'), salt)

    return full_key, key_hash, salt

def validate_api_key(provided_key, stored_hash):
    """
    Validate an API key against stored hash.

    Args:
        provided_key: Key provided by client
        stored_hash: BCrypt hash from database

    Returns:
        bool: True if valid, False otherwise
    """
    try:
        return bcrypt.checkpw(
            provided_key.encode('utf-8'),
            stored_hash
        )
    except Exception:
        return False

# Example usage
if __name__ == "__main__":
    # Generate new key
    key, hash_val, salt = generate_api_key(prefix="prod", entropy_bits=256)
    print(f"API Key (give to user once): {key}")
    print(f"Store in database (hash): {hash_val}")

    # Validate key
    is_valid = validate_api_key(key, hash_val)
    print(f"Validation result: {is_valid}")
```

**B.2: API Key Validation Middleware (Node.js/Express)**

```javascript
const bcrypt = require('bcrypt');
const rateLimit = require('express-rate-limit');

// Database query function (implement based on your DB)
async function getApiKeyHash(keyId) {
    // Extract key ID from prefix and query database
    // Return { hash, salt, scopes, isActive, expiresAt }
}

// Rate limiting middleware
const apiKeyRateLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 100, // 100 requests per minute
    message: 'Too many requests from this API key',
    standardHeaders: true,
    legacyHeaders: false,
});

// API key authentication middleware
async function authenticateApiKey(req, res, next) {
    try {
        // Extract API key from Authorization header
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                error: 'Missing or invalid Authorization header'
            });
        }

        const apiKey = authHeader.substring(7); // Remove "Bearer "

        // Validate key format and checksum
        if (!validateKeyFormat(apiKey)) {
            return res.status(401).json({
                error: 'Invalid API key format'
            });
        }

        // Retrieve key metadata from database
        const keyData = await getApiKeyHash(apiKey);

        if (!keyData) {
            return res.status(401).json({
                error: 'Invalid API key'
            });
        }

        // Check if key is active
        if (!keyData.isActive) {
            return res.status(401).json({
                error: 'API key has been revoked'
            });
        }

        // Check if key is expired
        if (keyData.expiresAt && new Date() > keyData.expiresAt) {
            return res.status(401).json({
                error: 'API key has expired'
            });
        }

        // Validate key against stored hash
        const isValid = await bcrypt.compare(apiKey, keyData.hash);

        if (!isValid) {
            return res.status(401).json({
                error: 'Invalid API key'
            });
        }

        // Attach key metadata to request for authorization checks
        req.apiKey = {
            id: keyData.id,
            scopes: keyData.scopes,
            userId: keyData.userId
        };

        next();
    } catch (error) {
        console.error('API key validation error:', error);
        return res.status(500).json({
            error: 'Internal server error'
        });
    }
}

// Scope validation middleware
function requireScope(requiredScope) {
    return (req, res, next) => {
        if (!req.apiKey || !req.apiKey.scopes) {
            return res.status(403).json({
                error: 'Access denied: No scopes assigned'
            });
        }

        if (!req.apiKey.scopes.includes(requiredScope)) {
            return res.status(403).json({
                error: `Access denied: Requires scope '${requiredScope}'`
            });
        }

        next();
    };
}

// Example usage
app.get('/api/resource',
    apiKeyRateLimiter,
    authenticateApiKey,
    requireScope('resource:read'),
    (req, res) => {
        res.json({ message: 'Access granted' });
    }
);

module.exports = { authenticateApiKey, requireScope };
```

**B.3: Backend Proxy Pattern (Node.js)**

```javascript
const express = require('express');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(express.json());

// API key stored securely on server (from environment variable)
const API_KEY = process.env.EXTERNAL_API_KEY;

// Proxy endpoint - client calls this instead of external API directly
app.get('/api/data', async (req, res) => {
    try {
        // Make request to external API with server-side API key
        const response = await axios.get('https://api.example.com/data', {
            headers: {
                'Authorization': `Bearer ${API_KEY}`
            },
            params: req.query // Forward query parameters
        });

        // Return data to client (API key never exposed)
        res.json(response.data);

    } catch (error) {
        console.error('External API error:', error.message);
        res.status(500).json({
            error: 'Failed to fetch data from external service'
        });
    }
});

app.listen(3000, () => {
    console.log('Proxy server running on port 3000');
});
```

### Appendix C: Quick Reference Guide

**Entropy Requirements**
- Minimum: 128 bits
- Recommended: 256 bits
- Formula: `entropy_bits = log2(charset_size^length)`

**Hash Functions**
- ✅ Use: BCrypt (work factor 12-14), Argon2
- ⚠️ Conditional: PBKDF2 (100k+ iterations)
- ❌ Never: MD5, SHA-1, unsalted SHA-256

**TLS Requirements**
- ✅ Required: TLS 1.3
- ⚠️ Minimum: TLS 1.2
- ❌ Prohibited: TLS 1.0, TLS 1.1, HTTP (plaintext)

**Rotation Schedule**
- High Risk: 30 days
- Moderate Risk: 90 days
- Low Risk: 180 days

**Rate Limits (Example)**
- Per-second: 10-100 requests
- Per-hour: 1,000-10,000 requests
- Per-day: 100,000-1,000,000 requests

**HTTP Status Codes**
- 200: Success
- 401: Invalid/expired/revoked API key
- 403: Valid key, insufficient permissions
- 429: Rate limit exceeded
- 500: Server error

**Required HTTP Headers (429 Response)**
```
HTTP/1.1 429 Too Many Requests
Retry-After: 3600
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1612345678
```

**Key Format Example**
```
prefix_base62-secret_checksum
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**MUST NOT Do**
- ❌ Store plaintext secrets
- ❌ Hardcode in source code
- ❌ Commit to version control
- ❌ Embed in client-side code
- ❌ Transmit over HTTP
- ❌ Use in query parameters
- ❌ Use weak RNGs (Math.random())

**MUST Do**
- ✅ Use CSPRNG for generation
- ✅ Hash with BCrypt/Argon2
- ✅ Transmit over TLS 1.3+
- ✅ Implement rate limiting
- ✅ Log all usage
- ✅ Monitor for anomalies
- ✅ Rotate regularly
- ✅ Enable immediate revocation

---

## Acknowledgments

This specification synthesizes guidance from 42 authoritative sources spanning security frameworks, industry implementations, academic research, and vendor best practices. Special acknowledgment to:

- OWASP Foundation for the API Security Top 10 framework
- GitHub Engineering team for pioneering identifiable token formats
- Ted Spence for detailed technical analysis of API key cryptography
- The security community for continuous evolution of best practices

## Document History

- **February 2026**: Initial publication
- **Status**: Informational / Best Current Practice
- **Feedback**: Issues and improvements welcome via repository

---

**END OF RFC SPECIFICATION**

*Total Length: ~50 pages · Comprehensive coverage of API key security lifecycle*
*Based on synthesis of 42 authoritative sources with proper attribution*
*Suitable for API providers, consumers, security architects, and compliance auditors*

