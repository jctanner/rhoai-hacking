# API Key Design

**Source:** `API Key Design.pdf`

---

API Key

1 of 7

https://microservice-api-patterns.org/patterns/structure/spec...

How can an API provider identify and authenticate clients and their requests?



Context

Problem

Forces

Solution

Consequences

Known Uses

More Information

An API provider o�ers services to subscribed participants only. For various reasons, such as establishing
a RATE LIMIT or PRICING PLAN, one or more clients have signed up and want to use the services. These
clients have to be identi�ed.

How can an API provider identify and authenticate clients and their requests?

When identifying and authenticating clients on the API provider side, the following forces come into play:
— Establishing basic security

2/27/26, 1:17 PM

API Key

2 of 7

https://microservice-api-patterns.org/patterns/structure/spec...

— Access control
— Avoiding the need to store or transmit user account credentials
— Decoupling clients from their organization
— Security versus ease of use
— Performance
Pattern forces are explained in depth in the book.

As an API provider, assign each client a unique token —- the API KEY -— that the client can present to the
API endpoint for identi�cation purposes.

A solution sketch for this pattern from pre-book times is:

In the following call to the Cloud Convert API a new process to convert a DOCX �le to PDF format is
started. The client creates a new conversion process by informing the provider of the desired in- and
output format, passed as two ATOMIC PARAMETERS in the body of the request (the input �le has to be
provided by a second call to the API). For billing purposes, the client identi�es itself by passing the API
KEY gqmbwwB74tToo4YOPEsev5 in the Authorization header of the request, according to the
HTTP/1.1 Authentication RFC 7235 speci�cation. HTTP supports various types of authentication, here the
RFC 6750 Bearer type is used:

POST https://api.cloudconvert.com/process

2/27/26, 1:17 PM

API Key

3 of 7

https://microservice-api-patterns.org/patterns/structure/spec...

Authorization: Bearer gqmbwwB74tToo4YOPEsev5
Content-Type: application/json
{
"inputformat": "docx",
"outputformat": "pdf"
}

The API provider can thus identify the client and charge their account.
Are you missing implementation hints? Our papers publications provide them (for selected patterns).

The resolution of pattern forces and other consequences are discussed in our book.

Many public Web APIs use the API KEY concept, sometimes under di�erent names (such as access token).
A few examples are:
— The YouTube Data API supports both OAuth 2.0 as well as API KEYS. Clients have to generate di�erent
API KEYS, depending on where these keys are used, e.g., server keys, browser keys, iOS and Android
keys. These keys can then only be used by the con�gured apps (in case of the iOS and Android apps),
IP addresses or domain names. This additional layer of protection makes a speci�c key unusable
outside of the speci�ed app. This is done to avoid that an attacker could, for example, simply extract
the key from an installed Android application and use it to make requests on behalf of that
application.
— The GitHub API’s primary means of authentication and authorization is OAuth, but basic
authentication with a username and token – the API KEY – is also supported. Here, the API KEY is not
sent via HTTP header but through the password parameter of the basic authentication. For example,
a request to access the user resource using the cURL command line tool looks as follows: curl -u
username:token https://api.github.com/user .
— The API of online payment provider Stripe uses a publishable key and a secret key. The secret key
takes the role of an API KEY and is transmitted in the Authorization header of each request,

2/27/26, 1:17 PM

API Key

4 of 7

https://microservice-api-patterns.org/patterns/structure/spec...

whereas the publishable key is just the account identi�er. This naming scheme might be surprising
for clients expecting the secret key to be kept private, like Amazon’s secret key, which is never
transmitted and only used to sign requests.

Many web servers use Session Identi�ers as described by Fowler (2002) to maintain and track user sessions
across multiple requests; this is a similar concept. In contrast to API KEYS, Session Identi�ers are only used
for single sessions and then discarded.
The Security Patterns in Schumacher et al. (2006) provide solutions satisfying security requirements such
as Con�dentiality, Integrity, and Authentication/Authorization, and discusses their strengths and
weaknesses in detail. Access control mechanisms, such as Role-based Access Control (RBAC) or Attributebased Access Control (ABAC), can complement API KEYS and other approaches to authentication; these
access control practices require one of the described authentication mechanisms to be in place.

Chapter 12 of the RESTful Web Services Cookbook Allamaraju (2010) is dedicated to security and presents
six related recipes. Pautasso, Ivanchikj, and Schreier (2016) covers two related patterns of alternative
authentication mechanism in a RESTful context, Basic Resource Authentication and Form-Based Resource
Authentication.
Siriwardena (2014) provides a comprehensive discussion on securing APIs with OAuth 2.0, OpenID
Connect, JWS, and JWE. Chapter 9 of Sturgeon (2016) has a discussion of conceptual and technology
alternatives and instructions on how to implement an OAuth 2.0 server. The OpenID Connect
speci�cation deals with user identi�cation on top of the OAuth 2.0 protocol.

Allamaraju, Subbu. 2010. RESTful Web Services Cookbook. O’Reilly.
Farrell, Stephen. 2009. “API Keys to the Kingdom.” IEEE Internet Computing, no. 5: 91–93.
Fowler, Martin. 2002. Patterns of Enterprise Application Architecture. Addison-Wesley.
Pautasso, Cesare, Ana Ivanchikj, and Silvia Schreier. 2016. “A Pattern Language for RESTful

2/27/26, 1:17 PM

API Key

5 of 7

https://microservice-api-patterns.org/patterns/structure/spec...

Conversations.” In Proceedings of the 21st European Conference on Pattern Languages of Programs
(EuroPLoP). Irsee, Germany.
Schumacher, Markus, Eduardo Fernandez-Buglioni, Duane Hybertson, Frank Buschmann, and Peter
Sommerlad. 2006. Security Patterns: Integrating Security and Systems Engineering. Wiley.
Siriwardena, Prabath. 2014. Advanced API Security: Securing APIs with OAuth 2.0, OpenID Connect, JWS, and
JWE. Apress.
Sturgeon, Phil. 2016. Build APIs You Won’t Hate. LeanPub. https://leanpub.com/build-apis-you-wont-hate.

— API Description
— Backend Integration
— Community API
— Frontend Integration
— Public API
— Solution-Internal API

— Computation Function
— Data Transfer Resource
— Information Holder Resource
— Link Lookup Resource
— Master Data Holder
— Operational Data Holder
— Processing Resource
— Reference Data Holder
— Retrieval Operation
— State Creation Operation
— State Transition Operation

2/27/26, 1:17 PM

API Key

6 of 7

https://microservice-api-patterns.org/patterns/structure/spec...

— API Key
— Atomic Parameter
— Atomic Parameter List
— Context Representation
— Data Element
— Error Report
— Id Element
— Link Element
— Metadata Element
— Parameter Forest
— Parameter Tree

— Conditional Request
— Embedded Entity
— Linked Information Holder
— Pagination
— Pricing Plan
— Rate Limit
— Request Bundle
— Service Level Agreement
— Wish List
— Wish Template

— Aggressive Obsolescence
— Eternal Lifetime Guarantee
— Experimental Preview
— Limited Lifetime Guarantee
— Semantic Versioning

2/27/26, 1:17 PM

API Key

7 of 7

https://microservice-api-patterns.org/patterns/structure/spec...

— Two in Production
— Version Identi�er





Copyright © 2019-2023.
All rights reserved. See terms and conditions of use.



2/27/26, 1:17 PM

