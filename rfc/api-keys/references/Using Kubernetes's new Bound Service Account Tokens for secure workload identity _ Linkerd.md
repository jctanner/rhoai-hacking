# Using Kubernetes's new Bound Service Account Tokens for secure workload identity _ Linkerd

**Source:** `Using Kubernetes's new Bound Service Account Tokens for secure workload identity _ Linkerd.pdf`

---

Using Kubernetes's new Bound Service Account Tokens for ...

1 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

Announcing Linkerd 2.19: Post-quantum cryptography Learn more

Using Kubernetes's new
Bound Service Account
Tokens for secure
workload identity
Tarun Pothulapati
Dec 28, 2021 • 8 min read

2/27/26, 3:46 PM

Using Kubernetes's new Bound Service Account Tokens for ...

2 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

Security is a �rst-class concern for Linkerd. It plays a
critical role in enhancing the overall security of the system,
and this is only possible if Linkerd itself is secure. We
recently added support for Kubernetes’s new bound
service account tokens to Linkerd. This is a big step
forward for security. But why? In order to understand that,
�rst we need to understand how Linkerd uses service
accounts.
Linkerd provides mutual TLS (mTLS) to secure
communication between workloads. Central to any type of
communication security is the notion of identity —as
discussed in the Kubernetes engineer’s guide to mTLS,
without identity you have no authenticity, and without
authenticity you do not have secure communication. All of
Linkerd’s mTLS magic is possible because the control
plane (speci�cally the
component) issues a
certi�cate that the proxy uses to authenticate itself with
other services.
But what is the identity contained in this TLS certi�cate?
And how does Linkerd’s identity component ensure it is
issuing a certi�cate to a proxy in the cluster and not some
intruder trying to communicate with other services in the
cluster? How does the control plane ensure identities of
the proxies itself? We’ll answer those questions in this blog
post. Let’s dive in!

Kubernetes Service Accounts
This is not just a Linkerd problem. A lot of components or
K8s controllers would want to verify the identity of their
clients (if they are running in the cluster or not) before
providing services for them. So, Kubernetes provides
service accounts that are attached to your pods by default,

2/27/26, 3:46 PM

Using Kubernetes's new Bound Service Account Tokens for ...

3 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

and can be used by the application inside to prove its
identity to other components that it is part of the
Kubernetes cluster. These are attached as a volume into
your pod, and are mounted into the container at the
�lepath. By default, Kubernetes attaches the
service account of the pod namespace.
spec:
containers:
...
volumeMounts:
- mountPath: /var/run/secrets/kubernetes.io/serviceaccount
name: kube-api-access-tsbwl
readOnly: true
...
volumes:
- name: kube-api-access-tsbwl
projected:
defaultMode: 420
sources:
- serviceAccountToken:
expirationSeconds: 3607
path: token
- configMap:
items:
- key: ca.crt
path: ca.crt
name: kube-root-ca.crt
- downwardAPI:
items:
- fieldRef:
apiVersion: v1
fieldPath: metadata.namespace
path: namespace

Service accounts are also popularly used with Kubernetes

2/27/26, 3:46 PM

Using Kubernetes's new Bound Service Account Tokens for ...

4 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

RBAC to grant access to Kubernetes API Services to pods.
This is done by attaching a
(with necessary
permissions) to a service account (by creating a
object) using a
.
Then we can specify the same service account in the
of your workload. This would
override the default service account that is present per
namespace. The default service account token has no
permissions to view, list or modify any resources in the
cluster.
When Kubernetes attaches the default service account
token, it also attaches a con�gmap of the
(as seen in the above YAML) that contains the
trusted root certi�cate of the API server. This is used for
TLS authentication with the API server when applications
communicate with the API server.
Linkerd never needed any of these additional �les apart
from the token as it never interacts with the Kubernetes
API (We will see later how bound service account tokens
�xes this).

So how does Linkerd validate that
its proxies are who they say they
are?
For the proxy to get its certi�cates, it needs to verify itself
with the identity component. This is done by embedding
the service account token into the
request that is
called every time a new certi�cate is needed (24hours by
default). The identity component validates the token by
talking to the TokenReview Kubernetes API and returns a
with the certi�cate only after that. The
identity component not only veri�es that the token is valid,

2/27/26, 3:46 PM

Using Kubernetes's new Bound Service Account Tokens for ...

5 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

but it also veri�es if the token is associated with the same
pod that is requesting the certi�cate. This can be veri�ed
by looking at the
in the
response. Kubernetes API sets the
username to the pod name to which that token was
attached.
Only the identity component in Linkerd has the necessary
API access to verify tokens. Once a token is veri�ed, the
identity component issues a certi�cate for the proxy to
use to communicate with other services.

How does Linkerd provide workload
identity?
Linkerd takes a beautiful (in my mind) simplifying step
here: the service accounts aren’t just used to validate that
the proxies are who they say they are, they’re used as the
basis of the workload’s identity itself. This gives us a
workload identity that is already tied to the capabilities
granted to the pod, and means that we can provide mTLS
without any additional con�guration! This is the secret
behind Linkerd’s ability to provide on-by-default mTLS for
all meshed pods.
Whenever Linkerd established a mutual TLS connection
between two endpoints, the identity exchanged is that of
the service account on either side. This identity is even
wired into Linkerd’s metrics: whenever a meshed request
is received or being sent, the relevant metrics also include
the service account with which that peer was associated
with.
Here is an example metric from the emojivoto example:

2/27/26, 3:46 PM

Using Kubernetes's new Bound Service Account Tokens for ...

6 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

request_total{..., client_id="web.emojivoto.serviceaccount.identit

As you can see the
label in the above metric is
the service account that was attached to the client pod
from where the request was received.

Authorization Policy
Linkerd’s new authorization policy feature allows users to
specify set of clients that can only access a set of
resources. This is done by using the same identity to
enable users to specify service accounts of the clients that
should be allowed to talk to a group of workloads
(grouped by the
resource) in their
resource.
apiVersion: policy.linkerd.io/v1beta1
kind: ServerAuthorization
metadata:
namespace: emojivoto
name: internal-grpc
labels:
app.kubernetes.io/part-of: emojivoto
app.kubernetes.io/version: v11
spec:
server:
selector:
matchLabels:
emojivoto/api: internal-grpc
client:
meshTLS:
serviceAccounts:
- name: web

In the above example, we are permitting workloads that
use the
service account to talk to the

2/27/26, 3:46 PM

Using Kubernetes's new Bound Service Account Tokens for ...

7 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

server.

Bound Service Account Tokens
Though all of this is great, there’s still a catch. This token is
aimed at the applications to talk to the Kubernetes API
and not speci�cally for Linkerd. Linkerd also doesn’t need
those extra certs that are part of the default volume
mount. This is not a security best practice. Linkerd actually
gets more permissions than it really needs with default
service account tokens. That’s a potential vulnerability
waiting to happen. This also means that there are controls
outside of Linkerd, to manage this service token, which
users might want to use, causing problems with Linkerd as
Linkerd might expect it to be present to do the
veri�cation. Users can also explicitly disable the token
auto-mount on their pods causing problems with Linkerd.
As of Linkerd 2.11, we skip pod injection if the token automount is disabled.
To address these challenges, starting from edge-21.11.1
we have added the support for auto-mount bound service
account tokens. Instead of using the token that is
mounted by default, Linkerd will request its own set of
tokens by using the Bound Service Account Tokens
feature. Bound Service Account Tokens (GA as of in
Kubernetes v1.20) feature allows components to request
tokens for a speci�c service account on demand from the
API server that are bound to a speci�c purpose (instead of
the default, which is used to access the API server).
Using this, Linkerd injector will request for a token that is
bound speci�cally for Linkerd, along with a 24h expiry (just
like that of identity expiration). This token is generated for
the same service account that was mounted to the pod by
Kubernetes, and thus does not a�ect any of Linkerd’s

2/27/26, 3:46 PM

Using Kubernetes's new Bound Service Account Tokens for ...

8 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

existing functionality around identity and policy discussed
above.
spec:
containers:
...
volumeMounts:
- name: linkerd-identity-token
mountPath: /var/run/secrets/kubernetes.io/serviceaccount
...
volumes:
- name: linkerd-identity-token
projected:
defaultMode: 420
sources:
- serviceAccountToken:
audience: identity.l5d.io
expirationSeconds: 86400
path: linkerd-identity-token

As you can this token is speci�cally generated for Linkerd
for the proxies to verify themselves with identity, and
cannot be used talk to the Kubernetes API, giving us a nice
separation of concerns.

Conclusion
In this post, we described the motivation for moving to
Kubernetes’s new bound service account tokens, which
reduce the scope of Linkerd’s access to the Kubernetes API
to the bare minimum necessary to support its security
features. We also uncovered some of the inner workings
of how the control plane validates the proxies before
issuing the certi�cates, and saw how Linkerd uses
Kubernetes’s service accounts as a primitive to build
features like authorization policy.

2/27/26, 3:46 PM

Using Kubernetes's new Bound Service Account Tokens for ...

9 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

Our goal with Linkerd is to provide world-class security for
Kubernetes users without imposing a burden on them. By
relying on service accounts, we can provide on-by-default
mutual TLS with zero con�g for all meshed pods, the
moment you install Linkerd. And with bound service
accounts, the implementation is even more secure than
before.

Linkerd is for everyone
Linkerd is a graduated project of the Cloud Native
Computing Foundation. Linkerd is committed to open
governance. If you have feature requests, questions, or
comments, we’d love to have you join our rapidly-growing
community! Linkerd is hosted on GitHub, and we have a
thriving community on Slack, Twitter, and the mailing lists.
Come and join the fun!

Linkerd was originally created by Buoyant
View Code of Conduct

Community

Follow

GitHub

Linkedin

Slack

YouTube

Linkerd Forum

Twitter

2/27/26, 3:46 PM

Using Kubernetes's new Bound Service Account Tokens for ...

10 of 10

https://linkerd.io/2021/12/28/using-kubernetess-new-bound-...

Edit This Site
Copyright © 2026 Linkerd Authors. All rights reserved.

2/27/26, 3:46 PM

