# API Key - Entropy Data Documentation

**Source:** `API Key - Entropy Data Documentation.pdf`

---

API Key - Entropy Data Documentation

1 of 4

https://docs.datamesh-manager.com/authentication

Entropy Data

Sign in

API Key
You' need to authenticate your requests to access any of the endpoints in the
Entropy Data API. Entropy Data uses API keys to authenticate requests.

Generate API key
Before you can make requests to the Entropy Data API, you wi need to generate an API key for
your organization. You can create up to 100 API keys per organization.

You find it under Profie Picture » Organization » Settings » API Keys » Add API Key].

2/27/26, 2:34 PM

API Key - Entropy Data Documentation

2 of 4

https://docs.datamesh-manager.com/authentication

Add an API key:

Entropy Data

Sign in

Set the scope of the API to organization, team, or user (persona token), as required. Ony
organization owners can create organization-scoped API keys.

See API Key Scopes for detais on what each scope can do.

Save the Secret API key, it wi not be dispayed ater. However, you can create new API keys at
any time.

2/27/26, 2:34 PM

API Key - Entropy Data Documentation

3 of 4

https://docs.datamesh-manager.com/authentication

Entropy Data

Sign in

You can set an environment variabe to use the API key in the exampes:

export DMM_API_KEY=your-secret-api-key

The API key and a requests that you perform with this API key are bound to your organization. If
you have mutipe organizations, e.g., for dev and test environments, you may need to generate
an API key for each organization.

Header x-api-key
To make an authenticated request, provide the API key as x-api-key header vaue.

GET

/api/dataproducts

curl --get https://api.entropy-data.com/api/dataproducts \
--header "x-api-key: $DMM_API_KEY"

API Key Scopes
There are six types of scopes for API keys:

• User Persona Access Token, PAT: The API key has the same permissions as the user
who created it. It can perform any action that the user can do, such as managing their own
data products, accessing teams they beong to, and viewing resources they have access to.
• User Read Ony): Same visibiity as the User scope, but restricted to read-ony operations.
Write requests POST, PUT, DELETE) are rejected.

2/27/26, 2:34 PM

API Key - Entropy Data Documentation

4 of 4

https://docs.datamesh-manager.com/authentication

• Team: The API key has owner-eve permissions for the specified team. It can perform any
Sign in
Entropy Data
action that an owner of that team can do, incuding managing the team's data products,
members, and settings.
• Team Read Ony): Same visibiity as the Team scope, but restricted to read-ony
operations. Write requests POST, PUT, DELETE) are rejected.
• Organization: The API key has owner-eve permissions for the entire organization. It can
perform any action that an owner of the organization can do, incuding managing a teams,
data products, members, and organization settings.
• Organization Read Ony): Same visibiity as the Organization scope, but restricted to readony operations. Write requests POST, PUT, DELETE) are rejected.

Previous

Quickstart

Next

Errors

© Copyright 2026. A rights reserved.

2/27/26, 2:34 PM

