# linux - where are tokens created by kubectl create token stored (from v1.24 on)_ - Stack Overflow

**Source:** `linux - where are tokens created by kubectl create token stored (from v1.24 on)_ - Stack Overflow.pdf`

---

linux - where are tokens created by kubectl create token sto...

1 of 7

https://stackoverﬂow.com/questions/73572929/where-are-to...

where are tokens created by kubectl create token stored
(from v1.24 on)?
Asked 3 years, 6 months ago

Modified 3 years, 4 months ago

Viewed 10k times

This question concerns kubernetes v1.24 and up

12

So I can create tokens for service accounts with
Copy
kubectl create token myserviceaccount

The created token works and serves the purpose, but what I find confusing is that when I
kubectl get sa SECRETS field of myserviceaccount is still 0. The token doesn't appear in
kubectl get secrets either.

I've also seen that I can pass --bound-object-kind and --bound-object-name to kubectl
create token but this doesn't seem to do anything (visible) either...

Is there a way to see created token? And what is the purpose of --bound.. flags?
linux

kubernetes

token

Share Improve this question

edited Sep 17, 2022 at 9:49

asked Sep 1, 2022 at 16:47

golder3

Follow

593

1

6

18

If this or any answer has solved your question please consider accepting it by clicking the check-mark.
This indicates to the wider community that you've found a solution and gives some reputation to both
the answerer and yourself. There is no obligation to do this. – Hector Martinez Rodriguez Sep 12, 2022
at 13:42

2 Answers

Sorted by:

Highest score (default)

2/27/26, 3:47 PM

linux - where are tokens created by kubectl create token sto...

2 of 7

11

https://stackoverﬂow.com/questions/73572929/where-are-to...

Thanks to the docs link I've stumbled upon today (I don't know how I've missed it when asking
the question because I've spent quite some time browsing through the docs...) I found the
information I was looking for. I feel like providing this answer because I find v1d3rm3's answer
incomplete and not fully accurate.
The kubernetes docs confirm v1d3rm3's claim (which is btw the key to answering my
question):
The created token is a signed JSON Web Token (JWT).
Since the token is JWT token the server can verify if it has signed it, hence no need to store it.
JWTs expiry time is set not because the token is not associated with an object (it actually is,
as we'll see below) but because the server has no way of invalidating a token (it would
actually need to keep track of invalidated tokens because tokens aren't stored anywhere and
any token with good signature is valid). To reduce the damage if a token gets stolen there is
an expiry time.
Signed JWT token contains all the necessary information inside of it.
The decoded token (created with kubectl create token test-sa where test-sa is service
account name) looks like this:
Copy
{
"aud": [
"https://kubernetes.default.svc.cluster.local"
],
"exp": 1666712616,
"iat": 1666709016,
"iss": "https://kubernetes.default.svc.cluster.local",
"kubernetes.io": {
"namespace": "default",
"serviceaccount": {
"name": "test-sa",
"uid": "dccf5808-b29b-49da-84bd-9b57f4efdc0b"
}
},
"nbf": 1666709016,
"sub": "system:serviceaccount:default:test-sa"
}

Contrary to v1d3rm3 answer, This token IS associated with a service account
automatically, as the kubernets docs link confirm and as we can also see from the token
content above.
Suppose I have a secret I want to bind my token to (for example kubectl create token
test-sa --bound-kind Secret --bound-name my-secret where test-sa is service account name

2/27/26, 3:47 PM

linux - where are tokens created by kubectl create token sto...

3 of 7

https://stackoverﬂow.com/questions/73572929/where-are-to...

and my-secret is the secret I'm binding token to), the decoded token will look like this:
Copy
{
"aud": [
"https://kubernetes.default.svc.cluster.local"
],
"exp": 1666712848,
"iat": 1666709248,
"iss": "https://kubernetes.default.svc.cluster.local",
"kubernetes.io": {
"namespace": "default",
"secret": {
"name": "my-secret",
"uid": "2a44872f-1c1c-4f18-8214-884db5f351f2"
},
"serviceaccount": {
"name": "test-sa",
"uid": "dccf5808-b29b-49da-84bd-9b57f4efdc0b"
}
},
"nbf": 1666709248,
"sub": "system:serviceaccount:default:test-sa"
}

Notice that binding happens inside the token, under kubernetes.io key and if you describe
my-secret you will still not see the token. So the --bound-... flags weren't visibly (from secret
object) doing anything because binding happens inside the token itself...
Instead of decoding JWT tokens, we can also see details in TokenRequest object with
Copy
kubectl create token test-sa -o yaml

Sign up to request clarification or add additional context in comments.
Share Improve this answer Follow
answered Oct 25, 2022 at 15:27
golder3

4 Comments

593

1

6

18

Add a comment
v1d3rm3 Over a year ago

Your answer is much better than mine, but, youdidn't understand my answer. I didn't said that
expiration time was set because the missing association. I said is obligatory because of "security
reasons"
0

Reply

2/27/26, 3:47 PM

linux - where are tokens created by kubectl create token sto...

4 of 7

golder3

https://stackoverﬂow.com/questions/73572929/where-are-to...

Over a year ago

Look@v1d3rm3
at golder3
answer.
sorry
then, I deducted it from "...for security reasons, expiration time of a created token not
associated with an object..." And thanks a lot for your time and help, I appreciate it!

0

1

Reply

Is there a way to see created token?
v1d3rm3 Over a year ago

When we talk about association, there is a property of direction of association ("token has a secret
reference"
"secret created
has tokenwith
reference"),
the source
ourone
miscommunication.
No, there
isn't.orTokens
Token it's
Request
API of
are
time creation. Kubernetes

doesn't manage
tokens,
the only way to manage tokens is associate it with a Secret or Pod
0
Reply
object. Tokens are JWT objects, so, for security reasons, expiration time of a created token
v1d3rm3 Over a year ago
not associated with an object is, by default, of one hour. It can be configured with --duration
Expiration time is optional in JWT if it was created from a secret object of type kubernetes.io/

property.
service-account-token
0

Reply

And what is the purpose of --bound.. flags?
The purpose of --bound flags is to associate a token with a specific object.

From v1.24, you've to manually create tokens.

Using TokenRequest API
It depends of the use case, but it's not so easy to manage these tokens. They're created with
the command kubectl create , some examples are:
Copy
kubectl create token SERVICE_ACCOUNT_NAME

if the Service Account is in a specific namespace , then you need to define on command:
Copy
kubectl create token SERVICE_ACCOUNT_NAME -n NAMESPACE

You can defined expiration time too:
Copy
kubectl create token SERVICE_ACCOUNT_NAME --duration 5h

Reference: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#-emtoken-em-

Token associated with a Secret

2/27/26, 3:47 PM

linux - where are tokens created by kubectl create token sto...

5 of 7

https://stackoverﬂow.com/questions/73572929/where-are-to...

Token associated with a Secret
To create a token associated with a secret object, you can use kubectl apply with a file:
Copy
apiVersion: v1
kind: Secret
metadata:
name: demo-token # the name of secret
annotations:
kubernetes.io/service-account.name: "name_of_sa" # the name of the
ServiceAccount
type: kubernetes.io/service-account-token

Then, just execute:
Copy
kubectl apply -f file.yml

Or, if the ServiceAccount is in a specific namespace
Copy
kubectl apply -f file.yml -n NAMESPACE

1
Comment
Share
Improve this answer

answered Oct 21, 2022 at 15:35

v1d3rm3

Follow
Add a comment
golder3

edited Oct 25, 2022 at 17:45

833

10

18

Over a year ago

the question was where the token created with kubectl create token is stored, not how to create it (btw I
wrote in the question how it can be created...) or how to associate a token to a secret...
0

Reply

Start asking to get answers
Find the answer to your question by asking.
Ask question

Explore related questions

2/27/26, 3:47 PM

linux - where are tokens created by kubectl create token sto...

6 of 7

linux

kubernetes

https://stackoverﬂow.com/questions/73572929/where-are-to...

token

See similar questions with these tags.

2/27/26, 3:47 PM

linux - where are tokens created by kubectl create token sto...

7 of 7

https://stackoverﬂow.com/questions/73572929/where-are-to...

2/27/26, 3:47 PM

