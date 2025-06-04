```
                foo.bar.com
    /                |                     \ 
/login            /echo/a                  /echo/b
(oauth2-proxy)    (auth-check-proxy)       (auth-check-proxy)
                  (echo-server)            (echo-server)
```

Use openshift path based routes to point each service to a subpath on the same domain
front the echo pods with a special auth checkign proxy to force redirect to /login


