# API Key Security Best Practices _ r_softwarearchitecture

**Source:** `API Key Security Best Practices _ r_softwarearchitecture.pdf`

---

API Key Security Best Practices : r/softwarearchitecture

1 of 4

r/softwarearchitecture

https://www.reddit.com/r/softwarearchitecture/comments/...

Search in r/software…

Create

r/softwarearchitecture • 3y ago
molmorg

API Key Security Best Practices
We spent a lot of time designing our API Key solution at Zuplo - we recently wrote up our learnings based on a
lot of research and internal discussion. Would love to hear thoughts of folks here... how do people feel about
choice between retrievable and irretrievable?
https://zuplo.com/blog/2022/12/01/api-key-authentication/

12

9

Share

Join the conversation
Search Comments

Sort by: Best

bugmonger • 3y ago

Irretrievable - in the event of a silent data breach you’d be better protected. In addition, having a primary
and secondary encryption key such that you can rotate all of the keys tied to a specific set of api keys is
useful and having the secondary provides a fallback during transitions.
Also - depending on the sensitivity of the data and auditing requirements will help you determine whether
or not to use api keys
3

Reply

molmorg OP • 3y ago

What do you think of the argument that irretrievable leads to a lot of people storing the key in
unsecure places (text files etc)? Obviously a tricky tradeoff but the reason to go 'retrievable' would be
that you think the risk of people making this mistake is greater than the silent data breach you
mention.
1

Reply

splitretina • 3y ago

For irretrievable keys the advice in this article is wrong. Don’t use bcrypt unless you are initiating an
authenticated session and issuing a token. Bcrypt is slow by design and if you are lucky enough to have a
ton of users pounding on your api, just legit requests, your bottleneck will be cpu and memory to verify
those passwords. I’m guessing the author’s company chose retrievable keys :).
Bcrypt is for passwords (the article that is linked is about passwords, not api keys) where you cannot

2/27/26, 12:42 PM

API Key Security Best Practices : r/softwarearchitecture

2 of 4

https://www.reddit.com/r/softwarearchitecture/comments/...

Bcrypt is for passwords (the article that is linked is about passwords, not api keys) where you cannot
control the amount of entropy, such as when the user provides it. When generating a key you get to
r/softwarearchitecture
Create
decide the length and character set. Provide enough entropy in the key and it will be unique (think UUIDs)
then hash it with sha256. Store that indexed in your db. You’ll have secure keys that are very fast to
check, which leads to a better user experience. Bcrypt, depending on the options you select, can take
500ms to verify. Sha256 is done in microseconds. Db/cache access being equal, do you want to add
499+ms to every request?
But what about salt? Yea, not necessary. What’s the point? Salt is to avoid two password that are the
same producing the same hash, allowing attacks where hashes are precomputed. It is unreasonable (or
impossible) to precompute hashes for all big inputs. You control the password this time so make sure it is
long enough that generating precomputed hashes would take literally forever.
If you’re having trouble understanding why this is secure think about git commits. Can you restore the
code from the hash? Can you guess a hash for a an extremely large project with lots of hashes, such as
the Linux kernel? How about a bitcoin address? No. There are just too many choices.
3

Reply

molmorg OP • 3y ago

This is great feedback - and you're correct that our current implementation is retrievable. Updated the
article.
What do you think to the idea of using a salted hash instead of a checksum to allow the key to be
verified as being of legitimate origin before calling the database?
1

Reply

splitretina • 3y ago

I noticed the checksum idea in the article. It’s interesting. I’d like to see how often invalid keys that
match the key format hit the servers. I have a feeling it wouldn’t be much if any, but I might be
surprised. If you can validate the checksum cheaply and keep bad connections away from the
application servers then it seems like a good solution to that problem.
I’m not sure what you mean about a salted hash in place of the checksum. Do you mean HMAC? I
suppose it depends on how expensive key checking is. And what attack vectors you are trying to
solve for. But in general, if your keys are random enough it shouldn’t be a problem. For instance,
imagine caching the auth result for every key that hits the server, even if that result is “unknown
key”. With passwords that is a problem because the user may have hit the server and cached
whatever creds they want to use as “unknown”. But when you generated the key and it is random
and universally unique, it won’t collide with an already cached key. The origin of key can only be
your service because the keyspace is just that big. Note that if you cache everything forever you’ll
also need a revocation list.
Speaking of revocation, if you really want to avoid hitting the db and do auth completely at the
edge you could use AEAD but your keys will be pretty long. (E.g PASETO) and you’ll still need to
hit a revocation list.
Disclaimer: I am not a cryptographer.

2/27/26, 12:42 PM

API Key Security Best Practices : r/softwarearchitecture

3 of 4

https://www.reddit.com/r/softwarearchitecture/comments/...

molmorg
OP • 3y ago
r/softwarearchitecture

Create

The checksum serves two purposes actually - it's primarily used in the secret scanning (in
partnership with GitHub) per their recommendations.

splitretina • 3y ago

Ah, that is very cool! I hadn’t seen that.
https://github.blog/2021-04-05-behind-githubs-new-authentication-token-formats/
#checksum

sebastianstehle • 3y ago

Why is it JWT vs API Key? You can implement your API Key as JWT token and make it self contained to
avoid the extra DB call.

molmorg OP • 3y ago

Great question - I actually talk about this in another post: https://zuplo.com/blog/2022/05/03/youshould-be-using-api-keys/
There are a few reasons folks might choose a key like this:
• API keys are typically an opaque string, whereas JWTs often contain details like claims that
expose details you may prefer to keep private
• JWTs are typically trusted until expiry as being signed by an authority. If a JWT is leaked it's
often very hard to revoke it (without revoking everybody's tokens). API Keys (when best
practices are followed) can be self revoked easily. You can set a short expiry time on the JWT
token to mitigate this situation, but that leads to a much more complicated auth flow for
developers - this is why the best API companies tend to favor keys over JWTs.
You could engineer a JWT that is essentially 'claimless' (basically contains an opaque string like an
API key) and has no expiry - but that is essentially a twist on what was presented, and would be an
unusual way to deploy JWT tokens.
Of course, if you're doing calls on behalf of a user (instead of a system or organization) - OAuth / JWT
is the best choice.

Reddit Rules Privacy Policy User Agreement Your Privacy Choices Accessibility Reddit, Inc. © 2026. All rights reserved.

2/27/26, 12:42 PM

API Key Security Best Practices : r/softwarearchitecture

4 of 4

r/softwarearchitecture

https://www.reddit.com/r/softwarearchitecture/comments/...

Create

2/27/26, 12:42 PM

