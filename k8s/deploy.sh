#!/bin/bash

# STCS Data Architecture - GKE Autopilot Deployment Script
# This script deploys the complete data architecture stack to GKE

set -e

echo "========================================"
echo "STCS Data Architecture - GKE Deployment"
echo "========================================"

# Configuration
NAMESPACE="stcs"
CLUSTER_NAME="your-gke-cluster"  # Replace with your cluster name
REGION="us-central1"             # Replace with your region
PROJECT_ID="your-project-id"     # Replace with your GCP project ID

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install Google Cloud SDK first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Connect to GKE cluster
connect_cluster() {
    print_status "Connecting to GKE cluster..."
    
    # Get cluster credentials
    gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        print_success "Connected to GKE cluster successfully"
    else
        print_error "Failed to connect to GKE cluster"
        exit 1
    fi
}

# Deploy infrastructure components
deploy_infrastructure() {
    print_status "Deploying infrastructure components..."
    
    # Create namespace
    print_status "Creating namespace..."
    kubectl apply -f namespace.yaml
    
    # Apply secrets
    print_status "Creating secrets..."
    kubectl apply -f secrets/
    
    # Apply ConfigMaps
    print_status "Creating ConfigMaps..."
    kubectl apply -f configmaps/
    
    print_success "Infrastructure components deployed"
}

# Deploy services
deploy_services() {
    print_status "Deploying services..."
    
    # Deploy PostgreSQL (metadata storage)
    print_status "Deploying PostgreSQL..."
    kubectl apply -f deployments/postgres-cube.yaml
    
    # Wait for PostgreSQL to be ready
    print_status "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/postgres-cube -n $NAMESPACE
    
    # Deploy Trino coordinator
    print_status "Deploying Trino coordinator..."
    kubectl apply -f deployments/trino-coordinator.yaml
    
    # Wait for Trino to be ready
    print_status "Waiting for Trino to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/trino-coordinator -n $NAMESPACE
    
    # Deploy Cube.js
    print_status "Deploying Cube.js..."
    kubectl apply -f deployments/cube.yaml
    
    # Wait for Cube.js to be ready
    print_status "Waiting for Cube.js to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/cube -n $NAMESPACE
    
    print_success "All services deployed successfully"
}

# Deploy ingress and load balancers
deploy_networking() {
    print_status "Deploying networking components..."
    
    # Deploy ingress and load balancers
    kubectl apply -f ingress/
    
    print_success "Networking components deployed"
}

# Get service endpoints
get_endpoints() {
    print_status "Getting service endpoints..."
    
    echo ""
    echo "========================================"
    echo "Service Endpoints"
    echo "========================================"
    
    # Get LoadBalancer IPs
    print_status "LoadBalancer Services:"
    kubectl get svc -n $NAMESPACE -o wide | grep LoadBalancer
    
    echo ""
    print_status "Internal Services:"
    kubectl get svc -n $NAMESPACE -o wide | grep ClusterIP
    
    echo ""
    print_status "Ingress:"
    kubectl get ingress -n $NAMESPACE
    
    echo ""
    print_warning "Note: LoadBalancer IPs may take a few minutes to be assigned."
    print_warning "Run 'kubectl get svc -n $NAMESPACE' to check status."
}

# Health check
health_check() {
    print_status "Performing health check..."
    
    # Check pod status
    echo ""
    print_status "Pod Status:"
    kubectl get pods -n $NAMESPACE
    
    # Check if all pods are running
    NOT_RUNNING=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    
    if [ $NOT_RUNNING -eq 0 ]; then
        print_success "All pods are running successfully"
    else
        print_warning "Some pods are not in Running state. Check with: kubectl get pods -n $NAMESPACE"
    fi
}

# Main deployment function
main() {
    print_status "Starting STCS Data Architecture deployment to GKE Autopilot..."
    
    # Change to k8s directory
    cd "$(dirname "$0")"
    
    # Run deployment steps
    check_prerequisites
    connect_cluster
    deploy_infrastructure
    deploy_services
    deploy_networking
    
    # Wait a moment for services to initialize
    print_status "Waiting for services to initialize..."
    sleep 30
    
    get_endpoints
    health_check
    
    echo ""
    echo "========================================"
    echo "Deployment Complete!"
    echo "========================================"
    echo ""
    print_success "STCS Data Architecture has been deployed to GKE Autopilot"
    echo ""
    print_status "Next Steps:"
    echo "1. Wait for LoadBalancer IPs to be assigned (5-10 minutes)"
    echo "2. Update DNS records to point to the LoadBalancer IPs"
    echo "3. Test the endpoints once they're accessible"
    echo "4. Configure Sigma Computing to connect to the SQL API"
    echo ""
    print_status "Useful Commands:"
    echo "  kubectl get pods -n $NAMESPACE                 # Check pod status"
    echo "  kubectl get svc -n $NAMESPACE                  # Check service status"
    echo "  kubectl logs -f deployment/cube -n $NAMESPACE  # Check Cube.js logs"
    echo "  kubectl logs -f deployment/trino-coordinator -n $NAMESPACE # Check Trino logs"
    echo ""
}

# Run main function
main "$@"