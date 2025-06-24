alice
---
```
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.191183       1 round_trippers.go:466] curl -v -XPOST  -H "User-Agent: kube-rbac-proxy/v0.0.0 (linux/amd64) kubernetes/$Format" -H "Authorization: Bearer <masked>" -H "Accept: application/json, */*" -H "Content-Type: application/json" 'https://10.96.0.1:443/apis/authentication.k8s.io/v1/tokenreviews'
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192261       1 round_trippers.go:553] POST https://10.96.0.1:443/apis/authentication.k8s.io/v1/tokenreviews 201 Created in 1 milliseconds
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192272       1 round_trippers.go:570] HTTP Statistics: GetConnection 0 ms ServerProcessing 0 ms Duration 1 ms
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192277       1 round_trippers.go:577] Response Headers:
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192282       1 round_trippers.go:580]     Audit-Id: ae7ddebe-93f7-4f47-b7fd-d3a0e84203e1
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192287       1 round_trippers.go:580]     Cache-Control: no-cache, private
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192291       1 round_trippers.go:580]     Content-Type: application/json
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192296       1 round_trippers.go:580]     X-Kubernetes-Pf-Flowschema-Uid: bc02f802-05e3-4888-9aa0-fbbbbc301a17
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192300       1 round_trippers.go:580]     X-Kubernetes-Pf-Prioritylevel-Uid: 8433e01b-4dc7-413a-bd41-b14a2aecca52
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192305       1 round_trippers.go:580]     Content-Length: 1613
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192309       1 round_trippers.go:580]     Date: Tue, 24 Jun 2025 18:41:24 GMT
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192329       1 request.go:1154] Response Body: {"kind":"TokenReview","apiVersion":"authentication.k8s.io/v1","metadata":{"creationTimestamp":null,"managedFields":[{"manager":"kube-rbac-proxy","operation":"Update","apiVersion":"authentication.k8s.io/v1","time":"2025-06-24T18:41:24Z","fieldsType":"FieldsV1","fieldsV1":{"f:spec":{"f:token":{}}}}]},"spec":{"token":"eyJhbGciOiJSUzI1NiIsImtpZCI6InJLVThRamxEbW1lN0RlQmZPTTMtQy01ZEk3eWx0Ym9qQVFNSWc0Z2huY28ifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNzUwNzk0MDg0LCJpYXQiOjE3NTA3OTA0ODQsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiMDFjMjMwNzEtNjQzYy00OTBlLWE2NDItODYyOTdhZWY3NmU3Iiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJucy1hIiwic2VydmljZWFjY291bnQiOnsibmFtZSI6ImJvYiIsInVpZCI6ImYyNmJhOWIyLTVmNmMtNGI0NS05MGJkLThhM2Q4ZGY2OWI2NiJ9fSwibmJmIjoxNzUwNzkwNDg0LCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6bnMtYTpib2IifQ.o2LQF6joX9RQe54qKdCzAMtABjjpnvOQt3aDLTKid-gKVPX-f4oW00X954Dc9PwRpCXaKYQD3AiG7IFvKeJGMGGH4yIz2ZHmv-CwZ06W7HCjL_PxMIq3Qa9hyxQRE3Te--uYAC-5IhRFVJ0ic6-FeMGXrl78i3KXNzgynw9ID4OXCMj3yvxVyfJmZT4ka8uUc8Ju5Z8oDcXZbz93J5go7aBxjRuOLrMTyqAn-rNrNJEq1DIPCGWKgaTC1Gfgse3k1R438nM3bRh9gH-y2S6_WTTWodBjDWTxzJIbU8DXQYNNp4Dt_B9m6e6UDjL00YaD8VkJPsuyPtOXERMknqvy5Q"},"status":{"authenticated":true,"user":{"username":"system:serviceaccount:ns-a:bob","uid":"f26ba9b2-5f6c-4b45-90bd-8a3d8df69b66","groups":["system:serviceaccounts","system:serviceaccounts:ns-a","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["JTI=01c23071-643c-490e-a642-86297aef76e7"]}},"audiences":["https://kubernetes.default.svc.cluster.local"]}}
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.192490       1 request.go:1154] Request Body: {"kind":"SubjectAccessReview","apiVersion":"authorization.k8s.io/v1","metadata":{"creationTimestamp":null},"spec":{"nonResourceAttributes":{"path":"/","verb":"get"},"user":"system:serviceaccount:ns-a:bob","groups":["system:serviceaccounts","system:serviceaccounts:ns-a","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["JTI=01c23071-643c-490e-a642-86297aef76e7"]},"uid":"f26ba9b2-5f6c-4b45-90bd-8a3d8df69b66"},"status":{"allowed":false}}
```

bob
---
```
echo-a-6996bf5694-xc5rm kube-rbac-proxy I0624 18:41:24.193432       1 proxy.go:102] Forbidden (user=system:serviceaccount:ns-a:bob, verb=get, resource=, subresource=). Reason: "".
```
