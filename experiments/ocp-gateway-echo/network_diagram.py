#!/usr/bin/env python3

import subprocess
import json
import sys
from typing import Dict, List, Optional, Tuple

class NetworkDiagramBuilder:
    def __init__(self, namespace: str = "echo-test"):
        self.namespace = namespace
        self.routes = []
        self.gateways = []
        self.httproutes = []
        self.services = []
        self.pods = []
        
    def run_oc_command(self, cmd: List[str]) -> Optional[str]:
        """Run oc command and return output"""
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            print(f"Error running command {' '.join(cmd)}: {e}")
            return None
    
    def get_routes(self):
        """Get TinyLB-managed routes"""
        cmd = ["oc", "get", "routes", "-n", self.namespace, "-l", "tinylb.io/managed=true", "-o", "json"]
        output = self.run_oc_command(cmd)
        if output:
            data = json.loads(output)
            for route in data.get("items", []):
                self.routes.append({
                    "name": route["metadata"]["name"],
                    "host": route["spec"]["host"],
                    "tls": route["spec"].get("tls", {}).get("termination", "none"),
                    "target_port": route["spec"].get("port", {}).get("targetPort", "80"),
                    "service": route["spec"]["to"]["name"]
                })
    
    def get_gateways(self):
        """Get Gateway API gateways"""
        cmd = ["oc", "get", "gateway", "-n", self.namespace, "-o", "json"]
        output = self.run_oc_command(cmd)
        if output:
            data = json.loads(output)
            for gateway in data.get("items", []):
                listeners = []
                for listener in gateway["spec"].get("listeners", []):
                    listeners.append({
                        "name": listener["name"],
                        "port": listener["port"],
                        "protocol": listener["protocol"],
                        "hostname": listener.get("hostname", "*")
                    })
                
                status = "Unknown"
                if gateway.get("status", {}).get("conditions"):
                    for condition in gateway["status"]["conditions"]:
                        if condition["type"] == "Programmed" and condition["status"] == "True":
                            status = "Programmed"
                
                self.gateways.append({
                    "name": gateway["metadata"]["name"],
                    "class": gateway["spec"]["gatewayClassName"],
                    "listeners": listeners,
                    "status": status
                })
    
    def get_httproutes(self):
        """Get HTTPRoute resources"""
        cmd = ["oc", "get", "httproute", "-n", self.namespace, "-o", "json"]
        output = self.run_oc_command(cmd)
        if output:
            data = json.loads(output)
            for httproute in data.get("items", []):
                rules = []
                for rule in httproute["spec"].get("rules", []):
                    matches = []
                    for match in rule.get("matches", []):
                        path_info = match.get("path", {})
                        matches.append({
                            "path": path_info.get("value", "/"),
                            "type": path_info.get("type", "PathPrefix")
                        })
                    
                    backends = []
                    for backend in rule.get("backendRefs", []):
                        backends.append({
                            "name": backend["name"],
                            "port": backend["port"]
                        })
                    
                    rules.append({
                        "matches": matches,
                        "backends": backends
                    })
                
                self.httproutes.append({
                    "name": httproute["metadata"]["name"],
                    "gateway": httproute["spec"]["parentRefs"][0]["name"],
                    "hostnames": httproute["spec"].get("hostnames", []),
                    "rules": rules
                })
    
    def get_services(self):
        """Get services"""
        cmd = ["oc", "get", "svc", "-n", self.namespace, "-o", "json"]
        output = self.run_oc_command(cmd)
        if output:
            data = json.loads(output)
            for service in data.get("items", []):
                if service["metadata"]["name"] == "kubernetes":
                    continue
                
                ports = []
                for port in service["spec"].get("ports", []):
                    ports.append({
                        "port": port["port"],
                        "target_port": port["targetPort"],
                        "protocol": port["protocol"]
                    })
                
                self.services.append({
                    "name": service["metadata"]["name"],
                    "type": service["spec"]["type"],
                    "selector": service["spec"].get("selector", {}),
                    "ports": ports
                })
    
    def get_pods(self):
        """Get pods"""
        cmd = ["oc", "get", "pods", "-n", self.namespace, "-o", "json"]
        output = self.run_oc_command(cmd)
        if output:
            data = json.loads(output)
            for pod in data.get("items", []):
                containers = []
                for container in pod["spec"].get("containers", []):
                    containers.append({
                        "name": container["name"],
                        "image": container["image"].split("/")[-1].split(":")[0]  # Just the image name
                    })
                
                ready_containers = 0
                total_containers = len(containers)
                if pod.get("status", {}).get("containerStatuses"):
                    for status in pod["status"]["containerStatuses"]:
                        if status.get("ready", False):
                            ready_containers += 1
                
                self.pods.append({
                    "name": pod["metadata"]["name"],
                    "labels": pod["metadata"].get("labels", {}),
                    "containers": containers,
                    "ready": f"{ready_containers}/{total_containers}",
                    "status": pod["status"]["phase"]
                })
    
    def collect_all_data(self):
        """Collect all network topology data"""
        print("🔍 Collecting network topology data...")
        self.get_routes()
        self.get_gateways()
        self.get_httproutes()
        self.get_services()
        self.get_pods()
        print(f"✅ Found: {len(self.routes)} routes, {len(self.gateways)} gateways, {len(self.httproutes)} httproutes, {len(self.services)} services, {len(self.pods)} pods")
    
    def find_service_pods(self, service_name: str) -> List[Dict]:
        """Find pods that match a service's selector"""
        service = next((s for s in self.services if s["name"] == service_name), None)
        if not service or not service["selector"]:
            return []
        
        matching_pods = []
        for pod in self.pods:
            # Check if all service selector labels match pod labels
            if all(pod["labels"].get(k) == v for k, v in service["selector"].items()):
                matching_pods.append(pod)
        
        return matching_pods
    
    def draw_ascii_diagram(self):
        """Draw the complete network topology as ASCII art"""
        print("\n" + "="*80)
        print("🌐 GATEWAY API NETWORK TOPOLOGY DIAGRAM")
        print("="*80)
        
        # Header with namespace info
        print(f"📍 Namespace: {self.namespace}")
        print(f"⏰ Generated: {subprocess.run(['date'], capture_output=True, text=True).stdout.strip()}")
        print()
        
        # Draw the topology layers
        self.draw_external_traffic()
        self.draw_openshift_routes()
        self.draw_gateways()
        self.draw_httproutes()
        self.draw_services_and_pods()
        
        print("="*80)
        print("🎯 Legend:")
        print("  📡 External Traffic    🛣️  OpenShift Route    🚪 Gateway API")
        print("  🔀 HTTPRoute          🎯 Service           🐳 Pod")
        print("  ⚡ LoadBalancer       🔒 TLS Termination   🔀 Path Routing")
        print("="*80)
    
    def draw_external_traffic(self):
        """Draw external traffic entry point"""
        print("📡 EXTERNAL TRAFFIC")
        print("     │")
        print("     │ HTTPS/HTTP")
        print("     ▼")
        print("┌─────────────────────┐")
        print("│   OpenShift Router  │")
        print("│   (HAProxy/Envoy)   │")
        print("└─────────────────────┘")
        print("     │")
        print("     │ TLS Passthrough")
        print("     ▼")
    
    def draw_openshift_routes(self):
        """Draw OpenShift Routes section"""
        print("🛣️  OPENSHIFT ROUTES (TinyLB Managed)")
        
        for route in self.routes:
            tls_info = f"🔒 {route['tls']}" if route['tls'] != 'none' else "🔓 HTTP"
            route_name = route['name'][:35] + "..." if len(route['name']) > 35 else route['name']
            route_host = route['host'][:45] + "..." if len(route['host']) > 45 else route['host']
            
            print(f"┌─────────────────────────────────────────────────────────────────────────┐")
            print(f"│ Route: {route_name:<50}                     │")
            print(f"│ Host:  {route_host:<50}                     │") 
            print(f"│ TLS:   {tls_info:<50}                     │")
            print(f"│ Port:  {route['target_port']:<50}                     │")
            print(f"└─────────────────────────────────────────────────────────────────────────┘")
            print("     │")
            print("     │ Forwards to LoadBalancer Service")
            print("     ▼")
    
    def draw_gateways(self):
        """Draw Gateway API Gateways"""
        print("🚪 GATEWAY API GATEWAYS")
        
        for gateway in self.gateways:
            status_icon = "✅" if gateway['status'] == 'Programmed' else "❌"
            gateway_name = gateway['name'][:20] + "..." if len(gateway['name']) > 20 else gateway['name']
            gateway_class = gateway['class'][:25] + "..." if len(gateway['class']) > 25 else gateway['class']
            
            print(f"┌─────────────────────────────────────────────────────────────────────────┐")
            print(f"│ Gateway: {gateway_name:<23} Status: {status_icon} {gateway['status']:<15}     │")
            print(f"│ Class:   {gateway_class:<28}                                        │")
            print(f"│ Listeners:                                                              │")
            
            for listener in gateway['listeners']:
                proto_icon = "🔒" if listener['protocol'] == 'HTTPS' else "🔓"
                listener_name = listener['name'][:10] + "..." if len(listener['name']) > 10 else listener['name']
                hostname = listener['hostname'][:25] + "..." if len(listener['hostname']) > 25 else listener['hostname']
                print(f"│   {proto_icon} {listener_name:<13} {listener['protocol']:<6} :{listener['port']:<5} {hostname:<28}    │")
            
            print(f"└─────────────────────────────────────────────────────────────────────────┘")
            print("     │")
            print("     │ Routes traffic via")
            print("     ▼")
    
    def draw_httproutes(self):
        """Draw HTTPRoute resources"""
        print("🔀 HTTPROUTE RESOURCES")
        
        for httproute in self.httproutes:
            route_name = httproute['name'][:25] + "..." if len(httproute['name']) > 25 else httproute['name']
            gateway_name = httproute['gateway'][:25] + "..." if len(httproute['gateway']) > 25 else httproute['gateway']
            hostnames = ', '.join(httproute['hostnames'])
            hostnames_display = hostnames[:35] + "..." if len(hostnames) > 35 else hostnames
            
            print(f"┌─────────────────────────────────────────────────────────────────────────┐")
            print(f"│ HTTPRoute: {route_name:<28}                                      │")
            print(f"│ Gateway:   {gateway_name:<28}                                      │")
            print(f"│ Hostnames: {hostnames_display:<28}                                      │")
            print(f"│ Routing Rules:                                                          │")
            
            for i, rule in enumerate(httproute['rules'], 1):
                for match in rule['matches']:
                    match_icon = "🎯" if match['type'] == 'Exact' else "🔀"
                    path_display = match['path'][:15] + "..." if len(match['path']) > 15 else match['path']
                    type_display = match['type'][:12] + "..." if len(match['type']) > 12 else match['type']
                    
                    backends = [b['name'] for b in rule['backends']]
                    backends_display = ', '.join(backends)
                    backends_display = backends_display[:25] + "..." if len(backends_display) > 25 else backends_display
                    
                    print(f"│   {match_icon} {path_display:<18} ({type_display:<15}) → {backends_display:<25}   │")
            
            print(f"└─────────────────────────────────────────────────────────────────────────┘")
            print("     │")
            print("     │ Forwards to backend services")
            print("     ▼")
    
    def draw_services_and_pods(self):
        """Draw Services and their associated Pods"""
        print("🎯 SERVICES & PODS")
        
        # Group services by type
        backend_services = [s for s in self.services if s['name'] != 'kubernetes']
        
        for service in backend_services:
            service_pods = self.find_service_pods(service['name'])
            
            service_name = service['name'][:25] + "..." if len(service['name']) > 25 else service['name']
            service_type = service['type'][:15] + "..." if len(service['type']) > 15 else service['type']
            
            print(f"┌─────────────────────────────────────────────────────────────────────────┐")
            print(f"│ Service: {service_name:<28} Type: {service_type:<18}         │")
            
            for port in service['ports']:
                print(f"│   Port: {port['port']:<5} → {port['target_port']:<5} ({port['protocol']})                                    │")
            
            print(f"│ Pods:                                                                   │")
            
            if service_pods:
                for pod in service_pods:
                    status_icon = "✅" if pod['status'] == 'Running' else "❌"
                    container_info = f"({pod['ready']})"
                    pod_name = pod['name'][:35] + "..." if len(pod['name']) > 35 else pod['name']
                    
                    print(f"│   🐳 {pod_name:<38} {status_icon} {pod['status']:<10} {container_info:<8} │")
                    
                    for container in pod['containers']:
                        sidecar_icon = "🔒" if container['name'] == 'istio-proxy' else "🎯"
                        container_name = container['name'][:15] + "..." if len(container['name']) > 15 else container['name']
                        container_image = container['image'][:20] + "..." if len(container['image']) > 20 else container['image']
                        print(f"│      {sidecar_icon} {container_name:<18} ({container_image:<23})            │")
            else:
                print(f"│   ❌ No pods found                                                      │")
            
            print(f"└─────────────────────────────────────────────────────────────────────────┘")
            print()
    
    def draw_traffic_flow_summary(self):
        """Draw a summary of the traffic flow"""
        print("🔄 TRAFFIC FLOW SUMMARY")
        print("┌─────────────────────────────────────────────────────────────────────────┐")
        print("│ 1. External Client → OpenShift Router (HAProxy/Envoy)                  │")
        print("│ 2. Router → TinyLB Route (TLS Passthrough)                             │")
        print("│ 3. TinyLB Route → Gateway API Gateway (LoadBalancer Service)           │")
        print("│ 4. Gateway → HTTPRoute (Path-based routing rules)                      │")
        print("│ 5. HTTPRoute → Backend Services (Service discovery)                    │")
        print("│ 6. Services → Pods (Container endpoints)                               │")
        print("│ 7. Pod → App Container + Istio Proxy (Service Mesh mTLS)               │")
        print("└─────────────────────────────────────────────────────────────────────────┘")
    
    def generate_diagram(self):
        """Generate the complete network diagram"""
        self.collect_all_data()
        self.draw_ascii_diagram()
        self.draw_traffic_flow_summary()
        
        # Summary statistics
        print(f"\n📊 TOPOLOGY STATISTICS")
        print(f"   Routes: {len(self.routes)}")
        print(f"   Gateways: {len(self.gateways)}")
        print(f"   HTTPRoutes: {len(self.httproutes)}")
        print(f"   Services: {len(self.services)}")
        print(f"   Pods: {len(self.pods)}")
        
        # Show routing rules count
        total_rules = sum(len(hr['rules']) for hr in self.httproutes)
        print(f"   Routing Rules: {total_rules}")
        
        # Show container count
        total_containers = sum(len(pod['containers']) for pod in self.pods)
        print(f"   Containers: {total_containers}")

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate Gateway API network topology diagram')
    parser.add_argument('-n', '--namespace', default='echo-test', 
                       help='Kubernetes namespace to analyze (default: echo-test)')
    parser.add_argument('-o', '--output', help='Output file (default: stdout)')
    
    args = parser.parse_args()
    
    # Create diagram builder
    builder = NetworkDiagramBuilder(namespace=args.namespace)
    
    # Generate and display diagram
    if args.output:
        import contextlib
        with open(args.output, 'w') as f:
            with contextlib.redirect_stdout(f):
                builder.generate_diagram()
        print(f"✅ Network diagram saved to {args.output}")
    else:
        builder.generate_diagram()

if __name__ == "__main__":
    main() 