```
                foo.bar.com
    /                |                     \ 
/login            /echo/a                  /echo/b
(oauth2-proxy)    (auth-check-proxy)       (auth-check-proxy)
                  (echo-server)            (echo-server)
```

Use openshift path based routes to point each service to a subpath on the same domain
front the echo pods with a special auth checkign proxy to force redirect to /login


You can check the state of auth with the oauth2-proxy service by opening <prefix>/userinfo ...

    https://oauth2-proxy.github.io/oauth2-proxy/features/endpoints?_highlight=prefix

    https://foo.bar.com/login/userinfo
    {"user":"b0dbec1f-7153-4163-ad62-750f8f858c49","email":"testuser1@haxx.net","preferredUsername":"testuser1"}



