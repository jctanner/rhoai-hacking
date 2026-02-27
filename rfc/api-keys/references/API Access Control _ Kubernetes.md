# API Access Control _ Kubernetes

**Source:** `API Access Control _ Kubernetes.pdf`

---

API Access Control | Kubernetes

1 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• 1: Authenticating
• 2: Authenticating with Bootstrap Tokens
• 3: Authorization
• 4: Using RBAC Authorization
• 5: Using Node Authorization
• 6: Webhook Mode
• 7: Using ABAC Authorization
• 8: Admission Control in Kubernetes
• 9: Dynamic Admission Control
• 10: Managing Service Accounts
• 11: User Impersonation
• 12: Certi�cates and Certi�cate Signing Requests
• 13: Mapping PodSecurityPolicies to Pod Security Standards
• 14: Kubelet authentication/authorization
• 15: TLS bootstrapping
• 16: Mutating Admission Policy
• 17: Validating Admission Policy
For an introduction to how Kubernetes implements and controls API access, read
Controlling Access to the Kubernetes API.
Reference documentation:
• Authenticating
◦ Authenticating with Bootstrap Tokens
• Admission Controllers
◦ Dynamic Admission Control
• Authorization
◦ Role Based Access Control
◦ Attribute Based Access Control
◦ Node Authorization
◦ Webhook Authorization
• Certi�cate Signing Requests
◦ including CSR approval and certi�cate signing
• Service accounts
◦ Developer guide
◦ Administration
• Kubelet Authentication & Authorization
◦ including kubelet TLS bootstrapping

2/27/26, 3:33 PM

API Access Control | Kubernetes

2 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

This page provides an overview of authentication in Kubernetes, with a
focus on authentication to the Kubernetes API.

Users in Kubernetes
All Kubernetes clusters have two categories of users: service accounts
managed by Kubernetes, and normal users.
It is assumed that a cluster-independent service manages normal users
in the following ways:
• an administrator distributing private keys
• a user store like Keystone or Google Accounts
• a �le with a list of usernames and passwords
In this regard, Kubernetes does not have objects which represent normal
user accounts. Normal users cannot be added to a cluster through an API
call.
Even though a normal user cannot be added via an API call, any user that
presents a valid certi�cate signed by the cluster's certi�cate authority
(CA) is considered authenticated. In this con�guration, Kubernetes
determines the username from the common name �eld in the 'subject' of
the cert (e.g., "/CN=bob"). From there, the role based access control
(RBAC) sub-system would determine whether the user is authorized to
perform a speci�c operation on a resource.
In contrast, service accounts are users managed by the Kubernetes API.
They are bound to speci�c namespaces, and created automatically by the
API server or manually through API calls. Service accounts are tied to a
set of credentials stored as Secrets , which are mounted into pods
allowing in-cluster processes to talk to the Kubernetes API.
API requests are tied to either a normal user or a service account, or are
treated as anonymous requests. This means every process inside or
outside the cluster, from a human user typing kubectl on a workstation,
to kubelets on nodes, to members of the control plane, must
authenticate when making requests to the API server, or be treated as an
anonymous user.

Authentication strategies
Kubernetes uses client certi�cates, bearer tokens, or an authenticating
proxy to authenticate API requests through authentication plugins. As
HTTP requests are made to the API server, plugins attempt to associate
the following attributes with the request:
• Username: a string which identi�es the end user. Common values
might be kube-admin or jane@example.com .
• UID: a string which identi�es the end user and attempts to be more
consistent and unique than username.
• Groups: a set of strings, each of which indicates the user's
membership in a named logical collection of users. Common values
might be system:masters or devops-team .
• Extra �elds: a map of strings to list of strings which holds additional
information authorizers may �nd useful.

2/27/26, 3:33 PM

API Access Control | Kubernetes

3 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

All values are opaque to the authentication system and only hold
signi�cance when interpreted by an authorizer.

Anonymous requests
When enabled, requests that are not rejected by other con�gured
authentication methods are treated as anonymous requests, and given a
username of system:anonymous and a group of
system:unauthenticated .

For example, on a server with token authentication con�gured, and
anonymous access enabled, a request providing an invalid bearer token
would receive a 401 Unauthorized error. A request providing no bearer
token would be treated as an anonymous request.
Anonymous access is enabled by default if an authorization mode other
than AlwaysAllow is used; you can disable it by passing the -anonymous-auth=false command line option to the API server. The built-

in ABAC and RBAC authorizers require explicit authorization of the
system:anonymous user or the system:unauthenticated group; if you

have legacy policy rules (from Kubernetes version 1.5 or earlier), those
legacy rules that grant access to the * user or * group do not
automatically allow access to anonymous users.

Anonymous authenticator con�guration
Kubernetes v1.34 [stable](enabled by

ⓘ

default)
The AuthenticationConfiguration can be used to con�gure the
anonymous authenticator. If you set the anonymous �eld in the
AuthenticationConfiguration �le then you cannot set the -anonymous-auth command line option.

The main advantage of con�guring anonymous authenticator using the
authentication con�guration �le is that in addition to enabling and
disabling anonymous authentication you can also con�gure which
endpoints support anonymous authentication.
A sample authentication con�guration �le is below:

--#
# CAUTION: this is an example configuration.
#

Do not use this as-is for your own cluster!

#
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
anonymous:
enabled: true
conditions:
- path: /livez
- path: /readyz
- path: /healthz

In the con�guration above, only the /livez , /readyz and /healthz

2/27/26, 3:33 PM

API Access Control | Kubernetes

4 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

endpoints are reachable by anonymous requests. Any other endpoints
will not be reachable anonymously, even if your authorization
con�guration would allow it.

Authentication methods
You can enable multiple authentication methods at once. You should
usually use at least two methods:
• service account tokens for service accounts
• at least one other method for user authentication.
When multiple authenticator modules are enabled, the �rst module to
successfully authenticate the request short-circuits evaluation. The API
server does not guarantee the order authenticators run in.
The system:authenticated group is included in the list of groups for all
authenticated users.
Integrations with other authentication protocols (LDAP, SAML, Kerberos,
alternate x509 schemes, etc) are available; for example using an
authenticating proxy or the authentication webhook.

X.509 client certi�cates
Any Kubernetes client that presents a valid client certi�cate signed by the
cluster's client trust certi�cate authority (CA) is considered authenticated.
In this con�guration, Kubernetes determines the username from the
commonName �eld in the subject of the certi�cate (for example,
commonName=bob represents a user with username "bob"). From there,

Kubernetes authorization mechanisms determine whether the user is
allowed to perform a speci�c operation on a resource.
Client certi�cate authentication is enabled by passing the --client-cafile=<SOMEFILE> option to the API server. This option con�gures the

cluster's client trust certi�cate authority. The referenced �le must contain
one or more certi�cate authorities that the API server can use, when it
needs to validate client certi�cates. If a client certi�cate is presented and
veri�ed, the common name of the subject is used as the user name for
the request. Client certi�cates can also indicate a user's group
memberships using the certi�cate's organization �elds. To include
multiple group memberships for a user, include multiple organization
�elds in the certi�cate.
See Managing Certi�cates for how to generate a client cert, or read the
brief example later in this page.

Kubernetes-compatible client certi�cates
You can present a valid certi�cate, issued by a CA in a trust chain that the
API server accepts for client certi�cates, and use that to authenticate to
Kubernetes. The certi�cate must be valid; the API server checks that
based on the X.509 notBefore and notAfter attributes, and the
certi�cate must have an extended key usage that includes client
authentication ( ClientAuth ).

Kubernetes 1.35 does not support certi�cate revocation. Any
certi�cate that is issued remains valid until it expires.

2/27/26, 3:33 PM

API Access Control | Kubernetes

5 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Username mapping
Kubernetes expects a client certi�cate that contains a commonName (OID
2.5.4.3 ) attribute, that is used as the username of the subject.

User ID mapping
ⓘ

Kubernetes v1.34 [beta](enabled by

default)
To use this feature, the certi�cate must have the attribute
1.3.6.1.4.1.57683.2 included, and the
AllowParsingUserUIDFromCertAuth feature gate must be enabled (it is on

by default).
Kubernetes can parse an

user UID from a certi�cate. UID is
di�erent from user name; it is an opaque value with a meaning de�ned
by the person who requested the certi�cate, or alternatively by whoever
has set the certi�cate approval rules.
For example, the UID could be 1042 (a simple integer) in one cluster, but
another certi�cate might use d3f77937-ec82-4f16-8010-61821abe315a (a
UUID) as the UID.
Here is an example to explain what that means. If you have a certi�cate
with the common name set to "Ada Lovelace" and the certi�cate also had
a uid attribute, (OID 0.9.2342.19200300.100.1.1 ) with uid set to
"aaking1815", Kubernetes considers that the client's username is "Ada
Lovelace"; Kubernetes ignores the uid attribute because it is not the
CNCF-speci�c OID that Kubernetes looks for. If you wanted aaking1815
to be recognized as UID by Kubernetes, it must be set as a value to the
OID 1.3.6.1.4.1.57683.2 attribute in the certi�cate's subject.

Group mapping
You can map a user into groups by statically including group information
into the certi�cate. For each group that the user is a member of, add the
group name as an organization (OID 2.5.6.4 ) in your certi�cate's
subject. To include multiple group memberships for a user, include
multiple organizations in the certi�cate subject (the order does not
matter). For the example user, the distinguished name for a certi�cate
might be CN=Ada Lovelace,O=Users,O=Sta�,O=Programmers, which
would place her into the groups "Programmers", "Sta�",
"system:authenticated", and "Users".
Putting group information into a certi�cate is optional; if you don't
specify any groups in the certi�cate, then the user will be a member of
"system:authenticated" only.

Node client certi�cates
Kubernetes can use the same approach for node identity; nodes are
clients of the Kubernetes API server that run a kubelet (also, although
less relevant here, the API server is usually also a client of each node). For
example: a Node "server-1a-antarctica42", with the domain name
"server-1a-antarctica42.cluster.example", could use a certi�cate issued to
"CN=system:node:server-1a-antarctica/42,O=system:nodes". The node's
username is then "system:node:server-1a-antarctica/g42", and the node
is a member of "system:authenticated" and "system:nodes".
The kubelet uses the node's certi�cate and private key to authenticate to

2/27/26, 3:33 PM

API Access Control | Kubernetes

6 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

the cluster's API server.

Machine identities for nodes are not the same as ServiceAccounts.

Example
You could use the openssl command line tool to generate a certi�cate
signing request:

# This example assumes that you already have a private key alovelace.pem
openssl req -new -key alovelace.pem -out alovelace-csr.pem -subj

This would create a signing request for the username "alovelace",
belonging to two groups, "app1" and "app2". You could then have that
signing request be signed by your cluster's client trust certi�cate
authority to obtain a certi�cate you can use for client authentication to
your cluster.

Bootstrap tokens
ⓘ

Kubernetes v1.18 [stable]

To allow for streamlined bootstrapping for new clusters, Kubernetes
includes a dynamically-managed Bearer token type called a Bootstrap
Token. These tokens are stored as Secrets in the kube-system
namespace, where they can be dynamically managed and created.
Controller Manager contains a TokenCleaner controller that deletes
bootstrap tokens as they expire.
The tokens are of the form [a-z0-9]{6}.[a-z0-9]{16} . The �rst
component is a Token ID and the second component is the Token Secret.
You specify the token in an HTTP header as follows:

Authorization: Bearer 781292.db7bc3a58fc5f07e

You must enable the Bootstrap Token Authenticator with the --enablebootstrap-token-auth �ag on the API Server. You must enable the

TokenCleaner controller via the --controllers command line argument
for kube-controller-manager. This is done with something like -controllers=*,tokencleaner . The kubeadm tool will do this for you if you

are using it to bootstrap a cluster.
The authenticator authenticates as system:bootstrap:<Token ID> . It is
included in the system:bootstrappers group. The naming and groups
are intentionally limited to discourage users from using these tokens past
bootstrapping. The user names and group can be used (and are used by
kubeadm ) to craft the appropriate authorization policies to support
bootstrapping a cluster.
Please see Bootstrap Tokens for in depth documentation on the
Bootstrap Token authenticator and controllers along with how to manage
these tokens with kubeadm .

Putting a bearer token in a request
2/27/26, 3:33 PM

API Access Control | Kubernetes

7 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

When using bearer token authentication from an HTTP client, the API
server expects an Authorization header with a value of Bearer
<token> . The bearer token must be a character sequence that can be put

in an HTTP header value using no more than the encoding and quoting
facilities of HTTP. For example: if the bearer token is 31ada4fdadec-460c-809a-9e56ceb75269 then it would appear in an HTTP header as

shown below.

Authorization: Bearer 31ada4fd-adec-460c-809a-9e56ceb75269

Service account tokens
A service account is an automatically enabled authenticator that uses
signed bearer tokens to verify requests. The plugin takes two optional
�ags:
• --service-account-key-file File containing PEM-encoded x509
RSA or ECDSA private or public keys, used to verify ServiceAccount
tokens. The speci�ed �le can contain multiple keys, and the �ag can
be speci�ed multiple times with di�erent �les. If unspeci�ed, --tlsprivate-key-�le is used.
• --service-account-lookup If enabled, tokens which are deleted
from the API will be revoked.
Service accounts are usually created automatically by the API server and
associated with pods running in the cluster through the ServiceAccount
Admission Controller. Bearer tokens are mounted into pods at wellknown locations, and allow in-cluster processes to talk to the API server.
Accounts may be explicitly associated with pods using the
serviceAccountName �eld of a PodSpec .

serviceAccountName is usually omitted because this is done

automatically.

apiVersion: apps/v1 # this apiVersion is relevant as of Kubernetes 1.9
kind: Deployment
metadata:
name: nginx-deployment
namespace: default
spec:
replicas: 3
template:
metadata:
# ...
spec:
serviceAccountName: bob-the-bot
containers:
- name: nginx
image: nginx:1.14.2

Service account bearer tokens are perfectly valid to use outside the
cluster and can be used to create identities for long standing jobs that
wish to talk to the Kubernetes API. To manually create a service account,
use the kubectl create serviceaccount (NAME) command. This creates
a service account in the current namespace.

2/27/26, 3:33 PM

API Access Control | Kubernetes

8 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

kubectl create serviceaccount jenkins

serviceaccount/jenkins created

You can manually create an associated token:

kubectl create token jenkins

eyJhbGciOiJSUzI1NiIsImtp...

The created token is a signed JSON Web Token (JWT).
The signed JWT can be used as a bearer token to authenticate as the
given service account. See above for how the token is included in a
request. Normally these tokens are mounted into pods for in-cluster
access to the API server, but can be used from outside the cluster as well.
Service accounts authenticate with the username
system:serviceaccount:(NAMESPACE):(SERVICEACCOUNT) , and are

assigned to the groups system:serviceaccounts and
system:serviceaccounts:(NAMESPACE) .

Because service account tokens can also be stored in Secret API
objects, any user with write access to Secrets can request a token,
and any user with read access to those Secrets can authenticate as
the service account. Be cautious when granting permissions to
service accounts and read or write capabilities for Secrets.

External integrations
Kubernetes has native support for JWT and for OpenID Connect (OIDC);
see JSON Web Token authentication.
Integrations with other authentication protocols (for example: LDAP,
SAML, Kerberos, alternate X.509 schemes) can be accomplished using an
authenticating proxy or by integrating with an authentication webhook.
You can also use any custom method that issues client X.509 certi�cates
to clients, provided that the API server will trust the valid certi�cates.
Read X.509 client certi�cates to learn about how to generate a certi�cate.
If you do issue certi�cates to clients, it is up to you (as a cloud platform
administrator) to make sure that the certi�cate validity period, and other
design choices you make, provide a suitable level of security.

JSON Web Token authentication
You can con�gure Kubernetes to authenticate users using JSON Web
Token (JWT) compliant tokens. JWT authentication mechanism is used for
the ServiceAccount tokens that Kubernetes itself issues, and you can also
use it to integrate with other identity sources.
The authenticator attempts to parse a raw ID token, verify it's been
signed by the con�gured issuer. For externally issued tokens, the public
2/27/26, 3:33 PM

API Access Control | Kubernetes

9 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

key to verify the signature is discovered from the issuer's public endpoint
using OIDC discovery.
The minimum valid JWT payload

contain the following claims:

{
"iss": "https://example.com",
"aud": ["my-app"],
"exp": 1234567890,
"<username-claim>": "user"

// must match the issuer.url
// at least one of the entries in issuer.audie
// token expiration as Unix time (the number o
// this is the username claim configured in th

}

JWT egress selector type
Kubernetes v1.34 [beta](enabled by

ⓘ

default)
The egressSelectorType �eld in the JWT issuer con�guration allows you
to specify which egress selector should be used for sending all tra�c
related to the issuer (discovery, JWKS, distributed claims, etc). This
feature requires the
StructuredAuthenticationConfigurationEgressSelector feature gate to
be enabled.

OpenID Connect tokens
OpenID Connect is a �avor of OAuth2 supported by some OAuth2
providers, notably Microsoft Entra ID, Salesforce, and Google. The
protocol's main extension of OAuth2 is an additional �eld returned with
the access token called an ID Token. This token is a JSON Web Token
(JWT) with well known �elds, such as a user's email, signed by the server.
To identify the user, the authenticator uses the id_token (not the
access_token ) from the OAuth2 token response as a bearer token. See

above for how the token is included in a request.
sequenceDiagram participant user as User participant idp as Identity
Provider participant kube as kubectl participant api as API Server user ->>
idp: 1. Log in to IdP activate idp idp -->> user: 2. Provide access_token,
id_token, and refresh_token deactivate idp activate user user ->> kube: 3.
Call kubectl
with --token being the id_token
OR add tokens to .kube/con�g deactivate user activate kube kube ->> api:
4. Authorization: Bearer... deactivate kube activate api api ->> api: 5. Is
JWT signature valid? api ->> api: 6. Has the JWT expired? (iat+exp) api ->>
api: 7. User authorized? api -->> kube: 8. Authorized: Perform
action and return result deactivate api activate kube kube --x user: 9.
Return result deactivate kube
1. Log in to your identity provider
2. Your identity provider will provide you with an access_token ,
id_token and a refresh_token

3. When using kubectl , use your id_token with the --token
command line argument or add it directly to your kubeconfig
4. kubectl sends your id_token in a header called Authorization to
the API server

2/27/26, 3:33 PM

API Access Control | Kubernetes

10 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

5. The API server will make sure the JWT signature is valid
6. Check to make sure the id_token hasn't expired
Perform claim and/or user validation if CEL expressions are
con�gured with AuthenticationConfiguration .
7. Make sure the user is authorized
8. Once authorized the API server returns a response to kubectl
9. kubectl provides feedback to the user
Since all of the data needed to validate who you are is in the id_token ,
Kubernetes doesn't need to "phone home" to the identity provider. In a
model where every request is stateless this provides a very scalable
solution for authentication. It does o�er a few challenges:
1. Kubernetes has no "web interface" to trigger the authentication
process. There is no browser or interface to collect credentials
which is why you need to authenticate to your identity provider
�rst.
2. The id_token can't be revoked, it's like a certi�cate so it should be
short-lived (only a few minutes) so it can be very annoying to have
to get a new token every few minutes.
3. To authenticate to the Kubernetes dashboard, you must use the
kubectl proxy command or a reverse proxy that injects the
id_token .

Con�guring the API Server
Using command line arguments
To enable the plugin, con�gure the following command line arguments
for the API server:

--oidcissuerurl

URL of the provider
that allows the API
server to discover
public signing keys.
Only URLs that use
the https://
scheme are
accepted. This is
typically the
provider's discovery
URL, changed to
have an empty path.

--oidcclientid

A client id that all
tokens must be
issued for.

If the issuer's OIDC discovery URL is
https://

Yes

accounts.provider.example/.well
-known/openid-configuration , the
value should be https://
accounts.provider.example

kubernetes

Yes

2/27/26, 3:33 PM

API Access Control | Kubernetes

11 of 200

--oidcusername
-claim

https://kubernetes.io/docs/reference/access-authn-authz/_print/

JWT claim to use as
the user name. By
default sub , which

sub

No

oidc:

No

groups

No

is expected to be a
unique identi�er of
the end user. Admins
can choose other
claims, such as
email or name ,
depending on their
provider. However,
claims other than
email will be
pre�xed with the
issuer URL to
prevent naming
clashes with other
plugins.

--oidcusername
-prefix

Pre�x prepended to
username claims to
prevent clashes with
existing names (such
as system: users).
For example, the
value oidc: will
create usernames
like
oidc:jane.doe . If
this argument isn't
provided and -oidc-usernameclaim is a value
other than email
the pre�x defaults to
( Issuer URL )#
where ( Issuer
URL ) is the value
of --oidcissuer-url . The
value - can be
used to disable all
pre�xing.

--oidcgroupsclaim

JWT claim to use as
the user's group. If
the claim is present it
must be an array of
strings.

2/27/26, 3:33 PM

API Access Control | Kubernetes

12 of 200

--oidcgroupsprefix

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Pre�x prepended to
group claims to
prevent clashes with
existing names (such
as system:

oidc:

No

A key=value pair that
describes a required
claim in the ID
Token. If set, the
claim is veri�ed to be
present in the ID
Token with a
matching value.
Repeat this
argument to specify
multiple claims.

claim=value

No

The path to the
certi�cate for the CA
that signed your
identity provider's
web certi�cate.
Defaults to the host's
root CAs.

/etc/kubernetes/ssl/kc-ca.pem

No

The signing
algorithms accepted.
Default is RS256.
Allowed values are:
RS256, RS384, RS512,
ES256, ES384, ES512,
PS256, PS384, PS512.
Values are de�ned
by RFC 7518 https://

RS512

No

groups). For
example, the value
oidc: will create
group names like
oidc:engineerin
g and
oidc:infra .
--oidcrequired
-claim

--oidcca-file

--oidcsigningalgs

tools.ietf.org/html/
rfc7518#section-3.1.

Authentication con�guration from a �le
ⓘ

Kubernetes v1.34 [stable](enabled by

default)
The con�guration �le approach allows you to con�gure multiple JWT
authenticators, each with a unique issuer.url and
issuer.discoveryURL . The con�guration �le even allows you to specify

CEL expressions to map claims to user attributes, and to validate claims
and user information. The API server also automatically reloads the
authenticators when the con�guration �le is modi�ed. You can use

2/27/26, 3:33 PM

API Access Control | Kubernetes

13 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiserver_authentication_config_controller_automatic_reload_last_
timestamp_seconds metric to monitor the last time the con�guration was

reloaded by the API server.
You must specify the path to the authentication con�guration using the
--authentication-config command line argument to the API server. If

you want to use command line arguments instead of the con�guration
�le, those will continue to work as-is. To access the new capabilities like
con�guring multiple authenticators, setting multiple audiences for an
issuer, switch to using the con�guration �le.
To use structured authentication, specify the --authentication-config
command line argument to the kube-apiserver. An example of the
structured authentication con�guration �le is shown below.

If you specify --authentication-config along with any of the -oidc-* command line arguments, this is a miscon�guration. In this

situation, the API server reports an error and then immediately
exits. If you want to switch to using structured authentication
con�guration, you have to remove the --oidc-* command line
arguments, and use the con�guration �le instead.

2/27/26, 3:33 PM

API Access Control | Kubernetes

14 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

--#
# CAUTION: this is an example configuration.
#

Do not use this for your own cluster!

#
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
# list of authenticators to authenticate Kubernetes users using JWT compliant to
# the maximum number of allowed authenticators is 64.
jwt:
- issuer:
# url must be unique across all authenticators.
# url must not conflict with issuer configured in --service-account-issuer.
url: https://example.com # Same as --oidc-issuer-url.
# discoveryURL, if specified, overrides the URL used to fetch discovery
# information instead of using "{url}/.well-known/openid-configuration".
# The exact value specified is used, so "/.well-known/openid-configuration"
# must be included in discoveryURL if needed.
#
# The "issuer" field in the fetched discovery information must match the "is
# in the AuthenticationConfiguration and will be used to validate the "iss"
# This is for scenarios where the well-known and jwks endpoints are hosted a
# location than the issuer (such as locally in the cluster).
# discoveryURL must be different from url if specified and must be unique ac
discoveryURL: https://discovery.example.com/.well-known/openid-configuration
# PEM encoded CA certificates used to validate the connection when fetching
# discovery information. If not set, the system verifier will be used.
# Same value as the content of the file referenced by the --oidc-ca-file com
certificateAuthority: <PEM encoded CA certificates>
# audiences is the set of acceptable audiences the JWT must be issued to.
# At least one of the entries must match the "aud" claim in presented JWTs.
audiences:
- my-app # Same as --oidc-client-id.
- my-other-app
# this is required to be set to "MatchAny" when multiple audiences are speci
audienceMatchPolicy: MatchAny
# egressSelectorType is an indicator of which egress selection should be use
# to this issuer (discovery, JWKS, distributed claims, etc).

If unspecified

# The StructuredAuthenticationConfigurationEgressSelector feature gate must
# before you can use the egressSelectorType field.
# When specified, the valid choices are "controlplane" and "cluster".

These

# values in the --egress-selector-config-file.
# - controlplane: for traffic intended to go to the control plane.
# - cluster: for traffic intended to go to the system being managed by Kuber
egressSelectorType: <egress-selector-type>
# rules applied to validate token claims to authenticate users.
claimValidationRules:
# Same as --oidc-required-claim key=value.
- claim: hd
requiredValue: example.com
# Instead of claim and requiredValue, you can use expression to validate the
# expression is a CEL expression that evaluates to a boolean.
# all the expressions must evaluate to true for validation to succeed.
- expression: 'claims.hd == "example.com"'
# Message customizes the error message seen in the API server logs when the
message: the hd claim must be set to example.com
- expression: 'claims.exp - claims.nbf <= 86400'
message: total token lifetime must not exceed 24 hours
claimMappings:
# username represents an option for the username attribute.
# This is the only required attribute.
username:
# Same as --oidc-username-claim. Mutually exclusive with username.expressi
claim: "sub"
# Same as --oidc-username-prefix. Mutually exclusive with username.express
# if username.claim is set, username.prefix is required.
2/27/26, 3:33 PM

API Access Control | Kubernetes

15 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

# Explicitly set it to "" if no prefix is desired.
prefix: ""
# Mutually exclusive with username.claim and username.prefix.
# expression is a CEL expression that evaluates to a string.
#
# 1.

If username.expression uses 'claims.email', then 'claims.email_verif

#

username.expression or extra[*].valueExpression or claimValidationRu

#

An example claim validation rule expression that matches the validat

#

applied when username.claim is set to 'email' is 'claims.?email_veri

#

By explicitly comparing the value to true, we let type-checking see

#

to make sure a non-boolean email_verified claim will be caught at ru

# 2.

If the username asserted based on username.expression is the empty s

#

request will fail.

expression: 'claims.username + ":external-user"'
# groups represents an option for the groups attribute.
groups:
# Same as --oidc-groups-claim. Mutually exclusive with groups.expression.
claim: "sub"
# Same as --oidc-groups-prefix. Mutually exclusive with groups.expression.
# if groups.claim is set, groups.prefix is required.
# Explicitly set it to "" if no prefix is desired.
prefix: ""
# Mutually exclusive with groups.claim and groups.prefix.
# expression is a CEL expression that evaluates to a string or a list of s
expression: 'claims.roles.split(",")'
# uid represents an option for the uid attribute.
uid:
# Mutually exclusive with uid.expression.
claim: 'sub'
# Mutually exclusive with uid.claim
# expression is a CEL expression that evaluates to a string.
expression: 'claims.sub'
# extra attributes to be added to the UserInfo object. Keys must be domain-p
extra:
# key is a string to use as the extra attribute key.
# key must be a domain-prefix path (e.g. example.org/foo). All characters
# subdomain as defined by RFC 1123. All characters trailing the first "/"
# be valid HTTP Path characters as defined by RFC 3986.
# k8s.io, kubernetes.io and their subdomains are reserved for Kubernetes u
# key must be lowercase and unique across all extra attributes.
- key: 'example.com/tenant'
# valueExpression is a CEL expression that evaluates to a string or a list
valueExpression: 'claims.tenant'
# validation rules applied to the final user object.
userValidationRules:
# expression is a CEL expression that evaluates to a boolean.
# all the expressions must evaluate to true for the user to be valid.
- expression: "!user.username.startsWith('system:')"
# Message customizes the error message seen in the API server logs when the
message: 'username cannot used reserved system: prefix'
- expression: "user.groups.all(group, !group.startsWith('system:'))"
message: 'groups cannot used reserved system: prefix'

• Claim validation rule expression
jwt.claimValidationRules[i].expression represents the

expression which will be evaluated by CEL. CEL expressions have
access to the contents of the token payload, organized into claims
CEL variable. claims is a map of claim names (as strings) to claim
values (of any type).
• User validation rule expression
jwt.userValidationRules[i].expression represents the

expression which will be evaluated by CEL. CEL expressions have
access to the contents of userInfo , organized into user CEL

2/27/26, 3:33 PM

API Access Control | Kubernetes

16 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

variable. Refer to the UserInfo API documentation for the schema of
user .
• Claim mapping expression
jwt.claimMappings.username.expression ,
jwt.claimMappings.groups.expression ,
jwt.claimMappings.uid.expression
jwt.claimMappings.extra[i].valueExpression represents the

expression which will be evaluated by CEL. CEL expressions have
access to the contents of the token payload, organized into claims
CEL variable. claims is a map of claim names (as strings) to claim
values (of any type).
To learn more, see the Documentation on CEL
Here are examples of the AuthenticationConfiguration with
di�erent token payloads.
Valid token

Fails claim validation

Fails user validation

apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt:
- issuer:
url: https://example.com
audiences:
- my-app
claimMappings:
username:
expression: 'claims.username + ":external-user"'
groups:
expression: 'claims.roles.split(",")'
uid:
expression: 'claims.sub'
extra:
- key: 'example.com/tenant'
valueExpression: 'claims.tenant'
userValidationRules:
- expression: "!user.username.startsWith('system:')"
message: 'username cannot used reserved system

TOKEN=eyJhbGciOiJSUzI1NiIsImtpZCI6ImY3dF9tOEROWmFTQk1oWGw5QX

where the token payload is:
{
"aud": "kubernetes",
"exp": 1703232949,
"iat": 1701107233,
"iss": "https://example.com",
"jti": "7c337942807e73caa2c30c868ac0ce910bce02ddcbfebe8c
"nbf": 1701107233,
"roles": "user,admin",
"sub": "auth",
"tenant": "72f988bf-86f1-41af-91ab-2d7cd011db4a"
"username": "foo"
}

The token with the above
AuthenticationConfiguration will produce the

following UserInfo object and successfully
authenticate the user.

2/27/26, 3:33 PM

API Access Control | Kubernetes

17 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"username": "foo:external-user",
"uid": "auth",
"groups": [
"user",
"admin"
],
"extra": {
"example.com/tenant": ["72f988bf-86f1-41af-91ab-2d7c
}
}

Limitations
1. Distributed claims do not work via CEL expressions.
Kubernetes does not provide an OpenID Connect Identity Provider. You
can use an existing public OpenID Connect Identity Provider or run your
own Identity Provider that supports the OpenID Connect protocol.
For an identity provider to work with Kubernetes it must:
1. Support OpenID connect discovery
The public key to verify the signature is discovered from the issuer's
public endpoint using OIDC discovery. If you're using the
authentication con�guration �le, the identity provider doesn't need
to publicly expose the discovery endpoint. You can host the
discovery endpoint at a di�erent location than the issuer (such as
locally in the cluster) and specify the issuer.discoveryURL in the
con�guration �le.
2. Run in TLS with non-obsolete ciphers
3. Have a CA signed certi�cate (even if the CA is not a commercial CA
or is self signed)
A note about requirement #3 above, requiring a CA signed certi�cate. If
you deploy your own identity provider you MUST have your identity
provider's web server certi�cate signed by a certi�cate with the CA �ag
set to TRUE , even if it is self signed. This is due to GoLang's TLS client
implementation being very strict to the standards around certi�cate
validation. If you don't have a CA handy, you can create a simple CA and a
signed certi�cate and key pair using standard certi�cate generation tools.

Using kubectl
Option 1 - OIDC authenticator
The �rst option is to use the kubectl oidc authenticator, which sets the
id_token as a bearer token for all requests and refreshes the token

once it expires. After you've logged into your provider, use kubectl to add
your id_token , refresh_token , client_id , and client_secret to
con�gure the plugin.
Providers that don't return an id_token as part of their refresh token
response aren't supported by this plugin and should use Option 2
(specifying --token ).

2/27/26, 3:33 PM

API Access Control | Kubernetes

18 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

kubectl config set-credentials USER_NAME \
--auth-provider=oidc \
--auth-provider-arg=idp-issuer-url=( issuer url ) \
--auth-provider-arg=client-id=( your client id ) \
--auth-provider-arg=client-secret=( your client secret ) \
--auth-provider-arg=refresh-token=( your refresh token ) \
--auth-provider-arg=idp-certificate-authority=( path to your ca certificate
--auth-provider-arg=id-token=( your id_token )

As an example, running the below command after authenticating to your
identity provider:

kubectl config set-credentials mmosley \
--auth-provider=oidc \
--auth-provider-arg=idp-issuer-url=https://oidcidp.tremolo.lan:8443/auth
--auth-provider-arg=client-id=kubernetes \
--auth-provider-arg=client-secret=1db158f6-177d-4d9c-8a8b-d36869918ec5
--auth-provider-arg=refresh-token=q1bKLFOyUiosTfawzA93TzZIDzH2TNa2SMm0zE
--auth-provider-arg=idp-certificate-authority=/root/ca.pem
--auth-provider-arg=id-token=eyJraWQiOiJDTj1vaWRjaWRwLnRyZW1vbG8ubGFuLCB

Which would produce the below con�guration:

users:
- name: mmosley
user:
auth-provider:
config:
client-id: kubernetes
client-secret: 1db158f6-177d-4d9c-8a8b-d36869918ec5
id-token: eyJraWQiOiJDTj1vaWRjaWRwLnRyZW1vbG8ubGFuLCBPVT1EZW1vLCBPPVRybW
idp-certificate-authority: /root/ca.pem
idp-issuer-url: https://oidcidp.tremolo.lan:8443/auth/idp/OidcIdP
refresh-token: q1bKLFOyUiosTfawzA93TzZIDzH2TNa2SMm0zEiPKTUwME6BkEo6Sql5y
name: oidc

Once your id_token expires, kubectl will attempt to refresh your
id_token using your refresh_token and client_secret storing the

new values for the refresh_token and id_token in your .kube/config .

Option 2 - Use the --token command line argument
The kubectl command lets you pass in a token using the --token
command line argument. Copy and paste the id_token into this option:

kubectl --token=eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL21sYi50cmVtb2xvLmxhbjo

Webhook token authentication
Kubernetes webhook authentication is a mechanism to make an HTTP
callout for verifying bearer tokens.
In terms of how you con�gure the API server:
• --authentication-token-webhook-config-file a con�guration �le
describing how to access the remote webhook service.
• --authentication-token-webhook-cache-ttl how long to cache
2/27/26, 3:33 PM

API Access Control | Kubernetes

19 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

authentication decisions. Defaults to two minutes.
• --authentication-token-webhook-version determines whether to
use authentication.k8s.io/v1beta1 or authentication.k8s.io/
TokenReview objects to send/receive information from the

v1

webhook. Defaults to v1beta1 .
The con�guration �le uses the kubecon�g �le format. Within the �le,
clusters refers to the remote service and users refers to the API
server webhook. An example would be:

# Kubernetes API version
apiVersion: v1
# kind of the API object
kind: Config
# clusters refers to the remote service.
clusters:
- name: name-of-remote-authn-service
cluster:
certificate-authority: /path/to/ca.pem

# CA for verifying the remo

server: https://authn.example.com/authenticate # URL of remote service to
# users refers to the API server's webhook configuration.
users:
- name: name-of-api-server
user:
client-certificate: /path/to/cert.pem # cert for the webhook plugin to use
client-key: /path/to/key.pem

# key matching the cert

# kubeconfig files require a context. Provide one for the API server.
current-context: webhook
contexts:
- context:
cluster: name-of-remote-authn-service
user: name-of-api-server
name: webhook

When a client attempts to authenticate with the API server using a bearer
token as discussed above, the authentication webhook POSTs a JSONserialized TokenReview object containing the token to the remote
service.
Note that webhook API objects are subject to the same versioning
compatibility rules as other Kubernetes API objects. Implementers should
check the apiVersion �eld of the request to ensure correct
deserialization, and

respond with a TokenReview object of the

same version as the request.
authentication.k8s.io/v1

authentication.k8s.io/v1beta1

The Kubernetes API server defaults to sending
authentication.k8s.io/v1beta1 token reviews for backwards
compatibility. To opt into receiving authentication.k8s.io/v1
token reviews, the API server must be started with -authentication-token-webhook-version=v1.

2/27/26, 3:33 PM

API Access Control | Kubernetes

20 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"apiVersion": "authentication.k8s.io/v1",
"kind": "TokenReview",
"spec": {
# Opaque bearer token sent to the API server
"token": "014fbff9a07c...",
# Optional list of the audience identifiers for the server the token was
# Audience-aware token authenticators (for example, OIDC token authentic
# should verify the token was intended for at least one of the audiences
# and return the intersection of this list and the valid audiences for t
# This ensures the token is valid to authenticate to the server it was p
# If no audiences are provided, the token should be validated to authent
"audiences": ["https://myserver.example.com", "https://myserver.internal
}
}

The remote service is expected to �ll the status �eld of the request to
indicate the success of the login. The response body's spec �eld is
ignored and may be omitted. The remote service must return a response
using the same TokenReview API version that it received. A successful
validation of the bearer token would return:
authentication.k8s.io/v1

authentication.k8s.io/v1beta1

{
"apiVersion": "authentication.k8s.io/v1",
"kind": "TokenReview",
"status": {
"authenticated": true,
"user": {
# Required
"username": "janedoe@example.com",
# Optional
"uid": "42",
# Optional group memberships
"groups": ["developers", "qa"],
# Optional additional information provided by the authenticator.
# This should not contain confidential data, as it can be recorded in
# or API objects, and is made available to admission webhooks.
"extra": {
"extrafield1": [
"extravalue1",
"extravalue2"
]
}
},
# Optional list audience-aware token authenticators can return,
# containing the audiences from the `spec.audiences` list for which the
# If this is omitted, the token is considered to be valid to authenticat
"audiences": ["https://myserver.example.com"]
}
}

An unsuccessful request would return:
authentication.k8s.io/v1

authentication.k8s.io/v1beta1

2/27/26, 3:33 PM

API Access Control | Kubernetes

21 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"apiVersion": "authentication.k8s.io/v1",
"kind": "TokenReview",
"status": {
"authenticated": false,
# Optionally include details about why authentication failed.
# If no error is provided, the API will return a generic Unauthorized me
# The error field is ignored when authenticated=true.
"error": "Credentials are expired"
}
}

Authenticating reverse proxy

If you have a certi�cate authority (CA) that is also used in a di�erent
context,
trust that certi�cate authority to identify
authenticating proxy clients, unless you understand the risks and
the mechanisms to protect that CA's usage.

The API server can be con�gured to identify users from request header
values, such as X-Remote-User . It is designed for use in combination with
an authenticating proxy that sets these headers.
Using an authenticating reverse proxy is di�erent from user
impersonation. With user impersonation, one user requests the API
server to treat the request as if it were being made by a di�erent user.
With an authenticating reverse proxy, the API server trusts its direct client
to provide information about the identity of the principal making the
original request.
See web request header con�guration to learn about con�guring this
using command line arguments.

Example
For example, with this con�guration:
--requestheader-username-headers=X-Remote-User
--requestheader-group-headers=X-Remote-Group
--requestheader-extra-headers-prefix=X-Remote-Extra-

this request:

GET / HTTP/1.1
X-Remote-User: fido
X-Remote-Group: dogs
X-Remote-Group: dachshunds
X-Remote-Extra-Acme.com%2Fproject: some-project
X-Remote-Extra-Scopes: openid
X-Remote-Extra-Scopes: profile

would result in this user info:

2/27/26, 3:33 PM

API Access Control | Kubernetes

22 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

name: fido
groups:
- dogs
- dachshunds
extra:
acme.com/project:
- some-project
scopes:
- openid
- profile

Client certi�cate
In order to prevent header spoo�ng, the authenticating proxy is required
to present a valid client certi�cate to the API server for validation against
the speci�ed CA before the request headers are checked.
See the command line option reference for request header
authentication mode.
Do
reuse a CA that is used in a di�erent context unless you
understand the risks and the mechanisms to protect the CA's usage.

Static token �le integration
The API server reads static bearer tokens from a �le when given the -token-auth-file=<SOMEFILE> option on the command line. In Kubernetes

1.35, tokens last inde�nitely, and the token list cannot be changed
without restarting the API server.
The token �le is a CSV �le with a minimum of 3 columns: token, user
name, user uid, followed by a comma-separated list of optional group
names.

If you have more than one group, the column must be double
quoted e.g.
token,user,uid,"group1,group2,group3"

Using a static token �le is appropriate for tokens that by their nature are
long-lived, static, and perhaps may never be rotated. It is also useful
when the client is local to a particular API server within the control plane,
such as a monitoring agent.
If you use this method during cluster provisioning, and then transition to
a di�erent authentication method that will be used longer term, you
should deactivate the token that was used for bootstrapping (this
requires a restart of each API server.
For other circumstances, and especially where very prompt token
rotation is important, the Kubernetes project recommends using a
webhook token authenticator instead of this mechanism.

User impersonation
User impersonation provides a method that a user can act as another
user through impersonation headers
2/27/26, 3:33 PM

API Access Control | Kubernetes

23 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Authentication con�guration
You can con�gure Kubernetes authentication either using command line
arguments, or using a con�guration �le.
Typically, you use a mix of these approaches.

Con�guration via command line arguments
You can use the following command line arguments to con�gure how
your cluster's control plane authenticates clients.
The command line reference for the API server describes all of the
relevant command line arguments in more detail.

Anonymous authentication con�guration
--anonymous-auth

Controls whether clients who have not authenticated can make
request via the API server's secure port. Anonymous requests have a
username of system:anonymous, and a group name of
system:unauthenticated. Also see anonymous requests.

Bootstrap token con�guration
--enable-bootstrap-token-auth

When this �ag is set, you can use bootstrap tokens to authenticate.

Certi�cate authentication con�guration
--client-ca-file

The path to the trust anchor(s) for validating client identity, when
clients use X.509 certi�cate authentication.

OIDC con�guration
--oidc-ca-file

The path to the trust anchor(s) for validating client identity, when
clients use OIDC.
--oidc-client-id

The client ID for the OpenID Connect client.
--oidc-username-claim

The name of a JWT claim for specifying the username. claim to use as
the user name. Default claim name is sub, as this should be a unique
identi�er of the end user. You can choose other claims, such as email
or name. For claims other than sub or email, the kube-apiserver adds a
pre�x to the group name (to prevent naming clashes).
--oidc-username-prefix

Pre�x prepended to username claims to prevent clashes with existing
names (such as system: users). For example, the value oidc: will
create usernames like oidc:jane.doe. If this argument isn't provided
and --oidc-username-claim is a value other than email the pre�x
2/27/26, 3:33 PM

API Access Control | Kubernetes

24 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

defaults to ( Issuer URL )# where ( Issuer URL ) is the value of -oidc-issuer-url. You can specify the pre�x value as - to disable

username pre�xing.
--oidc-groups-claim

The name of a custom OpenID Connect claim for specifying user
groups. The claim in the token must be an array of strings. No default.
--oidc-groups-prefix

Pre�x prepended to group claims to prevent clashes with existing
names (such as system: groups). For example, the value oidc: will
create group names like oidc:engineering and oidc:infra. The
default pre�x is oidc:
--oidc-issuer-url

The URL of the OpenID issuer. The URL scheme

be https. If the

issuer's OIDC discovery URL is https://
accounts.provider.example/.well-known/openid-configuration, the

value should be https://accounts.provider.example.
--oidc-required-claim

A claim that must be present in a token before Kubernetes
authenticates a client. Format is key=value. You can specify this
argument more than once.
--oidc-signing-algs

The signing algorithms accepted. Allowed values are: RS256, RS384,
RS512, ES256, ES384, ES512, PS256, PS384, PS512. Values are de�ned
by RFC 7518. Default is RS512.

ServiceAccount con�guration
--api-audiences

De�nes the authentication audience for service account tokens.
--service-account-extend-token-expiration

This �ag turns on projected service account expiration extension
during token generation, which helps safe transition from legacy
tokens to bound service account token feature. See authenticating
service account credentials.
--service-account-issuer

Identi�er of the service account token issuer. The issuer asserts this
identi�er in iss claim of each issued token. The Kubernetes project
recommends using a URL here, with the scheme set to https.
--service-account-jwks-uri

Overrides the URI for the JSON Web Key Set in the discovery document
that is served at /.well-known/openid-configuration
--service-account-key-file

Path to a �le containing PEM-encoded X.509 public or private keys (RSA
or ECDSA), used to verify ServiceAccount tokens. The speci�ed �le can
contain multiple keys, and you can specify the argument multiple
times with di�erent paths.
--service-account-lookup
2/27/26, 3:33 PM

API Access Control | Kubernetes

25 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

If true, the API server validates that ServiceAccount tokens exist in etcd
as part of authentication.
--service-account-max-token-expiration

The maximum validity duration of a token created by the service
account token issuer, as a Kubernetes duration string.
--service-account-signing-endpoint

Path to socket where an external JWT signer is listening. You can use
this to integrate with an external token signer.
--service-account-signing-key-file

Path to the �le that contains the current private key of the service
account token issuer. Changes made to this �le while the API server is
running are
re-read.

Static token con�guration
--token-auth-file

Path to the con�guration �le for static bearer tokens. Changes made
to this �le while the API server is running are
re-read.

Webhook authentication con�guration
--authentication-token-webhook-cache-ttl

How long (as a Kubernetes duration speci�cation) the API server
should cache the outcome of HTTP callouts to validate tokens.
--authentication-token-webhook-config-file

The path to a kubecon�g format client con�guration, that speci�es
how the API server authenticates when making HTTP callouts. Changes
made to this �le while the API server is running are
re-read.
--authentication-token-webhook-version

The API version of TokenReview to use when making HTTP callouts to
check tokens.

Web request authentication con�guration

You should read the documentation about con�guring an
authenticating proxy before you specify these command line
arguments, as there is important information security advice that
you must follow.

--requestheader-client-ca-file

Required. Path to a PEM-encoded certi�cate bundle containing trust
anchor(s) for validating authenticating proxy identity.
A valid client certi�cate must be presented and validated against the
certi�cate authorities in the speci�ed �le before the request headers
are checked for user names.
--requestheader-allowed-names

Optional. Comma-separated list of Common Name values (CNs).
If set, a valid client certi�cate with a CN in the speci�ed list must be

2/27/26, 3:33 PM

API Access Control | Kubernetes

26 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

presented before the request headers are checked for user names. If
empty, any CN is allowed.
--requestheader-username-headers

Required; case-insensitive. Header names to check, in order, for the user
identity.
The �rst header containing a value is used as the username.
--requestheader-group-headers

Optional; case-insensitive. Header names to check, in order, for the
user's groups.
X-Remote-Group is suggested. All values in all speci�ed headers are
used as group names.
--requestheader-extra-headers-prefix

Optional; case-insensitive. Header pre�xes to look for to determine
extra information about the user.
X-Remote-Extra- is suggested. Extra data is typically used by the
con�gured authorization plugin(s). Any headers beginning with any of
the speci�ed pre�xes have the pre�x removed. The remainder of the
header name is lowercased and percent-decoded and becomes the
extra key, and the header value is the extra value.

Con�guration via con�guration �le
ⓘ

Kubernetes v1.34 [stable](enabled by

default)
When you specify the --authentication-config command line
argument to the kube-apiserver, the API server loads a �le at the path
you specify, and uses the contents of that �le to con�gure authentication.
The contents of that �le can be changed while the API server is running
and, if you do that, the API server re-reads the �le afterwards.

Modi�cations to this �le should be done in an atomic way (for
example: writing to a peer temporary �le, then renaming the
temporary �le to replace this �le).

Con�guration �le path
--authentication-config

This special command line argument speci�es that you want to
con�gure authentication using a con�guration �le.

Example
Here is an example of a Kubernetes (structured) authentication
con�guration �le:

2/27/26, 3:33 PM

API Access Control | Kubernetes

27 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

--#
# CAUTION: this is an example configuration.
#

Check and amend this before you use it in your own cluster!

#
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
anonymous:
enabled: false

client-go credential plugins
ⓘ

Kubernetes v1.22 [stable]

k8s.io/client-go and tools using it such as kubectl and kubelet are

able to execute an external command to receive user credentials.
This feature is intended for client side integrations with authentication
protocols not natively supported by k8s.io/client-go (LDAP, Kerberos,
OAuth2, SAML, etc.). The plugin implements the protocol speci�c logic,
then returns opaque credentials to use. Almost all credential plugin use
cases require a server side component with support for the webhook
token authenticator to interpret the credential format produced by the
client plugin.

Earlier versions of kubectl included built-in support for
authenticating to AKS and GKE, but this is no longer present.

Example use case
In a hypothetical use case, an organization would run an external service
that exchanges LDAP credentials for user speci�c, signed tokens. The
service would also be capable of responding to webhook token
authenticator requests to validate the tokens. Users would be required to
install a credential plugin on their workstation.
To authenticate against the API:
• The user issues a kubectl command.
• Credential plugin prompts the user for LDAP credentials, exchanges
credentials with external service for a token.
• Credential plugin returns token to client-go, which uses it as a
bearer token against the API server.
• API server uses the webhook token authenticator to submit a
TokenReview to the external service.
• External service veri�es the signature on the token and returns the
user's username and groups.

Con�guration
Credential plugins are con�gured through kubectl con�g �les as part of
the user �elds.
client.authentication.k8s.io/v1

2/27/26, 3:33 PM

API Access Control | Kubernetes

28 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

client.authentication.k8s.io/v1beta1

2/27/26, 3:33 PM

API Access Control | Kubernetes

29 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: v1
kind: Config
users:
- name: my-user
user:
exec:
# Command to execute. Required.
command: "example-client-go-exec-plugin"
# API version to use when decoding the ExecCredentials resource. Requi
#
# The API version returned by the plugin MUST match the version listed
#
# To integrate with tools that support multiple versions (such as clie
# set an environment variable, pass an argument to the tool that indic
# or read the version from the ExecCredential object in the KUBERNETES
apiVersion: "client.authentication.k8s.io/v1"
# Environment variables to set when executing the plugin. Optional.
env:
- name: "FOO"
value: "bar"
# Arguments to pass when executing the plugin. Optional.
args:
- "arg1"
- "arg2"
# Text shown to the user when the executable doesn't seem to be presen
installHint: |
example-client-go-exec-plugin is required to authenticate
to the current cluster.

It can be installed:

On macOS: brew install example-client-go-exec-plugin
On Ubuntu: apt-get install example-client-go-exec-plugin
On Fedora: dnf install example-client-go-exec-plugin
...
# Whether or not to provide cluster information, which could potential
# very large CA data, to this exec plugin as a part of the KUBERNETES_
# environment variable.
provideClusterInfo: true
# The contract between the exec plugin and the standard input I/O stre
# contract cannot be satisfied, this plugin will not be run and an err
# returned. Valid values are "Never" (this exec plugin never uses stan
# "IfAvailable" (this exec plugin wants to use standard input if it is
# or "Always" (this exec plugin requires standard input to function).
interactiveMode: Never
clusters:
- name: my-cluster
cluster:
server: "https://172.17.4.100:6443"
certificate-authority: "/etc/kubernetes/ca.pem"
extensions:
- name: client.authentication.k8s.io/exec # reserved extension name for
extension:
arbitrary: config
this: can be provided via the KUBERNETES_EXEC_INFO environment varia
you: ["can", "put", "anything", "here"]
contexts:
- name: my-cluster

2/27/26, 3:33 PM

API Access Control | Kubernetes

30 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

context:
cluster: my-cluster
user: my-user
current-context: my-cluster

Relative command paths are interpreted as relative to the directory of
the con�g �le. If KUBECONFIG is set to /home/jane/kubeconfig and the
exec command is ./bin/example-client-go-exec-plugin , the binary /
home/jane/bin/example-client-go-exec-plugin is executed.

- name: my-user
user:
exec:
# Path relative to the directory of the kubeconfig
command: "./bin/example-client-go-exec-plugin"
apiVersion: "client.authentication.k8s.io/v1"
interactiveMode: Never

Input and output formats
The executed command prints an ExecCredential object to stdout .
k8s.io/client-go authenticates against the Kubernetes API using the

returned credentials in the status . The executed command is passed an
ExecCredential object as input via the KUBERNETES_EXEC_INFO

environment variable. This input contains helpful information like the
expected API version of the returned ExecCredential object and
whether or not the plugin can use stdin to interact with the user.
When run from an interactive session (i.e., a terminal), stdin can be
exposed directly to the plugin. Plugins should use the spec.interactive
�eld of the input ExecCredential object from the
KUBERNETES_EXEC_INFO environment variable in order to determine if
stdin has been provided. A plugin's stdin requirements (i.e., whether
stdin is optional, strictly required, or never used in order for the plugin

to run successfully) is declared via the user.exec.interactiveMode �eld
in the kubecon�g (see table below for valid values). The
user.exec.interactiveMode �eld is optional in
client.authentication.k8s.io/v1beta1 and required in
client.authentication.k8s.io/v1 .

interactiveMode

Never

This exec plugin never needs to use standard input, and
therefore the exec plugin will be run regardless of whether
standard input is available for user input.

IfAvailable

This exec plugin would like to use standard input if it is
available, but can still operate if standard input is not available.
Therefore, the exec plugin will be run regardless of whether
stdin is available for user input. If standard input is available
for user input, then it will be provided to this exec plugin.

2/27/26, 3:33 PM

API Access Control | Kubernetes

31 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

interactiveMode

Always

This exec plugin requires standard input in order to run, and
therefore the exec plugin will only be run if standard input is
available for user input. If standard input is not available for
user input, then the exec plugin will not be run and an error
will be returned by the exec plugin runner.

To use bearer token credentials, the plugin returns a token in the status
of the ExecCredential
client.authentication.k8s.io/v1
client.authentication.k8s.io/v1beta1

{
"apiVersion": "client.authentication.k8s.io/v1",
"kind": "ExecCredential",
"status": {
"token": "my-bearer-token"
}
}

Alternatively, a PEM-encoded client certi�cate and key can be returned to
use TLS client auth. If the plugin returns a di�erent certi�cate and key on
a subsequent call, k8s.io/client-go will close existing connections with
the server to force a new TLS handshake.
If speci�ed, clientKeyData and clientCertificateData must both
must be present.
clientCertificateData may contain additional intermediate certi�cates

to send to the server.
client.authentication.k8s.io/v1
client.authentication.k8s.io/v1beta1

{
"apiVersion": "client.authentication.k8s.io/v1",
"kind": "ExecCredential",
"status": {
"clientCertificateData": "-----BEGIN CERTIFICATE-----\n...\n-----END CER
"clientKeyData": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRI
}
}

Optionally, the response can include the expiry of the credential
formatted as a RFC 3339 timestamp.
Presence or absence of an expiry has the following impact:
• If an expiry is included, the bearer token and TLS credentials are
cached until the expiry time is reached, or if the server responds
with a 401 HTTP status code, or when the process exits.
• If an expiry is omitted, the bearer token and TLS credentials are
cached until the server responds with a 401 HTTP status code or
until the process exits.

2/27/26, 3:33 PM

API Access Control | Kubernetes

32 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

client.authentication.k8s.io/v1
client.authentication.k8s.io/v1beta1

{
"apiVersion": "client.authentication.k8s.io/v1",
"kind": "ExecCredential",
"status": {
"token": "my-bearer-token",
"expirationTimestamp": "2018-03-05T17:30:20-08:00"
}
}

To enable the exec plugin to obtain cluster-speci�c information, set
provideClusterInfo on the user.exec �eld in the kubecon�g. The
plugin will then be supplied this cluster-speci�c information in the
KUBERNETES_EXEC_INFO environment variable. Information from this

environment variable can be used to perform cluster-speci�c credential
acquisition logic. The following ExecCredential manifest describes a
cluster information sample.
client.authentication.k8s.io/v1
client.authentication.k8s.io/v1beta1

{
"apiVersion": "client.authentication.k8s.io/v1",
"kind": "ExecCredential",
"spec": {
"cluster": {
"server": "https://172.17.4.100:6443",
"certificate-authority-data": "LS0t...",
"config": {
"arbitrary": "config",
"this": "can be provided via the KUBERNETES_EXEC_INFO environment va
"you": ["can", "put", "anything", "here"]
}
},
"interactive": true
}
}

API access to authentication
information for a client
ⓘ

Kubernetes v1.28 [stable]

You can use the SelfSubjectReview API to �nd out how your Kubernetes
cluster maps your authentication information to identify you as a client.
This works whether you are authenticating as a user (typically
representing a real person) or as a ServiceAccount.
In a typical Kubernetes cluster, all authenticated users can create
SelfSubjectReviews. Access to do this is allowed by the built-in
system:basic-user ClusterRole.

The ability for a client to learn its own identity is extremely useful when

2/27/26, 3:33 PM

API Access Control | Kubernetes

33 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

troubleshooting a complicated authentication �ow that is used in a
Kubernetes cluster; for example, if you use webhook token
authentication or an authenticating proxy.
If you want to query this on the command line, see CLI access to
authentication information.

HTTP access to authentication information
SelfSubjectReviews do not have any con�gurable �elds. On receiving a
request, the Kubernetes API server �lls the status with the user attributes
and returns it to the user. This does
persist a named resource into
your cluster: you cannot fetch the SelfSubjectReview, and it is discarded
once your POST request has completed.
Request example (the body would be a SelfSubjectReview):

POST /apis/authentication.k8s.io/v1/selfsubjectreviews

{
"apiVersion": "authentication.k8s.io/v1",
"kind": "SelfSubjectReview"
}

Response example:

{
"apiVersion": "authentication.k8s.io/v1",
"kind": "SelfSubjectReview",
"status": {
"userInfo": {
"username": "janedoe@example.com",
"groups": [
"viewers",
"editors",
"system:authenticated"
]
}
}
}

The Kubernetes API server �lls userInfo after all authentication
mechanisms are applied, including impersonation. If you, or an
authentication proxy, make a SelfSubjectReview using
impersonation, you see the user details and properties for the user
that was impersonated.

This example response did not show all the available �elds; not all
authentication mechanisms �ll in every available �eld. See the
SelfSubjectReview API reference to see which �elds are available.
Here is another example that also includes the uid and extra �elds:

2/27/26, 3:33 PM

API Access Control | Kubernetes

34 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"apiVersion": "authentication.k8s.io/v1",
"kind": "SelfSubjectReview",
"status": {
"userInfo": {
"username": "janedoe@example.com",
"groups": [
"viewers",
"editors",
"system:authenticated"
],
"uid": "000042",
"extra": {
"firstName": [
"Jane"
],
"familyName": [
"Doe"
],
"projectAssignments": [
"web-frontend",
"ai-training-proof-of-concept"
],
}
}
}
}

The data in these optional �elds come from your authentication
integration or from the user database that it uses. The username, UID,
extra information, and all groups with names that don't start system:
are all sourced from outside of Kubernetes.
When querying the Kubernetes API via HTTP, you can request a response
in either JSON or YAML using the Accept: HTTP header; for example:
JSON

YAML

POST /apis/authentication.k8s.io/v1/selfsubjectreviews HTTP/
Accept: application/json;q=1.0
Content-Type: application/json
…other request headers
{
"apiVersion": "authentication.k8s.io/v1",
"kind": "SelfSubjectReview"
}

2/27/26, 3:33 PM

API Access Control | Kubernetes

35 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"apiVersion": "authentication.k8s.io/v1",
"kind": "SelfSubjectReview",
"status": {
"userInfo": {
"username": "jane.doe",
"uid": "b79dbf30-0c6a-11ed-861d-0242ac120002",
"groups": [
"students",
"teachers",
"system:authenticated"
],
"extra": {
"skills": [
"reading",
"learning"
],
"subjects": [
"math",
"sports"
]
}
}
}
}

CLI access to authentication information
For convenience, the kubectl auth whoami subcommand is also
available:

kubectl auth whoami

The output is similar to:

ATTRIBUTE
Username
Groups

VALUE
george.boole
[system:authenticated]

See kubectl auth whoami for more details.

What's next
• To learn about issuing certi�cates for users, read Issue a Certi�cate
for a Kubernetes API Client Using A Certi�cateSigningRequest
• Read the client authentication reference (v1)
• Read the client authentication reference (v1beta1)

2/27/26, 3:33 PM

API Access Control | Kubernetes

36 of 200

ⓘ

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Kubernetes v1.18 [stable]

Bootstrap tokens are a simple bearer token that is meant to be used
when creating new clusters or joining new nodes to an existing cluster. It
was built to support kubeadm, but can be used in other contexts for
users that wish to start clusters without kubeadm . It is also built to work,
via RBAC policy, with the kubelet TLS Bootstrapping system.

Bootstrap Tokens Overview
Bootstrap Tokens are de�ned with a speci�c type
( bootstrap.kubernetes.io/token ) of secrets that lives in the kubesystem namespace. These Secrets are then read by the Bootstrap

Authenticator in the API Server. Expired tokens are removed with the
TokenCleaner controller in the Controller Manager. The tokens are also
used to create a signature for a speci�c Con�gMap used in a "discovery"
process through a BootstrapSigner controller.

Token Format
Bootstrap Tokens take the form of abcdef.0123456789abcdef . More
formally, they must match the regular expression [a-z0-9]{6}\.[az0-9]{16} .

The �rst part of the token is the "Token ID" and is considered public
information. It is used when referring to a token without leaking the
secret part used for authentication. The second part is the "Token Secret"
and should only be shared with trusted parties.

Enabling Bootstrap Token
Authentication
The Bootstrap Token authenticator can be enabled using the following
�ag on the API server:
--enable-bootstrap-token-auth

When enabled, bootstrapping tokens can be used as bearer token
credentials to authenticate requests against the API server.

Authorization: Bearer 07401b.f395accd246ae52d

Tokens authenticate as the username system:bootstrap:<token id>
and are members of the group system:bootstrappers . Additional
groups may be speci�ed in the token's Secret.
Expired tokens can be deleted automatically by enabling the
tokencleaner controller on the controller manager.

2/27/26, 3:33 PM

API Access Control | Kubernetes

37 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

--controllers=*,tokencleaner

Bootstrap Token Secret Format
Each valid token is backed by a secret in the kube-system namespace.
You can �nd the full design doc here.
Here is what the secret looks like.

apiVersion: v1
kind: Secret
metadata:
# Name MUST be of form "bootstrap-token-<token id>"
name: bootstrap-token-07401b
namespace: kube-system
# Type MUST be 'bootstrap.kubernetes.io/token'
type: bootstrap.kubernetes.io/token
stringData:
# Human readable description. Optional.
description: "The default bootstrap token generated by 'kubeadm init'."
# Token ID and secret. Required.
token-id: 07401b
token-secret: f395accd246ae52d
# Expiration. Optional.
expiration: 2017-03-10T03:22:11Z
# Allowed usages.
usage-bootstrap-authentication: "true"
usage-bootstrap-signing: "true"
# Extra groups to authenticate the token as. Must start with "system:bootstrap
auth-extra-groups: system:bootstrappers:worker,system:bootstrappers:ingress

The type of the secret must be bootstrap.kubernetes.io/token and the
name must be bootstrap-token-<token id> . It must also exist in the
kube-system namespace.

The usage-bootstrap-* members indicate what this secret is intended
to be used for. A value must be set to true to be enabled.
• usage-bootstrap-authentication indicates that the token can be
used to authenticate to the API server as a bearer token.
• usage-bootstrap-signing indicates that the token may be used to
sign the cluster-info Con�gMap as described below.
The expiration �eld controls the expiry of the token. Expired tokens are
rejected when used for authentication and ignored during Con�gMap
signing. The expiry value is encoded as an absolute UTC time using
RFC3339. Enable the tokencleaner controller to automatically delete
expired tokens.

Token Management with kubeadm

2/27/26, 3:33 PM

API Access Control | Kubernetes

38 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

You can use the kubeadm tool to manage tokens on a running cluster.
See the kubeadm token docs for details.

Con�gMap Signing
In addition to authentication, the tokens can be used to sign a
Con�gMap. This is used early in a cluster bootstrap process before the
client trusts the API server. The signed Con�gMap can be authenticated
by the shared token.
Enable Con�gMap signing by enabling the bootstrapsigner controller
on the Controller Manager.
--controllers=*,bootstrapsigner

The Con�gMap that is signed is cluster-info in the kube-public
namespace. The typical �ow is that a client reads this Con�gMap while
unauthenticated and ignoring TLS errors. It then validates the payload of
the Con�gMap by looking at a signature embedded in the Con�gMap.
The Con�gMap may look like this:

apiVersion: v1
kind: ConfigMap
metadata:
name: cluster-info
namespace: kube-public
data:
jws-kubeconfig-07401b: eyJhbGciOiJIUzI1NiIsImtpZCI6IjA3NDAxYiJ9..tYEfbo6zDNo40
kubeconfig: |
apiVersion: v1
clusters:
- cluster:
certificate-authority-data: <really long certificate data>
server: https://10.138.0.2:6443
name: ""
contexts: []
current-context: ""
kind: Config
preferences: {}
users: []

The kubeconfig member of the Con�gMap is a con�g �le with only the
cluster information �lled out. The key thing being communicated here is
the certificate-authority-data . This may be expanded in the future.
The signature is a JWS signature using the "detached" mode. To validate
the signature, the user should encode the kubeconfig payload
according to JWS rules (base64 encoded while discarding any trailing = ).
That encoded payload is then used to form a whole JWS by inserting it
between the 2 dots. You can verify the JWS using the HS256 scheme
(HMAC-SHA256) with the full token (e.g. 07401b.f395accd246ae52d ) as
the shared secret. Users must verify that HS256 is used.

Any party with a bootstrapping token can create a valid signature
for that token. When using Con�gMap signing it's discouraged to
share the same token with many clients, since a compromised

2/27/26, 3:33 PM

API Access Control | Kubernetes

39 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

client can potentially man-in-the middle another client relying on
the signature to bootstrap TLS trust.

Consult the kubeadm implementation details section for more
information.

2/27/26, 3:33 PM

API Access Control | Kubernetes

40 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Kubernetes authorization takes place following authentication. Usually, a
client making a request must be authenticated (logged in) before its
request can be allowed; however, Kubernetes also allows anonymous
requests in some circumstances.
For an overview of how authorization �ts into the wider context of API
access control, read Controlling Access to the Kubernetes API.

Authorization verdicts
Kubernetes authorization of API requests takes place within the API
server. The API server evaluates all of the request attributes against all
policies, potentially also consulting external services, and then allows or
denies the request.
All parts of an API request must be allowed by some authorization
mechanism in order to proceed. In other words: access is denied by
default.

Access controls and policies that depend on speci�c �elds of
speci�c kinds of objects are handled by admission controllers.
Kubernetes admission control happens after authorization has
completed (and, therefore, only when the authorization decision
was to allow the request).

When multiple authorization modules are con�gured, each is checked in
sequence. If any authorizer approves or denies a request, that decision is
immediately returned and no other authorizer is consulted. If all modules
have no opinion on the request, then the request is denied. An overall
deny verdict means that the API server rejects the request and responds
with an HTTP 403 (Forbidden) status.

Request attributes used in
authorization
Kubernetes reviews only the following API request attributes:
•

- The user string provided during authentication.

•

- The list of group names to which the authenticated user
belongs.

•

- A map of arbitrary string keys to string values, provided by
the authentication layer.

•
•
•

- Indicates whether the request is for an API resource.
- Path to miscellaneous non-resource endpoints like
/api or /healthz .
- API verbs like get , list , create , update ,
patch , watch , delete , and deletecollection are used for

resource requests. To determine the request verb for a resource

2/27/26, 3:33 PM

API Access Control | Kubernetes

41 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

API endpoint, see request verbs and authorization.
- Lowercased HTTP methods like get , post ,

•

put , and delete are used for non-resource requests.

•

- The ID or name of the resource that is being accessed
(for resource requests only) -- For resource requests using get ,
update , patch , and delete verbs, you must provide the resource

name.
•

- The subresource that is being accessed (for resource
requests only).

•

- The namespace of the object that is being accessed
(for namespaced resource requests only).

•

- The API Group being accessed (for resource requests
only). An empty string designates the core API group.

Request verbs and authorization
Non-resource requests
Requests to endpoints other than /api/v1/... or /apis/<group>/
<version>/... are considered non-resource requests, and use the lower-

cased HTTP method of the request as the verb. For example, making a
GET request using HTTP to endpoints such as /api or /healthz would

use

as the verb.

Resource requests
To determine the request verb for a resource API endpoint, Kubernetes
maps the HTTP verb used and considers whether or not the request acts
on an individual resource or on a collection of resources:

POST
GET ,

(for individual resources),
(for collections, including full object
content),
(for watching an individual resource or collection of
resources)

HEAD

PUT
PATCH
DELETE

(for individual resources),

(for collections)

+The
,
and
verbs can all return the full details of a
resource. In terms of access to the returned data they are
equivalent. For example,
on secrets will reveal the
attributes of any returned resources.

Kubernetes sometimes checks authorization for additional permissions
using specialized verbs. For example:
• Special cases of authentication
◦

verb on users , groups , and serviceaccounts
in the core API group, and the userextras in the
authentication.k8s.io API group.

2/27/26, 3:33 PM

API Access Control | Kubernetes

42 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• Authorization of Certi�cateSigningRequests
◦
verb for Certi�cateSigningRequests, and
revisions to existing approvals
• RBAC
◦

and

for

verbs on roles and clusterroles

resources in the rbac.authorization.k8s.io API group.

Authorization context
Kubernetes expects attributes that are common to REST API requests.
This means that Kubernetes authorization works with existing
organization-wide or cloud-provider-wide access control systems which
may handle other APIs besides the Kubernetes API.

Authorization modes
The Kubernetes API server may authorize a request using one of several
authorization modes:
AlwaysAllow

This mode allows all requests, which brings security risks. Use this
authorization mode only if you do not require authorization for your
API requests (for example, for testing).
AlwaysDeny

This mode blocks all requests. Use this authorization mode only for
testing.
ABAC

Kubernetes ABAC mode de�nes an access control paradigm whereby
access rights are granted to users through the use of policies which
combine attributes together. The policies can use any type of
attributes (user attributes, resource attributes, object, environment
attributes, etc).
RBAC

Kubernetes RBAC is a method of regulating access to computer or
network resources based on the roles of individual users within an
enterprise. In this context, access is the ability of an individual user to
perform a speci�c task, such as view, create, or modify a �le.
In this mode, Kubernetes uses the rbac.authorization.k8s.io API
group to drive authorization decisions, allowing you to dynamically
con�gure permission policies through the Kubernetes API.
Node

A special-purpose authorization mode that grants permissions to
kubelets based on the pods they are scheduled to run. To learn more
about the Node authorization mode, see Node Authorization.
Webhook

Kubernetes webhook mode for authorization makes a synchronous
HTTP callout, blocking the request until the remote HTTP service
responds to the query.You can write your own software to handle the
callout, or use solutions from the ecosystem.

2/27/26, 3:33 PM

API Access Control | Kubernetes

43 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Enabling the AlwaysAllow mode bypasses authorization; do not
use this on a cluster where you do not trust

potential API clients,

including the workloads that you run.
Authorization mechanisms typically return either a deny or no
opinion result; see authorization verdicts for more on this.
Activating the AlwaysAllow means that if all other authorizers
return “no opinion”, the request is allowed. For example, -authorization-mode=AlwaysAllow,RBAC has the same e�ect as -authorization-mode=AlwaysAllow because Kubernetes RBAC does

not provide negative (deny) access rules.
You should not use the AlwaysAllow mode on a Kubernetes
cluster where the API server is reachable from the public internet.

The system:masters group
The system:masters group is a built-in Kubernetes group that grants
unrestricted access to the API server. Any user assigned to this group has
full cluster administrator privileges, bypassing any authorization
restrictions imposed by the RBAC or Webhook mechanisms. Avoid adding
users to this group. If you do need to grant a user cluster-admin rights,
you can create a ClusterRoleBinding to the built-in cluster-admin
ClusterRole.

Authorization mode con�guration
You can con�gure the Kubernetes API server's authorizer chain using
either a con�guration �le only or command line arguments.
You have to pick one of the two con�guration approaches; setting both
--authorization-config path and con�guring an authorization
webhook using the --authorization-mode and --authorizationwebhook-* command line arguments is not allowed. If you try this, the

API server reports an error message during startup, then exits
immediately.

Con�guring the API Server using an authorization con�g �le

ⓘ

Kubernetes v1.32 [stable](enabled by

default)
Kubernetes lets you con�gure authorization chains that can include multiple webhooks. The
authorization items in that chain can have well-de�ned parameters that validate requests in
a particular order, o�ering you �ne-grained control, such as explicit Deny on failures.
The con�guration �le approach even allows you to specify CEL rules to
pre-�lter requests before they are dispatched to webhooks, helping you
to prevent unnecessary invocations. The API server also automatically
reloads the authorizer chain when the con�guration �le is modi�ed.
You specify the path to the authorization con�guration using the -authorization-config command line argument.

If you want to use command line arguments instead of a con�guration
�le, that's also a valid and supported approach. Some authorization
capabilities (for example: multiple webhooks, webhook failure policy, and
pre-�lter rules) are only available if you use an authorization
con�guration �le.

2/27/26, 3:33 PM

API Access Control | Kubernetes

44 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Example con�guration

2/27/26, 3:33 PM

API Access Control | Kubernetes

45 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

--#
# DO NOT USE THE CONFIG AS IS. THIS IS AN EXAMPLE.
#
apiVersion: apiserver.config.k8s.io/v1
kind: AuthorizationConfiguration
authorizers:
- type: Webhook
# Name used to describe the authorizer
# This is explicitly used in monitoring machinery for metrics
# Note:
#

- Validation for this field is similar to how K8s labels are validated t

# Required, with no default
name: webhook
webhook:
# The duration to cache 'authorized' responses from the webhook
# authorizer.
# Same as setting `--authorization-webhook-cache-authorized-ttl` flag
# Default: 5m0s
authorizedTTL: 30s
# If set to false, 'authorized' responses from the webhook are not cached
# and the specified authorizedTTL is ignored/has no effect.
# Same as setting `--authorization-webhook-cache-authorized-ttl` flag to `
# Note: Setting authorizedTTL to `0` results in its default value being us
# Default: true
cacheAuthorizedRequests: true
# The duration to cache 'unauthorized' responses from the webhook
# authorizer.
# Same as setting `--authorization-webhook-cache-unauthorized-ttl` flag
# Default: 30s
unauthorizedTTL: 30s
# If set to false, 'unauthorized' responses from the webhook are not cache
# and the specified unauthorizedTTL is ignored/has no effect.
# Same as setting `--authorization-webhook-cache-unauthorized-ttl` flag to
# Note: Setting unauthorizedTTL to `0` results in its default value being
# Default: true
cacheUnauthorizedRequests: true
# Timeout for the webhook request
# Maximum allowed is 30s.
# Required, with no default.
timeout: 3s
# The API version of the authorization.k8s.io SubjectAccessReview to
# send to and expect from the webhook.
# Same as setting `--authorization-webhook-version` flag
# Required, with no default
# Valid values: v1beta1, v1
subjectAccessReviewVersion: v1
# MatchConditionSubjectAccessReviewVersion specifies the SubjectAccessRevi
# version the CEL expressions are evaluated against
# Valid values: v1
# Required, no default value
matchConditionSubjectAccessReviewVersion: v1
# Controls the authorization decision when a webhook request fails to
# complete or returns a malformed response or errors evaluating
# matchConditions.
# Valid values:
#

- NoOpinion: continue to subsequent authorizers to see if one of

#

them allows the request

#

- Deny: reject the request without consulting subsequent authorizers

# Required, with no default.
failurePolicy: Deny
connectionInfo:
# Controls how the webhook should communicate with the server.
# Valid values:
# - KubeConfigFile: use the file specified in kubeConfigFile to locate t
#

server.
2/27/26, 3:33 PM

API Access Control | Kubernetes

46 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

# - InClusterConfig: use the in-cluster configuration to call the
#

SubjectAccessReview API hosted by kube-apiserver. This mode is not

#

allowed for kube-apiserver.

type: KubeConfigFile
# Path to KubeConfigFile for connection info
# Required, if connectionInfo.Type is KubeConfigFile
kubeConfigFile: /kube-system-authz-webhook.yaml
# matchConditions is a list of conditions that must be met for a request
# webhook. An empty list of matchConditions matches all requests.
# There are a maximum of 64 match conditions allowed.
#
# The exact matching logic is (in order):
#

1. If at least one matchCondition evaluates to FALSE, then the webho

#

2. If ALL matchConditions evaluate to TRUE, then the webhook is call

#

3. If at least one matchCondition evaluates to an error (but none ar

#

- If failurePolicy=Deny, then the webhook rejects the request

#

- If failurePolicy=NoOpinion, then the error is ignored and the w

matchConditions:
# expression represents the expression which will be evaluated by CEL. Mus
# CEL expressions have access to the contents of the SubjectAccessReview i
# If version specified by subjectAccessReviewVersion in the request variab
# the contents would be converted to the v1 version before evaluating the
#
# Documentation on CEL: https://kubernetes.io/docs/reference/using-api/cel
#
# only send resource requests to the webhook
- expression: has(request.resourceAttributes)
# only intercept requests to kube-system
- expression: request.resourceAttributes.namespace == 'kube-system'
# don't intercept requests from kube-system service accounts
- expression: "!('system:serviceaccounts:kube-system' in request.groups)"
- type: Node
name: node
- type: RBAC
name: rbac
- type: Webhook
name: in-cluster-authorizer
webhook:
authorizedTTL: 5m
unauthorizedTTL: 30s
timeout: 3s
subjectAccessReviewVersion: v1
failurePolicy: NoOpinion
connectionInfo:
type: InClusterConfig

When con�guring the authorizer chain using a con�guration �le, make
sure all the control plane nodes have the same �le contents. Take a note
of the API server con�guration when upgrading / downgrading your
clusters. For example, if upgrading from Kubernetes 1.34 to Kubernetes
1.35, you would need to make sure the con�g �le is in a format that
Kubernetes 1.35 can understand, before you upgrade the cluster. If you
downgrade to 1.34, you would need to set the con�guration
appropriately.

Authorization con�guration and reloads
Kubernetes reloads the authorization con�guration �le when the API
server observes a change to the �le, and also on a 60 second schedule if
no change events were observed.

You must ensure that all non-webhook authorizer types remain
unchanged in the �le on reload.
2/27/26, 3:33 PM

API Access Control | Kubernetes

47 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

A reload
add or remove Node or RBAC authorizers (they
can be reordered, but cannot be added or removed).

Command line authorization mode con�guration
You can use the following modes:
• --authorization-mode=ABAC (Attribute-based access control mode)
• --authorization-mode=RBAC (Role-based access control mode)
• --authorization-mode=Node (Node authorizer)
• --authorization-mode=Webhook (Webhook authorization mode)
• --authorization-mode=AlwaysAllow (always allows requests;
carries security risks)
• --authorization-mode=AlwaysDeny (always denies requests)
You can choose more than one authorization mode; for example: -authorization-mode=Node,RBAC,Webhook

Kubernetes checks authorization modules based on the order that you
specify them on the API server's command line, so an earlier module has
higher priority to allow or deny a request.
You cannot combine the --authorization-mode command line
argument with the --authorization-config command line argument
used for con�guring authorization using a local �le.
For more information on command line arguments to the API server,
read the kube-apiserver reference.

Privilege escalation via workload
creation or edits
Users who can create/edit pods in a namespace, either directly or
through an object that enables indirect workload management, may be
able to escalate their privileges in that namespace. The potential routes
to privilege escalation include Kubernetes API extensions and their
associated controllers.

As a cluster administrator, use caution when granting access to
create or edit workloads. Some details of how these can be
misused are documented in escalation paths.

Escalation paths
There are di�erent ways that an attacker or untrustworthy user could
gain additional privilege within a namespace, if you allow them to run
arbitrary Pods in that namespace:
• Mounting arbitrary Secrets in that namespace
◦ Can be used to access con�dential information meant for
other workloads
◦ Can be used to obtain a more privileged ServiceAccount's
service account token
• Using arbitrary ServiceAccounts in that namespace
◦ Can perform Kubernetes API actions as another workload
(impersonation)

2/27/26, 3:33 PM

API Access Control | Kubernetes

48 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

◦ Can perform any privileged actions that ServiceAccount has
• Mounting or using Con�gMaps meant for other workloads in that
namespace
◦ Can be used to obtain information meant for other workloads,
such as database host names.
• Mounting volumes meant for other workloads in that namespace
◦ Can be used to obtain information meant for other workloads,
and change it.

As a system administrator, you should be cautious when deploying
CustomResourceDe�nitions that let users make changes to the
above areas. These may open privilege escalations paths. Consider
the consequences of this kind of change when deciding on your
authorization controls.

Checking API access
kubectl provides the auth can-i subcommand for quickly querying

the API authorization layer. The command uses the
SelfSubjectAccessReview API to determine if the current user can

perform a given action, and works regardless of the authorization mode
used.

kubectl auth can-i create deployments --namespace dev

The output is similar to this:
yes

kubectl auth can-i create deployments --namespace prod

The output is similar to this:
no

Administrators can combine this with user impersonation to determine
what action other users can perform.

kubectl auth can-i list secrets --namespace dev --as dave

The output is similar to this:
no

Similarly, to check whether a ServiceAccount named dev-sa in
Namespace dev can list Pods in the Namespace target :

2/27/26, 3:33 PM

API Access Control | Kubernetes

49 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

kubectl auth can-i list pods \
--namespace target \
--as system:serviceaccount:dev:dev-sa

The output is similar to this:
yes

SelfSubjectAccessReview is part of the authorization.k8s.io API group,
which exposes the API server authorization to external services. Other
resources in this group include:

Access review for any user, not only the current one. Useful for
delegating authorization decisions to the API server. For example, the
kubelet and extension API servers use this to determine user access to
their own APIs.

Like SubjectAccessReview but restricted to a speci�c namespace.

A review which returns the set of actions a user can perform within a
namespace. Useful for users to quickly summarize their own access, or
for UIs to hide/show actions.
These APIs can be queried by creating normal Kubernetes resources,
where the response status �eld of the returned object is the result of
the query. For example:

kubectl create -f - -o yaml << EOF
apiVersion: authorization.k8s.io/v1
kind: SelfSubjectAccessReview
spec:
resourceAttributes:
group: apps
resource: deployments
verb: create
namespace: dev
EOF

The generated SelfSubjectAccessReview is similar to:

apiVersion: authorization.k8s.io/v1
kind: SelfSubjectAccessReview
metadata:
creationTimestamp: null
spec:
resourceAttributes:
group: apps
resource: deployments
namespace: dev
verb: create
status:
allowed: true
denied: false

2/27/26, 3:33 PM

API Access Control | Kubernetes

50 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

What's next
• To learn more about Authentication, see Authentication.
• For an overview, read Controlling Access to the Kubernetes API.
• To learn more about Admission Control, see Using Admission
Controllers.
• Read more about Common Expression Language in Kubernetes.

2/27/26, 3:33 PM

API Access Control | Kubernetes

51 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Role-based access control (RBAC) is a method of regulating access to
computer or network resources based on the roles of individual users
within your organization.
RBAC authorization uses the rbac.authorization.k8s.io API group to
drive authorization decisions, allowing you to dynamically con�gure
policies through the Kubernetes API.
To enable RBAC, start the API server with the --authorization-config
�ag set to a �le that includes the RBAC authorizer; for example:

apiVersion: apiserver.config.k8s.io/v1
kind: AuthorizationConfiguration
authorizers:
...
- type: RBAC
...

Or, start the API server with the --authorization-mode �ag set to a
comma-separated list that includes RBAC ; for example:

kube-apiserver --authorization-mode=...,RBAC --other-options --more-options

API objects
The RBAC API declares four kinds of Kubernetes object: Role, ClusterRole,
RoleBinding and ClusterRoleBinding. You can describe or amend the RBAC
objects using tools such as kubectl , just like any other Kubernetes
object.

These objects, by design, impose access restrictions. If you are
making changes to a cluster as you learn, see privilege escalation
prevention and bootstrapping to understand how those
restrictions can prevent you making some changes.

Role and ClusterRole
An RBAC Role or ClusterRole contains rules that represent a set of
permissions. Permissions are purely additive (there are no "deny" rules).
A Role always sets permissions within a particular namespace; when you
create a Role, you have to specify the namespace it belongs in.
ClusterRole, by contrast, is a non-namespaced resource. The resources
have di�erent names (Role and ClusterRole) because a Kubernetes object
always has to be either namespaced or not namespaced; it can't be both.
ClusterRoles have several uses. You can use a ClusterRole to:
1. de�ne permissions on namespaced resources and be granted
access within individual namespace(s)
2. de�ne permissions on namespaced resources and be granted
2/27/26, 3:33 PM

API Access Control | Kubernetes

52 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

access across all namespaces
3. de�ne permissions on cluster-scoped resources
If you want to de�ne a role within a namespace, use a Role; if you want to
de�ne a role cluster-wide, use a ClusterRole.

Role example
Here's an example Role in the "default" namespace that can be used to
grant read access to pods:

access/simple-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
namespace: default
name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
resources: ["pods"]
verbs: ["get", "watch", "list"]

ClusterRole example
A ClusterRole can be used to grant the same permissions as a Role.
Because ClusterRoles are cluster-scoped, you can also use them to grant
access to:
• cluster-scoped resources (like nodes)
• non-resource endpoints (like /healthz )
• namespaced resources (like Pods), across all namespaces
For example: you can use a ClusterRole to allow a particular user to
run kubectl get pods --all-namespaces
Here is an example of a ClusterRole that can be used to grant read access
to secrets in any particular namespace, or across all namespaces
(depending on how it is bound):

access/simple-clusterrole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
# "namespace" omitted since ClusterRoles are not namespaced
name: secret-reader
rules:
- apiGroups: [""]
#
# at the HTTP level, the name of the resource for accessing Secret
# objects is "secrets"
resources: ["secrets"]
verbs: ["get", "watch", "list"]

The name of a Role or a ClusterRole object must be a valid path segment
name.

RoleBinding and ClusterRoleBinding
2/27/26, 3:33 PM

API Access Control | Kubernetes

53 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

A role binding grants the permissions de�ned in a role to a user or set of
users. It holds a list of subjects (users, groups, or service accounts), and a
reference to the role being granted. A RoleBinding grants permissions
within a speci�c namespace whereas a ClusterRoleBinding grants that
access cluster-wide.
A RoleBinding may reference any Role in the same namespace.
Alternatively, a RoleBinding can reference a ClusterRole and bind that
ClusterRole to the namespace of the RoleBinding. If you want to bind a
ClusterRole to all the namespaces in your cluster, you use a
ClusterRoleBinding.
The name of a RoleBinding or ClusterRoleBinding object must be a valid
path segment name.

RoleBinding examples
Here is an example of a RoleBinding that grants the "pod-reader" Role to
the user "jane" within the "default" namespace. This allows "jane" to read
pods in the "default" namespace.

access/simple-rolebinding-with-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
# This role binding allows "jane" to read pods in the "default" namespace.
# You need to already have a Role named "pod-reader" in that namespace.
kind: RoleBinding
metadata:
name: read-pods
namespace: default
subjects:
# You can specify more than one "subject"
- kind: User
name: jane # "name" is case sensitive
apiGroup: rbac.authorization.k8s.io
roleRef:
# "roleRef" specifies the binding to a Role / ClusterRole
kind: Role #this must be Role or ClusterRole
name: pod-reader # this must match the name of the Role or ClusterRole you wis
apiGroup: rbac.authorization.k8s.io

A RoleBinding can also reference a ClusterRole to grant the permissions
de�ned in that ClusterRole to resources inside the RoleBinding's
namespace. This kind of reference lets you de�ne a set of common roles
across your cluster, then reuse them within multiple namespaces.
For instance, even though the following RoleBinding refers to a
ClusterRole, "dave" (the subject, case sensitive) will only be able to read
Secrets in the "development" namespace, because the RoleBinding's
namespace (in its metadata) is "development".

access/simple-rolebinding-with-clusterrole.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

54 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
# This role binding allows "dave" to read secrets in the "development" namespace
# You need to already have a ClusterRole named "secret-reader".
kind: RoleBinding
metadata:
name: read-secrets
#
# The namespace of the RoleBinding determines where the permissions are grante
# This only grants permissions within the "development" namespace.
namespace: development
subjects:
- kind: User
name: dave # Name is case sensitive
apiGroup: rbac.authorization.k8s.io
roleRef:
kind: ClusterRole
name: secret-reader
apiGroup: rbac.authorization.k8s.io

ClusterRoleBinding example
To grant permissions across a whole cluster, you can use a
ClusterRoleBinding. The following ClusterRoleBinding allows any user in
the group "manager" to read secrets in any namespace.

access/simple-clusterrolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
# This cluster role binding allows anyone in the "manager" group to read secrets
kind: ClusterRoleBinding
metadata:
name: read-secrets-global
subjects:
- kind: Group
name: manager # Name is case sensitive
apiGroup: rbac.authorization.k8s.io
roleRef:
kind: ClusterRole
name: secret-reader
apiGroup: rbac.authorization.k8s.io

After you create a binding, you cannot change the Role or ClusterRole
that it refers to. If you try to change a binding's roleRef , you get a
validation error. If you do want to change the roleRef for a binding, you
need to remove the binding object and create a replacement.
There are two reasons for this restriction:
1. Making roleRef immutable allows granting someone update
permission on an existing binding object, so that they can manage
the list of subjects, without being able to change the role that is
granted to those subjects.
2. A binding to a di�erent role is a fundamentally di�erent binding.
Requiring a binding to be deleted/recreated in order to change the
roleRef ensures the full list of subjects in the binding is intended
to be granted the new role (as opposed to enabling or accidentally
modifying only the roleRef without verifying all of the existing
subjects should be given the new role's permissions).
The kubectl auth reconcile command-line utility creates or updates a
manifest �le containing RBAC objects, and handles deleting and

2/27/26, 3:33 PM

API Access Control | Kubernetes

55 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

recreating binding objects if required to change the role they refer to. See
command usage and examples for more information.

Referring to resources
In the Kubernetes API, most resources are represented and accessed
using a string representation of their object name, such as pods for a
Pod. RBAC refers to resources using exactly the same name that appears
in the URL for the relevant API endpoint. Some Kubernetes APIs involve a
subresource, such as the logs for a Pod. A request for a Pod's logs looks
like:

GET /api/v1/namespaces/{namespace}/pods/{name}/log

In this case, pods is the namespaced resource for Pod resources, and
log is a subresource of pods . To represent this in an RBAC role, use a

slash ( / ) to delimit the resource and subresource. To allow a subject to
read pods and also access the log subresource for each of those Pods,
you write:

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
namespace: default
name: pod-and-pod-logs-reader
rules:
- apiGroups: [""]
resources: ["pods", "pods/log"]
verbs: ["get", "list"]

You can also refer to resources by name for certain requests through the
resourceNames list. When speci�ed, requests can be restricted to

individual instances of a resource. Here is an example that restricts its
subject to only get or update a Con�gMap named my-configmap :

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
namespace: default
name: configmap-updater
rules:
- apiGroups: [""]
#
# at the HTTP level, the name of the resource for accessing ConfigMap
# objects is "configmaps"
resources: ["configmaps"]
resourceNames: ["my-configmap"]
verbs: ["update", "get"]

You cannot restrict
or top-level
requests
by resource name. For
, this limitation is because the name
of the new object may not be known at authorization time.
However, the
limitation applies only to top-level resources,
not subresources. For example, you can use the resourceNames
�eld with pods/exec. If you restrict

or

by resourceName,
2/27/26, 3:33 PM

API Access Control | Kubernetes

56 of 200

clients must include a metadata.name �eld selector in their

https://kubernetes.io/docs/reference/access-authn-authz/_print/

or

request (that matches the speci�ed resourceName) in order
to be authorized. For example: kubectl get configmaps --fieldselector=metadata.name=my-configmap

Rather than referring to individual resources , apiGroups , and verbs ,
you can use the wildcard * symbol to refer to all such objects. For
nonResourceURLs , you can use the wildcard * as a su�x glob match.

For resourceNames , an empty set means that everything is allowed. Here
is an example that allows access to perform any current and future
action on all current and future resources in the example.com API group.
This is similar to the built-in cluster-admin role.

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
namespace: default
name: example.com-superuser # DO NOT USE THIS ROLE, IT IS JUST AN EXAMPLE
rules:
- apiGroups: ["example.com"]
resources: ["*"]
verbs: ["*"]

Using wildcards in resource and verb entries could result in overly
permissive access being granted to sensitive resources. For
instance, if a new resource type is added, or a new subresource is
added, or a new custom verb is checked, the wildcard entry
automatically grants access, which may be undesirable. The
principle of least privilege should be employed, using speci�c
resources and verbs to ensure only the permissions required for
the workload to function correctly are applied.

Aggregated ClusterRoles
You can aggregate several ClusterRoles into one combined ClusterRole. A
controller, running as part of the cluster control plane, watches for
ClusterRole objects with an aggregationRule set. The aggregationRule
de�nes a label selector that the controller uses to match other
ClusterRole objects that should be combined into the rules �eld of this
one.

The control plane overwrites any values that you manually specify
in the rules �eld of an aggregate ClusterRole. If you want to change
or add rules, do so in the ClusterRole objects that are selected by
the aggregationRule.

Here is an example aggregated ClusterRole:

2/27/26, 3:33 PM

API Access Control | Kubernetes

57 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: monitoring
aggregationRule:
clusterRoleSelectors:
- matchLabels:
rbac.example.com/aggregate-to-monitoring: "true"
rules: [] # The control plane automatically fills in the rules

If you create a new ClusterRole that matches the label selector of an
existing aggregated ClusterRole, that change triggers adding the new
rules into the aggregated ClusterRole. Here is an example that adds rules
to the "monitoring" ClusterRole, by creating another ClusterRole labeled
rbac.example.com/aggregate-to-monitoring: true .

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: monitoring-endpointslices
labels:
rbac.example.com/aggregate-to-monitoring: "true"
# When you create the "monitoring-endpointslices" ClusterRole,
# the rules below will be added to the "monitoring" ClusterRole.
rules:
- apiGroups: [""]
resources: ["services", "pods"]
verbs: ["get", "list", "watch"]
- apiGroups: ["discovery.k8s.io"]
resources: ["endpointslices"]
verbs: ["get", "list", "watch"]

The default user-facing roles use ClusterRole aggregation. This lets you,
as a cluster administrator, include rules for custom resources, such as
those served by CustomResourceDe�nitions or aggregated API servers,
to extend the default roles.
For example: the following ClusterRoles let the "admin" and "edit" default
roles manage the custom resource named CronTab, whereas the "view"
role can perform only read actions on CronTab resources. You can
assume that CronTab objects are named "crontabs" in URLs as seen by
the API server.

2/27/26, 3:33 PM

API Access Control | Kubernetes

58 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: aggregate-cron-tabs-edit
labels:
# Add these permissions to the "admin" and "edit" default roles.
rbac.authorization.k8s.io/aggregate-to-admin: "true"
rbac.authorization.k8s.io/aggregate-to-edit: "true"
rules:
- apiGroups: ["stable.example.com"]
resources: ["crontabs"]
verbs: ["get", "list", "watch", "create", "update", "patch",
--kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
name: aggregate-cron-tabs-view
labels:
# Add these permissions to the "view" default role.
rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
- apiGroups: ["stable.example.com"]
resources: ["crontabs"]
verbs: ["get", "list", "watch"]

Role examples
The following examples are excerpts from Role or ClusterRole objects,
showing only the rules section.
Allow reading "pods" resources in the core API Group:

rules:
- apiGroups: [""]
#
# at the HTTP level, the name of the resource for accessing Pod
# objects is "pods"
resources: ["pods"]
verbs: ["get", "list", "watch"]

Allow reading/writing Deployments (at the HTTP level: objects with
"deployments" in the resource part of their URL) in the "apps" API
groups:

rules:
- apiGroups: ["apps"]
#
# at the HTTP level, the name of the resource for accessing Deployment
# objects is "deployments"
resources: ["deployments"]
verbs: ["get", "list", "watch", "create", "update", "patch",

Allow reading Pods in the core API group, as well as reading or writing Job
resources in the "batch" API group:

2/27/26, 3:33 PM

API Access Control | Kubernetes

59 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

rules:
- apiGroups: [""]
#
# at the HTTP level, the name of the resource for accessing Pod
# objects is "pods"
resources: ["pods"]
verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
#
# at the HTTP level, the name of the resource for accessing Job
# objects is "jobs"
resources: ["jobs"]
verbs: ["get", "list", "watch", "create", "update", "patch",

Allow reading a Con�gMap named "my-con�g" (must be bound with a
RoleBinding to limit to a single Con�gMap in a single namespace):

rules:
- apiGroups: [""]
#
# at the HTTP level, the name of the resource for accessing ConfigMap
# objects is "configmaps"
resources: ["configmaps"]
resourceNames: ["my-config"]
verbs: ["get"]

Allow reading the resource "nodes" in the core group (because a Node
is cluster-scoped, this must be in a ClusterRole bound with a
ClusterRoleBinding to be e�ective):

rules:
- apiGroups: [""]
#
# at the HTTP level, the name of the resource for accessing Node
# objects is "nodes"
resources: ["nodes"]
verbs: ["get", "list", "watch"]

Allow GET and POST requests to the non-resource endpoint /healthz
and all subpaths (must be in a ClusterRole bound with a
ClusterRoleBinding to be e�ective):

rules:
- nonResourceURLs: ["/healthz", "/healthz/*"] # '*' in a nonResourceURL is a suf
verbs: ["get", "post"]

Referring to subjects
A RoleBinding or ClusterRoleBinding binds a role to subjects. Subjects can
be groups, users or ServiceAccounts.
Kubernetes represents usernames as strings. These can be: plain names,
such as "alice"; email-style names, like "bob@example.com"; or numeric
user IDs represented as a string. It is up to you as a cluster administrator
to con�gure the authentication modules so that authentication produces
usernames in the format you want.

2/27/26, 3:33 PM

API Access Control | Kubernetes

60 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

The pre�x system: is reserved for Kubernetes system use, so you
should ensure that you don't have users or groups with names that
start with system: by accident. Other than this special pre�x, the
RBAC authorization system does not require any format for
usernames.

In Kubernetes, Authenticator modules provide group information.
Groups, like users, are represented as strings, and that string has no
format requirements, other than that the pre�x system: is reserved.
ServiceAccounts have names pre�xed with system:serviceaccount: ,
and belong to groups that have names pre�xed with
system:serviceaccounts: .

• system:serviceaccount: (singular) is the pre�x for service
account usernames.
• system:serviceaccounts: (plural) is the pre�x for service
account groups.

RoleBinding examples
The following examples are RoleBinding excerpts that only show the
subjects section.

For a user named alice@example.com :

subjects:
- kind: User
name: "alice@example.com"
apiGroup: rbac.authorization.k8s.io

For a group named frontend-admins :

subjects:
- kind: Group
name: "frontend-admins"
apiGroup: rbac.authorization.k8s.io

For the default service account in the "kube-system" namespace:

subjects:
- kind: ServiceAccount
name: default
namespace: kube-system

For all service accounts in the "qa" namespace:

2/27/26, 3:33 PM

API Access Control | Kubernetes

61 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

subjects:
- kind: Group
name: system:serviceaccounts:qa
apiGroup: rbac.authorization.k8s.io

For all service accounts in any namespace:

subjects:
- kind: Group
name: system:serviceaccounts
apiGroup: rbac.authorization.k8s.io

For all authenticated users:

subjects:
- kind: Group
name: system:authenticated
apiGroup: rbac.authorization.k8s.io

For all unauthenticated users:

subjects:
- kind: Group
name: system:unauthenticated
apiGroup: rbac.authorization.k8s.io

For all users:

subjects:
- kind: Group
name: system:authenticated
apiGroup: rbac.authorization.k8s.io
- kind: Group
name: system:unauthenticated
apiGroup: rbac.authorization.k8s.io

Default roles and role bindings
API servers create a set of default ClusterRole and ClusterRoleBinding
objects. Many of these are system: pre�xed, which indicates that the
resource is directly managed by the cluster control plane. All of the
default ClusterRoles and ClusterRoleBindings are labeled with
kubernetes.io/bootstrapping=rbac-defaults .

Take care when modifying ClusterRoles and ClusterRoleBindings
with names that have a system: pre�x. Modi�cations to these
resources can result in non-functional clusters.

Auto-reconciliation
2/27/26, 3:33 PM

API Access Control | Kubernetes

62 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

At each start-up, the API server updates default cluster roles with any
missing permissions, and updates default cluster role bindings with any
missing subjects. This allows the cluster to repair accidental
modi�cations, and helps to keep roles and role bindings up-to-date as
permissions and subjects change in new Kubernetes releases.
To opt out of this reconciliation, set the
rbac.authorization.kubernetes.io/autoupdate annotation on a default

cluster role or default cluster RoleBinding to false . Be aware that
missing default permissions and subjects can result in non-functional
clusters.
Auto-reconciliation is enabled by default if the RBAC authorizer is active.

API discovery roles
Default cluster role bindings authorize unauthenticated and
authenticated users to read API information that is deemed safe to be
publicly accessible (including CustomResourceDe�nitions). To disable
anonymous unauthenticated access, add --anonymous-auth=false �ag
to the API server con�guration.
To view the con�guration of these roles via kubectl run:

kubectl get clusterroles system:discovery -o yaml

If you edit that ClusterRole, your changes will be overwritten on API
server restart via auto-reconciliation. To avoid that overwriting,
either do not manually edit the role, or disable auto-reconciliation.

group

group

and
groups

Allows a user read-only access to
basic information about
themselves. Prior to v1.14, this role
was also bound to
system:unauthenticated by
default.
Allows read-only access to API
discovery endpoints needed to
discover and negotiate an API level.
Prior to v1.14, this role was also
bound to
system:unauthenticated by
default.
Allows read-only access to nonsensitive information about the
cluster. Introduced in Kubernetes
v1.14.

Kubernetes RBAC API discovery roles

User-facing roles
2/27/26, 3:33 PM

API Access Control | Kubernetes

63 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Some of the default ClusterRoles are not system: pre�xed. These are
intended to be user-facing roles. They include super-user roles
( cluster-admin ), roles intended to be granted cluster-wide using
ClusterRoleBindings, and roles intended to be granted within particular
namespaces using RoleBindings ( admin , edit , view ).
User-facing ClusterRoles use ClusterRole aggregation to allow admins to
include rules for custom resources on these ClusterRoles. To add rules to
the admin , edit , or view roles, create a ClusterRole with one or more
of the following labels:

metadata:
labels:
rbac.authorization.k8s.io/aggregate-to-admin: "true"
rbac.authorization.k8s.io/aggregate-to-edit: "true"
rbac.authorization.k8s.io/aggregate-to-view: "true"

group

Allows super-user access to perform any
action on any resource. When used in a
, it gives full control
over every resource in the cluster and in
all namespaces. When used in a
, it gives full control over
every resource in the role binding's
namespace, including the namespace
itself.

None

Allows admin access, intended to be
granted within a namespace using a
.
If used in a
, allows read/
write access to most resources in a
namespace, including the ability to create
roles and role bindings within the
namespace. This role does not allow write
access to resource quota or to the
namespace itself. This role also does not
allow write access to EndpointSlices in
clusters created using Kubernetes v1.22+.
More information is available in the
"Write Access for EndpointSlices" section.

2/27/26, 3:33 PM

API Access Control | Kubernetes

64 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

None

Allows read/write access to most objects
in a namespace.
This role does not allow viewing or
modifying roles or role bindings.
However, this role allows accessing
Secrets and running Pods as any
ServiceAccount in the namespace, so it
can be used to gain the API access levels
of any ServiceAccount in the namespace.
This role also does not allow write access
to EndpointSlices in clusters created
using Kubernetes v1.22+. More
information is available in the "Write
Access for EndpointSlices" section.

None

Allows read-only access to see most
objects in a namespace. It does not allow
viewing roles or role bindings.
This role does not allow viewing Secrets,
since reading the contents of Secrets
enables access to ServiceAccount
credentials in the namespace, which
would allow API access as any
ServiceAccount in the namespace (a form
of privilege escalation).

Core component roles

user

user

Allows access to the resources required
by the scheduler component.
Allows access to the volume resources
required by the kube-scheduler
component.
Allows access to the resources required
by the controller manager component.

user

The permissions required by individual
controllers are detailed in the controller
roles.

2/27/26, 3:33 PM

API Access Control | Kubernetes

65 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

None

Allows access to resources required by
the kubelet,
.
You should use the Node authorizer and
NodeRestriction admission plugin instead
of the system:node role, and allow
granting API access to kubelets based on
the Pods scheduled to run on them.
The system:node role only exists for
compatibility with Kubernetes clusters
upgraded from versions prior to v1.8.

user

Allows access to the resources required
by the kube-proxy component.

Other component roles

None

Allows delegated authentication and
authorization checks. This is commonly
used by add-on API servers for uni�ed
authentication and authorization.

None

Role for the Heapster component
(deprecated).

None

Role for the kube-aggregator
component.

service
account in the

Role for the kube-dns component.

namespace
None

Allows full access to the kubelet API.

None

Allows access to the resources required
to perform kubelet TLS bootstrapping.

None

Role for the node-problem-detector
component.

None

Allows access to the resources required
by most dynamic volume provisioners.

2/27/26, 3:33 PM

API Access Control | Kubernetes

66 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

group

Allows read access to control-plane
monitoring endpoints (i.e. kube-apiserver
liveness and readiness endpoints (/
healthz, /livez, /readyz), the
individual health-check endpoints (/
healthz/*, /livez/*, /readyz/*), /
metrics), and causes the kube-apiserver
to respect the traceparent header
provided with requests for tracing. Note
that individual health check endpoints
and the metric endpoint may expose
sensitive information.

Roles for built-in controllers
The Kubernetes controller manager runs controllers that are built in to
the Kubernetes control plane. When invoked with --use-serviceaccount-credentials , kube-controller-manager starts each controller

using a separate service account. Corresponding roles exist for each
built-in controller, pre�xed with system:controller: . If the controller
manager is not started with --use-service-account-credentials , it runs
all control loops using its own credential, which must be granted all the
relevant roles. These roles include:
• system:controller:attachdetach-controller
• system:controller:certificate-controller
• system:controller:clusterrole-aggregation-controller
• system:controller:cronjob-controller
• system:controller:daemon-set-controller
• system:controller:deployment-controller
• system:controller:disruption-controller
• system:controller:endpoint-controller
• system:controller:expand-controller
• system:controller:generic-garbage-collector
• system:controller:horizontal-pod-autoscaler
• system:controller:job-controller
• system:controller:namespace-controller
• system:controller:node-controller
• system:controller:persistent-volume-binder
• system:controller:pod-garbage-collector
• system:controller:pv-protection-controller
• system:controller:pvc-protection-controller
• system:controller:replicaset-controller
• system:controller:replication-controller
• system:controller:resourcequota-controller
• system:controller:root-ca-cert-publisher
• system:controller:route-controller
• system:controller:service-account-controller
• system:controller:service-controller
• system:controller:statefulset-controller
• system:controller:ttl-controller

2/27/26, 3:33 PM

API Access Control | Kubernetes

67 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Privilege escalation prevention and
bootstrapping
The RBAC API prevents users from escalating privileges by editing roles or
role bindings. Because this is enforced at the API level, it applies even
when the RBAC authorizer is not in use.

Restrictions on role creation or update
You can only create/update a role if at least one of the following things is
true:
1. You already have all the permissions contained in the role, at the
same scope as the object being modi�ed (cluster-wide for a
ClusterRole, within the same namespace or cluster-wide for a Role).
2. You are granted explicit permission to perform the escalate verb
on the roles or clusterroles resource in the
rbac.authorization.k8s.io API group.

For example, if user-1 does not have the ability to list Secrets clusterwide, they cannot create a ClusterRole containing that permission. To
allow a user to create/update roles:
1. Grant them a role that allows them to create/update Role or
ClusterRole objects, as desired.
2. Grant them permission to include speci�c permissions in the roles
they create/update:
◦ implicitly, by giving them those permissions (if they attempt to
create or modify a Role or ClusterRole with permissions they
themselves have not been granted, the API request will be
forbidden)
◦ or explicitly allow specifying any permission in a Role or
ClusterRole by giving them permission to perform the
escalate verb on roles or clusterroles resources in the
rbac.authorization.k8s.io API group

Restrictions on role binding creation or update
You can only create/update a role binding if you already have all the
permissions contained in the referenced role (at the same scope as the
role binding) or if you have been authorized to perform the bind verb
on the referenced role. For example, if user-1 does not have the ability
to list Secrets cluster-wide, they cannot create a ClusterRoleBinding to a
role that grants that permission. To allow a user to create/update role
bindings:
1. Grant them a role that allows them to create/update RoleBinding or
ClusterRoleBinding objects, as desired.
2. Grant them permissions needed to bind a particular role:
◦ implicitly, by giving them the permissions contained in the
role.
◦ explicitly, by giving them permission to perform the bind
verb on the particular Role (or ClusterRole).
For example, this ClusterRole and RoleBinding would allow user-1 to
grant other users the admin , edit , and view roles in the namespace
user-1-namespace :

2/27/26, 3:33 PM

API Access Control | Kubernetes

68 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: role-grantor
rules:
- apiGroups: ["rbac.authorization.k8s.io"]
resources: ["rolebindings"]
verbs: ["create"]
- apiGroups: ["rbac.authorization.k8s.io"]
resources: ["clusterroles"]
verbs: ["bind"]
# omit resourceNames to allow binding any ClusterRole
resourceNames: ["admin","edit","view"]
--apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
name: role-grantor-binding
namespace: user-1-namespace
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: ClusterRole
name: role-grantor
subjects:
- apiGroup: rbac.authorization.k8s.io
kind: User
name: user-1

When bootstrapping the �rst roles and role bindings, it is necessary for
the initial user to grant permissions they do not yet have. To bootstrap
initial roles and role bindings:
• Use a credential with the "system:masters" group, which is bound
to the "cluster-admin" super-user role by the default bindings.

Command-line utilities
kubectl create role
Creates a Role object de�ning permissions within a single namespace.
Examples:
• Create a Role named "pod-reader" that allows users to perform
get , watch and list on pods:

kubectl create role pod-reader --verb=get --verb=list --verb

• Create a Role named "pod-reader" with resourceNames speci�ed:

kubectl create role pod-reader --verb=get --resource=pods --resource-name

• Create a Role named "foo" with apiGroups speci�ed:

kubectl create role foo --verb=get,list,watch --resource=replicasets.apps

2/27/26, 3:33 PM

API Access Control | Kubernetes

69 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• Create a Role named "foo" with subresource permissions:

kubectl create role foo --verb=get,list,watch --resource=pods,pods/status

• Create a Role named "my-component-lease-holder" with
permissions to get/update a resource with a speci�c name:

kubectl create role my-component-lease-holder --verb=get,list,watch,update

kubectl create clusterrole
Creates a ClusterRole. Examples:
• Create a ClusterRole named "pod-reader" that allows user to
perform get , watch and list on pods:

kubectl create clusterrole pod-reader --verb=get,list,watch --resource

• Create a ClusterRole named "pod-reader" with resourceNames
speci�ed:

kubectl create clusterrole pod-reader --verb=get --resource

• Create a ClusterRole named "foo" with apiGroups speci�ed:

kubectl create clusterrole foo --verb=get,list,watch --resource

• Create a ClusterRole named "foo" with subresource permissions:

kubectl create clusterrole foo --verb=get,list,watch --resource

• Create a ClusterRole named "foo" with nonResourceURL speci�ed:

kubectl create clusterrole "foo" --verb=get --non-resource-url

• Create a ClusterRole named "monitoring" with an aggregationRule
speci�ed:

kubectl create clusterrole monitoring --aggregation-rule="rbac.example.com/

kubectl create rolebinding
Grants a Role or ClusterRole within a speci�c namespace. Examples:
• Within the namespace "acme", grant the permissions in the "admin"
ClusterRole to a user named "bob":

2/27/26, 3:33 PM

API Access Control | Kubernetes

70 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

kubectl create rolebinding bob-admin-binding --clusterrole=

• Within the namespace "acme", grant the permissions in the "view"
ClusterRole to the service account in the namespace "acme" named
"myapp":

kubectl create rolebinding myapp-view-binding --clusterrole

• Within the namespace "acme", grant the permissions in the "view"
ClusterRole to a service account in the namespace
"myappnamespace" named "myapp":

kubectl create rolebinding myappnamespace-myapp-view-binding --clusterrole

kubectl create clusterrolebinding
Grants a ClusterRole across the entire cluster (all namespaces).
Examples:
• Across the entire cluster, grant the permissions in the "clusteradmin" ClusterRole to a user named "root":

kubectl create clusterrolebinding root-cluster-admin-binding --clusterrole

• Across the entire cluster, grant the permissions in the
"system:node-proxier" ClusterRole to a user named "system:kubeproxy":

kubectl create clusterrolebinding kube-proxy-binding --clusterrole

• Across the entire cluster, grant the permissions in the "view"
ClusterRole to a service account named "myapp" in the namespace
"acme":

kubectl create clusterrolebinding myapp-view-binding --clusterrole

kubectl auth reconcile
Creates or updates rbac.authorization.k8s.io/v1 API objects from a
manifest �le.
Missing objects are created, and the containing namespace is created for
namespaced objects, if required.
Existing roles are updated to include the permissions in the input objects,
and remove extra permissions if --remove-extra-permissions is
speci�ed.
Existing bindings are updated to include the subjects in the input objects,
and remove extra subjects if --remove-extra-subjects is speci�ed.
Examples:
2/27/26, 3:33 PM

API Access Control | Kubernetes

71 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• Test applying a manifest �le of RBAC objects, displaying changes
that would be made:

kubectl auth reconcile -f my-rbac-rules.yaml --dry-run=client

• Apply a manifest �le of RBAC objects, preserving any extra
permissions (in roles) and any extra subjects (in bindings):

kubectl auth reconcile -f my-rbac-rules.yaml

• Apply a manifest �le of RBAC objects, removing any extra
permissions (in roles) and any extra subjects (in bindings):

kubectl auth reconcile -f my-rbac-rules.yaml --remove-extra-subjects --remo

ServiceAccount permissions
Default RBAC policies grant scoped permissions to control-plane
components, nodes, and controllers, but grant no permissions to service
accounts outside the kube-system namespace (beyond the permissions
given by API discovery roles).
This allows you to grant particular roles to particular ServiceAccounts as
needed. Fine-grained role bindings provide greater security, but require
more e�ort to administrate. Broader grants can give unnecessary (and
potentially escalating) API access to ServiceAccounts, but are easier to
administrate.
In order from most secure to least secure, the approaches are:
1. Grant a role to an application-speci�c service account (best practice)
This requires the application to specify a serviceAccountName in its
pod spec, and for the service account to be created (via the API,
application manifest, kubectl create serviceaccount , etc.).
For example, grant read-only permission within "my-namespace" to
the "my-sa" service account:

kubectl create rolebinding my-sa-view \
--clusterrole=view \
--serviceaccount=my-namespace:my-sa \
--namespace=my-namespace

2. Grant a role to the "default" service account in a namespace
If an application does not specify a serviceAccountName , it uses the
"default" service account.

Permissions given to the "default" service account are
available to any pod in the namespace that does not specify a
serviceAccountName.

2/27/26, 3:33 PM

API Access Control | Kubernetes

72 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

For example, grant read-only permission within "my-namespace" to
the "default" service account:

kubectl create rolebinding default-view \
--clusterrole=view \
--serviceaccount=my-namespace:default \
--namespace=my-namespace

Many add-ons run as the "default" service account in the kubesystem namespace. To allow those add-ons to run with super-user

access, grant cluster-admin permissions to the "default" service
account in the kube-system namespace.

Enabling this means the kube-system namespace contains
Secrets that grant super-user access to your cluster's API.

kubectl create clusterrolebinding add-on-cluster-admin \
--clusterrole=cluster-admin \
--serviceaccount=kube-system:default

3. Grant a role to all service accounts in a namespace
If you want all applications in a namespace to have a role, no matter
what service account they use, you can grant a role to the service
account group for that namespace.
For example, grant read-only permission within "my-namespace" to
all service accounts in that namespace:

kubectl create rolebinding serviceaccounts-view \
--clusterrole=view \
--group=system:serviceaccounts:my-namespace \
--namespace=my-namespace

4. Grant a limited role to all service accounts cluster-wide
(discouraged)
If you don't want to manage permissions per-namespace, you can
grant a cluster-wide role to all service accounts.
For example, grant read-only permission across all namespaces to
all service accounts in the cluster:

kubectl create clusterrolebinding serviceaccounts-view \
--clusterrole=view \
--group=system:serviceaccounts

5. Grant super-user access to all service accounts cluster-wide
(strongly discouraged)
If you don't care about partitioning permissions at all, you can grant
super-user access to all service accounts.

2/27/26, 3:33 PM

API Access Control | Kubernetes

73 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

This allows any application full access to your cluster, and also
grants any user with read access to Secrets (or the ability to
create any pod) full access to your cluster.

kubectl create clusterrolebinding serviceaccounts-cluster-admin
--clusterrole=cluster-admin \
--group=system:serviceaccounts

Write access for EndpointSlices
Kubernetes clusters created before Kubernetes v1.22 include write
access to EndpointSlices (and the now-deprecated Endpoints API) in the
aggregated "edit" and "admin" roles. As a mitigation for CVE-2021-25740,
this access is not part of the aggregated roles in clusters that you create
using Kubernetes v1.22 or later.
Existing clusters that have been upgraded to Kubernetes v1.22 will not be
subject to this change. The CVE announcement includes guidance for
restricting this access in existing clusters.
If you want new clusters to retain this level of access in the aggregated
roles, you can create the following ClusterRole:

access/endpoints-aggregated.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
annotations:
kubernetes.io/description: |Add endpoints write permissions to the edit and admin roles. This was
removed by default in 1.22 because of CVE-2021-25740. See
https://issue.k8s.io/103675. This can allow writers to direct LoadBalancer
or Ingress implementations to expose backend IPs that would not otherwise
be accessible, and can circumvent network policies or security controls
intended to prevent/isolate access to those backends.
EndpointSlices were never included in the edit or admin roles, so there
is nothing to restore for the EndpointSlice API.
labels:
rbac.authorization.k8s.io/aggregate-to-edit: "true"
name: custom:aggregate-to-edit:endpoints # you can change this if you wish
rules:
- apiGroups: [""]
resources: ["endpoints"]
verbs: ["create", "delete", "deletecollection", "patch", "update"

Upgrading from ABAC
Clusters that originally ran older Kubernetes versions often used
permissive ABAC policies, including granting full API access to all service
accounts.
Default RBAC policies grant scoped permissions to control-plane
components, nodes, and controllers, but grant no permissions to service
accounts outside the kube-system namespace (beyond the permissions
given by API discovery roles).

2/27/26, 3:33 PM

API Access Control | Kubernetes

74 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

While far more secure, this can be disruptive to existing workloads
expecting to automatically receive API permissions. Here are two
approaches for managing this transition:

Parallel authorizers
Run both the RBAC and ABAC authorizers, and specify a policy �le that
contains the legacy ABAC policy:

--authorization-mode=...,RBAC,ABAC --authorization-policy-file=

To explain that �rst command line option in detail: if earlier authorizers,
such as Node, deny a request, then the RBAC authorizer attempts to
authorize the API request. If RBAC also denies that API request, the ABAC
authorizer is then run. This means that any request allowed by either the
RBAC or ABAC policies is allowed.
When the kube-apiserver is run with a log level of 5 or higher for the
RBAC component ( --vmodule=rbac*=5 or --v=5 ), you can see RBAC
denials in the API server log (pre�xed with RBAC ). You can use that
information to determine which roles need to be granted to which users,
groups, or service accounts.
Once you have granted roles to service accounts and workloads are
running with no RBAC denial messages in the server logs, you can
remove the ABAC authorizer.

Permissive RBAC permissions
You can replicate a permissive ABAC policy using RBAC role bindings.

The following policy allows
service accounts to act as cluster
administrators. Any application running in a container receives
service account credentials automatically, and could perform any
action against the API, including viewing secrets and modifying
permissions. This is not a recommended policy.

kubectl create clusterrolebinding permissive-binding \
--clusterrole=cluster-admin \
--user=admin \
--user=kubelet \
--group=system:serviceaccounts

After you have transitioned to use RBAC, you should adjust the access
controls for your cluster to ensure that these meet your information
security needs.

2/27/26, 3:33 PM

API Access Control | Kubernetes

75 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Node authorization is a special-purpose authorization mode that
speci�cally authorizes API requests made by kubelets.

Overview
The Node authorizer allows a kubelet to perform API operations. This
includes:
Read operations:
• services
• endpoints
• nodes
• pods
• secrets, con�gmaps, persistent volume claims and persistent
volumes related to pods bound to the kubelet's node

Kubernetes v1.34 [stable](enabled by

ⓘ

default)
Kubelets are limited to reading their own Node objects, and only reading
pods bound to their node.
Write operations:
• nodes and node status (enable the NodeRestriction admission
plugin to limit a kubelet to modify its own node)
• pods and pod status (enable the NodeRestriction admission
plugin to limit a kubelet to modify pods bound to itself)
• events
Auth-related operations:
• read/write access to the Certi�cateSigningRequests API for TLS
bootstrapping
• the ability to create TokenReviews and SubjectAccessReviews for
delegated authentication/authorization checks
In future releases, the node authorizer may add or remove permissions
to ensure kubelets have the minimal set of permissions required to
operate correctly.
In order to be authorized by the Node authorizer, kubelets must use a
credential that identi�es them as being in the system:nodes group, with
a username of system:node:<nodeName> . This group and user name
format match the identity created for each kubelet as part of kubelet TLS
bootstrapping.
The value of <nodeName>

match precisely the name of the node as

registered by the kubelet. By default, this is the host name as provided by
hostname , or overridden via the kubelet option --hostname-override .
However, when using the --cloud-provider kubelet option, the speci�c
hostname may be determined by the cloud provider, ignoring the local
hostname and the --hostname-override option. For speci�cs about how
the kubelet determines the hostname, see the kubelet options reference.
To enable the Node authorizer, start the API server with the -2/27/26, 3:33 PM

API Access Control | Kubernetes

76 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

authorization-config �ag set to a �le that includes the Node

authorizer; for example:

apiVersion: apiserver.config.k8s.io/v1
kind: AuthorizationConfiguration
authorizers:
...
- type: Node
...

Or, start the API server with the --authorization-mode �ag set to a
comma-separated list that includes Node ; for example:

kube-apiserver --authorization-mode=...,Node --other-options --more-options

To limit the API objects kubelets are able to write, enable the
NodeRestriction admission plugin by starting the apiserver with -enable-admission-plugins=...,NodeRestriction,...

Migration considerations
Kubelets outside the system:nodes group
Kubelets outside the system:nodes group would not be authorized by
the Node authorization mode, and would need to continue to be
authorized via whatever mechanism currently authorizes them. The node
admission plugin would not restrict requests from these kubelets.

Kubelets with undi�erentiated usernames
In some deployments, kubelets have credentials that place them in the
system:nodes group, but do not identify the particular node they are
associated with, because they do not have a username in the
system:node:... format. These kubelets would not be authorized by the
Node authorization mode, and would need to continue to be authorized

via whatever mechanism currently authorizes them.
The NodeRestriction admission plugin would ignore requests from
these kubelets, since the default node identi�er implementation would
not consider that a node identity.

2/27/26, 3:33 PM

API Access Control | Kubernetes

77 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

A WebHook is an HTTP callback: an HTTP POST that occurs when
something happens; a simple event-noti�cation via HTTP POST. A web
application implementing WebHooks will POST a message to a URL when
certain things happen.
When speci�ed, mode Webhook causes Kubernetes to query an outside
REST service when determining user privileges.

Con�guration File Format
Mode Webhook requires a �le for HTTP con�guration, specify by the -authorization-webhook-config-file=SOME_FILENAME �ag.

The con�guration �le uses the kubecon�g �le format. Within the �le
"users" refers to the API Server webhook and "clusters" refers to the
remote service.
A con�guration example which uses HTTPS client auth:

# Kubernetes API version
apiVersion: v1
# kind of the API object
kind: Config
# clusters refers to the remote service.
clusters:
- name: name-of-remote-authz-service
cluster:
# CA for verifying the remote service.
certificate-authority: /path/to/ca.pem
# URL of remote service to query. Must use 'https'. May not include parame
server: https://authz.example.com/authorize
# users refers to the API Server's webhook configuration.
users:
- name: name-of-api-server
user:
client-certificate: /path/to/cert.pem # cert for the webhook plugin to use
client-key: /path/to/key.pem

# key matching the cert

# kubeconfig files require a context. Provide one for the API Server.
current-context: webhook
contexts:
- context:
cluster: name-of-remote-authz-service
user: name-of-api-server
name: webhook

Request Payloads
When faced with an authorization decision, the API Server POSTs a JSONserialized authorization.k8s.io/v1beta1 SubjectAccessReview object
describing the action. This object contains �elds describing the user
attempting to make the request, and either details about the resource
being accessed or requests attributes.
Note that webhook API objects are subject to the same versioning
compatibility rules as other Kubernetes API objects. Implementers should
be aware of looser compatibility promises for beta objects and check the
2/27/26, 3:33 PM

API Access Control | Kubernetes

78 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

"apiVersion" �eld of the request to ensure correct deserialization.
Additionally, the API Server must enable the authorization.k8s.io/
v1beta1 API extensions group ( --runtimeconfig=authorization.k8s.io/v1beta1=true ).

An example request body:

{
"apiVersion": "authorization.k8s.io/v1beta1",
"kind": "SubjectAccessReview",
"spec": {
"resourceAttributes": {
"namespace": "kittensandponies",
"verb": "get",
"group": "unicorn.example.org",
"resource": "pods"
},
"user": "jane",
"group": [
"group1",
"group2"
]
}
}

The remote service is expected to �ll the status �eld of the request and
respond to either allow or disallow access. The response body's spec
�eld is ignored and may be omitted. A permissive response would return:

{
"apiVersion": "authorization.k8s.io/v1beta1",
"kind": "SubjectAccessReview",
"status": {
"allowed": true
}
}

For disallowing access there are two methods.
The �rst method is preferred in most cases, and indicates the
authorization webhook does not allow, or has "no opinion" about the
request, but if other authorizers are con�gured, they are given a chance
to allow the request. If there are no other authorizers, or none of them
allow the request, the request is forbidden. The webhook would return:

{
"apiVersion": "authorization.k8s.io/v1beta1",
"kind": "SubjectAccessReview",
"status": {
"allowed": false,
"reason": "user does not have read access to the namespace"
}
}

The second method denies immediately, short-circuiting evaluation by
other con�gured authorizers. This should only be used by webhooks that
have detailed knowledge of the full authorizer con�guration of the
cluster. The webhook would return:

2/27/26, 3:33 PM

API Access Control | Kubernetes

79 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"apiVersion": "authorization.k8s.io/v1beta1",
"kind": "SubjectAccessReview",
"status": {
"allowed": false,
"denied": true,
"reason": "user does not have read access to the namespace"
}
}

Access to non-resource paths are sent as:

{
"apiVersion": "authorization.k8s.io/v1beta1",
"kind": "SubjectAccessReview",
"spec": {
"nonResourceAttributes": {
"path": "/debug",
"verb": "get"
},
"user": "jane",
"group": [
"group1",
"group2"
]
}
}

ⓘ

Kubernetes v1.34 [stable](enabled by

default)
When calling out to an authorization webhook, Kubernetes passes label
and �eld selectors in the request to the authorization webhook. The
authorization webhook can make authorization decisions informed by
the scoped �eld and label selectors, if it wishes.
The SubjectAccessReview API documentation gives guidelines for how
these �elds should be interpreted and handled by authorization
webhooks, speci�cally using the parsed requirements rather than the
raw selector strings, and how to handle unrecognized operators safely.

2/27/26, 3:33 PM

API Access Control | Kubernetes

80 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"apiVersion": "authorization.k8s.io/v1beta1",
"kind": "SubjectAccessReview",
"spec": {
"resourceAttributes": {
"verb": "list",
"group": "",
"resource": "pods",
"fieldSelector": {
"requirements": [
{"key":"spec.nodeName", "operator":"In", "values":["mynode"
]
},
"labelSelector": {
"requirements": [
{"key":"example.com/mykey", "operator":"In", "values"
]
}
},
"user": "jane",
"group": [
"group1",
"group2"
]
}
}

Non-resource paths include: /api , /apis , /metrics , /logs , /debug ,
/healthz , /livez , /openapi/v2 , /readyz , and /version. Clients

require access to /api , /api/* , /apis , /apis/* , and /version to
discover what resources and versions are present on the server. Access
to other non-resource paths can be disallowed without restricting access
to the REST api.
For further information, refer to the SubjectAccessReview API
documentation and webhook.go implementation.

2/27/26, 3:33 PM

API Access Control | Kubernetes

81 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Attribute-based access control (ABAC) de�nes an access control
paradigm whereby access rights are granted to users through the use of
policies which combine attributes together.

Policy File Format
To enable ABAC mode, specify --authorization-policyfile=SOME_FILENAME and --authorization-mode=ABAC on startup.

The �le format is one JSON object per line. There should be no enclosing
list or map, only one map per line.
Each line is a "policy object", where each such object is a map with the
following properties:
• Versioning properties:
◦ apiVersion , type string; valid values are
"abac.authorization.kubernetes.io/v1beta1". Allows versioning
and conversion of the policy format.
◦ kind , type string: valid values are "Policy". Allows versioning
and conversion of the policy format.
• spec property set to a map with the following properties:
◦ Subject-matching properties:
▪ user , type string; the user-string from --token-authfile . If you specify user , it must match the username

of the authenticated user.
▪ group , type string; if you specify group , it must match
one of the groups of the authenticated user.
system:authenticated matches all authenticated

requests. system:unauthenticated matches all
unauthenticated requests.
◦ Resource-matching properties:
▪ apiGroup , type string; an API group.
▪ Ex: apps , networking.k8s.io
▪ Wildcard: * matches all API groups.
▪ namespace , type string; a namespace.
▪ Ex: kube-system
▪ Wildcard: * matches all resource requests.
▪ resource , type string; a resource type
▪ Ex: pods , deployments
▪ Wildcard: * matches all resource requests.
◦ Non-resource-matching properties:
▪ nonResourcePath , type string; non-resource request
paths.
▪ Ex: /version or /apis
▪ Wildcard:
▪ * matches all non-resource requests.
▪ /foo/* matches all subpaths of /foo/ .
◦ readonly , type boolean, when true, means that the Resourcematching policy only applies to get, list, and watch operations,
Non-resource-matching policy only applies to get operation.

2/27/26, 3:33 PM

API Access Control | Kubernetes

82 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

An unset property is the same as a property set to the zero value
for its type (e.g. empty string, 0, false). However, unset should be
preferred for readability.
In the future, policies may be expressed in a JSON format, and
managed via a REST interface.

Authorization Algorithm
A request has attributes which correspond to the properties of a policy
object.
When a request is received, the attributes are determined. Unknown
attributes are set to the zero value of its type (e.g. empty string, 0, false).
A property set to "*" will match any value of the corresponding
attribute.
The tuple of attributes is checked for a match against every policy in the
policy �le. If at least one line matches the request attributes, then the
request is authorized (but may fail later validation).
To permit any authenticated user to do something, write a policy with the
group property set to "system:authenticated" .
To permit any unauthenticated user to do something, write a policy with
the group property set to "system:unauthenticated" .
To permit a user to do anything, write a policy with the apiGroup,
namespace, resource, and nonResourcePath properties set to "*" .

Kubectl
Kubectl uses the /api and /apis endpoints of apiserver to discover
served resource types, and validates objects sent to the API by create/
update operations using schema information located at /openapi/v2 .
When using ABAC authorization, those special resources have to be
explicitly exposed via the nonResourcePath property in a policy (see
examples below):
• /api , /api/* , /apis , and /apis/* for API version negotiation.
• /version for retrieving the server version via kubectl version .
• /swaggerapi/* for create/update operations.
To inspect the HTTP calls involved in a speci�c kubectl operation you can
turn up the verbosity:

kubectl --v=8 version

Examples
1. Alice can do anything to all resources:

{"apiVersion": "abac.authorization.kubernetes.io/v1beta1",

2/27/26, 3:33 PM

API Access Control | Kubernetes

83 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

2. The kubelet can read any pods:

{"apiVersion": "abac.authorization.kubernetes.io/v1beta1",

3. The kubelet can read and write events:

{"apiVersion": "abac.authorization.kubernetes.io/v1beta1",

4. Bob can just read pods in namespace "projectCaribou":

{"apiVersion": "abac.authorization.kubernetes.io/v1beta1",

5. Anyone can make read-only requests to all non-resource paths:

{"apiVersion": "abac.authorization.kubernetes.io/v1beta1",
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1",

Complete �le example

A quick note on service accounts
Every service account has a corresponding ABAC username, and that
service account's username is generated according to the naming
convention:

system:serviceaccount:<namespace>:<serviceaccountname>

Creating a new namespace leads to the creation of a new service account
in the following format:

system:serviceaccount:<namespace>:default

For example, if you wanted to grant the default service account (in the
kube-system namespace) full privilege to the API using ABAC, you would
add this line to your policy �le:

{"apiVersion":"abac.authorization.kubernetes.io/v1beta1","kind"

The apiserver will need to be restarted to pick up the new policy lines.

2/27/26, 3:33 PM

API Access Control | Kubernetes

84 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

This page provides an overview of admission controllers.
An admission controller is a piece of code that intercepts requests to the
Kubernetes API server prior to persistence of the resource, but after the
request is authenticated and authorized.
Several important features of Kubernetes require an admission controller
to be enabled in order to properly support the feature. As a result, a
Kubernetes API server that is not properly con�gured with the right set of
admission controllers is an incomplete server that will not support all the
features you expect.

What are they?
Admission controllers are code within the Kubernetes API server that
check the data arriving in a request to modify a resource.
Admission controllers apply to requests that create, delete, or modify
objects. Admission controllers can also block custom verbs, such as a
request to connect to a pod via an API server proxy. Admission
,
or
controllers do not (and cannot) block requests to read (
objects, because reads bypass the admission control layer.

)

Admission control mechanisms may be validating, mutating, or both.
Mutating controllers may modify the data for the resource being
modi�ed; validating controllers may not.
The admission controllers in Kubernetes 1.35 consist of the list below,
are compiled into the kube-apiserver binary, and may only be
con�gured by the cluster administrator.

Admission control extension points
Within the full list, there are three special controllers:
MutatingAdmissionWebhook, ValidatingAdmissionWebhook, and
ValidatingAdmissionPolicy. The two webhook controllers execute the
mutating and validating (respectively) admission control webhooks which
are con�gured in the API. ValidatingAdmissionPolicy provides a way to
embed declarative validation code within the API, without relying on any
external HTTP callouts.
You can use these three admission controllers to customize cluster
behavior at admission time.

Admission control phases
The admission control process proceeds in two phases. In the �rst phase,
mutating admission controllers are run. In the second phase, validating
admission controllers are run. Note again that some of the controllers
are both.
If any of the controllers in either phase reject the request, the entire
request is rejected immediately and an error is returned to the end-user.
Finally, in addition to sometimes mutating the object in question,
admission controllers may sometimes have side e�ects, that is, mutate
related resources as part of request processing. Incrementing quota
usage is the canonical example of why this is necessary. Any such side-

2/27/26, 3:33 PM

API Access Control | Kubernetes

85 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

e�ect needs a corresponding reclamation or reconciliation process, as a
given admission controller does not know for sure that a given request
will pass all of the other admission controllers.
The ordering of these calls can be seen below.
Admission Control
Called until first rejection
User

Kubernetes API Server

Authentication + Authorization

Mutating Webhook(s)

Validating Admission Policies

Validating Webhook(s)

Request (e.g., create a pod)
Authenticate user and
check user permissions
loop

[For all Mutating Webhooks]
Invoke Mutating Webhooks
Modify or reject object (if needed)

loop

[For all Validating Policies]
Invoke Validating Policies
Reject object (if needed)

par

[For all Validating Webhooks in parallel]
Invoke Validating Webhooks
Reject object (if needed)

Allow or reject request
Response (e.g., success or error)

User

Kubernetes API Server

Authentication + Authorization

Mutating Webhook(s)

Validating Admission Policies

Validating Webhook(s)

Why do I need them?
Several important features of Kubernetes require an admission controller
to be enabled in order to properly support the feature. As a result, a
Kubernetes API server that is not properly con�gured with the right set of
admission controllers is an incomplete server and will not support all the
features you expect.

How do I turn on an admission
controller?
The Kubernetes API server �ag enable-admission-plugins takes a
comma-delimited list of admission control plugins to invoke prior to
modifying objects in the cluster. For example, the following command
line enables the NamespaceLifecycle and the LimitRanger admission
control plugins:

kube-apiserver --enable-admission-plugins=NamespaceLifecycle,LimitRanger ...

Depending on the way your Kubernetes cluster is deployed and
how the API server is started, you may need to apply the settings in
di�erent ways. For example, you may have to modify the systemd
unit �le if the API server is deployed as a systemd service, you may
modify the manifest �le for the API server if Kubernetes is deployed
in a self-hosted way.

How do I turn o� an admission
controller?
The Kubernetes API server �ag disable-admission-plugins takes a
comma-delimited list of admission control plugins to be disabled, even if
2/27/26, 3:33 PM

API Access Control | Kubernetes

86 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

they are in the list of plugins enabled by default.

kube-apiserver --disable-admission-plugins=PodNodeSelector,AlwaysDeny ...

Which plugins are enabled by
default?
To see which admission plugins are enabled:

kube-apiserver -h | grep enable-admission-plugins

In Kubernetes 1.35, the default ones are:

CertificateApproval, CertificateSigning, CertificateSubjectRestriction, DefaultI

What does each admission
controller do?
AlwaysAdmit
Kubernetes v1.13 [deprecated]

ⓘ
: Validating.

This admission controller allows all pods into the cluster. It is
because its behavior is the same as if there were no admission controller
at all.

AlwaysDeny
Kubernetes v1.13 [deprecated]

ⓘ
: Validating.

Rejects all requests. AlwaysDeny is

as it has no real meaning.

AlwaysPullImages
: Mutating and Validating.
This admission controller modi�es every new Pod to force the image pull
policy to Always . This is useful in a multitenant cluster so that users can
be assured that their private images can only be used by those who have
the credentials to pull them. Without this admission controller, once an
image has been pulled to a node, any pod from any user can use it by
knowing the image's name (assuming the Pod is scheduled onto the right
node), without any authorization check against the image. When this
admission controller is enabled, images are always pulled prior to
starting containers, which means valid credentials are required.

2/27/26, 3:33 PM

API Access Control | Kubernetes

87 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Certi�cateApproval
: Validating.
This admission controller observes requests to approve
Certi�cateSigningRequest resources and performs additional
authorization checks to ensure the approving user has permission to
certi�cate requests with the spec.signerName requested on the
Certi�cateSigningRequest resource.
See Certi�cate Signing Requests for more information on the permissions
required to perform di�erent actions on Certi�cateSigningRequest
resources.

Certi�cateSigning
: Validating.
This admission controller observes updates to the status.certificate
�eld of Certi�cateSigningRequest resources and performs an additional
authorization checks to ensure the signing user has permission to
certi�cate requests with the spec.signerName requested on the
Certi�cateSigningRequest resource.
See Certi�cate Signing Requests for more information on the permissions
required to perform di�erent actions on Certi�cateSigningRequest
resources.

Certi�cateSubjectRestriction
: Validating.
This admission controller observes creation of Certi�cateSigningRequest
resources that have a spec.signerName of kubernetes.io/kubeapiserver-client . It rejects any request that speci�es a 'group' (or

'organization attribute') of system:masters .

DefaultIngressClass
: Mutating.
This admission controller observes creation of Ingress objects that do
not request any speci�c ingress class and automatically adds a default
ingress class to them. This way, users that do not request any special
ingress class do not need to care about them at all and they will get the
default one.
This admission controller does not do anything when no default ingress
class is con�gured. When more than one ingress class is marked as
default, it rejects any creation of Ingress with an error and an
administrator must revisit their IngressClass objects and mark only one
as default (with the annotation "ingressclass.kubernetes.io/is-defaultclass"). This admission controller ignores any Ingress updates; it acts
only on creation.
See the Ingress documentation for more about ingress classes and how
to mark one as default.

DefaultStorageClass
: Mutating.
This admission controller observes creation of PersistentVolumeClaim

2/27/26, 3:33 PM

API Access Control | Kubernetes

88 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

objects that do not request any speci�c storage class and automatically
adds a default storage class to them. This way, users that do not request
any special storage class do not need to care about them at all and they
will get the default one.
This admission controller does nothing when no default StorageClass
exists. When more than one storage class is marked as default, and you
then create a PersistentVolumeClaim with no storageClassName set,
Kubernetes uses the most recently created default StorageClass . When
a PersistentVolumeClaim is created with a speci�ed volumeName , it
remains in a pending state if the static volume's storageClassName does
not match the storageClassName on the PersistentVolumeClaim after
any default StorageClass is applied to it. This admission controller ignores
any PersistentVolumeClaim updates; it acts only on creation.
See persistent volume documentation about persistent volume claims
and storage classes and how to mark a storage class as default.

DefaultTolerationSeconds
: Mutating.
This admission controller sets the default forgiveness toleration for pods
to tolerate the taints notready:NoExecute and unreachable:NoExecute
based on the k8s-apiserver input parameters default-not-readytoleration-seconds and default-unreachable-toleration-seconds if

the pods don't already have toleration for taints node.kubernetes.io/
not-ready:NoExecute or node.kubernetes.io/unreachable:NoExecute .

The default value for default-not-ready-toleration-seconds and
default-unreachable-toleration-seconds is 5 minutes.

DenyServiceExternalIPs
: Validating.
This admission controller rejects all net-new usage of the Service �eld
externalIPs . This feature is very powerful (allows network tra�c

interception) and not well controlled by policy. When enabled, users of
the cluster may not create new Services which use externalIPs and may
not add new values to externalIPs on existing Service objects.
Existing uses of externalIPs are not a�ected, and users may remove
values from externalIPs on existing Service objects.
Most users do not need this feature at all, and cluster admins should
consider disabling it. Clusters that do need to use this feature should
consider using some custom policy to manage usage of it.
This admission controller is disabled by default.

EventRateLimit
Kubernetes v1.13 [alpha]

ⓘ
: Validating.

This admission controller mitigates the problem where the API server
gets �ooded by requests to store new Events. The cluster admin can
specify event rate limits by:
• Enabling the EventRateLimit admission controller;
• Referencing an EventRateLimit con�guration �le from the �le

2/27/26, 3:33 PM

API Access Control | Kubernetes

89 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

provided to the API server's command line �ag --admissioncontrol-config-file :

apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: EventRateLimit
path: eventconfig.yaml
...

There are four types of limits that can be speci�ed in the con�guration:
• Server : All Event requests (creation or modi�cations) received by
the API server share a single bucket.
• Namespace : Each namespace has a dedicated bucket.
• User : Each user is allocated a bucket.
• SourceAndObject : A bucket is assigned by each combination of
source and involved object of the event.
Below is a sample eventconfig.yaml for such a con�guration:

apiVersion: eventratelimit.admission.k8s.io/v1alpha1
kind: Configuration
limits:
- type: Namespace
qps: 50
burst: 100
cacheSize: 2000
- type: User
qps: 10
burst: 50

See the EventRateLimit Con�g API (v1alpha1) for more details.
This admission controller is disabled by default.

ExtendedResourceToleration
: Mutating.
This plug-in facilitates creation of dedicated nodes with extended
resources. If operators want to create dedicated nodes with extended
resources (like GPUs, FPGAs etc.), they are expected to taint the node
with the extended resource name as the key. This admission controller, if
enabled, automatically adds tolerations for such taints to pods
requesting extended resources, so users don't have to manually add
these tolerations.
This admission controller is disabled by default.

ImagePolicyWebhook
: Validating.
The ImagePolicyWebhook admission controller allows a backend
webhook to make admission decisions.
This admission controller is disabled by default.

2/27/26, 3:33 PM

API Access Control | Kubernetes

90 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Con�guration �le format
ImagePolicyWebhook uses a con�guration �le to set options for the
behavior of the backend. This �le may be json or yaml and has the
following format:

imagePolicy:
kubeConfigFile: /path/to/kubeconfig/for/backend
# time in s to cache approval
allowTTL: 50
# time in s to cache denial
denyTTL: 50
# time in ms to wait between retries
retryBackoff: 500
# determines behavior if the webhook backend fails
defaultAllow: true

Reference the ImagePolicyWebhook con�guration �le from the �le
provided to the API server's command line �ag --admission-controlconfig-file :

apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
path: imagepolicyconfig.yaml
...

Alternatively, you can embed the con�guration directly in the �le:

apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
configuration:
imagePolicy:
kubeConfigFile: <path-to-kubeconfig-file>
allowTTL: 50
denyTTL: 50
retryBackoff: 500
defaultAllow: true

The ImagePolicyWebhook con�g �le must reference a kubecon�g
formatted �le which sets up the connection to the backend. It is required
that the backend communicate over TLS.
The kubecon�g �le's cluster �eld must point to the remote service, and
the user �eld must contain the returned authorizer.

2/27/26, 3:33 PM

API Access Control | Kubernetes

91 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

# clusters refers to the remote service.
clusters:
- name: name-of-remote-imagepolicy-service
cluster:
certificate-authority: /path/to/ca.pem

# CA for verifying the remote se

server: https://images.example.com/policy # URL of remote service to query
# users refers to the API server's webhook configuration.
users:
- name: name-of-api-server
user:
client-certificate: /path/to/cert.pem # cert for the webhook admission con
client-key: /path/to/key.pem

# key matching the cert

For additional HTTP con�guration, refer to the kubecon�g
documentation.

Request payloads
When faced with an admission decision, the API Server POSTs a JSON
serialized imagepolicy.k8s.io/v1alpha1 ImageReview object describing
the action. This object contains �elds describing the containers being
admitted, as well as any pod annotations that match *.imagepolicy.k8s.io/* .

The webhook API objects are subject to the same versioning
compatibility rules as other Kubernetes API objects. Implementers
should be aware of looser compatibility promises for alpha objects
and check the apiVersion �eld of the request to ensure correct
deserialization. Additionally, the API Server must enable the
imagepolicy.k8s.io/v1alpha1 API extensions group (--runtimeconfig=imagepolicy.k8s.io/v1alpha1=true).

An example request body:

{
"apiVersion": "imagepolicy.k8s.io/v1alpha1",
"kind": "ImageReview",
"spec": {
"containers": [
{
"image": "myrepo/myimage:v1"
},
{
"image": "myrepo/myimage@sha256:beb6bd6a68f114c1dc2ea4b28db81bdf91de202a
}
],
"annotations": {
"mycluster.image-policy.k8s.io/ticket-1234": "break-glass"
},
"namespace": "mynamespace"
}
}

The remote service is expected to �ll the status �eld of the request and
respond to either allow or disallow access. The response body's spec
�eld is ignored, and may be omitted. A permissive response would
return:
2/27/26, 3:33 PM

API Access Control | Kubernetes

92 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"apiVersion": "imagepolicy.k8s.io/v1alpha1",
"kind": "ImageReview",
"status": {
"allowed": true
}
}

To disallow access, the service would return:

{
"apiVersion": "imagepolicy.k8s.io/v1alpha1",
"kind": "ImageReview",
"status": {
"allowed": false,
"reason": "image currently blacklisted"
}
}

For further documentation refer to the imagepolicy.v1alpha1 API.

Extending with Annotations
All annotations on a Pod that match *.image-policy.k8s.io/* are sent
to the webhook. Sending annotations allows users who are aware of the
image policy backend to send extra information to it, and for di�erent
backends implementations to accept di�erent information.
Examples of information you might put here are:
• request to "break glass" to override a policy, in case of emergency.
• a ticket number from a ticket system that documents the breakglass request
• provide a hint to the policy server as to the imageID of the image
being provided, to save it a lookup
In any case, the annotations are provided by the user and are not
validated by Kubernetes in any way.

LimitPodHardAntiA�nityTopology
: Validating.
This admission controller denies any pod that de�nes AntiAffinity
topology key other than kubernetes.io/hostname in
requiredDuringSchedulingRequiredDuringExecution .

This admission controller is disabled by default.

LimitRanger
: Mutating and Validating.
This admission controller will observe the incoming request and ensure
that it does not violate any of the constraints enumerated in the
LimitRange object in a Namespace . If you are using LimitRange objects

in your Kubernetes deployment, you MUST use this admission controller
to enforce those constraints. LimitRanger can also be used to apply
default resource requests to Pods that don't specify any; currently, the
default LimitRanger applies a 0.1 CPU requirement to all Pods in the

2/27/26, 3:33 PM

API Access Control | Kubernetes

93 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

default namespace.

See the LimitRange API reference and the example of LimitRange for
more details.

MutatingAdmissionWebhook
: Mutating.
This admission controller calls any mutating webhooks which match the
request. Matching webhooks are called in serial; each one may modify
the object if it desires.
This admission controller (as implied by the name) only runs in the
mutating phase.
If a webhook called by this has side e�ects (for example, decrementing
quota) it must have a reconciliation system, as it is not guaranteed that
subsequent webhooks or validating admission controllers will permit the
request to �nish.
If you disable the MutatingAdmissionWebhook, you must also disable the
MutatingWebhookConfiguration object in the
admissionregistration.k8s.io/v1 group/version via the --runtimeconfig �ag, both are on by default.

Use caution when authoring and installing mutating webhooks
• Users may be confused when the objects they try to create are
di�erent from what they get back.
• Built in control loops may break when the objects they try to create
are di�erent when read back.
◦ Setting originally unset �elds is less likely to cause problems
than overwriting �elds set in the original request. Avoid doing
the latter.
• Future changes to control loops for built-in resources or third-party
resources may break webhooks that work well today. Even when
the webhook installation API is �nalized, not all possible webhook
behaviors will be guaranteed to be supported inde�nitely.

NamespaceAutoProvision
: Mutating.
This admission controller examines all incoming requests on
namespaced resources and checks if the referenced namespace does
exist. It creates a namespace if it cannot be found. This admission
controller is useful in deployments that do not want to restrict creation of
a namespace prior to its usage.

NamespaceExists
: Validating.
This admission controller checks all requests on namespaced resources
other than Namespace itself. If the namespace referenced from a request
doesn't exist, the request is rejected.

NamespaceLifecycle
: Validating.
This admission controller enforces that a Namespace that is undergoing
2/27/26, 3:33 PM

API Access Control | Kubernetes

94 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

termination cannot have new objects created in it, and ensures that
requests in a non-existent Namespace are rejected. This admission
controller also prevents deletion of three system reserved namespaces
default , kube-system , kube-public .

A Namespace deletion kicks o� a sequence of operations that remove all
objects (pods, services, etc.) in that namespace. In order to enforce
integrity of that process, we strongly recommend running this admission
controller.

NodeDeclaredFeatureValidator
Kubernetes v1.35 [alpha](disabled by

ⓘ

default)
: Validating.
This admission controller intercepts writes to bound Pods, to ensure that
the changes are compatible with the features declared by the node
where the Pod is currently running. It uses the
.status.declaredFeatures �eld of the Node to determine the set of
enabled features. If a Pod update requires a feature that is not listed in
the features of its current node, the admission controller will reject the
update request. This prevents runtime failures due to feature mismatch
after a Pod has been scheduled.
This admission controller is enabled by default if the
NodeDeclaredFeatures feature gate is enabled.

NodeRestriction
: Validating.
This admission controller limits the Node and Pod objects a kubelet can
modify. In order to be limited by this admission controller, kubelets must
use credentials in the system:nodes group, with a username in the form
system:node:<nodeName> . Such kubelets will only be allowed to modify

their own Node API object, and only modify Pod API objects that are
bound to their node. kubelets are not allowed to update or remove taints
from their Node API object.
The NodeRestriction admission plugin prevents kubelets from deleting
their Node API object, and enforces kubelet modi�cation of labels under
the kubernetes.io/ or k8s.io/ pre�xes as follows:
•

kubelets from adding/removing/updating labels with a
node-restriction.kubernetes.io/ pre�x. This label pre�x is
reserved for administrators to label their Node objects for
workload isolation purposes, and kubelets will not be allowed to
modify labels with that pre�x.

•

kubelets to add/remove/update these labels and label
pre�xes:
◦ kubernetes.io/hostname
◦ kubernetes.io/arch
◦ kubernetes.io/os
◦ beta.kubernetes.io/instance-type
◦ node.kubernetes.io/instance-type
◦ failure-domain.beta.kubernetes.io/region (deprecated)
◦ failure-domain.beta.kubernetes.io/zone (deprecated)

2/27/26, 3:33 PM

API Access Control | Kubernetes

95 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

◦ topology.kubernetes.io/region
◦ topology.kubernetes.io/zone
◦ kubelet.kubernetes.io/ -pre�xed labels
◦ node.kubernetes.io/ -pre�xed labels
Use of any other labels under the kubernetes.io or k8s.io pre�xes by
kubelets is reserved, and may be disallowed or allowed by the
NodeRestriction admission plugin in the future.

Future versions may add additional restrictions to ensure kubelets have
the minimal set of permissions required to operate correctly.

OwnerReferencesPermissionEnforcement
: Validating.
This admission controller protects the access to the
metadata.ownerReferences of an object so that only users with
permission to the object can change it. This admission controller also
protects the access to
metadata.ownerReferences[x].blockOwnerDeletion of an object, so that
only users with

permission to the finalizers subresource of

the referenced owner can change it.

PersistentVolumeClaimResize
Kubernetes v1.24 [stable]

ⓘ
: Validating.

This admission controller implements additional validations for checking
incoming PersistentVolumeClaim resize requests.
Enabling the PersistentVolumeClaimResize admission controller is
recommended. This admission controller prevents resizing of all claims
by default unless a claim's StorageClass explicitly enables resizing by
setting allowVolumeExpansion to true .
For example: all PersistentVolumeClaim s created from the following
StorageClass support volume expansion:

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
name: gluster-vol-default
provisioner: kubernetes.io/glusterfs
parameters:
resturl: "http://192.168.10.100:8080"
restuser: ""
secretNamespace: ""
secretName: ""
allowVolumeExpansion: true

For more information about persistent volume claims, see
PersistentVolumeClaims.

PodNodeSelector

2/27/26, 3:33 PM

API Access Control | Kubernetes

96 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Kubernetes v1.5 [alpha]

ⓘ
: Validating.

This admission controller defaults and limits what node selectors may be
used within a namespace by reading a namespace annotation and a
global con�guration.
This admission controller is disabled by default.

Con�guration �le format
PodNodeSelector uses a con�guration �le to set options for the behavior

of the backend. Note that the con�guration �le format will move to a
versioned �le in a future release. This �le may be json or yaml and has
the following format:

podNodeSelectorPluginConfig:
clusterDefaultNodeSelector: name-of-node-selector
namespace1: name-of-node-selector
namespace2: name-of-node-selector

Reference the PodNodeSelector con�guration �le from the �le provided
to the API server's command line �ag --admission-control-configfile :

apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodNodeSelector
path: podnodeselector.yaml
...

Con�guration Annotation Format
PodNodeSelector uses the annotation key
scheduler.alpha.kubernetes.io/node-selector to assign node selectors

to namespaces.

apiVersion: v1
kind: Namespace
metadata:
annotations:
scheduler.alpha.kubernetes.io/node-selector: name-of-node-selector
name: namespace3

Internal Behavior
This admission controller has the following behavior:
1. If the Namespace has an annotation with a key
scheduler.alpha.kubernetes.io/node-selector , use its value as

the node selector.
2. If the namespace lacks such an annotation, use the
clusterDefaultNodeSelector de�ned in the PodNodeSelector

plugin con�guration �le as the node selector.
2/27/26, 3:33 PM

API Access Control | Kubernetes

97 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

3. Evaluate the pod's node selector against the namespace node
selector for con�icts. Con�icts result in rejection.
4. Evaluate the pod's node selector against the namespace-speci�c
allowed selector de�ned the plugin con�guration �le. Con�icts
result in rejection.

PodNodeSelector allows forcing pods to run on speci�cally labeled
nodes. Also see the PodTolerationRestriction admission plugin,
which allows preventing pods from running on speci�cally tainted
nodes.

PodSecurity
Kubernetes v1.25 [stable]

ⓘ
: Validating.

The PodSecurity admission controller checks new Pods before they are
admitted, determines if it should be admitted based on the requested
security context and the restrictions on permitted Pod Security Standards
for the namespace that the Pod would be in.
See the Pod Security Admission documentation for more information.
PodSecurity replaced an older admission controller named
PodSecurityPolicy.

PodTolerationRestriction
ⓘ

Kubernetes v1.7 [alpha]
: Mutating and Validating.

The PodTolerationRestriction admission controller veri�es any con�ict
between tolerations of a pod and the tolerations of its namespace. It
rejects the pod request if there is a con�ict. It then merges the
tolerations annotated on the namespace into the tolerations of the pod.
The resulting tolerations are checked against a list of allowed tolerations
annotated to the namespace. If the check succeeds, the pod request is
admitted otherwise it is rejected.
If the namespace of the pod does not have any associated default
tolerations or allowed tolerations annotated, the cluster-level default
tolerations or cluster-level list of allowed tolerations are used instead if
they are speci�ed.
Tolerations to a namespace are assigned via the
scheduler.alpha.kubernetes.io/defaultTolerations annotation key.

The list of allowed tolerations can be added via the
scheduler.alpha.kubernetes.io/tolerationsWhitelist annotation key.

Example for namespace annotations:

2/27/26, 3:33 PM

API Access Control | Kubernetes

98 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: v1
kind: Namespace
metadata:
name: apps-that-need-nodes-exclusively
annotations:
scheduler.alpha.kubernetes.io/defaultTolerations: '[{"operator": "Exists", "
scheduler.alpha.kubernetes.io/tolerationsWhitelist: '[{"operator": "Exists",

This admission controller is disabled by default.

PodTopologyLabels
Kubernetes v1.35 [beta](enabled by

ⓘ

default)
: Mutating
The PodTopologyLabels admission controller mutates the pods/binding
subresources for all pods bound to a Node, adding topology labels
matching those of the bound Node. This allows Node topology labels to
be available as pod labels, which can be surfaced to running containers
using the Downward API. The labels available as a result of this controller
are the topology.kubernetes.io/region and topology.kuberentes.io/zone
labels.

If any mutating admission webhook adds or modi�es labels of the
pods/binding subresource, these changes will propagate to pod
labels as a result of this controller, overwriting labels with
con�icting keys.

This admission controller is enabled when the
PodTopologyLabelsAdmission feature gate is enabled.

Priority
: Mutating and Validating.
The priority admission controller uses the priorityClassName �eld and
populates the integer value of the priority. If the priority class is not
found, the Pod is rejected.

ResourceQuota
: Validating.
This admission controller will observe the incoming request and ensure
that it does not violate any of the constraints enumerated in the
ResourceQuota object in a Namespace . If you are using ResourceQuota
objects in your Kubernetes deployment, you MUST use this admission
controller to enforce quota constraints.
See the ResourceQuota API reference and the example of Resource
Quota for more details.

RuntimeClass

2/27/26, 3:33 PM

API Access Control | Kubernetes

99 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

: Mutating and Validating.
If you de�ne a RuntimeClass with Pod overhead con�gured, this
admission controller checks incoming Pods. When enabled, this
admission controller rejects any Pod create requests that have the
overhead already set. For Pods that have a RuntimeClass con�gured and
selected in their .spec , this admission controller sets .spec.overhead
in the Pod based on the value de�ned in the corresponding
RuntimeClass.
See also Pod Overhead for more information.

ServiceAccount
: Mutating and Validating.
This admission controller implements automation for serviceAccounts.
The Kubernetes project strongly recommends enabling this admission
controller. You should enable this admission controller if you intend to
make any use of Kubernetes ServiceAccount objects.
To enhance the security measures around Secrets, use separate
namespaces to isolate access to mounted secrets.

StorageObjectInUseProtection
: Mutating.
The StorageObjectInUseProtection plugin adds the kubernetes.io/
pvc-protection or kubernetes.io/pv-protection �nalizers to newly

created Persistent Volume Claims (PVCs) or Persistent Volumes (PV). In
case a user deletes a PVC or PV the PVC or PV is not removed until the
�nalizer is removed from the PVC or PV by PVC or PV Protection
Controller. Refer to the Storage Object in Use Protection for more
detailed information.

TaintNodesByCondition
: Mutating.
This admission controller taints newly created Nodes as NotReady and
NoSchedule . That tainting avoids a race condition that could cause Pods

to be scheduled on new Nodes before their taints were updated to
accurately re�ect their reported conditions.

ValidatingAdmissionPolicy
: Validating.
This admission controller implements the CEL validation for incoming
matched requests. It is enabled when both feature gate
validatingadmissionpolicy and admissionregistration.k8s.io/
v1alpha1 group/version are enabled. If any of the

ValidatingAdmissionPolicy fails, the request fails.

ValidatingAdmissionWebhook
: Validating.
This admission controller calls any validating webhooks which match the
request. Matching webhooks are called in parallel; if any of them rejects
the request, the request fails. This admission controller only runs in the
validation phase; the webhooks it calls may not mutate the object, as
2/27/26, 3:33 PM

API Access Control | Kubernetes

100 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

opposed to the webhooks called by the MutatingAdmissionWebhook
admission controller.
If a webhook called by this has side e�ects (for example, decrementing
quota) it must have a reconciliation system, as it is not guaranteed that
subsequent webhooks or other validating admission controllers will
permit the request to �nish.
If you disable the ValidatingAdmissionWebhook, you must also disable
the ValidatingWebhookConfiguration object in the
admissionregistration.k8s.io/v1 group/version via the --runtimeconfig �ag.

Is there a recommended set of
admission controllers to use?
Yes. The recommended admission controllers are enabled by default
(shown here), so you do not need to explicitly specify them. You can
enable additional admission controllers beyond the default set using the
--enable-admission-plugins �ag (
).

2/27/26, 3:33 PM

API Access Control | Kubernetes

101 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

In addition to compiled-in admission plugins, admission plugins can be
developed as extensions and run as webhooks con�gured at runtime.
This page describes how to build, con�gure, use, and monitor admission
webhooks.

What are admission webhooks?
Admission webhooks are HTTP callbacks that receive admission requests
and do something with them. You can de�ne two types of admission
webhooks, validating admission webhook and mutating admission
webhook. Mutating admission webhooks are invoked �rst, and can
modify objects sent to the API server to enforce custom defaults. After all
object modi�cations are complete, and after the incoming object is
validated by the API server, validating admission webhooks are invoked
and can reject requests to enforce custom policies.

Admission webhooks that need to guarantee they see the �nal
state of the object in order to enforce policy should use a validating
admission webhook, since objects can be modi�ed after being seen
by mutating webhooks.

Experimenting with admission
webhooks
Admission webhooks are essentially part of the cluster control-plane. You
should write and deploy them with great caution. Please read the user
guides for instructions if you intend to write/deploy production-grade
admission webhooks. In the following, we describe how to quickly
experiment with admission webhooks.

Prerequisites
• Ensure that MutatingAdmissionWebhook and
ValidatingAdmissionWebhook admission controllers are enabled.
Here is a recommended set of admission controllers to enable in
general.
• Ensure that the admissionregistration.k8s.io/v1 API is enabled.

Write an admission webhook server
Please refer to the implementation of the admission webhook server that
is validated in a Kubernetes e2e test. The webhook handles the
AdmissionReview request sent by the API servers, and sends back its
decision as an AdmissionReview object in the same version it received.
See the webhook request section for details on the data sent to
webhooks.
See the webhook response section for the data expected from
webhooks.
The example admission webhook server leaves the ClientAuth �eld
2/27/26, 3:33 PM

API Access Control | Kubernetes

102 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

empty, which defaults to NoClientCert . This means that the webhook
server does not authenticate the identity of the clients, supposedly API
servers. If you need mutual TLS or other ways to authenticate the clients,
see how to authenticate API servers.

Deploy the admission webhook service
The webhook server in the e2e test is deployed in the Kubernetes cluster,
via the deployment API. The test also creates a service as the front-end of
the webhook server. See code.
You may also deploy your webhooks outside of the cluster. You will need
to update your webhook con�gurations accordingly.

Con�gure admission webhooks on the �y
You can dynamically con�gure what resources are subject to what
admission webhooks via ValidatingWebhookCon�guration or
MutatingWebhookCon�guration.
The following is an example ValidatingWebhookConfiguration , a
mutating webhook con�guration is similar. See the webhook
con�guration section for details about each con�g �eld.

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
name: "pod-policy.example.com"
webhooks:
- name: "pod-policy.example.com"
rules:
- apiGroups:

[""]

apiVersions: ["v1"]
operations:

["CREATE"]

resources:

["pods"]

scope:

"Namespaced"

clientConfig:
service:
namespace: "example-namespace"
name: "example-service"
caBundle: <CA_BUNDLE>
admissionReviewVersions: ["v1"]
sideEffects: None
timeoutSeconds: 5

You must replace the <CA_BUNDLE> in the above example by a valid
CA bundle which is a PEM-encoded (�eld value is Base64 encoded)
CA bundle for validating the webhook's server certi�cate.

The scope �eld speci�es if only cluster-scoped resources ("Cluster") or
namespace-scoped resources ("Namespaced") will match this rule. "∗"
means that there are no scope restrictions.

When using clientConfig.service, the server cert must be valid
for <svc_name>.<svc_namespace>.svc.

2/27/26, 3:33 PM

API Access Control | Kubernetes

103 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Default timeout for a webhook call is 10 seconds, You can set the
timeout and it is encouraged to use a short timeout for webhooks.
If the webhook call times out, the request is handled according to
the webhook's failure policy.

When an API server receives a request that matches one of the rules ,
the API server sends an admissionReview request to webhook as
speci�ed in the clientConfig .
After you create the webhook con�guration, the system will take a few
seconds to honor the new con�guration.

Authenticate API servers
If your admission webhooks require authentication, you can con�gure
the API servers to use basic auth, bearer token, or a cert to authenticate
itself to the webhooks. There are three steps to complete the
con�guration.
• When starting the API server, specify the location of the admission
control con�guration �le via the --admission-control-config-file
�ag.
• In the admission control con�guration �le, specify where the
MutatingAdmissionWebhook controller and
ValidatingAdmissionWebhook controller should read the
credentials. The credentials are stored in kubeCon�g �les (yes, the
same schema that's used by kubectl), so the �eld name is
kubeConfigFile . Here is an example admission control
con�guration �le:
apiserver.con�g.k8s.io/v1

apiserver.k8s.io/v1alpha1

apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ValidatingAdmissionWebhook
configuration:
apiVersion: apiserver.config.k8s.io/v1
kind: WebhookAdmissionConfiguration
kubeConfigFile: "<path-to-kubeconfig-file>"
- name: MutatingAdmissionWebhook
configuration:
apiVersion: apiserver.config.k8s.io/v1
kind: WebhookAdmissionConfiguration
kubeConfigFile: "<path-to-kubeconfig-file>"

For more information about AdmissionConfiguration , see the
AdmissionCon�guration (v1) reference. See the webhook con�guration
section for details about each con�g �eld.
In the kubeCon�g �le, provide the credentials:

2/27/26, 3:33 PM

API Access Control | Kubernetes

104 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: v1
kind: Config
users:
# name should be set to the DNS name of the service or the host (including port)
# If a non-443 port is used for services, it must be included in the name when c
#
# For a webhook configured to speak to a service on the default port (443), spec
# - name: webhook1.ns1.svc
#

user: ...

#
# For a webhook configured to speak to a service on non-default port (e.g. 8443)
# - name: webhook1.ns1.svc:8443
#

user: ...

# and optionally create a second stanza using only the DNS name of the service f
# - name: webhook1.ns1.svc
#

user: ...

#
# For webhooks configured to speak to a URL, match the host (and port) specified
# A webhook with `url: https://www.example.com`:
# - name: www.example.com
#

user: ...

#
# A webhook with `url: https://www.example.com:443`:
# - name: www.example.com:443
#

user: ...

#
# A webhook with `url: https://www.example.com:8443`:
# - name: www.example.com:8443
#

user: ...

#
- name: 'webhook1.ns1.svc'
user:
client-certificate-data: "<pem encoded certificate>"
client-key-data: "<pem encoded key>"
# The `name` supports using * to wildcard-match prefixing segments.
- name: '*.webhook-company.org'
user:
password: "<password>"
username: "<name>"
# '*' is the default match.
- name: '*'
user:
token: "<token>"

Of course you need to set up the webhook server to handle these
authentication requests.

Webhook request and response
Request
Webhooks are sent as POST requests, with Content-Type: application/
json , with an AdmissionReview API object in the admission.k8s.io API

group serialized to JSON as the body.
Webhooks can specify what versions of AdmissionReview objects they
accept with the admissionReviewVersions �eld in their con�guration:

2/27/26, 3:33 PM

API Access Control | Kubernetes

105 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
admissionReviewVersions: ["v1", "v1beta1"]

admissionReviewVersions is a required �eld when creating webhook

con�gurations. Webhooks are required to support at least one
AdmissionReview version understood by the current and previous API

server.
API servers send the �rst AdmissionReview version in the
admissionReviewVersions list they support. If none of the versions in the

list are supported by the API server, the con�guration will not be allowed
to be created. If an API server encounters a webhook con�guration that
was previously created and does not support any of the
AdmissionReview versions the API server knows how to send, attempts

to call to the webhook will fail and be subject to the failure policy.
This example shows the data contained in an AdmissionReview object
for a request to update the scale subresource of an apps/v1
Deployment :

2/27/26, 3:33 PM

API Access Control | Kubernetes

106 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"apiVersion": "admission.k8s.io/v1",
"kind": "AdmissionReview",
"request": {
# Random uid uniquely identifying this admission call
"uid": "705ab4f5-6393-11e8-b7cc-42010a800002",
# Fully-qualified group/version/kind of the incoming object
"kind": {
"group": "autoscaling",
"version": "v1",
"kind": "Scale"
},
# Fully-qualified group/version/kind of the resource being modified
"resource": {
"group": "apps",
"version": "v1",
"resource": "deployments"
},
# Subresource, if the request is to a subresource
"subResource": "scale",
# Fully-qualified group/version/kind of the incoming object in the original
# This only differs from `kind` if the webhook specified `matchPolicy: Equiv
# request to the API server was converted to a version the webhook registere
"requestKind": {
"group": "autoscaling",
"version": "v1",
"kind": "Scale"
},
# Fully-qualified group/version/kind of the resource being modified in the o
# This only differs from `resource` if the webhook specified `matchPolicy: E
# request to the API server was converted to a version the webhook registere
"requestResource": {
"group": "apps",
"version": "v1",
"resource": "deployments"
},
# Subresource, if the request is to a subresource
# This only differs from `subResource` if the webhook specified `matchPolicy
# request to the API server was converted to a version the webhook registere
"requestSubResource": "scale",
# Name of the resource being modified
"name": "my-deployment",
# Namespace of the resource being modified, if the resource is namespaced (o
"namespace": "my-namespace",
# operation can be CREATE, UPDATE, DELETE, or CONNECT
"operation": "UPDATE",
"userInfo": {
# Username of the authenticated user making the request to the API server
"username": "admin",
# UID of the authenticated user making the request to the API server
"uid": "014fbff9a07c",
# Group memberships of the authenticated user making the request to the AP
"groups": [

2/27/26, 3:33 PM

API Access Control | Kubernetes

107 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

"system:authenticated",
"my-admin-group"
],
# Arbitrary extra info associated with the user making the request to the
# This is populated by the API server authentication layer
"extra": {
"some-key": [
"some-value1",
"some-value2"
]
}
},
# object is the new object being admitted. It is null for DELETE operations
"object": {
"apiVersion": "autoscaling/v1",
"kind": "Scale"
},
# oldObject is the existing object. It is null for CREATE and CONNECT operat
"oldObject": {
"apiVersion": "autoscaling/v1",
"kind": "Scale"
},
# options contain the options for the operation being admitted, like meta.k8
# UpdateOptions, or DeleteOptions. It is null for CONNECT operations
"options": {
"apiVersion": "meta.k8s.io/v1",
"kind": "UpdateOptions"
},
# dryRun indicates the API request is running in dry run mode and will not b
# Webhooks with side effects should avoid actuating those side effects when
"dryRun": false
}
}

Response
Webhooks respond with a 200 HTTP status code, Content-Type:
application/json , and a body containing an AdmissionReview object (in

the same version they were sent), with the response stanza populated,
serialized to JSON.
At a minimum, the response stanza must contain the following �elds:
• uid , copied from the request.uid sent to the webhook
• allowed , either set to true or false
Example of a minimal response from a webhook to allow a request:

{
"apiVersion": "admission.k8s.io/v1",
"kind": "AdmissionReview",
"response": {
"uid": "<value from request.uid>",
"allowed": true
}
}

Example of a minimal response from a webhook to forbid a request:
2/27/26, 3:33 PM

API Access Control | Kubernetes

108 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

{
"apiVersion": "admission.k8s.io/v1",
"kind": "AdmissionReview",
"response": {
"uid": "<value from request.uid>",
"allowed": false
}
}

When rejecting a request, the webhook can customize the http code and
message returned to the user using the status �eld. The speci�ed
status object is returned to the user. See the API documentation for
details about the status type. Example of a response to forbid a
request, customizing the HTTP status code and message presented to
the user:

{
"apiVersion": "admission.k8s.io/v1",
"kind": "AdmissionReview",
"response": {
"uid": "<value from request.uid>",
"allowed": false,
"status": {
"code": 403,
"message": "You cannot do this because it is Tuesday and your name starts
}
}
}

When allowing a request, a mutating admission webhook may optionally
modify the incoming object as well. This is done using the patch and
patchType �elds in the response. The only currently supported
patchType is JSONPatch . See JSON patch documentation for more

details. For patchType: JSONPatch , the patch �eld contains a base64encoded array of JSON patch operations.
As an example, a single patch operation that would set spec.replicas
would be [{"op": "add", "path": "/spec/replicas", "value": 3}]
Base64-encoded, this would be
W3sib3AiOiAiYWRkIiwgInBhdGgiOiAiL3NwZWMvcmVwbGljYXMiLCAidmFsdWUiO
iAzfV0=

So a webhook response to add that label would be:

{
"apiVersion": "admission.k8s.io/v1",
"kind": "AdmissionReview",
"response": {
"uid": "<value from request.uid>",
"allowed": true,
"patchType": "JSONPatch",
"patch": "W3sib3AiOiAiYWRkIiwgInBhdGgiOiAiL3NwZWMvcmVwbGljYXMiLCAidmFsdWUiOi
}
}

Admission webhooks can optionally return warning messages that are
returned to the requesting client in HTTP Warning headers with a
warning code of 299. Warnings can be sent with allowed or rejected
admission responses.
2/27/26, 3:33 PM

API Access Control | Kubernetes

109 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

If you're implementing a webhook that returns a warning:
• Don't include a "Warning:" pre�x in the message
• Use warning messages to describe problems the client making the
API request should correct or be aware of
• Limit warnings to 120 characters if possible

Individual warning messages over 256 characters may be truncated
by the API server before being returned to clients. If more than
4096 characters of warning messages are added (from all sources),
additional warning messages are ignored.

{
"apiVersion": "admission.k8s.io/v1",
"kind": "AdmissionReview",
"response": {
"uid": "<value from request.uid>",
"allowed": true,
"warnings": [
"duplicate envvar entries specified with name MY_ENV",
"memory request less than 4MB specified for container mycontainer, which w
]
}
}

Webhook con�guration
To register admission webhooks, create MutatingWebhookConfiguration
or ValidatingWebhookConfiguration API objects. The name of a
MutatingWebhookConfiguration or a ValidatingWebhookConfiguration

object must be a valid DNS subdomain name.
Each con�guration can contain one or more webhooks. If multiple
webhooks are speci�ed in a single con�guration, each must be given a
unique name. This is required in order to make resulting audit logs and
metrics easier to match up to active con�gurations.
Each webhook de�nes the following things.

Matching requests: rules
Each webhook must specify a list of rules used to determine if a request
to the API server should be sent to the webhook. Each rule speci�es one
or more operations, apiGroups, apiVersions, and resources, and a
resource scope:
• operations lists one or more operations to match. Can be
"CREATE" , "UPDATE" , "DELETE" , "CONNECT" , or "*" to match all.

• apiGroups lists one or more API groups to match. "" is the core
API group. "*" matches all API groups.
• apiVersions lists one or more API versions to match. "*"
matches all API versions.
• resources lists one or more resources to match.
◦ "*" matches all resources, but not subresources.
◦ "*/*" matches all resources and subresources.

2/27/26, 3:33 PM

API Access Control | Kubernetes

110 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

◦ "pods/*" matches all subresources of pods.
◦ "*/status" matches all status subresources.
• scope speci�es a scope to match. Valid values are "Cluster" ,
"Namespaced" , and "*" . Subresources match the scope of their

parent resource. Default is "*" .
◦ "Cluster" means that only cluster-scoped resources will
match this rule (Namespace API objects are cluster-scoped).
◦ "Namespaced" means that only namespaced resources will
match this rule.
◦ "*" means that there are no scope restrictions.
If an incoming request matches one of the speci�ed operations ,
groups , versions , resources , and scope for any of a webhook's
rules , the request is sent to the webhook.

Here are other examples of rules that could be used to specify which
resources should be intercepted.
Match CREATE or UPDATE requests to apps/v1 and apps/v1beta1
deployments and replicasets :

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
...
webhooks:
- name: my-webhook.example.com
rules:
- operations: ["CREATE", "UPDATE"]
apiGroups: ["apps"]
apiVersions: ["v1", "v1beta1"]
resources: ["deployments", "replicasets"]
scope: "Namespaced"
...

Match create requests for all resources (but not subresources) in all API
groups and versions:

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
rules:
- operations: ["CREATE"]
apiGroups: ["*"]
apiVersions: ["*"]
resources: ["*"]
scope: "*"

Match update requests for all status subresources in all API groups and
versions:

2/27/26, 3:33 PM

API Access Control | Kubernetes

111 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
rules:
- operations: ["UPDATE"]
apiGroups: ["*"]
apiVersions: ["*"]
resources: ["*/status"]
scope: "*"

Matching requests: objectSelector
Webhooks may optionally limit which requests are intercepted based on
the labels of the objects they would be sent, by specifying an
objectSelector . If speci�ed, the objectSelector is evaluated against both
the object and oldObject that would be sent to the webhook, and is
considered to match if either object matches the selector.
A null object ( oldObject in the case of create, or newObject in the case
of delete), or an object that cannot have labels (like a
DeploymentRollback or a PodProxyOptions object) is not considered to

match.
Use the object selector only if the webhook is opt-in, because end users
may skip the admission webhook by setting the labels.
This example shows a mutating webhook that would match a CREATE of
any resource (but not subresources) with the label foo: bar :

apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
objectSelector:
matchLabels:
foo: bar
rules:
- operations: ["CREATE"]
apiGroups: ["*"]
apiVersions: ["*"]
resources: ["*"]
scope: "*"

See labels concept for more examples of label selectors.

Matching requests: namespaceSelector
Webhooks may optionally limit which requests for namespaced
resources are intercepted, based on the labels of the containing
namespace, by specifying a namespaceSelector .
The namespaceSelector decides whether to run the webhook on a
request for a namespaced resource (or a Namespace object), based on
whether the namespace's labels match the selector. If the object itself is
a namespace, the matching is performed on object.metadata.labels. If
the object is a cluster scoped resource other than a Namespace,
namespaceSelector has no e�ect.

This example shows a mutating webhook that matches a CREATE of any

2/27/26, 3:33 PM

API Access Control | Kubernetes

112 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

namespaced resource inside a namespace that does not have a
"runlevel" label of "0" or "1":

apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
namespaceSelector:
matchExpressions:
- key: runlevel
operator: NotIn
values: ["0","1"]
rules:
- operations: ["CREATE"]
apiGroups: ["*"]
apiVersions: ["*"]
resources: ["*"]
scope: "Namespaced"

This example shows a validating webhook that matches a CREATE of any
namespaced resource inside a namespace that is associated with the
"environment" of "prod" or "staging":

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
namespaceSelector:
matchExpressions:
- key: environment
operator: In
values: ["prod","staging"]
rules:
- operations: ["CREATE"]
apiGroups: ["*"]
apiVersions: ["*"]
resources: ["*"]
scope: "Namespaced"

See labels concept for more examples of label selectors.

Matching requests: matchPolicy
API servers can make objects available via multiple API groups or
versions.
For example, if a webhook only speci�ed a rule for some API groups/
versions (like apiGroups:["apps"], apiVersions:["v1","v1beta1"] ), and
a request was made to modify the resource via another API group/
version (like extensions/v1beta1 ), the request would not be sent to the
webhook.
The matchPolicy lets a webhook de�ne how its rules are used to
match incoming requests. Allowed values are Exact or Equivalent .
• Exact means a request should be intercepted only if it exactly
matches a speci�ed rule.
• Equivalent means a request should be intercepted if it modi�es a
resource listed in rules , even via another API group or version.

2/27/26, 3:33 PM

API Access Control | Kubernetes

113 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

In the example given above, the webhook that only registered for apps/
v1 could use matchPolicy :

• matchPolicy: Exact would mean the extensions/v1beta1 request
would not be sent to the webhook
• matchPolicy: Equivalent means the extensions/v1beta1 request
would be sent to the webhook (with the objects converted to a
version the webhook had speci�ed: apps/v1 )
Specifying Equivalent is recommended, and ensures that webhooks
continue to intercept the resources they expect when upgrades enable
new versions of the resource in the API server.
When a resource stops being served by the API server, it is no longer
considered equivalent to other versions of that resource that are still
served. For example, extensions/v1beta1 deployments were �rst
deprecated and then removed (in Kubernetes v1.16).
Since that removal, a webhook with a apiGroups:["extensions"],
apiVersions:["v1beta1"], resources:["deployments"] rule does not

intercept deployments created via apps/v1 APIs. For that reason,
webhooks should prefer registering for stable versions of resources.
This example shows a validating webhook that intercepts modi�cations
to deployments (no matter the API group or version), and is always sent
an apps/v1 Deployment object:

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
matchPolicy: Equivalent
rules:
- operations: ["CREATE","UPDATE","DELETE"]
apiGroups: ["apps"]
apiVersions: ["v1"]
resources: ["deployments"]
scope: "Namespaced"

The matchPolicy for an admission webhooks defaults to Equivalent .

Matching requests: matchConditions
ⓘ

Kubernetes v1.30 [stable](enabled by

default)
You can de�ne match conditions for webhooks if you need �ne-grained
request �ltering. These conditions are useful if you �nd that match rules,
objectSelectors and namespaceSelectors still doesn't provide the
�ltering you want over when to call out over HTTP. Match conditions are
CEL expressions. All match conditions must evaluate to true for the
webhook to be called.
Here is an example illustrating a few di�erent uses for match conditions:

2/27/26, 3:33 PM

API Access Control | Kubernetes

114 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
matchPolicy: Equivalent
rules:
- operations: ['CREATE','UPDATE']
apiGroups: ['*']
apiVersions: ['*']
resources: ['*']
failurePolicy: 'Ignore' # Fail-open (optional)
sideEffects: None
clientConfig:
service:
namespace: my-namespace
name: my-webhook
caBundle: '<omitted>'
# You can have up to 64 matchConditions per webhook
matchConditions:
- name: 'exclude-leases' # Each match condition must have a unique name
expression: '!(request.resource.group == "coordination.k8s.io" && reques
- name: 'exclude-kubelet-requests'
expression: '!("system:nodes" in request.userInfo.groups)'
- name: 'rbac' # Skip RBAC requests, which are handled by the second webho
expression: 'request.resource.group != "rbac.authorization.k8s.io"'
# This example illustrates the use of the 'authorizer'. The authorization chec
# than a simple expression, so in this example it is scoped to only RBAC reque
# webhook. Both webhooks can be served by the same endpoint.
- name: rbac.my-webhook.example.com
matchPolicy: Equivalent
rules:
- operations: ['CREATE','UPDATE']
apiGroups: ['rbac.authorization.k8s.io']
apiVersions: ['*']
resources: ['*']
failurePolicy: 'Fail' # Fail-closed (the default)
sideEffects: None
clientConfig:
service:
namespace: my-namespace
name: my-webhook
caBundle: '<omitted>'
# You can have up to 64 matchConditions per webhook
matchConditions:
- name: 'breakglass'
# Skip requests made by users authorized to 'breakglass' on this webhook
# The 'breakglass' API verb does not need to exist outside this check.
expression: '!authorizer.group("admissionregistration.k8s.io").resource(

You can de�ne up to 64 elements in the matchConditions �eld per
webhook.

Match conditions have access to the following CEL variables:
• object - The object from the incoming request. The value is null for
DELETE requests. The object version may be converted based on
the matchPolicy.
• oldObject - The existing object. The value is null for CREATE
requests.
• request - The request portion of the AdmissionReview, excluding
2/27/26, 3:33 PM

API Access Control | Kubernetes

115 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

object and oldObject .

• authorizer - A CEL Authorizer. May be used to perform
authorization checks for the principal (authenticated user) of the
request. See Authz in the Kubernetes CEL library documentation for
more details.
• authorizer.requestResource - A shortcut for an authorization
check con�gured with the request resource (group, resource,
(subresource), namespace, name).
For more information on CEL expressions, refer to the Common
Expression Language in Kubernetes reference.
In the event of an error evaluating a match condition the webhook is
never called. Whether to reject the request is determined as follows:
1. If

match condition evaluated to false (regardless of other

errors), the API server skips the webhook.
2. Otherwise:
◦ for failurePolicy: Fail, reject the request (without calling
the webhook).
◦ for failurePolicy: Ignore, proceed with the request but skip
the webhook.

Contacting the webhook
Once the API server has determined a request should be sent to a
webhook, it needs to know how to contact the webhook. This is speci�ed
in the clientConfig stanza of the webhook con�guration.
Webhooks can either be called via a URL or a service reference, and can
optionally include a custom CA bundle to use to verify the TLS
connection.

URL
url gives the location of the webhook, in standard URL form

( scheme://host:port/path ).
The host should not refer to a service running in the cluster; use a
service reference by specifying the service �eld instead. The host might
be resolved via external DNS in some API servers (e.g., kube-apiserver
cannot resolve in-cluster DNS as that would be a layering violation).
host may also be an IP address.
Please note that using localhost or 127.0.0.1 as a host is risky
unless you take great care to run this webhook on all hosts which run an
API server which might need to make calls to this webhook. Such
installations are likely to be non-portable or not readily run in a new
cluster.
The scheme must be "https"; the URL must begin with "https://".
Attempting to use a user or basic auth (for example user:password@ ) is
not allowed. Fragments ( #... ) and query parameters ( ?... ) are also
not allowed.
Here is an example of a mutating webhook con�gured to call a URL (and
expects the TLS certi�cate to be veri�ed using system trust roots, so does
not specify a caBundle):

2/27/26, 3:33 PM

API Access Control | Kubernetes

116 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
clientConfig:
url: "https://my-webhook.example.com:9443/my-webhook-path"

Service reference
The service stanza inside clientConfig is a reference to the service
for this webhook. If the webhook is running within the cluster, then you
should use service instead of url . The service namespace and name
are required. The port is optional and defaults to 443. The path is
optional and defaults to "/".
Here is an example of a mutating webhook con�gured to call a service on
port "1234" at the subpath "/my-path", and to verify the TLS connection
against the ServerName my-service-name.my-service-namespace.svc
using a custom CA bundle:

apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
clientConfig:
caBundle: <CA_BUNDLE>
service:
namespace: my-service-namespace
name: my-service-name
path: /my-path
port: 1234

You must replace the <CA_BUNDLE> in the above example by a valid
CA bundle which is a PEM-encoded CA bundle for validating the
webhook's server certi�cate.

Side e�ects
Webhooks typically operate only on the content of the AdmissionReview
sent to them. Some webhooks, however, make out-of-band changes as
part of processing admission requests.
Webhooks that make out-of-band changes ("side e�ects") must also have
a reconciliation mechanism (like a controller) that periodically determines
the actual state of the world, and adjusts the out-of-band data modi�ed
by the admission webhook to re�ect reality. This is because a call to an
admission webhook does not guarantee the admitted object will be
persisted as is, or at all. Later webhooks can modify the content of the
object, a con�ict could be encountered while writing to storage, or the
server could power o� before persisting the object.
Additionally, webhooks with side e�ects must skip those side-e�ects
when dryRun: true admission requests are handled. A webhook must
explicitly indicate that it will not have side-e�ects when run with dryRun ,
or the dry-run request will not be sent to the webhook and the API
request will fail instead.
Webhooks indicate whether they have side e�ects using the
2/27/26, 3:33 PM

API Access Control | Kubernetes

117 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

sideEffects �eld in the webhook con�guration:

• None : calling the webhook will have no side e�ects.
• NoneOnDryRun : calling the webhook will possibly have side e�ects,
but if a request with dryRun: true is sent to the webhook, the
webhook will suppress the side e�ects (the webhook is dryRun aware).
Here is an example of a validating webhook indicating it has no side
e�ects on dryRun: true requests:

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
sideEffects: NoneOnDryRun

Timeouts
Because webhooks add to API request latency, they should evaluate as
quickly as possible. timeoutSeconds allows con�guring how long the API
server should wait for a webhook to respond before treating the call as a
failure.
If the timeout expires before the webhook responds, the webhook call
will be ignored or the API call will be rejected based on the failure policy.
The timeout value must be between 1 and 30 seconds.
Here is an example of a validating webhook with a custom timeout of 2
seconds:

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
timeoutSeconds: 2

The timeout for an admission webhook defaults to 10 seconds.

Reinvocation policy
A single ordering of mutating admissions plugins (including webhooks)
does not work for all cases (see https://issue.k8s.io/64333 as an
example). A mutating webhook can add a new sub-structure to the object
(like adding a container to a pod ), and other mutating plugins which
have already run may have opinions on those new structures (like setting
an imagePullPolicy on all containers).
To allow mutating admission plugins to observe changes made by other
plugins, built-in mutating admission plugins are re-run if a mutating
webhook modi�es an object, and mutating webhooks can specify a
reinvocationPolicy to control whether they are reinvoked as well.
reinvocationPolicy may be set to Never or IfNeeded . It defaults to
Never .

• Never : the webhook must not be called more than once in a single
admission evaluation.
• IfNeeded : the webhook may be called again as part of the
2/27/26, 3:33 PM

API Access Control | Kubernetes

118 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

admission evaluation if the object being admitted is modi�ed by
other admission plugins after the initial webhook call.
The important elements to note are:
• The number of additional invocations is not guaranteed to be
exactly one.
• If additional invocations result in further modi�cations to the object,
webhooks are not guaranteed to be invoked again.
• Webhooks that use this option may be reordered to minimize the
number of additional invocations.
• To validate an object after all mutations are guaranteed complete,
use a validating admission webhook instead (recommended for
webhooks with side-e�ects).
Here is an example of a mutating webhook opting into being re-invoked if
later admission plugins modify the object:

apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
reinvocationPolicy: IfNeeded

Mutating webhooks must be idempotent, able to successfully process an
object they have already admitted and potentially modi�ed. This is true
for all mutating admission webhooks, since any change they can make in
an object could already exist in the user-provided object, but it is
essential for webhooks that opt into reinvocation.

Failure policy
failurePolicy de�nes how unrecognized errors and timeout errors

from the admission webhook are handled. Allowed values are Ignore or
Fail .

• Ignore means that an error calling the webhook is ignored and the
API request is allowed to continue.
• Fail means that an error calling the webhook causes the
admission to fail and the API request to be rejected.
Here is a mutating webhook con�gured to reject an API request if errors
are encountered calling the admission webhook:

apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
webhooks:
- name: my-webhook.example.com
failurePolicy: Fail

The default failurePolicy for an admission webhooks is Fail .

Monitoring admission webhooks
The API server provides ways to monitor admission webhook behaviors.
These monitoring mechanisms help cluster admins to answer questions
like:

2/27/26, 3:33 PM

API Access Control | Kubernetes

119 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

1. Which mutating webhook mutated the object in a API request?
2. What change did the mutating webhook applied to the object?
3. Which webhooks are frequently rejecting API requests? What's the
reason for a rejection?

Mutating webhook auditing annotations
Sometimes it's useful to know which mutating webhook mutated the
object in a API request, and what change did the webhook apply.
The Kubernetes API server performs auditing on each mutating webhook
invocation. Each invocation generates an auditing annotation capturing if
a request object is mutated by the invocation, and optionally generates
an annotation capturing the applied patch from the webhook admission
response. The annotations are set in the audit event for given request on
given stage of its execution, which is then pre-processed according to a
certain policy and written to a backend.
The audit level of a event determines which annotations get recorded:
• At Metadata audit level or higher, an annotation with key
mutation.webhook.admission.k8s.io/round_{round idx}
_index_{order idx} gets logged with JSON payload indicating a

webhook gets invoked for given request and whether it mutated the
object or not.
For example, the following annotation gets recorded for a webhook
being reinvoked. The webhook is ordered the third in the mutating
webhook chain, and didn't mutated the request object during the
invocation.

# the audit event recorded
{
"kind": "Event",
"apiVersion": "audit.k8s.io/v1",
"annotations": {
"mutation.webhook.admission.k8s.io/round_1_index_2": "{\"configurat
# other annotations
...
}
# other fields
...
}

# the annotation value deserialized
{
"configuration": "my-mutating-webhook-configuration.example.com"
"webhook": "my-webhook.example.com",
"mutated": false
}

The following annotation gets recorded for a webhook being
invoked in the �rst round. The webhook is ordered the �rst in the
mutating webhook chain, and mutated the request object during
the invocation.

2/27/26, 3:33 PM

API Access Control | Kubernetes

120 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

# the audit event recorded
{
"kind": "Event",
"apiVersion": "audit.k8s.io/v1",
"annotations": {
"mutation.webhook.admission.k8s.io/round_0_index_0": "{\"configurat
# other annotations
...
}
# other fields
...
}

# the annotation value deserialized
{
"configuration": "my-mutating-webhook-configuration.example.com"
"webhook": "my-webhook-always-mutate.example.com",
"mutated": true
}

• At Request audit level or higher, an annotation with key
patch.webhook.admission.k8s.io/round_{round idx}
_index_{order idx} gets logged with JSON payload indicating a

webhook gets invoked for given request and what patch gets
applied to the request object.
For example, the following annotation gets recorded for a webhook
being reinvoked. The webhook is ordered the fourth in the mutating
webhook chain, and responded with a JSON patch which got applied
to the request object.

# the audit event recorded
{
"kind": "Event",
"apiVersion": "audit.k8s.io/v1",
"annotations": {
"patch.webhook.admission.k8s.io/round_1_index_3":
# other annotations
...
}
# other fields
...
}

# the annotation value deserialized
{
"configuration": "my-other-mutating-webhook-configuration.example.com"
"webhook": "my-webhook-always-mutate.example.com",
"patchType": "JSONPatch",
"patch": [
{
"op": "add",
"path": "/data/mutation-stage",
"value": "yes"
}
]
}

2/27/26, 3:33 PM

API Access Control | Kubernetes

121 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Admission webhook metrics
The API server exposes Prometheus metrics from the /metrics
endpoint, which can be used for monitoring and diagnosing API server
status. The following metrics record status related to admission
webhooks.

API server admission webhook rejection count
Sometimes it's useful to know which admission webhooks are frequently
rejecting API requests, and the reason for a rejection.
The API server exposes a Prometheus counter metric recording
admission webhook rejections. The metrics are labelled to identify the
causes of webhook rejection(s):
• name : the name of the webhook that rejected a request.
• operation : the operation type of the request, can be one of
CREATE , UPDATE , DELETE and CONNECT .

• type : the admission webhook type, can be one of admit and
validating .

• error_type : identi�es if an error occurred during the webhook
invocation that caused the rejection. Its value can be one of:
◦ calling_webhook_error : unrecognized errors or timeout
errors from the admission webhook happened and the
webhook's Failure policy is set to Fail .
◦ no_error : no error occurred. The webhook rejected the
request with allowed: false in the admission response. The
metrics label rejection_code records the .status.code set
in the admission response.
◦ apiserver_internal_error : an API server internal error
happened.
• rejection_code : the HTTP status code set in the admission
response when a webhook rejected a request.
Example of the rejection count metrics:
# HELP apiserver_admission_webhook_rejection_count [ALPHA] Admission webhook rej
# TYPE apiserver_admission_webhook_rejection_count counter
apiserver_admission_webhook_rejection_count{error_type="calling_webhook_error",n
apiserver_admission_webhook_rejection_count{error_type="calling_webhook_error",n
apiserver_admission_webhook_rejection_count{error_type="no_error",name="deny-unw

Best practices and warnings
For recommendations and considerations when writing mutating
admission webhooks, see Admission Webhooks Good Practices.

2/27/26, 3:33 PM

API Access Control | Kubernetes

122 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

A ServiceAccount provides an identity for processes that run in a Pod.
A process inside a Pod can use the identity of its associated service
account to authenticate to the cluster's API server.
For an introduction to service accounts, read con�gure service accounts.
This task guide explains some of the concepts behind ServiceAccounts.
The guide also explains how to obtain or revoke tokens that represent
ServiceAccounts, and how to (optionally) bind a ServiceAccount's validity
to the lifetime of an API object.

Before you begin
You need to have a Kubernetes cluster, and the kubectl command-line
tool must be con�gured to communicate with your cluster. It is
recommended to run this tutorial on a cluster with at least two nodes
that are not acting as control plane hosts. If you do not already have a
cluster, you can create one by using minikube or you can use one of
these Kubernetes playgrounds:
• iximiuz Labs
• Killercoda
• KodeKloud
• Play with Kubernetes
To be able to follow these steps exactly, ensure you have a namespace
named examplens . If you don't, create one by running:

kubectl create namespace examplens

User accounts versus service
accounts
Kubernetes distinguishes between the concept of a user account and a
service account for a number of reasons:
• User accounts are for humans. Service accounts are for application
processes, which (for Kubernetes) run in containers that are part of
pods.
• User accounts are intended to be global: names must be unique
across all namespaces of a cluster. No matter what namespace you
look at, a particular username that represents a user represents the
same user. In Kubernetes, service accounts are namespaced: two
di�erent namespaces can contain ServiceAccounts that have
identical names.
• Typically, a cluster's user accounts might be synchronised from a
corporate database, where new user account creation requires
special privileges and is tied to complex business processes. By
contrast, service account creation is intended to be more
lightweight, allowing cluster users to create service accounts for
speci�c tasks on demand. Separating ServiceAccount creation from
the steps to onboard human users makes it easier for workloads to
follow the principle of least privilege.
2/27/26, 3:33 PM

API Access Control | Kubernetes

123 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• Auditing considerations for humans and service accounts may
di�er; the separation makes that easier to achieve.
• A con�guration bundle for a complex system may include de�nition
of various service accounts for components of that system. Because
service accounts can be created without many constraints and have
namespaced names, such con�guration is usually portable.

Bound service account tokens
ServiceAccount tokens can be bound to API objects that exist in the kubeapiserver. This can be used to tie the validity of a token to the existence
of another API object. Supported object types are as follows:
• Pod (used for projected volume mounts, see below)
• Secret (can be used to allow revoking a token by deleting the Secret)
• Node (can be used to auto-revoke a token when its Node is deleted;
creating new node-bound tokens is GA in v1.33+)
When a token is bound to an object, the object's metadata.name and
metadata.uid are stored as extra 'private claims' in the issued JWT.

When a bound token is presented to the kube-apiserver, the service
account authenticator will extract and verify these claims. If the
referenced object or the ServiceAccount is pending deletion (for example,
due to �nalizers), then for any instant that is 60 seconds (or more) after
the .metadata.deletionTimestamp date, authentication with that token
would fail. If the referenced object no longer exists (or its metadata.uid
does not match), the request will not be authenticated.

Additional metadata in Pod bound tokens
Kubernetes v1.32 [stable](enabled by

ⓘ

default)
When a service account token is bound to a Pod object, additional
metadata is also embedded into the token that indicates the value of the
bound pod's spec.nodeName �eld, and the uid of that Node, if available.
veri�ed by the kube-apiserver when the
This node information is
token is used for authentication. It is included so integrators do not have
to fetch Pod or Node API objects to check the associated Node name and
uid when inspecting a JWT.

Verifying and inspecting private claims
The TokenReview API can be used to verify and extract private claims
from a token:
1. First, assume you have a pod named test-pod and a service
account named my-sa .
2. Create a token that is bound to this Pod:

kubectl create token my-sa --bound-object-kind="Pod" --bound-object-name

3. Copy this token into a new �le named tokenreview.yaml :

2/27/26, 3:33 PM

API Access Control | Kubernetes

124 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
token: <token from step 2>

4. Submit this resource to the apiserver for review:

# use '-o yaml' to inspect the output
kubectl create -o yaml -f tokenreview.yaml

You should see an output like below:

apiVersion: authentication.k8s.io/v1
kind: TokenReview
metadata:
creationTimestamp: null
spec:
token: <token>
status:
audiences:
- https://kubernetes.default.svc.cluster.local
authenticated: true
user:
extra:
authentication.kubernetes.io/credential-id:
- JTI=7ee52be0-9045-4653-aa5e-0da57b8dccdc
authentication.kubernetes.io/node-name:
- kind-control-plane
authentication.kubernetes.io/node-uid:
- 497e9d9a-47aa-4930-b0f6-9f2fb574c8c6
authentication.kubernetes.io/pod-name:
- test-pod
authentication.kubernetes.io/pod-uid:
- e87dbbd6-3d7e-45db-aafb-72b24627dff5
groups:
- system:serviceaccounts
- system:serviceaccounts:default
- system:authenticated
uid: f8b4161b-2e2b-11e9-86b7-2afc33b31a7e
username: system:serviceaccount:default:my-sa

Despite using kubectl create -f to create this resource, and
de�ning it similar to other resource types in Kubernetes,
TokenReview is a special type and the kube-apiserver does
not actually persist the TokenReview object into etcd. Hence
kubectl get tokenreview is not a valid command.

Schema for service account private claims
The schema for the Kubernetes-speci�c claims within JWT tokens is not
currently documented, however the relevant code area can be found in
the serviceaccount package in the Kubernetes codebase.
You can inspect a JWT using standard JWT decoding tool. Below is an
example of a JWT for the my-serviceaccount ServiceAccount, bound to a
Pod object named my-pod which is scheduled to the Node my-node , in

2/27/26, 3:33 PM

API Access Control | Kubernetes

125 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

the my-namespace namespace:

{
"aud": [
"https://my-audience.example.com"
],
"exp": 1729605240,
"iat": 1729601640,
"iss": "https://my-cluster.example.com",
"jti": "aed34954-b33a-4142-b1ec-389d6bbb4936",
"kubernetes.io": {
"namespace": "my-namespace",
"node": {
"name": "my-node",
"uid": "646e7c5e-32d6-4d42-9dbd-e504e6cbe6b1"
},
"pod": {
"name": "my-pod",
"uid": "5e0bd49b-f040-43b0-99b7-22765a53f7f3"
},
"serviceaccount": {
"name": "my-serviceaccount",
"uid": "14ee3fa4-a7e2-420f-9f9a-dbc4507c3798"
}
},
"nbf": 1729601640,
"sub": "system:serviceaccount:my-namespace:my-serviceaccount"
}

The aud and iss �elds in this JWT may di�er between di�erent
Kubernetes clusters depending on your con�guration.
The presence of both the pod and node claim implies that this
token is bound to a Pod object. When verifying Pod bound
verify the existence
ServiceAccount tokens, the API server
of the referenced Node object.

Services that run outside of Kubernetes and want to perform o�ine
validation of JWTs may use this schema, along with a compliant JWT
validator con�gured with OpenID Discovery information from the API
server, to verify presented JWTs without requiring use of the
TokenReview API.
the claims embedded
Services that verify JWTs in this way
in the JWT token to be current and still valid. This means if the token is
bound to an object, and that object no longer exists, the token will still be
considered valid (until the con�gured token expires).
Clients that require assurance that a token's bound claims are still valid
use the TokenReview API to present the token to the kubeapiserver for it to verify and expand the embedded claims, using similar

steps to the Verifying and inspecting private claims section above, but
with a supported client library. For more information on JWTs and their
structure, see the JSON Web Token RFC.

Bound service account token
volume mechanism
2/27/26, 3:33 PM

API Access Control | Kubernetes

126 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Kubernetes v1.22 [stable](enabled by

ⓘ

default)
By default, the Kubernetes control plane (speci�cally, the ServiceAccount
admission controller) adds a projected volume to Pods, and this volume
includes a token for Kubernetes API access.
Here's an example of how that looks for a launched Pod:

...
- name: kube-api-access-<random-suffix>
projected:
sources:
- serviceAccountToken:
path: token # must match the path the app expects
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

That manifest snippet de�nes a projected volume that consists of three
sources. In this case, each source also represents a single path within
that volume. The three sources are:
1. A serviceAccountToken source, that contains a token that the
kubelet acquires from kube-apiserver. The kubelet fetches timebound tokens using the TokenRequest API. A token served for a
TokenRequest expires either when the pod is deleted or after a
de�ned lifespan (by default, that is 1 hour). The kubelet also
refreshes that token before the token expires. The token is bound
to the speci�c Pod and has the kube-apiserver as its audience. This
mechanism superseded an earlier mechanism that added a volume
based on a Secret, where the Secret represented the
ServiceAccount for the Pod, but did not expire.
2. A configMap source. The Con�gMap contains a bundle of certi�cate
authority data. Pods can use these certi�cates to make sure that
they are connecting to your cluster's kube-apiserver (and not to
middlebox or an accidentally miscon�gured peer).
3. A downwardAPI source that looks up the name of the namespace
containing the Pod, and makes that name information available to
application code running inside the Pod.
Any container within the Pod that mounts this particular volume can
access the above information.

There is no speci�c mechanism to invalidate a token issued via
TokenRequest. If you no longer trust a bound service account token
for a Pod, you can delete that Pod. Deleting a Pod expires its bound
service account tokens.

2/27/26, 3:33 PM

API Access Control | Kubernetes

127 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Manual Secret management for
ServiceAccounts
Versions of Kubernetes before v1.22 automatically created credentials for
accessing the Kubernetes API. This older mechanism was based on
creating token Secrets that could then be mounted into running Pods.
In more recent versions, including Kubernetes v1.35, API credentials are
obtained directly using the TokenRequest API, and are mounted into
Pods using a projected volume. The tokens obtained using this method
have bounded lifetimes, and are automatically invalidated when the Pod
they are mounted into is deleted.
You can still manually create a Secret to hold a service account token; for
example, if you need a token that never expires.
Once you manually create a Secret and link it to a ServiceAccount, the
Kubernetes control plane automatically populates the token into that
Secret.

Although the manual mechanism for creating a long-lived
ServiceAccount token exists, using TokenRequest to obtain shortlived API access tokens is recommended instead.

Auto-generated legacy
ServiceAccount token clean up
Before version 1.24, Kubernetes automatically generated Secret-based
tokens for ServiceAccounts. To distinguish between automatically
generated tokens and manually created ones, Kubernetes checks for a
reference from the ServiceAccount's secrets �eld. If the Secret is
referenced in the secrets �eld, it is considered an auto-generated
legacy token. Otherwise, it is considered a manually created legacy token.
For example:

apiVersion: v1
kind: ServiceAccount
metadata:
name: build-robot
namespace: default
secrets:
- name: build-robot-secret # usually NOT present for a manually generated toke

Beginning from version 1.29, legacy ServiceAccount tokens that were
generated automatically will be marked as invalid if they remain unused
for a certain period of time (set to default at one year). Tokens that
continue to be unused for this de�ned period (again, by default, one
year) will subsequently be purged by the control plane.
If users use an invalidated auto-generated token, the token validator will
1. add an audit annotation for the key-value pair
authentication.k8s.io/legacy-token-invalidated: <secret
name>/<namespace> ,

2. increment the invalid_legacy_auto_token_uses_total metric
count,

2/27/26, 3:33 PM

API Access Control | Kubernetes

128 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

3. update the Secret label kubernetes.io/legacy-token-last-used
with the new date,
4. return an error indicating that the token has been invalidated.
When receiving this validation error, users can update the Secret to
remove the kubernetes.io/legacy-token-invalid-since label to
temporarily allow use of this token.
Here's an example of an auto-generated legacy token that has been
marked with the kubernetes.io/legacy-token-last-used and
kubernetes.io/legacy-token-invalid-since labels:

apiVersion: v1
kind: Secret
metadata:
name: build-robot-secret
namespace: default
labels:
kubernetes.io/legacy-token-last-used: 2022-10-24
kubernetes.io/legacy-token-invalid-since: 2023-10-25
annotations:
kubernetes.io/service-account.name: build-robot
type: kubernetes.io/service-account-token

Control plane details
ServiceAccount controller
A ServiceAccount controller manages the ServiceAccounts inside
namespaces, and ensures a ServiceAccount named "default" exists in
every active namespace.

Token controller
The service account token controller runs as part of kube-controllermanager . This controller acts asynchronously. It:

• watches for ServiceAccount deletion and deletes all corresponding
ServiceAccount token Secrets.
• watches for ServiceAccount token Secret addition, and ensures the
referenced ServiceAccount exists, and adds a token to the Secret if
needed.
• watches for Secret deletion and removes a reference from the
corresponding ServiceAccount if needed.
You must pass a service account private key �le to the token controller in
the kube-controller-manager using the --service-account-privatekey-file �ag. The private key is used to sign generated service account

tokens. Similarly, you must pass the corresponding public key to the
kube-apiserver using the --service-account-key-file �ag. The public
key will be used to verify the tokens during authentication.

ⓘ

Kubernetes v1.34 [beta](enabled by

default)
An alternate setup to setting --service-account-private-key-file and
--service-account-key-file �ags is to con�gure an external JWT signer

for external ServiceAccount token signing and key management. Note

2/27/26, 3:33 PM

API Access Control | Kubernetes

129 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

that these setups are mutually exclusive and cannot be con�gured
together.

ServiceAccount admission controller
The modi�cation of pods is implemented via a plugin called an Admission
Controller. It is part of the API server. This admission controller acts
synchronously to modify pods as they are created. When this plugin is
active (and it is by default on most distributions), then it does the
following when a Pod is created:
1. If the pod does not have a .spec.serviceAccountName set, the
admission controller sets the name of the ServiceAccount for this
incoming Pod to default .
2. The admission controller ensures that the ServiceAccount
referenced by the incoming Pod exists. If there is no ServiceAccount
with a matching name, the admission controller rejects the
incoming Pod. That check applies even for the default
ServiceAccount.
3. Provided that neither the ServiceAccount's
automountServiceAccountToken �eld nor the Pod's
automountServiceAccountToken �eld is set to false :

◦ the admission controller mutates the incoming Pod, adding an
extra volume that contains a token for API access.
◦ the admission controller adds a volumeMount to each
container in the Pod, skipping any containers that already
have a volume mount de�ned for the path /var/run/
secrets/kubernetes.io/serviceaccount . For Linux containers,

that volume is mounted at /var/run/secrets/kubernetes.io/
serviceaccount ; on Windows nodes, the mount is at the

equivalent path.
4. If the spec of the incoming Pod doesn't already contain any
imagePullSecrets , then the admission controller adds
imagePullSecrets , copying them from the ServiceAccount .

Legacy ServiceAccount token tracking controller
ⓘ

Kubernetes v1.28 [stable](enabled by

default)
This controller generates a Con�gMap called kube-system/kubeapiserver-legacy-service-account-token-tracking in the kube-system

namespace. The Con�gMap records the timestamp when legacy service
account tokens began to be monitored by the system.

Legacy ServiceAccount token cleaner
ⓘ

Kubernetes v1.30 [stable](enabled by

default)
The legacy ServiceAccount token cleaner runs as part of the kubecontroller-manager and checks every 24 hours to see if any auto-

generated legacy ServiceAccount token has not been used in a speci�ed
amount of time. If so, the cleaner marks those tokens as invalid.
The cleaner works by �rst checking the Con�gMap created by the control
plane (provided that LegacyServiceAccountTokenTracking is enabled). If

2/27/26, 3:33 PM

API Access Control | Kubernetes

130 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

the current time is a speci�ed amount of time after the date in the
Con�gMap, the cleaner then loops through the list of Secrets in the
cluster and evaluates each Secret that has the type kubernetes.io/
service-account-token .

If a Secret meets all of the following conditions, the cleaner marks it as
invalid:
• The Secret is auto-generated, meaning that it is bi-directionally
referenced by a ServiceAccount.
• The Secret is not currently mounted by any pods.
• The Secret has not been used in a speci�ed amount of time since it
was created or since it was last used.
The cleaner marks a Secret invalid by adding a label called
kubernetes.io/legacy-token-invalid-since to the Secret, with the
current date as the value. If an invalid Secret is not used in a speci�ed
amount of time, the cleaner will delete it.

All the speci�ed amount of time above defaults to one year. The
cluster administrator can con�gure this value through the -legacy-service-account-token-clean-up-period command line

argument for the kube-controller-manager component.

TokenRequest API
ⓘ

Kubernetes v1.22 [stable]

You use the TokenRequest subresource of a ServiceAccount to obtain a
time-bound token for that ServiceAccount. You don't need to call this to
obtain an API token for use within a container, since the kubelet sets this
up for you using a projected volume.
If you want to use the TokenRequest API from kubectl , see Manually
create an API token for a ServiceAccount.
The Kubernetes control plane (speci�cally, the ServiceAccount admission
controller) adds a projected volume to Pods, and the kubelet ensures
that this volume contains a token that lets containers authenticate as the
right ServiceAccount.
(This mechanism superseded an earlier mechanism that added a volume
based on a Secret, where the Secret represented the ServiceAccount for
the Pod but did not expire.)
Here's an example of how that looks for a launched Pod:

2/27/26, 3:33 PM

API Access Control | Kubernetes

131 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

...
- name: kube-api-access-<random-suffix>
projected:
defaultMode: 420 # decimal equivalent of octal 0644
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

That manifest snippet de�nes a projected volume that combines
information from three sources:
1. A serviceAccountToken source, that contains a token that the
kubelet acquires from kube-apiserver. The kubelet fetches timebound tokens using the TokenRequest API. A token served for a
TokenRequest expires either when the pod is deleted or after a
de�ned lifespan (by default, that is 1 hour). The token is bound to
the speci�c Pod and has the kube-apiserver as its audience.
2. A configMap source. The Con�gMap contains a bundle of certi�cate
authority data. Pods can use these certi�cates to make sure that
they are connecting to your cluster's kube-apiserver (and not to a
middlebox or an accidentally miscon�gured peer).
3. A downwardAPI source. This downwardAPI volume makes the name
of the namespace containing the Pod available to application code
running inside the Pod.
Any container within the Pod that mounts this volume can access the
above information.

Create additional API tokens
Only create long-lived API tokens if the token request mechanism is
not suitable. The token request mechanism provides time-limited
tokens; because these expire, they represent a lower risk to
information security.

To create a non-expiring, persisted API token for a ServiceAccount, create
a Secret of type kubernetes.io/service-account-token with an
annotation referencing the ServiceAccount. The control plane then
generates a long-lived token and updates that Secret with that generated
token data.
Here is a sample manifest for such a Secret:

secret/serviceaccount/mysecretname.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

132 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
name: mysecretname
annotations:
kubernetes.io/service-account.name: myserviceaccount

To create a Secret based on this example, run:

kubectl -n examplens create -f https://k8s.io/examples/secret/serviceaccount/mys

To see the details for that Secret, run:

kubectl -n examplens describe secret mysecretname

The output is similar to:
Name:
Namespace:
Labels:
Annotations:

Type:

mysecretname
examplens
<none>
kubernetes.io/service-account.name=myserviceaccount
kubernetes.io/service-account.uid=8a85c4c4-8483-11e9-bc42-526af7

kubernetes.io/service-account-token

Data
====
ca.crt:
namespace:
token:

1362 bytes
9 bytes
...

If you launch a new Pod into the examplens namespace, it can use the
myserviceaccount service-account-token Secret that you just created.

Do not reference manually created Secrets in the secrets �eld of a
ServiceAccount. Or the manually created Secrets will be cleaned if it
is not used for a long time. Please refer to auto-generated legacy
ServiceAccount token clean up.

Delete/invalidate a ServiceAccount
token
Delete/invalidate a long-lived/legacy ServiceAccount token
If you know the name of the Secret that contains the token you want to
remove:

kubectl delete secret name-of-secret

Otherwise, �rst �nd the Secret for the ServiceAccount.

2/27/26, 3:33 PM

API Access Control | Kubernetes

133 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

# This assumes that you already have a namespace named 'examplens'
kubectl -n examplens get serviceaccount/example-automated-thing -o yaml

The output is similar to:

apiVersion: v1
kind: ServiceAccount
metadata:
annotations:
kubectl.kubernetes.io/last-applied-configuration: |
{"apiVersion":"v1","kind":"ServiceAccount","metadata":{"annotations":{},"n
creationTimestamp: "2019-07-21T07:07:07Z"
name: example-automated-thing
namespace: examplens
resourceVersion: "777"
selfLink: /api/v1/namespaces/examplens/serviceaccounts/example-automated-thing
uid: f23fd170-66f2-4697-b049-e1e266b7f835
secrets:
- name: example-automated-thing-token-zyxwv

Then, delete the Secret you now know the name of:

kubectl -n examplens delete secret/example-automated-thing-token-zyxwv

Delete/invalidate a short-lived ServiceAccount token
Short lived ServiceAccount tokens automatically expire after the timelimit speci�ed during their creation. There is no central record of tokens
issued, so there is no way to revoke individual tokens.
If you have to revoke a short-lived token before its expiration, you can
delete and re-create the ServiceAccount it is associated to. This will
change its UID and hence invalidate
ServiceAccount tokens that were
created for it.

External ServiceAccount token
signing and key management
ⓘ

Kubernetes v1.34 [beta](enabled by

default)
The kube-apiserver can be con�gured to use external signer for token
signing and token verifying key management. This feature enables
kubernetes distributions to integrate with key management solutions of
their choice (for example, HSMs, cloud KMSes) for service account
credential signing and veri�cation. To con�gure kube-apiserver to use
external-jwt-signer set the --service-account-signing-endpoint �ag to
the location of a Unix domain socket (UDS) on a �lesystem, or be pre�xed
with an @ symbol and name a UDS in the abstract socket namespace. At
the con�gured UDS shall be an RPC server which implements an
ExternalJWTSigner gRPC service.
The external-jwt-signer must be healthy and be ready to serve supported
service account keys for the kube-apiserver to start.

2/27/26, 3:33 PM

API Access Control | Kubernetes

134 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

The kube-apiserver �ags --service-account-key-file and -service-account-signing-key-file will continue to be used for

reading from �les unless --service-account-signing-endpoint is
set; they are mutually exclusive ways of supporting JWT signing and
authentication.

An external signer provides a v1.ExternalJWTSigner gRPC service that
implements 3 methods:

Metadata
Metadata is meant to be called once by kube-apiserver on startup. This
enables the external signer to share metadata with kube-apiserver, like
the max token lifetime that signer supports.

rpc Metadata(MetadataRequest) returns (MetadataResponse) {}
message MetadataRequest {}
message MetadataResponse {
// used by kube-apiserver for defaulting/validation of JWT lifetime while acco
// 1. `--service-account-max-token-expiration`
// 2. `--service-account-extend-token-expiration`
//
// * If `--service-account-max-token-expiration` is greater than `max_token_ex
// * If `--service-account-max-token-expiration` is not explicitly set, kube-a
// * If `--service-account-extend-token-expiration` is true, the extended expi
//
// `max_token_expiration_seconds` must be at least 600s.
int64 max_token_expiration_seconds = 1;
}

FetchKeys
FetchKeys returns the set of public keys that are trusted to sign
Kubernetes service account tokens. Kube-apiserver will call this RPC:
• Every time it tries to validate a JWT from the service account issuer
with an unknown key ID, and
• Periodically, so it can serve reasonably-up-to-date keys from the
OIDC JWKs endpoint.

2/27/26, 3:33 PM

API Access Control | Kubernetes

135 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

rpc FetchKeys(FetchKeysRequest) returns (FetchKeysResponse) {}
message FetchKeysRequest {}
message FetchKeysResponse {
repeated Key keys = 1;
// The timestamp when this data was pulled from the authoritative source of
// truth for verification keys.
// kube-apiserver can export this from metrics, to enable end-to-end SLOs.
google.protobuf.Timestamp data_timestamp = 2;
// refresh interval for verification keys to pick changes if any.
// any value <= 0 is considered a misconfiguration.
int64 refresh_hint_seconds = 3;
}
message Key {
// A unique identifier for this key.
// Length must be <=1024.
string key_id = 1;
// The public key, PKIX-serialized.
// must be a public key supported by kube-apiserver (currently RSA 256 or ECDS
bytes key = 2;
// Set only for keys that are not used to sign bound tokens.
// eg: supported keys for legacy tokens.
// If set, key is used for verification but excluded from OIDC discovery docs.
// if set, external signer should not use this key to sign a JWT.
bool exclude_from_oidc_discovery = 3;
}

Sign
Sign takes a serialized JWT payload, and returns the serialized header and
signature. kube-apiserver then assembles the JWT from the header,
payload, and signature.

rpc Sign(SignJWTRequest) returns (SignJWTResponse) {}
message SignJWTRequest {
// URL-safe base64 wrapped payload to be signed.
// Exactly as it appears in the second segment of the JWT
string claims = 1;
}
message SignJWTResponse {
// header must contain only alg, kid, typ claims.
// typ must be “JWT”.
// kid must be non-empty, <=1024 characters, and its corresponding public key
// alg must be one of the algorithms supported by kube-apiserver (currently RS
// header cannot have any additional data that kube-apiserver does not recogni
// Already wrapped in URL-safe base64, exactly as it appears in the first segm
string header = 1;
// The signature for the JWT.
// Already wrapped in URL-safe base64, exactly as it appears in the final segm
string signature = 2;
}

Clean up
2/27/26, 3:33 PM

API Access Control | Kubernetes

136 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

If you created a namespace examplens to experiment with, you can
remove it:

kubectl delete namespace examplens

What's next
• Read more details about projected volumes.

2/27/26, 3:33 PM

API Access Control | Kubernetes

137 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

User impersonation is a method of allowing authenticated users to act as
another user, group, or service account through HTTP headers.
A user can act as another user through impersonation headers. These let
requests manually override the user info a request authenticates as. For
example, an admin could use this feature to debug an authorization
policy by temporarily impersonating another user and seeing if a request
was denied.
Impersonation requests �rst authenticate as the requesting user, then
switch to the impersonated user info.
• A user makes an API call with their credentials and impersonation
headers.
• API server authenticates the user.
• API server ensures the authenticated users have impersonation
privileges.
• Request user info is replaced with impersonation values.
• Request is evaluated, authorization acts on impersonated user info.
The following HTTP headers can be used to performing an impersonation
request:
• Impersonate-User : The username to act as.
• Impersonate-Uid : A unique identi�er that represents the user
being impersonated. Optional. Requires "Impersonate-User".
Kubernetes does not impose any format requirements on this
string.
• Impersonate-Group : A group name to act as. Can be provided
multiple times to set multiple groups. Optional. Requires
"Impersonate-User".
• Impersonate-Extra-( extra name ) : A dynamic header used to
associate extra �elds with the user. Optional. Requires
"Impersonate-User". In order to be preserved consistently, ( extra
name ) must be lower-case, and any characters which aren't legal in

HTTP header labels MUST be utf8 and percent-encoded.

Prior to 1.11.3 (and 1.10.7, 1.9.11), ( extra name ) could only
contain characters which were legal in HTTP header labels.

Impersonate-Uid is only available in versions 1.22.0 and higher.

An example of the impersonation headers used when impersonating a
user with groups:

Impersonate-User: jane.doe@example.com
Impersonate-Group: developers
Impersonate-Group: admins

An example of the impersonation headers used when impersonating a
user with a UID and extra �elds:

2/27/26, 3:33 PM

API Access Control | Kubernetes

138 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Impersonate-User: jane.doe@example.com
Impersonate-Uid: 06f6ce97-e2c5-4ab8-7ba5-7654dd08d52b
Impersonate-Extra-dn: cn=jane,ou=engineers,dc=example,dc=com
Impersonate-Extra-acme.com%2Fproject: some-project
Impersonate-Extra-scopes: view
Impersonate-Extra-scopes: development

When using kubectl set the --as command line argument to con�gure
the Impersonate-User header, you can also set the --as-group �ag to
con�gure the Impersonate-Group header， set the --as-uid �ag (1.23)
to con�gure Impersonate-Uid header, and set the --as-user-extra �ag
(1.35) to con�gure Impersonate-Extra-( extra name ) header.

kubectl drain mynode

Error from server (Forbidden): User "clark" cannot get nodes at the cluster scop

Set the --as and --as-group �ag:

kubectl drain mynode --as=superman --as-group=system:masters

node/mynode cordoned
node/mynode drained

To impersonate a user, user identi�er (UID), group or extra �elds, the
impersonating user must have the ability to perform the
verb on the kind of attribute being impersonated ("user", "uid", "group",
etc.). For clusters that enable the RBAC authorization plugin, the following
ClusterRole encompasses the rules needed to set user and group
impersonation headers:

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: impersonator
rules:
- apiGroups: [""]
resources: ["users", "groups", "serviceaccounts"]
verbs: ["impersonate"]

For impersonation, extra �elds and impersonated UIDs are both under
the "authentication.k8s.io" apiGroup . Extra �elds are evaluated as subresources of the resource "userextras". To allow a user to use
impersonation headers for the extra �eld scopes and for UIDs, a user
should be granted the following role:

2/27/26, 3:33 PM

API Access Control | Kubernetes

139 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: scopes-and-uid-impersonator
rules:
# Can set "Impersonate-Extra-scopes" header and the "Impersonate-Uid" header.
- apiGroups: ["authentication.k8s.io"]
resources: ["userextras/scopes", "uids"]
verbs: ["impersonate"]

The values of impersonation headers can also be restricted by limiting
the set of resourceNames a resource can take.

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: limited-impersonator
rules:
# Can impersonate the user "jane.doe@example.com"
- apiGroups: [""]
resources: ["users"]
verbs: ["impersonate"]
resourceNames: ["jane.doe@example.com"]
# Can impersonate the groups "developers" and "admins"
- apiGroups: [""]
resources: ["groups"]
verbs: ["impersonate"]
resourceNames: ["developers","admins"]
# Can impersonate the extras field "scopes" with the values "view" and "developm
- apiGroups: ["authentication.k8s.io"]
resources: ["userextras/scopes"]
verbs: ["impersonate"]
resourceNames: ["view", "development"]
# Can impersonate the uid "06f6ce97-e2c5-4ab8-7ba5-7654dd08d52b"
- apiGroups: ["authentication.k8s.io"]
resources: ["uids"]
verbs: ["impersonate"]
resourceNames: ["06f6ce97-e2c5-4ab8-7ba5-7654dd08d52b"]

Impersonating a user or group allows you to perform any action as
if you were that user or group; for that reason, impersonation is
not namespace scoped. If you want to allow impersonation using
Kubernetes RBAC, this requires using a ClusterRole and a
ClusterRoleBinding, not a Role and RoleBinding.
Granting impersonation over ServiceAccounts is namespace
scoped, but the impersonated ServiceAccount could perform
actions outside of namespace.

Constrained Impersonation

2/27/26, 3:33 PM

API Access Control | Kubernetes

140 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Kubernetes v1.35 [alpha](disabled by

ⓘ

default)
With the
verb, impersonation cannot be limited or scoped.
It either grants full impersonation or none at all. Once granted
permission to impersonate a user, you can perform any action that user
can perform across all resources and namespaces.
With constrained impersonation, an impersonator can be limited to
impersonate another user only for speci�c actions on speci�c resources,
rather than being able to perform all actions that the impersonated user
can perform.
This feature is enabled by setting the ConstrainedImpersonation feature
gate.

Understanding constrained impersonation
Constrained impersonation requires
1.

:
(user, UID, group,

service account or node)
2.
(for example, only list and watch pods in
the default namespace)
This means an impersonator can be limited to impersonate another user
only for speci�c operations.

Impersonation modes
Constrained impersonation de�nes three distinct modes, each with its
own set of verbs:

user-info mode
Use this mode to impersonate generic users (not service accounts or
nodes). This mode applies when the Impersonate-User header value:
• Does

start with system:serviceaccount:

• Does

start with system:node:

• impersonate:user-info - Permission to impersonate a speci�c
user, group, UID, or extra �eld
• impersonate-on:user-info:<verb> - Permission to perform
<verb> when impersonating a generic user

ServiceAccount mode
Use this mode to impersonate ServiceAccounts.

• impersonate:serviceaccount - Permission to impersonate a
speci�c service account
• impersonate-on:serviceaccount:<verb> - Permission to perform
<verb> when impersonating a service account

arbitrary-node and associated-node modes
2/27/26, 3:33 PM

API Access Control | Kubernetes

141 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Use these modes to impersonate nodes. This mode applies when the
Impersonate-User header value starts with system:node: .

• impersonate:arbitrary-node - Permission to impersonate any
speci�ed node
• impersonate:associated-node - Permission to impersonate only
the node to which the impersonator is bound
• impersonate-on:arbitrary-node:<verb> - Permission to perform
<verb> when impersonating any node

• impersonate-on:associated-node:<verb> - Permission to perform
<verb> when impersonating the associated node

The impersonate:associated-node verb only applies when the
impersonator is a service account bound to the node it's trying to
impersonate. This is determined by checking if the service
account's user info contains an extra �eld with key
authentication.kubernetes.io/node-name that matches the node
being impersonated.

Con�guring constrained impersonation with RBAC
All constrained impersonation permissions use the
authentication.k8s.io API group. Here's how to con�gure the di�erent
modes.

Example: Impersonate a user for speci�c actions
This example shows how to allow a service account to impersonate a
user named jane.doe@example.com , but only to list and watch pods
in the default namespace. You need both a ClusterRoleBinding for
the identity permission and a RoleBinding for the action permission

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: impersonate-jane-identity
rules:
- apiGroups: ["authentication.k8s.io"]
resources: ["users"]
resourceNames: ["jane.doe@example.com"]
verbs: ["impersonate:user-info"]
--apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: impersonate-jane-identity
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: ClusterRole
name: impersonate-jane-identity
subjects:
- kind: ServiceAccount
name: my-controller
namespace: default

2/27/26, 3:33 PM

API Access Control | Kubernetes

142 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
name: impersonate-list-watch-pods
namespace: default
rules:
- apiGroups: [""]
resources: ["pods"]
verbs:
- "impersonate-on:user-info:list"
- "impersonate-on:user-info:watch"
--apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
name: impersonate-list-watch-pods
namespace: default
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: Role
name: impersonate-list-watch-pods
subjects:
- kind: ServiceAccount
name: my-controller
namespace: default

Now the my-controller service account can impersonate
jane.doe@example.com to list and watch pods in the default

namespace, but
perform other actions like deleting pods or
accessing resources in other namespaces.

Example: Impersonate a ServiceAccount
To allow impersonating a service account named app-sa in the
production namespace to create and update deployments:

2/27/26, 3:33 PM

API Access Control | Kubernetes

143 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
name: impersonate-app-sa
namespace: default
rules:
- apiGroups: ["authentication.k8s.io"]
resources: ["serviceaccounts"]
resourceNames: ["app-sa"]
# For service accounts, you must specify the namespace in the RoleBinding
verbs: ["impersonate:serviceaccount"]
--apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
name: impersonate-manage-deployments
namespace: production
rules:
- apiGroups: ["apps"]
resources: ["deployments"]
verbs:
- "impersonate-on:serviceaccount:create"
- "impersonate-on:serviceaccount:update"
- "impersonate-on:serviceaccount:patch"
--apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
name: impersonate-app-sa
namespace: default
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: Role
name: impersonate-app-sa
subjects:
- kind: ServiceAccount
name: deputy-controller
namespace: default
--apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
name: impersonate-manage-deployments
namespace: production
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: Role
name: impersonate-manage-deployments
subjects:
- kind: ServiceAccount
name: deputy-controller
namespace: default

Example: Impersonate a node
To allow node-impersonator ServiceAccount in default namespace
impersonating a node named mynode to get and list pods:

2/27/26, 3:33 PM

API Access Control | Kubernetes

144 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: impersonate-node-sa
rules:
- apiGroups: ["authentication.k8s.io"]
resources: ["nodes"]
resourceNames: ["mynode"]
verbs: ["impersonate:arbitrary-node"]
--apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: impersonate-list-pods
rules:
- apiGroups: [""]
resources: ["pods"]
verbs:
- "impersonate-on:arbitrary-node:list"
- "impersonate-on:arbitrary-node:get"
--apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: impersonate-node-sa
namespace: default
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: ClusterRole
name: impersonate-node-sa
subjects:
- kind: ServiceAccount
name: node-impersonator
namespace: default
--apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: impersonate-list-pods
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: ClusterRole
name: impersonate-list-pods
subjects:
- kind: ServiceAccount
name: node-impersonator
namespace: default

Example: Node agent impersonating the associated node
This is a common pattern for node agents (like CNI plugins) that need to
read pods on their node without having cluster-wide pod access.

2/27/26, 3:33 PM

API Access Control | Kubernetes

145 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: impersonate-associated-node-identity
rules:
- apiGroups: ["authentication.k8s.io"]
resources: ["nodes"]
verbs: ["impersonate:associated-node"]
--apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: impersonate-list-pods-on-node
rules:
- apiGroups: [""]
resources: ["pods"]
verbs:
- "impersonate-on:associated-node:list"
- "impersonate-on:associated-node:get"
--apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: node-agent-impersonate-node
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: ClusterRole
name: impersonate-associated-node-identity
subjects:
- kind: ServiceAccount
name: node-agent
namespace: kube-system
--apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: node-agent-impersonate-list-pods
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: ClusterRole
name: impersonate-list-pods-on-node
subjects:
- kind: ServiceAccount
name: node-agent
namespace: kube-system

The controller would get the node name using the downward API:

env:
- name: MY_NODE_NAME
valueFrom:
fieldRef:
fieldPath: spec.nodeName

Then con�gure the kubecon�g to impersonate:

kubeConfig, _ := clientcmd.BuildConfigFromFlags("", "")
kubeConfig.Impersonate = rest.ImpersonationConfig{
UserName: "system:node:" + os.Getenv("MY_NODE_NAME"),
}

2/27/26, 3:33 PM

API Access Control | Kubernetes

146 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Using constrained impersonation
From a client perspective, using constrained impersonation is identical to
using traditional impersonation. You use the same impersonation
headers:

Impersonate-User: jane.doe@example.com

Or with kubectl:

kubectl get pods -n default --as=jane.doe@example.com

The di�erence is entirely in the authorization checks performed by the
API server.

Working with impersonate verb
• If you have existing RBAC rules using the impersonate verb, they
continue to function when the feature gate is enabled.
• When an impersonation request is made, the API server �rst checks
for constrained impersonation permissions. If those checks fail, it
falls back to checking the impersonate permission.

Auditing
An audit event is logged for each impersonation request to help track
how impersonation is used.
When a request uses constrained impersonation, the audit event
includes authenticationMetadata object with an
impersonationConstraint �eld that indicates which constrained

impersonation verb was used to authorize the request.
Example audit event:

{
"kind": "Event",
"apiVersion": "audit.k8s.io/v1",
"user": {
"username": "system:serviceaccount:default:my-controller"
},
"impersonatedUser": {
"username": "jane.doe@example.com"
},
"authenticationMetadata": {
"impersonationConstraint": "impersonate:user-info"
},
"verb": "list",
"objectRef": {
"resource": "pods",
"namespace": "default"
}
}

The impersonationConstraint value indicates which mode was used (for

2/27/26, 3:33 PM

API Access Control | Kubernetes

147 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

example, impersonate:user-info , impersonate:associated-node ). The
speci�c action (for example, list ) can be determined from the verb
�eld in the audit event.

What's next
• Read about RBAC authorization
• Understand Kubernetes authentication

2/27/26, 3:33 PM

API Access Control | Kubernetes

148 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Kubernetes certi�cate and trust bundle APIs enable automation of X.509
credential provisioning by providing a programmatic interface for clients
of the Kubernetes API to request and obtain X.509 certi�cates from a
Certi�cate Authority (CA).
There is also experimental (alpha) support for distributing trust bundles.

Certi�cate signing requests
ⓘ

Kubernetes v1.19 [stable]

A Certi�cateSigningRequest (CSR) resource is used to request that a
certi�cate be signed by a denoted signer, after which the request may be
approved or denied before �nally being signed.

Request signing process
The Certi�cateSigningRequest resource type allows a client to ask for an
X.509 certi�cate be issued, based on a signing request. The
Certi�cateSigningRequest object includes a PEM-encoded PKCS#10
signing request in the spec.request �eld. The Certi�cateSigningRequest
denotes the signer (the recipient that the request is being made to) using
the spec.signerName �eld. Note that spec.signerName is a required key
after API version certificates.k8s.io/v1 . In Kubernetes v1.22 and
later, clients may optionally set the spec.expirationSeconds �eld to
request a particular lifetime for the issued certi�cate. The minimum valid
value for this �eld is 600 , i.e. ten minutes.
Once created, a Certi�cateSigningRequest must be approved before it
can be signed. Depending on the signer selected, a
Certi�cateSigningRequest may be automatically approved by a controller.
Otherwise, a Certi�cateSigningRequest must be manually approved
either via the REST API (or client-go) or by running kubectl certificate
approve . Likewise, a Certi�cateSigningRequest may also be denied, which

tells the con�gured signer that it must not sign the request.
For certi�cates that have been approved, the next step is signing. The
relevant signing controller �rst validates that the signing conditions are
met and then creates a certi�cate. The signing controller then updates
the Certi�cateSigningRequest, storing the new certi�cate into the
status.certificate �eld of the existing Certi�cateSigningRequest
object. The status.certificate �eld is either empty or contains a X.509
certi�cate, encoded in PEM format. The Certi�cateSigningRequest
status.certificate �eld is empty until the signer does this.
Once the status.certificate �eld has been populated, the request has
been completed and clients can now fetch the signed certi�cate PEM
data from the Certi�cateSigningRequest resource. The signers can
instead deny certi�cate signing if the approval conditions are not met.
In order to reduce the number of old Certi�cateSigningRequest resources
left in a cluster, a garbage collection controller runs periodically. The
garbage collection removes Certi�cateSigningRequests that have not
changed state for some duration:
• Approved requests: automatically deleted after 1 hour

2/27/26, 3:33 PM

API Access Control | Kubernetes

149 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• Denied requests: automatically deleted after 1 hour
• Failed requests: automatically deleted after 1 hour
• Pending requests: automatically deleted after 24 hours
• All requests: automatically deleted after the issued certi�cate has
expired

Certi�cate signing authorization
To allow creating a Certi�cateSigningRequest and retrieving any
Certi�cateSigningRequest:
• Verbs: create , get , list , watch , group: certificates.k8s.io ,
resource: certificatesigningrequests
For example:

access/certificate-signing-request/clusterrole-create.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: csr-creator
rules:
- apiGroups:
- certificates.k8s.io
resources:
- certificatesigningrequests
verbs:
- create
- get
- list
- watch

To allow approving a Certi�cateSigningRequest:
• Verbs: get , list , watch , group: certificates.k8s.io , resource:
certificatesigningrequests

• Verbs: update , group: certificates.k8s.io , resource:
certificatesigningrequests/approval

• Verbs: approve , group: certificates.k8s.io , resource: signers ,
resourceName: <signerNameDomain>/<signerNamePath> or
<signerNameDomain>/*

For example:

access/certificate-signing-request/clusterrole-approve.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

150 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: csr-approver
rules:
- apiGroups:
- certificates.k8s.io
resources:
- certificatesigningrequests
verbs:
- get
- list
- watch
- apiGroups:
- certificates.k8s.io
resources:
- certificatesigningrequests/approval
verbs:
- update
- apiGroups:
- certificates.k8s.io
resources:
- signers
resourceNames:
- example.com/my-signer-name # example.com/* can be used to authorize for all
verbs:
- approve

To allow signing a Certi�cateSigningRequest:
• Verbs: get , list , watch , group: certificates.k8s.io , resource:
certificatesigningrequests

• Verbs: update , group: certificates.k8s.io , resource:
certificatesigningrequests/status

• Verbs: sign , group: certificates.k8s.io , resource: signers ,
resourceName: <signerNameDomain>/<signerNamePath> or
<signerNameDomain>/*

access/certificate-signing-request/clusterrole-sign.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

151 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: csr-signer
rules:
- apiGroups:
- certificates.k8s.io
resources:
- certificatesigningrequests
verbs:
- get
- list
- watch
- apiGroups:
- certificates.k8s.io
resources:
- certificatesigningrequests/status
verbs:
- update
- apiGroups:
- certificates.k8s.io
resources:
- signers
resourceNames:
- example.com/my-signer-name # example.com/* can be used to authorize for all
verbs:
- sign

Signers
Signers abstractly represent the entity or entities that might sign, or have
signed, a security certi�cate.
Any signer that is made available for outside a particular cluster should
provide information about how the signer works, so that consumers can
understand what that means for Certi�cateSigningRequests and (if
enabled) ClusterTrustBundles. This includes:
1.

: how trust anchors (CA certi�cates or certi�cate
bundles) are distributed.

2.

: any restrictions on and behavior when a
disallowed subject is requested.

3.

: including IP subjectAltNames, DNS
subjectAltNames, Email subjectAltNames, URI subjectAltNames etc,
and behavior when a disallowed extension is requested.

4.

: any restrictions on
and behavior when usages di�erent than the signer-determined
usages are speci�ed in the CSR.

5.

: whether it is �xed by the signer,
con�gurable by the admin, determined by the CSR
spec.expirationSeconds �eld, etc and the behavior when the
signer-determined expiration is di�erent from the CSR
spec.expirationSeconds �eld.

6.

: and behavior if a CSR contains a
request for a CA certi�cate when the signer does not permit it.

Commonly, the status.certificate �eld of a Certi�cateSigningRequest
contains a single PEM-encoded X.509 certi�cate once the CSR is approved
and the certi�cate is issued. Some signers store multiple certi�cates into
the status.certificate �eld. In that case, the documentation for the
signer should specify the meaning of additional certi�cates; for example,
2/27/26, 3:33 PM

API Access Control | Kubernetes

152 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

this might be the certi�cate plus intermediates to be presented during
TLS handshakes.
If you want to make the trust anchor (root certi�cate) available, this
should be done separately from a Certi�cateSigningRequest and its
status.certificate �eld. For example, you could use a
ClusterTrustBundle.
The PKCS#10 signing request format does not have a standard
mechanism to specify a certi�cate expiration or lifetime. The expiration
or lifetime therefore has to be set through the spec.expirationSeconds
�eld of the CSR object. The built-in signers use the
ClusterSigningDuration con�guration option, which defaults to 1 year,
(the --cluster-signing-duration command-line �ag of the kubecontroller-manager) as the default when no spec.expirationSeconds is
speci�ed. When spec.expirationSeconds is speci�ed, the minimum of
spec.expirationSeconds and ClusterSigningDuration is used.

The spec.expirationSeconds �eld was added in Kubernetes v1.22.
Earlier versions of Kubernetes do not honor this �eld. Kubernetes
API servers prior to v1.22 will silently drop this �eld when the object
is created.

Kubernetes signers
Kubernetes provides built-in signers that each have a well-known
signerName :
1. kubernetes.io/kube-apiserver-client : signs certi�cates that will
be honored as client certi�cates by the API server. Never autoapproved by kube-controller-manager.
1. Trust distribution: signed certi�cates must be honored as
client certi�cates by the API server. The CA bundle is not
distributed by any other means.
2. Permitted subjects - no subject restrictions, but approvers and
signers may choose not to approve or sign. Certain subjects
like cluster-admin level users or groups vary between
distributions and installations, but deserve additional scrutiny
before approval and signing. The
CertificateSubjectRestriction admission plugin is enabled
by default to restrict system:masters , but it is often not the
only cluster-admin subject in a cluster.
3. Permitted x509 extensions - honors subjectAltName and key
usage extensions and discards other extensions.
4. Permitted key usages - must include ["client auth"] . Must
not include key usages beyond ["digital signature", "key
encipherment", "client auth"] .

5. Expiration/certi�cate lifetime - for the kube-controllermanager implementation of this signer, set to the minimum of
the --cluster-signing-duration option or, if speci�ed, the
spec.expirationSeconds �eld of the CSR object.

6. CA bit allowed/disallowed - not allowed.
2. kubernetes.io/kube-apiserver-client-kubelet : signs client
certi�cates that will be honored as client certi�cates by the API
server. May be auto-approved by kube-controller-manager.
1. Trust distribution: signed certi�cates must be honored as
client certi�cates by the API server. The CA bundle is not
2/27/26, 3:33 PM

API Access Control | Kubernetes

153 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

distributed by any other means.
2. Permitted subjects - organizations are exactly
["system:nodes"] , common name is " system:node:
${NODE_NAME} ".

3. Permitted x509 extensions - honors key usage extensions,
forbids subjectAltName extensions and drops other
extensions.
4. Permitted key usages - ["key encipherment", "digital
signature", "client auth"] or ["digital signature",
"client auth"] .

5. Expiration/certi�cate lifetime - for the kube-controllermanager implementation of this signer, set to the minimum of
the --cluster-signing-duration option or, if speci�ed, the
spec.expirationSeconds �eld of the CSR object.

6. CA bit allowed/disallowed - not allowed.
3. kubernetes.io/kubelet-serving : signs serving certi�cates that are
honored as a valid kubelet serving certi�cate by the API server, but
has no other guarantees. Never auto-approved by
kube-controller-manager.
1. Trust distribution: signed certi�cates must be honored by the
API server as valid to terminate connections to a kubelet. The
CA bundle is not distributed by any other means.
2. Permitted subjects - organizations are exactly
["system:nodes"] , common name is " system:node:
${NODE_NAME} ".

3. Permitted x509 extensions - honors key usage and DNSName/
IPAddress subjectAltName extensions, forbids EmailAddress
and URI subjectAltName extensions, drops other extensions.
At least one DNS or IP subjectAltName must be present.
4. Permitted key usages - ["key encipherment", "digital
signature", "server auth"] or ["digital signature",
"server auth"] .

5. Expiration/certi�cate lifetime - for the kube-controllermanager implementation of this signer, set to the minimum of
the --cluster-signing-duration option or, if speci�ed, the
spec.expirationSeconds �eld of the CSR object.

6. CA bit allowed/disallowed - not allowed.
4. kubernetes.io/legacy-unknown : has no guarantees for trust at all.
Some third-party distributions of Kubernetes may honor client
certi�cates signed by it. The stable Certi�cateSigningRequest API
(version certificates.k8s.io/v1 and later) does not allow to set
the signerName as kubernetes.io/legacy-unknown . Never autoapproved by kube-controller-manager.
1. Trust distribution: None. There is no standard trust or
distribution for this signer in a Kubernetes cluster.
2. Permitted subjects - any
3. Permitted x509 extensions - honors subjectAltName and key
usage extensions and discards other extensions.
4. Permitted key usages - any
5. Expiration/certi�cate lifetime - for the kube-controllermanager implementation of this signer, set to the minimum of
the --cluster-signing-duration option or, if speci�ed, the
spec.expirationSeconds �eld of the CSR object.

6. CA bit allowed/disallowed - not allowed.
The kube-controller-manager implements control plane signing for each
of the built in signers. Failures for all of these are only reported in kube2/27/26, 3:33 PM

API Access Control | Kubernetes

154 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

controller-manager logs.

The spec.expirationSeconds �eld was added in Kubernetes v1.22.
Earlier versions of Kubernetes do not honor this �eld. Kubernetes
API servers prior to v1.22 will silently drop this �eld when the object
is created.

Distribution of trust happens out of band for these signers. Any trust
outside of those described above are strictly coincidental. For instance,
some distributions may honor kubernetes.io/legacy-unknown as client
certi�cates for the kube-apiserver, but this is not a standard. None of
these usages are related to ServiceAccount token secrets .data[ca.crt]
in any way. That CA bundle is only guaranteed to verify a connection to
the API server using the default service ( kubernetes.default.svc ).

Custom signers
You can also introduce your own custom signer, which should have a
similar pre�xed name but using your own domain name. For example, if
you represent an open source project that uses the domain openfictional.example then you might use issuer.openfictional.example/service-mesh as a signer name.

A custom signer uses the Kubernetes API to issue a certi�cate. See APIbased signers.

Signing
Control plane signer
The Kubernetes control plane implements each of the Kubernetes
signers, as part of the kube-controller-manager.

Prior to Kubernetes v1.18, the kube-controller-manager would sign
any CSRs that were marked as approved.

The spec.expirationSeconds �eld was added in Kubernetes v1.22.
Earlier versions of Kubernetes do not honor this �eld. Kubernetes
API servers prior to v1.22 will silently drop this �eld when the object
is created.

API-based signers
Users of the REST API can sign CSRs by submitting an UPDATE request to
the status subresource of the CSR to be signed.
As part of this request, the status.certificate �eld should be set to
contain the signed certi�cate. This �eld contains one or more PEMencoded certi�cates.
All PEM blocks must have the "CERTIFICATE" label, contain no headers,
and the encoded data must be a BER-encoded ASN.1 Certi�cate structure
as described in section 4 of RFC5280.

2/27/26, 3:33 PM

API Access Control | Kubernetes

155 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Example certi�cate content:
-----BEGIN CERTIFICATE----MIIDgjCCAmqgAwIBAgIUC1N1EJ4Qnsd322BhDPRwmg3b/oAwDQYJKoZIhvcNAQEL
BQAwXDELMAkGA1UEBhMCeHgxCjAIBgNVBAgMAXgxCjAIBgNVBAcMAXgxCjAIBgNV
BAoMAXgxCjAIBgNVBAsMAXgxCzAJBgNVBAMMAmNhMRAwDgYJKoZIhvcNAQkBFgF4
MB4XDTIwMDcwNjIyMDcwMFoXDTI1MDcwNTIyMDcwMFowNzEVMBMGA1UEChMMc3lz
dGVtOm5vZGVzMR4wHAYDVQQDExVzeXN0ZW06bm9kZToxMjcuMC4wLjEwggEiMA0G
CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDne5X2eQ1JcLZkKvhzCR4Hxl9+ZmU3
+e1zfOywLdoQxrPi+o4hVsUH3q0y52BMa7u1yehHDRSaq9u62cmi5ekgXhXHzGmm
kmW5n0itRECv3SFsSm2DSghRKf0mm6iTYHWDHzUXKdm9lPPWoSOxoR5oqOsm3JEh
Q7Et13wrvTJqBMJo1GTwQuF+HYOku0NF/DLqbZIcpI08yQKyrBgYz2uO51/oNp8a
sTCsV4OUfyHhx2BBLUo4g4SptHFySTBwlpRWBnSjZPOhmN74JcpTLB4J5f4iEeA7
2QytZfADckG4wVkhH3C2EJUmRtFIBVirwDn39GXkSGlnvnMgF3uLZ6zNAgMBAAGj
YTBfMA4GA1UdDwEB/wQEAwIFoDATBgNVHSUEDDAKBggrBgEFBQcDAjAMBgNVHRMB
Af8EAjAAMB0GA1UdDgQWBBTREl2hW54lkQBDeVCcd2f2VSlB1DALBgNVHREEBDAC
ggAwDQYJKoZIhvcNAQELBQADggEBABpZjuIKTq8pCaX8dMEGPWtAykgLsTcD2jYr
L0/TCrqmuaaliUa42jQTt2OVsVP/L8ofFunj/KjpQU0bvKJPLMRKtmxbhXuQCQi1
qCRkp8o93mHvEz3mTUN+D1cfQ2fpsBENLnpS0F4G/JyY2Vrh19/X8+mImMEK5eOy
o0BMby7byUj98WmcUvNCiXbC6F45QTmkwEhMqWns0JZQY+/XeDhEcg+lJvz9Eyo2
aGgPsye1o3DpyXnyfJWAWMhOz7cikS5X2adesbgI86PhEHBXPIJ1v13ZdfCExmdd
M1fLPhLyR54fGaY+7/X8P9AZzPefAkwizeXwe9ii6/a08vWoiE4=
-----END CERTIFICATE-----

Non-PEM content may appear before or after the CERTIFICATE PEM
blocks and is unvalidated, to allow for explanatory text as described in
section 5.2 of RFC7468.
When encoded in JSON or YAML, this �eld is base-64 encoded. A
Certi�cateSigningRequest containing the example certi�cate above would
look like this:

apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
...
status:
certificate: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JS..."

Approval or rejection
Before a signer issues a certi�cate based on a Certi�cateSigningRequest,
the signer typically checks that the issuance for that CSR has been
approved.

Control plane automated approval
The kube-controller-manager ships with a built-in approver for
certi�cates with a signerName of kubernetes.io/kube-apiserverclient-kubelet that delegates various permissions on CSRs for node

credentials to authorization. The kube-controller-manager POSTs
SubjectAccessReview resources to the API server in order to check
authorization for certi�cate approval.

Approval or rejection using kubectl
A Kubernetes administrator (with appropriate permissions) can manually
approve (or deny) Certi�cateSigningRequests by using the kubectl
certificate approve and kubectl certificate deny commands.

To approve a CSR with kubectl:

2/27/26, 3:33 PM

API Access Control | Kubernetes

156 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

kubectl certificate approve <certificate-signing-request-name>

Likewise, to deny a CSR:

kubectl certificate deny <certificate-signing-request-name>

Approval or rejection using the Kubernetes API
Users of the REST API can approve CSRs by submitting an UPDATE
request to the approval subresource of the CSR to be approved. For
example, you could write an operator that watches for a particular kind
of CSR and then sends an UPDATE to approve them.
When you make an approval or rejection request, set either the
Approved or Denied status condition based on the state you determine:
For Approved CSRs:

apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
...
status:
conditions:
- lastUpdateTime: "2020-02-08T11:37:35Z"
lastTransitionTime: "2020-02-08T11:37:35Z"
message: Approved by my custom approver controller
reason: ApprovedByMyPolicy # You can set this to any string
type: Approved

For Denied CSRs:

apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
...
status:
conditions:
- lastUpdateTime: "2020-02-08T11:37:35Z"
lastTransitionTime: "2020-02-08T11:37:35Z"
message: Denied by my custom approver controller
reason: DeniedByMyPolicy # You can set this to any string
type: Denied

It's usual to set status.conditions.reason to a machine-friendly reason
code using TitleCase; this is a convention but you can set it to anything
you like. If you want to add a note for human consumption, use the
status.conditions.message �eld.

PodCerti�cateRequests
ⓘ

Kubernetes v1.35 [beta](disabled by

default)

2/27/26, 3:33 PM

API Access Control | Kubernetes

157 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

In Kubernetes 1.35, you must enable support for Pod Certi�cates
using the PodCertificateRequest feature gate and the --runtimeconfig=certificates.k8s.io/v1beta1/
podcertificaterequests=true kube-apiserver �ag.

PodCerti�cateRequests are API objects tailored to provisioning
certi�cates to workloads running as Pods within a cluster. The user
typically does not interact with PodCerti�cateRequests directly, but uses
podCerti�cate projected volume sources, which are a kubelet feature
that handles secure key provisioning and automatic certi�cate refresh.
The application inside the pod only needs to know how to read the
certi�cates from the �lesystem.
PodCerti�cateRequests are similar to Certi�cateSigningRequests, but
have a simpler format enabled by their narrower use case.
A PodCerti�cateRequest has the following spec �elds:
• signerName : The signer to which this request is addressed.
• podName and podUID : The Pod that Kubelet is requesting a
certi�cate for.
• serviceAccountName and serviceAccountUID : The ServiceAccount
corresponding to the Pod.
• nodeName and nodeUID : The Node corresponding to the Pod.
• maxExpirationSeconds : The maximum lifetime that the workload
author will accept for this certi�cate. Defaults to 24 hours if not
speci�ed.
• pkixPublicKey : The public key for which the certi�cate should be
issued.
• proofOfPossession : A signature demonstrating that the requester
controls the private key corresponding to pkixPublicKey .
• unverifiedUserAnnotations : A map that allows the user to pass
additional information to the signer implementation. It is copied
verbatim from the userAnnotations �eld of the podCerti�cate
projected volume source. Entries are subject to the same validation
as object metadata annotations, with the addition that all keys must
be domain-pre�xed. No restrictions are placed on values, except an
overall size limitation on the entire �eld. Other than these basic
validations, the API server does not conduct any extra validations.
The signer implementations should be very careful when
consuming this data. Signers must not inherently trust this data
without �rst performing the appropriate veri�cation steps. Signers
should document the keys and values they support. Signers should
deny requests that contain keys they do not recognize.
Nodes automatically receive permissions to create
PodCerti�cateRequests and read PodCerti�cateRequests related to them
(as determined by the spec.nodeName �eld). The NodeRestriction
admission plugin, if enabled, ensures that nodes can only create
PodCerti�cateRequests that correspond to a real pod that is currently
running on the node.
After creation, the spec of a PodCerti�cateRequest is immutable.
Unlike CSRs, PodCerti�cateRequests do not have an approval phase.
Once the PodCerti�cateRequest is created, the signer's controller directly
decides to issue or deny the request. It also has the option to mark the
request as failed, if it encountered a permanent error when attempting
to issue the request.

2/27/26, 3:33 PM

API Access Control | Kubernetes

158 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

To take any of these actions, the signing controller needs to have the
appropriate permissions on both the PodCerti�cateRequest type, as well
as on the signer name:
• Verbs:

, group: certificates.k8s.io , resource:

podcertificaterequests/status

• Verbs:

, group: certificates.k8s.io , resource: signers ,

resourceName: <signerNameDomain>/<signerNamePath> or
<signerNameDomain>/*

The signing controller is free to consider other information beyond
what's contained in the request, but it can rely on the information in the
request to be accurate. For example, the signing controller might load
the Pod and read annotations set on it, or perform a
SubjectAccessReview on the ServiceAccount.
To issue a certi�cate in response to a request, the signing controller:
• Adds an Issued condition to status.conditions .
• Puts the issued certi�cate in status.certificateChain
• Puts the NotBefore and NotAfter �elds of the certi�cate in the
status.notBefore and status.notAfter �elds — these �elds are

denormalized into the Kubernetes API in order to aid debugging
• Suggests a time to begin attempting to refresh the certi�cate using
status.beginRefreshAt .

To deny a request, the signing controller adds a "Denied" condition to
status.conditions[] .

To mark a request failed, the signing controller adds a "Failed" condition
to status.conditions[] .
All of these conditions are mutually-exclusive, and must have status
"True". No other condition types are permitted on
PodCerti�cateRequests. In addition, once any of these conditions are set,
the status �eld becomes immutable.
Like all conditions, the status.conditions[].reason �eld is meant to
contain a machine-readable code describing the condition in TitleCase.
The status.conditions[].message �eld is meant for a free-form
explanation for human consumption.
To ensure that terminal PodCerti�cateRequests do not build up in the
cluster, a kube-controller-manager controller deletes all
PodCerti�cateRequests older than 15 minutes. All certi�cate issuance
�ows are expected to complete within this 15-minute limit.

Cluster trust bundles
ⓘ

Kubernetes v1.33 [beta](disabled by

default)

In Kubernetes 1.35, you must enable the ClusterTrustBundle
feature gate and the certificates.k8s.io/v1alpha1 API group in
order to use this API.

A ClusterTrustBundles is a cluster-scoped object for distributing X.509

2/27/26, 3:33 PM

API Access Control | Kubernetes

159 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

trust anchors (root certi�cates) to workloads within the cluster. They're
designed to work well with the signer concept from
Certi�cateSigningRequests.
ClusterTrustBundles can be used in two modes: signer-linked and signerunlinked.

Common properties and validation
All ClusterTrustBundle objects have strong validation on the contents of
their trustBundle �eld. That �eld must contain one or more X.509
certi�cates, DER-serialized, each wrapped in a PEM CERTIFICATE block.
The certi�cates must parse as valid X.509 certi�cates.
Esoteric PEM features like inter-block data and intra-block headers are
either rejected during object validation, or can be ignored by consumers
of the object. Additionally, consumers are allowed to reorder the
certi�cates in the bundle with their own arbitrary but stable ordering.
ClusterTrustBundle objects should be considered world-readable within
the cluster. If your cluster uses RBAC authorization, all ServiceAccounts
have a default grant that allows them to
,
, and
all
ClusterTrustBundle objects. If you use your own authorization
mechanism and you have enabled ClusterTrustBundles in your cluster,
you should set up an equivalent rule to make these objects public within
the cluster, so that they work as intended.
If you do not have permission to list cluster trust bundles by default in
your cluster, you can impersonate a service account you have access to
in order to see available ClusterTrustBundles:

kubectl get clustertrustbundles --as='system:serviceaccount:mynamespace:default'

Signer-linked ClusterTrustBundles
Signer-linked ClusterTrustBundles are associated with a signer name, like
this:

apiVersion: certificates.k8s.io/v1alpha1
kind: ClusterTrustBundle
metadata:
name: example.com:mysigner:foo
spec:
signerName: example.com/mysigner
trustBundle: "<... PEM data ...>"

These ClusterTrustBundles are intended to be maintained by a signerspeci�c controller in the cluster, so they have several security features:
• To create or update a signer-linked ClusterTrustBundle, you must
on the signer (custom authorization verb
be permitted to
attest , API group certificates.k8s.io ; resource path signers ).
You can con�gure authorization for the speci�c resource name
<signerNameDomain>/<signerNamePath> or match a pattern such as
<signerNameDomain>/* .

be named with a pre�x
• Signer-linked ClusterTrustBundles
derived from their spec.signerName �eld. Slashes ( / ) are replaced
with colons ( : ), and a �nal colon is appended. This is followed by
an arbitrary name. For example, the signer example.com/mysigner

2/27/26, 3:33 PM

API Access Control | Kubernetes

160 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

can be linked to a ClusterTrustBundle
example.com:mysigner:<arbitrary-name> .

Signer-linked ClusterTrustBundles will typically be consumed in
workloads by a combination of a �eld selector on the signer name, and a
separate label selector.

Signer-unlinked ClusterTrustBundles
Signer-unlinked ClusterTrustBundles have an empty spec.signerName
�eld, like this:

apiVersion: certificates.k8s.io/v1alpha1
kind: ClusterTrustBundle
metadata:
name: foo
spec:
# no signerName specified, so the field is blank
trustBundle: "<... PEM data ...>"

They are primarily intended for cluster con�guration use cases. Each
signer-unlinked ClusterTrustBundle is an independent object, in contrast
to the customary grouping behavior of signer-linked ClusterTrustBundles.
Signer-unlinked ClusterTrustBundles have no attest verb requirement.
Instead, you control access to them directly using the usual mechanisms,
such as role-based access control.
To distinguish them from signer-linked ClusterTrustBundles, the names
of signer-unlinked ClusterTrustBundles
contain a colon ( : ).

Accessing ClusterTrustBundles from pods
ⓘ

Kubernetes v1.33 [beta](disabled by

default)
The contents of ClusterTrustBundles can be injected into the container
�lesystem, similar to Con�gMaps and Secrets. See the clusterTrustBundle
projected volume source for more details.

What's next
• Read Manage TLS Certi�cates in a Cluster
• Read Issue a Certi�cate for a Kubernetes API Client Using A
Certi�cateSigningRequest
• View the source code for the kube-controller-manager built in
signer
• View the source code for the kube-controller-manager built in
approver
• For details of X.509 itself, refer to RFC 5280 section 3.1
• For information on the syntax of PKCS#10 certi�cate signing
requests, refer to RFC 2986
• Read about the ClusterTrustBundle API:
◦ %!s()

2/27/26, 3:33 PM

API Access Control | Kubernetes

161 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

The tables below enumerate the con�guration parameters on
PodSecurityPolicy objects, whether the �eld mutates and/or validates
pods, and how the con�guration values map to the Pod Security
Standards.
For each applicable parameter, the allowed values for the Baseline and
Restricted pro�les are listed. Anything outside the allowed values for
those pro�les would fall under the Privileged pro�le. "No opinion" means
all values are allowed under all Pod Security Standards.
For a step-by-step migration guide, see Migrate from PodSecurityPolicy to
the Built-In PodSecurity Admission Controller.

PodSecurityPolicy Spec
The �elds enumerated in this table are part of the
PodSecurityPolicySpec , which is speci�ed under the .spec �eld path.
PodSecurityPolicySpec

privileged

Validating

: false
unde�ned / nil

defaultAddCapabilities

Mutating &
Validating

allowedCapabilities

Validating

Requirements match
allowedCapabilities below.
: subset of
• AUDIT_WRITE
• CHOWN
• DAC_OVERRIDE
• FOWNER
• FSETID
• KILL
• MKNOD
• NET_BIND_SERVICE
• SETFCAP
• SETGID
• SETPCAP
• SETUID
• SYS_CHROOT
: empty / unde�ned /
nil OR a list containing only
NET_BIND_SERVICE

requiredDropCapabilities

Mutating &
Validating

: no opinion
: must include ALL

2/27/26, 3:33 PM

API Access Control | Kubernetes

162 of 200

volumes

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Validating

: anything except
• hostPath
• *
: subset of
• configMap
• csi
• downwardAPI
• emptyDir
• ephemeral
• persistentVolumeClaim
• projected
• secret

hostNetwork

Validating

: false
unde�ned / nil

hostPorts

Validating

hostPID

Validating

:
unde�ned / nil / empty
: false
unde�ned / nil

hostIPC

Validating

: false
unde�ned / nil

seLinux

Mutating &
Validating

:
seLinux.rule is MustRunAs
with the following options
• user is unset ( "" /
unde�ned / nil)
• role is unset ( "" /
unde�ned / nil)
• type is unset or one of:
container_t,
container_init_t,
container_kvm_t,
container_engine_t
• level is anything

runAsUser

Mutating &
Validating

: Anything
: rule is
MustRunAsNonRoot

runAsGroup

Mutating
(MustRunAs)
& Validating

No opinion

supplementalGroups

Mutating &
Validating

No opinion

2/27/26, 3:33 PM

API Access Control | Kubernetes

163 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

fsGroup

Mutating &
Validating

No opinion

readOnlyRootFilesystem

Mutating &
Validating

No opinion

defaultAllowPrivilegeEscalation

Mutating

No opinion (non-validating)

allowPrivilegeEscalation

Mutating &
Validating

Only mutating if set to false
: No opinion
: false

allowedHostPaths

Validating

No opinion (volumes takes
precedence)

allowedFlexVolumes

Validating

No opinion (volumes takes
precedence)

allowedCSIDrivers

Validating

No opinion (volumes takes
precedence)

allowedUnsafeSysctls

Validating

:
unde�ned / nil / empty

forbiddenSysctls

Validating

No opinion

allowedProcMountTypes

Validating

:
["Default"] OR unde�ned /

(alpha feature)

nil / empty
runtimeClass

Mutating

No opinion

Validating

No opinion

.defaultRuntimeClassName
runtimeClass
.allowedRuntimeClassNames

PodSecurityPolicy annotations
The annotations enumerated in this table can be speci�ed under
.metadata.annotations on the PodSecurityPolicy object.
PSP Annotation

seccomp.security.alpha.kubernetes.io

Mutating

No opinion

/defaultProfileName

2/27/26, 3:33 PM

API Access Control | Kubernetes

164 of 200

seccomp.security.alpha.kubernetes.io

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Validating

: "runtime/
default," (Trailing

/allowedProfileNames

comma to allow unset)
:
"runtime/default"
(No trailing comma)
localhost/* values
are also permitted for
both Baseline &
Restricted.

apparmor.security.beta.kubernetes.io

Mutating

No opinion

/defaultProfileName
apparmor.security.beta.kubernetes.io
/allowedProfileNames

Validating

: "runtime/
default," (Trailing
comma to allow unset)
:
"runtime/default"
(No trailing comma)
localhost/* values
are also permitted for
both Baseline &
Restricted.

2/27/26, 3:33 PM

API Access Control | Kubernetes

165 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Overview
A kubelet's HTTPS endpoint exposes APIs which give access to data of
varying sensitivity, and allow you to perform operations with varying
levels of power on the node and within containers.
This document describes how to authenticate and authorize access to
the kubelet's HTTPS endpoint.

Kubelet authentication
By default, requests to the kubelet's HTTPS endpoint that are not
rejected by other con�gured authentication methods are treated as
anonymous requests, and given a username of system:anonymous and a
group of system:unauthenticated .
To disable anonymous access and send 401 Unauthorized responses to
unauthenticated requests:
• start the kubelet with the --anonymous-auth=false �ag
To enable X509 client certi�cate authentication to the kubelet's HTTPS
endpoint:
• start the kubelet with the --client-ca-file �ag, providing a CA
bundle to verify client certi�cates with
• start the apiserver with --kubelet-client-certificate and -kubelet-client-key �ags

• see the apiserver authentication documentation for more details
To enable API bearer tokens (including service account tokens) to be used
to authenticate to the kubelet's HTTPS endpoint:
• ensure the authentication.k8s.io/v1 API group is enabled in the
API server
• start the kubelet with the --authentication-token-webhook and
--kubeconfig �ags

• the kubelet calls the TokenReview API on the con�gured API server
to determine user information from bearer tokens

Kubelet authorization
Any request that is successfully authenticated (including an anonymous
request) is then authorized. The default authorization mode is
AlwaysAllow , which allows all requests.
There are many possible reasons to subdivide access to the kubelet API:
• anonymous auth is enabled, but anonymous users' ability to call the
kubelet API should be limited
• bearer token auth is enabled, but arbitrary API users' (like service
accounts) ability to call the kubelet API should be limited
• client certi�cate auth is enabled, but only some of the client
certi�cates signed by the con�gured CA should be allowed to use
the kubelet API
2/27/26, 3:33 PM

API Access Control | Kubernetes

166 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

To subdivide access to the kubelet API, delegate authorization to the API
server:
• ensure the authorization.k8s.io/v1 API group is enabled in the
API server
• start the kubelet with the --authorization-mode=Webhook and the
--kubeconfig �ags

• the kubelet calls the SubjectAccessReview API on the con�gured
API server to determine whether each request is authorized
The kubelet authorizes API requests using the same request attributes
approach as the apiserver.
The verb is determined from the incoming request's HTTP verb:

POST

create

GET, HEAD

get

PUT

update

PATCH

patch

DELETE

delete

The resource and subresource is determined from the incoming
request's path:

/stats/*

nodes

stats

/metrics/*

nodes

metrics

/logs/*

nodes

log

/spec/*

nodes

spec

/checkpoint/*

nodes

checkpoint

all others

nodes

proxy

nodes/proxy permission grants access to all other kubelet APIs.

This includes APIs that can be used to execute commands in any
container running on the node.
Some of these endpoints support Websocket protocols via HTTP
GET requests, which are authorized with the
verb. This means
that

permission on nodes/proxy is not a read-only permission,

and authorizes executing commands in any container running on
the node.

The namespace and API group attributes are always an empty string, and
the resource name is always the name of the kubelet's Node API object.

2/27/26, 3:33 PM

API Access Control | Kubernetes

167 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

When running in this mode, ensure the user identi�ed by the -kubelet-client-certificate and --kubelet-client-key �ags passed to

the apiserver is authorized for the following attributes:
• verb=*, resource=nodes, subresource=proxy
• verb=*, resource=nodes, subresource=stats
• verb=*, resource=nodes, subresource=log
• verb=*, resource=nodes, subresource=spec
• verb=*, resource=nodes, subresource=metrics

Fine-grained authorization
ⓘ

Kubernetes v1.33 [beta](enabled by

default)
When the feature gate KubeletFineGrainedAuthz is enabled kubelet
performs a �ne-grained check before falling back to the proxy
subresource for the /pods , /runningPods , /configz and /healthz
endpoints. The resource and subresource are determined from the
incoming request's path:

/stats/*

nodes

stats

/metrics/*

nodes

metrics

/logs/*

nodes

log

/pods

nodes

pods, proxy

/runningPods/

nodes

pods, proxy

/healthz

nodes

healthz, proxy

/con�gz

nodes

con�gz, proxy

all others

nodes

proxy

When the feature-gate KubeletFineGrainedAuthz is enabled, ensure the
user identi�ed by the --kubelet-client-certificate and --kubeletclient-key �ags passed to the API server is authorized for the following

attributes:
• verb=*, resource=nodes, subresource=proxy
• verb=*, resource=nodes, subresource=stats
• verb=*, resource=nodes, subresource=log
• verb=*, resource=nodes, subresource=metrics
• verb=*, resource=nodes, subresource=con�gz
• verb=*, resource=nodes, subresource=healthz
• verb=*, resource=nodes, subresource=pods
If RBAC authorization is used, enabling this gate also ensure that the
builtin system:kubelet-api-admin ClusterRole is updated with
permissions to access all the above mentioned subresources.

2/27/26, 3:33 PM

API Access Control | Kubernetes

168 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

In a Kubernetes cluster, the components on the worker nodes - kubelet
and kube-proxy - need to communicate with Kubernetes control plane
components, speci�cally kube-apiserver. In order to ensure that
communication is kept private, not interfered with, and ensure that each
component of the cluster is talking to another trusted component, we
strongly recommend using client TLS certi�cates on nodes.
The normal process of bootstrapping these components, especially
worker nodes that need certi�cates so they can communicate safely with
kube-apiserver, can be a challenging process as it is often outside of the
scope of Kubernetes and requires signi�cant additional work. This in
turn, can make it challenging to initialize or scale a cluster.
In order to simplify the process, beginning in version 1.4, Kubernetes
introduced a certi�cate request and signing API. The proposal can be
found here.
This document describes the process of node initialization, how to set up
TLS client certi�cate bootstrapping for kubelets, and how it works.

Initialization process
When a worker node starts up, the kubelet does the following:
1. Look for its kubeconfig �le
2. Retrieve the URL of the API server and credentials, normally a TLS
key and signed certi�cate from the kubeconfig �le
3. Attempt to communicate with the API server using the credentials.
Assuming that the kube-apiserver successfully validates the kubelet's
credentials, it will treat the kubelet as a valid node, and begin to assign
pods to it.
Note that the above process depends upon:
• Existence of a key and certi�cate on the local host in the
kubeconfig

• The certi�cate having been signed by a Certi�cate Authority (CA)
trusted by the kube-apiserver
All of the following are responsibilities of whoever sets up and manages
the cluster:
1. Creating the CA key and certi�cate
2. Distributing the CA certi�cate to the control plane nodes, where
kube-apiserver is running
3. Creating a key and certi�cate for each kubelet; strongly
recommended to have a unique one, with a unique CN, for each
kubelet
4. Signing the kubelet certi�cate using the CA key
5. Distributing the kubelet key and signed certi�cate to the speci�c
node on which the kubelet is running
The TLS Bootstrapping described in this document is intended to simplify,
and partially or even completely automate, steps 3 onwards, as these are
the most common when initializing or scaling a cluster.

Bootstrap initialization
In the bootstrap initialization process, the following occurs:
2/27/26, 3:33 PM

API Access Control | Kubernetes

169 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

1. kubelet begins
2. kubelet sees that it does not have a kubeconfig �le
3. kubelet searches for and �nds a bootstrap-kubeconfig �le
4. kubelet reads its bootstrap �le, retrieving the URL of the API server
and a limited usage "token"
5. kubelet connects to the API server, authenticates using the token
6. kubelet now has limited credentials to create and retrieve a
certi�cate signing request (CSR)
7. kubelet creates a CSR for itself with the signerName set to
kubernetes.io/kube-apiserver-client-kubelet

8. CSR is approved in one of two ways:
◦ If con�gured, kube-controller-manager automatically approves
the CSR
◦ If con�gured, an outside process, possibly a person, approves
the CSR using the Kubernetes API or via kubectl
9. Certi�cate is created for the kubelet
10. Certi�cate is issued to the kubelet
11. kubelet retrieves the certi�cate
12. kubelet creates a proper kubeconfig with the key and signed
certi�cate
13. kubelet begins normal operation
14. Optional: if con�gured, kubelet automatically requests renewal of
the certi�cate when it is close to expiry
15. The renewed certi�cate is approved and issued, either
automatically or manually, depending on con�guration.
The rest of this document describes the necessary steps to con�gure TLS
Bootstrapping, and its limitations.

Con�guration
To con�gure for TLS bootstrapping and optional automatic approval, you
must con�gure options on the following components:
• kube-apiserver
• kube-controller-manager
• kubelet
• in-cluster resources: ClusterRoleBinding and potentially
ClusterRole

In addition, you need your Kubernetes Certi�cate Authority (CA).

Certi�cate Authority
As without bootstrapping, you will need a Certi�cate Authority (CA) key
and certi�cate. As without bootstrapping, these will be used to sign the
kubelet certi�cate. As before, it is your responsibility to distribute them to
control plane nodes.
For the purposes of this document, we will assume these have been
distributed to control plane nodes at /var/lib/kubernetes/ca.pem
(certi�cate) and /var/lib/kubernetes/ca-key.pem (key). We will refer to
these as "Kubernetes CA certi�cate and key".
All Kubernetes components that use these certi�cates - kubelet, kubeapiserver, kube-controller-manager - assume the key and certi�cate to be
PEM-encoded.

2/27/26, 3:33 PM

API Access Control | Kubernetes

170 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

kube-apiserver con�guration
The kube-apiserver has several requirements to enable TLS
bootstrapping:
• Recognizing CA that signs the client certi�cate
• Authenticating the bootstrapping kubelet to the
system:bootstrappers group
• Authorize the bootstrapping kubelet to create a certi�cate signing
request (CSR)

Recognizing client certi�cates
This is normal for all client certi�cate authentication. If not already set,
add the --client-ca-file=FILENAME �ag to the kube-apiserver
command to enable client certi�cate authentication, referencing a
certi�cate authority bundle containing the signing certi�cate, for example
--client-ca-file=/var/lib/kubernetes/ca.pem .

Initial bootstrap authentication
In order for the bootstrapping kubelet to connect to kube-apiserver and
request a certi�cate, it must �rst authenticate to the server. You can use
any authenticator that can authenticate the kubelet.
While any authentication strategy can be used for the kubelet's initial
bootstrap credentials, the following two authenticators are
recommended for ease of provisioning.
1. Bootstrap Tokens
2. Token authentication �le
Using bootstrap tokens is a simpler and more easily managed method to
authenticate kubelets, and does not require any additional �ags when
starting kube-apiserver.
Whichever method you choose, the requirement is that the kubelet be
able to authenticate as a user with the rights to:
1. create and retrieve CSRs
2. be automatically approved to request node client certi�cates, if
automatic approval is enabled.
A kubelet authenticating using bootstrap tokens is authenticated as a
user in the group system:bootstrappers , which is the standard method
to use.
As this feature matures, you should ensure tokens are bound to a Role
Based Access Control (RBAC) policy which limits requests (using the
bootstrap token) strictly to client requests related to certi�cate
provisioning. With RBAC in place, scoping the tokens to a group allows for
great �exibility. For example, you could disable a particular bootstrap
group's access when you are done provisioning the nodes.

Bootstrap tokens
Bootstrap tokens are described in detail here. These are tokens that are
stored as secrets in the Kubernetes cluster, and then issued to the
individual kubelet. You can use a single token for an entire cluster, or
issue one per worker node.
The process is two-fold:
2/27/26, 3:33 PM

API Access Control | Kubernetes

171 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

1. Create a Kubernetes secret with the token ID, secret and scope(s).
2. Issue the token to the kubelet
From the kubelet's perspective, one token is like another and has no
special meaning. From the kube-apiserver's perspective, however, the
bootstrap token is special. Due to its type , namespace and name , kubeapiserver recognizes it as a special token, and grants anyone
authenticating with that token special bootstrap rights, notably treating
them as a member of the system:bootstrappers group. This ful�lls a
basic requirement for TLS bootstrapping.
The details for creating the secret are available here.
If you want to use bootstrap tokens, you must enable it on kubeapiserver with the �ag:

--enable-bootstrap-token-auth=true

Token authentication �le
kube-apiserver has the ability to accept tokens as authentication. These
tokens are arbitrary but should represent at least 128 bits of entropy
derived from a secure random number generator (such as /dev/urandom
on most modern Linux systems). There are multiple ways you can
generate a token. For example:

head -c 16 /dev/urandom | od -An -t x | tr -d ' '

This will generate tokens that look like
02b50b05283e98dd0fd71db496ef01e8 .

The token �le should look like the following example, where the �rst
three values can be anything and the quoted group name should be as
depicted:

02b50b05283e98dd0fd71db496ef01e8,kubelet-bootstrap,10001,"system:bootstrappers"

Add the --token-auth-file=FILENAME �ag to the kube-apiserver
command (in your systemd unit �le perhaps) to enable the token �le. See
docs here for further details.

Authorize kubelet to create CSR
Now that the bootstrapping node is authenticated as part of the
system:bootstrappers group, it needs to be authorized to create a
certi�cate signing request (CSR) as well as retrieve it when done.
Fortunately, Kubernetes ships with a ClusterRole with precisely these
(and only these) permissions, system:node-bootstrapper .
To do this, you only need to create a ClusterRoleBinding that binds the
system:bootstrappers group to the cluster role system:nodebootstrapper .

2/27/26, 3:33 PM

API Access Control | Kubernetes

172 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

# enable bootstrapping nodes to create CSR
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: create-csrs-for-bootstrapping
subjects:
- kind: Group
name: system:bootstrappers
apiGroup: rbac.authorization.k8s.io
roleRef:
kind: ClusterRole
name: system:node-bootstrapper
apiGroup: rbac.authorization.k8s.io

kube-controller-manager
con�guration
While the apiserver receives the requests for certi�cates from the kubelet
and authenticates those requests, the controller-manager is responsible
for issuing actual signed certi�cates.
The controller-manager performs this function via a certi�cate-issuing
control loop. This takes the form of a cfssl local signer using assets on
disk. Currently, all certi�cates issued have one year validity and a default
set of key usages.
In order for the controller-manager to sign certi�cates, it needs the
following:
• access to the "Kubernetes CA key and certi�cate" that you created
and distributed
• enabling CSR signing

Access to key and certi�cate
As described earlier, you need to create a Kubernetes CA key and
certi�cate, and distribute it to the control plane nodes. These will be used
by the controller-manager to sign the kubelet certi�cates.
Since these signed certi�cates will, in turn, be used by the kubelet to
authenticate as a regular kubelet to kube-apiserver, it is important that
the CA provided to the controller-manager at this stage also be trusted
by kube-apiserver for authentication. This is provided to kube-apiserver
with the �ag --client-ca-file=FILENAME (for example, --client-cafile=/var/lib/kubernetes/ca.pem ), as described in the kube-apiserver

con�guration section.
To provide the Kubernetes CA key and certi�cate to kube-controllermanager, use the following �ags:

--cluster-signing-cert-file="/etc/path/to/kubernetes/ca/ca.crt"

For example:

--cluster-signing-cert-file="/var/lib/kubernetes/ca.pem" --cluster-signing-key-f

2/27/26, 3:33 PM

API Access Control | Kubernetes

173 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

The validity duration of signed certi�cates can be con�gured with �ag:

--cluster-signing-duration

Approval
In order to approve CSRs, you need to tell the controller-manager that it
is acceptable to approve them. This is done by granting RBAC
permissions to the correct group.
There are two distinct sets of permissions:
• nodeclient : If a node is creating a new certi�cate for a node, then
it does not have a certi�cate yet. It is authenticating using one of the
tokens listed above, and thus is part of the group
system:bootstrappers .
• selfnodeclient : If a node is renewing its certi�cate, then it already
has a certi�cate (by de�nition), which it uses continuously to
authenticate as part of the group system:nodes .
To enable the kubelet to request and receive a new certi�cate, create a
ClusterRoleBinding that binds the group in which the bootstrapping

node is a member system:bootstrappers to the ClusterRole that
grants it permission,
system:certificates.k8s.io:certificatesigningrequests:nodeclient :

# Approve all CSRs for the group "system:bootstrappers"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: auto-approve-csrs-for-group
subjects:
- kind: Group
name: system:bootstrappers
apiGroup: rbac.authorization.k8s.io
roleRef:
kind: ClusterRole
name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
apiGroup: rbac.authorization.k8s.io

To enable the kubelet to renew its own client certi�cate, create a
ClusterRoleBinding that binds the group in which the fully functioning
node is a member system:nodes to the ClusterRole that grants it
permission,
system:certificates.k8s.io:certificatesigningrequests:selfnodecli
ent :

2/27/26, 3:33 PM

API Access Control | Kubernetes

174 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

# Approve renewal CSRs for the group "system:nodes"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: auto-approve-renewals-for-nodes
subjects:
- kind: Group
name: system:nodes
apiGroup: rbac.authorization.k8s.io
roleRef:
kind: ClusterRole
name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
apiGroup: rbac.authorization.k8s.io

The csrapproving controller that ships as part of kube-controllermanager and is enabled by default. The controller uses the
SubjectAccessReview API to determine if a given user is authorized to
request a CSR, then approves based on the authorization outcome. To
prevent con�icts with other approvers, the built-in approver doesn't
explicitly deny CSRs. It only ignores unauthorized requests. The controller
also prunes expired certi�cates as part of garbage collection.

kubelet con�guration
Finally, with the control plane nodes properly set up and all of the
necessary authentication and authorization in place, we can con�gure
the kubelet.
The kubelet requires the following con�guration to bootstrap:
• A path to store the key and certi�cate it generates (optional, can use
default)
• A path to a kubeconfig �le that does not yet exist; it will place the
bootstrapped con�g �le here
• A path to a bootstrap kubeconfig �le to provide the URL for the
server and bootstrap credentials, e.g. a bootstrap token
• Optional: instructions to rotate certi�cates
The bootstrap kubeconfig should be in a path available to the kubelet,
for example /var/lib/kubelet/bootstrap-kubeconfig .
Its format is identical to a normal kubeconfig �le. A sample �le might
look as follows:

2/27/26, 3:33 PM

API Access Control | Kubernetes

175 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: v1
kind: Config
clusters:
- cluster:
certificate-authority: /var/lib/kubernetes/ca.pem
server: https://my.server.example.com:6443
name: bootstrap
contexts:
- context:
cluster: bootstrap
user: kubelet-bootstrap
name: bootstrap
current-context: bootstrap
preferences: {}
users:
- name: kubelet-bootstrap
user:
token: 07401b.f395accd246ae52d

The important elements to note are:
• certificate-authority : path to a CA �le, used to validate the
server certi�cate presented by kube-apiserver
• server : URL to kube-apiserver
• token : the token to use
The format of the token does not matter, as long as it matches what
kube-apiserver expects. In the above example, we used a bootstrap
token. As stated earlier, any valid authentication method can be used, not
only tokens.
Because the bootstrap kubeconfig is a standard kubeconfig , you can
use kubectl to generate it. To create the above example �le:
kubectl config --kubeconfig=/var/lib/kubelet/bootstrap-kubeconfig set-cluster bo
kubectl config --kubeconfig=/var/lib/kubelet/bootstrap-kubeconfig set-credential
kubectl config --kubeconfig=/var/lib/kubelet/bootstrap-kubeconfig set-context bo
kubectl config --kubeconfig=/var/lib/kubelet/bootstrap-kubeconfig use-context bo

To indicate to the kubelet to use the bootstrap kubeconfig , use the
following kubelet �ag:
--bootstrap-kubeconfig="/var/lib/kubelet/bootstrap-kubeconfig" --kubeconfig="/va

When starting the kubelet, if the �le speci�ed via --kubeconfig does not
exist, the bootstrap kubecon�g speci�ed via --bootstrap-kubeconfig is
used to request a client certi�cate from the API server. On approval of
the certi�cate request and receipt back by the kubelet, a kubecon�g �le
referencing the generated key and obtained certi�cate is written to the
path speci�ed by --kubeconfig . The certi�cate and key �le will be placed
in the directory speci�ed by --cert-dir .

Client and serving certi�cates
All of the above relate to kubelet client certi�cates, speci�cally, the
certi�cates a kubelet uses to authenticate to kube-apiserver.
A kubelet also can use serving certi�cates. The kubelet itself exposes an
https endpoint for certain features. To secure these, the kubelet can do
one of:

2/27/26, 3:33 PM

API Access Control | Kubernetes

176 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• use provided key and certi�cate, via the --tls-private-key-file
and --tls-cert-file �ags
• create self-signed key and certi�cate, if a key and certi�cate are not
provided
• request serving certi�cates from the cluster server, via the CSR API
The client certi�cate provided by TLS bootstrapping is signed, by default,
for client auth only, and thus cannot be used as serving certi�cates, or
server auth .

However, you can enable its server certi�cate, at least partially, via
certi�cate rotation.

Certi�cate rotation
Kubernetes v1.8 and higher kubelet implements features for enabling
rotation of its client and/or serving certi�cates. Note, rotation of serving
certi�cate is a
feature and requires the
RotateKubeletServerCertificate feature �ag on the kubelet (enabled
by default).
You can con�gure the kubelet to rotate its client certi�cates by creating
new CSRs as its existing credentials expire. To enable this feature, use the
rotateCertificates �eld of kubelet con�guration �le or pass the

following command line argument to the kubelet (deprecated):
--rotate-certificates

Enabling RotateKubeletServerCertificate causes the kubelet

to

request a serving certi�cate after bootstrapping its client credentials
to rotate that certi�cate. To enable this behavior, use the �eld
serverTLSBootstrap of the kubelet con�guration �le or pass the
following command line argument to the kubelet (deprecated):
--rotate-server-certificates

The CSR approving controllers implemented in core Kubernetes do
not approve node serving certi�cates for security reasons. To use
RotateKubeletServerCertificate operators need to run a custom
approving controller, or manually approve the serving certi�cate
requests.
A deployment-speci�c approval process for kubelet serving
certi�cates should typically only approve CSRs which:
1. are requested by nodes (ensure the spec.username �eld is of
the form system:node:<nodeName> and spec.groups
contains system:nodes )
2. request usages for a serving certi�cate (ensure spec.usages
contains server auth , optionally contains digital
signature and key encipherment , and contains no other

usages)
3. only have IP and DNS subjectAltNames that belong to the
requesting node, and have no URI and Email subjectAltNames
(parse the x509 Certi�cate Signing Request in spec.request
to verify subjectAltNames )

2/27/26, 3:33 PM

API Access Control | Kubernetes

177 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Other authenticating components
All of TLS bootstrapping described in this document relates to the
kubelet. However, other components may need to communicate directly
with kube-apiserver. Notable is kube-proxy, which is part of the
Kubernetes node components and runs on every node, but may also
include other components such as monitoring or networking.
Like the kubelet, these other components also require a method of
authenticating to kube-apiserver. You have several options for generating
these credentials:
• The old way: Create and distribute certi�cates the same way you did
for kubelet before TLS bootstrapping
• DaemonSet: Since the kubelet itself is loaded on each node, and is
su�cient to start base services, you can run kube-proxy and other
node-speci�c services not as a standalone process, but rather as a
daemonset in the kube-system namespace. Since it will be incluster, you can give it a proper service account with appropriate
permissions to perform its activities. This may be the simplest way
to con�gure such services.

kubectl approval
CSRs can be approved outside of the approval �ows built into the
controller manager.
The signing controller does not immediately sign all certi�cate requests.
Instead, it waits until they have been �agged with an "Approved" status
by an appropriately-privileged user. This �ow is intended to allow for
automated approval handled by an external approval controller or the
approval controller implemented in the core controller-manager.
However cluster administrators can also manually approve certi�cate
requests using kubectl. An administrator can list CSRs with kubectl get
csr and describe one in detail with kubectl describe csr <name> . An

administrator can approve or deny a CSR with kubectl certificate
approve <name> and kubectl certificate deny <name> .

2/27/26, 3:33 PM

API Access Control | Kubernetes

178 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Kubernetes v1.34 [beta]

ⓘ

This page provides an overview of MutatingAdmissionPolicies.
MutatingAdmissionPolicies allow you to change what happens when
someone writes a change to the Kubernetes API. If you want to use
declarative policies just to prevent a particular kind of change to
resources (for example: protecting platform namespaces from deletion),
ValidatingAdmissionPolicy is a simpler and more e�ective alternative.
To use the feature, enable the MutatingAdmissionPolicy feature gate
(which is o� by default) and set --runtimeconfig=admissionregistration.k8s.io/v1beta1=true on the kube-

apiserver.

What are
MutatingAdmissionPolicies?
Mutating admission policies o�er a declarative, in-process alternative to
mutating admission webhooks.
Mutating admission policies use the Common Expression Language (CEL)
to declare mutations to resources. Mutations can be de�ned either with
an apply con�guration that is merged using the server side apply merge
strategy, or a JSON patch.
Mutating admission policies are highly con�gurable, enabling policy
authors to de�ne policies that can be parameterized and scoped to
resources as needed by cluster administrators.

What resources make a policy
A policy is generally made up of three resources:
• The MutatingAdmissionPolicy describes the abstract logic of a policy
(think: "this policy sets a particular label to a particular value").
• A parameter resource provides information to a
MutatingAdmissionPolicy to make it a concrete statement (think
"set the owner label to something like company.example.com ").
Parameter resources refer to Kubernetes resources, available in the
Kubernetes API. They can be built-in types or extensions, such as a
CustomResourceDe�nition (CRD). For example, you can use a
Con�gMap as a parameter.
• A MutatingAdmissionPolicyBinding links the above
(MutatingAdmissionPolicy and parameter) resources together and
provides scoping. If you only want to set an owner label for Pods ,
and not other API kinds, the binding is where you specify this
mutation.
At least a MutatingAdmissionPolicy and a corresponding
MutatingAdmissionPolicyBinding must be de�ned for a policy to have an
e�ect.
If a MutatingAdmissionPolicy does not need to be con�gured via

2/27/26, 3:33 PM

API Access Control | Kubernetes

179 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

parameters, simply leave spec.paramKind in MutatingAdmissionPolicy
not speci�ed.

Getting Started with
MutatingAdmissionPolicies
Mutating admission policy is part of the cluster control-plane. You should
write and deploy them with great caution. The following describes how to
quickly experiment with Mutating admission policy.

Create a MutatingAdmissionPolicy
The following is an example of a MutatingAdmissionPolicy. This policy
mutates newly created Pods to have a sidecar container if it does not
exist.

mutatingadmissionpolicy/applyconfiguration-example.yaml
apiVersion: admissionregistration.k8s.io/v1beta1
kind: MutatingAdmissionPolicy
metadata:
name: "sidecar-policy.example.com"
spec:
paramKind:
kind: Sidecar
apiVersion: mutations.example.com/v1
matchConstraints:
resourceRules:
- apiGroups:

[""]

apiVersions: ["v1"]
operations:

["CREATE"]

resources:

["pods"]

matchConditions:
- name: does-not-already-have-sidecar
expression: "!object.spec.initContainers.exists(ic, ic.name == \"mesh-prox
failurePolicy: Fail
reinvocationPolicy: IfNeeded
mutations:
- patchType: "ApplyConfiguration"
applyConfiguration:
expression: >
Object{
spec: Object.spec{
initContainers: [
Object.spec.initContainers{
name: "mesh-proxy",
image: "mesh/proxy:v1.0.0",
args: ["proxy", "sidecar"],
restartPolicy: "Always"
}
]
}
}

The .spec.mutations �eld consists of a list of expressions that evaluate
to resource patches. The emitted patches may be either apply
con�gurations or JSON Patch patches. You cannot specify an empty list of
mutations. After evaluating all the expressions, the API server applies
those changes to the resource that is passing through admission.
To con�gure a mutating admission policy for use in a cluster, a binding is
2/27/26, 3:33 PM

API Access Control | Kubernetes

180 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

required. The MutatingAdmissionPolicy will only be active if a
corresponding binding exists with the referenced spec.policyName
matching the spec.name of a policy.
Once the binding and policy are created, any resource request that
matches the spec.matchConditions of a policy will trigger the set of
mutations de�ned.
In the example above, creating a Pod will add the mesh-proxy
initContainer mutation:

apiVersion: v1
kind: Pod
metadata:
name: myapp
namespace: default
spec:
...
initContainers:
- name: mesh-proxy
image: mesh/proxy:v1.0.0
args: ["proxy", "sidecar"]
restartPolicy: Always
- name: myapp-initializer
image: example/initializer:v1.0.0
...

Parameter resources
Parameter resources allow a policy con�guration to be separate from its
de�nition. A policy can de�ne paramKind , which outlines GVK of the
parameter resource, and then a policy binding ties a policy by name (via
policyName ) to a particular parameter resource via paramRef .
Please refer to parameter resources for more information.

ApplyConfiguration
MutatingAdmissionPolicy expressions are always CEL. Each apply
con�guration expression must evaluate to a CEL object (declared using
Object() initialization).

Apply con�gurations may not modify atomic structs, maps or arrays due
to the risk of accidental deletion of values not included in the apply
con�guration.
CEL expressions have access to the object types needed to create apply
con�gurations:
• Object - CEL type of the resource object.
• Object.<fieldName> - CEL type of object �eld (such as
Object.spec )

• Object.<fieldName1>.<fieldName2>...<fieldNameN> - CEL type of
nested �eld (such as Object.spec.containers )
CEL expressions have access to the contents of the API request,
organized into CEL variables as well as some other useful variables:
• object - The object from the incoming request. The value is null for
DELETE requests.
• oldObject - The existing object. The value is null for CREATE
requests.

2/27/26, 3:33 PM

API Access Control | Kubernetes

181 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• request - Attributes of the API request.
• params - Parameter resource referred to by the policy binding
being evaluated. Only populated if the policy has a ParamKind.
• namespaceObject - The namespace object that the incoming object
belongs to. The value is null for cluster-scoped resources.
• variables - Map of composited variables, from its name to its lazily
evaluated value. For example, a variable named foo can be
accessed as variables.foo .
• authorizer - A CEL Authorizer. May be used to perform
authorization checks for the principal (user or service account) of
the request. See https://pkg.go.dev/k8s.io/apiserver/pkg/cel/
library#Authz
• authorizer.requestResource - A CEL ResourceCheck constructed
from the authorizer and con�gured with the request resource.
The apiVersion , kind , metadata.name , metadata.generateName and
metadata.labels are always accessible from the root of the

object. No other metadata properties are accessible.

JSONPatch
The same mutation can be written as a JSON Patch as follows:

mutatingadmissionpolicy/json-patch-example.yaml
apiVersion: admissionregistration.k8s.io/v1beta1
kind: MutatingAdmissionPolicy
metadata:
name: "sidecar-policy.example.com"
spec:
paramKind:
kind: Sidecar
apiVersion: mutations.example.com/v1
matchConstraints:
resourceRules:
- apiGroups:

[""]

apiVersions: ["v1"]
operations:

["CREATE"]

resources:

["pods"]

matchConditions:
- name: does-not-already-have-sidecar
expression: "!object.spec.initContainers.exists(ic, ic.name == \"mesh-prox
failurePolicy: Fail
reinvocationPolicy: IfNeeded
mutations:
- patchType: "JSONPatch"
jsonPatch:
expression: >
[
JSONPatch{
op: "add", path: "/spec/initContainers/-",
value: Object.spec.initContainers{
name: "mesh-proxy",
image: "mesh-proxy/v1.0.0",
restartPolicy: "Always"
}
}
]

The expression will be evaluated by CEL to create a JSON patch. ref:
https://github.com/google/cel-spec

2/27/26, 3:33 PM

API Access Control | Kubernetes

182 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Each evaluated expression must return an array of JSONPatch values.
The
JSONPatch type represents one operation from a JSON patch.

For example, this CEL expression returns a JSON patch to conditionally
modify a value:
[
JSONPatch{op: "test", path: "/spec/example", value: "Red"},
JSONPatch{op: "replace", path: "/spec/example", value: "Green"}
]

To de�ne a JSON object for the patch operation value , use CEL Object
types. For example:
[
JSONPatch{
op: "add",
path: "/spec/selector",
value: Object.spec.selector{matchLabels: {"environment": "test"}}
}
]

To use strings containing '/' and '~' as JSONPatch path keys, use
jsonpatch.escapeKey() . For example:
[
JSONPatch{
op: "add",
path: "/metadata/labels/" + jsonpatch.escapeKey("example.com/environment")
value: "test"
},
]

CEL expressions have access to the types needed to create JSON patches
and objects:
• JSONPatch - CEL type of JSON Patch operations. JSONPatch has the
�elds op , from , path and value . See JSON patch for more
details. The value �eld may be set to any of: string, integer, array,
map or object. If set, the path and from �elds must be set to a
JSON pointer string, where the jsonpatch.escapeKey() CEL
function may be used to escape path keys containing / and ~ .
• Object - CEL type of the resource object.
• Object.<fieldName> - CEL type of object �eld (such as
Object.spec )

• Object.<fieldName1>.<fieldName2>...<fieldNameN> - CEL type of
nested �eld (such as Object.spec.containers )
CEL expressions have access to the contents of the API request,
organized into CEL variables as well as some other useful variables:
• object - The object from the incoming request. The value is null for
DELETE requests.
• oldObject - The existing object. The value is null for CREATE
requests.
• request - Attributes of the API request.
• params - Parameter resource referred to by the policy binding
being evaluated. Only populated if the policy has a ParamKind.
• namespaceObject - The namespace object that the incoming object
belongs to. The value is null for cluster-scoped resources.

2/27/26, 3:33 PM

API Access Control | Kubernetes

183 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• variables - Map of composited variables, from its name to its lazily
evaluated value. For example, a variable named foo can be
accessed as variables.foo .
• authorizer - A CEL Authorizer. May be used to perform
authorization checks for the principal (user or service account) of
the request. See https://pkg.go.dev/k8s.io/apiserver/pkg/cel/
library#Authz
• authorizer.requestResource - A CEL ResourceCheck constructed
from the authorizer and con�gured with the request resource.
CEL expressions have access to Kubernetes CEL function libraries as well
as:
• jsonpatch.escapeKey - Performs JSONPatch key escaping. ~ and
/ are escaped as ~0 and ~1 respectively.

Only property names of the form [a-zA-Z_.-/][a-zA-Z0-9_.-/]* are
accessible.

API kinds exempt from mutating
admission
There are certain API kinds that are exempt from admission-time
mutation. For example, you can't create a MutatingAdmissionPolicy that
changes a MutatingAdmissionPolicy.
The list of exempt API kinds is:
• ValidatingAdmissionPolicies
• ValidatingAdmissionPolicyBindings
• MutatingAdmissionPolicies
• MutatingAdmissionPolicyBindings
• TokenReviews
• LocalSubjectAccessReviews
• SelfSubjectAccessReviews
• SelfSubjectReviews

2/27/26, 3:33 PM

API Access Control | Kubernetes

184 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Kubernetes v1.30 [stable]

ⓘ

This page provides an overview of Validating Admission Policy.

What is Validating Admission Policy?
Validating admission policies o�er a declarative, in-process alternative to
validating admission webhooks.
Validating admission policies use the Common Expression Language
(CEL) to declare the validation rules of a policy. Validation admission
policies are highly con�gurable, enabling policy authors to de�ne policies
that can be parameterized and scoped to resources as needed by cluster
administrators.

What Resources Make a Policy
A policy is generally made up of three resources:
• The ValidatingAdmissionPolicy describes the abstract logic of a
policy (think: "this policy makes sure a particular label is set to a
particular value").
• A parameter resource provides information to a
ValidatingAdmissionPolicy to make it a concrete statement (think
"the owner label must be set to something that ends in
.company.com "). A native type such as Con�gMap or a CRD de�nes

the schema of a parameter resource. ValidatingAdmissionPolicy
objects specify what Kind they are expecting for their parameter
resource.
• A ValidatingAdmissionPolicyBinding links the above resources
together and provides scoping. If you only want to require an
owner label to be set for Pods , the binding is where you would
specify this restriction.
At least a ValidatingAdmissionPolicy and a corresponding
ValidatingAdmissionPolicyBinding must be de�ned for a policy to have

an e�ect.
If a ValidatingAdmissionPolicy does not need to be con�gured via
parameters, simply leave spec.paramKind in
ValidatingAdmissionPolicy not speci�ed.

Getting Started with Validating
Admission Policy
Validating Admission Policy is part of the cluster control-plane. You
should write and deploy them with great caution. The following describes
how to quickly experiment with Validating Admission Policy.

2/27/26, 3:33 PM

API Access Control | Kubernetes

185 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Creating a ValidatingAdmissionPolicy
The following is an example of a ValidatingAdmissionPolicy.

validatingadmissionpolicy/basic-example-policy.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
name: "demo-policy.example.com"
spec:
failurePolicy: Fail
matchConstraints:
resourceRules:
- apiGroups:

["apps"]

apiVersions: ["v1"]
operations:

["CREATE", "UPDATE"]

resources:

["deployments"]

validations:
- expression: "object.spec.replicas <= 5"

spec.validations contains CEL expressions which use the Common

Expression Language (CEL) to validate the request. If an expression
evaluates to false, the validation check is enforced according to the
spec.failurePolicy �eld.

You can quickly test CEL expressions in CEL Playground.

To con�gure a validating admission policy for use in a cluster, a binding is
required. The following is an example of a
ValidatingAdmissionPolicyBinding.:

validatingadmissionpolicy/basic-example-binding.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
name: "demo-binding-test.example.com"
spec:
policyName: "demo-policy.example.com"
validationActions: [Deny]
matchResources:
namespaceSelector:
matchLabels:
environment: test

When trying to create a deployment with replicas set not satisfying the
validation expression, an error will return containing message:
ValidatingAdmissionPolicy 'demo-policy.example.com' with binding 'demo-binding-t

The above provides a simple example of using ValidatingAdmissionPolicy
without a parameter con�gured.

Validation actions
Each ValidatingAdmissionPolicyBinding must specify one or more

2/27/26, 3:33 PM

API Access Control | Kubernetes

186 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

validationActions to declare how validations of a policy are

enforced.
The supported validationActions are:
• Deny : Validation failure results in a denied request.
• Warn : Validation failure is reported to the request client as a
warning.
• Audit : Validation failure is included in the audit event for the API
request.
For example, to both warn clients about a validation failure and to audit
the validation failures, use:

validationActions: [Warn, Audit]

Deny and Warn may not be used together since this combination

needlessly duplicates the validation failure both in the API response body
and the HTTP warning headers.
A validation that evaluates to false is always enforced according to
these actions. Failures de�ned by the failurePolicy are enforced
according to these actions only if the failurePolicy is set to Fail (or
not speci�ed), otherwise the failures are ignored.
See Audit Annotations: validation failures for more details about the
validation failure audit annotation.

Parameter resources
Parameter resources allow a policy con�guration to be separate from its
de�nition. A policy can de�ne paramKind, which outlines GVK of the
parameter resource, and then a policy binding ties a policy by name (via
policyName) to a particular parameter resource via paramRef.
If parameter con�guration is needed, the following is an example of a
ValidatingAdmissionPolicy with parameter con�guration.

validatingadmissionpolicy/policy-with-param.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
name: "replicalimit-policy.example.com"
spec:
failurePolicy: Fail
paramKind:
apiVersion: rules.example.com/v1
kind: ReplicaLimit
matchConstraints:
resourceRules:
- apiGroups:

["apps"]

apiVersions: ["v1"]
operations:

["CREATE", "UPDATE"]

resources:

["deployments"]

validations:
- expression: "object.spec.replicas <= params.maxReplicas"
reason: Invalid

The spec.paramKind �eld of the ValidatingAdmissionPolicy speci�es the

2/27/26, 3:33 PM

API Access Control | Kubernetes

187 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

kind of resources used to parameterize this policy. For this example, it is
con�gured by ReplicaLimit custom resources. Note in this example how
the CEL expression references the parameters via the CEL params
variable, e.g. params.maxReplicas . spec.matchConstraints speci�es
what resources this policy is designed to validate. Note that the native
types such like ConfigMap could also be used as parameter reference.
The spec.validations �elds contain CEL expressions. If an expression
evaluates to false, the validation check is enforced according to the
spec.failurePolicy �eld.

The validating admission policy author is responsible for providing the
ReplicaLimit parameter CRD.
To con�gure an validating admission policy for use in a cluster, a binding
and parameter resource are created. The following is an example of a
param - the
ValidatingAdmissionPolicyBinding that uses a
same param will be used to validate every resource request that matches
the binding:

validatingadmissionpolicy/binding-with-param.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
name: "replicalimit-binding-test.example.com"
spec:
policyName: "replicalimit-policy.example.com"
validationActions: [Deny]
paramRef:
name: "replica-limit-test.example.com"
namespace: "default"
parameterNotFoundAction: Deny
matchResources:
namespaceSelector:
matchLabels:
environment: test

Notice this binding applies a parameter to the policy for all resources
which are in the test environment.
The parameter resource could be as following:

validatingadmissionpolicy/replicalimit-param.yaml
apiVersion: rules.example.com/v1
kind: ReplicaLimit
metadata:
name: "replica-limit-test.example.com"
namespace: "default"
maxReplicas: 3

This policy parameter resource limits deployments to a max of 3 replicas.
An admission policy may have multiple bindings. To bind all other
environments to have a maxReplicas limit of 100, create another
ValidatingAdmissionPolicyBinding:

validatingadmissionpolicy/binding-with-param-prod.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

188 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
name: "replicalimit-binding-nontest"
spec:
policyName: "replicalimit-policy.example.com"
validationActions: [Deny]
paramRef:
name: "replica-limit-prod.example.com"
namespace: "default"
parameterNotFoundAction: Deny
matchResources:
namespaceSelector:
matchExpressions:
- key: environment
operator: NotIn
values:
- test

Notice this binding applies a di�erent parameter to resources which are
not in the test environment.
And have a parameter resource:

validatingadmissionpolicy/replicalimit-param-prod.yaml
apiVersion: rules.example.com/v1
kind: ReplicaLimit
metadata:
name: "replica-limit-prod.example.com"
maxReplicas: 100

For each admission request, the API server evaluates CEL expressions of
each (policy, binding, param) combination that match the request. For a
request to be admitted it must pass
evaluations.
If multiple bindings match the request, the policy will be evaluated for
each, and they must all pass evaluation for the policy to be considered
passed.
If multiple parameters match a single binding, the policy rules will be
evaluated for each param, and they too must all pass for the binding to
be considered passed. Bindings can have overlapping match criteria. The
policy is evaluated for each matching binding-parameter combination. A
policy may even be evaluated multiple times if multiple bindings match it,
or a single binding that matches multiple parameters.
The params object representing a parameter resource will not be set if a
parameter resource has not been bound, so for policies requiring a
parameter resource, it can be useful to add a check to ensure one has
been bound. A parameter resource will not be bound and params will be
null if paramKind of the policy, or paramRef of the binding are not
speci�ed.
For the use cases requiring parameter con�guration, we recommend to
add a param check in spec.validations[0].expression :
- expression: "params != null"
message: "params missing but required to bind to this policy"

2/27/26, 3:33 PM

API Access Control | Kubernetes

189 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

Optional parameters
It can be convenient to be able to have optional parameters as part of a
parameter resource, and only validate them if present. CEL provides
has() , which checks if the key passed to it exists. CEL also implements
Boolean short-circuiting. If the �rst half of a logical OR evaluates to true,
it won’t evaluate the other half (since the result of the entire OR will be
true regardless).
Combining the two, we can provide a way to validate optional
parameters:
!has(params.optionalNumber) || (params.optionalNumber >= 5 &&
params.optionalNumber <= 10)

Here, we �rst check that the optional parameter is present with !
has(params.optionalNumber) .

• If optionalNumber hasn’t been de�ned, then the expression shortcircuits since !has(params.optionalNumber) will evaluate to true.
• If optionalNumber has been de�ned, then the latter half of the CEL
expression will be evaluated, and optionalNumber will be checked
to ensure that it contains a value between 5 and 10 inclusive.

Per-namespace Parameters
As the author of a ValidatingAdmissionPolicy and its
ValidatingAdmissionPolicyBinding, you can choose to specify clusterwide, or per-namespace parameters. If you specify a namespace for the
binding's paramRef , the control plane only searches for parameters in
that namespace.
However, if namespace is not speci�ed in the
ValidatingAdmissionPolicyBinding, the API server can search for relevant
parameters in the namespace that a request is against. For example, if
you make a request to modify a Con�gMap in the default namespace
and there is a relevant ValidatingAdmissionPolicyBinding with no
namespace set, then the API server looks for a parameter object in
default . This design enables policy con�guration that depends on the

namespace of the resource being manipulated, for more �ne-tuned
control.

Parameter selector
In addition to specify a parameter in a binding by name , you may choose
instead to specify label selector, such that all resources of the policy's
paramKind , and the param's namespace (if applicable) that match the

label selector are selected for evaluation. See selector for more
information on how label selectors match resources.
If multiple parameters are found to meet the condition, the policy's rules
are evaluated for each parameter found and the results will be ANDed
together.
If namespace is provided, only objects of the paramKind in the provided
namespace are eligible for selection. Otherwise, when namespace is
empty and paramKind is namespace-scoped, the namespace used in the
request being admitted will be used.

Authorization checks
We introduced the authorization check for parameter resources. User is

2/27/26, 3:33 PM

API Access Control | Kubernetes

190 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

expected to have read access to the resources referenced by
paramKind in ValidatingAdmissionPolicy and paramRef in
ValidatingAdmissionPolicyBinding .

Note that if a resource in paramKind fails resolving via the restmapper,
read access to all resources of groups is required.

paramRef
The paramRef �eld speci�es the parameter resource used by the policy.
It has the following �elds:
: The name of the parameter resource.

•

: The namespace of the parameter resource.

•

: A label selector to match multiple parameter resources.

•
•

: (Required) Controls the behavior
when the speci�ed parameters are not found.
◦

:
▪ Allow: The absence of matched parameters is treated as
a successful validation by the binding.
▪ Deny: The absence of matched parameters is subject to
the failurePolicy of the policy.

One of name or selector must be set, but not both.

The parameterNotFoundAction �eld in paramRef is

. It

speci�es the action to take when no parameters are found
matching the paramRef . If not speci�ed, the policy binding may be
considered invalid and will be ignored or could lead to unexpected
behavior.
• Allow: If set to Allow , and no parameters are found, the
binding treats the absence of parameters as a successful
validation, and the policy is considered to have passed.
• Deny: If set to Deny , and no parameters are found, the
binding enforces the failurePolicy of the policy. If the
failurePolicy is Fail , the request is rejected.

Make sure to set parameterNotFoundAction according to the
desired behavior when parameters are missing.

Handling Missing Parameters with parameterNotFoundAction
When using paramRef with a selector, it's possible that no parameters
match the selector. The parameterNotFoundAction �eld determines how
the binding behaves in this scenario.

2/27/26, 3:33 PM

API Access Control | Kubernetes

191 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1alpha1
kind: ValidatingAdmissionPolicyBinding
metadata:
name: example-binding
spec:
policyName: example-policy
paramRef:
selector:
matchLabels:
environment: test
parameterNotFoundAction: Allow
validationActions:
- Deny

Failure Policy
failurePolicy de�nes how mis-con�gurations and CEL expressions

evaluating to error from the admission policy are handled. Allowed
values are Ignore or Fail .
• Ignore means that an error calling the ValidatingAdmissionPolicy is
ignored and the API request is allowed to continue.
• Fail means that an error calling the ValidatingAdmissionPolicy
causes the admission to fail and the API request to be rejected.
Note that the failurePolicy is de�ned inside
ValidatingAdmissionPolicy :

validatingadmissionpolicy/failure-policy-ignore.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
spec:
...
failurePolicy: Ignore # The default is "Fail"
validations:
- expression: "object.spec.xyz == params.x"

Validation Expression
spec.validations[i].expression represents the expression which will

be evaluated by CEL. To learn more, see the CEL language speci�cation
CEL expressions have access to the contents of the Admission request/
response, organized into CEL variables as well as some other useful
variables:
• 'object' - The object from the incoming request. The value is null for
DELETE requests.
• 'oldObject' - The existing object. The value is null for CREATE
requests.
• 'request' - Attributes of the admission request.
• 'params' - Parameter resource referred to by the policy binding
being evaluated. The value is null if ParamKind is not speci�ed.
• namespaceObject - The namespace, as a Kubernetes resource, that
the incoming object belongs to. The value is null if the incoming
object is cluster-scoped.
• authorizer - A CEL Authorizer. May be used to perform
authorization checks for the principal (authenticated user) of the
request. See AuthzSelectors and Authz in the Kubernetes CEL

2/27/26, 3:33 PM

API Access Control | Kubernetes

192 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

library documentation for more details.
• authorizer.requestResource - A shortcut for an authorization
check con�gured with the request resource (group, resource,
(subresource), namespace, name).
In CEL expressions, variables like object and oldObject are stronglytyped. You can access any �eld in the object's schema, such as
object.metadata.labels and �elds in spec .
For any Kubernetes object, including schemaless Custom Resources, CEL
guarantees access to a minimal set of properties: apiVersion , kind ,
metadata.name , and metadata.generateName .

Equality on arrays with list type of 'set' or 'map' ignores element order,
i.e. [1, 2] == [2, 1]. Concatenation on arrays with x-kubernetes-list-type
use the semantics of the list type:
• 'set': X + Y performs a union where the array positions of all
elements in X are preserved and non-intersecting elements in Y
are appended, retaining their partial order.
• 'map': X + Y performs a merge where the array positions of all
keys in X are preserved but the values are overwritten by values in
Y when the key sets of X and Y intersect. Elements in Y with

non-intersecting keys are appended, retaining their partial order.

Validation expression examples

object.minReplicas <= object.replicas &&
object.replicas <= object.maxReplicas

Validate that the
three �elds de�ning
replicas are
ordered
appropriately

'Available' in object.stateCounts

Validate that an
entry with the
'Available' key
exists in a map

(size(object.list1) == 0) != (size(object.list2)

Validate that one of
two lists is nonempty, but not both

== 0)

!('MY_KEY' in object.map1) ||
object['MY_KEY'].matches('^[a-zA-Z]*$')

object.envars.filter(e, e.name ==
'MY_ENV').all(e, e.value.matches('^[a-zA-Z]*$')

has(object.expired) && object.created +
object.ttl < object.expired

Validate the value
of a map for a
speci�c key, if it is
in the map
Validate the 'value'
�eld of a listMap
entry where key
�eld 'name' is
'MY_ENV'
Validate that
'expired' date is
after a 'create' date
plus a 'ttl' duration

2/27/26, 3:33 PM

API Access Control | Kubernetes

193 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

object.health.startsWith('ok')

Validate a 'health'
string �eld has the
pre�x 'ok'

object.widgets.exists(w, w.key == 'x' && w.foo <

Validate that the
'foo' property of a
listMap item with a
key 'x' is less than
10

10)

type(object) == string ? object == '100%' :
object == 1000

Validate an int-orstring �eld for both
the int and string
cases

object.metadata.name.startsWith(object.prefix)

Validate that an
object's name has
the pre�x of
another �eld value

object.set1.all(e, !(e in object.set2))

Validate that two
listSets are disjoint

size(object.names) == size(object.details) &&

Validate the 'details'
map is keyed by the
items in the 'names'
listSet

object.names.all(n, n in object.details)

size(object.clusters.filter(c, c.name ==
object.primary)) == 1

Validate that the
'primary' property
has one and only
one occurrence in
the 'clusters'
listMap

Read Supported evaluation on CEL for more information about CEL rules.
spec.validation[i].reason represents a machine-readable description

of why this validation failed. If this is the �rst validation in the list to fail,
this reason, as well as the corresponding HTTP response code, are used
in the HTTP response to the client. The currently supported reasons are:
Unauthorized , Forbidden , Invalid , RequestEntityTooLarge . If not set,
StatusReasonInvalid is used in the response to the client.

Matching requests: matchConditions
You can de�ne match conditions for a ValidatingAdmissionPolicy if you
need �ne-grained request �ltering. These conditions are useful if you �nd
that match rules, objectSelectors and namespaceSelectors still doesn't
provide the �ltering you want. Match conditions are CEL expressions. All
match conditions must evaluate to true for the resource to be evaluated.
Here is an example illustrating a few di�erent uses for match conditions:

access/validating-admission-policy-match-conditions.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

194 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
name: "demo-policy.example.com"
spec:
failurePolicy: Fail
matchConstraints:
resourceRules:
- apiGroups:

["*"]

apiVersions: ["*"]
operations:

["CREATE", "UPDATE"]

resources:

["*"]

matchConditions:
- name: 'exclude-leases' # Each match condition must have a unique name
expression: '!(request.resource.group == "coordination.k8s.io" && request.
- name: 'exclude-kubelet-requests'
expression: '!("system:nodes" in request.userInfo.groups)'
- name: 'rbac' # Skip RBAC requests.
expression: 'request.resource.group != "rbac.authorization.k8s.io"'
validations:
- expression: "!object.metadata.name.contains('demo') || object.metadata.nam

Match conditions have access to the same CEL variables as validation
expressions.
In the event of an error evaluating a match condition the policy is not
evaluated. Whether to reject the request is determined as follows:
1. If

match condition evaluated to false (regardless of other

errors), the API server skips the policy.
2. Otherwise:
◦ for failurePolicy: Fail, reject the request (without
evaluating the policy).
◦ for failurePolicy: Ignore, proceed with the request but skip
the policy.

Audit annotations
auditAnnotations may be used to include audit annotations in the audit

event of the API request.
For example, here is an admission policy with an audit annotation:

access/validating-admission-policy-audit-annotation.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

195 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
name: "demo-policy.example.com"
spec:
failurePolicy: Fail
matchConstraints:
resourceRules:
- apiGroups:

["apps"]

apiVersions: ["v1"]
operations:

["CREATE", "UPDATE"]

resources:

["deployments"]

validations:
- expression: "object.spec.replicas > 50"
messageExpression: "'Deployment spec.replicas set to ' + string(object.spe
auditAnnotations:
- key: "high-replica-count"
valueExpression: "'Deployment spec.replicas set to ' + string(object.spec.

When an API request is validated with this admission policy, the resulting
audit event will look like:
# the audit event recorded
{
"kind": "Event",
"apiVersion": "audit.k8s.io/v1",
"annotations": {
"demo-policy.example.com/high-replica-count": "Deployment spec.replicas
# other annotations
...
}
# other fields
...
}

In this example the annotation will only be included if the spec.replicas
of the Deployment is more than 50, otherwise the CEL expression
evaluates to null and the annotation will not be included.
Note that audit annotation keys are pre�xed by the name of the
ValidatingAdmissionPolicy and a / . If another admission controller,
such as an admission webhook, uses the exact same audit annotation
key, the value of the �rst admission controller to include the audit
annotation will be included in the audit event and all other values will be
ignored.

Message expression
To return a more friendly message when the policy rejects a request, we
can use a CEL expression to composite a message with
spec.validations[i].messageExpression . Similar to the validation
expression, a message expression has access to object , oldObject ,
request , params , and namespaceObject . Unlike validations, message

expression must evaluate to a string.
For example, to better inform the user of the reason of denial when the
policy refers to a parameter, we can have the following validation:

access/deployment-replicas-policy.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

196 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
name: "deploy-replica-policy.example.com"
spec:
paramKind:
apiVersion: rules.example.com/v1
kind: ReplicaLimit
matchConstraints:
resourceRules:
- apiGroups:

["apps"]

apiVersions: ["v1"]
operations:

["CREATE", "UPDATE"]

resources:

["deployments"]

validations:
- expression: "object.spec.replicas <= params.maxReplicas"
messageExpression: "'object.spec.replicas must be no greater than ' + string
reason: Invalid

After creating a params object that limits the replicas to 3 and setting up
the binding, when we try to create a deployment with 5 replicas, we will
receive the following message.
$ kubectl create deploy --image=nginx nginx --replicas=5
error: failed to create deployment: deployments.apps "nginx" is forbidden: Valid

This is more informative than a static message of "too many replicas".
The message expression takes precedence over the static message
de�ned in spec.validations[i].message if both are de�ned. However, if
the message expression fails to evaluate, the static message will be used
instead. Additionally, if the message expression evaluates to a multi-line
string, the evaluation result will be discarded and the static message will
be used if present. Note that static message is validated against multi-line
strings.

Type checking
When a policy de�nition is created or updated, the validation process
parses the expressions it contains and reports any syntax errors,
rejecting the de�nition if any errors are found. Afterward, the referred
variables are checked for type errors, including missing �elds and type
confusion, against the matched types of spec.matchConstraints . The
result of type checking can be retrieved from status.typeChecking . The
presence of status.typeChecking indicates the completion of type
checking, and an empty status.typeChecking means that no errors
were detected.
For example, given the following policy de�nition:

validatingadmissionpolicy/typechecking.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

197 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
name: "deploy-replica-policy.example.com"
spec:
matchConstraints:
resourceRules:
- apiGroups:

["apps"]

apiVersions: ["v1"]
operations:

["CREATE", "UPDATE"]

resources:

["deployments"]

validations:
- expression: "object.replicas > 1" # should be "object.spec.replicas > 1"
message: "must be replicated"
reason: Invalid

The status will yield the following information:

status:
typeChecking:
expressionWarnings:
- fieldRef: spec.validations[0].expression
warning: |apps/v1, Kind=Deployment: ERROR: <input>:1:7: undefined field 'replicas'
| object.replicas > 1
| ......^

If multiple resources are matched in spec.matchConstraints , all of
matched resources will be checked against. For example, the following
policy de�nition

validatingadmissionpolicy/typechecking-multiple-match.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
name: "replica-policy.example.com"
spec:
matchConstraints:
resourceRules:
- apiGroups:

["apps"]

apiVersions: ["v1"]
operations:

["CREATE", "UPDATE"]

resources:

["deployments","replicasets"]

validations:
- expression: "object.replicas > 1" # should be "object.spec.replicas > 1"
message: "must be replicated"
reason: Invalid

will have multiple types and type checking result of each type in the
warning message.

2/27/26, 3:33 PM

API Access Control | Kubernetes

198 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

status:
typeChecking:
expressionWarnings:
- fieldRef: spec.validations[0].expression
warning: |apps/v1, Kind=Deployment: ERROR: <input>:1:7: undefined field 'replicas'
| object.replicas > 1
| ......^
apps/v1, Kind=ReplicaSet: ERROR: <input>:1:7: undefined field 'replicas'
| object.replicas > 1
| ......^

Type Checking has the following limitation:
• No wildcard matching. If spec.matchConstraints.resourceRules
contains "*" in any of apiGroups , apiVersions or resources ,
the types that "*" matches will not be checked.
• The number of matched types is limited to 10. This is to prevent a
policy that manually specifying too many types. to consume
excessive computing resources. In the order of ascending group,
version, and then resource, 11th combination and beyond are
ignored.
• Type Checking does not a�ect the policy behavior in any way. Even
if the type checking detects errors, the policy will continue to
evaluate. If errors do occur during evaluate, the failure policy will
decide its outcome.
• Type Checking does not apply to CRDs, including matched CRD
types and reference of paramKind. The support for CRDs will come
in future release.

Variable composition
If an expression grows too complicated, or part of the expression is
reusable and computationally expensive to evaluate, you can extract
some part of the expressions into variables. A variable is a named
expression that can be referred later in variables in other expressions.

spec:
variables:
- name: foo
expression: "'foo' in object.spec.metadata.labels ? object.spec.metadata.l
validations:
- expression: variables.foo == 'bar'

A variable is lazily evaluated when it is �rst referred. Any error that occurs
during the evaluation will be reported during the evaluation of the
referring expression. Both the result and potential error are memorized
and count only once towards the runtime cost.
The order of variables are important because a variable can refer to
other variables that are de�ned before it. This ordering prevents circular
references.
The following is a more complex example of enforcing that image repo
names match the environment de�ned in its namespace.

access/image-matches-namespace-environment.policy.yaml

2/27/26, 3:33 PM

API Access Control | Kubernetes

199 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

# This policy enforces that all containers of a deployment has the image repo ma
# Except for "exempt" deployments, or any containers that do not belong to the "
# For example, if the namespace has a label of {"environment": "staging"}, all c
# or do not contain "example.com" at all, unless the deployment has {"exempt": "
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
name: "image-matches-namespace-environment.policy.example.com"
spec:
failurePolicy: Fail
matchConstraints:
resourceRules:
- apiGroups:

["apps"]

apiVersions: ["v1"]
operations:

["CREATE", "UPDATE"]

resources:

["deployments"]

variables:
- name: environment
expression: "'environment' in namespaceObject.metadata.labels ? namespaceObj
- name: exempt
expression: "'exempt' in object.metadata.labels && object.metadata.labels['e
- name: containers
expression: "object.spec.template.spec.containers"
- name: containersToCheck
expression: "variables.containers.filter(c, c.image.contains('example.com/')
validations:
- expression: "variables.exempt || variables.containersToCheck.all(c, c.image.
messageExpression: "'only ' + variables.environment + ' images are allowed i

With the policy bound to the namespace default , which is labeled
environment: prod , the following attempt to create a deployment would

be rejected.

kubectl create deploy --image=dev.example.com/nginx invalid

The error message is similar to this.

error: failed to create deployment: deployments.apps "invalid" is forbidden: Val

API kinds exempt from admission
validation
There are certain API kinds that are exempt from admission-time
validation checks. For example, you can't create a
ValidatingAdmissionPolicy that prevents changes to
ValidatingAdmissionPolicyBindings.
The list of exempt API kinds is:
• ValidatingAdmissionPolicies
• ValidatingAdmissionPolicyBindings
• MutatingAdmissionPolicies
• MutatingAdmissionPolicyBindings
• TokenReviews
• LocalSubjectAccessReviews
• SelfSubjectAccessReviews
2/27/26, 3:33 PM

API Access Control | Kubernetes

200 of 200

https://kubernetes.io/docs/reference/access-authn-authz/_print/

• SelfSubjectReviews

2/27/26, 3:33 PM

