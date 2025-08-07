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

func main() {
    snapshotCache := cache.NewSnapshotCache(false, cache.IDHash{}, nil)

    go func() {
        lis, err := net.Listen("tcp", fmt.Sprintf(":%d", grpcPort))
        if err != nil {
            log.Fatalf("failed to listen: %v", err)
        }

        callbacks := server.CallbackFuncs{
            StreamOpenFunc: func(ctx context.Context, id int64, typ string) error {
                log.Printf("stream opened: %d (%s)", id, typ)
                return nil
            },
            StreamRequestFunc: func(id int64, req *discoverygrpc.DiscoveryRequest) error {
                log.Printf("request stream %d for %s", id, req.TypeUrl)
                return nil
            },
        }

        s := grpc.NewServer()
        srv := server.NewServer(context.Background(), snapshotCache, &callbacks)

        discoverygrpc.RegisterAggregatedDiscoveryServiceServer(s, srv)
        endpointservice.RegisterEndpointDiscoveryServiceServer(s, srv)
        clusterservice.RegisterClusterDiscoveryServiceServer(s, srv)
        routeservice.RegisterRouteDiscoveryServiceServer(s, srv)
        listenerservice.RegisterListenerDiscoveryServiceServer(s, srv)
        secretservice.RegisterSecretDiscoveryServiceServer(s, srv)
        runtimeservice.RegisterRuntimeDiscoveryServiceServer(s, srv)

        log.Printf("gRPC xDS server listening on :%d", grpcPort)
        if err := s.Serve(lis); err != nil {
            log.Fatalf("failed to serve: %v", err)
        }
    }()

    setSnapshot(snapshotCache)

    select {}
}

func setSnapshot(snapshotCache cache.SnapshotCache) {
    routeName := "local_route"
    listenerName := "listener_0"
    clusterName := "xds_cluster"

    manager := &hcm.HttpConnectionManager{
        StatPrefix: "ingress_http",
        RouteSpecifier: &hcm.HttpConnectionManager_Rds{
            Rds: &hcm.Rds{
                ConfigSource:    makeConfigSource(),
                RouteConfigName: routeName,
            },
        },
        HttpFilters: []*hcm.HttpFilter{{
            Name: "envoy.filters.http.router",
        }},
    }
    pbst, err := anypb.New(manager)
    if err != nil {
        panic(err)
    }

    listener := &listener.Listener{
        Name: listenerName,
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
        FilterChains: []*listener.FilterChain{{
            Filters: []*listener.Filter{{
                Name:       "envoy.filters.network.http_connection_manager",
                ConfigType: &listener.Filter_TypedConfig{TypedConfig: pbst},
            }},
        }},
    }

    routeConfig := &route.RouteConfiguration{
        Name: routeName,
        VirtualHosts: []*route.VirtualHost{{
            Name:    "local_service",
            Domains: []string{"*"},
            Routes: []*route.Route{{
                Match: &route.RouteMatch{
                    PathSpecifier: &route.RouteMatch_Prefix{
                        Prefix: "/",
                    },
                },
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

    xdsCluster := &cluster.Cluster{
        Name: clusterName,
        ClusterDiscoveryType: &cluster.Cluster_Type{
            Type: cluster.Cluster_STATIC,
        },
        ConnectTimeout: durationpb.New(1 * time.Second),
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

    snap, err := cache.NewSnapshot(
        "1.0",
        map[resource.Type][]types.Resource{
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

    if err := snapshotCache.SetSnapshot(context.Background(), nodeID, snap); err != nil {
        log.Fatalf("failed to set snapshot: %v", err)
    }

    log.Printf("Snapshot set successfully")
}

func makeConfigSource() *core.ConfigSource {
    return &core.ConfigSource{
        ResourceApiVersion: core.ApiVersion_V3,
        ConfigSourceSpecifier: &core.ConfigSource_ApiConfigSource{
            ApiConfigSource: &core.ApiConfigSource{
                TransportApiVersion:       core.ApiVersion_V3,
                ApiType:                   core.ApiConfigSource_GRPC,
                SetNodeOnFirstMessageOnly: true,
                GrpcServices: []*core.GrpcService{{
                    TargetSpecifier: &core.GrpcService_EnvoyGrpc_{
                        EnvoyGrpc: &core.GrpcService_EnvoyGrpc{
                            ClusterName: "xds_cluster",
                        },
                    },
                }},
            },
        },
    }
}

