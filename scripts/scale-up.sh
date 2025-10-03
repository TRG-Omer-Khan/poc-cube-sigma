#!/bin/bash

# Cube.js Cluster Scale Up Script
# This script restores deployments in the stcs namespace to their original replica counts
# Use this to restore the cluster after scaling down

set -e

NAMESPACE="stcs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/scaling-backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔼 Cube.js Cluster Scale Up Script${NC}"
echo "=================================================="

# Default replica counts if no backup is found
declare -A DEFAULT_REPLICAS=(
    ["cube"]="1"
    ["postgres-cube"]="1"
    ["trino-coordinator"]="1"
)

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
        exit 1
    fi
}

# Function to check if namespace exists
check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        echo -e "${RED}❌ Namespace '$NAMESPACE' not found.${NC}"
        exit 1
    fi
}

# Function to load replica counts from backup
load_replica_counts() {
    local backup_file="$BACKUP_DIR/latest-replica-counts.txt"
    
    if [ -f "$backup_file" ]; then
        echo -e "${GREEN}📦 Found replica backup: $backup_file${NC}"
        
        # Read backup file and populate associative array
        declare -gA REPLICA_COUNTS
        while IFS='=' read -r name replicas; do
            # Skip comments and empty lines
            [[ "$name" =~ ^#.*$ ]] || [[ -z "$name" ]] && continue
            REPLICA_COUNTS["$name"]="$replicas"
            echo -e "${BLUE}  📋 $name: $replicas replicas${NC}"
        done < "$backup_file"
        
        return 0
    else
        echo -e "${YELLOW}⚠️  No replica backup found. Using default values...${NC}"
        
        # Use default replica counts
        declare -gA REPLICA_COUNTS
        for deployment in "${!DEFAULT_REPLICAS[@]}"; do
            REPLICA_COUNTS["$deployment"]="${DEFAULT_REPLICAS[$deployment]}"
            echo -e "${BLUE}  📋 $deployment: ${DEFAULT_REPLICAS[$deployment]} replicas (default)${NC}"
        done
        
        return 1
    fi
}

# Function to scale up deployments
scale_up_deployments() {
    echo -e "${YELLOW}⬆️  Scaling up deployments...${NC}"
    
    local deployments=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$deployments" ]; then
        echo -e "${RED}❌ No deployments found in namespace '$NAMESPACE'${NC}"
        exit 1
    fi
    
    local failed_deployments=()
    
    for deployment in $deployments; do
        local target_replicas="${REPLICA_COUNTS[$deployment]:-1}"
        
        echo -e "${BLUE}  🔼 Scaling up $deployment to $target_replicas replicas...${NC}"
        
        if kubectl scale deployment "$deployment" --replicas="$target_replicas" -n "$NAMESPACE"; then
            echo -e "${GREEN}    ✅ $deployment scaled to $target_replicas replicas${NC}"
        else
            echo -e "${RED}    ❌ Failed to scale $deployment${NC}"
            failed_deployments+=("$deployment")
        fi
    done
    
    if [ ${#failed_deployments[@]} -gt 0 ]; then
        echo -e "${RED}❌ Failed to scale the following deployments:${NC}"
        printf '%s\n' "${failed_deployments[@]}"
        return 1
    fi
    
    return 0
}

# Function to wait for deployments to be ready
wait_for_ready() {
    echo -e "${YELLOW}⏳ Waiting for deployments to be ready...${NC}"
    
    local timeout=600  # 10 minutes timeout
    local elapsed=0
    local interval=10
    
    while [ $elapsed -lt $timeout ]; do
        local all_ready=true
        local status_info=""
        
        local deployments=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
        
        for deployment in $deployments; do
            local ready=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
            local desired=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
            
            ready=${ready:-0}
            desired=${desired:-0}
            
            status_info="$status_info\n  📊 $deployment: $ready/$desired ready"
            
            if [ "$ready" -ne "$desired" ]; then
                all_ready=false
            fi
        done
        
        if [ "$all_ready" = true ]; then
            echo -e "${GREEN}✅ All deployments are ready!${NC}"
            return 0
        fi
        
        echo -e "${BLUE}  ⏳ Waiting for deployments to be ready... (${elapsed}s elapsed)${NC}"
        echo -e "$status_info"
        echo ""
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo -e "${YELLOW}⚠️  Timeout reached. Some deployments may still be starting up.${NC}"
    return 1
}

# Function to verify services are accessible
verify_services() {
    echo -e "${YELLOW}🔍 Verifying service accessibility...${NC}"
    
    # Get external IP of cube service
    local external_ip=$(kubectl get svc cube-lb -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
        echo -e "${GREEN}  ✅ Cube service external IP: $external_ip${NC}"
        
        # Test if the service is responding
        echo -e "${BLUE}  🔍 Testing Cube.js API accessibility...${NC}"
        
        if timeout 10 curl -s "http://$external_ip:4000/cubejs-api/v1/meta" > /dev/null 2>&1; then
            echo -e "${GREEN}    ✅ Cube.js REST API is responding${NC}"
        else
            echo -e "${YELLOW}    ⚠️  Cube.js REST API not yet responding (may still be starting)${NC}"
        fi
        
        # Test SQL API
        echo -e "${BLUE}  🔍 Testing SQL API accessibility...${NC}"
        if timeout 5 nc -z "$external_ip" 15432 2>/dev/null; then
            echo -e "${GREEN}    ✅ SQL API port is accessible${NC}"
        else
            echo -e "${YELLOW}    ⚠️  SQL API not yet accessible (may still be starting)${NC}"
        fi
        
    else
        echo -e "${YELLOW}  ⚠️  External IP not yet assigned or service not found${NC}"
    fi
}

# Function to show final status
show_final_status() {
    echo -e "${YELLOW}📊 Final cluster status:${NC}"
    echo ""
    
    echo -e "${BLUE}Deployments:${NC}"
    kubectl get deployments -n "$NAMESPACE" -o custom-columns="NAME:.metadata.name,READY:.status.readyReplicas,UP-TO-DATE:.status.updatedReplicas,AVAILABLE:.status.availableReplicas,REPLICAS:.spec.replicas"
    echo ""
    
    echo -e "${BLUE}Pods:${NC}"
    kubectl get pods -n "$NAMESPACE"
    echo ""
    
    echo -e "${BLUE}Services:${NC}"
    kubectl get services -n "$NAMESPACE"
}

# Function to show access information
show_access_info() {
    echo ""
    echo -e "${GREEN}🌐 Access Information:${NC}"
    
    local external_ip=$(kubectl get svc cube-lb -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
        echo -e "${BLUE}  🌐 External IP: $external_ip${NC}"
        echo -e "${BLUE}  📊 Dev Dashboard: http://$external_ip:3001${NC}"
        echo -e "${BLUE}  🔗 REST API: http://$external_ip:4000/cubejs-api/v1${NC}"
        echo -e "${BLUE}  🗄️  SQL API: $external_ip:15432 (PostgreSQL protocol)${NC}"
        echo ""
        echo -e "${BLUE}  📝 SQL Connection Example:${NC}"
        echo -e "${GREEN}    PGPASSWORD=stcs-production-secret-2024 psql -h $external_ip -p 15432 -U cube -d cube${NC}"
    else
        echo -e "${YELLOW}  ⚠️  External IP not yet available. Check again in a few minutes.${NC}"
        echo -e "${BLUE}  💡 Run: kubectl get svc cube -n $NAMESPACE${NC}"
    fi
    echo ""
}

# Main execution
main() {
    check_kubectl
    check_namespace
    
    echo -e "${YELLOW}🔍 Current cluster status:${NC}"
    kubectl get deployments -n "$NAMESPACE"
    echo ""
    
    # Load replica counts
    load_replica_counts
    echo ""
    
    # Confirm action
    read -p "Are you sure you want to scale up all deployments in '$NAMESPACE'? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ Scale up cancelled.${NC}"
        exit 0
    fi
    
    echo ""
    
    if ! scale_up_deployments; then
        echo -e "${RED}❌ Some deployments failed to scale. Check the status manually.${NC}"
        exit 1
    fi
    
    echo ""
    wait_for_ready
    echo ""
    verify_services
    echo ""
    show_final_status
    show_access_info
    
    echo -e "${GREEN}🎉 Cluster scale up completed successfully!${NC}"
    echo -e "${BLUE}💡 Monitor status with: ./cluster-status.sh${NC}"
}

# Handle script interruption
cleanup() {
    echo ""
    echo -e "${YELLOW}⚠️  Script interrupted. Some deployments may be in an inconsistent state.${NC}"
    echo -e "${BLUE}💡 Check cluster status with: ./cluster-status.sh${NC}"
    exit 1
}

trap cleanup INT TERM

# Run main function
main "$@"