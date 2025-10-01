#!/bin/bash

# STCS Data Architecture - GKE Deployment Testing Script
# This script tests the deployed services on GKE

set -e

NAMESPACE="stcs"

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

# Test pod health
test_pod_health() {
    print_status "Testing pod health..."
    
    # Get pod status
    echo ""
    kubectl get pods -n $NAMESPACE
    
    # Check if all pods are running
    NOT_RUNNING=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    
    if [ $NOT_RUNNING -eq 0 ]; then
        print_success "All pods are running"
    else
        print_error "Some pods are not running"
        kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running
        return 1
    fi
}

# Test service connectivity
test_service_connectivity() {
    print_status "Testing service connectivity..."
    
    # Test Trino health endpoint
    print_status "Testing Trino health..."
    if kubectl exec deployment/trino-coordinator -n $NAMESPACE -- curl -f -s http://localhost:8080/v1/info > /dev/null; then
        print_success "Trino is healthy"
    else
        print_error "Trino health check failed"
        return 1
    fi
    
    # Test Cube.js health endpoint
    print_status "Testing Cube.js health..."
    if kubectl exec deployment/cube -n $NAMESPACE -- curl -f -s http://localhost:4000/cubejs-api/v1/meta > /dev/null; then
        print_success "Cube.js is healthy"
    else
        print_error "Cube.js health check failed"
        return 1
    fi
    
    # Test PostgreSQL connectivity
    print_status "Testing PostgreSQL connectivity..."
    if kubectl exec deployment/postgres-cube -n $NAMESPACE -- pg_isready -U cube > /dev/null; then
        print_success "PostgreSQL is healthy"
    else
        print_error "PostgreSQL health check failed"
        return 1
    fi
}

# Test inter-service communication
test_inter_service_communication() {
    print_status "Testing inter-service communication..."
    
    # Test Cube.js to Trino connection
    print_status "Testing Cube.js → Trino connection..."
    if kubectl exec deployment/cube -n $NAMESPACE -- curl -f -s http://trino-coordinator:8080/v1/info > /dev/null; then
        print_success "Cube.js can reach Trino"
    else
        print_error "Cube.js cannot reach Trino"
        return 1
    fi
}

# Test external database connectivity
test_external_database_connectivity() {
    print_status "Testing external database connectivity..."
    
    # Test PostgreSQL external database
    print_status "Testing external PostgreSQL connection..."
    TRINO_QUERY_RESULT=$(kubectl exec deployment/trino-coordinator -n $NAMESPACE -- \
        bash -c "echo 'SHOW CATALOGS' | trino --server localhost:8080 --user admin --execute-stdin" 2>/dev/null || echo "FAILED")
    
    if echo "$TRINO_QUERY_RESULT" | grep -q "postgresql"; then
        print_success "External PostgreSQL connection working"
    else
        print_warning "External PostgreSQL connection failed - check network/credentials"
    fi
    
    # Test Snowflake connection
    if echo "$TRINO_QUERY_RESULT" | grep -q "snowflake"; then
        print_success "External Snowflake connection working"
    else
        print_warning "External Snowflake connection failed - check network/credentials"
    fi
}

# Test Cube.js data models
test_cube_data_models() {
    print_status "Testing Cube.js data models..."
    
    # Get Cube.js metadata
    CUBE_META=$(kubectl exec deployment/cube -n $NAMESPACE -- \
        curl -s http://localhost:4000/cubejs-api/v1/meta 2>/dev/null || echo '{"cubes":[]}')
    
    CUBE_COUNT=$(echo "$CUBE_META" | grep -o '"name"' | wc -l)
    
    if [ $CUBE_COUNT -gt 0 ]; then
        print_success "Cube.js data models loaded successfully ($CUBE_COUNT cubes found)"
    else
        print_error "No Cube.js data models found"
        return 1
    fi
}

# Test LoadBalancer services
test_external_access() {
    print_status "Testing external access..."
    
    # Get LoadBalancer IPs
    echo ""
    print_status "LoadBalancer Services:"
    kubectl get svc -n $NAMESPACE -o wide | grep LoadBalancer
    
    # Check if external IPs are assigned
    PENDING_LBS=$(kubectl get svc -n $NAMESPACE -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer}' | grep -c "ingress" || echo "0")
    
    if [ $PENDING_LBS -gt 0 ]; then
        print_success "LoadBalancer IPs assigned"
        
        # Test external access to Cube.js
        CUBE_LB_IP=$(kubectl get svc cube-lb -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ ! -z "$CUBE_LB_IP" ]; then
            print_status "Testing external Cube.js access at $CUBE_LB_IP:4000..."
            if curl -f -s --connect-timeout 10 http://$CUBE_LB_IP:4000/cubejs-api/v1/meta > /dev/null 2>&1; then
                print_success "External Cube.js access working"
            else
                print_warning "External Cube.js access not yet available (may need more time)"
            fi
        fi
    else
        print_warning "LoadBalancer IPs not yet assigned (this may take 5-10 minutes)"
    fi
}

# Test resource usage
test_resource_usage() {
    print_status "Checking resource usage..."
    
    echo ""
    print_status "Pod Resource Usage:"
    kubectl top pods -n $NAMESPACE 2>/dev/null || print_warning "Metrics server not available"
    
    echo ""
    print_status "HPA Status:"
    kubectl get hpa -n $NAMESPACE 2>/dev/null || print_warning "HPA not configured"
}

# Main test function
main() {
    echo "========================================"
    echo "STCS Data Architecture - Deployment Test"
    echo "========================================"
    
    # Check if namespace exists
    if ! kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
        print_error "Namespace '$NAMESPACE' not found. Please deploy first."
        exit 1
    fi
    
    # Run tests
    test_pod_health
    echo ""
    
    test_service_connectivity
    echo ""
    
    test_inter_service_communication
    echo ""
    
    test_external_database_connectivity
    echo ""
    
    test_cube_data_models
    echo ""
    
    test_external_access
    echo ""
    
    test_resource_usage
    echo ""
    
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    
    print_success "Basic deployment tests completed"
    
    echo ""
    print_status "Next Steps:"
    echo "1. Wait for LoadBalancer IPs if not yet assigned"
    echo "2. Test external access once IPs are available"
    echo "3. Configure Sigma Computing connection"
    echo "4. Verify end-to-end data flow"
    
    echo ""
    print_status "Useful Commands:"
    echo "  kubectl get pods -n $NAMESPACE                    # Check pod status"
    echo "  kubectl get svc -n $NAMESPACE                     # Check service status"
    echo "  kubectl get hpa -n $NAMESPACE                     # Check autoscaling"
    echo "  kubectl logs -f deployment/cube -n $NAMESPACE     # Cube.js logs"
    echo "  kubectl logs -f deployment/trino-coordinator -n $NAMESPACE # Trino logs"
}

# Run main function
main "$@"