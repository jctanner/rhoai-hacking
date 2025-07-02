#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="odh-minimal"
NAMESPACE="default"
TIMEOUT_SECONDS=300

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

# Utility functions
wait_for_deployment() {
    local name=$1
    local namespace=${2:-default}
    local timeout=${3:-300}
    
    log_info "Waiting for deployment '$name' to be ready..."
    kubectl wait --for=condition=available --timeout=${timeout}s deployment/$name -n $namespace
}

wait_for_pods() {
    local selector=$1
    local namespace=${2:-default}
    local timeout=${3:-300}
    
    log_info "Waiting for pods with selector '$selector' to be ready..."
    kubectl wait --for=condition=ready --timeout=${timeout}s pods -l $selector -n $namespace
}

wait_for_crd() {
    local crd_name=$1
    local timeout=${2:-60}
    
    log_info "Waiting for CRD '$crd_name' to be available..."
    local count=0
    while ! kubectl get crd $crd_name >/dev/null 2>&1; do
        if [ $count -ge $timeout ]; then
            log_error "Timeout waiting for CRD $crd_name"
            return 1
        fi
        sleep 1
        ((count++))
    done
    log_success "CRD '$crd_name' is available"
}

check_prerequisites() {
    log_step "Checking Prerequisites"
    
    # Check if required tools are installed
    for tool in kind kubectl podman; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check if Podman is running
    if ! podman info >/dev/null 2>&1; then
        log_error "Podman is not running or not configured properly"
        exit 1
    fi
    
    log_success "All prerequisites are met"
}

create_cluster() {
    log_step "Creating KIND Cluster"
    
    # Delete existing cluster if it exists
    if kind get clusters | grep -q $CLUSTER_NAME; then
        log_info "Deleting existing cluster '$CLUSTER_NAME'"
        kind delete cluster --name $CLUSTER_NAME
    fi
    
    # Create new cluster
    log_info "Creating cluster '$CLUSTER_NAME'"
    kind create cluster --name $CLUSTER_NAME
    
    # Verify cluster is ready
    kubectl cluster-info --context kind-$CLUSTER_NAME
    log_success "Cluster '$CLUSTER_NAME' created and ready"
}

deploy_gateway_operator() {
    log_step "Deploying ODH Gateway Operator"
    
    cd src/odh-gateway-operator
    
    # Generate manifests and install CRDs
    log_info "Generating manifests and installing CRDs"
    make manifests generate install
    
    # Wait for CRDs to be available
    wait_for_crd "odhgateways.gateway.opendatahub.io"
    
    # Build and push image to registry
    log_info "Building and pushing operator image"
    make publish IMG=registry.tannerjc.net/odh-gateway-operator:latest
    
    # Deploy operator
    log_info "Deploying operator"
    make deploy IMG=registry.tannerjc.net/odh-gateway-operator:latest
    
    # Wait for operator to be ready
    wait_for_deployment "odh-gateway-operator-controller-manager" "odh-gateway-operator-system"
    
    cd ../..
    log_success "ODH Gateway Operator deployed successfully"
}

deploy_notebook_operator() {
    log_step "Deploying Notebook Operator"
    
    cd src/notebook-operator
    
    # Generate manifests and install CRDs
    log_info "Generating manifests and installing CRDs"
    make manifests generate install
    
    # Wait for CRDs to be available
    wait_for_crd "notebooks.ds.example.com"
    
    # Build and push image to registry
    log_info "Building and pushing operator image"
    make publish IMG=registry.tannerjc.net/notebook-operator:latest
    
    # Deploy operator
    log_info "Deploying operator"
    make deploy IMG=registry.tannerjc.net/notebook-operator:latest
    
    # Wait for operator to be ready
    wait_for_deployment "notebook-operator-controller-manager" "notebook-operator-system"
    
    cd ../..
    log_success "Notebook Operator deployed successfully"
}

deploy_dashboard() {
    log_step "Deploying ODH Dashboard"
    
    cd src/odh-dashboard
    
    # Build and push image to registry
    log_info "Building and pushing dashboard image"
    make publish IMAGE_TAG=latest
    
    # Deploy dashboard
    log_info "Deploying dashboard"
    make deploy
    
    # Wait for dashboard to be ready
    wait_for_deployment "odh-dashboard"
    
    cd ../..
    log_success "ODH Dashboard deployed successfully"
}

create_sample_resources() {
    log_step "Creating Sample Resources"
    
    # Create ODH Gateway instance
    log_info "Creating ODH Gateway instance"
    kubectl apply -f configs/gateway-oidc.yaml
    
    # Wait a bit for the gateway to be processed
    sleep 10
    
    # Create sample notebooks
    log_info "Creating sample notebooks"
    kubectl apply -f configs/nb2.yaml
    kubectl apply -f configs/nb3.yaml
    kubectl apply -f configs/nb4.yaml
    
    # Wait for notebooks to be ready
    sleep 15
    
    log_success "Sample resources created"
}

verify_deployment() {
    log_step "Verifying Deployment"
    
    # Check operators
    log_info "Checking operators status"
    kubectl get deployments -A | grep -E "(gateway-operator|notebook-operator)"
    
    # Check dashboard
    log_info "Checking dashboard status"
    kubectl get pods -l app=odh-dashboard
    kubectl get svc odh-dashboard-svc
    
    # Check ODH Gateway instance
    log_info "Checking ODH Gateway instance"
    kubectl get odhgateways
    kubectl get pods,svc -l app=odhgateway-sample
    
    # Check notebooks
    log_info "Checking notebooks"
    kubectl get notebooks
    kubectl get pods -l app=notebook
    
    # Check services discovered by gateway
    log_info "Checking services with gateway annotations"
    kubectl get svc -A -o jsonpath='{range .items[?(@.metadata.annotations.odhgateway\.opendatahub\.io/enabled=="true")]}{.metadata.name}{" ("}{.metadata.annotations.odhgateway\.opendatahub\.io/route-path}{")"}{"\n"}{end}'
    
    log_success "Deployment verification complete"
}

display_access_info() {
    log_step "Access Information"
    
    echo -e "\n${GREEN}🎉 ODH Gateway System Deployed Successfully! 🎉${NC}\n"
    
    echo -e "${BLUE}To access your services:${NC}"
    echo -e "1. Port forward the gateway service:"
    echo -e "   ${YELLOW}kubectl port-forward svc/odhgateway-sample-svc 8080:80${NC}"
    echo -e ""
    echo -e "2. Access the dashboard:"
    echo -e "   ${YELLOW}http://localhost:8080${NC}"
    echo -e ""
    echo -e "3. Access notebooks directly:"
    echo -e "   ${YELLOW}http://localhost:8080/notebooks/notebook-sample2${NC}"
    echo -e "   ${YELLOW}http://localhost:8080/notebooks/notebook-sample3${NC}"
    echo -e "   ${YELLOW}http://localhost:8080/notebooks/notebook-sample4${NC}"
    echo -e ""
    echo -e "${BLUE}Useful commands:${NC}"
    echo -e "• View all resources: ${YELLOW}kubectl get all -A${NC}"
    echo -e "• Check gateway config: ${YELLOW}kubectl get configmap odhgateway-sample-routes -o yaml${NC}"
    echo -e "• View operator logs: ${YELLOW}kubectl logs -n odh-gateway-operator-system deployment/odh-gateway-operator-controller-manager${NC}"
    echo -e "• Port forward dashboard directly: ${YELLOW}kubectl port-forward svc/odh-dashboard-svc 5000:80${NC}"
}

cleanup() {
    log_step "Cleanup on Exit"
    log_info "Cleaning up any temporary files..."
    # No cleanup needed - we're using registry-based deployment
}

# Set up cleanup trap
trap cleanup EXIT

# Main execution
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    ODH Gateway Deployment                   ║"
    echo "║                    Complete System Setup                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_prerequisites
    create_cluster
    deploy_gateway_operator
    deploy_notebook_operator
    deploy_dashboard
    create_sample_resources
    verify_deployment
    display_access_info
    
    log_success "All done! 🚀"
}

# Handle command line arguments
case "${1:-}" in
    "cluster")
        create_cluster
        ;;
    "operators")
        deploy_gateway_operator
        deploy_notebook_operator
        ;;
    "dashboard")
        deploy_dashboard
        ;;
    "samples")
        create_sample_resources
        ;;
    "verify")
        verify_deployment
        ;;
    "clean")
        log_info "Deleting cluster '$CLUSTER_NAME'"
        kind delete cluster --name $CLUSTER_NAME
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (no args)  - Deploy everything (default)"
        echo "  cluster    - Create KIND cluster only"
        echo "  operators  - Deploy operators only"
        echo "  dashboard  - Deploy dashboard only"
        echo "  samples    - Create sample resources only"
        echo "  verify     - Verify deployment"
        echo "  clean      - Delete cluster"
        echo "  help       - Show this help"
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown command: $1"
        log_info "Use '$0 help' for usage information"
        exit 1
        ;;
esac 