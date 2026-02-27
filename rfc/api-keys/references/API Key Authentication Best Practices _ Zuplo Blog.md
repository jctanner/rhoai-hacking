# API Key Authentication Best Practices _ Zuplo Blog

**Source:** `API Key Authentication Best Practices _ Zuplo Blog.pdf`

---

API Key Authentication Best Practices | Zuplo Blog

1 of 18

https://zuplo.com/blog/api-key-authentication

Back to all articles

Josh Twist

·

December 1, 2022

·

8 min read

Learn the best practices for API Key Management, including api key
authentication, API key security, design tradeoffs, and technical
implementation details.
Many public APIs choose to use API keys as their authentication mechanism,
and with good reason. In this article, weʼll discuss how to approach API key
security for your API, including:
• why you should consider API key security
• design options and tradeoffs
• best practices of API key authentication
• technical details of a sound implementation

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

2 of 18

https://zuplo.com/blog/api-key-authentication

This article is language agnostic and doesn't provide a particular solution for
PHP, Python, TypeScript, C# etc but every language should afford the
capabilities that would allow you to build an appropriate solution.
There is an accompanying video presentation of this content:

I talked about this in more detail in

but in

summary, API keys are a great choice because they are plenty secure, easier
for developers to use vs JWT tokens, are opaque strings that donʼt give away
any clues to your claims structure, and are used by some of the best API-first

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

3 of 18

https://zuplo.com/blog/api-key-authentication

companies in the world like Stripe, Twilio, and SendGrid.
Perhaps the most legitimate complaint against API keys is that they are not
standardized, which is true, but — thanks to programs like GitHubʼs secret
scanning program — some patterns are starting to emerge.
If youʼre building a public API, API-key authentication is much easier for a
developer to configure and learn. They work great in

and, provided you

follow some of the best practices outlined here, are plenty secure.
The main case where I would not advocate for using API keys is for operations
that are on behalf of an individual user. For this, OAuth and JWT is a much
better fit. Examples of APIs that do and should use OAuth are Twitter and
Facebook. However, if youʼre Stripe and the callee of your API is an
‘organizationʼ and not a user, API keys are a great choice. Perhaps the best
example of this is the GitHub API, which uses both: API-keys for organizationlevel interactions and JWT for on-behalf of users.

The best practices for API key authentication are becoming somewhat
recognizable now, but there is a dimension where we still see some variability
in the implementation of API keys: to make the key

or

.

The world of API-key implementations is divided into two groups. The first will
show you your API key only once. You'll need to copy it and save it somewhere
safe before leaving the console. This is

. Typically the keys are

unrecoverable because they are not actually stored in the key database, only a
hash of the key is stored in the database. This means, if lost, the keys can
genuinely never be recovered. Of course, in the case of a loss you can usually

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

4 of 18

https://zuplo.com/blog/api-key-authentication

regenerate a new key and view it once.
The other group allows you to go back to your developer portal and retrieve
your key at any time. These keys are typically stored encrypted in the
database. Meaning if the database is stolen, the thief would also need the
encryption codes to access the API keys.
The tradeoffs here are tricky, and there are two schools of thought
���

is better because itʼs more secure. The keys are stored via a
one-way encryption process so they can never be retrieved, or stolen
from the database in a worse case scenario.

���

offers good-enough security with some advantages, and itʼs
easier to use. The keys are stored encrypted via reversible encryption.
One potential security advantage is that users are less likely to feel
pressured to quickly store the key somewhere to avoid losing it. A person
that follows best practices will use a vault or service like 1password.
However, some users will take the convenient path and paste it into a .txt
file for a few minutes thinking, “Iʼll delete that later."

So what are some examples of APIs that support recoverable vs.
unrecoverable today??
Stripe, Amazon AWS
Twilio, AirTable, RapidAPI
There is some correlation between services that protect sensitive information
and services seem more likely to use
sensitive choose

, while services that are less

for ease of use and good-enough security.

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

5 of 18

The choice is yours. Personally, I lean a little toward

https://zuplo.com/blog/api-key-authentication

because I

know that I personally have made the mistake of quickly pasting a newly
generated

key into notepad and forgetting about it. You may

come to a different conclusion for your own API key authentication.

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

6 of 18

https://zuplo.com/blog/api-key-authentication

The bit of API key authentication advice youʼve been waiting for… the best
practices of API key auth based on the patterns observed in the API world and
.

our experience building our own

Depending on your choice of
different path. For

vs.

youʼll need to take a

keys, itʼs best to store them as a hash, probably

using sha256 and ensure that they are stored as primary key (this will help
avoid hash collisions, unlikely but possible so you should build in a retry on
create and insert).
For

, youʼll need to use encryption so that the values can be read

from the database to show to the user at a later date. You have a few choices
here, like storing the keys in a secure vault, or using encryption
programmatically to store in a standard database and manage the keys
yourself.

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

7 of 18

https://zuplo.com/blog/api-key-authentication

Itʼs critical that you allow your users to roll their API keys in case they
accidentally expose it, or just have a practice of periodically changing them
out. Itʼs important that this ‘rollʼ function either allows for multiple keys to exist
at the same time or allows the setting of an expiry period on the previous key,
otherwise rolling the key will cause downtime for any consumers that didnʼt
get the chance to plug-in the new key before the last one expired. Hereʼs
Stripeʼs roll dialog:

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

8 of 18

https://zuplo.com/blog/api-key-authentication

In Zuplo, we allow folks to have multiple keys so they can temporarily add
another key and delete the old one as soon as theyʼre done with the transition.

Itʼs important to show developers when the key was created so they can
compare the date to any potential incidents. This is especially important if you
support multiple keys so that users can differentiate between old and new.

Since checking the API key will be on the critical path of every API call, you
want to minimize latency. This is one of the reasons that youʼll want to add a
checksum to your API key. Hereʼs an example API key from Zuplo:

The last section

is a checksum that we can use to verify in the request

pipeline whether this even looks like a valid key. If not, we can simply reject
the request and avoid putting load on the API key store.

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

9 of 18

https://zuplo.com/blog/api-key-authentication

One of the reason we have the unusual beginning of the key
we could participate in programs like

" is so that
. This allows us

to create a regular expression that allows GitHub to inform us if an API key is
accidentally checked into a repo. Then we can automatically revoke the key
and inform its owner of the event. We also use the checksum to double-check
that itʼs one of our keys before locating the service and owner.
At Zuplo, we participate in the GitHub secret scanning program so that we can
offer these services to any customer using our API-key policy.
�Aside: Yes, the example key above triggered our secret scanning when I

checked this article into GitHub and we got notified about a token leak

)

To reduce the latency on every API request, you might consider using an inmemory cache to store keys (and any metadata read from the API Key Store).
If you have a globally distributed system, youʼll want multiple caches, one in
each location. Since Zuplo runs at the edge, we use a high-performance cache
in every data center. To increase security it's important to consider only
caching the one-way hashed version of the API-key (taking care to avoid
hash-collisions by doing a pre-hash collision check at the point of keycreation, using the same hash algorithm).
Youʼll need to choose an appropriate TTL (time-to-live) for your cache entries
which has some tradeoffs. The longer the cache, the faster your average
response time will be and less load will be placed on your API Key store however, it will also take longer for any revocations or changes to key
metadata to work.
We recommend just a couple of minutes maximum; thatʼs usually plenty to

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

10 of 18

https://zuplo.com/blog/api-key-authentication

keep your latency low, a manageable load on your API Key Store, and be able
to revoke keys quickly.
If this is important to you, you might want to design a way to actively flush a
key from your cache.

Today, everybody has a high-quality camera in their pocket. Donʼt show an API
key on-screen unless explicitly requested. Avoid the need to show keys at all
by providing a copy button. Hereʼs the supabase console, which almost gets
full marks, but would be even better if it provided a copy option
needing me to reveal the key visually.

Sometimes itʼs the little things in life; for example, try double-clicking on
below to select it. Then try

.

key-1�
key-2�
Note how much easier it is to select the API key in

?

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

11 of 18

https://zuplo.com/blog/api-key-authentication

A number of services are increasingly doing this to help their customers, but
mostly to help their support teams. For example, in Stripe they have a
convention as follows:
•

- Secret Key, Live version

•

- Publishable Key, Test version

This not only supports GitHub secret key scanning above, but it can also be
invaluable to your support team when they can easily check if the customer is
using the right key in the right place. Your SDK can even enforce this to
prevent confusion.
The downside to key labeling is that if the key is found without context by a
malicious user - they can discover which services to attack. This is one
advantage of using a managed API key service that dissociates the key from
any specific API. GitHub have a great article .

Stacking all of that together, hereʼs a flow chart showing the canonical
implementation of the API key check using all these practices above.

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

12 of 18

https://zuplo.com/blog/api-key-authentication

We touched on key rolling earlier, but let's dig deeper into rotation strategies
that keep your API consumers happy while maintaining strong security
posture. Getting rotation right is one of the most impactful things you can do
for the long-term health of your API platform.

The simplest rotation pattern is to issue a new key while keeping the old one
active for a defined grace period. When a consumer triggers a rotation, the
system generates a fresh key immediately but continues to honor the outgoing
key for a window — typically 24 to 72 hours. During this window the API can
return a custom header (for example

) on every

response authenticated with the old key, giving automated clients a machinereadable signal to swap credentials. Once the grace period elapses, the old
key is permanently revoked. This pattern strikes a balance between urgency
and practicality: it gives teams enough time to propagate the new key through
CI/CD pipelines, environment variables, and secret managers without causing
an outage.

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

13 of 18

https://zuplo.com/blog/api-key-authentication

A more flexible approach is to let each consumer hold two or more active keys
at the same time. Instead of replacing one key with another, the consumer
creates a second key, deploys it wherever needed, verifies traffic is flowing on
the new key, and then deletes the old one at their own pace. This is the model
Zuplo uses: consumers can create additional keys from the developer portal,
test them in staging, and retire previous keys once the rollover is confirmed.
The advantage is that the consumer — not the platform — controls the timing,
which eliminates the risk of an expiring grace period catching someone off
guard during a holiday weekend or a deploy freeze. It also simplifies the
server-side logic because every stored key is either valid or deleted; there is
no intermediate "expiring soon" state to track.

For organizations that manage dozens or hundreds of API keys, manual
rotation does not scale. A self-service developer portal can expose rotation as
a first-class workflow: consumers log in, click

, receive the new key, and

the portal handles the grace period or multi-key transition behind the scenes.
Better yet, the portal can surface rotation reminders based on key age, flag
keys older than a policy threshold (say 90 days), and even enforce mandatory
rotation via expiration dates set at creation time. Combining this with webhook
notifications — so that a consumer's infrastructure can be alerted
programmatically when a key is about to expire — closes the loop entirely and
makes rotation a non-event rather than a fire drill.
When you pair automated rotation with an API management layer like Zuplo,
you get audit logs for every rotation event, the ability to instantly revoke
compromised keys across all edge locations, and a portal experience that your
consumers actually enjoy using. The goal is to make rotation so painless that
teams do it proactively rather than only in response to a security incident.

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

14 of 18

https://zuplo.com/blog/api-key-authentication

If you want to go deeper on API key authentication and explore how it
compares to other approaches, these resources are a great next step:
— A hands-on guide covering

•

the end-to-end implementation of API key auth, including code examples
and integration patterns for common frameworks.
— A side-by-side

•

comparison of API keys, OAuth 2.0, JWT, Basic Auth, and more, helping
you pick the right method for your use case.

API keys are a great approach if you want to maximize the developer
experience of those using your API, but there are quite a few things to think
about when it comes to API key security. An alternative to building this yourself
is to use an API Management product with a gateway that does all the work for
you and includes a self-serve developer portal. Examples include Apigee,
Kong, and — of course — Zuplo.

Before founding Zuplo, Josh led Product for Stripeʼs Payment Methods team
(responsible for the majority of Stripes payment APIs) and worked at Facebook
and Microsoft, where he founded a number of services, including Azure API
Management.

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

15 of 18

https://zuplo.com/blog/api-key-authentication

Updated December 4 2022 to update recommended hashing algo to sha256
based on community feedback.

Continue reading from the Zuplo blog.

A three-part series on API monetization:

Get clear tiers, a comparison table, and

what to count, how to structure plans, and

reasoning so you can price your API with

how to decide what to charge. Start here

confidence and move on to

for the full picture.

implementation faster.

4 min read

3 min read

Scale your APIs with
confidence.
Start for free or book a demo with our team.

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

16 of 18

https://zuplo.com/blog/api-key-authentication

Book a demo

Start for Free

Get Updates From Zuplo
Subscribe to our newsletter to receive tips, tricks and product updates right to
your inbox.
Your Email

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

17 of 18

https://zuplo.com/blog/api-key-authentication

Subscribe

2/27/26, 12:42 PM

API Key Authentication Best Practices | Zuplo Blog

18 of 18

Privacy Policy

Security Policies

https://zuplo.com/blog/api-key-authentication

Terms of Service

Trust & Compliance

2/27/26, 12:42 PM

