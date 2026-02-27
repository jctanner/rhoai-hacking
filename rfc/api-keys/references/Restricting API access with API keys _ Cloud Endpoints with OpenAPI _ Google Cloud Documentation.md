# Restricting API access with API keys _ Cloud Endpoints with OpenAPI _ Google Cloud Documentation

**Source:** `Restricting API access with API keys _ Cloud Endpoints with OpenAPI _ Google Cloud Documentation.pdf`

---

Restricting API access with API keys | Cloud Endpoints wit...

1 of 8

https://docs.cloud.google.com/endpoints/docs/openapi/restri...

| gRPC (/endpoints/docs/grpc/restricting-api-access-with-api-keys)
You can use API keys (/endpoints/docs/openapi/when-why-api-key) to restrict access to speci�c
API methods or all methods in an API. This page describes how to restrict API access to those
clients that have an API key and also shows how to create an API key.
The Extensible Service Proxy (ESP) (/endpoints/docs/openapi/glossary#extensible_service_proxy)
uses Service Control API to validate an API key and its association with a project's enabled
API. If you set an API key requirement in your API, requests to the protected method, class, or
API are rejected unless they have a key generated in your project or within other projects
belonging to developers with whom you have granted access to enable your API
(/endpoints/docs/openapi/control-api-callers). The project that the API key was created in isn't
logged and isn't added to the request header. You can, however, view the Google Cloud project
that a client is associated with in
>
, as described in Filter for a speci�c
consumer project (/endpoints/docs/openapi/monitoring-your-api#�lter_for_a_speci�c_consumer_project)
.
For information on which Google Cloud project an API key should be created in, see Sharing
APIs protected by API key (#sharing_apis_protected_by_api_key).

Restricting access to all API methods
To require an API key for accessing all methods of an API:

(#openapi-2.0)

(#openapi-3.x)

1. Open your project's

�le in a text editor.

2. Under
, add
shown in the sample code snippet:

values

,

,

as

securityDefinitions:
# This section configures basic authentication with an API key.
api_key:

2/27/26, 12:39 PM

Restricting API access with API keys | Cloud Endpoints wit...

2 of 8

https://docs.cloud.google.com/endpoints/docs/openapi/restri...

type: "apiKey"
name: "key"
in: "query"

This establishes a "security scheme" called
, which you can use to protect
the API. For other
de�nition options, refer to Api key de�nition limitations
(/endpoints/docs/openapi/openapi-limitations#api_key_de�nition_limitations).
3. At the top level of the �le (not indented or nested), add
to the
directive. You may need to add the
directive or it may already
be present:

security:
- api_key: []

This directive applies the
security scheme to all methods in the �le. Don't
place anything inside the brackets. The OpenAPI speci�cation requires an empty
list for security schemes that don't use OAuth.

Restricting access to speci�c API methods
To require an API key for a speci�c method:

(#openapi-2.0)

(#openapi-3.x)

1. Open your project's

�le in a text editor.

2. At the top level of the �le (not indented or nested), add an empty security directive
to apply it to the entire API:

security: []

2/27/26, 12:39 PM

Restricting API access with API keys | Cloud Endpoints wit...

3 of 8

3. Under
, add
shown in the sample code snippet:

https://docs.cloud.google.com/endpoints/docs/openapi/restri...

values

,

,

as

securityDefinitions:
# This section configures basic authentication with an API key.
api_key:
type: "apiKey"
name: "key"
in: "query"

This establishes a "security scheme" called
, which you can use to protect
the API. For other
de�nition options, refer to Api key de�nition limitations
(/endpoints/docs/openapi/openapi-limitations#api_key_de�nition_limitations).
4. Add

to the

directive in the method's de�nition:

...
paths:
"∕echo":
post:
description: "Echo back a given message."
operationId: "echo"
security:
- api_key: []
produces:
...

This directive applies the
security scheme to the method. Don't place
anything inside the brackets. The OpenAPI speci�cation requires an empty list for
security schemes which don't use OAuth.

Removing API key restriction for a method
To turn off API key validation for a particular method even when you've restricted API access
for the API:

2/27/26, 12:39 PM

Restricting API access with API keys | Cloud Endpoints wit...

4 of 8

(#openapi-2.0)

(#openapi-3.x)

1. Open your project's
2. Add an empty

https://docs.cloud.google.com/endpoints/docs/openapi/restri...

�le in a text editor.
directive in the method's de�nition:

...
paths:
"∕echo":
post:
description: "Echo back a given message."
operationId: "echo"
security: []
produces:
...

Calling an API using an API key
If an API or API method requires an API key, supply the key using a query parameter named
, as shown in the following curl example:

curl "${ENDPOINTS_HOST}∕echo?key=${ENDPOINTS_KEY}"

where
and
hostname and API key, respectively.

are environment variables containing your API

Sharing APIs protected by API key
API keys are associated with the Google Cloud project in which they have been created. If you
have decided to require an API key for your API, the Google Cloud project that the API key gets
created in depends on the answers to the following questions:

2/27/26, 12:39 PM

Restricting API access with API keys | Cloud Endpoints wit...

5 of 8

https://docs.cloud.google.com/endpoints/docs/openapi/restri...

• Do you need to distinguish between the callers of your API so that you can use Endpoints
features such as quotas (/endpoints/docs/openapi/quotas-overview)?
• Do all the callers of your API have their own Google Cloud projects?
• Do you need to set up different API key restrictions
(/docs/authentication/api-keys#api_key_restrictions)?
You can use the following decision tree as a guide for deciding which Google Cloud project to
create the API key in.

Grant permission to enable the API
When you need to distinguish between callers of your API, and each caller has their own
Google Cloud project, you can grant principals permission to enable the API in their own
Google Cloud project. This way, users of your API can create their own API key for use with
your API.
For example, suppose your team has created an API for internal use by various client programs
in your company, and each client program has their own Google Cloud project. To distinguish
between callers of your API, the API key for each caller must be created in a different Google
Cloud project. You can grant your coworkers permission to enable the API in the Google Cloud
project that the client program is associated with.

2/27/26, 12:39 PM

Restricting API access with API keys | Cloud Endpoints wit...

6 of 8

https://docs.cloud.google.com/endpoints/docs/openapi/restri...

To let users create their own API key:
1. In the Google Cloud project in which your API is con�gured, grant each user the
permission to enable your API (/endpoints/docs/openapi/control-api-callers).
2. Contact the users, and let them know that they can enable your API
(/endpoints/docs/openapi/enable-api) in their own Google Cloud project and create an API
key (/docs/authentication/api-keys#creating_an_api_key).

Create a separate Google Cloud project for each caller
When you need to distinguish between callers of your API, and not all of the callers have
Google Cloud projects, you can create a separate Google Cloud project and API key for each
caller. Before creating the projects, give some thought to the project names so that you can
easily identify the caller associated with the project.
For example, suppose you have external customers of your API, and you have no idea how the
client programs that call your API were created. Perhaps some of the clients use Google Cloud
services and have a Google Cloud project, and perhaps some don't. To distinguish between the
callers, you must create a separate Google Cloud project and API key for each caller.
To create a separate Google Cloud project and API key for each caller:
1. Create a separate project for each caller.
2. In each project, enable your API (/endpoints/docs/openapi/enable-api) and create an API key
(/docs/authentication/api-keys#creating_an_api_key).
3. Give the API key to each caller.

Create an API key for each caller
When you don't need to distinguish between callers of your API, but you want to add API key
restrictions, you can create a separate API key for each caller in the same project.
To create an API key for each caller in the same project:
1. In either the project that your API is con�gured in, or a project that your API is enabled in
(/endpoints/docs/openapi/enable-api), create an API key for each customer that has the API
key restrictions (/docs/authentication/api-keys#api_key_restrictions) that you need.

2/27/26, 12:39 PM

Restricting API access with API keys | Cloud Endpoints wit...

7 of 8

https://docs.cloud.google.com/endpoints/docs/openapi/restri...

2. Give the API key to each caller.

Create one API key for all callers
When you don't need to distinguish between callers of your API, and you don't need to add API
restrictions, but you still want to require an API key (to prevent anonymous access, for
example), you can create one API key for all callers to use.
To create one API key for all callers:
1. In either the project that your API is con�gured in, or a project that your API is enabled in
(/endpoints/docs/openapi/enable-api), create an API key for all callers that has the API key
restrictions (/docs/authentication/api-keys#api_key_restrictions) that you need.
2. Give the same API key to every caller.

Best practices
If you rely on API keys to protect access to your API and user data, make sure that you set the
�ag to
when con�guring the Extensible
Service Proxy V2 (ESPv2) startup options
(/endpoints/docs/openapi/specify-esp-v2-startup-options#timeout). The default value for the �ag is

ESPv2 calls Service Control to verify API keys. If there are network failures when connecting to
Service Control and ESPv2 cannot verify the API key, this results in any potential requests
made to your API with fraudulent keys being rejected.

What's next
• When and why to use API keys (/endpoints/docs/openapi/when-why-api-key)
• Securing an API key (/docs/authentication/api-keys#securing_an_api_key)
Except as otherwise noted, the content of this page is licensed under the Creative Commons Attribution 4.0 License

(https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the Apache 2.0 License
(https://www.apache.org/licenses/LICENSE-2.0). For details, see the Google Developers Site Policies

2/27/26, 12:39 PM

Restricting API access with API keys | Cloud Endpoints wit...

8 of 8

https://docs.cloud.google.com/endpoints/docs/openapi/restri...

(https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its a�liates.
Last updated 2026-02-25 UTC.

2/27/26, 12:39 PM

