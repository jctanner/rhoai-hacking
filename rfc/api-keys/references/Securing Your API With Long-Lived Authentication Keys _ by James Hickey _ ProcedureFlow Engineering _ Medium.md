# Securing Your API With Long-Lived Authentication Keys _ by James Hickey _ ProcedureFlow Engineering _ Medium

**Source:** `Securing Your API With Long-Lived Authentication Keys _ by James Hickey _ ProcedureFlow Engineering _ Medium.pdf`

---

Securing Your API With Long-Lived Authentication Keys | b...

1 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

Sign up

Open in app

Sign in

Search

ProcedureFlow Eng… · Follow publication

Securing Your API With Long-Lived
Authentication Keys
9 min read · Dec 9, 2021
James Hickey

Follow

Listen

Share

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

2 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

Photo by Old Money on Unsplash

There comes a time in the life of a multi-tenant SAAS company when its larger
customers need the automation and power of an API. The multitude of reasons
includes scaling user provisioning, integrating with other products, facilitating
advanced reporting and more.
If you’re in this position, one of the most important areas you need to think about
carefully is authentication. There are many different factors to consider:
• Is your API responding to server-to-server requests? Or will you need to support
other types of clients like web applications, mobile, etc.?
• Do you need long-lived or short-lived tokens?
• What about OAuth? Does that make sense right now?
• Should you jump on the JWT bandwagon?
• How will your customers configure authentication? How does your choice on
this affect their user and developer experience?
At ProcedureFlow, we’ve spent a fair amount of time researching how the best APIs
out there have implemented API authentication: Stripe, Slack, GitHub, Twilio and
others. We want to make sure our API is really easy to use, gives superpowers to our
customers and is rock-solid secure.

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

3 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

Needless to say, this one area can get overwhelming quickly! To figure out what
works best for your company’s needs, you have to start by thinking about the
requirements of your API.

Minimum Viable API
If you’re a startup like us, then you won’t have the time and resources to build a
complete API that will integrate with “all the things” immediately. You have to
identify what API products make sense as a priority. Then, you can build your
foundational API infrastructure, that first API product and iterate based on your
customer’s feedback.

Use An Iterative Approach To API Product Development

For example, we decided to build a SCIM API first.
Authentication is one of the areas where SCIM is flexible — so we can use the
mechanism that works best for our custom API and use it for SCIM too

.

Based on our requirements, there were a few smaller decisions we had to make
first:
• We’d be focusing on server-to-server APIs for the first few API products so this
influences what kind of authentication mechanism makes sense for us.
• We wanted to retain the ability to implement other authentication mechanisms
in the future.

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

4 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

• TTFC (Time-to-first-call) is considered one of the most important API metrics.
Configuring authentication should be as simple as possible for our customers to
facilitate a low TTFC.
• How do well-designed APIs like Stripe, Twilio, Slack, Twitter and GitHub do
things? What can we learn or implement ourselves?

The Big Decision
Your overall decision will be based on a balance between valuing ease of use for
your customers and enforcing solid security.

At ProcedureFlow, we decided to use a long-lived API key that our customers can
generate from within our product. This is similar to how Stripe and Twitter V2 do
API authentication. We generate both a client_id and a client_secret (more on
these later

).

Some of the qualities and behaviors of using a long-lived API key includes:
• API keys can be tied to individual tenants or specific users like Slack does.
• Can be scoped to specific products or features like Stripe does, with read-only or
read/write access per feature.
• Also inspired by Stripe’s approach, customers can have a user-friendly UI to
generate new keys, revoke them immediately or revoke them with a grace
period.
• API secrets should be hidden on the UI, except when first generated. This is
mainly inspired by Stripe’s approach and is a best practice. You don’t want those
secrets getting leaked!

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

5 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

Another thing we chose to do is prefix our key values. This makes them easier to
identify and makes the type of key/token more explicit. This technique is inspired by
Stripe and GitHub who have recently switched to this format too.

Deep-Dive: Long-lived API Token Authentication
Let’s deep-dive into some of the more detailed decisions we had to make and why
they might make sense for you too.
The Anatomy Of An API Key

Services like Stripe, Slack and Twilio use two values for their long-lived API keys.
Slack, for example, calls these the Client Id and Client Secret. Stripe calls them the
Publishable and Secret Keys. Other vendors have used other terms like “Access Key”
and “Access Key Secret”.
We have chosen to call ours client_id and client_secret . This helps to set us up for
future use-cases around delegated authorization (e.g. OAuth) and is consistent with
the standard OAuth naming terminology. Also, each token can be used by a specific
client — web, mobile, server, etc. so client_id seems more semantically accurate to
us than other options like app_id , access_key or public_key .
Public Identifier

The client_id is used to identify the user or owner of the API key.
This is helpful when you may have multiple types of clients that use your API keys —
web applications, mobile applications, back-end systems, etc. It also helps when
tokens can be assigned to specific users in your system. You can use the client_id
to peg rate limits per client, logging metrics that are tied to the identifier, etc.
Secret Token

The client_secret is a random cryptographically generated token.
When thinking about the technical aspects of implementing API key authentication,
one of the most important issues to make sure you consider is that API secrets are just
like passwords.
It is inappropriate to store these tokens as plain-text for the same reasons you

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

6 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

wouldn’t store passwords as plain-text. Even worse, API secrets are present for every
HTTP request, so you want to make sure to protect them well.
Like passwords, API secrets ought to be hashed when stored in a database or some
other tool like a cache. If an attacker ever managed to get access to your database,
then they could start impersonating your customers by using plain-text API secrets.

Other Security Considerations

One of the reasons you may not want to only use a “secret” value, even if hashed, is
that it becomes both the secret and the lookup value.
When an API request comes into your system, and if all you have is the secret value,
then you would have to hash the secret and check if it exists in your database. If it
does exist, then you know who owns the API key and therefore who’s allowed to
perform the API request.
Get James Hickey’s stories in your inbox
Join Medium for free to get updates from this writer.
Enter your email

Subscribe

Your SQL query would look similar to the following:

select * from api_auth_keys where secret_hash = $secret_hash

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

7 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

One potential problem with this approach is that it could be susceptible to timing
attacks. While in practice there are multiple ways to mitigate these kinds of security
vulnerabilities, the issue simply disappears if you use a different value as the
identifier for the lookup — assuming you compare the hashes in memory by using a
safe constant time comparison function.
Bearer Token

At the moment, we are only using API keys for server-to-server communication.
This means our customer’s servers will need to communicate directly with our API
as opposed to via some delegated third-party system (which would require
something like OAuth).
Because of this, we can combine both the client_id and client_secret and display
that to our users as one value. This helps with ease of use and user experience, yet
allows us to still gain the benefits of using a split token approach.

Bearer Token Using A Split Token

Best Hashing Algorithm?

PBKDF2 is one of the most popular and reliable hashing algorithms today. It’s a great
algorithm for password hashing because it’s slow and cryptographically sound. You
don’t want attackers to brute-force guess passwords quickly, so PBKFD2 makes that
process much slower and therefore harder to attack.
That’s great — but one of the hallmarks of any high-quality API is having a short
response time. This affects developer experience, can cause more load on servers
(which means paying money for more servers), can affect contractual issues due to
not meeting certain SLAs and can affect the overall perception of your products and

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

8 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

company.
Is PBKFD2 the best option then?
SHA256 is another common hashing algorithm that is solid — but it’s quick to
compute hashes. But, is there a way to use SHA256 so that hashes are still computed
quickly but have high entropy so that attackers can’t brute force API tokens within a
reasonable amount of time?
Two core problems with user-supplied passwords are that they are generally short
and predictable. So, what you need are API tokens that are long and random!

This is what we did — we opted to generate very long random values for our
client_secret — and we hash this using SHA256.

The code for this might look like the following:

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

9 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

Storing API Tokens

You already know that you should store the hash of an API secret. However, you
might also want to store the last few digits of your API secret.
Like Stripe, you should only show the raw API secret immediately after it is created.
From that point forward, show the last few digits of the token on the UI. This helps
customers identify which key they want to revoke, change scopes for, etc.

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

10 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

We opted to follow suit with Stripe and keep 4 digits from our non-hashed API
secrets.

Mock API Key Schema

The client_id column would also benefit from using an index so that your database
lookups performed during incoming API request authentication are fast

.

API Token Pipeline

Whatever technology stack you are using, you’ll want to verify any incoming API
tokens early in the lifetime of an HTTP request.
While .NET can sometimes get a bad rap, we use it for reasons like being one of the
most secure web development platforms out there, having most of the basic tools
you’ll need for web development out of the box and having a robust type system. We
might write more on that topic another time

.

.NET’s MVC framework has a flexible middleware system that’s easy to hook into.
We use the built-in middleware (a.k.a. “filters”) to process API tokens early in the
HTTP pipeline.
Here’s the flow of how we process bearer tokens when authenticating against our
API:
1. A client issues an HTTP request with an API token as a bearer token.

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

11 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

2. We intercept the bearer token early in the HTTP pipeline.
3. We split the token into client_id and client_secret .
4. Using client_id we check if a row exists in the database.
5. We hash the user input client_secret and use a constant-time comparison
function to verify that it matches the stored hash.
6. We create a “session” object that only exists in memory for the lifetime of the
HTTP request.
7. Other events occur downstream that use the API key—like rate limiting.

API authentication process

The core of our API authentication middleware looks roughly like the following:

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

12 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

Conclusion
There’s much more you’ll have to consider when implementing API authentication
and API tokens in particular:
• Resource/feature scopes
• UI elements

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

13 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

• Logging
• Tracking token usage for troubleshooting
• Database indexing
• Rate limiting
• Etc.
For example, we had to extend our existing Redis-based rate-limiting to support
limiting based on API keys. Originally, limit data was not being made available to the
caller. We had to modify our LUA scripts to return rate limit data and then assign
values to the appropriate HTTP headers.
We do our best at working fast and smart so that we can deliver value to our
customers quickly. But we also care about the details, especially when decisions we
make now can have an impact on the future of our products. For example, choosing
to prefix our API tokens may seem insignificant at face value, but it affects user
experience, the overall security of our API, and is not trivial to change in the future.
If you like solving problems like the ones we’ve discussed and you’re interested in
the possibility of joining our team then check out our open positions!
Software Development

API

Authentication

Agile

Iteration

Follow

Published in ProcedureFlow Engineering
9 followers · Last published Apr 1, 2022
ProcedureFlow is a SaaS company based in Canada. Our mission is to democratize business procedures and
help turn employees into experts faster. If you are interested in finding out more about our team, visit

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

14 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

procedureflow.com

Follow

Written by James Hickey
13 followers · 1 following

Responses (1)
Write a response
What are your thoughts?

Ayyappa J
Jul 23, 2024

How actually the client secret helps here? We can just have clientId alone as api key right as if api key is
exposed, secret also has high changes to get exposed.
Reply

More from James Hickey and ProcedureFlow Engineering

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

15 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

In ProcedureFlow Engineering by James Hickey

How We Do Software Engineering At ProcedureFlow
We are a SaaS startup based out of Canada with a team of 5 fully remote software engineers.
We’re growing our team this year - we’re…
Apr 1, 2022

See all from James Hickey

See all from ProcedureFlow Engineering

Recommended from Medium

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

16 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

Jacob Bennett

The 5 paid subscriptions I actually use in 2026 as a Staff Software
Engineer
Tools I use that are (usually) cheaper than Netflix
Jan 18

3.4K

84

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

17 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

In AI Software Engineer by Joe Njenga

Anthropic Just Released Claude Code Course (And I Earned My
Certificate)
Anthropic just launched their Claude Code in Action course, and I’ve just passed — how about
you?
Jan 21

3.1K

42

In Stackademic by Umesh Kumar Yadav

Token, Session, Cookie, JWT, OAuth2 —I can’t tell the difference!
Recently, I’ve noticed that some people easily confuse the concepts of Token, Session, Cookie,
JWT, and OAuth2.
Dec 10, 2025

197

5

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

18 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

In Generative AI by Adham Khaled

Stanford Just Killed Prompt Engineering With 8 Words (And I Can’t
Believe It Worked)
ChatGPT keeps giving you the same boring response? This new technique unlocks 2× more
creativity from ANY AI model — no training required…
Oct 19, 2025

24K

640

2/27/26, 1:34 PM

Securing Your API With Long-Lived Authentication Keys | b...

19 of 19

https://medium.com/procedureﬂow-engineering/building-ap...

In Women in Technology by Alina Kovtun

Stop Memorizing Design Patterns: Use This Decision Tree Instead
Choose design patterns based on pain points: apply the right pattern with minimal overengineering in any OO language.
Jan 29

4.8K

42

In Write A Catalyst by Dr. Patricia Schmidt

As a Neuroscientist, I Quit These 5 Morning Habits That Destroy Your
Brain
Most people do #1 within 10 minutes of waking (and it sabotages your entire day)
Jan 14

32K

603

See more recommendations

2/27/26, 1:34 PM

