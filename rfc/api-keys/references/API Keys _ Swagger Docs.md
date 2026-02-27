# API Keys _ Swagger Docs

**Source:** `API Keys _ Swagger Docs.pdf`

---

API Keys | Swagger Docs

1 of 6

https://swagger.io/docs/speciﬁcation/v3_0/authentication/api...

Documentation
On this page

Overview

Overview
Describing API Keys

API Keys
Multiple API Keys
401 Response

Note
OAS 3 This guide is for OpenAPI 3.0. If you use OpenAPI 2.0, see our OpenAPI 2.0 guide.
Some APIs use API keys for authorization. An API key is a token that a client provides when
making API calls. The key can be sent in the query string:
1

GET /something?api_key=abcdef12345

or as a request header:
1

GET /something HTTP/1.1

2

X-API-Key: abcdef12345

or as a cookie:
1

GET /something HTTP/1.1

2
Cookie: on
X-API-KEY=abcdef12345
About
cookies
this site
We use cookies to collect and analyze information on site performance and usage, to provide social media
features and to enhance and customize content and advertisements. Learn more

API keys are supposed to be a secret that only the client and server know. Like Basic
authentication, API key-based authentication is only considered secure if used together with
Cookie settings

ALLOW ALL COOKIES

other security mechanisms such as HTTPS/SSL.

2/27/26, 12:38 PM

API Keys | Swagger Docs

2 of 6

https://swagger.io/docs/speciﬁcation/v3_0/authentication/api...

Describing API Keys
In OpenAPI 3.0, API keys are described as follows:

Documentation

1

openapi: 3.0.4

2

---

3

# 1) Define the key name and location

On this page

Overview

Overview
4
components:
5
securitySchemes:
Describing API Keys
6
ApiKeyAuth: # arbitrary name for the security scheme
Multiple API Keys
7
type: apiKey
8 Response in: header # can be "header", "query" or "cookie"
401
9

name: X-API-KEY # name of the header, query parameter or cookie

10
11

# 2) Apply the API key globally to all operations

12

security:

13

- ApiKeyAuth: [] # use the same name as under securitySchemes

This example de�nes an API key named X-API-Key sent as a request header X-API-Key:
<key> . The key name ApiKeyAuth is an arbitrary name for the security scheme (not to be

confused with the API key name, which is speci�ed by the name key). The name ApiKeyAuth
is used again in the security section to apply this security scheme to the API. Note: The
securitySchemes

section alone is not enough; you must also use security for the API key

to have e�ect. security can also be set on the operation level instead of globally. This is
useful if just a subset of the operations need the API key:
1
2
3

paths:
/something:
get:

4

# Operation-specific security:

5

security:

About cookies on this site
6

- ApiKeyAuth: []

We use cookies to collect and analyze information on site performance and usage, to provide social media

7

responses:

8

"200":

features and to enhance and customize content and advertisements. Learn more

9
description: OK (successfully authenticated)
Cookie settings
ALLOW ALL COOKIES

2/27/26, 12:38 PM

API Keys | Swagger Docs

3 of 6

https://swagger.io/docs/speciﬁcation/v3_0/authentication/api...

Note that it is possible to support multiple authorization types in an API. See Using Multiple
Authentication Types.

Documentation
Multiple API Keys
On this page
Overview
Some
APIs use a pair
of security keys, say, API Key and App ID. To specify that the keys are

used
together (as in logical AND), list them in the same array item in the security array:
Overview
Describing API Keys
1
components:
Multiple
API
Keys
2
securitySchemes:
3 Response
apiKey:
401
4
type: apiKey
5

in: header

6

name: X-API-KEY

7

appId:

8

type: apiKey

9

in: header

10

name: X-APP-ID

11
12
13
14

security:
- apiKey: []
appId: [] # <-- no leading dash (-)

Note the di�erence from:
1

security:

2

- apiKey: []

3

- appId: []

which means either key can be used (as in logical OR). For more examples, see Using
Multiple
About Authentication
cookies on thisTypes.
site
We use cookies to collect and analyze information on site performance and usage, to provide social media
features and to enhance and customize content and advertisements. Learn more

401 Response

Cookie settings
ALLOW ALL COOKIES
You can
de�ne the 401 “Unauthorized”
response returned for requests with missing or

2/27/26, 12:38 PM

API Keys | Swagger Docs

4 of 6

https://swagger.io/docs/speciﬁcation/v3_0/authentication/api...

invalid API key. This response includes the WWW-Authenticate header, which you may want
to mention. As with other common responses, the 401 response can be de�ned in the
global components/responses section and referenced elsewhere via $ref .

Documentation

1

paths:

On2 this page/something:
Overview

3
get:
Overview
4
...
Describing
API Keys
5
responses:
6
Multiple
API Keys ...
7
'401':
401 Response
8
$ref: "#/components/responses/UnauthorizedError"
9

post:

10

...

11

responses:

12

...

13

'401':

14

$ref: "#/components/responses/UnauthorizedError"

15
16

components:

17

responses:

18

UnauthorizedError:

19

description: API key is missing or invalid

20

headers:

21

WWW_Authenticate:

22
23

schema:
type: string

To learn more about describing responses, see Describing Responses.
Did not �nd what you were looking for? Ask the community
Found
a mistake?
know
About
cookiesLet
on us
this
site
We use cookies to collect and analyze information on site performance and usage, to provide social media
features and to enhance and customize content and advertisements. Learn more

Edit page
Cookie settings

ALLOW ALL COOKIES

2/27/26, 12:38 PM

API Keys | Swagger Docs

Previous

Next

Basic Authentication
Documentation
On this page

Bearer Authentication

Overview

Overview
Describing API Keys
Multiple CONTACT
API Keys US
USA +1 617-684-2600
401 Response
EUR +353 91 398300
AUS +61 391929960

COMPANY

PRODUCTS

About

Swagger



Careers

Swagger Editor



Newsroom

Swagger UI



Partners

Swagger Codegen



Contact Us



Responsibility

LEGAL



Privacy



RESOURCES

Security

OpenAPI Speci�cation

Terms of Use

Resource Center

Website Terms of Use





5 of 6

https://swagger.io/docs/speciﬁcation/v3_0/authentication/api...

Blog
Docs

About cookies on this site
We use cookies to collect and analyze information on site performance and usage, to provide social media
features and to enhance and customize content and advertisements. Learn more

Cookie settings

ALLOW ALL COOKIES

2/27/26, 12:38 PM

API Keys | Swagger Docs

6 of 6

https://swagger.io/docs/speciﬁcation/v3_0/authentication/api...

© 2026 SmartBear Software. All Rights Reserved.

Documentation
On this page

Overview

Overview
Describing API Keys
Multiple API Keys
401 Response

About cookies on this site
We use cookies to collect and analyze information on site performance and usage, to provide social media
features and to enhance and customize content and advertisements. Learn more

Cookie settings

ALLOW ALL COOKIES

2/27/26, 12:38 PM

