# What Is an API Key_ _ IBM

**Source:** `What Is an API Key_ _ IBM.pdf`

---

What Is an API Key? | IBM

1 of 15

https://www.ibm.com/think/topics/api-key

Cloud

What is an API key?

2/27/26, 12:18 PM

What Is an API Key? | IBM

2 of 15

https://www.ibm.com/think/topics/api-key

Authors
Gita Jackson

Michael Goodwin

Staff Writer

Staff Editor, Automation &
ITOps
IBM Think

What is an API key?
An API key is a unique identiﬁer used to authenticate software and
systems attempting to access other software or systems via an
application programming interface, or API.
An API, or application programming interface, is a set of rules or protocols that enable
software applications to communicate with each other to exchange data, features and
functionality. APIs give application owners a simple, secure way to make their application
data and functions available to departments within their organization. Application owners
can also share or market data and functions to business partners or third parties. APIs
allow for the sharing of only the information necessary, keeping other internal system
details hidden, which helps with system security.
Because APIs can provide access to sensitive data, it’s important that the API can validate
that the application making the request is authorized to do so. Using API keys enables an
application developer to authenticate the applications that are calling an API’s backend to
ensure they are authorized to do so.
While API keys can be an aspect of making sure an enterprise’s APIs—and the data they
handle—are secure, they are not a deﬁnitive API security solution. Notably, API keys are not
as secure as authentication tokens or the OAuth (open authorization) protocol. These
measures are better suited to authenticate speciﬁc human users, give organizations more
granular control over access to the functions of a speciﬁc API and can be set to expire.
OAuth can be used with API keys or on their own. Sometimes an enterprise might use an
API key for some users but use OAuth for other users. There are other methods of

2/27/26, 12:18 PM

What Is an API Key? | IBM

3 of 15

https://www.ibm.com/think/topics/api-key

authenticating calls to an API, such as JSON Web Tokens (JWT), but they are not as
commonly used.
API keys are still a useful aspect of API security, as they help organizations monitor calls to
APIs and manage API consumption, increasing security and ensuring that these programs
have adequate bandwidth.

Keep your head in the cloud
Get the weekly Think Newsletter for expert guidance on
optimizing multicloud settings in the AI era.

Subscribe today

How do API keys work?
An API key is a randomly generated, unique alphanumeric string of characters that APIs
use to authenticate the applications that are making calls to an API. Each key that an API
provider issues is associated with speciﬁc API client, such as a software module. API keys
enable an API server to identify which software and applications are sending a call to the
API. The generated key is used for every request made from that application or project to
the associated API (until the key is refreshed or deleted).

The process works like this:
When an application makes a call to an API to request functions or data from another
application, the API server uses the API key to validate the application's authenticity. For
web applications and REST APIs, the key can be sent as a header, in a query string, or as a
cookie. If the API key matches an approved key, the server returns the requested data. If it
does not, it denies the call and sends a rejection message.

2/27/26, 12:18 PM

What Is an API Key? | IBM

4 of 15

https://www.ibm.com/think/topics/api-key

Developers can add more validations and restrictions if necessary.
For example, developers can conﬁgure access rights for an application or project that only
allow access to certain kinds of data or functions. Developers can also set application
restrictions that specify which websites, IP addresses, applications (or mobile apps) and
software development kits (SDKs) can use an API key.

WebMethods Hybrid Integration

Reimagine integration for the AI era
IBM Web Methods Hybrid Integration showcases how businesses can
seamlessly connect cloud and on-premises applications, enabling agile
and scalable digital transformation.
Explore IBM webMethods

API keys and API security
While API keys are part of API security, they should not be the only way that an
organization authenticates and validates calls being made to an API. In fact, while API keys
are useful, they are not an especially secure method of authenticating calls. API keys can
identify a speciﬁc application or project, but they cannot validate the individual user who is

2/27/26, 12:18 PM

What Is an API Key? | IBM

5 of 15

https://www.ibm.com/think/topics/api-key

using the application making the calls. This makes API keys a poor choice for enforcing API
access control. API keys only offer project identiﬁcation and project authorization, not user
identiﬁcation or user authorization.
Think of an API key like a password: it is one layer of security, but also a potential point of
failure for a security breach. Like a password, anyone who has access to an API key can use
it. There isn’t a way to verify who is using the key; and keys rarely expire unless they are
speciﬁcally regenerated.
API keys used with web applications are not considered secure over plain hypertext
transfer protocol (HTTP) because they send unencrypted credentials. To be considered
secure, web applications must have a secure sockets layer (SSL) certiﬁcation, otherwise
known as hypertext transfer protocol secure (HTTPS).
Other validation methods for API calls include:

Authentication tokens
Also known as API tokens, authentication tokens add an additional layer of API security
because they can identify a speciﬁc user, not just the application making the request. These
tokens are snippets of code that identify a user to the API that they are requesting data
from. Because they are multiple lines of code rather than a single alphanumeric string, they
provide more information to the API about what person or project is making a request. API
tokens can also be generated with a limited scope, only granting access to speciﬁc
information for a limited period.

OAuth protocol
The OAuth (open authorization) protocol is part of the industry standard method for
authorizing and authenticating calls to an API when used with OpenID Connect (OIDC). The
OAuth protocol is the aspect that grants users access to the requested information and is
used in the broader process of user authentication.
OAuth uses a kind of API token called an access token. Access tokens are issued to users
by the APIs that they’re requesting access to. These tokens, through a series of
communications between an API and the user, grant access to the speciﬁc information that
the user requested without the need to share credentials or other secure information with
the API.

2/27/26, 12:18 PM

What Is an API Key? | IBM

6 of 15

https://www.ibm.com/think/topics/api-key

OpenID Connect is an authentication protocol built on top of OAuth, which enables OAuth
to authenticate users by issuing identity tokens as well as access tokens. These identity
tokens also include information about the speciﬁc account that is making the request,
rather than just the project. OpenID Connect makes slight adjustments to the authorization
flow of OAuth by requiring both an access token and an identity token before granting
access to an API.
API keys can be used with other forms of authentication for API calls, or they can be used
separately. Within an enterprise, an API might use different kinds of authentication and
authorization depending on who is requesting access. Some parts of an organization, such
as developers, might need unrestricted access to an API, while other departments need
more tightly controlled access.

What are the types of API keys?
There are two main types of API keys and they both play a role in authenticating API calls.
Sometimes, they’re even used in tandem.

Public keys
These are keys that provide access to nonsensitive data, or functionalities that don’t
require user authentication. They can be shared openly between developers and other
stakeholders who are working with an API.

Private keys
Private keys are used to access sensitive data and might also grant write access to the key
user. Private API keys can be used with a public key to add an additional layer of security.
Although API keys should not be the only method of authenticating API calls, using public
and private keys in pairs can provide an additional layer of security. When a call is made to
an API, a private key can be used as a kind of digital signature for speciﬁc clients who need
access to speciﬁc functions of an API. Then, the public key can verify the signature and
reconﬁrm that the call to the API is legitimate.

2/27/26, 12:18 PM

What Is an API Key? | IBM

7 of 15

https://www.ibm.com/think/topics/api-key

What are other use cases for API keys?
API keys provide useful functions within an organization beyond simple authentication.
Because these keys help determine API access, they can also be used to keep applications
up and running and provide useful data about how they’re being used.

Block anonymous trafﬁc
API keys are an important aspect of access management, which allows an organization to
control which users can access their APIs. Anonymous trafﬁc to an API may be an indicator
of malicious activity. Using API keys enables an organization to block unauthorized access
to APIs, such as anonymous API calls, which can limit the scope of a potential cyberattack.
Limiting API service in this way also helps prevent APIs from being bombarded with
requests, minimizing the chances of downtime for important applications.

Control the number of calls made to APIs
API keys can be used to restrict an API’s trafﬁc, a measure known as rate limiting. Rate
limiting enables an organization to control how many requests are made to an API by a
client during a speciﬁc period. API access is denied after trafﬁc reaches the deﬁned
threshold.
By only allowing application trafﬁc within the deﬁned parameters, the organization can
optimize API resource and bandwidth usage. These settings can be determined in an
organization’s API documentation.

Monitor API usage trends
Because API keys are unique identiﬁers, an organization can use API keys to track trafﬁc
and calls made to APIs. By using API keys, organizations can trace each call made to an API
back to a speciﬁc application. They can also determine the number of calls being made, the
type of calls, the IP address range of the user, and even if they’re using iOS or Android.
Analyzing usage patterns helps an organization better understand which parts of an
enterprise are accessing speciﬁc endpoints most frequently. Monitoring trafﬁc and ﬁltering
logs is also useful for API security. In the case of a cyberattack, checking the activity on an

2/27/26, 12:18 PM

What Is an API Key? | IBM

8 of 15

https://www.ibm.com/think/topics/api-key

API server against speciﬁc API keys can give an organization greater insight into the attack
and which keys may have been compromised.

How to secure an API key
API keys can help protect APIs, data and networks, but only when they’re used in a secure
way. Many organizations employ these methods to make sure that their API keys are secure
and prevent APIs from becoming vectors for a cyberattack.

Combining multiple authentication methods
API keys are not secure enough to be the only way that API calls are authenticated. They
cannot validate individual users and can be easily compromised. API keys can add an
additional barrier of security to an organization’s API ecosystem when used with another
authentication method such as OAuth, JSON Web Tokens (JWT) or authentication tokens.
It is not uncommon for organizations to use more than one authentication method. For
instance, developers can use API keys internally to provide unrestricted access to APIs
during development, but then use OAuth for outside clients because it provides tokens that
expire and can be set up to only allow access to speciﬁc data.

Secure key storage
When keys are generated, they are often produced in plain text. Just like a password, the
security of that key depends on how and where they are stored. Security professionals
recommend that these keys are stored as hashed values in a database so that they aren’t
vulnerable to theft.
Embedding API keys in the source code or repository also makes them vulnerable to bad
actors—when the application is published, the keys may also be exposed to the public. If
possible, use a secure and encrypted data vault to save generated API keys.

Rotating or replacing keys
API keys don’t expire unless developers set an expiration date, or if the key generator

2/27/26, 12:18 PM

What Is an API Key? | IBM

9 of 15

https://www.ibm.com/think/topics/api-key

revokes access or regenerates the key. If an unauthorized user gets an API key, they could
access sensitive data without anyone within the organization knowing. After all, they’re
using the correct key to get the data they’re requesting.
Rotating and generating new API keys every 90 to 180 days can help keep APIs secure. It’s
also a good idea to delete your API keys that are no longer in use. For an extra layer of
protection, organizations can limit the scope of access for API keys that are shared with
clients by enforcing access rights. These rights give users access to the endpoints that they
need and nothing else. Some organizations automate the generation of new keys to make
sure that they are rotated regularly.

Report

IBM webMethods Hybrid
Integration has been
recognized as a leader in
iPaaS

Read the report to discover why
Forrester ranked IBM a leader,
awarding the highest score in
current offering and what that
means for you in today’s
evolving iPaaS landscape.
Read the report

2/27/26, 12:18 PM

What Is an API Key? | IBM

10 of 15

https://www.ibm.com/think/topics/api-key

Resources

2/27/26, 12:18 PM

What Is an API Key? | IBM

11 of 15

https://www.ibm.com/think/topics/api-key

Report

Explore the trends shaping
iPaaS today

The iPaaS landscape is shifting.
Get the latest market trends in The
Forrester Wave(TM): Integration
Platform as a Service.
Get the report

Client Story

Shifting hybrid integration
into gear with the right
iPaaS
Learn how Bonﬁglioli deployed a
single platform to take on any
integration challenge.
Read the story

Product tour

Interactive Hybrid
Integration demo

Discover how webMethods® Hybrid
Integration uniﬁes AI, APIs, apps
and data with a self-guided, handson tour of three key iPaaS use
cases.

2/27/26, 12:18 PM

What Is an API Key? | IBM

12 of 15

https://www.ibm.com/think/topics/api-key

Start the Demo

Guide

Drive transformation
through iPaaS

Navigate the complexities of iPaaS
deployment with IBM’s expert
guide. Address integration
challenges and empower your
team with actionable strategies.
Get the Guide

Report

176% ROI with IBM
webMethods

See how deploying IBM
webMethods can deliver
measurable ROI for your business,
according to the Forrester TEI
study.
Read the report

Webinar

AI-driven integration:
Shaping the future of
automation

2/27/26, 12:18 PM

What Is an API Key? | IBM

13 of 15

https://www.ibm.com/think/topics/api-key

Hear from IBM experts about how
agentic, AI-powered integration
across the full lifecycle drives
productivity throught the
enterprise.
Watch the webinar

1/2

Related solutions

2/27/26, 12:18 PM

What Is an API Key? | IBM

14 of 15

https://www.ibm.com/think/topics/api-key

IBM webMethods hybrid integration
Enable dynamic, scalable integration
that adapts to evolving business
needs. AI-powered, API-driven
automation

IBM integration software and solutions
Unlock business potential with IBM
integration solutions, which connect
applications and systems to access
critical data quickly and securely.

Discover IBM webMethods hybrid
integration

Explore IBM integration solutions

Cloud Consulting Services
Harness hybrid cloud to its fullest
value in the era of agentic AI
Explore cloud consulting services

2/27/26, 12:18 PM

What Is an API Key? | IBM

15 of 15

https://www.ibm.com/think/topics/api-key

Take the next step
Enable dynamic, scalable integration that adapts to evolving business needs. AIpowered, API-driven automation.

Discover IBM webMethods hybrid integration

Get industry insights

2/27/26, 12:18 PM

