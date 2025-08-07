package main

import (
	"log"
	"net"

	"google.golang.org/grpc"
)

const (
	grpcPort = 18000
)

func main() {
	lis, err := net.Listen("tcp", ":18000")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	log.Printf("server listening at %v", lis.Addr())
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
