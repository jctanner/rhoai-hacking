# What makes a good API key system_ _ by Ted Spence _ tedspence.com

**Source:** `What makes a good API key system_ _ by Ted Spence _ tedspence.com.pdf`

---

What makes a good API key system? | by Ted Spence | teds...

1 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

Sign up

Open in app

Sign in

Search

tedspence.com · Follow publication

What makes a good API key system?
8 min read · Jul 14, 2023
Ted Spence

Follow

Listen

Share

The complex usability challenges of authentication for unattended API calls
The days of storing usernames and passwords in a database have been over for a long
time. If you have a website, your users should log on using either OAuth or SAML. But
how can we help developers use our API in a secure and convenient manner?
As it turns out, API keys are a usability challenge. It may not be immediately obvious how
to make them work correctly, and there are subtle risks involved in handling API keys.
Let’s unlock the complexities.

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

2 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

A robust key management system should support multiple active keys at once (Pexels on FreeRangeStock)

API keys are for unattended use

If you’re building a web application, you should be using OAuth or SAML. These
technologies are designed for interactive applications, and they will issue a token which
authenticates a user. When there is a problem with a user’s credentials, you redirect the
web browser back to their OAuth or SAML provider. After they authenticate, they will
redirect right back to your application, and they can continue where they left off.
But what if your client is an unattended computer? Since OAuth tokens are generally
expected to be valid for only a few hours at a time, and since an unattended computer
can’t launch a web browser to redirect to an authentication provider, this means
unattended programs can only make API calls for a short while before needing an
entirely new token.
Fortunately, the OAuth system created refresh tokens. With a refresh token, a client can
renew their token without launching a web browser.

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

3 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

4 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

Problem solved, right? This is a bit of extra work for the client and server developers, but
the result is good security. Unfortunately you may encounter a few problems with OAuth
and refresh tokens:
• Some developers don’t implement refresh tokens correctly. If a client tries to refresh
their token and fails, it doesn’t matter who’s to blame — the client still can’t use your
API.
• Some OAuth systems don’t make it easy to generate multiple tokens, or they

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

5 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

invalidate old tokens when a new token is created or refreshed. This means if you
have multiple computers using the same OAuth token, they will lock each other out.
• Some systems make it hard to generate multiple tokens on demand. Security best
practices call for least privilege — that means you may want to have one token with
read-only access and another token with write-only access.
So what happens if we try to write our own API key system?
A simple implementation for API keys

As an API developer, I want the following functionality from an API key:
• I should be able to create new API keys on demand.
• An API key is a secret that is only viewable once — it can never be regenerated.
• It must be impractical or impossible for an attacker to brute force hack the secret
component of my API key.
• Each API key can have different security roles associated with it.
• I can revoke individual API keys and set expiration dates.
• Information about when an API key was most recently used.
• The API key system should be able to identify trivial mistakes made by a developer
when they attempt to copy and paste an API key incorrectly.
A good discussion on the usability of API keys is this article from the Github blog in 2021.
They consider lots of valid usability issues like:
• Keys should have prefixes, so you can identify them.
• Keys should have checksums, so you can see if you failed to copy the entire key.
• Keys shouldn’t include characters that prevent copying and pasting like hyphens, so a
developer can double click on it and copy it correctly.
With these usability issues documented, let’s discuss how secure an API key can be.
The algorithm behind an API key system

For this discussion, we will consider a relatively well studied and understood algorithm

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

6 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

that works as follows:
• Create a secret of X bits length using random entropy.
• Create a salt of Y bits length using random entropy.
• Hash the secret and salt together using a well-known and valid algorithm such as
SHA256, SHA512, BCrypt, or Argon2.
• Return the secret to the customer — that will be their API key.
• Store the salt and hash in our database, along with the privilege levels of this key, its
expiration date, and its revocation status.
You’ll notice that this is very similar to how people used to store usernames and
passwords. The big difference is that we don’t allow customers to select their passwords
here — if we actually allowed customers to choose their own API key, they won’t be
guaranteed to choose one with enough entropy!
Get Ted Spence’s stories in your inbox
Join Medium for free to get updates from this writer.
Enter your email

Subscribe
Remember me for faster sign in

So the next question is, how much entropy do we need?
How much would it cost to hack this API key?

To test the security of our algorithm, we need to estimate a few risks:
• What is the risk of someone brute force guessing a client secret from scratch?
• If someone has managed to hack into our database to steal the hash and salt, what is
the risk of an attacker computing the secret from these two values?
• Is there a specific vulnerability within my hashing algorithm or entropy generator

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

7 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

that allows it to be cracked faster than brute force?
The way to prevent the first risk is to audit your API usage. If you choose 64 bits of
entropy for your client secret, a brute force attack with the attacker randomly guessing
API keys would require 2⁶³ API calls on average before it would be expected to have a 50%
chance of succeeding.
This is unlikely to happen — if a single API call took one millisecond, this kind of brute
force attack would take 292 million years. My hope is that you’d notice that your audit logs
had grown in size before then.
On the other hand, data breaches and data leaks happen all the time. If an attacker
somehow stole a copy of your API key table from your database, how vulnerable are you?
Estimating the cost of an attack on known salt and hash

If we implement this algorithm correctly, an attacker who steals your API key database
tables would have a salt and a hash. They would then attempt to generate a client secret
such that a computed hash of (secret+salt) matches the stolen hash.
How difficult is this? There’s a fantastic hacking tool called hashcat that demonstrates the
best available techniques to brute force an algorithm. A good place to start is to consider
a hashcat computer build article written by netmux in 2018.
In this article, the author built a computer for $5,000 and published its speed using
hashcat. Let’s see how long it would take this computer to brute force guess our 64-bit
client secret using three hashing algorithms that are generally considered secure —
SHA256, SHA512, and BCrypt:
• For SHA256, we can generate 9,392.1 million SHA256 hashes per second on this
computer. At a rate of 9 billion hashes per second, it would take a total of 11,366 CPU
days on this computer to have a 50% chance of cracking a single API key.
• Although this seems like a lot of CPU days, we can imagine someone who has access
to a computer four times more powerful than the one built in 2018 by netmux. With a
cluster of 100 instances of these computers, a single API key could be cracked within
a month.
So SHA256 is pretty secure but not impossible to break. SHA512 is about three times
more complex, so an attacker would need about three times the number of computers to

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

8 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

attack it at a similar speed.
On the other hand, BCrypt is punishingly slow compared to SHA256 and SHA512. The
computer that generates 9 billion SHA256 hashes per second can only generate forty three
thousand BCrypt hashes per second. This means that a password stored in BCrypt would
take over two billion CPU days using the netmux 2018 machine in question.
Should we just always use BCrypt then?

I do recommend using BCrypt — however, there’s a challenge. Since BCrypt is slow to
execute, it can take a non-negligible length of time to validate an API key using BCrypt. I
recommend that you cache authentication successes in an appropriate manner for your
system. Ideally, your software will do the following:
• Validate an API key when it is first used by a particular IP address. This means that
the first API call from a new client will take a few extra milliseconds since the API key
must be hashed.
• Allow that IP address to continue using that API key for a short period of time, say,
two minutes. During this time, we presume that as long as that IP address continues
to use the same API key, it will remain valid.
• If the system continues to use the same API key, we re-confirm that the API key is
indeed valid and not revoked. This test should happen in the background so that
individual API calls remain fast.
• If the background validation succeeds, we reset the clock and allow the client to
continue using the API key for another two minutes.
• However, if the validation fails — perhaps because the API key expired or was revoked
— we reject subsequent API calls using this key with 401 unauthorized.
An implementation of this algorithm

I’ve published a DotNet implementation of this BCrypt API key generation algorithm on
NuGet and GitHub. With my library, you can generate keys and validate them using
whatever key generation algorithm your company selects as appropriate.
I’ve put a bunch of usability features in this toolkit:
• You can generate any number of API keys on demand.

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

9 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

• Your own software handles the storage and determines the permission levels of keys.
• You can define your own revocation and expiration policies for API keys.
• You can define multiple algorithms as valid, and you can determine which algorithm
applies to a key by looking at its prefix and suffix.
This means that when your company decides to change algorithms in response to advice
from an auditor, your software can continue supporting old keys and new keys alongside
each other.
With this implementation, I’ve found the following performance on my laptop, a Dell
with I7–12700H at 2.3GHz:
• 2.7us to generate and 1.2us to validate a SHA256 key
• 3.3us to generate and 1.8us to validate a SHA512 key
• 12.1 milliseconds to generate and 12.2ms to validate a BCrypt key
• 9.1 milliseconds to generate and 9.1ms to validate a PBKDF key
You can view my API key generation code and benchmarks on GitHub, or download the
library via NuGet.
Security is a never ending battle

Even though I have intentionally chosen the best practices of which I am aware, the field
of security develops rapidly. I would never trust myself to write my own hashing
algorithm; what I’ve done with ApiKeyGenerator is to encapsulate a well tested algorithm
within a usable and friendly library.
No algorithm that I describe above is guaranteed to be safe forever. As near as I can tell,
SHA256, SHA512, and BCrypt are not broken as of the writing of this article. Older
algorithms like MD5 and SHA-1 are no longer considered strong enough for general
purpose use in 2023.
I hope to continue to refine and make this toolkit more usable over time, and I welcome
your feedback and questions.

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

10 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

Ted Spence heads engineering at ProjectManager.com and teaches at Bellevue College. If
you’re interested in software engineering and business analysis, I’d love to hear from you
on Mastodon or LinkedIn.
Security

API

Api Key

Dotnet

Authentication

Follow

Published in tedspence.com
74 followers · Last published Nov 22, 2025
Software development management, focusing on analytics and effective programming techniques.

Follow

Written by Ted Spence
1.4K followers · 78 following
Software development management, focusing on analytics and effective programming techniques.

Responses (3)
Write a response
What are your thoughts?

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

11 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

Salih Can Erdal
Feb 14, 2025

Hello Ted, thank you for this article. It's a good starting point for beginners like me. However, I have one question
regarding adding salt to the API key before hashing. Why would we need to add salt before hashing, if the API key
itself already has enough entropy?
1

1 reply

Reply

Oren Rose
Jan 18, 2024

Thanks for the read. I have a question regarding the "The algorithm behind an API key system" - Why do you need
the salt for? Seems that if you generate the random api-key, and not the user, you can guarantee strong enough
entropy. Also, I didn't… more
1

1 reply

Reply

Brandon Bernard
Aug 29, 2023

This is a well written article, providing a great overview of the topic of API keys and unattended applications,
Thanks!
1

Reply

More from Ted Spence and tedspence.com

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

12 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

In tedspence.com by Ted Spence

Building applications on a monorepo with Docker containers
Tips and tricks for more complex Docker container build scenarios
Jul 24, 2023

20

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

13 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

In tedspence.com by Ted Spence

Using AWS single sign-on within your Docker containers
Treat your containers like first-class AWS instances with SSO
Oct 24, 2023

74

In tedspence.com by Ted Spence

Why am I having trouble adding a Python library with pip install?
A walkthrough of useful tips and tricks for beginners to Python and Jupyter
May 2, 2023

8

2

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

14 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

In CodeX by Ted Spence

Should your API use enums?
Enumerated values are a clever validation technique that can be risky for an API
Mar 19, 2022

74

3

See all from Ted Spence

See all from tedspence.com

Recommended from Medium

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

15 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

In Women in Technology by Alina Kovtun

Stop Memorizing Design Patterns: Use This Decision Tree Instead
Choose design patterns based on pain points: apply the right pattern with minimal over-engineering
in any OO language.
Jan 29

4.8K

42

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

16 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

In Stackademic by Umesh Kumar Yadav

Token, Session, Cookie, JWT, OAuth2 — I can’t tell the difference!
Recently, I’ve noticed that some people easily confuse the concepts of Token, Session, Cookie, JWT,
and OAuth2.
Dec 10, 2025

197

5

Jacob Bennett

The 5 paid subscriptions I actually use in 2026 as a Staff Software Engineer
Tools I use that are (usually) cheaper than Netflix
Jan 18

3.4K

84

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

17 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

In Generative AI by Adham Khaled

Stanford Just Killed Prompt Engineering With 8 Words (And I Can’t Believe It
Worked)
ChatGPT keeps giving you the same boring response? This new technique unlocks 2× more
creativity from ANY AI model — no training required…
Oct 19, 2025

24K

640

2/27/26, 1:33 PM

What makes a good API key system? | by Ted Spence | teds...

18 of 18

https://tedspence.com/what-makes-a-good-api-key-system-c...

In Write A Catalyst by Dr. Patricia Schmidt

As a Neuroscientist, I Quit These 5 Morning Habits That Destroy Your Brain
Most people do #1 within 10 minutes of waking (and it sabotages your entire day)
Jan 14

32K

603

In Level Up Coding by Teja Kusireddy

I Stopped Using ChatGPT for 30 Days. What Happened to My Brain Was
Terrifying.
91% of you will abandon 2026 resolutions by January 10th. Here’s how to be in the 9% who actually
win.
Dec 28, 2025

8.1K

311

See more recommendations

2/27/26, 1:33 PM

