---
apiVersion: v1
kind: Namespace
metadata:
  name: dex

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dex-config
  namespace: dex
data:
  config.yaml: |
    issuer: https://dex.dex.svc.cluster.local:5556
    #storage:
    #  type: memory
    storage:
       type: sqlite3
       config:
         file: /var/dex/dex.db
    enablePasswordDB: true
    web:
      https: 0.0.0.0:5556
      tlsCert: /etc/dex/tls/tls.crt
      tlsKey: /etc/dex/tls/tls.key
    #connectors:
    #- type: local
    #  id: local
    #  name: Password
    staticClients:
    - id: kubernetes
      redirectURIs:
      - 'http://localhost:8000/callback'
      name: Kubernetes
      secret: kubernetes-secret
    - id: echo
      name: Echo App
      redirectURIs:
      - http://localhost:8000/callback
      secret: echo-secret
    staticPasswords:
    - email: alice@example.com
      hash: "${BASIC_PASSWORD_HASH}"
      username: alice
      userID: "123"

---
apiVersion: v1
kind: Secret
metadata:
  name: dex-tls
  namespace: dex
type: kubernetes.io/tls
data:
  tls.crt: ${TLS_CRT}
  tls.key: ${TLS_KEY}

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dex
  namespace: dex
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dex
  template:
    metadata:
      labels:
        app: dex
    spec:
      containers:
      - name: dex
        image: ghcr.io/dexidp/dex:latest
        volumeMounts:
        - name: config
          mountPath: /etc/dex
        - name: tls
          mountPath: /etc/dex/tls
        args:
        - dex
        - serve
        - /etc/dex/config.yaml
        ports:
        - containerPort: 5556
      volumes:
      - name: config
        configMap:
          name: dex-config
      - name: tls
        secret:
          secretName: dex-tls

---
apiVersion: v1
kind: Service
metadata:
  name: dex
  namespace: dex
spec:
  selector:
    app: dex
  ports:
  - name: https
    port: 5556
    targetPort: 5556

