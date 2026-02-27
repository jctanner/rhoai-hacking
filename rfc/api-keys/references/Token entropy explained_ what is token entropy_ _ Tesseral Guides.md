# Token entropy explained_ what is token entropy_ _ Tesseral Guides

**Source:** `Token entropy explained_ what is token entropy_ _ Tesseral Guides.pdf`

---

Token entropy explained: what is token entropy? | Tesseral...

1 of 7

Soutions

Bog

https://tesseral.com/guides/token-entropy-explained-what-is...

Pricing

Docs

Contact Us

Access the Consoe

Back to Guides

Token entropy
expained: what
is token entropy?
Ned O'Leary
Cofounder and CEO, Tessera

Security and identity peope just ove technica jargon.
There's tons of it. Some is pretty bana, ike identity
federation. Some of it sounds neat, ike tabnabbing.
It's pretty much a impenetetrabe, though.
I' try to dispe confusion around one particuar bit of
jargon: token entropy. You might have heard this
before. If you're ucky, you might have figured it out
from context cues. But if you're ike most of us, you
just want someone to expain it simpy.
I' do my best here. Let's start with a TL;DR token
entropy just means randomness!

2/27/26, 3:25 PM

Token entropy explained: what is token entropy? | Tesseral...

2 of 7

https://tesseral.com/guides/token-entropy-explained-what-is...

What is token entropy?

Soutions

Bog

Pricing

Docs

Contact Us

Access the Consoe

Okay, so token entropy breaks down into two pretty
obvious parts: token and entropy. Let's take them oneby-one. We' start with token and then tak about
entropy.

What is a token?
This one's kind of tough.
"Token" is kind of a generic container term. It doesn't
intrinsicay mean very much.
If you're a software engineer, you might be famiiar
with these kinds of abstract terms. You might tak
about "resources" or "services" or "objects" at work.
Pressed to expain exacty what those mean, you
woud probaby have a hard time. We, "token" is a bit
ike that!
For those of you who aren't software engineers,
imagine I'd said "thingie." That's not a very descriptive
term, but sometimes that's exacty what you want!
There are cases where you just need a bit of a
pacehoder word.

2/27/26, 3:25 PM

Token entropy explained: what is token entropy? | Tesseral...

3 of 7

Soutions

Bog

Pricing

https://tesseral.com/guides/token-entropy-explained-what-is...

Docs

Contact Us

Access the Consoe

"Token" in this context just means a representation of
authentication or authorization status. See: AuthN vs.
AuthZ) It's often just a chunk of data that we ink to a
user.
Here's an exampe using a particuar kind of token,
caed a JSON Web Token JWT

eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI

This isn't the ony kind of token out there, to be cear.
In fact, there are ots! But the genera idea is the same
-- a token is a representation of authentication or
authorization status.

What is entropy (in security)?
There's an idea in phsyics caed "entropy." I'm not
sure I coud give you a great expanation here. It's just
one of those foundationa concepts that defies
intuition; it means an awfu ot of different things. On
some eve, it's usefu to understand (the physics
version of) entropy as a measurement of how
disordered or chaotic a system is.
Good news, though. Entropy in software security isn't

2/27/26, 3:25 PM

Token entropy explained: what is token entropy? | Tesseral...

4 of 7

https://tesseral.com/guides/token-entropy-explained-what-is...

neary as subte. It's sti pretty compicated, but it's
Soutions

Bog

Pricing

Docs

Contact Us

ess metaphysica than its anaogue in physics.

Access the Consoe

Entropy in security basicay just means randomness.
If we say something is "high entropy," we just mean
that it's reay, reay random. We mean that it's hard to
guess.
If we say that a given token is high entropy, that
means it's seected from a very, very arge number of
possibe states. It's just one possibe configuration
seected -- at random -- from an overwheming
number of simiary ikey configurations.

Entropy in passwords
Let's back up from 'tokens' for just a moment. We can
appy the same idea of entropy to passwords, which
are pretty famiiar.
Suppose you require your users to set up a four-digit
PIN as their password, seecting each digit from the
numbers 0 through 9. We coud consider this pretty
ow entropy, because there are 10^4 possibe PINs. If
you spent a day guessing PINs, you'd eventuay get
it right. It woud take a computer ess than a second to
generate a of the possibe PINs.
By contrast, imagine you require a 30 character
password comprising a mix of uppercase etters,
owercase etters, numbers, and specia characters.
Such a password has about 1.5  10^59 possibe
configurations. A computer woud not be abe to
enumerate a such configurations even if it ran for the
entire age of the universe.

2/27/26, 3:25 PM

Token entropy explained: what is token entropy? | Tesseral...

5 of 7

Soutions

Bog

Pricing

https://tesseral.com/guides/token-entropy-explained-what-is...

Docs

Contact Us

Access the Consoe

Entropy in tokens
We often need tokens to be secrets, just ike
passwords. So when we're taking about entropy in
tokens, the idea is exacty the same.
"Entropy" in tokens just describes how hard they'd be
to guess. It's a measure of randomness. If a token is
high entropy, that means it's very difficut to guess.

How to estimate the entropy of a token
Cacuating the entropy of a token is kind of invoved.
It's not so hard when you get the hang of it, but it
requires expanation of some combinatorics that's out
of scope here.
Fortunatey, Wofram Apha has a reay hepfu too for
this! If you have an exampe of a token (pease don't

2/27/26, 3:25 PM

Token entropy explained: what is token entropy? | Tesseral...

6 of 7

https://tesseral.com/guides/token-entropy-explained-what-is...

use a rea secret token), you can use Wofram Apha to
Soutions

Bog

Pricing

Docs

Contact Us

estimate its entropy. I put together an exampe query

Access the Consoe

to estimate token entropy.
That shoud cover your bases!

Tessera: secure auth
for SaaS
Tessera is open source auth infrastructure for SaaS
appications. It incudes everything you need to
manage ogins and identity at any scae.
For exampe, it incudes a service that can manage API
keys for you. That is, if you expose a pubic API to
your customers, you need to use secure API keys to
authenticate your customers' requests. Tessera can
manage the entire ifecyce of an API key and make
sure that they're extremey high entropy (i.e.,
functionay impossibe to guess at random).
See our reated artice: API Key Management Service:
What It Is, Why It Matters, and How to Choose One.

About the Author

2/27/26, 3:25 PM

Token entropy explained: what is token entropy? | Tesseral...

7 of 7

Soutions

Bog

https://tesseral.com/guides/token-entropy-explained-what-is...

Ned O'Leary

Pricing Cofounder
Docs andContact
Us
Access the Consoe
CEO, Tessera

Ned is the cofounder and CEO
of Tessera. Previousy he
worked at Gem and the
Boston Consuting Group. He
writes about product design,
identity, and access
management. You can often
find him at Baker Beach in San
Francisco with his puppy,
Fred.

Resources

Compare

Company

Socia

Pricing

Tessera vs. Auth0

Terms of Use

GitHub

Docs

Tessera vs. WorkOS

Privacy Poicy

LinkedIn

Bog

Tessera vs. Cerk

Contact us

X Twitter)

Security

Schedue a Ca

2/27/26, 3:25 PM

