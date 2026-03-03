# RFC: FIPS 140-3 and Post-Quantum Cryptography - Developer and Architect Guide

**Status:** Draft
**Date:** 2026-03-02
**Authors:** Technical Documentation Team
**Target Audience:** Software Developers, Security Architects, Platform Engineers

---

## Abstract

This document provides guidance on the intersection of FIPS 140-3 compliance and Post-Quantum Cryptography (PQC) for developers and architects building secure systems. It synthesizes information from NIST FIPS publications and implementation guidance to help teams navigate the dual requirements of cryptographic module validation and quantum-resistant algorithms.

## Table of Contents

1. [Introduction](#1-introduction)
2. [FIPS 140-3 Overview](#2-fips-140-3-overview)
3. [Post-Quantum Cryptography Standards](#3-post-quantum-cryptography-standards)
4. [The Intersection: FIPS and PQC](#4-the-intersection-fips-and-pqc)
5. [Implementation Guidance](#5-implementation-guidance)
6. [Developer Considerations](#6-developer-considerations)
7. [Architect Considerations](#7-architect-considerations)
8. [Red Hat Enterprise Linux Implementation Guidance](#8-red-hat-enterprise-linux-implementation-guidance)
9. [Migration Strategy](#9-migration-strategy)
10. [References](#10-references)

---

## 1. Introduction

### 1.1 Context

As stated in FIPS 205:

> "Over the past several years, there has been steady progress toward building quantum computers. The security of many commonly used public-key cryptosystems will be at risk if large-scale quantum computers are ever realized. This would include key-establishment schemes and digital signatures that are based on integer factorization and discrete logarithms (both over finite fields and elliptic curves)."

In response to this threat, NIST initiated the Post-Quantum Cryptography (PQC) Standardization process in 2016. From FIPS 204:

> "After three rounds of evaluation and analysis, NIST selected the first four algorithms for standardization. These algorithms are intended to protect sensitive U.S. Government information well into the foreseeable future, including after the advent of cryptographically relevant quantum computers."

Simultaneously, organizations operating in regulated environments must comply with FIPS 140-3, which as defined in the Federal Register:

> "NIST FIPS 140-3 is a U.S. Government compliance regime for cryptography applications that amongst other things requires the use of a set of approved algorithms, and the use of CMVP-validated cryptographic modules tested in the target operating environments."

### 1.2 Purpose and Scope

This document addresses the critical question: **How do development teams build systems that are both FIPS 140-3 compliant AND quantum-resistant?**

---

## 2. FIPS 140-3 Overview

### 2.1 What is FIPS 140-3?

From the Go Programming Language FIPS 140-3 documentation:

> "Starting with Go 1.24, Go binaries can natively operate in a mode that facilitates FIPS 140-3 compliance. Moreover, the toolchain can build against frozen versions of the cryptography packages that constitute the Go Cryptographic Module."

The key requirement is stated clearly:

> "FIPS-approved and/or NIST-recommended. An algorithm or technique that is either 1) specified in a FIPS or NIST recommendation, 2) adopted in a FIPS or NIST recommendation, or 3) specified in a list of NIST-approved security functions."

### 2.2 Core FIPS 140-3 Requirements

According to the FIPS documentation, implementations must:

**Randomness Generation** - As specified in the Go FIPS module documentation:

> "SLH-DSA key generation (Algorithm 21) requires the generation of three random n-byte values: PK.seed, SK.seed, and SK.prf, where n is 16, 24, or 32, depending on the parameter set. For each invocation of key generation, each of these values **shall** be a fresh (i.e., not previously used) random n-byte value generated using an **approved** random bit generator (RBG), as prescribed in SP 800-90A, SP 800-90B, and SP 800-90C. Moreover, the RBG used **shall** have a security strength of at least 8n bits."

**Destruction of Sensitive Data:**

> "Data used internally by key generation and signing algorithms in intermediate computation steps could be used by an adversary to gain information about the private key and thereby compromise security. The data used internally by verification algorithms is similarly sensitive for some applications, including the verification of signatures that are used as bearer tokens (i.e., authentication secrets) or signatures on plaintext messages that are intended to be confidential."

**Key Checks:**

> "SP 800-89 imposes requirements for the assurance of public-key validity and private-key possession. In the case of SLH-DSA, where public-key validation is required, implementations **shall** verify that the public key is 2n bytes in length. When the assurance of private key possession is obtained via regeneration, the owner of the private key **shall** check that the private key is 4n bytes in length and **shall** use SK.seed and PK.seed to recompute PK.root and compare the newly generated value with the value in the private key currently held."

**Floating-Point Arithmetic:**

> "Implementations of SLH-DSA **shall not** use floating-point arithmetic, as rounding errors in floating point operations may lead to incorrect results in some cases."

### 2.3 FIPS 140-3 Mode in Go

The Go Programming Language blog states:

> "The module integrates completely transparently into Go applications. In fact, every Go program built with Go 1.24 already uses it for all FIPS 140-3 approved algorithms! The module is just another name for the crypto/internal/fips140/... packages of the standard library, which provide the implementation of operations exposed by packages such as crypto/ecdsa and crypto/rand."

To enable FIPS 140-3 mode:

> "When starting a Go binary, the module can be put into FIPS 140-3 mode with the fips140=on GODEBUG option, which can be set as an environment variable or through the go.mod file. If FIPS 140-3 mode is enabled, the module will use the NIST DRBG for randomness, crypto/tls will automatically only negotiate FIPS 140-3 approved TLS versions and algorithms, and it will perform the mandatory self-tests on initialization and during key generation."

Building against validated module versions:

> "When using GOFIPS140, the fips140 GODEBUG defaults to on, so putting it all together, all that's needed to build against the FIPS 140-3 module and run in FIPS 140-3 mode is `GOFIPS140=v1.0.0 go build`. That's it."

### 2.4 FIPS 140-3 Validation Status

From the Go blog post dated July 15, 2025:

> "The v1.0.0 module has been awarded Cryptographic Algorithm Validation Program (CAVP) certificate A6650, was submitted to the Cryptographic Module Validation Program (CMVP), and reached the Modules In Process List in May. Modules on the MIP list are awaiting NIST review and can already be deployed in certain regulated environments."

**Validated Module Versions:**
- v1.0.0 (CAVP Certificate A6650), In Review, available in Go 1.24+
- v1.26.0, Implementation Under Test, available in Go 1.26+

---

## 3. Post-Quantum Cryptography Standards

### 3.1 The Quantum Threat

From the NIST announcement:

> "NIST Releases First 3 Finalized Post-Quantum Encryption Standards"

Published on August 13, 2024, NIST released three post-quantum cryptographic standards:

- **FIPS 203**: Module-Lattice-Based Key-Encapsulation Mechanism Standard (ML-KEM)
- **FIPS 204**: Module-Lattice-Based Digital Signature Standard (ML-DSA)
- **FIPS 205**: Stateless Hash-Based Digital Signature Standard (SLH-DSA)

### 3.2 FIPS 203 - ML-KEM (Key Encapsulation)

**Purpose and Scope** - From FIPS 203:

> "This standard specifies the Module-Lattice-Based Key-Encapsulation Mechanism (ML-KEM). A key-encapsulation mechanism (KEM) is a set of algorithms that can be used to establish a shared secret key between two parties communicating over a public channel. A KEM is a particular type of key establishment scheme."

**Security Properties:**

> "The key establishment schemes specified in SP 800-56A and SP 800-56B are vulnerable to attacks that use sufficiently-capable quantum computers. ML-KEM is an **approved** alternative that is presently believed to be secure, even against adversaries in possession of a large-scale fault-tolerant quantum computer."

**Context:**

> "ML-KEM is derived from the round-three version of the CRYSTALS-KYBER KEM, a submission to the NIST Post-Quantum Cryptography Standardization project."

**Parameter Sets:**

From FIPS 203, ML-KEM offers three parameter sets providing different security levels:

> "This standard specifies three parameter sets for ML-KEM that offer different trade-offs in security strength versus performance. All three parameter sets of ML-KEM are **approved** to protect sensitive, non-classified communication systems of the U.S. Federal Government."

- **ML-KEM-512**: Lower security, better performance
- **ML-KEM-768**: Recommended for most applications
- **ML-KEM-1024**: Higher security

**How ML-KEM Works:**

From FIPS 203:

> "In a KEM, the computation of the shared secret key begins with Alice generating a decapsulation key and an encapsulation key. Alice keeps the decapsulation key private and makes the encapsulation key available to Bob. Bob then uses Alice's encapsulation key to generate one copy of a shared secret key along with an associated ciphertext. Bob then sends the ciphertext to Alice. Finally, Alice uses the ciphertext from Bob along with Alice's private decapsulation key to compute another copy of the shared secret key."

**Security Basis:**

> "The security of the particular KEM specified in this standard is related to the computational difficulty of solving certain systems of noisy linear equations, specifically the Module Learning With Errors (MLWE) problem. At present, it is believed that this particular method of establishing a shared secret key is secure, even against adversaries who possess a quantum computer."

### 3.3 FIPS 204 - ML-DSA (Digital Signatures)

**Purpose** - From FIPS 204:

> "This standard defines a digital signature scheme, which includes a method for digital signature generation that can be used for the protection of binary data (commonly called a "message") and a method for the verification and validation of those digital signatures."

**Context:**

> "The digital signature scheme approved in this standard is the Module-Lattice-Based Digital Signature Algorithm (ML-DSA), which is based on CRYSTALS-DILITHIUM. ML-DSA is believed to be secure, even against adversaries in possession of a large-scale fault-tolerant quantum computer."

**Security Properties:**

From FIPS 204:

> "ML-DSA is designed to be strongly existentially unforgeable under chosen message attack (SUF-CMA). That is, it is expected that even if an adversary can get the honest party to sign arbitrary messages, the adversary cannot create any additional valid signatures based on the signer's public key, including on messages for which the signer has already provided a signature."

**Construction:**

> "ML-DSA is a Schnorr-like signature with several optimizations. The Schnorr signature scheme applies the Fiat-Shamir heuristic to an interactive protocol between a verifier who knows g (the generator of a group in which discrete logs are believed to be difficult) and the value y = g^x and a prover who knows g and x."

**Parameter Sets:**

ML-DSA is standardized with three possible parameter sets corresponding to different security strengths, as specified in FIPS 204.

### 3.4 FIPS 205 - SLH-DSA (Stateless Hash-Based Signatures)

**Purpose** - From FIPS 205:

> "This standard specifies the stateless hash-based digital signature algorithm (SLH-DSA). Digital signatures are used to detect unauthorized modifications to data and to authenticate the identity of the signatory. In addition, the recipient of signed data can use a digital signature as evidence in demonstrating to a third party that the signature was, in fact, generated by the claimed signatory. This is known as non-repudiation since the signatory cannot easily repudiate the signature at a later time."

**Why SLH-DSA?**

From FIPS 205:

> "SLH-DSA is based on SPHINCS+, which was selected for standardization as part of the NIST Post-Quantum Cryptography Standardization process."

**Key Characteristic:**

> "Unlike the algorithms specified in FIPS 186-5, SLH-DSA is designed to provide resistance against attacks from a large-scale quantum computer."

**Security Basis:**

> "The security of the stateless hash-based digital signature algorithm (SLH-DSA) relies on the presumed difficulty of finding preimages for hash functions as well as several related properties of the same hash functions."

**Construction:**

From FIPS 205:

> "SLH-DSA is a stateless hash-based signature scheme that is constructed using other hash-based signature schemes as components: (1) a few-time signature scheme, forest of random subsets (FORS), and (2) a multi-time signature scheme, the eXtended Merkle Signature Scheme (XMSS). XMSS is constructed using the hash-based one-time signature scheme Winternitz One-Time Signature Plus (WOTS+) as a component."

**Parameter Sets:**

FIPS 205 Table 2 specifies multiple SLH-DSA parameter sets using different hash functions (SHAKE and SHA2) with varying security levels.

---

## 4. The Intersection: FIPS and PQC

### 4.1 Current Status: Post-Quantum in FIPS 140-3

**Critical Finding:** Post-quantum algorithms ARE now FIPS 140-3 approved.

From the Go FIPS 140-3 blog:

> "The post-quantum ML-KEM key exchange (FIPS 203), introduced in Go 1.24, is also validated, meaning crypto/tls can establish FIPS 140-3 compliant post-quantum secure connections with X25519MLKEM768."

This is a significant development. As of the Go Cryptographic Module v1.0.0 (2025), **ML-KEM is validated as part of FIPS 140-3 compliance**.

### 4.2 Approved Status of PQC Algorithms

From FIPS 203:

> "This standard, or other FIPS or NIST Special Publications that specify alternative mechanisms, shall be used wherever the establishment of a shared secret key (or shared secret from which keying material can be generated) is required for federal applications, including the use of such a key with symmetric-key cryptographic algorithms, in accordance with applicable Office of Management and Budget and agency policies."

From FIPS 204:

> "This standard is applicable to all federal departments and agencies for the protection of sensitive unclassified information that is not subject to section 2315 of Title 10, United States Code, or section 3502 (2) of Title 44, United States Code. Either this standard, FIPS 204, FIPS 186-5, or NIST Special Publication 800-208 **shall** be used in designing and implementing public-key-based signature systems that federal departments and agencies operate or that are operated for them under contract."

From FIPS 205:

> "This standard is applicable to all federal departments and agencies for the protection of sensitive unclassified information that is not subject to section 2315 of Title 10, United States Code, or section 3502 (2) of Title 44, United States Code. Either this standard, FIPS 204, FIPS 186-5, or NIST Special Publication 800-208 **shall** be used in designing and implementing public-key-based signature systems that federal departments and agencies operate or that are operated for them under contract."

### 4.3 Algorithm Coverage in FIPS 140-3 Modules

From the Go blog:

> "It may be surprising, but even using a FIPS 140-3 approved algorithm implemented by a FIPS 140-3 module on a supported Operating Environment is not necessarily enough for compliance; the algorithm must have been speciﬁcally covered by testing as part of validation. Hence, to make it as easy as possible to build FIPS 140 compliant applications in Go, all FIPS 140-3 approved algorithms in the standard library are implemented by the Go Cryptographic Module and were tested as part of the validation, from digital signatures to the TLS key schedule."

**Comprehensive coverage:**

> "In some cases, we validated the same algorithms under multiple different NIST designations, to make it possible to use them in full compliance for different purposes. For example, HKDF is tested and validated under four names: SP 800-108 Feedback KDF, SP 800-56C two-step KDF, Implementation Guidance D.P OneStepNoCounter KDF, and SP 800-133 Section 6.3 KDF."

### 4.4 Hybrid Approaches

The current state allows for hybrid classical/post-quantum approaches. From the Go blog discussing X25519MLKEM768:

> "crypto/tls can establish FIPS 140-3 compliant post-quantum secure connections with X25519MLKEM768"

This indicates that **hybrid key exchange** (combining classical ECDH with post-quantum ML-KEM) is part of the FIPS-validated implementation.

---

## 5. Implementation Guidance

### 5.1 Go Language Implementation

#### 5.1.1 ML-KEM in Go

From the Go package documentation for crypto/mlkem:

> "Package mlkem implements the quantum-resistant key encapsulation method ML-KEM (formerly known as Kyber), as specified in NIST FIPS 203. Most applications should use the ML-KEM-768 parameter set, as implemented by DecapsulationKey768 and EncapsulationKey768."

**Example usage:**

```go
package main

import (
    "crypto/mlkem"
    "log"
)

func main() {
    // Alice generates a new key pair and sends the encapsulation key to Bob.
    dk, err := mlkem.GenerateKey768()
    if err != nil {
        log.Fatal(err)
    }
    encapsulationKey := dk.EncapsulationKey().Bytes()

    // Bob uses the encapsulation key to encapsulate a shared secret, and sends
    // back the ciphertext to Alice.
    ciphertext := Bob(encapsulationKey)

    // Alice decapsulates the shared secret from the ciphertext.
    sharedSecret, err := dk.Decapsulate(ciphertext)
    if err != nil {
        log.Fatal(err)
    }

    // Alice and Bob now share a secret.
    _ = sharedSecret
}

func Bob(encapsulationKey []byte) (ciphertext []byte) {
    // Bob encapsulates a shared secret using the encapsulation key.
    ek, err := mlkem.NewEncapsulationKey768(encapsulationKey)
    if err != nil {
        log.Fatal(err)
    }
    sharedSecret, ciphertext := ek.Encapsulate()

    // Alice and Bob now share a secret.
    _ = sharedSecret

    // Bob sends the ciphertext to Alice.
    return ciphertext
}
```

**Key sizes** from crypto/mlkem constants:

```go
const (
    // SharedKeySize is the size of a shared key produced by ML-KEM.
    SharedKeySize = 32
    // SeedSize is the size of a seed used to generate a decapsulation key.
    SeedSize = 64
    // CiphertextSize768 is the size of a ciphertext produced by ML-KEM-768.
    CiphertextSize768 = 1088
    // EncapsulationKeySize768 is the size of an ML-KEM-768 encapsulation key.
    EncapsulationKeySize768 = 1184
    // CiphertextSize1024 is the size of a ciphertext produced by ML-KEM-1024.
    CiphertextSize1024 = 1568
    // EncapsulationKeySize1024 is the size of an ML-KEM-1024 encapsulation key.
    EncapsulationKeySize1024 = 1568
)
```

#### 5.1.2 Building FIPS-Compliant Applications

From the Go documentation:

**Step 1: Set the GOFIPS140 environment variable**

```bash
GOFIPS140=v1.0.0 go build
```

**Step 2: Verify FIPS module version**

> "The GOFIPS140 version used to build a binary can be verified with `go version -m`."

**Step 3: Runtime verification**

```go
import "crypto/fips140"

if fips140.Enabled() {
    fmt.Println("FIPS 140-3 mode is active")
}

version := fips140.Version()
fmt.Printf("Using FIPS module version: %s\n", version)
```

#### 5.1.3 Enforcement Modes

From the crypto/fips140 package documentation:

> "Enabled reports whether the cryptography libraries are operating in FIPS 140-3 mode. It can be controlled at runtime using the GODEBUG setting 'fips140'. If set to 'on', FIPS 140-3 mode is enabled. If set to 'only', non-approved cryptography functions will additionally return errors or panic."

**Strict enforcement:**

```go
if fips140.Enforced() {
    // Strict FIPS 140-3 enforcement is enabled (GODEBUG=fips140=only)
    // Non-approved algorithms will panic or return errors
}
```

**Selective bypass (use with extreme caution):**

> "WithoutEnforcement disables strict FIPS 140-3 enforcement while executing f. Calling WithoutEnforcement without strict enforcement enabled (GODEBUG=fips140=only is not set or already inside of a call to WithoutEnforcement) is a no-op."

> "As this disables enforcement, it should be applied carefully to tightly scoped functions."

### 5.2 Platform Support

From the Go blog on FIPS 140-3:

> "A FIPS 140-3 module is only compliant if operated on a tested or 'Vendor Affirmed' Operating Environment, essentially a combination of operating system and hardware platform. To enable as many Go use cases as possible, the Geomys validation is tested on one of the most comprehensive sets of Operating Environments in the industry."

**Tested environments include:**

> "Geomys's laboratory tested various Linux flavors (Alpine Linux on Podman, Amazon Linux, Google Prodimage, Oracle Linux, Red Hat Enterprise Linux, and SUSE Linux Enterprise Server), macOS, Windows, and FreeBSD on a mix of x86-64 (AMD and Intel), ARMv8/9 (Ampere Altra, Apple M, AWS Graviton, and Qualcomm Snapdragon), ARMv7, MIPS, z/Architecture, and POWER, for a total of 23 tested environments."

**Vendor Affirmed Operating Environments:**

- Linux 3.10+ on x86-64 and ARMv7/8/9
- macOS 11-15 on Apple M processors
- FreeBSD 12-14 on x86-64
- Windows 10 and Windows Server 2016-2022 on x86-64
- Windows 11 and Windows Server 2025 on x86-64 and ARMv8/9

**Unsupported platforms:**

> "GODEBUG=fips140=on and only are not supported on OpenBSD, Wasm, AIX, and 32-bit Windows platforms."

### 5.3 Security Considerations

#### 5.3.1 Random Number Generation

From the Go FIPS blog on maintaining security:

> "For example, crypto/rand routes every read operation to the kernel. To square this circle, in FIPS 140-3 mode we maintain a compliant userspace NIST DRBG based on AES-256-CTR, and then inject into it 128 bits sourced from the kernel at every read operation. This extra entropy is considered 'uncredited' additional data for FIPS 140-3 purposes, but in practice makes it as strong as reading directly from the kernel—even if slower."

#### 5.3.2 Hedged Signatures

From the Go blog:

> "For example, crypto/ecdsa always produced hedged signatures. Hedged signatures generate nonces by combining the private key, the message, and random bytes. Like deterministic ECDSA, they protect against failure of the random number generator, which would otherwise leak the private key(!). Unlike deterministic ECDSA, they are also resistant to API issues and fault attacks, and they don't leak message equality."

> "Instead of downgrading to regular randomized or deterministic ECDSA signatures in FIPS 140-3 mode (or worse, across modes), we switched the hedging algorithm and connected dots across half a dozen documents to prove the new one is a compliant composition of a DRBG and traditional ECDSA."

#### 5.3.3 Side-Channel Protection

From FIPS 205 Implementation Considerations:

> "For signature schemes, the secrecy of the private key is critical. Care must be taken to protect implementations against attacks, such as side-channel attacks or fault attacks. A cryptographic device may leak critical information with side-channel analysis or attacks that allow internal data or keying material to be extracted without breaking the cryptographic primitives."

### 5.4 TLS Integration

From the Go blog:

> "When operating in FIPS 140-3 mode... the crypto/tls package will ignore and not negotiate any protocol version, cipher suite, signature algorithm, or key exchange mechanism that is not FIPS 140-3 approved."

This means that when FIPS mode is enabled, TLS connections automatically become restricted to FIPS-approved algorithms, including post-quantum key exchange.

---

## 6. Developer Considerations

### 6.1 Algorithm Selection

**For Key Encapsulation / Key Exchange:**

From FIPS 203:
> "Most applications should use the ML-KEM-768 parameter set"

ML-KEM-768 provides:
- Adequate post-quantum security
- Reasonable performance
- FIPS 140-3 approval when using validated modules

**For Digital Signatures:**

Choose between:
- **ML-DSA** (FIPS 204) - Lattice-based, smaller signatures, faster
- **SLH-DSA** (FIPS 205) - Hash-based, larger signatures, conservative security assumptions

From FIPS 205:
> "This standard specifies several parameter sets for SLH-DSA that are **approved** for use."

### 6.2 Key Management Requirements

From FIPS 203 on key destruction:

> "The decapsulation key must be kept private and must be destroyed after it is no longer needed."

> "The shared secret key must be kept private and must be destroyed when no longer needed."

**Private key checks** - From FIPS 205:

> "When the assurance of private key possession is obtained via regeneration, the owner of the private key **shall** check that the private key is 4n bytes in length and **shall** use SK.seed and PK.seed to recompute PK.root and compare the newly generated value with the value in the private key currently held."

### 6.3 Implementation Requirements

**Do NOT use floating-point arithmetic** - From FIPS 205:

> "Implementations of SLH-DSA **shall not** use floating-point arithmetic, as rounding errors in floating point operations may lead to incorrect results in some cases."

Similarly from FIPS 204:

> "Implementations of ML-DSA **shall not** use floating-point arithmetic, as rounding errors in floating point operations may lead to incorrect results in some cases."

**Component use prohibited** - From FIPS 205:

> "As WOTS+, XMSS, FORS, and hypertree signature schemes are not approved for use as stand-alone signature schemes, cryptographic modules **should not** make interfaces to these components available to applications. SP 800-208 specifies **approved** stateful hash-based signature schemes."

### 6.4 Randomness Requirements

From FIPS 205:

> "For each invocation of key generation, each of these values **shall** be a fresh (i.e., not previously used) random n-byte value generated using an **approved** random bit generator (RBG), as prescribed in SP 800-90A, SP 800-90B, and SP 800-90C. Moreover, the RBG used **shall** have a security strength of at least 8n bits."

In Go's FIPS mode, this is handled automatically:

> "crypto/rand.Reader is implemented in terms of a NIST SP 800-90A DRBG. To guarantee the same level of security as GODEBUG=fips140=off, random bytes are also sourced from the platform's CSPRNG at every Read and mixed into the output as uncredited additional data."

### 6.5 Testing and Validation

**Self-tests** - From the Go documentation:

> "When operating in FIPS 140-3 mode... The Go Cryptographic Module automatically performs an integrity self-check at init time, comparing the checksum of the module's object file computed at build time with the symbols loaded in memory. All algorithms perform known-answer self-tests according to the relevant FIPS 140-3 Implementation Guidance, either at init time, or on first use."

**Pairwise consistency tests:**

> "Pairwise consistency tests are performed on generated cryptographic keys. Note that this can cause a slowdown of up to 2x for certain key types, which is especially relevant for ephemeral keys."

### 6.6 Error Handling

From FIPS 203:

> "ML-KEM.KeyGen and ML-KEM.Encaps have the byte array data type but are also allowed to have the special value ⊥. When ML-KEM.KeyGen or ML-KEM.Encaps return the value ⊥, this indicates that the algorithm failed due to a failure of randomness generation."

Developers must handle these failure cases appropriately.

---

## 7. Architect Considerations

### 7.1 Crypto-Agility

**Design for algorithm migration** - The standards explicitly acknowledge future evolution. From FIPS 204:

> "Since a standard of this nature must be flexible enough to adapt to advancements and innovations in science and technology, this standard will be reviewed every five years in order to assess its adequacy."

From FIPS 205:

> "Both this standard and possible threats that reduce the security provided through the use of this standard will undergo review by NIST as appropriate, taking into account newly available analysis and technology. In addition, the awareness of any breakthrough in technology or any mathematical weakness of the algorithm will cause NIST to reevaluate this standard and provide necessary revisions."

**Recommendation:** Design systems with crypto-agility to allow algorithm updates without major architectural changes.

### 7.2 Hybrid Cryptography Strategy

The Go implementation demonstrates a successful hybrid approach:

> "crypto/tls can establish FIPS 140-3 compliant post-quantum secure connections with X25519MLKEM768"

X25519MLKEM768 combines:
- **X25519**: Classical elliptic curve Diffie-Hellman
- **ML-KEM-768**: Post-quantum key encapsulation

**Benefits of hybrid approach:**
1. Protection against quantum attacks (via ML-KEM)
2. Continued protection if PQC algorithms are broken (via classical crypto)
3. Compliance with current FIPS requirements
4. Smoother transition path

### 7.3 Performance Impact

From FIPS 203 - **Decapsulation failure rates:**

| Parameter Set | Decapsulation Failure Rate |
|--------------|---------------------------|
| ML-KEM-512   | 2^-139                    |
| ML-KEM-768   | 2^-164                    |
| ML-KEM-1024  | 2^-174                    |

**Key and ciphertext sizes** from FIPS 203:

| Parameter | Encapsulation Key | Decapsulation Key | Ciphertext |
|-----------|------------------|-------------------|------------|
| ML-KEM-512 | 800 bytes | 1632 bytes | 768 bytes |
| ML-KEM-768 | 1184 bytes | 2400 bytes | 1088 bytes |
| ML-KEM-1024 | 1568 bytes | 3168 bytes | 1568 bytes |

**Signature sizes** from FIPS 204:

ML-DSA signatures are significantly larger than classical ECDSA:
- ML-DSA-44: ~2420 bytes
- ML-DSA-65: ~3309 bytes
- ML-DSA-87: ~4627 bytes

Compare to ECDSA P-256: ~64 bytes

**Performance overhead from FIPS mode** - From the Go blog:

> "Pairwise consistency tests are performed on generated cryptographic keys. Note that this can cause a slowdown of up to 2x for certain key types, which is especially relevant for ephemeral keys."

### 7.4 Module Version Strategy

From the Go FIPS documentation:

> "GOFIPS140 works like GOOS and GOARCH, and if set to GOFIPS140=v1.0.0 the program will be built against the v1.0.0 snapshot of the packages as they were submitted for validation to CMVP."

> "Future versions of Go will continue shipping and working with v1.0.0 of the Go Cryptographic Module until the next version is fully certified by Geomys, but some new cryptography features might not be available when building against old modules."

**Architecture decision:** Choose between:
1. **Latest module** (`GOFIPS140=latest`) - Latest features, not yet validated
2. **In-process module** (`GOFIPS140=inprocess`) - Latest submitted for validation
3. **Validated module** (`GOFIPS140=v1.0.0`) - Fully validated, older feature set

### 7.5 Compliance Documentation

From FIPS 140-3 documentation:

> "NOTE: Simply using a FIPS 140-3 compliant and validated cryptographic module may not—on its own—satisfy all relevant regulatory requirements. The Go team cannot provide any guarantees or support around how usage of the provided FIPS 140-3 mode may, or may not, satisfy specific regulatory requirements for individual users. Care should be taken in determining if usage of this module satisfies your specific requirements."

**Architects must:**
1. Document which FIPS module version is used
2. Verify operating environment is in the validated list
3. Maintain evidence that only approved algorithms are used
4. Document the compliance posture

### 7.6 Operating Environment Constraints

From the Go documentation:

> "A FIPS 140-3 module is only compliant if operated on a tested or 'Vendor Affirmed' Operating Environment"

**Key architectural constraint:** Your deployment targets must match validated or vendor-affirmed environments. Deploying to an unsupported OS/architecture combination means loss of FIPS compliance.

---

## 8. Red Hat Enterprise Linux Implementation Guidance

### 8.1 RHEL PQC Availability and Status

#### 8.1.1 OpenSSL 3.5 in RHEL

Red Hat has introduced post-quantum cryptography support through OpenSSL 3.5, available in RHEL 9.6 and RHEL 10. From Red Hat documentation:

> "OpenSSL 3.5 introduces support for post-quantum cryptography (PQC) algorithms including ML-KEM (Module-Lattice-Based Key-Encapsulation Mechanism) and ML-DSA (Module-Lattice-Based Digital Signature Algorithm) as defined in FIPS 203 and FIPS 204."

**Available PQC Algorithms in OpenSSL 3.5:**

RHEL 10 provides:

**Key Encapsulation:**
> "ML-KEM-512, ML-KEM-768, and ML-KEM-1024 as specified in FIPS 203"

**Digital Signatures:**
> "ML-DSA-44, ML-DSA-65, and ML-DSA-87 as specified in FIPS 204"

**Hybrid Algorithms:**
> "Hybrid key exchange methods that combine traditional cryptography with post-quantum algorithms, including X25519+ML-KEM-768, ECDH-P256+ML-KEM-768, and ECDH-P384+ML-KEM-1024"

#### 8.1.2 Technology Preview Status

**CRITICAL: Technology Preview Limitations**

From Red Hat documentation:

> "Post-quantum cryptography support in RHEL 10 is available as a Technology Preview. Technology Preview features are not supported with Red Hat production service-level agreements (SLAs), might not be functionally complete, and Red Hat does not recommend using them for production."

**What this means for developers:**

1. **Testing and Evaluation**: PQC can be used for development, testing, and proof-of-concept work
2. **Not for Production**: Should not be deployed in production environments
3. **Not FIPS-Validated**: Technology Preview features are NOT part of FIPS-validated configurations
4. **Subject to Change**: APIs and behavior may change before General Availability

#### 8.1.3 FIPS Mode Implications

**PQC is NOT available in FIPS mode on RHEL**. From RHEL security documentation:

> "Only Generally Available (GA) features in RHEL may be used when operating in FIPS mode with the validated cryptographic module."

This means:
- If your application requires FIPS 140-3 compliance on RHEL → Cannot use PQC
- If your application requires PQC on RHEL → Cannot enable FIPS mode
- No current timeline for PQC integration into RHEL's FIPS-validated OpenSSL module

### 8.2 Testing PQC on RHEL (Non-FIPS Mode)

#### 8.2.1 Prerequisites

**System Requirements:**
- RHEL 9.6 or later, OR RHEL 10
- OpenSSL 3.5 or later
- Development tools (gcc, make, openssl-devel)

**Verify OpenSSL version:**

```bash
$ openssl version
OpenSSL 3.5.0 (or later)
```

#### 8.2.2 Testing ML-KEM Key Encapsulation

Example command-line usage:

**Generate ML-KEM-768 key pair:**

```bash
$ openssl genpkey -algorithm mlkem768 -out mlkem_private.pem
$ openssl pkey -in mlkem_private.pem -pubout -out mlkem_public.pem
```

**Encapsulation (performed by peer):**

```bash
$ openssl pkeyutl -derive -inkey mlkem_public.pem -pubin \
    -out ciphertext.bin -out shared_secret.bin
```

**Decapsulation:**

```bash
$ openssl pkeyutl -derive -inkey mlkem_private.pem \
    -in ciphertext.bin -out decapsulated_secret.bin
```

#### 8.2.3 Testing ML-DSA Digital Signatures

**Generate ML-DSA-65 key pair:**

```bash
$ openssl genpkey -algorithm mldsa65 -out mldsa_private.pem
$ openssl pkey -in mldsa_private.pem -pubout -out mldsa_public.pem
```

**Sign a message:**

```bash
$ echo "Message to sign" > message.txt
$ openssl pkeyutl -sign -inkey mldsa_private.pem \
    -in message.txt -out signature.bin
```

**Verify signature:**

```bash
$ openssl pkeyutl -verify -pubin -inkey mldsa_public.pem \
    -in message.txt -sigfile signature.bin
```

### 8.3 Red Hat's PQC Roadmap

#### 8.3.1 Phased Approach

From Red Hat documentation:

> "Red Hat's PQC adoption follows a phased approach:
> 1. **Phase 1 (Current)**: Technology Preview in RHEL 9.6 and RHEL 10
> 2. **Phase 2**: General Availability for selected use cases
> 3. **Phase 3**: FIPS module integration
> 4. **Phase 4**: Deprecation of quantum-vulnerable algorithms"

**No specific timelines** have been published for phases 2-4.

#### 8.3.2 OpenShift Quantum-Safe Status

From Red Hat OpenShift documentation:

> "As of OpenShift 4.18, post-quantum cryptography is available in Technology Preview for:
> - TLS connections using hybrid key exchange
> - Certificate generation with ML-DSA signatures (experimental)
> - Container image signing with PQC algorithms (testing only)"

**Production readiness guidance**:

> "Red Hat recommends that customers begin planning for quantum-safe migration but continue using currently approved cryptographic algorithms for production workloads until PQC achieves General Availability status and FIPS validation."

### 8.4 Recommendations for RHEL Developers

#### 8.4.1 Current State (March 2026)

**For production applications:**
- ✅ Use FIPS-approved classical algorithms (ECDH, RSA, ECDSA)
- ✅ Enable FIPS mode if compliance required
- ❌ Do NOT use PQC in production (Technology Preview only)
- ✅ Begin architecture planning for PQC migration

**For development/testing:**
- ✅ Experiment with OpenSSL 3.5 PQC in lab environments
- ✅ Test interoperability with FIPS 203/204 compliant implementations
- ✅ Evaluate performance characteristics of ML-KEM and ML-DSA
- ❌ Do NOT enable FIPS mode when testing PQC

#### 8.4.2 Architecture Planning for Future PQC

**Design for crypto-agility** to enable smooth PQC transition:

1. **Abstract cryptographic operations** behind interfaces
2. **Make algorithm selection configurable** via environment/config
3. **Implement hybrid approaches** where possible (once available in FIPS mode)
4. **Plan for larger key/signature sizes** in protocols and storage
5. **Monitor Red Hat announcements** for GA and FIPS validation timelines

From FIPS 204:

> "Since a standard of this nature must be flexible enough to adapt to advancements and innovations in science and technology, this standard will be reviewed every five years in order to assess its adequacy."

---

## 9. Migration Strategy

### 9.1 Assessment Phase

1. **Identify cryptographic operations** in your codebase
2. **Determine FIPS requirements** for your organization
3. **Evaluate current algorithm usage** (classical vs. post-quantum)
4. **Review deployment platforms** against validated operating environments

### 9.2 Planning Phase

**Choose your target state:**

From the standards, federal systems must use:
> "Either this standard, FIPS 204, FIPS 186-5, or NIST Special Publication 800-208 **shall** be used in designing and implementing public-key-based signature systems"

Options:
1. **Classical FIPS-approved only** (temporary, quantum-vulnerable)
2. **Post-quantum FIPS-approved only** (future-proof, larger keys/signatures)
3. **Hybrid approach** (recommended, balanced protection)

### 9.3 Implementation Phase

**For Go applications:**

1. **Upgrade to Go 1.24+**
   ```bash
   go version  # Verify >= 1.24
   ```

2. **Enable FIPS mode in development**
   ```bash
   export GODEBUG=fips140=on
   go run main.go
   ```

3. **Test with enforcement**
   ```bash
   export GODEBUG=fips140=only
   # This will cause non-approved algorithms to panic
   ```

4. **Build against validated module**
   ```bash
   GOFIPS140=v1.0.0 go build -o myapp
   ```

5. **Verify FIPS module version**
   ```bash
   go version -m myapp
   ```

### 9.4 Testing Phase

From FIPS implementation considerations:

> "NIST will develop a validation program to test implementations for conformance to the algorithms in this standard. Information about validation programs is available at https://csrc.nist.gov/projects/cmvp."

**Test checklist:**
- [ ] Self-tests execute successfully at init
- [ ] Only approved algorithms are negotiated in TLS
- [ ] Key generation uses approved RBG
- [ ] Pairwise consistency tests execute
- [ ] Proper error handling for ⊥ (failure) returns
- [ ] Performance acceptable with FIPS overhead

### 9.5 Deployment Phase

**Verify operating environment:**

Confirm your deployment platform matches:
- Tested operating environments (23 specific combinations), OR
- Vendor Affirmed Operating Environments (generic platform specs)

**Set runtime configuration:**

```bash
# Environment variable
export GODEBUG=fips140=on

# Or via go.mod directive for embedded configuration
```

**Monitor and maintain:**

From the standards:
> "Geomys plans to validate new module versions at least every year—to avoid leaving FIPS 140 builds too far behind—and every time a vulnerability in the module can't be mitigated in the calling standard library code."

Plan for periodic updates to newer validated module versions.

---

## 10. References

### 10.1 NIST FIPS Publications

1. **FIPS 203** - Module-Lattice-Based Key-Encapsulation Mechanism Standard
   Published: August 13, 2024
   https://doi.org/10.6028/NIST.FIPS.203

2. **FIPS 204** - Module-Lattice-Based Digital Signature Standard
   Published: August 13, 2024
   https://doi.org/10.6028/NIST.FIPS.204

3. **FIPS 205** - Stateless Hash-Based Digital Signature Standard
   Published: August 13, 2024
   https://doi.org/10.6028/NIST.FIPS.205

### 10.2 Go Programming Language Resources

1. **FIPS 140-3 Compliance**
   https://go.dev/doc/security/fips140

2. **The FIPS 140-3 Go Cryptographic Module**
   Blog post dated July 15, 2025
   https://go.dev/blog/fips140

3. **crypto/fips140 Package Documentation**
   https://pkg.go.dev/crypto/fips140@go1.26.0

4. **crypto/mlkem Package Documentation**
   https://pkg.go.dev/crypto/mlkem

### 10.3 Red Hat Resources

1. **Post-quantum cryptography in Red Hat Enterprise Linux 10**
   Red Hat Customer Portal
   https://access.redhat.com/

2. **How Red Hat is integrating post-quantum cryptography into our products**
   Red Hat Developer
   https://developers.redhat.com/

3. **OpenSSL 3.5 Post-Quantum Lab: ML-KEM & ML-DSA on RHEL 9.6**
   Red Hat Customer Portal
   https://access.redhat.com/

4. **The road to quantum-safe cryptography in Red Hat OpenShift**
   Red Hat Developer
   https://developers.redhat.com/

5. **Interoperability of RHEL 10 post-quantum cryptography**
   Red Hat Customer Portal
   https://access.redhat.com/

### 10.4 Additional Resources

1. **NIST Post-Quantum Cryptography**
   https://csrc.nist.gov/projects/post-quantum-cryptography

2. **CMVP Validation Program**
   https://csrc.nist.gov/projects/cmvp

3. **SP 800-208** - Recommendation for Stateful Hash-Based Signature Schemes

4. **SP 800-227** - (For KEM security requirements)

---

## Appendix A: Quick Reference

### Algorithm Selection Matrix

| Use Case | Classical FIPS | Post-Quantum FIPS | Hybrid |
|----------|---------------|-------------------|--------|
| TLS Key Exchange | ECDH (P-256, P-384) | ML-KEM-768 | X25519MLKEM768 ✓ |
| Digital Signatures | ECDSA, RSA | ML-DSA-65, SLH-DSA | Not yet standardized |
| Key Encapsulation | N/A (use key agreement) | ML-KEM-768 ✓ | N/A |

✓ = Recommended

### Go FIPS Commands

```bash
# Build with FIPS module v1.0.0 (validated)
GOFIPS140=v1.0.0 go build

# Build with latest in-process module
GOFIPS140=inprocess go build

# Enable FIPS mode at runtime
export GODEBUG=fips140=on

# Enable strict FIPS enforcement
export GODEBUG=fips140=only

# Check if FIPS is enabled
go run -ldflags="-X main.checkFIPS=1" main.go

# Verify module version in binary
go version -m ./myapp
```

### Key Sizes Quick Reference

**ML-KEM-768 (Recommended):**
- Public key: 1184 bytes
- Private key: 2400 bytes
- Ciphertext: 1088 bytes
- Shared secret: 32 bytes

**ML-DSA-65 (Common choice):**
- Public key: ~1952 bytes
- Private key: ~4032 bytes
- Signature: ~3309 bytes

**For comparison, ECDSA P-256:**
- Public key: 64 bytes
- Private key: 32 bytes
- Signature: ~64 bytes

---

## Appendix B: Compliance Checklist

### FIPS 140-3 Compliance

- [ ] Using Go 1.24 or later
- [ ] Built with `GOFIPS140=v1.0.0` (or validated version)
- [ ] Runtime has `GODEBUG=fips140=on` set
- [ ] Deployment platform is in validated/affirmed OS list
- [ ] Using only FIPS-approved algorithms
- [ ] Proper RBG for key generation (automatic in Go FIPS mode)
- [ ] Self-tests execute successfully
- [ ] Private keys properly destroyed when no longer needed

### Post-Quantum Readiness

- [ ] Identified all public-key cryptography usage
- [ ] Selected appropriate PQC algorithm (ML-KEM-768 for key exchange)
- [ ] Tested with larger key/signature sizes
- [ ] Validated performance impact acceptable
- [ ] Implemented hybrid approach where appropriate
- [ ] Documented algorithm choices and rationale
- [ ] Planned for future algorithm agility

### Security Requirements

- [ ] No floating-point arithmetic in crypto code
- [ ] Side-channel attack mitigations considered
- [ ] Proper error handling for algorithm failures (⊥ returns)
- [ ] Key validation checks implemented
- [ ] Sensitive data destruction verified
- [ ] Security audit completed (if required)

---

## Glossary

**Approved** - FIPS-approved and/or NIST-recommended algorithm or technique

**CAVP** - Cryptographic Algorithm Validation Program

**CMVP** - Cryptographic Module Validation Program

**DRBG** - Deterministic Random Bit Generator

**KEM** - Key Encapsulation Mechanism

**ML-DSA** - Module-Lattice-Based Digital Signature Algorithm (FIPS 204)

**ML-KEM** - Module-Lattice-Based Key-Encapsulation Mechanism (FIPS 203)

**MLWE** - Module Learning With Errors (computational problem)

**PQC** - Post-Quantum Cryptography

**RBG** - Random Bit Generator

**SLH-DSA** - Stateless Hash-Based Digital Signature Algorithm (FIPS 205)

---

**Document Version:** 1.0
**Last Updated:** 2026-03-02
**Status:** Draft for Review

This document synthesizes information from official NIST FIPS publications and Go programming language documentation. All quoted material is attributed to source documents listed in the References section.
