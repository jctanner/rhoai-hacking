// This program implements a minimal, static Envoy xDS (Discovery Service) server.
// The xDS server acts as a control plane for Envoy proxies, providing them with
// configuration for listeners, routes, clusters, and other resources.
//
// Architecture:
// 1. A gRPC server is started to serve the Envoy xDS APIs (e.g., LDS, CDS, RDS).
// 2. A SnapshotCache from the go-control-plane library is used to hold different
//    versions of the configuration.
// 3. A single, static configuration snapshot is created and loaded into the cache.
//    This configuration is served to any Envoy proxy that connects with the
//    node ID "test-id".
// 4. The provided configuration instructs the Envoy proxy to:
//    a. Listen for incoming HTTP traffic on port 10000.
//    b. For any request, respond directly with a 200 OK status and a static
//       "Hello from minimal xDS!" message, rather than proxying the request
//       to an upstream service.
// 5. The configuration also defines a cluster named "xds_cluster" that points back
//    to the xDS server itself. This is used by the Envoy proxy to fetch route
//    configurations via the Route Discovery Service (RDS).
//
// Relationship with Envoy's Static Configuration:
// It's important to understand that an xDS server does not necessarily manage the
// ENTIRE configuration of an Envoy proxy. Envoy starts with a static bootstrap
// configuration file (e.g., envoy.yaml). This file can contain a mix of static
// resources (like listeners) and dynamic resource locators that point to an xDS
// server.
//
// This specific implementation assumes that the Envoy proxy is configured to use
// LDS (Listener Discovery Service) to fetch its listeners dynamically. Therefore,
// this server IS responsible for providing the listener's entire configuration,
// including its filter chain (e.g., the HttpConnectionManager). If, however,
// the listener were defined statically in Envoy's bootstrap file, this server
// would not need to manage it, though it could still provide other dynamic
// resources for that listener, such as its routes via RDS.
//
// In essence, this is a self-contained example of an xDS control plane that configures
// its data plane (Envoy) to behave as a simple, non-proxying HTTP server.
package main

import (
    "context"
    "fmt"
    "log"
    "net"
    "time"

    "google.golang.org/grpc"

    "github.com/envoyproxy/go-control-plane/pkg/cache/v3"
    "github.com/envoyproxy/go-control-plane/pkg/cache/types"
    "github.com/envoyproxy/go-control-plane/pkg/resource/v3"
    "github.com/envoyproxy/go-control-plane/pkg/server/v3"

    core "github.com/envoyproxy/go-control-plane/envoy/config/core/v3"
    cluster "github.com/envoyproxy/go-control-plane/envoy/config/cluster/v3"
    endpoint "github.com/envoyproxy/go-control-plane/envoy/config/endpoint/v3"
    listener "github.com/envoyproxy/go-control-plane/envoy/config/listener/v3"
    route "github.com/envoyproxy/go-control-plane/envoy/config/route/v3"
    hcm "github.com/envoyproxy/go-control-plane/envoy/extensions/filters/network/http_connection_manager/v3"

    clusterservice "github.com/envoyproxy/go-control-plane/envoy/service/cluster/v3"
    discoverygrpc "github.com/envoyproxy/go-control-plane/envoy/service/discovery/v3"
    endpointservice "github.com/envoyproxy/go-control-plane/envoy/service/endpoint/v3"
    listenerservice "github.com/envoyproxy/go-control-plane/envoy/service/listener/v3"
    routeservice "github.com/envoyproxy/go-control-plane/envoy/service/route/v3"
    runtimeservice "github.com/envoyproxy/go-control-plane/envoy/service/runtime/v3"
    secretservice "github.com/envoyproxy/go-control-plane/envoy/service/secret/v3"

    "google.golang.org/protobuf/types/known/anypb"
    "google.golang.org/protobuf/types/known/durationpb"
)

const (
    grpcPort = 18000
    nodeID   = "test-id"
)

// main is the entry point of the program. It initializes and starts the xDS server,
// then creates and sets an initial configuration snapshot.
func main() {
	// Create a snapshot cache. This cache holds the configuration snapshots that will be
	// served to the Envoy proxies. The first argument 'false' disables ADS (Aggregated
	// Discovery Service) mode, meaning each resource type is fetched on its own
	// stream. The second argument provides a hashing function for node IDs. The third 'nil'
	// is for a logger, which we are not using here.
	snapshotCache := cache.NewSnapshotCache(false, cache.IDHash{}, nil)

    	// Run the gRPC server in a separate goroutine.
	go func() {
		// Create a TCP listener for the gRPC server.
		lis, err := net.Listen("tcp", fmt.Sprintf(":%d", grpcPort))
		if err != nil {
			log.Fatalf("failed to listen: %v", err)
		}

		// Create a new gRPC server.
		s := grpc.NewServer()

		// Create a new xDS server instance. The server needs a context, the snapshot cache,
		// and optional callbacks for handling events.
		srv := server.NewServer(context.Background(), snapshotCache, nil)

		// Register the various discovery services with the gRPC server.
		discoverygrpc.RegisterAggregatedDiscoveryServiceServer(s, srv)
		endpointservice.RegisterEndpointDiscoveryServiceServer(s, srv)
		clusterservice.RegisterClusterDiscoveryServiceServer(s, srv)
		routeservice.RegisterRouteDiscoveryServiceServer(s, srv)
		listenerservice.RegisterListenerDiscoveryServiceServer(s, srv)
		secretservice.RegisterSecretDiscoveryServiceServer(s, srv)
		runtimeservice.RegisterRuntimeDiscoveryServiceServer(s, srv)

		log.Printf("gRPC xDS server listening on :%d", grpcPort)
		// Start serving requests on the listener. This is a blocking call.
		if err := s.Serve(lis); err != nil {
			log.Fatalf("failed to serve: %v", err)
		}
	}()

	// Set the initial snapshot in the cache.
	setSnapshot(snapshotCache)

	// Block the main goroutine indefinitely so the gRPC server can continue to run.
	select {}
}

// setSnapshot creates a new configuration snapshot and sets it in the cache.
// This snapshot contains the configuration for a listener, a route, and a cluster.
func setSnapshot(snapshotCache cache.SnapshotCache) {
	// These are the names for our resources. They are used to link resources together.
	routeName := "local_route"
	listenerName := "listener_0"
	clusterName := "xds_cluster"

	// Create an HTTP connection manager filter. This filter manages HTTP connections
	// and routes requests.
	manager := &hcm.HttpConnectionManager{
		StatPrefix: "ingress_http",
		// The RouteSpecifier tells the connection manager how to get its route configuration.
		// Here, we're using RDS (Route Discovery Service) to fetch routes from the xDS server.
		RouteSpecifier: &hcm.HttpConnectionManager_Rds{
			Rds: &hcm.Rds{
				// ConfigSource specifies where to fetch the configuration from.
				ConfigSource:    makeConfigSource(),
				RouteConfigName: routeName,
			},
		},
		// HttpFilters is a list of filters that will be applied to HTTP requests.
		// The router filter is essential for request routing.
		HttpFilters: []*hcm.HttpFilter{{
			Name: "envoy.filters.http.router",
		}},
	}
	// The HttpConnectionManager configuration must be marshaled into an Any protobuf.
	pbst, err := anypb.New(manager)
	if err != nil {
		panic(err)
	}

	// Create a listener. A listener is a named network location (e.g., port, unix domain socket)
	// that can be connected to by downstream clients.
	listener := &listener.Listener{
		Name: listenerName,
		// The address the listener will listen on.
		Address: &core.Address{
			Address: &core.Address_SocketAddress{
				SocketAddress: &core.SocketAddress{
					Protocol: core.SocketAddress_TCP,
					Address:  "0.0.0.0",
					PortSpecifier: &core.SocketAddress_PortValue{
						PortValue: 10000,
					},
				},
			},
		},
		// FilterChains is a list of filters that are applied to connections that match the listener.
		FilterChains: []*listener.FilterChain{{
			Filters: []*listener.Filter{{
				Name: "envoy.filters.network.http_connection_manager",
				// The typed config for the filter is our HttpConnectionManager.
				ConfigType: &listener.Filter_TypedConfig{TypedConfig: pbst},
			}},
		}},
	}

	// Create a route configuration. This defines how requests are routed to clusters.
	routeConfig := &route.RouteConfiguration{
		Name: routeName,
		// VirtualHosts group a set of domains and their routing rules.
		VirtualHosts: []*route.VirtualHost{{
			Name: "local_service",
			// Domains that this virtual host applies to. "*" matches any domain.
			Domains: []string{"*"},
			// Routes define the matching criteria and action for a request.
			Routes: []*route.Route{{
				// Match specifies the conditions for a route to be matched.
				// Here, we match any request with a "/" prefix.
				Match: &route.RouteMatch{
					PathSpecifier: &route.RouteMatch_Prefix{
						Prefix: "/",
					},
				},
				// Action defines what to do when a route is matched.
				// Here, we send a direct response, so Envoy doesn't proxy the request.
				Action: &route.Route_DirectResponse{
					DirectResponse: &route.DirectResponseAction{
						Status: 200,
						Body: &core.DataSource{
							Specifier: &core.DataSource_InlineString{
								InlineString: "Hello from minimal xDS!",
							},
						},
					},
				},
			}},
		}},
	}

	// Create a cluster. A cluster is a group of upstream hosts that Envoy can proxy requests to.
	// In this case, the cluster is used by the gRPC service definition in makeConfigSource
	// to allow Envoy to discover the xDS server itself for fetching route configurations.
	xdsCluster := &cluster.Cluster{
		Name: clusterName,
		// The discovery type determines how the members of the cluster are discovered.
		// STATIC means the hosts are hardcoded in the configuration.
		ClusterDiscoveryType: &cluster.Cluster_Type{
			Type: cluster.Cluster_STATIC,
		},
		ConnectTimeout: durationpb.New(1 * time.Second),
		// LoadAssignment specifies the endpoints for a STATIC cluster.
		LoadAssignment: &endpoint.ClusterLoadAssignment{
			ClusterName: clusterName,
			Endpoints: []*endpoint.LocalityLbEndpoints{{
				LbEndpoints: []*endpoint.LbEndpoint{{
					HostIdentifier: &endpoint.LbEndpoint_Endpoint{
						Endpoint: &endpoint.Endpoint{
							Address: &core.Address{
								Address: &core.Address_SocketAddress{
									SocketAddress: &core.SocketAddress{
										Protocol: core.SocketAddress_TCP,
										Address:  "127.0.0.1",
										PortSpecifier: &core.SocketAddress_PortValue{
											PortValue: grpcPort,
										},
									},
								},
							},
						},
					},
				}},
			}},
		},
	}

	// Create a new snapshot with the resources we've defined.
	// The version "1.0" is arbitrary and can be any string.
	snap, err := cache.NewSnapshot(
		"1.0",
		map[resource.Type][]types.Resource{
			// We provide our listener, route, and cluster resources.
			// Other resource types are empty.
			resource.EndpointType: {},
			resource.ClusterType:  {xdsCluster},
			resource.RouteType:    {routeConfig},
			resource.ListenerType: {listener},
			resource.RuntimeType:  {},
			resource.SecretType:   {},
		},
	)
	if err != nil {
		log.Fatalf("failed to create snapshot: %v", err)
	}

	// Set the snapshot in the cache for the given node ID.
	// Any Envoy proxy that identifies with "test-id" will receive this snapshot.
	if err := snapshotCache.SetSnapshot(context.Background(), nodeID, snap); err != nil {
		log.Fatalf("failed to set snapshot: %v", err)
	}

	log.Printf("Snapshot set successfully")
}

// makeConfigSource creates a configuration source for the Route Discovery Service (RDS).
// This tells Envoy how to connect to the xDS server to fetch route configurations.
func makeConfigSource() *core.ConfigSource {
	return &core.ConfigSource{
		ResourceApiVersion: core.ApiVersion_V3,
		ConfigSourceSpecifier: &core.ConfigSource_ApiConfigSource{
			ApiConfigSource: &core.ApiConfigSource{
				TransportApiVersion:       core.ApiVersion_V3,
				ApiType:                   core.ApiConfigSource_GRPC,
				SetNodeOnFirstMessageOnly: true,
				// GrpcServices specifies the gRPC service(s) to connect to.
				GrpcServices: []*core.GrpcService{{
					TargetSpecifier: &core.GrpcService_EnvoyGrpc_{
						// EnvoyGrpc specifies that the gRPC service is an Envoy gRPC service.
						// The ClusterName tells Envoy which cluster to use to connect to the service.
						// In this case, it's our "xds_cluster" which points back to this server.
						EnvoyGrpc: &core.GrpcService_EnvoyGrpc{
							ClusterName: "xds_cluster",
						},
					},
				}},
			},
		},
	}
}

