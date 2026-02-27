# security - What's the best approach for generating a new API key_ - Stack Overflow

**Source:** `security - What's the best approach for generating a new API key_ - Stack Overflow.pdf`

---

security - What's the best approach for generating a new AP...

1 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

What's the best approach for generating a new API key?
Asked 13 years, 1 month ago

Modified 5 months ago

Viewed 188k times

So with lots of different services around now, Google APIs, Twitter API, Facebook API, etc
etc.

162

Each service has an API key, like:
AIzaSyClzfrOzB818x55FASHvX4JuGQciR9lv7q

All the keys vary in length and the characters they contain, I'm wondering what the best
approach is for generating an API key?
I'm not asking for a specific language, just the general approach to creating keys, should they
be an encryption of details of the users app, or a hash, or a hash of a random string, etc.
Should we worry about hash algorithm (MSD, SHA1, bcrypt) etc?
Edit: I've spoke to a few friends (email/twitter) and they recommended just using a GUID with
the dashes stripped.
This seems a little hacky to me though, hoping to get some more ideas.
security

api-key

Share Improve this question
Follow

edited Dec 11, 2020 at 2:38

Piper
1,267

asked Jan 19, 2013 at 7:26

Phill
3

15

26

19k

7

66

105

I have answered in more details here.. generating keys and using it as hmac auth – Anshu Kumar Apr
19, 2020 at 8:33

12 Answers

Sorted by:

Highest score (default)

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

2 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

Use a random number generator designed for cryptography. Then base-64 encode the
number.

94

This is a C# example:
Copy
var key = new byte[32];
using (var generator = RandomNumberGenerator.Create())
generator.GetBytes(key);
string apiKey = Convert.ToBase64String(key);

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

3 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

Sign up to request clarification or add additional context in comments.
Share Improve this answer
edited Mar 1, 2018 at 16:19
answered Sep 11, 2013 at 0:30
Follow

14 Comments

Edward Brey
42.1k

21

215

269

Add a comment
James Wierzba Over a year ago

This is not very secure, an attacker that gains access to your database could obtain the key. It would
be better to generate the key as a hash of something unique to the user (like a salt), combined with a
server secret.
4

Reply

Edward Brey Over a year ago

Storing a randomly generated API key has the same security characteristics as storing a hashed
password. In most cases, it's fine. As you suggest, it is possible to consider the randomly generated
number to be a salt and hashing it with a server secret; however, by doing so, you incur the hash
overhead on every validation. There is also no way to invalidate the server secret without invalidating
all API keys.
29

Reply

Jon Story Over a year ago

@JamesWierzba if the attacked is already in your database, then them having unsecured access to
your API is probably the least of your concerns...
51

Reply

Rob Grant Over a year ago

@EdwardBrey not quite the same characteristics. Someone who reads the database with the API key
in it now has a valid API key. Someone who reads a hashed password cannot use that hash as a
password.
10

Reply

Edward Brey Over a year ago

@RobGrant Good point. The server can give the API key to the application but store a hash of it in the
database. When authenticating, the server can hash the presented API key and verify that the hash
matches the hash in the database. So long as the salt used for hashing is stored separately from the
hash, such that an attacker is unlikely to obtain both the hash and salt, a leak of a hash does not grant
an attacker API access.
4

Reply

|

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

4 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

API keys need to have the properties that they:

40

• uniquely identify an authorized API user -- the "key" part of "API key"
• authenticate that user -- cannot be guessed/forged
• can be revoked if a user misbehaves -- typically they key into a database that can have a
record deleted.
Typically you will have thousands or millions of API keys not billions, so they do not need to:
• Reliably store information about the API user because that can be stored in your
database.
As such, one way to generate an API key is to take two pieces of information:
1. a serial number to guarantee uniqueness
2. enough random bits to pad out the key
and sign them using a private secret.
The counter guarantees that they uniquely identify the user, and the signing prevents forgery.
Revocability requires checking that the key is still valid in the database before doing anything
that requires API-key authorization.
A good GUID generator is a pretty good approximation of an incremented counter if you need
to generate keys from multiple data centers or don't have otherwise a good distributed way to
assign serial numbers.

or a hash of a random string
Hashing doesn't prevent forgery. Signing is what guarantees that the key came from you.

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

5 of 14

5
Comments
Share
Improve this answer

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

edited Jun 23, 2014 at 17:07

answered Jun 23, 2014 at 14:02

Mike Samuel

Follow
Add a comment

121k

30

230

255

sappenin Over a year ago

Is the signing step of your algorithm necessary if the API key presented by a client is checked against
a database of already registered API keys on the server providing the API? Seems like signing would
be redundant here if the server is the one providing keys.
8

Reply

Mike Samuel Over a year ago

@sappenin, Yes. If you store an unguessable key on the server, then you don't need to prevent
forgery. Often API requests are handled by any one of a farm of machines -- the server is one of many
servers. Signature checking can be done on any machine without a round-trip to a database which can
avoid race conditions in some cases.
7

Reply

Abhyudit Jain Over a year ago

@MikeSamuel if API key is signed and you don't do a round trip to Database then what happens when
the key is revoked but still used to access the API?
5

Reply

Mike Samuel Over a year ago

@AbhyuditJain, In any distributed system, you need a consistent message order (revocations happenbefore subsequent uses of revoked credentials) or other ways to bound ambiguity. Some systems don't
round-trip on every request -- if a node caches the fact that a key was in the database for 10 minutes,
there's only a 10 min. window in which an attacker can abuse a revoked credential. Possible confusion
can result though: user revokes a credential, then tests that it's revoked, and is surprised because nonsticky sessions cause the two requests to go to different nodes.
0

Reply

tekHedd Over a year ago

"Hashing doesn't prevent forgery." So, why exactly am I hashing all these passwords? Oh, and there is
the answer. Passwords are supposed to be difficult to guess. This answer uses easily guessable
tokens. Well, yes, if they are easily guessable then signing is essential. Otherwise, and assuming you
are not trusting additional data embedded in the token, signing is a waste of CPU.
0

Reply

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

6 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

2023 Note: In Chrome, the default new tab page does not allow the use of the cryptography
module in the console, so please use a different page.

19

Update, in Chrome's console and Node.js, you can issue:
crypto.randomUUID()

Example output:
4f9d5fe0-a964-4f11-af99-6c40de98af77

Original answer (stronger):
You could try your web browser console by opening a new tab on any site (see 2023 note at
the top of this answer), hitting CTRL + SHIFT + i on Chrome, and then entering the following
immediately invoked function expression (IIFE):
(async function (){
let k = await window.crypto.subtle.generateKey(
{name: "AES-GCM", length: 256}, true, ["encrypt", "decrypt"]);
const jwk = await crypto.subtle.exportKey("jwk", k)
console.log(jwk.k)
})()

Example output:
gv4Gp1OeZhF5eBNU7vDjDL-yqZ6vrCfdCzF7HGVMiCs

References:
https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/generateKey
https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/exportKey
I'll confess that I mainly wrote this for myself for future reference...
Share Improve this answer
Follow

edited Jan 8, 2024 at 23:59

answered Feb 2, 2022 at 20:13

Chris Chiasson
866

12

20

Comments
Add a comment

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

7 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

In the terminal, you can use openssl like so:

16

openssl rand -hex 32

Example output:
1e846f3fcf103f64ca10fa4eac73bfae32ef10750bf4eae29132dc099526c561

Share Improve this answer Follow

answered Apr 12, 2023 at 12:50

Victor
3,641

2

23

22

Comments
Add a comment

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

8 of 14

10

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

If you want an API key with only alphanumeric characters, you can use a variant of the
base64-random approach, only using a base-62 encoding instead. The base-62 encoder is
based on this.
Copy
public static string CreateApiKey()
{
var bytes = new byte[256 / 8];
using (var random = RandomNumberGenerator.Create())
random.GetBytes(bytes);
return ToBase62String(bytes);
}
static string ToBase62String(byte[] toConvert)
{
const string alphabet =
"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
BigInteger dividend = new BigInteger(toConvert);
var builder = new StringBuilder();
while (dividend != 0) {
dividend = BigInteger.DivRem(dividend, alphabet.Length, out BigInteger
remainder);
builder.Insert(0, alphabet[Math.Abs(((int)remainder))]);
}
return builder.ToString();
}

Share Improve this answer Follow

answered Jun 20, 2018 at 20:35

Edward Brey
42.1k

21

215

269

Comments
Add a comment

I use UUIDs, formatted in lower case without dashes.

8

Generation is easy since most languages have it built in.
API keys can be compromised, in which case a user may want to cancel their API key and
generate a new one, so your key generation method must be able to satisfy this requirement.

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

9 of 14

3
Comments
Share
Improve this answer

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

edited Jan 20, 2013 at 9:08

answered Jan 20, 2013 at 8:55

Adam Ralph

Follow
Add a comment

30.1k

5

63

68

Edward Brey Over a year ago

Do not assume that UUIDs are hard to guess; they should not be used as security capabilities (UUID
spec RFC4122 section 6). An API key needs a secure random number, but UUIDs are not securely
unguessable.
24

Reply

Micro Over a year ago

@EdwardBrey what about UUID uuid = UUID.randomUUID(); in Java? Are you saying that
random is not good enough?
5

Reply

Edward Brey Over a year ago

@MicroR A random UUID is secure only if the random number generator used to make it is
cryptographically secure and 128 bits are sufficient. Although the UUID RFC does not require a secure
random number generator, a given implementation is free to use one. In the case of randomUUID, the
API docs specifically state that it uses a "cryptographically strong pseudo random number generator".
So that particular implementation is secure for a 128-bit API key.
12

Reply

Yet another more updated version of previous answers - but more compact and newjavascripty than before!

4
Copy
#!/usr/bin/env node
const { subtle } = require('crypto').webcrypto
subtle
.generateKey({ name: 'AES-GCM', length: 256 }, true, ['encrypt', 'decrypt'])
.then(key => subtle.exportKey('jwk', key))
.then(jwk => console.log(jwk.k))

Run:
$ node /tmp/genkey.js
Mtra_qEFS7F76HrpgDAP2rBsb4pJ4w2hTL8UUyxalRA

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

10 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

1
Comment
Share
Improve this answer Follow

answered Jul 26, 2023 at 11:27

Andrew E

Add a comment

8,485

4

47

47

Oussama Bouchareb Over a year ago

This should be the accepted answer, as it is the only sane approach here
2

Reply

I liked Chris Chiasson's use of crypto.subtle in a browser, but wanted a command-line
version. If you have NodeJS installed, this can be saved in a file (e.g., mkapikey.js ):

2
#!/usr/bin/env node
crypto.subtle.generateKey({name:"AES-GCM", length:256},true,
["encrypt","decrypt"]).then(key => {crypto.subtle.exportKey("jwk",key).
then(jwk => {console.log(jwk.k)})});

Either chmod +x to an executable or invoke with node mkapikey.js .
chmod +x mkapikey.js
./mkapikey.js
4SvnAK87DD0t3WMS878UCY-obmADtPeBn6X4gFOtUig

Share Improve this answer Follow

answered May 7, 2023 at 14:05

Joe
2,438

21

40

Comments
Add a comment

1

An API key should be some random value. Random enough that it can't be predicted. It
should not contain any details of the user or account that it's for. Using UUIDs is a good idea,
if you're certain that the IDs created are random.
Earlier versions of Windows produced predictable GUIDs, for example, but this is an old story.

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

11 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

1
Comment
Share
Improve this answer Follow

answered Jan 20, 2013 at 9:26

Dave Van den Eynde

Add a comment

17.5k

7

63

91

Edward Brey Over a year ago

Windows 2000 switched to GUIDs using random numbers. However, there is no guarantee that the
random numbers can't be predicted. For example, if an attacker creates several API keys for himself, it
may be possible to determine a future random number used to generate another user's API key. In
general, do not consider UUIDs to be securely unguessable.
6

1

Reply

One popular way is to generate a random string using a cryptographically secure pseudorandom number generator (CSPRNG) and then encode this string with base64 encoding. This
can provide a high level of security, as the keys are difficult to guess, and can be of virtually
any length.
The other approach, as your friends suggested, is to use a GUID/UUID. It's true that some
might find this to be a little "hacky", but in practice, it works well.
As for the hashing algorithms, if you choose to go the hashing route, it's generally
recommended to use a strong algorithm like SHA256 or SHA3. Algorithms like MD5 and
SHA1 are considered to be broken and should not be used for new systems.
Here is the Python code:
import secrets
import base64
def generate_api_key():
# Generate 32 random bytes
random_bytes = secrets.token_bytes(32)
# Convert those bytes into a URL-safe base64 string
api_key = base64.urlsafe_b64encode(random_bytes).decode("utf-8")
return api_key
print(generate_api_key())

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

Comments
Share Improve this answer

answered Jul 22, 2023 at 7:03

12 of 14

edited Jul 22, 2023 at 9:04

Eric Aya

Follow
Add a comment

70.2k

36

Dana Scott
190

266

21

1

I'd like to add an implementation in Java, that uses class KeyPairGenerator to gen a public

1

key using RSA, then convert it to base64. Lastly you can also pretty your API key by
eliminating all the slash char and extract only the last part of the generated public key.
Copy
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
public static String generateMyAPIKey() throws NoSuchAlgorithmException {
KeyPairGenerator keyGen = KeyPairGenerator.getInstance("RSA");
keyGen.initialize(1024);
byte[] publicKey = keyGen.genKeyPair().getPublic().getEncoded();
String base64Binary =
DatatypeConverter.printBase64Binary(publicKey).replaceAll("/", "");
return base64Binary.substring(base64Binary.length() - 32);
}

Share Improve this answer Follow

answered Apr 1, 2024 at 9:15

lepoing
66

6

1 Comment
Add a comment
TheRealChx101 Over a year ago

Huh? What exactly are you doing here? Why not directly removed something from the public key itself
first?
0

Reply

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

13 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

import os
import base64

0

def generate_api_key(length=64):
"""Generates a cryptographically secure API key of a specified length."""
# Calculate the number of bytes needed for the desired length after Base64
encoding
# Base64 encoding expands data by approximately 33%, so we need fewer bytes.
# A rough estimate for 64 characters is around 48 bytes (48 * 4/3 = 64)
num_bytes = int(length * 3 / 4)
# Generate random bytes
random_bytes = os.urandom(num_bytes)
# Encode to Base64 and decode to a string
api_key = base64.urlsafe_b64encode(random_bytes).decode('utf-8')
# Truncate or pad to the exact desired length
if len(api_key) > length:
return api_key[:length]
elif len(api_key) < length:
# This case is less common if num_bytes is calculated correctly for Base64
# You might need to regenerate with slightly more bytes or pad with random
chars
padding_needed = length - len(api_key)
api_key +=
base64.urlsafe_b64encode(os.urandom(padding_needed)).decode('utf-8')
[:padding_needed]
return api_key
return api_key
# Generate a 64-character API key
api_key = generate_api_key(64)
print(f"Generated API Key: {api_key}")
print(f"Length: {len(api_key)}")

Share Improve this answer Follow

answered Sep 10, 2025 at 6:36

Ayush
1

3

Comments
Add a comment

Start asking to get answers
Find the answer to your question by asking.
Ask question

2/27/26, 1:31 PM

security - What's the best approach for generating a new AP...

14 of 14

https://stackoverﬂow.com/questions/14412132/whats-the-bes...

Explore related questions
security

api-key

See similar questions with these tags.

2/27/26, 1:31 PM

