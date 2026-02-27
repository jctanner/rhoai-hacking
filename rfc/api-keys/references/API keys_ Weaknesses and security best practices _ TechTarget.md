# API keys_ Weaknesses and security best practices _ TechTarget

**Source:** `API keys_ Weaknesses and security best practices _ TechTarget.pdf`

---

API keys: Weaknesses and security best practices | TechTarget

1 of 5

https://www.techtarget.com/searchsecurity/tip/API-keys-We...

TechTarget and Informa Tech’s Digital Businesses Combine.

9

g

Search

Security

Home > Application and platform security

TIP

5 OF 5

TAMPATRA - STOCK.ADOBE.COM

A A Part of: How to start securing APIs

API keys: Weaknesses and security best
practices
API keys are not a replacement for API security. They only offer a ﬁrst step in
authentication -- and they require additional security measures to keep them
protected.

By Ravi Das, ML Tech Inc.

Published: 20 Jul 2023

With the popularity of APIs comes the question of their security. If APIs leak data
or can be an entry point for an attack, what good is the security strategy of the
applications they connect to?
Attackers
constantly looking for potential weakness in APIs to target -- with
Short onare
time?
Engage
with our
AI feature
forAPI
a quick
one
potential
avenue
being
keys.
overview and key insights.

Let's lookRead
at what
API keys are, their security vulnerabilities and how to secure
AI Insights
them.

5 of 5

AA

+

2/27/26, 12:41 PM

API keys: Weaknesses and security best practices | TechTarget

2 of 5

https://www.techtarget.com/searchsecurity/tip/API-keys-We...

What is an API key?
An API key is a unique code that identiﬁes and veriﬁes that applications or end
users calling an API are authorized to request access to that API -- thus providing
a ﬁrst level of authentication. Depending on the type of API key, it can limit
access to only authorized users, identify usage patterns, rate-limit trafﬁc and
block or throttle calls made to an API.
API keys are the ﬁrst step in the authentication process. They identify whether
calls submitted to the API are valid, conﬁrming the identities of requestors and
ensuring they have the permission to request access. API keys provide limited
authentication capabilities, however, and shouldn't be used as the sole
authentication method.

API key security weaknesses
It is important to note that API keys have their own set of vulnerabilities, which
could be potentially exploited. API key weaknesses include the following:
• API keys are rarely initially encrypted. API keys are often generated and
stored in plaintext, making it possible for malicious actors to steal them if no
further encryption occurs.
• Secure storage is lacking. Once an end user receives an API key, they must
securely store it. This may include using a secrets manager, local device
storage or -- worse yet -- writing it down on a Post-it note at their workstation.
• Third party-created API keys aren't secure by default. Organizations can
use third-party services to create, issue and distribute API keys. Third parties,
however, often do not provide security features, leaving API key protection
and encryption to software developers.
• API keys lack granular controls. API keys do not provide granular levels of
control.
End users who have more detailed access rights and permissions for
Short
on time?
Engage
with
AI feature
fornot
a quick
an API,
forour
example,
are
recognized by an API key.
overview and key insights.

How to Read
secure
API keys
AI Insights
Despite their weaknesses, API keys are necessary components in API use. They,
5 of 5

AA

+

2/27/26, 12:41 PM

API keys: Weaknesses and security best practices | TechTarget

3 of 5

https://www.techtarget.com/searchsecurity/tip/API-keys-We...

therefore, require careful management and security measures. To ensure API key
security, adhere to the following best practices:
• Don't store API keys within the code or the application's source tree. To
streamline the overall security of a web application, software developers
sometimes embed API keys into the code itself. If the API's or application's
source code gets posted to a public repository, such as GitHub, the API key is
publicly exposed.
• Securely store API keys. Create an environment variable to store API keys in.
Storing an API key as an environment variable keeps it from being revealed if
the source code gets uploaded to a public repository. Developers can also
store API keys in secure ﬁles outside the application's source tree or use a
secrets management service.
• Rotate API keys. API keys don't change or expire until their owner
purposefully deletes them. Constantly rotate API keys to reduce potential
vulnerabilities if exposed. Create a security policy that requires changing API
keys every 30, 60 or 90 days. Many compliance regulations and frameworks,
such as ISO 27001, require regular key rotation.
• Delete unused API keys. Alongside rotating keys, delete unused or unneeded
API keys to prevent malicious actors from using them in an attack.

m Next Steps
How to build an API security strategy

Dig Deeper on Application and platform security
mShort
on time?
Engage with our AI feature for a quick
overview and key insights.

Read AI Insights
About Us

5 of 5
Deﬁnitions

AA

Corporate Site

+

2/27/26, 12:41 PM

API keys: Weaknesses and security best practices | TechTarget

4 of 5

https://www.techtarget.com/searchsecurity/tip/API-keys-We...

EditorialCISO's
Ethics Policy
Guides
guide to nonhuman

Latest
TechTarget
identity
security

Meet The Editors

resources

Contact Us

2

Events
How network efﬁciency
advances ESG goals

Partner with Us

NETWORKING

Videos

Top web app Contributors
security
Search
Networking
vulnerabilities and how to
Advertisers
Reprints
mitigate them

By: Dave Shackleford

A
Media Kit

E-Products

By: Sharon Shea
From SDN to green electricity, network
optimization plays a critical role in helping

CIO
Photo Stories

enterprises reduce emissions, cut costs and

When to consider
Certiﬁed AWS Security
...
ENTERPRISE DESKTOP ©2025 TechTarget, Inc. d/b/a Informa TechTarget. All Rights Reserved.
Kubernetes security posture
Specialist Exam Dumps and
management
Braindumps
CLOUD COMPUTING

2

Privacy Policy

How to build a private 5G
network architecture

Do Not Sell or Share My Personal Information
COMPUTER WEEKLY

ABy:
private
5G network
can provide
Cameron
McKenzie
organizations with a powerful new option for

By: Dave Shackleford

their wireless environments. Here are the

This websitemajor
is owned
and operated by Informa
...
TechTarget, part of a global network that informs,
in�uences and connects the world’s technology buyers
and sellers. All copyright resides with them. Informa PLC’s
registered o�ce is 5 Howick Place, London SW1P 1WG.
Registered in England and Wales. TechTarget, Inc.’s
registered o�ce is 275 Grove St. Newton, MA 02466.

Short on time?
Engage with our AI feature for a quick
overview and key insights.

Read AI Insights
5 of 5

AA

+

2/27/26, 12:41 PM

API keys: Weaknesses and security best practices | TechTarget

5 of 5

https://www.techtarget.com/searchsecurity/tip/API-keys-We...

Short on time?
Engage with our AI feature for a quick
overview and key insights.

Read AI Insights
5 of 5

AA

+

2/27/26, 12:41 PM

