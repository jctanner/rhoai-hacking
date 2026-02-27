# Securing APIs with The Phantom Token Approach _ Curity

**Source:** `Securing APIs with The Phantom Token Approach _ Curity.pdf`

---

Securing APIs with The Phantom Token Approach | Curity

1 of 7

https://curity.io/resources/learn/phantom-token-pattern/

The Phantom Token Approach

The Phantom Token Approach is a privacy-preserving token usage pattern for
microservices. It combines the beneﬁts of opaque and structured tokens. To
understand the pattern it is therefore essential to understand the basic
differences between these token types.

OAuth 2.0 Token Types
When OAuth 2.0 was deﬁned tokens were intentionally kept abstract and the
format was not deﬁned. There is basically no limitation on the format of
tokens that an authorization server may issue. In practice you can distinguish
two types of tokens:
• Opaque tokens (by reference)
• Structured tokens (by value)
An opaque token is a random string that has no meaning to the resource
server thus the token is opaque. However, there is metadata connected to the
token such as its validity or the list of approved scopes that may be of
relevance or even vital for the authorization decision of the resource server
AKA API or microservice. In a system using solely opaque tokens the resource
server cannot retrieve this kind of information from the token itself but must
call the authorization server by sending a request at the introspection endpoint
as illustrated below.

2/27/26, 3:27 PM

Securing APIs with The Phantom Token Approach | Curity

2 of 7

https://curity.io/resources/learn/phantom-token-pattern/

An opaque token can be seen as the reference to the user attributes and token
metadata. Thus passing an opaque token can also be referred to as passing a
token by reference.
Having to look up each token for validation will inevitably create load on the
resource and authorization server as well as infrastructure. Structured token
formats such as JSON web tokens (JWT) solve this problem. JWT tokens are
compact and lightweight tokens that are designed to be passed in HTTP
headers and query parameters. They are signed to protect the integrity of its
data and can even be encrypted for privacy reasons. Since the format is well
deﬁned the resource server can decode and verify the token without calling
any other system.
Structured tokens are tokens passed by value. The token contains enough
data for the resource server to make its authorization decision. Often, it also
contains user information. In certain cases such a token may even contain
personal identiﬁable information (PII) or other data protected by law or
regulations and the token as well as related systems become a subject to
compliance requirements.

The Phantom Token Approach
The Phantom Token Approach is a prescriptive pattern for securing APIs and
microservices that combines the security of opaque tokens with the

2/27/26, 3:27 PM

Securing APIs with The Phantom Token Approach | Curity

3 of 7

https://curity.io/resources/learn/phantom-token-pattern/

convenience of JWTs. The idea is to have a pair of a by-reference and a byvalue token. The by-value token (JWT) can be obtained with the help of a byreference equivalent (opaque token). The client is not aware of the JWT and
therefore we call the token the Phantom Token.
When a client asks for a token the Token Service returns a by-reference token.
Instead of having the APIs and microservices call the Token Service for
resolving the by-reference token for every request the pattern takes advantage
of an API gateway, reverse proxy or any other middleware that is usually
placed between the client and the APIs. In that way the APIs and
microservices can beneﬁt from the JWT without exposing any data to the
client since the client will only retrieve an opaque token.

1. The client retrieves a by-reference token using any OAuth 2.0 ﬂow.
2. The client forwards the token in its requests to the API.
3. The reverse proxy looks up the by-value token by calling the
Introspection endpoint of the Token Service.
4. The reverse proxy replaces the by-reference token with the by-value
token in the actual request to the microservice.

Beneﬁts of Using Opaque Tokens
The main beneﬁt of using opaque tokens is security. Access tokens are
intended for the resource server, the API. However, a client may violate this
rule and parse a token nevertheless. By using opaque tokens clients are
prevented from implementing logic based on the content of access tokens. In

2/27/26, 3:27 PM

Securing APIs with The Phantom Token Approach | Curity

4 of 7

https://curity.io/resources/learn/phantom-token-pattern/

addition opaque tokens for clients limit the regulated space and remove the
risk of data leakages and compliance violations. It is simply not possible for
the client to access or leak any data because it is not given any.
At the same time, security is increased and performance is optimized. The
microservices will use JWT tokens that contain all the data that the service
requires for processing. No need for time consuming requests. In addition, the
pattern can utilize caching mechanisms of the reverse proxy. A by-value token
can be cached until it expires. The Curity Identity Server supports HTTP cache
headers with updated values for this purpose. As a result the number of
requests needed for token exchange is minimized and the system's
performance is optimized.
The Phantom Token Approach is compliant with the OAuth 2.0 standard.
Neither the client nor the APIs have to implement any proprietary solution for
this pattern. This makes the pattern vendor neutral and applicable for any
OAuth 2.0 ecosystem.

Further Reading
Check out the tutorial on phantom tokens and the module for NGINX on
GitHub

Published: 2020-03-27

Curity

2/27/26, 3:27 PM

Securing APIs with The Phantom Token Approach | Curity

5 of 7

https://curity.io/resources/learn/phantom-token-pattern/

Join our Newsletter
Get the latest on identity management, API Security and
authentication straight to your inbox.

Start Free Trial
Try the Curity Identity Server for Free. Get up and running in 10
minutes.

Start Free Trial

Was this helpful?

2/27/26, 3:27 PM

Securing APIs with The Phantom Token Approach | Curity

6 of 7

https://curity.io/resources/learn/phantom-token-pattern/

Start a Free Trial

NEXT STEPS

Ready for the Next Generation of

Book a Call

IAM?
Build secure, ﬂexible identity solutions that
keep pace with innovation. Start today.

Speak to an Identity Specialist

Explore learning resources

2/27/26, 3:27 PM

Securing APIs with The Phantom Token Approach | Curity

7 of 7

https://curity.io/resources/learn/phantom-token-pattern/

Start a Free Trial

NEXT STEPS

Ready for the Next Generation of

Book a Call

IAM?
Build secure, ﬂexible identity solutions that
keep pace with innovation. Start today.

Speak to an Identity Specialist

Explore learning resources

2/27/26, 3:27 PM

