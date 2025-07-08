#!/usr/bin/env python3

import subprocess
import json
import sys
from typing import Dict, List, Optional, Tuple

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.tree import Tree
    from rich.columns import Columns
    from rich.text import Text
    from rich.layout import Layout
    from rich.align import Align
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.live import Live
    from rich.markdown import Markdown
except ImportError:
    print("❌ Rich library not found. Please install it with: pip install rich")
    sys.exit(1)

class RichNetworkDiagram:
    def __init__(self, namespace: str = "echo-test"):
        self.namespace = namespace
        self.console = Console()
        self.routes = []
        self.gateways = []
        self.httproutes = []
        self.services = []
        self.pods = []
        self.secrets = []
        self.peer_auth = []
        
    def run_oc_command(self, cmd: List[str]) -> Optional[str]:
        """Run oc command and return output"""
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            self.console.print(f"[red]Error running command {' '.join(cmd)}: {e}[/red]")
            return None
    
    def collect_data_with_progress(self):
        """Collect all data with a progress indicator"""
        tasks = [
            ("Collecting Routes", self.get_routes),
            ("Collecting Gateways", self.get_gateways),
            ("Collecting HTTPRoutes", self.get_httproutes),
            ("Collecting Services", self.get_services),
            ("Collecting Pods", self.get_pods),
            ("Collecting TLS Secrets", self.get_secrets),
            ("Collecting Security Policies", self.get_peer_auth)
        ]
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=self.console,
            transient=True
        ) as progress:
            for task_name, task_func in tasks:
                task = progress.add_task(task_name, total=1)
                task_func()
                progress.update(task, advance=1)
    
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
                        "image": container["image"]
                    })
                
                ready_containers = 0
                total_containers = len(containers)
                if pod.get("status", {}).get("containerStatuses"):
                    for status in pod["status"]["containerStatuses"]:
                        if status.get("ready", False):
                            ready_containers += 1
                
                # Check if pod has Istio sidecar
                has_istio = any(c["name"] == "istio-proxy" for c in containers)
                
                self.pods.append({
                    "name": pod["metadata"]["name"],
                    "labels": pod["metadata"].get("labels", {}),
                    "containers": containers,
                    "ready": f"{ready_containers}/{total_containers}",
                    "status": pod["status"]["phase"],
                    "has_istio": has_istio
                })
    
    def get_secrets(self):
        """Get TLS secrets"""
        cmd = ["oc", "get", "secrets", "-n", self.namespace, "-o", "json"]
        output = self.run_oc_command(cmd)
        if output:
            data = json.loads(output)
            for secret in data.get("items", []):
                if secret.get("type") == "kubernetes.io/tls":
                    self.secrets.append({
                        "name": secret["metadata"]["name"],
                        "type": secret["type"],
                        "data_keys": list(secret.get("data", {}).keys())
                    })
    
    def get_peer_auth(self):
        """Get PeerAuthentication policies"""
        cmd = ["oc", "get", "peerauthentication", "-n", self.namespace, "-o", "json"]
        output = self.run_oc_command(cmd)
        if output:
            data = json.loads(output)
            for policy in data.get("items", []):
                mtls_mode = policy.get("spec", {}).get("mtls", {}).get("mode", "PERMISSIVE")
                self.peer_auth.append({
                    "name": policy["metadata"]["name"],
                    "mtls_mode": mtls_mode,
                    "selector": policy.get("spec", {}).get("selector", {})
                })
    
    def find_service_pods(self, service_name: str) -> List[Dict]:
        """Find pods that match a service's selector"""
        service = next((s for s in self.services if s["name"] == service_name), None)
        if not service or not service["selector"]:
            return []
        
        matching_pods = []
        for pod in self.pods:
            if all(pod["labels"].get(k) == v for k, v in service["selector"].items()):
                matching_pods.append(pod)
        
        return matching_pods
    
    def create_header(self):
        """Create the header panel"""
        # Get security summary
        istio_pods = sum(1 for pod in self.pods if pod.get('has_istio', False))
        mtls_mode = "PERMISSIVE"
        for policy in self.peer_auth:
            if policy['name'] == 'default':
                mtls_mode = policy['mtls_mode']
                break
        
        gateway_tls = any(
            any(l['protocol'] == 'HTTPS' for l in gw['listeners'])
            for gw in self.gateways
        )
        
        header_text = f"""
🌐 **Gateway API Network Topology**

📍 **Namespace:** {self.namespace}
📊 **Resources:** {len(self.routes)} routes, {len(self.gateways)} gateways, {len(self.httproutes)} httproutes, {len(self.services)} services, {len(self.pods)} pods
🔒 **Security:** {mtls_mode} mTLS, {istio_pods}/{len(self.pods)} pods with Istio, {"HTTPS" if gateway_tls else "HTTP"} Gateway
⏰ **Generated:** {subprocess.run(['date'], capture_output=True, text=True).stdout.strip()}
        """
        return Panel(
            Align.center(Markdown(header_text)),
            title="🚪 Gateway API Topology Viewer",
            border_style="bright_blue",
            padding=(1, 2)
        )
    
    def create_traffic_flow_panel(self):
        """Create traffic flow diagram with security details"""
        # Determine TLS termination points
        gateway_tls = any(
            any(l['protocol'] == 'HTTPS' for l in gw['listeners'])
            for gw in self.gateways
        )
        
        mtls_mode = "PERMISSIVE"
        for policy in self.peer_auth:
            if policy['name'] == 'default':
                mtls_mode = policy['mtls_mode']
                break
        
        # Find LoadBalancer service info
        lb_services = [s for s in self.services if s['type'] == 'LoadBalancer']
        lb_service_info = ""
        if lb_services:
            lb_service = lb_services[0]  # Usually there's one Gateway LB service
            ports_info = []
            for port in lb_service['ports']:
                if port['port'] in [80, 443]:
                    ports_info.append(f"{port['port']}→{port['target_port']}")
            lb_service_info = f" ({', '.join(ports_info)})" if ports_info else ""
        
        tls_cert_info = ""
        if self.secrets:
            tls_cert_info = f"\n🔑 TLS Certificates: {', '.join(s['name'] for s in self.secrets)}"
        
        flow_text = f"""
🔄 **Traffic Flow & Security**

```
📡 External Client
    ↓ HTTPS/HTTP (Port 80/443)
🛣️  OpenShift Router (HAProxy/Envoy)
    ↓ TLS Passthrough (No termination) 
⚡ LoadBalancer Service (echo-gateway-istio{lb_service_info})
    ↓ Port forwarding (TinyLB managed)
🚪 Gateway API Gateway (Istio Gateway pods)
    ↓ {"🔒 HTTPS Termination" if gateway_tls else "🔓 HTTP Only"} 
🔀 HTTPRoute Rules
    ↓ Path-based Routing + Port Selection
🎯 Backend Services (Port 80 → 8080)
    ↓ {"🔒 Istio mTLS (" + mtls_mode + ")" if mtls_mode != "PERMISSIVE" else "🔓 mTLS Optional"}
🐳 Application Pods
    ↓ Istio Proxy (15001) + App Container (8080)
🔒 {"STRICT mTLS" if mtls_mode == "STRICT" else "Optional mTLS"} Communication
```{tls_cert_info}

**🔗 TinyLB Architecture:**
• TinyLB detects LoadBalancer services in <pending> state
• Creates OpenShift Route pointing to LoadBalancer service
• LoadBalancer service forwards to Gateway API Gateway pods
• Gateway implements actual routing logic via HTTPRoutes
        """
        return Panel(
            Markdown(flow_text),
            title="🔄 Traffic Flow & Security",
            border_style="bright_green"
        )
    
    def create_routes_table(self):
        """Create routes table"""
        table = Table(title="🛣️ OpenShift Routes (TinyLB Managed)")
        table.add_column("Name", style="cyan")
        table.add_column("Host", style="magenta")
        table.add_column("TLS", style="green")
        table.add_column("Port", style="yellow")
        table.add_column("Target Service", style="blue")
        
        for route in self.routes:
            tls_display = f"🔒 {route['tls']}" if route['tls'] != 'none' else "🔓 HTTP"
            table.add_row(
                route['name'],
                route['host'],
                tls_display,
                str(route['target_port']),
                route['service']
            )
        
        return table
    
    def create_gateways_table(self):
        """Create gateways table"""
        table = Table(title="🚪 Gateway API Gateways")
        table.add_column("Name", style="cyan")
        table.add_column("Class", style="magenta")
        table.add_column("Status", style="green")
        table.add_column("Listeners", style="yellow")
        
        for gateway in self.gateways:
            status_display = "✅ Programmed" if gateway['status'] == 'Programmed' else "❌ " + gateway['status']
            
            listeners_info = []
            for listener in gateway['listeners']:
                proto_icon = "🔒" if listener['protocol'] == 'HTTPS' else "🔓"
                listeners_info.append(f"{proto_icon} {listener['name']}:{listener['port']}")
            
            table.add_row(
                gateway['name'],
                gateway['class'],
                status_display,
                "\n".join(listeners_info)
            )
        
        return table
    
    def create_httproutes_table(self):
        """Create HTTPRoutes table with port and TLS details"""
        table = Table(title="🔀 HTTPRoute Resources")
        table.add_column("Name", style="cyan")
        table.add_column("Gateway", style="magenta")
        table.add_column("Hostnames", style="green")
        table.add_column("Routing Rules", style="yellow")
        table.add_column("Backend Ports", style="blue")
        table.add_column("mTLS Policy", style="bright_red")
        table.add_column("Backend Security", style="red")
        
        # Get mTLS policy once for all routes
        mtls_mode = "PERMISSIVE"
        for policy in self.peer_auth:
            if policy['name'] == 'default':
                mtls_mode = policy['mtls_mode']
                break
        
        for httproute in self.httproutes:
            routing_rules = []
            backend_ports = []
            tls_info = []
            
            for rule in httproute['rules']:
                for match in rule['matches']:
                    match_icon = "🎯" if match['type'] == 'Exact' else "🔀"
                    backends = []
                    ports = []
                    
                    for backend in rule['backends']:
                        backends.append(backend['name'])
                        ports.append(f"{backend['name']}:{backend['port']}")
                        
                        # Check if backend service has Istio sidecar
                        backend_pods = self.find_service_pods(backend['name'])
                        has_istio = any(pod.get('has_istio', False) for pod in backend_pods)
                        
                        if has_istio:
                            tls_info.append(f"🔒 {backend['name']}")
                        else:
                            tls_info.append(f"🔓 {backend['name']}")
                    
                    routing_rules.append(f"{match_icon} {match['path']} → {', '.join(backends)}")
                    backend_ports.extend(ports)
            
            # Format policy display
            policy_icon = "🔒" if mtls_mode == "STRICT" else "🔓" if mtls_mode == "DISABLE" else "⚠️"
            policy_display = f"{policy_icon} {mtls_mode}"
            
            table.add_row(
                httproute['name'],
                httproute['gateway'],
                ", ".join(httproute['hostnames']),
                "\n".join(routing_rules),
                "\n".join(backend_ports),
                policy_display,
                "\n".join(tls_info)
            )
        
        return table
    
    def create_services_tree(self):
        """Create services and pods tree"""
        tree = Tree("🎯 Services & Pods")
        
        # Separate Gateway infrastructure from backend services
        lb_services = [s for s in self.services if s['type'] == 'LoadBalancer']
        backend_services = [s for s in self.services if s['type'] != 'LoadBalancer']
        
        # Add Gateway Infrastructure section
        if lb_services:
            gateway_node = tree.add("⚡ [bold yellow]Gateway Infrastructure[/bold yellow]")
            for service in lb_services:
                service_node = gateway_node.add(f"⚡ [bold cyan]{service['name']}[/bold cyan] ({service['type']})")
                self._add_service_details(service, service_node)
        
        # Add Backend Services section
        if backend_services:
            backend_node = tree.add("🎯 [bold green]Backend Services[/bold green]")
            for service in backend_services:
                service_node = backend_node.add(f"🎯 [bold cyan]{service['name']}[/bold cyan] ({service['type']})")
                self._add_service_details(service, service_node)
        
        return tree
    
    def _add_service_details(self, service, service_node):
        """Add port and pod details to a service node"""
        # Add port information with TLS details
        ports_info = []
        for port in service['ports']:
            if port['port'] == 443:
                ports_info.append(f"🔒 {port['port']}→{port['target_port']}/{port['protocol']} (HTTPS)")
            elif port['port'] == 80:
                ports_info.append(f"🔓 {port['port']}→{port['target_port']}/{port['protocol']} (HTTP)")
            elif port['port'] == 15021:
                ports_info.append(f"🔧 {port['port']}→{port['target_port']}/{port['protocol']} (Istio Health)")
            else:
                ports_info.append(f"📋 {port['port']}→{port['target_port']}/{port['protocol']}")
        
        if ports_info:
            service_node.add(f"📋 Ports: {', '.join(ports_info)}")
        
        # Add special note for LoadBalancer services
        if service['type'] == 'LoadBalancer':
            service_node.add("🔗 TinyLB managed (Route → LoadBalancer → Gateway pods)")
        
        # Add pods with security info
        service_pods = self.find_service_pods(service['name'])
        if service_pods:
            pods_node = service_node.add(f"🐳 Pods ({len(service_pods)})")
            for pod in service_pods:
                status_icon = "✅" if pod['status'] == 'Running' else "❌"
                istio_icon = "🔒" if pod.get('has_istio', False) else "🔓"
                pod_node = pods_node.add(f"{status_icon} {istio_icon} [bold green]{pod['name']}[/bold green] ({pod['ready']})")
                
                # Add containers with detailed info
                for container in pod['containers']:
                    if container['name'] == 'istio-proxy':
                        container_icon = "🔒"
                        image_name = "istio-proxy"
                        pod_node.add(f"{container_icon} {container['name']} ({image_name}) - mTLS Sidecar")
                    else:
                        container_icon = "🎯"
                        image_name = container['image'].split('/')[-1].split(':')[0]
                        pod_node.add(f"{container_icon} {container['name']} ({image_name}) - Application")
        else:
            service_node.add("❌ No pods found")
    
    def create_security_panel(self):
        """Create security information panel"""
        # Count pods with Istio sidecars
        istio_pods = sum(1 for pod in self.pods if pod.get('has_istio', False))
        
        # Get mTLS policy info
        mtls_mode = "PERMISSIVE"
        for policy in self.peer_auth:
            if policy['name'] == 'default':
                mtls_mode = policy['mtls_mode']
                break
        
        # Check Gateway TLS
        gateway_tls = any(
            any(l['protocol'] == 'HTTPS' for l in gw['listeners'])
            for gw in self.gateways
        )
        
        # Check Route TLS
        route_tls = any(route['tls'] == 'passthrough' for route in self.routes)
        
        security_text = f"""
🔒 **Security Configuration**

• **mTLS Policy**: {mtls_mode}
• **Istio Sidecars**: {istio_pods}/{len(self.pods)} pods
• **Gateway TLS**: {"✅ HTTPS" if gateway_tls else "❌ HTTP Only"}
• **Route TLS**: {"✅ Passthrough" if route_tls else "❌ No TLS"}
• **TLS Certificates**: {len(self.secrets)}
• **Security Policies**: {len(self.peer_auth)}

**TLS Termination Points:**
• 🛣️ Router: Passthrough (no termination)
• 🚪 Gateway: {"HTTPS Termination" if gateway_tls else "None"}
• 🔒 Service Mesh: {mtls_mode} mTLS
        """
        
        return Panel(
            Markdown(security_text),
            title="🔒 Security",
            border_style="bright_red"
        )
    
    def create_statistics_panel(self):
        """Create statistics panel"""
        total_rules = sum(len(hr['rules']) for hr in self.httproutes)
        total_containers = sum(len(pod['containers']) for pod in self.pods)
        
        stats_text = f"""
📊 **Topology Statistics**

• **Routes**: {len(self.routes)}
• **Gateways**: {len(self.gateways)}
• **HTTPRoutes**: {len(self.httproutes)}
• **Services**: {len(self.services)}
• **Pods**: {len(self.pods)}
• **Routing Rules**: {total_rules}
• **Containers**: {total_containers}
        """
        
        return Panel(
            Markdown(stats_text),
            title="📈 Statistics",
            border_style="bright_yellow"
        )
    
    def create_legend_panel(self):
        """Create legend panel"""
        legend_text = """
🎯 **Legend**

• 📡 External Traffic
• 🛣️ OpenShift Route
• 🚪 Gateway API
• 🔀 HTTPRoute
• 🎯 Service
• 🐳 Pod
• ⚡ LoadBalancer
• 🔒 TLS/mTLS
• ✅ Running/Ready
• ❌ Failed/NotReady
        """
        
        return Panel(
            Markdown(legend_text),
            title="🗂️ Legend",
            border_style="bright_magenta"
        )
    
    def generate_diagram(self):
        """Generate the complete network diagram"""
        # Collect data
        self.collect_data_with_progress()
        
        # Create header
        self.console.print(self.create_header())
        self.console.print()
        
        # Create traffic flow
        self.console.print(self.create_traffic_flow_panel())
        self.console.print()
        
        # Create tables
        if self.routes:
            self.console.print(self.create_routes_table())
            self.console.print()
        
        if self.gateways:
            self.console.print(self.create_gateways_table())
            self.console.print()
        
        if self.httproutes:
            self.console.print(self.create_httproutes_table())
            self.console.print()
        
        # Create services tree
        self.console.print(self.create_services_tree())
        self.console.print()
        
        # Create bottom panels
        columns = Columns([
            self.create_security_panel(),
            self.create_statistics_panel(),
            self.create_legend_panel()
        ])
        self.console.print(columns)

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate Gateway API network topology diagram using Rich')
    parser.add_argument('-n', '--namespace', default='echo-test', 
                       help='Kubernetes namespace to analyze (default: echo-test)')
    parser.add_argument('-o', '--output', help='Output file (default: stdout)')
    parser.add_argument('--html', action='store_true', help='Generate HTML output')
    
    args = parser.parse_args()
    
    # Create diagram builder
    diagram = RichNetworkDiagram(namespace=args.namespace)
    
    # Generate diagram
    if args.output:
        if args.html:
            with open(args.output, 'w') as f:
                console = Console(file=f, record=True)
                diagram.console = console
                diagram.generate_diagram()
                f.write(console.export_html())
        else:
            with open(args.output, 'w') as f:
                console = Console(file=f, width=120)
                diagram.console = console
                diagram.generate_diagram()
        print(f"✅ Network diagram saved to {args.output}")
    else:
        diagram.generate_diagram()

if __name__ == "__main__":
    main() 