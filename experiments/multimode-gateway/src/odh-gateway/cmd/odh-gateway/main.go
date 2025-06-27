package main

import (
	"log"

	"github.com/jctanner/odh-gateway/internal/proxy"
)

func main() {
	if err := proxy.StartServer(); err != nil {
		log.Fatalf("failed to start gateway: %v", err)
	}
}
