1. `./START_CLUSTER.sh`
2. `./DEPLOY_DEX.sh`
3. `./DEPLOY_ECHO.sh`
4. `kubectl apply -f configs/alice-allow.yaml`

kubectl port-forward -n dex svc/dex 5556:5556
kubectl port-forward -n echo svc/echo 8443:443

`./LOGIN_AND_CURL.sh` ... copy the code from the browser url bar after login and paste back into the terminal

```
$ ./LOGIN_AND_CURL.sh                                                                                                                                                                                                                                               
Starting temporary HTTP callback listener...                                              
Please log in at:                                                                         
https://localhost:5556/auth?client_id=echo&redirect_uri=http://localhost:8000/callback&response_type=code&scope=openid+profile+email+groups+offline_access                                                                                                   
                                                                                          
After login, copy the 'code' param from the redirected URL and paste it here:             
Code: jginsguyn6xyi2a3rvxdejvmq                                                           
Requesting token...                                                                                                                                                                 
                                                                                          
Sending request to echo service with ID token...                                          
* Host localhost:8443 was resolved.                                                       
* IPv6: ::1                                                                               
* IPv4: 127.0.0.1                                                                         
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current           
                                 Dload  Upload   Total   Spent    Left  Speed             
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying [::1]:8443...                                                                                                                                                       
* ALPN: curl offers h2,http/1.1                                                           
} [5 bytes data]                                                                          
* TLSv1.3 (OUT), TLS handshake, Client hello (1):                                         
} [512 bytes data]                                                                        
* TLSv1.3 (IN), TLS handshake, Server hello (2):                                          
{ [122 bytes data]                                                                        
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):                                  
{ [15 bytes data]                                                                         
* TLSv1.3 (IN), TLS handshake, Request CERT (13):                                         
{ [45 bytes data]                                                                         
* TLSv1.3 (IN), TLS handshake, Certificate (11):                                          
{ [1122 bytes data]                                                                       
* TLSv1.3 (IN), TLS handshake, CERT verify (15):                                          
{ [264 bytes data]                                                                        
* TLSv1.3 (IN), TLS handshake, Finished (20):                                                                                                                                                                                                                                                                                                                            
{ [36 bytes data]                                                                                                                                                                                                                                                                                                                                                        
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):                               
} [1 bytes data]                                                                          
* TLSv1.3 (OUT), TLS handshake, Certificate (11):       
} [8 bytes data]                                                                          
* TLSv1.3 (OUT), TLS handshake, Finished (20):                                            
} [36 bytes data]                                                                         
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256 / x25519 / RSASSA-PSS             
* ALPN: server accepted h2                                                                
* Server certificate:                                                                     
*  subject: CN=echo.echo.svc.cluster.local                                                                                                                                                                                                                                                                                                                               
*  start date: Jun 25 13:51:25 2025 GMT                                                                                                                                                                                                                                                                                                                                  
*  expire date: Jun 25 13:51:25 2026 GMT                                                  
*  issuer: CN=Dex CA                                                                                                                                                                 
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.                                 
*   Certificate level 0: Public key type RSA (2048/112 Bits/secBits), signed using sha256WithRSAEncryption       
* Connected to localhost (::1) port 8443                                                  
* using HTTP/2                                                                            
* [HTTP/2] [1] OPENED stream for https://localhost:8443/                                                                                                                                                                                                                                                                                                                 
* [HTTP/2] [1] [:method: GET]                                                                                                                                                                                                                                                                                                                                            
* [HTTP/2] [1] [:scheme: https]                                                           
* [HTTP/2] [1] [:authority: localhost:8443]                                               
* [HTTP/2] [1] [:path: /]                                                                 
* [HTTP/2] [1] [user-agent: curl/8.11.1]                                                  
* [HTTP/2] [1] [accept: */*]                                                              
* [HTTP/2] [1] [authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IjRlODczMTBkMmE4ZWFiZjI0MTU1ZGU1YzlkY2NkMjUzYzEzOTQxZDcifQ.eyJpc3MiOiJodHRwczovL2RleC5kZXguc3ZjLmNsdXN0ZXIubG9jYWw6NTU1NiIsInN1YiI6IkNnTXhNak1TQld4dlkyRnMiLCJhdWQiOiJlY2hvIiwiZXhwIjoxNzUwOTU4NDY3LCJpYXQiOjE3NTA4NzIwNjcsImF0X2hhc2giOiJwZjY5R3doV2RZcm9xMU9sbHhWUkN3IiwiY19oYXNoIjoiV1dBS0ZvMm8wTHU1MkRpa2tkN1hXUSIsImVtYWlsIjoiYWxpY2VAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibmFtZSI6ImFsaWNlIn0.BRT6poSq-GIvxlUaIK11dzSvx1_hmAm3mp26tOF7V
2VtCwP67hCjDHsZt8fMhLz6wGQxtTTYj4yCas6u9JHi7xXCKh7rNjeDODU_ECnkF-vqFAooxs_UabPJ1c_v7YsYrW1S30nLQz1VDIYiTAWAiu6hvwoqdIT65hmRXRpyplQj-UeeyTY3jQfCcQ71BZANxAiWn_bXWMeurWH6iMOIdEwm61tlz6SP1HwqxssGjiSwgrBIJa-xI8fE49EXlA2mk_WHNy9YSBmqK4kRUf5qaRwS_Zygy6Gmy1R8KG7H_tdEMJbLPe4-gvWvc-jij0tYKfrx7qhCFejVKefMw-C70g]
} [5 bytes data]                                                                          
> GET / HTTP/2                                                                            
> Host: localhost:8443                                                                    
> User-Agent: curl/8.11.1                                                                 
> Accept: */*                                                                             
> Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IjRlODczMTBkMmE4ZWFiZjI0MTU1ZGU1YzlkY2NkMjUzYzEzOTQxZDcifQ.eyJpc3MiOiJodHRwczovL2RleC5kZXguc3ZjLmNsdXN0ZXIubG9jYWw6NTU1NiIsInN1YiI6IkNnTXhNak1TQld4dlkyRnMiLCJhdWQiOiJlY2hvIiwiZXhwIjoxNzUwOTU4NDY3LCJpYXQiOjE3NTA4NzIwNjcsImF0X2hhc2giOiJwZjY5R3doV2RZcm9xMU9sbHhWUkN3IiwiY19oYXNoIjoiV1dBS0ZvMm8wTHU1MkRpa2tkN1hXUSIsImVtYWlsIjoiYWxpY2VAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibmFtZSI6ImFsaWNlIn0.BRT6poSq-GIvxlUaIK11dzSvx1_hmAm3mp26tOF7V2VtCwP67hCjDHs
Zt8fMhLz6wGQxtTTYj4yCas6u9JHi7xXCKh7rNjeDODU_ECnkF-vqFAooxs_UabPJ1c_v7YsYrW1S30nLQz1VDIYiTAWAiu6hvwoqdIT65hmRXRpyplQj-UeeyTY3jQfCcQ71BZANxAiWn_bXWMeurWH6iMOIdEwm61tlz6SP1HwqxssGjiSwgrBIJa-xI8fE49EXlA2mk_WHNy9YSBmqK4kRUf5qaRwS_Zygy6Gmy1R8KG7H_tdEMJbLPe4-gvWvc-jij0tYKfrx7qhCFejVKefMw-C70g
>                                                                                                                                                                                    
* Request completely sent off                                  
{ [5 bytes data]                                                                                                               
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):                                                                         
{ [130 bytes data]                                             
< HTTP/2 200                                                                                                                   
< content-type: application/json; charset=utf-8                                                                                
< date: Wed, 25 Jun 2025 17:21:07 GMT                          
< etag: W/"491-kR3i5NKrayriAJvI7TAnTcJDQ38"                                                                                   
< content-length: 1169                                         
<                                                                                                                              
{ [5 bytes data]                                               
100  1169  100  1169    0     0  46165      0 --:--:-- --:--:-- --:--:-- 46760                                                
* Connection #0 to host localhost left intact 

{                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
  "host": {                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
    "hostname": "localhost",                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
    "ip": "::ffff:127.0.0.1",                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
    "ips": []                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
  },                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
  "http": {                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
    "method": "GET",                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
    "baseUrl": "",                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
    "originalUrl": "/",                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               
    "protocol": "http"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                
  },                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
  "request": {                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
    "params": {                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       
      "0": "/"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       
    },                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
    "query": {},                                                                                                              
    "cookies": {},                                                                                                             
    "body": {},                                                                                                               
    "headers": {                                                                                                              
      "host": "localhost:8443",                                                                                               
      "user-agent": "curl/8.11.1",                                                                                             
      "accept": "*/*",                                                                                                        
      "x-forwarded-for": "127.0.0.1",                                                                                                                                                                                                                        
      "x-remote-groups": "",                                   
      "x-remote-user": "alice@example.com",                                                                                    
      "accept-encoding": "gzip"                                                                                                                                                                                                                              
    }                                                                                                                                                                                                                                                         
  },                                                                                                                           
  "environment": {                                             
    "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",                                                    
    "HOSTNAME": "echo-a-5c47f8b74-mhsc9",                      
    "NODE_VERSION": "20.11.0",                                                                                                 
    "YARN_VERSION": "1.22.19",                                 
    "KUBERNETES_PORT_443_TCP_PROTO": "tcp",                                                                                    
    "KUBERNETES_PORT_443_TCP_ADDR": "10.96.0.1",                                                                              
    "ECHO_PORT_443_TCP_ADDR": "10.96.58.59",                                                                                   
    "ECHO_PORT_443_TCP_PROTO": "tcp",                                                                                          
    "KUBERNETES_SERVICE_HOST": "10.96.0.1",                                                                                                                                                                                                                  
    "KUBERNETES_SERVICE_PORT": "443",                          
    "KUBERNETES_PORT_443_TCP_PORT": "443",                                                                                     
    "KUBERNETES_SERVICE_PORT_HTTPS": "443",                                                                                    
    "KUBERNETES_PORT": "tcp://10.96.0.1:443",                                                                                  
    "ECHO_SERVICE_HOST": "10.96.58.59",                                                                                       
    "KUBERNETES_PORT_443_TCP": "tcp://10.96.0.1:443",                                                                          
    "ECHO_SERVICE_PORT": "443",                                                                                               
    "ECHO_SERVICE_PORT_HTTPS": "443",                                                                                                                                                                                                                         
    "ECHO_PORT": "tcp://10.96.58.59:443",                                                                                     
    "ECHO_PORT_443_TCP": "tcp://10.96.58.59:443",                                                                              
    "ECHO_PORT_443_TCP_PORT": "443",                                                                                           
    "HOME": "/root"                                                                                                            
  }                                                                                                                            
}    
``


