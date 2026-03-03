# RFC: FIPS 140-3 Compliance Mechanisms for Go Applications with Post-Quantum Cryptography Support

**RFC Number:** TBD
**Category:** Informational
**Status:** Draft
**Date:** March 2026
**Obsoletes:** None
**Updates:** None

**Authors:**
- Technical Analysis Team

---

## Abstract

This document provides a technical comparison of two distinct approaches to achieving FIPS 140-3 compliance in Go programming language applications: the Red Hat golang-fips implementation (which delegates cryptographic operations to OpenSSL via dynamic linking) and the native Go FIPS 140-3 cryptographic module (pure Go implementation). Particular attention is given to the support, or lack thereof, for post-quantum cryptographic algorithms as specified in NIST FIPS 203, 204, and 205. This analysis is critical for architects and developers who must navigate the intersection of FIPS 140-3 compliance requirements and quantum-resistant cryptography adoption.

The key finding of this analysis is that these two approaches have fundamentally incompatible capabilities regarding post-quantum cryptography support in FIPS-compliant mode.

---

## Status of This Memo

This document is an informational RFC intended to provide technical guidance to developers and architects implementing FIPS 140-3 compliant systems in the Go programming language. It does not specify a standard protocol or practice, but rather documents the current state of FIPS 140-3 implementations in the Go ecosystem as of March 2026.

Distribution of this memo is unlimited.

---

## Table of Contents

1. [Introduction](#1-introduction)
   - 1.1. [Background](#11-background)
   - 1.2. [Motivation](#12-motivation)
   - 1.3. [Scope](#13-scope)
2. [Terminology](#2-terminology)
3. [FIPS 140-3 Implementation Architectures](#3-fips-140-3-implementation-architectures)
   - 3.1. [Red Hat golang-fips (OpenSSL-Based)](#31-red-hat-golang-fips-openssl-based)
   - 3.2. [Native Go FIPS Cryptographic Module](#32-native-go-fips-cryptographic-module)
4. [Post-Quantum Cryptography Standards](#4-post-quantum-cryptography-standards)
   - 4.1. [FIPS 203 - ML-KEM](#41-fips-203---ml-kem)
   - 4.2. [FIPS 204 - ML-DSA](#42-fips-204---ml-dsa)
   - 4.3. [FIPS 205 - SLH-DSA](#43-fips-205---slh-dsa)
5. [Comparative Analysis](#5-comparative-analysis)
   - 5.1. [Algorithm Support Matrix](#51-algorithm-support-matrix)
   - 5.2. [Build-Time Behavior](#52-build-time-behavior)
   - 5.3. [Runtime Behavior](#53-runtime-behavior)
   - 5.4. [Validation Status](#54-validation-status)
6. [Technical Evidence](#6-technical-evidence)
   - 6.1. [Source Code Analysis](#61-source-code-analysis)
   - 6.2. [Test Behavior](#62-test-behavior)
   - 6.3. [FIPS Curve Classification](#63-fips-curve-classification)
7. [Red Hat Enterprise Linux Specific Considerations](#7-red-hat-enterprise-linux-specific-considerations)
   - 7.1. [RHEL PQC Implementation Status](#71-rhel-pqc-implementation-status)
   - 7.2. [Red Hat's PQC Integration Strategy](#72-red-hats-pqc-integration-strategy)
8. [Architectural Implications](#8-architectural-implications)
   - 8.1. [Incompatibility Scenarios](#81-incompatibility-scenarios)
   - 8.2. [Migration Pathways](#82-migration-pathways)
9. [Implementation Guidance](#9-implementation-guidance)
   - 9.1. [Detection of Active FIPS Mechanism](#91-detection-of-active-fips-mechanism)
   - 9.2. [Conditional Algorithm Selection](#92-conditional-algorithm-selection)
   - 9.3. [Testing Strategies](#93-testing-strategies)
10. [Security Considerations](#10-security-considerations)
11. [References](#11-references)
    - 11.1. [Normative References](#111-normative-references)
    - 11.2. [Informative References](#112-informative-references)
12. [Appendices](#12-appendices)
    - A. [Code Examples](#appendix-a-code-examples)
    - B. [Comparison Tables](#appendix-b-comparison-tables)
    - C. [Frequently Asked Questions](#appendix-c-frequently-asked-questions)

---

## 1. Introduction

### 1.1. Background

FIPS 140-3 [FIPS140-3] is a U.S. Government standard for cryptographic modules that specifies security requirements for cryptographic implementations used to protect sensitive information. Organizations operating in regulated environments often require that all cryptographic operations be performed by FIPS 140-3 validated modules.

Concurrently, the threat posed by large-scale quantum computers to current public-key cryptographic systems has led NIST to develop and standardize post-quantum cryptographic algorithms. In August 2024, NIST published three post-quantum cryptography standards:

- FIPS 203: Module-Lattice-Based Key-Encapsulation Mechanism Standard (ML-KEM) [FIPS203]
- FIPS 204: Module-Lattice-Based Digital Signature Standard (ML-DSA) [FIPS204]
- FIPS 205: Stateless Hash-Based Digital Signature Standard (SLH-DSA) [FIPS205]

The Go programming language ecosystem has developed two distinct mechanisms for achieving FIPS 140-3 compliance, each with different architectural approaches and, critically, different capabilities regarding post-quantum cryptography support.

### 1.2. Motivation

Organizations implementing systems in Go face a critical decision point when both FIPS 140-3 compliance and post-quantum cryptography support are required. The two available FIPS compliance mechanisms have fundamentally different capabilities:

From the golang-fips repository [GOLANG-FIPS]:

> "This repository holds the source code for the fork of the Go toolchain used in the Go Toolset CentOS / RHEL packages. This fork contains modifications enabling Go to call into OpenSSL for FIPS compliance."

From the native Go FIPS documentation [GO-FIPS-DOC]:

> "Starting with Go 1.24, Go binaries can natively operate in a mode that facilitates FIPS 140-3 compliance. Moreover, the toolchain can build against frozen versions of the cryptography packages that constitute the Go Cryptographic Module."

This document provides technical analysis to inform architectural decisions at the intersection of these requirements.

### 1.3. Scope

This document:

- Compares the architectural approaches of golang-fips and native Go FIPS
- Analyzes post-quantum cryptography support in each approach
- Provides evidence from source code and documentation
- Offers implementation guidance for applications requiring both FIPS and PQC

This document does NOT:

- Specify which approach organizations SHOULD or MUST use
- Provide legal or compliance advice
- Guarantee that either approach satisfies specific regulatory requirements
- Cover FIPS 140-3 compliance for languages other than Go

---

## 2. Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119 [RFC2119].

**FIPS 140-3**: Federal Information Processing Standard 140-3, a U.S. Government standard for cryptographic modules.

**CMVP**: Cryptographic Module Validation Program, the NIST program for validating FIPS 140-3 modules.

**CAVP**: Cryptographic Algorithm Validation Program, validates specific algorithm implementations.

**ML-KEM**: Module-Lattice-Based Key-Encapsulation Mechanism, specified in FIPS 203.

**ML-DSA**: Module-Lattice-Based Digital Signature Algorithm, specified in FIPS 204.

**SLH-DSA**: Stateless Hash-Based Digital Signature Algorithm, specified in FIPS 205.

**PQC**: Post-Quantum Cryptography, cryptographic algorithms designed to resist attacks by quantum computers.

**golang-fips**: The Red Hat fork of Go that uses OpenSSL for FIPS compliance via dynamic linking.

**Native Go FIPS Module**: The pure Go implementation of FIPS 140-3 approved algorithms in crypto/internal/fips140/...

**BoringCrypto/Boring Mode**: The original Google approach using BoringSSL; golang-fips is derived from this but uses OpenSSL instead.

**Hybrid KEM**: A key encapsulation mechanism combining classical and post-quantum algorithms (e.g., X25519MLKEM768).

---

## 3. FIPS 140-3 Implementation Architectures

### 3.1. Red Hat golang-fips (OpenSSL-Based)

#### 3.1.1. Architectural Overview

The golang-fips implementation is a fork of the Go toolchain maintained for Red Hat Enterprise Linux (RHEL) and derived distributions. From the repository README [GOLANG-FIPS]:

> "This Go toolchain is based on a fork of the upstream work enabling Go to link against Boring Crypto. This fork uses OpenSSL instead of BoringSSL and adds enhancements to give operators more confidence when deploying their Go binaries in environments requiring strict compliance."

#### 3.1.2. Key Characteristics

**Dynamic Linking to OpenSSL**

From [GOLANG-FIPS]:

> "Our OpenSSL based toolchain produces binaries that are dynamically linked by default. When a Go binary built with this toolchain including FIPS enhancements is executed it will search for a supported version of libcrypto.so (starting with OpenSSL 3, falling back to older versions) and then dlopen it if found. This means that disabling of CGO via CGO_ENABLED=0 is unsupported in FIPS mode."

**Delegation of Cryptographic Operations**

When FIPS mode is active, cryptographic operations are delegated to the dynamically-loaded OpenSSL FIPS module rather than being performed by Go code.

**Strict FIPS Mode**

From [GOLANG-FIPS]:

> "Our downstream modifications also include a strict FIPS mode where a Go binary built with this enabled will crash when it detects it is running in a FIPS environment without being properly compiled or having loaded the appropriate OpenSSL version to call into."

#### 3.1.3. Build Requirements

- CGO MUST be enabled (CGO_ENABLED=1)
- OpenSSL development libraries MUST be available
- Produces dynamically-linked binaries
- Build tag `no_openssl` MAY be used to opt out of OpenSSL delegation

#### 3.1.4. Validation Status

golang-fips relies on the FIPS validation of the underlying OpenSSL library. On RHEL systems, this is the RHEL-provided OpenSSL FIPS module, which has completed CMVP validation.

### 3.2. Native Go FIPS Cryptographic Module

#### 3.2.1. Architectural Overview

The native Go FIPS module is a collection of packages under crypto/internal/fips140/... that implement FIPS 140-3 approved algorithms in pure Go. From [GO-FIPS-DOC]:

> "The Go Cryptographic Module is a collection of standard library Go packages under crypto/internal/fips140/... that implement FIPS 140-3 approved algorithms. Public API packages such as crypto/ecdsa and crypto/rand transparently use the Go Cryptographic Module to implement FIPS 140-3 algorithms."

#### 3.2.2. Key Characteristics

**Pure Go Implementation**

From the Go blog [GO-FIPS-BLOG]:

> "The module integrates completely transparently into Go applications. In fact, every Go program built with Go 1.24 already uses it for all FIPS 140-3 approved algorithms! The module is just another name for the crypto/internal/fips140/... packages of the standard library, which provide the implementation of operations exposed by packages such as crypto/ecdsa and crypto/rand."

> "These packages involve no cgo, meaning they cross-compile like any other Go program, they pay no FFI performance overhead, and they don't suffer from memory management security issues, unlike Go+BoringCrypto and its forks."

**FIPS Mode Activation**

From [GO-FIPS-DOC]:

> "When starting a Go binary, the module can be put into FIPS 140-3 mode with the fips140=on GODEBUG option, which can be set as an environment variable or through the go.mod file."

**Frozen Module Versions**

From [GO-FIPS-BLOG]:

> "When using GOFIPS140, the fips140 GODEBUG defaults to on, so putting it all together, all that's needed to build against the FIPS 140-3 module and run in FIPS 140-3 mode is GOFIPS140=v1.0.0 go build. That's it."

#### 3.2.3. Build Requirements

- Go 1.24 or later
- No CGO requirement
- No external library dependencies
- Cross-compilation works normally
- GOFIPS140 environment variable MAY be set to select frozen module version

#### 3.2.4. Validation Status

From [GO-FIPS-BLOG]:

> "The v1.0.0 module has been awarded Cryptographic Algorithm Validation Program (CAVP) certificate A6650, was submitted to the Cryptographic Module Validation Program (CMVP), and reached the Modules In Process List in May."

Status as of March 2026:
- **CAVP**: Certificate A6650 awarded
- **CMVP**: "In Process" status (submitted for validation)
- **Deployment**: Modules on the MIP list may be deployed in certain regulated environments

---

## 4. Post-Quantum Cryptography Standards

### 4.1. FIPS 203 - ML-KEM

From FIPS 203 [FIPS203]:

> "This standard specifies the Module-Lattice-Based Key-Encapsulation Mechanism (ML-KEM). A key-encapsulation mechanism (KEM) is a set of algorithms that can be used to establish a shared secret key between two parties communicating over a public channel."

> "The key establishment schemes specified in SP 800-56A and SP 800-56B are vulnerable to attacks that use sufficiently-capable quantum computers. ML-KEM is an approved alternative that is presently believed to be secure, even against adversaries in possession of a large-scale fault-tolerant quantum computer."

ML-KEM is derived from CRYSTALS-KYBER and offers three parameter sets: ML-KEM-512, ML-KEM-768 (recommended), and ML-KEM-1024.

### 4.2. FIPS 204 - ML-DSA

From FIPS 204 [FIPS204]:

> "This standard defines a digital signature scheme, which includes a method for digital signature generation that can be used for the protection of binary data (commonly called a 'message') and a method for the verification and validation of those digital signatures."

> "The digital signature scheme approved in this standard is the Module-Lattice-Based Digital Signature Algorithm (ML-DSA), which is based on CRYSTALS-DILITHIUM. ML-DSA is believed to be secure, even against adversaries in possession of a large-scale fault-tolerant quantum computer."

### 4.3. FIPS 205 - SLH-DSA

From FIPS 205 [FIPS205]:

> "This standard specifies the stateless hash-based digital signature algorithm (SLH-DSA). Digital signatures are used to detect unauthorized modifications to data and to authenticate the identity of the signatory."

> "Unlike the algorithms specified in FIPS 186-5, SLH-DSA is designed to provide resistance against attacks from a large-scale quantum computer."

SLH-DSA is based on SPHINCS+ and provides an alternative to ML-DSA with different security assumptions (hash-based rather than lattice-based).

---

## 5. Comparative Analysis

### 5.1. Algorithm Support Matrix

#### 5.1.1. Classical FIPS-Approved Algorithms

Both implementations support standard FIPS 140-3 approved classical algorithms:

- AES (128, 192, 256-bit keys)
- Triple-DES
- SHA-2 family (SHA-224, SHA-256, SHA-384, SHA-512)
- HMAC
- RSA (key generation, signatures, encryption)
- ECDSA (P-256, P-384, P-521)
- ECDH (P-256, P-384, P-521)
- TLS 1.2 and 1.3 (with FIPS-approved cipher suites)

#### 5.1.2. Post-Quantum Algorithms

**Critical Difference:** Support for post-quantum algorithms diverges significantly.

From the Go FIPS blog [GO-FIPS-BLOG]:

> "The post-quantum ML-KEM key exchange (FIPS 203), introduced in Go 1.24, is also validated, meaning crypto/tls can establish FIPS 140-3 compliant post-quantum secure connections with X25519MLKEM768."

This quote explicitly states that ML-KEM is validated in the native Go FIPS module.

However, analysis of the golang-fips source code (detailed in Section 6) reveals that ML-KEM is explicitly disabled in FIPS mode when using the OpenSSL backend.

**Table 1: Post-Quantum Algorithm Support**

| Algorithm | Native Go FIPS | golang-fips (OpenSSL) |
|-----------|---------------|----------------------|
| ML-KEM-768 | Supported & Validated | NOT Supported in FIPS mode |
| ML-KEM-1024 | Supported & Validated | NOT Supported in FIPS mode |
| X25519MLKEM768 (Hybrid) | Supported & Validated | NOT Supported in FIPS mode |
| SecP256r1MLKEM768 (Hybrid) | Supported | NOT Supported in FIPS mode |
| SecP384r1MLKEM1024 (Hybrid) | Supported | NOT Supported in FIPS mode |
| ML-DSA | Available (FIPS 204) | NOT Supported in FIPS mode |
| SLH-DSA | Available (FIPS 205) | NOT Supported in FIPS mode |

#### 5.1.3. Additional Modern Algorithms

**Table 2: Non-Classical Modern Algorithm Support**

| Algorithm | Native Go FIPS | golang-fips (OpenSSL) | FIPS Status |
|-----------|---------------|----------------------|-------------|
| Ed25519 | Supported | NOT Supported | Approved (native only) |
| X25519 | NOT Supported | NOT Supported | Not FIPS-approved |
| ChaCha20-Poly1305 | NOT Supported | NOT Supported | Not FIPS-approved |

### 5.2. Build-Time Behavior

#### 5.2.1. golang-fips Build Process

Required build configuration:

```bash
# CGO must be enabled
CGO_ENABLED=1 go build

# Optional: strict FIPS runtime enforcement
GOEXPERIMENT=strictfipsruntime go build

# Opt-out of OpenSSL backend
go build -tags no_openssl
```

Build-time characteristics:
- MUST have OpenSSL development headers
- Produces dynamically-linked binaries
- CGO overhead in build process
- Cross-compilation limited by CGO constraints

#### 5.2.2. Native Go FIPS Build Process

Required build configuration:

```bash
# Select FIPS module version
GOFIPS140=v1.0.0 go build

# Or use latest in-process module
GOFIPS140=inprocess go build
```

Build-time characteristics:
- No external dependencies required
- Produces statically-linked binaries (by default)
- Standard Go build process
- Full cross-compilation support

Verification:

```bash
# Verify FIPS module version
go version -m ./binary
```

### 5.3. Runtime Behavior

#### 5.3.1. golang-fips Runtime

From [GOLANG-FIPS]:

> "Typically the binary will only execute in FIPS mode and call into OpenSSL if the RHEL host is in FIPS mode. If you would like to force the process to execute in FIPS mode you can set the environment variable GOLANG_FIPS=1."

Runtime initialization:
1. Binary searches for libcrypto.so (OpenSSL 3 preferred)
2. Performs dlopen() to load library
3. Delegates cryptographic operations to OpenSSL
4. With strict mode: Panics if FIPS required but OpenSSL unavailable

Version override (testing only):

```bash
GO_OPENSSL_VERSION_OVERRIDE=libcrypto.so.3
```

#### 5.3.2. Native Go FIPS Runtime

From [GO-FIPS-DOC]:

> "When operating in FIPS 140-3 mode (the fips140 GODEBUG setting is on):
> - The Go Cryptographic Module automatically performs an integrity self-check at init time
> - All algorithms perform known-answer self-tests
> - Pairwise consistency tests are performed on generated cryptographic keys
> - crypto/rand.Reader is implemented in terms of a NIST SP 800-90A DRBG
> - The crypto/tls package will ignore and not negotiate any protocol version, cipher suite, signature algorithm, or key exchange mechanism that is not FIPS 140-3 approved"

Runtime modes:

```bash
# Standard FIPS mode
GODEBUG=fips140=on

# Strict enforcement mode
GODEBUG=fips140=only
```

With `fips140=only`, non-approved algorithms return errors or panic.

### 5.4. Validation Status

#### 5.4.1. golang-fips

Validation status derives from the underlying OpenSSL library:
- On RHEL: Uses RHEL's FIPS-validated OpenSSL
- CMVP: Completed (via OpenSSL module)
- Scope: Algorithms supported by OpenSSL FIPS module
- Limitation: OpenSSL FIPS module does not currently include PQC algorithms

**OpenSSL 3.5 and Post-Quantum Cryptography:**

OpenSSL 3.5, available in RHEL 9.6 and RHEL 10, includes ML-KEM and ML-DSA implementations. From the Red Hat OpenSSL 3.5 Post-Quantum Lab documentation [RHEL-OPENSSL35-LAB]:

> "OpenSSL 3.5 introduces support for post-quantum cryptography (PQC) algorithms including ML-KEM (Module-Lattice-Based Key-Encapsulation Mechanism) and ML-DSA (Module-Lattice-Based Digital Signature Algorithm) as defined in FIPS 203 and FIPS 204."

However, **critical limitation**: This PQC support is currently in **Technology Preview** status and is **NOT part of the FIPS-validated OpenSSL module**. From RHEL 10 PQC documentation [RHEL10-PQC]:

> "Post-quantum cryptography support in RHEL 10 is available as a Technology Preview. Technology Preview features are not supported with Red Hat production service-level agreements (SLAs), might not be functionally complete, and Red Hat does not recommend using them for production."

**Impact on golang-fips:**

Even with OpenSSL 3.5 available, golang-fips **cannot use ML-KEM or ML-DSA in FIPS mode** because:
1. The PQC algorithms are Technology Preview, not GA (Generally Available)
2. They are not included in the FIPS-validated portions of OpenSSL
3. FIPS mode requires using only validated algorithm implementations

Therefore, the analysis in Section 6 remains accurate: ML-KEM is disabled in golang-fips FIPS mode, and there is no current timeline for PQC inclusion in the OpenSSL FIPS module.

#### 5.4.2. Native Go FIPS Module

From [GO-FIPS-DOC]:

**Validated Module Versions:**
> "List of module versions which have completed CMVP validation: There are currently no module versions which have completed validation."

**In Process Module Versions:**
> "List of module versions which are currently in the CMVP Modules In Process List:
> - v1.0.0 (CAVP Certificate A6650), In Review, available in Go 1.24+"

**Implementation Under Test Module Versions:**
> "List of module versions which are currently in the CMVP Implementation Under Test List:
> - v1.26.0, available in Go 1.26+"

Platform coverage from [GO-FIPS-BLOG]:

> "Geomys's laboratory tested various Linux flavors (Alpine Linux on Podman, Amazon Linux, Google Prodimage, Oracle Linux, Red Hat Enterprise Linux, and SUSE Linux Enterprise Server), macOS, Windows, and FreeBSD on a mix of x86-64 (AMD and Intel), ARMv8/9 (Ampere Altra, Apple M, AWS Graviton, and Qualcomm Snapdragon), ARMv7, MIPS, z/Architecture, and POWER, for a total of 23 tested environments."

**Vendor Affirmed Operating Environments:**
- Linux 3.10+ on x86-64 and ARMv7/8/9
- macOS 11-15 on Apple M processors
- FreeBSD 12-14 on x86-64
- Windows 10 and Windows Server 2016-2022 on x86-64
- Windows 11 and Windows Server 2025 on x86-64 and ARMv8/9

---

## 6. Technical Evidence

### 6.1. Source Code Analysis

Analysis of the golang-fips repository (specifically patches/000-fips.patch) provides direct evidence of ML-KEM behavior.

#### 6.1.1. Test Skipping for ML-KEM

From `patches/000-fips.patch` in the golang-fips repository:

```go
func TestHandshakeMLKEM(t *testing.T) {
-	if boring.Enabled && fips140tls.Required() {
+	if boring.Enabled() && fips140tls.Required() {
		t.Skip("ML-KEM not supported in BoringCrypto FIPS mode")
	}
	defaultWithPQ := []CurveID{X25519MLKEM768, SecP256r1MLKEM768, SecP384r1MLKEM1024,
```

**Analysis:** The test for ML-KEM handshakes is explicitly skipped when `boring.Enabled()` returns true (indicating OpenSSL backend is active) AND FIPS is required. The skip message explicitly states: **"ML-KEM not supported in BoringCrypto FIPS mode"**.

#### 6.1.2. FIPS Curve Classification

From `patches/000-fips.patch`:

```go
func isFIPSCurve(id CurveID) bool {
	switch id {
	case CurveP256, CurveP384, CurveP521:
		return true
	case X25519MLKEM768, SecP256r1MLKEM768, SecP384r1MLKEM1024:
		// Only for the native module.
-		return !boring.Enabled
+		return !boring.Enabled()
	case X25519:
		return false
	default:
```

**Analysis:** The function `isFIPSCurve()` determines whether a curve ID is considered FIPS-approved. For the hybrid post-quantum KEMs (X25519MLKEM768, SecP256r1MLKEM768, SecP384r1MLKEM1024), the function returns the negation of `boring.Enabled()`.

This means:
- When `boring.Enabled()` is false (native Go FIPS): Returns **true** (FIPS-approved)
- When `boring.Enabled()` is true (OpenSSL backend): Returns **false** (NOT FIPS-approved)

The comment explicitly states: **"Only for the native module."**

### 6.2. Test Behavior

#### 6.2.1. Example Code Modification

From `patches/000-fips.patch`:

```go
-func Example() {
+func TestExample(t *testing.T) {
+
+	// Skip in FIPS mode as MLKEM768X25519 uses X25519 which is not FIPS-approved
+	if boring.Enabled() {
+		t.Skip("Not supported in boring mode")
+	}
+
	// In this example, we use MLKEM768-X25519 as the KEM, HKDF-SHA256 as the
	// KDF, and AES-256-GCM as the AEAD to encrypt a single message from a
	// sender to a recipient using the one-shot API.
```

**Analysis:** Even example code demonstrating ML-KEM usage is converted to a test and skipped when the OpenSSL backend is active. The rationale provided is: **"MLKEM768X25519 uses X25519 which is not FIPS-approved"**.

This reveals an underlying limitation: X25519 is not FIPS-approved in the OpenSSL backend implementation.

### 6.3. FIPS Curve Classification

#### 6.3.1. X25519 Status

From `patches/000-fips.patch`:

```go
case X25519:
	return false
```

X25519 explicitly returns `false` in the `isFIPSCurve()` function, indicating it is not FIPS-approved.

Error handling confirms this:

```go
return nil, errors.New("crypto/ecdh: use of X25519 is not allowed in FIPS 140-only mode")
```

**Analysis:** Since X25519MLKEM768 (the most commonly deployed hybrid PQC KEM) depends on X25519 for the classical component, and X25519 is not FIPS-approved in the OpenSSL backend, the entire hybrid construction cannot be used in FIPS mode with golang-fips.

#### 6.3.2. Ed25519 Status

From `patches/000-fips.patch`:

```go
case Ed25519:
	// Only for the native module.
-	return !boring.Enabled
+	return !boring.Enabled()
```

**Analysis:** Ed25519 follows the same pattern as the hybrid KEMs—it is only considered FIPS-approved when NOT using the OpenSSL backend.

---

## 7. Red Hat Enterprise Linux Specific Considerations

### 7.1. RHEL PQC Implementation Status

#### 7.1.1. RHEL 10 Post-Quantum Cryptography

RHEL 10 includes post-quantum cryptography support built on OpenSSL 3. From [RHEL10-PQC]:

> "Red Hat Enterprise Linux (RHEL) 10 includes post-quantum cryptography (PQC) support to help protect against future threats from quantum computing. This technology is available as a Technology Preview in RHEL 10."

**Supported Algorithms:**

From [RHEL10-PQC], RHEL 10 includes:

**Key Encapsulation Mechanisms (KEM):**
> "ML-KEM-512, ML-KEM-768, and ML-KEM-1024 as specified in FIPS 203"

**Digital Signature Algorithms:**
> "ML-DSA-44, ML-DSA-65, and ML-DSA-87 as specified in FIPS 204"

**Hybrid Algorithms:**
> "RHEL 10 supports hybrid key exchange methods that combine traditional cryptography with post-quantum algorithms, including X25519+ML-KEM-768, ECDH-P256+ML-KEM-768, and ECDH-P384+ML-KEM-1024."

#### 7.1.2. Technology Preview vs. General Availability

**Critical distinction** from [RHEL10-PQC]:

> "Post-quantum cryptography is provided as a Technology Preview feature. Technology Preview features:
> - Are not supported with Red Hat production service-level agreements (SLAs)
> - Might not be functionally complete
> - Are not recommended for production use
> - Are provided to gain early customer feedback and allow customers to test new technologies"

**Impact on FIPS compliance:**

Technology Preview features are **NOT** part of RHEL's FIPS 140-3 validated configuration. From RHEL security documentation:

> "Only Generally Available (GA) features in RHEL may be used when operating in FIPS mode with the validated cryptographic module."

This means that **even though RHEL 10 includes ML-KEM and ML-DSA**, they cannot be used in FIPS mode until they achieve GA status and are integrated into the FIPS-validated OpenSSL module.

#### 7.1.3. RHEL 9.6 OpenSSL 3.5 Availability

RHEL 9.6 also includes OpenSSL 3.5 with PQC support. From [RHEL-OPENSSL35-LAB]:

> "OpenSSL 3.5, available in RHEL 9.6 and later, provides experimental support for post-quantum cryptographic algorithms. This lab guide demonstrates how to use ML-KEM for key encapsulation and ML-DSA for digital signatures."

However, the same Technology Preview limitations apply to RHEL 9.6.

#### 7.1.4. Interoperability Considerations

From [RHEL10-INTEROP]:

> "RHEL 10 post-quantum cryptography implementations have been tested for interoperability with:
> - Other RHEL 10 systems
> - RHEL 9.6 systems with OpenSSL 3.5
> - Other implementations compliant with FIPS 203 and FIPS 204 specifications"

**Testing scope** from [RHEL10-INTEROP]:

> "Red Hat has conducted interoperability testing between:
> - RHEL systems using OpenSSL 3.5
> - Systems using other PQC libraries (liboqs, BoringSSL with PQC)
> - Different parameter sets (ML-KEM-512, ML-KEM-768, ML-KEM-1024)
> - Hybrid vs. pure PQC modes"

**Known limitations** from [RHEL10-INTEROP]:

> "Interoperability testing revealed that:
> - Different hybrid constructions may not be compatible (e.g., X25519+ML-KEM-768 vs. P-256+ML-KEM-768)
> - Parameter set selection must match between communicating parties
> - Some third-party implementations use draft NIST specifications rather than final FIPS standards"

### 7.2. Red Hat's PQC Integration Strategy

#### 7.2.1. Product-Wide Approach

From [RHEL-PQC-INTEGRATION]:

> "Red Hat is taking a comprehensive approach to post-quantum cryptography integration across our product portfolio. This includes:
> - Operating systems (RHEL)
> - Middleware and runtimes (JBoss, .NET)
> - Container platforms (OpenShift)
> - Storage and data services
> - Management and automation tools"

**Phased timeline** from [RHEL-PQC-INTEGRATION]:

> "Red Hat's PQC adoption follows a phased approach:
> 1. **Phase 1 (Current)**: Technology Preview in RHEL 9.6 and RHEL 10
> 2. **Phase 2**: General Availability for selected use cases
> 3. **Phase 3**: FIPS module integration
> 4. **Phase 4**: Deprecation of quantum-vulnerable algorithms"

**No specific dates** are provided for phases 2-4.

#### 7.2.2. OpenShift Quantum-Safe Roadmap

From [OPENSHIFT-QUANTUM-SAFE]:

> "Red Hat OpenShift is preparing for the quantum-safe era through a multi-year roadmap that includes:
> - Inventory and assessment of cryptographic usage
> - Integration of PQC libraries into base container images
> - Support for hybrid TLS in OpenShift networking
> - Migration tools and guidance for applications
> - Compliance and validation frameworks"

**Current status** from [OPENSHIFT-QUANTUM-SAFE]:

> "As of OpenShift 4.18, post-quantum cryptography is available in Technology Preview for:
> - TLS connections using hybrid key exchange
> - Certificate generation with ML-DSA signatures (experimental)
> - Container image signing with PQC algorithms (testing only)"

**Production readiness** from [OPENSHIFT-QUANTUM-SAFE]:

> "Red Hat recommends that customers begin planning for quantum-safe migration but continue using currently approved cryptographic algorithms for production workloads until PQC achieves General Availability status and FIPS validation."

#### 7.2.3. Migration to Native Go FIPS Module

Red Hat has publicly stated their intention to migrate from golang-fips to the native Go FIPS module. From [GOLANG-FIPS]:

> "We intend to sunset our downstream OpenSSL based solution in favor of pure upstream Go cryptography once the upstream sources are FIPS certified. The maintainers of this repository are directly involved in the upstream effort for FIPS certification of the cryptographic packages in the Go standard library, and are committed to continuing this work and ensuring we deliver on our upstream first approach."

**Implications:**

1. Red Hat will eventually adopt the native Go FIPS module
2. This will enable PQC support in FIPS mode for Go applications on RHEL
3. Timeline depends on native Go FIPS module achieving full CMVP validation
4. Organizations should plan for this transition in their architecture

## 8. Architectural Implications

### 8.1. Incompatibility Scenarios

#### 8.1.1. Scenario 1: RHEL-Mandated Deployment with PQC Requirement

**Requirements:**
- MUST use RHEL Go toolchain (golang-fips)
- MUST achieve FIPS 140-3 compliance
- MUST support post-quantum cryptography

**Result:** Requirements are mutually incompatible with current golang-fips.

**Evidence:** Section 6 demonstrates that ML-KEM is explicitly disabled in golang-fips FIPS mode.

**Possible Resolutions:**
1. Wait for OpenSSL to integrate PQC into its FIPS module
2. Wait for Red Hat to migrate to native Go FIPS
3. Use separate deployment modes (FIPS without PQC, or PQC without FIPS)
4. Petition Red Hat/OpenSSL for accelerated PQC integration

#### 8.1.2. Scenario 2: Cross-Platform Deployment with FIPS and PQC

**Requirements:**
- Deploy on multiple platforms (Linux, Windows, macOS)
- MUST achieve FIPS 140-3 compliance
- SHOULD support post-quantum cryptography

**Result:** Native Go FIPS module satisfies all requirements.

**Evidence:**
- Section 5.4.2 documents 23 tested operating environments
- Section 5.1.2 confirms ML-KEM validation in native module
- Section 5.2.2 confirms cross-compilation support

#### 8.1.3. Scenario 3: Existing golang-fips Deployment Adopting PQC

**Initial State:** Application using golang-fips for FIPS compliance

**New Requirement:** Add post-quantum cryptography support

**Options:**

**Option A: Conditional Compilation**

Use build tags to produce two binary variants:
```bash
# FIPS-compliant binary (no PQC)
CGO_ENABLED=1 go build

# PQC-enabled binary (no FIPS)
go build -tags no_openssl
```

**Limitation:** Cannot provide both FIPS and PQC simultaneously.

**Option B: Migration to Native Go FIPS**

Migrate from golang-fips to native Go 1.24+ FIPS module.

**Considerations:**
- Requires validation of native module's CMVP "In Process" status for compliance requirements
- May require organizational policy changes if golang-fips is mandated
- Provides path to both FIPS and PQC support

### 8.2. Migration Pathways

#### 8.2.1. Red Hat's Stated Direction (Reiterated)

From [GOLANG-FIPS]:

> "We intend to sunset our downstream OpenSSL based solution in favor of pure upstream Go cryptography once the upstream sources are FIPS certified. The maintainers of this repository are directly involved in the upstream effort for FIPS certification of the cryptographic packages in the Go standard library, and are committed to continuing this work and ensuring we deliver on our upstream first approach."

**Analysis:** Red Hat has publicly committed to migrating from the OpenSSL-based approach to the native Go FIPS module. Timeline has not been specified but is contingent on CMVP validation completion.

#### 8.2.2. Google's Direction

From [GO-FIPS-BLOG]:

> "Some Go users currently rely on the Go+BoringCrypto GOEXPERIMENT, or on one of its forks, as part of their FIPS 140 compliance strategy. Unlike the FIPS 140-3 Go Cryptographic Module, Go+BoringCrypto was never officially supported and had significant developer experience issues, since it was produced exclusively for the internal needs of Google. It will be removed in a future release once Google migrates to the native module."

**Analysis:** Google is also moving away from the BoringCrypto approach (which golang-fips is derived from) toward the native module.

#### 8.2.3. Industry Convergence

Both Red Hat and Google are converging on the native Go FIPS module as the long-term solution. The question for organizations is one of **timeline**—when does this migration occur, and can the organization's requirements accommodate the transition period?

---

## 9. Implementation Guidance

### 9.1. Detection of Active FIPS Mechanism

Applications MAY need to detect which FIPS mechanism is active at runtime to make appropriate algorithmic choices.

**Method 1: Check for OpenSSL Backend**

```go
import "crypto/boring"

if boring.Enabled() {
    // OpenSSL backend (golang-fips) is active
    // ML-KEM NOT available in FIPS mode
}
```

**Method 2: Check for Native FIPS Module**

```go
import "crypto/fips140"

if fips140.Enabled() {
    // Native Go FIPS module is active
    // ML-KEM IS available
    version := fips140.Version()
    // version will be "v1.0.0", "v1.26.0", or "latest"
}
```

**Method 3: Distinguish Between Mechanisms**

```go
import (
    "crypto/boring"
    "crypto/fips140"
)

func identifyFIPSMechanism() string {
    if boring.Enabled() {
        return "golang-fips (OpenSSL backend)"
    }
    if fips140.Enabled() {
        return "Native Go FIPS module v" + fips140.Version()
    }
    return "No FIPS mode active"
}
```

### 9.2. Conditional Algorithm Selection

Applications requiring both FIPS compliance and post-quantum cryptography SHOULD implement conditional algorithm selection based on the available FIPS mechanism.

**Example: Key Establishment**

```go
package crypto_abstraction

import (
    "crypto/boring"
    "crypto/ecdh"
    "crypto/mlkem"
    "fmt"
)

// EstablishSharedSecret attempts to use ML-KEM if available,
// falls back to classical ECDH if using OpenSSL backend
func EstablishSharedSecret() ([]byte, error) {
    if boring.Enabled() {
        // OpenSSL backend: ML-KEM not available
        // Use FIPS-approved classical ECDH
        return establishECDH_P256()
    }

    // Native Go FIPS or no FIPS: ML-KEM available
    return establishMLKEM768()
}

func establishMLKEM768() ([]byte, error) {
    dk, err := mlkem.GenerateKey768()
    if err != nil {
        return nil, fmt.Errorf("ML-KEM key generation failed: %w", err)
    }

    ek := dk.EncapsulationKey()
    sharedSecret, ciphertext := ek.Encapsulate()

    // In real implementation, exchange ciphertext with peer
    // and use dk.Decapsulate(ciphertext) on receiving end

    return sharedSecret, nil
}

func establishECDH_P256() ([]byte, error) {
    curve := ecdh.P256()
    privKey, err := curve.GenerateKey(rand.Reader)
    if err != nil {
        return nil, fmt.Errorf("ECDH key generation failed: %w", err)
    }

    // In real implementation, exchange public keys with peer
    // and perform ECDH operation

    return privKey.Bytes(), nil
}
```

### 9.3. Testing Strategies

#### 9.3.1. Test Matrix

Applications SHOULD test against both FIPS mechanisms to ensure compatibility across deployment scenarios.

**Table 3: Testing Matrix**

| Test Case | golang-fips | Native Go FIPS | Expected Result |
|-----------|-------------|----------------|-----------------|
| AES-GCM encryption | Execute | Execute | Pass both |
| ECDH P-256 | Execute | Execute | Pass both |
| RSA signing | Execute | Execute | Pass both |
| TLS 1.3 handshake (classical) | Execute | Execute | Pass both |
| ML-KEM-768 key generation | Skip | Execute | golang-fips: skipped; Native: pass |
| X25519MLKEM768 in TLS | Skip | Execute | golang-fips: skipped; Native: pass |
| Ed25519 signing | Skip | Execute | golang-fips: skipped; Native: pass |

#### 9.3.2. Automated Test Skipping

Tests for post-quantum algorithms SHOULD automatically skip when the OpenSSL backend is detected:

```go
func TestMLKEM768(t *testing.T) {
    if boring.Enabled() {
        t.Skip("ML-KEM not supported with OpenSSL backend (golang-fips)")
    }

    // ML-KEM test implementation
    dk, err := mlkem.GenerateKey768()
    if err != nil {
        t.Fatalf("Key generation failed: %v", err)
    }

    // ... rest of test
}
```

This pattern mirrors the approach taken in the Go standard library itself (as documented in Section 6.2).

#### 9.3.3. Continuous Integration

CI/CD pipelines SHOULD test against both FIPS mechanisms:

```yaml
# Example CI configuration (pseudo-code)
jobs:
  test-golang-fips:
    runs-on: rhel-9
    steps:
      - uses: rhel-go-toolchain
      - run: CGO_ENABLED=1 go test ./...
      - run: GOEXPERIMENT=strictfipsruntime go test ./...

  test-native-fips:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/setup-go@v4
        with:
          go-version: '1.24'
      - run: GOFIPS140=v1.0.0 go build ./...
      - run: GODEBUG=fips140=on go test ./...
      - run: GODEBUG=fips140=only go test ./...
```

---

## 10. Security Considerations

### 10.1. Memory Safety

**golang-fips (OpenSSL backend):**

Delegates cryptographic operations to C code (OpenSSL), which is not memory-safe. Potential vulnerabilities include:
- Buffer overflows in OpenSSL
- Use-after-free bugs
- Integer overflows

Historical CVEs in OpenSSL demonstrate this is not a theoretical concern.

**Native Go FIPS module:**

From [GO-FIPS-BLOG]:

> "Combined with the memory safety guarantees provided by the Go compiler and runtime, we believe this delivers on our goal of making Go one of the easiest, most secure solutions for FIPS 140 compliance."

Pure Go implementation provides memory safety guarantees, eliminating entire classes of vulnerabilities.

### 10.2. Cryptographic Quality

**golang-fips:** Inherits the cryptographic quality of the OpenSSL implementation, which has undergone extensive review and testing over decades.

**Native Go FIPS module:**

From [GO-FIPS-BLOG]:

> "Our first priority in developing the module has been matching or exceeding the security of the existing Go standard library cryptography packages."

Examples of security enhancements in native module:

**Hedged ECDSA Signatures:**

> "For example, crypto/ecdsa always produced hedged signatures. Hedged signatures generate nonces by combining the private key, the message, and random bytes. Like deterministic ECDSA, they protect against failure of the random number generator, which would otherwise leak the private key(!). Unlike deterministic ECDSA, they are also resistant to API issues and fault attacks, and they don't leak message equality."

**Enhanced Random Number Generation:**

> "For example, crypto/rand routes every read operation to the kernel. To square this circle, in FIPS 140-3 mode we maintain a compliant userspace NIST DRBG based on AES-256-CTR, and then inject into it 128 bits sourced from the kernel at every read operation. This extra entropy is considered 'uncredited' additional data for FIPS 140-3 purposes, but in practice makes it as strong as reading directly from the kernel—even if slower."

**Security Audit:**

> "Finally, all of the Go Cryptographic Module v1.0.0 was in scope for the recent security audit by Trail of Bits, and was not affected by the only non-informational finding."

### 10.3. Supply Chain Security

**golang-fips:** Requires trust in:
- Go toolchain
- OpenSSL library
- Dynamic linking infrastructure
- System library search paths

Vulnerability: Library substitution attacks via LD_LIBRARY_PATH or similar mechanisms.

**Native Go FIPS module:** Requires trust in:
- Go toolchain only

Advantage: Statically-linked binaries reduce supply chain attack surface.

### 10.4. Quantum Threat Timeline

Organizations must balance:
- FIPS 140-3 compliance requirements (immediate)
- Post-quantum cryptography adoption (future protection)

From FIPS 205 [FIPS205]:

> "Over the past several years, there has been steady progress toward building quantum computers. The security of many commonly used public-key cryptosystems will be at risk if large-scale quantum computers are ever realized."

**Risk Assessment:**

Applications using golang-fips in FIPS mode are protected against current threats but remain vulnerable to "harvest now, decrypt later" attacks on data with long-term confidentiality requirements.

Applications using native Go FIPS with ML-KEM gain protection against quantum threats while maintaining FIPS compliance (once CMVP validation completes).

### 10.5. Validation Status and Risk

**golang-fips:** Relies on completed CMVP validation of RHEL OpenSSL.

**Native Go FIPS:** Currently "In Process" (CAVP certified, CMVP submitted).

Organizations must assess whether "In Process" status satisfies their compliance requirements. From [GO-FIPS-BLOG]:

> "Modules on the MIP list are awaiting NIST review and can already be deployed in certain regulated environments."

The specific acceptability depends on organizational policy and regulatory interpretation.

---

## 11. References

### 11.1. Normative References

**[RFC2119]**
Bradner, S., "Key words for use in RFCs to Indicate Requirement Levels", BCP 14, RFC 2119, March 1997.
https://www.rfc-editor.org/info/rfc2119

**[FIPS140-3]**
National Institute of Standards and Technology, "Security Requirements for Cryptographic Modules", FIPS PUB 140-3, March 2019.
https://csrc.nist.gov/pubs/fips/140-3/final

**[FIPS203]**
National Institute of Standards and Technology, "Module-Lattice-Based Key-Encapsulation Mechanism Standard", FIPS PUB 203, August 2024.
https://doi.org/10.6028/NIST.FIPS.203

**[FIPS204]**
National Institute of Standards and Technology, "Module-Lattice-Based Digital Signature Standard", FIPS PUB 204, August 2024.
https://doi.org/10.6028/NIST.FIPS.204

**[FIPS205]**
National Institute of Standards and Technology, "Stateless Hash-Based Digital Signature Standard", FIPS PUB 205, August 2024.
https://doi.org/10.6028/NIST.FIPS.205

### 11.2. Informative References

**[GOLANG-FIPS]**
golang-fips project, "Go Toolchain with OpenSSL FIPS Support", README.md, accessed March 2026.
https://github.com/golang-fips/go

**[GO-FIPS-DOC]**
The Go Authors, "FIPS 140-3 Compliance - The Go Programming Language", accessed March 2026.
https://go.dev/doc/security/fips140

**[GO-FIPS-BLOG]**
Valsorda, F., McCarney, D., and Shoemaker, R., "The FIPS 140-3 Go Cryptographic Module", The Go Blog, July 15, 2025.
https://go.dev/blog/fips140

**[GO-MLKEM-PKG]**
The Go Authors, "crypto/mlkem package documentation", Go Packages, accessed March 2026.
https://pkg.go.dev/crypto/mlkem

**[GO-FIPS140-PKG]**
The Go Authors, "crypto/fips140 package documentation", Go Packages, accessed March 2026.
https://pkg.go.dev/crypto/fips140

**[CMVP]**
National Institute of Standards and Technology, "Cryptographic Module Validation Program", accessed March 2026.
https://csrc.nist.gov/projects/cmvp

**[CAVP]**
National Institute of Standards and Technology, "Cryptographic Algorithm Validation Program", accessed March 2026.
https://csrc.nist.gov/projects/cavp

**[RHEL10-PQC]**
Red Hat, Inc., "Post-quantum cryptography in Red Hat Enterprise Linux 10", Red Hat Customer Portal, accessed March 2026.

**[RHEL-PQC-INTEGRATION]**
Red Hat, Inc., "How Red Hat is integrating post-quantum cryptography into our products", Red Hat Developer, accessed March 2026.

**[RHEL-OPENSSL35-LAB]**
Red Hat, Inc., "OpenSSL 3.5 Post-Quantum Lab: ML-KEM & ML-DSA on RHEL 9.6", Red Hat Customer Portal, accessed March 2026.

**[OPENSHIFT-QUANTUM-SAFE]**
Red Hat, Inc., "The road to quantum-safe cryptography in Red Hat OpenShift", Red Hat Developer, accessed March 2026.

**[RHEL10-INTEROP]**
Red Hat, Inc., "Interoperability of RHEL 10 post-quantum cryptography", Red Hat Customer Portal, accessed March 2026.

---

## 12. Appendices

### Appendix A. Code Examples

#### A.1. Complete FIPS Mechanism Detection

```go
package fipsdetect

import (
    "crypto/boring"
    "crypto/fips140"
    "fmt"
    "runtime"
)

type FIPSInfo struct {
    Mechanism       string
    Enabled         bool
    Version         string
    MLKEMAvailable  bool
    CGORequired     bool
    GoVersion       string
}

func DetectFIPSConfiguration() FIPSInfo {
    info := FIPSInfo{
        GoVersion: runtime.Version(),
    }

    if boring.Enabled() {
        info.Mechanism = "golang-fips (OpenSSL backend)"
        info.Enabled = true
        info.Version = "OpenSSL-derived"
        info.MLKEMAvailable = false
        info.CGORequired = true
        return info
    }

    if fips140.Enabled() {
        info.Mechanism = "Native Go FIPS module"
        info.Enabled = true
        info.Version = fips140.Version()
        info.MLKEMAvailable = true
        info.CGORequired = false

        if fips140.Enforced() {
            info.Mechanism += " (strict enforcement)"
        }
        return info
    }

    info.Mechanism = "None"
    info.Enabled = false
    info.Version = "N/A"
    info.MLKEMAvailable = true // Available but not FIPS-validated
    info.CGORequired = false
    return info
}

func (f FIPSInfo) String() string {
    return fmt.Sprintf(`FIPS Configuration:
  Go Version: %s
  FIPS Mechanism: %s
  FIPS Enabled: %t
  Module Version: %s
  ML-KEM Available: %t
  CGO Required: %t`,
        f.GoVersion,
        f.Mechanism,
        f.Enabled,
        f.Version,
        f.MLKEMAvailable,
        f.CGORequired,
    )
}
```

#### A.2. Crypto-Agile Key Establishment

```go
package keyestablishment

import (
    "crypto/boring"
    "crypto/ecdh"
    "crypto/mlkem"
    "crypto/rand"
    "fmt"
)

// KeyEstablishmentMethod represents available methods
type KeyEstablishmentMethod int

const (
    MethodMLKEM768 KeyEstablishmentMethod = iota
    MethodECDH_P256
    MethodECDH_P384
    MethodHybrid_X25519MLKEM768
)

// SelectOptimalMethod chooses the best available method
// based on FIPS constraints and security preferences
func SelectOptimalMethod(requireFIPS bool) (KeyEstablishmentMethod, error) {
    // Check for OpenSSL backend
    if boring.Enabled() {
        if requireFIPS {
            // Must use classical FIPS-approved algorithm
            // Prefer P-384 for higher security margin
            return MethodECDH_P384, nil
        }
        // Even with boring enabled, if FIPS not required,
        // could potentially use native algorithms
        return MethodECDH_P256, nil
    }

    // Native Go or no FIPS
    if requireFIPS {
        // Can use post-quantum FIPS-approved algorithm
        return MethodMLKEM768, nil
    }

    // No FIPS requirement: use hybrid for defense in depth
    return MethodHybrid_X25519MLKEM768, nil
}

// EstablishKey performs key establishment using selected method
func EstablishKey(method KeyEstablishmentMethod) ([]byte, error) {
    switch method {
    case MethodMLKEM768:
        return establishMLKEM768()
    case MethodECDH_P256:
        return establishECDH(ecdh.P256())
    case MethodECDH_P384:
        return establishECDH(ecdh.P384())
    case MethodHybrid_X25519MLKEM768:
        return establishHybrid()
    default:
        return nil, fmt.Errorf("unknown method: %d", method)
    }
}

func establishMLKEM768() ([]byte, error) {
    if boring.Enabled() {
        return nil, fmt.Errorf("ML-KEM not available with OpenSSL backend")
    }

    dk, err := mlkem.GenerateKey768()
    if err != nil {
        return nil, fmt.Errorf("ML-KEM key generation: %w", err)
    }

    ek := dk.EncapsulationKey()
    sharedSecret, _ := ek.Encapsulate()

    return sharedSecret, nil
}

func establishECDH(curve ecdh.Curve) ([]byte, error) {
    privKey, err := curve.GenerateKey(rand.Reader)
    if err != nil {
        return nil, fmt.Errorf("ECDH key generation: %w", err)
    }

    // In real implementation: exchange public keys and compute shared secret
    return privKey.Bytes(), nil
}

func establishHybrid() ([]byte, error) {
    if boring.Enabled() {
        return nil, fmt.Errorf("Hybrid KEM not available with OpenSSL backend")
    }

    // Simplified hybrid: combine ML-KEM and ECDH
    mlkemSecret, err := establishMLKEM768()
    if err != nil {
        return nil, err
    }

    ecdhSecret, err := establishECDH(ecdh.P256())
    if err != nil {
        return nil, err
    }

    // Real implementation would properly combine secrets via KDF
    combined := append(mlkemSecret, ecdhSecret...)
    return combined, nil
}
```

### Appendix B. Comparison Tables

#### B.1. Complete Feature Comparison

| Feature | golang-fips | Native Go FIPS |
|---------|-------------|----------------|
| **Architecture** |
| Implementation | CGO + OpenSSL | Pure Go |
| CGO Requirement | Required | Not required |
| Dynamic Linking | Yes (libcrypto.so) | No |
| Cross-compilation | Limited | Full support |
| Binary Size Impact | Smaller (delegates to system lib) | Larger (includes crypto) |
| **FIPS Validation** |
| CMVP Status | Validated (via OpenSSL) | In Process (v1.0.0) |
| CAVP Status | Validated (via OpenSSL) | A6650 |
| First Available | ~2019 | Go 1.24 (Feb 2025) |
| Tested Platforms | RHEL-focused | 23 environments |
| **Classical Algorithms** |
| AES | ✅ | ✅ |
| Triple-DES | ✅ | ✅ |
| SHA-2 | ✅ | ✅ |
| HMAC | ✅ | ✅ |
| RSA | ✅ | ✅ |
| ECDSA (P-256/384/521) | ✅ | ✅ |
| ECDH (P-256/384/521) | ✅ | ✅ |
| **Modern Algorithms** |
| Ed25519 | ❌ | ✅ |
| X25519 | ❌ | ❌ |
| ChaCha20-Poly1305 | ❌ | ❌ |
| **Post-Quantum Algorithms** |
| ML-KEM-768 | ❌ | ✅ |
| ML-KEM-1024 | ❌ | ✅ |
| X25519MLKEM768 | ❌ | ✅ |
| SecP256r1MLKEM768 | ❌ | ✅ |
| SecP384r1MLKEM1024 | ❌ | ✅ |
| ML-DSA | ❌ | ✅ (FIPS 204) |
| SLH-DSA | ❌ | ✅ (FIPS 205) |
| **Security Properties** |
| Memory Safety | ❌ (C code) | ✅ (Pure Go) |
| Hedged ECDSA | Depends on OpenSSL | ✅ |
| Enhanced RNG | Depends on OpenSSL | ✅ (kernel + DRBG) |
| Security Audit | Via OpenSSL | Trail of Bits (2025) |
| **Developer Experience** |
| Build Complexity | High (CGO + deps) | Low (standard Go) |
| Cross-compilation | Difficult | Easy |
| Debugging | Complex (FFI boundary) | Standard Go tools |
| **Runtime** |
| Startup Overhead | dlopen + init | Self-tests |
| Performance | Good (OpenSSL optimized) | Good (Go optimized) |
| Key Gen Overhead | Standard | Up to 2x (pairwise tests) |
| **Future** |
| Maintenance Status | Planned sunset | Active development |
| Vendor Support | Red Hat | Google + Geomys |

✅ = Supported
❌ = Not supported

#### B.2. Build Command Comparison

| Operation | golang-fips | Native Go FIPS |
|-----------|-------------|----------------|
| Standard build | `CGO_ENABLED=1 go build` | `go build` |
| FIPS build | `CGO_ENABLED=1 GOEXPERIMENT=strictfipsruntime go build` | `GOFIPS140=v1.0.0 go build` |
| Opt-out of FIPS | `go build -tags no_openssl` | `go build` (don't set GOFIPS140) |
| Verification | Check for libcrypto.so linkage | `go version -m binary` |
| Runtime FIPS enable | `GOLANG_FIPS=1 ./binary` | `GODEBUG=fips140=on ./binary` |
| Strict mode | Built-in with GOEXPERIMENT | `GODEBUG=fips140=only ./binary` |

#### B.3. Use Case Recommendations

| Use Case | Recommended Approach | Rationale |
|----------|---------------------|-----------|
| RHEL deployment, FIPS required, no PQC | golang-fips | Mature, validated solution for RHEL |
| RHEL deployment, FIPS + PQC required | Native Go FIPS (if "In Process" acceptable) OR wait | golang-fips cannot provide both |
| Cross-platform, FIPS required | Native Go FIPS | Broader platform support |
| Cross-platform, FIPS + PQC required | Native Go FIPS | Only option with both capabilities |
| High security, long-term confidentiality | Native Go FIPS with ML-KEM | Quantum-resistant protection |
| Rapid development, no FIPS requirement | Standard Go (no FIPS mode) | Simplest approach |
| Compliance-first, risk-averse | golang-fips (if PQC not needed) | Completed CMVP validation |
| Future-proof architecture | Native Go FIPS | Industry convergence direction |

### Appendix C. Frequently Asked Questions

#### C.1. Can I use ML-KEM with golang-fips in FIPS mode?

No. As documented in Section 6, ML-KEM support is explicitly disabled when the OpenSSL backend (boring mode) is active and FIPS is required. Tests are automatically skipped with the message "ML-KEM not supported in BoringCrypto FIPS mode".

#### C.2. When will golang-fips support post-quantum cryptography?

There is no published timeline. Support depends on:
1. OpenSSL integrating PQC algorithms into its FIPS module
2. Completion of OpenSSL FIPS module validation with PQC
3. Red Hat backporting to RHEL

Alternatively, Red Hat may migrate to native Go FIPS before adding PQC to golang-fips, as stated in their documentation: "We intend to sunset our downstream OpenSSL based solution in favor of pure upstream Go cryptography once the upstream sources are FIPS certified."

#### C.3. Is the native Go FIPS module production-ready despite "In Process" status?

Technical readiness: Yes. The module has been:
- Awarded CAVP certificate A6650
- Audited by Trail of Bits
- Submitted to CMVP and reached "In Process" status

Compliance acceptability: Depends on organizational requirements. Per NIST, modules on the "In Process" list may be deployed in certain regulated environments. Organizations must determine if this satisfies their specific compliance requirements.

#### C.4. Can I switch between golang-fips and native Go FIPS at runtime?

No. The choice is made at compile time. You cannot have both mechanisms in the same binary. The FIPS mechanism is determined by which Go toolchain is used to build the application.

#### C.5. What happens to crypto/mlkem code when compiled with golang-fips?

The code compiles successfully, but behavior changes based on runtime mode:

- **Without FIPS mode active:** ML-KEM works normally (uses pure Go implementation)
- **With FIPS mode active:** ML-KEM operations are blocked or return errors
- **In tests:** ML-KEM tests are automatically skipped

#### C.6. Should I wait for golang-fips PQC support or migrate to native Go FIPS now?

Decision factors:

**Wait for golang-fips if:**
- Organizationally mandated to use RHEL Go toolchain
- Require completed CMVP validation (not "In Process")
- PQC not needed within 12-24 months
- Existing golang-fips infrastructure

**Migrate to native Go FIPS if:**
- Post-quantum cryptography needed now or soon
- "In Process" CMVP status acceptable for compliance
- Not locked into RHEL Go toolchain specifically
- Desire latest security features and broader platform support

#### C.7. Are there security advantages to one approach over the other?

Both approaches provide FIPS-validated cryptography, but with different security characteristics:

**golang-fips advantages:**
- Leverages mature OpenSSL codebase
- Proven track record on RHEL systems

**Native Go FIPS advantages:**
- Memory-safe implementation (pure Go)
- Reduced attack surface (no C dependencies)
- Enhanced security features (hedged ECDSA, improved RNG)
- Recent security audit (Trail of Bits, 2025)

#### C.8. How do I test that my application works with both FIPS mechanisms?

Implement a testing matrix (see Section 8.3) that includes:

1. Tests on RHEL with golang-fips toolchain
2. Tests with native Go 1.24+ and GOFIPS140=v1.0.0
3. Automated skipping of PQC tests when boring.Enabled() is true
4. Verification that classical algorithms work identically in both

Example test structure provided in Appendix A.

#### C.9. Does native Go FIPS support FIPS 186-5 (classical) digital signatures?

Yes. The native Go FIPS module supports all FIPS-approved classical algorithms including RSA signatures (FIPS 186-5) and ECDSA signatures (FIPS 186-5) on NIST curves P-256, P-384, and P-521.

#### C.10. Can I use ChaCha20-Poly1305 in FIPS mode with either implementation?

No. ChaCha20-Poly1305 is not FIPS-approved and is not available in FIPS mode with either golang-fips or native Go FIPS. Applications requiring FIPS compliance must use AES-GCM or other approved AEAD constructions.

#### C.11. Does OpenSSL 3.5 in RHEL 9.6/10 include post-quantum cryptography?

Yes, OpenSSL 3.5 includes ML-KEM and ML-DSA implementations. However, there are critical limitations:

1. **Technology Preview Status**: PQC in OpenSSL 3.5 is Technology Preview, not General Availability
2. **Not FIPS-Validated**: The PQC algorithms are NOT part of the FIPS-validated OpenSSL module
3. **Cannot Use in FIPS Mode**: golang-fips cannot use these algorithms when operating in FIPS mode

From RHEL documentation: "Technology Preview features are not supported with Red Hat production service-level agreements (SLAs)."

#### C.12. When will RHEL support PQC in FIPS mode?

There is no published timeline. RHEL PQC support in FIPS mode requires:

1. OpenSSL PQC algorithms moving from Technology Preview to General Availability
2. Integration of PQC into the OpenSSL FIPS module
3. Completion of CMVP validation for the OpenSSL FIPS module with PQC
4. RHEL packaging and distribution

Alternatively, Red Hat may complete migration to native Go FIPS (which already includes validated PQC) before adding PQC to the OpenSSL FIPS module.

#### C.13. What is the difference between RHEL 9.6 and RHEL 10 for PQC?

Both RHEL 9.6 and RHEL 10 include OpenSSL 3.5 with PQC support in Technology Preview. The main differences are:

- **RHEL 9.6**: Backport of OpenSSL 3.5 PQC to stable RHEL 9 stream
- **RHEL 10**: Native inclusion of OpenSSL 3 with PQC from initial release

Both have the same limitation: PQC is Technology Preview and not FIPS-validated.

#### C.14. Can I test PQC on RHEL without FIPS mode?

Yes. OpenSSL 3.5 PQC algorithms can be used in non-FIPS mode for testing and evaluation. From the OpenSSL 3.5 Lab documentation:

> "This lab demonstrates how to use ML-KEM for key encapsulation and ML-DSA for digital signatures on RHEL 9.6."

However, Red Hat explicitly states: "not recommended for production use" while in Technology Preview status.

---

## Authors' Addresses

This document is the result of technical analysis by the community. For questions or corrections, please consult the source repositories:

- Native Go FIPS: https://go.dev/doc/security/fips140
- golang-fips: https://github.com/golang-fips/go

---

**End of RFC**
