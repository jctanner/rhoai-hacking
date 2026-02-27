# Quantum-safe API Security - How to prepare APIs for the post-quantum future _ Curity

**Source:** `Quantum-safe API Security - How to prepare APIs for the post-quantum future _ Curity.pdf`

---

Quantum-safe API Security - How to prepare APIs for the po...

1 of 8

https://curity.io/blog/quantum-safe-api-security/

How to Prepare APIs for the Post-quantum Future
Quantum computing changes the security assumptions for APIs. With the help of
specialized algorithms, quantum computers can speed up calculations and
potentially break common cryptographic algorithms. To keep data safe, things need
to change. This article discusses controls that you should take to boost an API
security architecture and prepare for quantum computing.
Fortunately, several practical steps - including robust token design and proxy
conﬁguration - already allow teams to build quantum-resilient APIs today, even
before new cryptographic standards are fully deployed.

What is Quantum Computing?
Quantum computing takes advantage of physical properties such as superposition
and entanglement. Superposition allows tiny particles to be in multiple energy
states at once, while entanglement links particles so their states remain
synchronized, even across distance.
While conventional computers operate on “bits” to store information that can either
be on (1) or off (0), quantum computers use quantum bits, “qubits”, that can be in
multiple states. That is, qubits can be zero, one and anything in between at the
same time. Furthermore, the states of qubits can be entangled giving a quantum
computer exceptionally much more computing power. As a result, the main beneﬁts
of quantum computing are parallelism and processing speed.

2/27/26, 3:26 PM

Quantum-safe API Security - How to prepare APIs for the po...

https://curity.io/blog/quantum-safe-api-security/

Quantum computers are not good at everything; they perform very well for special
computations. It turns out that quantum computers are good at breaking crypto,
which impacts the techniques used to protect APIs and business data.

What is the Impact of Quantum Computing on API
Security?
API security relies heavily on cryptographic algorithms to deliver key security
properties such as conﬁdentiality, integrity, authenticity and non-repudiation. These
typically rely on mathematical problems that are difﬁcult for traditional computers
to solve.
Quantum computers change the current state of the art signiﬁcantly. They can
eventually solve common cryptographic problems in a fraction of time compared to
conventional computing (e.g., hours instead of years). Such computers are called
Cryptographically Relevant Quantum Computers (CRQC). They basically deprecate
many common cryptographic algorithms.
In practical terms, there is a risk that transport encryption such as HTTPS can be
decrypted and requests manipulated on the ﬂy, or that unauthorized parties can
create valid signatures to undermine any integrity and authenticity. In other words,
the availability of CRQC potentially breaks common API security controls and
neutralizes any trust in digital communications.
There are still challenges with quantum computing that prevent a big rollout of
CRQCs. Quantum computers are error-prone, for example, and can only process a
limited amount of data. So far, researchers have only managed to crack RSA with
very small keys (such as 80-bit) using quantum computers. However, attackers may
already harvest encrypted data for later decryption with CRQC (an attack called
“harvest now, decrypt later”), putting data from the past (archived documents),
present and future at risk.
Researchers estimate that a quantum computer with less than a million noisy
qubits could factor a 2048-bit RSA integer in less than a week. In line with that risk,
NIST recommends in its initial public draft deprecating ECDSA, EdDSA and RSA in
2030 and stopping using them after 2035. Similarly, the European Commission
recommends member states to transfer to post-quantum cryptography as soon as
possible.

2 of 8

2/27/26, 3:26 PM

Quantum-safe API Security - How to prepare APIs for the po...

https://curity.io/blog/quantum-safe-api-security/

What is Post-Quantum Cryptography?
Post-quantum cryptography (PQC) encompasses algorithms whose security
properties hold despite the processing power of quantum computers of tomorrow.
It means that not even cryptographically relevant quantum computers will be able to
break such algorithms, decipher encrypted communication or calculate private keys
from public keys. Other names for post-quantum cryptography are quantum-proof,
quantum-resilient or quantum-safe cryptography (QSC).
Standardization and guidance is very important when it comes to the selection of
cryptographic algorithms. The following list includes algorithms that either the
National Institute of Standards and Technology (NIST) or the German Federal Ofﬁce
for Information Security (BSI) calls out to be quantum-safe.
Key Agreement: FrodoKem, ML-KEM
Symmetric Encryption: AES
Hash Functions: SHA2, SHA3
Message Authentication Code: HMAC, CMAC
Signature Schemes: ML-DSA, SLH-DSA
The above list includes new and traditional algorithms because cryptographically
relevant quantum computers have a higher impact on asymmetric algorithms than
on symmetric ones. If you are already using SHA2, and AES such as AES-GCM, for
example, then you may not have to change (much) in certain areas of your API
security architecture.

How Does Quantum Computing Affect the Curity Identity
Server?
The Curity Identity Server uses cryptography across several key areas. Here’s how
it’s affected.

3 of 8

2/27/26, 3:26 PM

Quantum-safe API Security - How to prepare APIs for the po...

4 of 8

Area

Conﬁguration

Hashing func‐
tions

Algorithms

Quantum-

(available)

Safe

AES

yes

https://curity.io/blog/quantum-safe-api-security/

Comment

SHA2
(SHA-256,

yes

SHA-512)
Can be solved via a re‐

TLS 1.3

ECDSA,

(Handshake)

EdDSA, RSA

Not yet

verse proxy that supports
TLS 1.3 with quantumsafe algorithms.

TLS 1.3
(Encryption)

AES-GCM

yes

External clients receive
Access
Tokens

access and refresh tokens
N/A

yes

with an unguessable and
quantum-safe opaque ac‐
cess token format.
Mostly used in the internal
network, where APIs re‐

Token

RSA, ECDSA,

Signatures

EdDSA

Not yet

ceive JWT access tokens.
Future product versions
will support quantum-safe
signature algorithms.

Symmetric
Signatures
Symmetric en‐
cryption

HMAC-SHA

yes

AES

yes

The above table lists two current vulnerabilities: TLS and token signatures. TLS is
typically out of hand of the Curity Identity Server as the TLS communication
terminates at an API gateway.

2/27/26, 3:26 PM

Quantum-safe API Security - How to prepare APIs for the po...

5 of 8

https://curity.io/blog/quantum-safe-api-security/

a proxy. It means that you don’t have to rely on Curity to solve the problem but can
address it independently via the proxy. This leaves token signatures as the only
open issue. With the correct architecture, you don’t even have to bother with that.

Phantom Tokens: A Practical, Quantum-Safe Token
Strategy
Curity has been advocating the phantom token approach as a best practice for
years. Typically we explain the privacy and architecture beneﬁts. But it turns out that
phantom tokens are also the most effective and immediately implementable
strategy for quantum-safe access tokens.

The phantom token approach is simple to understand:
1. The authorization server issues opaque, random tokens (not JWTs).
2. Clients receive and use these non-parsable tokens.
3. At runtime, the API gateway introspects the token and exchanges it for a
signed JWT inside the trusted network.
Opaque access tokens are quantum-safe tokens. They are random strings that the
authorization server associates with some data. The only way to determine whether
an opaque access token is valid, is via the authorization server using a protocol
called introspection. A cryptographically relevant quantum computer cannot craft a
valid, opaque token to pass validity checks.

2/27/26, 3:26 PM

Quantum-safe API Security - How to prepare APIs for the po...

6 of 8

https://curity.io/blog/quantum-safe-api-security/

With opaque tokens, a quantum computer must guess the correct value. It may, at
best, be quicker to generate new random values than conventional computers, but it
still needs to try each guess to check whether it found a valid token that gives
access. This is no different from the current threat of brute forcing.
You should address the threat of brute force independently from the quantum
computing risks. What is more, since brute force is not a new risk, you most likely
already have controls in place. For example, you may already use mechanisms such
as rate limiting and cooldowns to restrict requests with invalid access tokens.
By simply changing to opaque access tokens and applying the phantom token
approach, you can reduce the API risks of quantum computing to those of brute
force attacks. There is no need to support new, complex algorithms for access
tokens that you return to external clients. Once quantum-safe algorithms are
available, you can also update the internal network to use them without changing
your deployment architecture. The phantom token approach is therefore futureproof.

Conclusion
Cryptographically relevant quantum computers (CRQC) appear scary because of
their impact on the current ecosystem. Some solutions require a switch to postquantum algorithms. For example, to mitigate the risk of harvest-now-decrypt-later
threats, change to TLS 1.3 with quantum-safe algorithms in your reverse proxy or
API gateway. Some proxy vendors already support quantum-safe TLS.
When it comes to access tokens, you can use the phantom token approach to
achieve a post-quantum solution without quantum-safe algorithms. Sometimes, the
simplest solutions are the best and most robust. The phantom token approach is
one of them. The Curity Identity Server supports the phantom token pattern out of
the box - letting you build secure, scalable, and quantum-resilient API architectures
today.



Blog

View all tags

2/27/26, 3:26 PM

Quantum-safe API Security - How to prepare APIs for the po...

7 of 8

https://curity.io/blog/quantum-safe-api-security/

Join The Discussion
Follow @curityio on X and Bluesky

Follow @curityio

Follow @curityio

Start a Free Trial

NEXT STEPS

Book a Call

Ready for the Next Generation of
IAM?
Build secure, ﬂexible identity solutions that
keep pace with innovation. Start today.

2/27/26, 3:26 PM

Quantum-safe API Security - How to prepare APIs for the po...

8 of 8

https://curity.io/blog/quantum-safe-api-security/

Speak to an Identity Specialist

Explore learning resources

2/27/26, 3:26 PM

