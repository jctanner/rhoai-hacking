CERTS_DIR=certs
ROOT_CA=$(CERTS_DIR)/root-cert.pem
CERT_CHAIN=$(CERTS_DIR)/cert-chain.pem
KEY=$(CERTS_DIR)/key.pem

.PHONY: all clean

all: $(CERTS_DIR) $(ROOT_CA) $(CERT_CHAIN) $(KEY)

$(CERTS_DIR):
	mkdir -p $(CERTS_DIR)

$(ROOT_CA):
	openssl req -x509 -newkey rsa:2048 -days 365 -nodes -keyout $(CERTS_DIR)/ca.key -out $(ROOT_CA) -subj "/CN=Test Root CA"

$(CERT_CHAIN):
	openssl req -new -newkey rsa:2048 -nodes -keyout $(KEY) -out $(CERTS_DIR)/envoy.csr -subj "/CN=envoy.local" && \
	openssl x509 -req -in $(CERTS_DIR)/envoy.csr -CA $(ROOT_CA) -CAkey $(CERTS_DIR)/ca.key -CAcreateserial -out $(CERT_CHAIN) -days 365

clean:
	rm -rf $(CERTS_DIR) *.srl
