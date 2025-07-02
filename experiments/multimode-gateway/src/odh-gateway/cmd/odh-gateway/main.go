package main

import (
	"flag"
	"log"

	"github.com/jctanner/odh-gateway/internal/proxy"
)

func main() {
	var (
		tlsCertFile = flag.String("tls-cert-file", "", "Path to TLS certificate file (enables HTTPS)")
		tlsKeyFile  = flag.String("tls-key-file", "", "Path to TLS private key file (enables HTTPS)")
	)
	flag.Parse()

	// Both cert and key must be provided to enable TLS
	var certFile, keyFile string
	if *tlsCertFile != "" && *tlsKeyFile != "" {
		certFile = *tlsCertFile
		keyFile = *tlsKeyFile
	} else if *tlsCertFile != "" || *tlsKeyFile != "" {
		log.Fatal("Both --tls-cert-file and --tls-key-file must be provided to enable TLS")
	}

	if err := proxy.StartServer(certFile, keyFile); err != nil {
		log.Fatalf("failed to start gateway: %v", err)
	}
}
