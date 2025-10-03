#!/bin/bash

# Cube.js Cluster Scale Down Script
# This script scales down all deployments in the stcs namespace to 0 replicas
# Use this to save costs when the cluster is not needed

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

echo -e "${BLUE}🔽 Cube.js Cluster Scale Down Script${NC}"
echo "=================================================="

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

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

# Function to backup current replica counts
backup_replica_counts() {
    echo -e "${YELLOW}📦 Backing up current replica counts...${NC}"
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/replica-counts-$TIMESTAMP.txt"
    
    echo "# Replica backup created on $(date)" > "$BACKUP_FILE"
    echo "# Use scale-up.sh to restore these values" >> "$BACKUP_FILE"
    echo "" >> "$BACKUP_FILE"
    
    kubectl get deployments -n "$NAMESPACE" -o custom-columns="NAME:.metadata.name,REPLICAS:.spec.replicas" --no-headers | while read name replicas; do
        echo "$name=$replicas" >> "$BACKUP_FILE"
        echo -e "${BLUE}  📋 $name: $replicas replicas${NC}"
    done
    
    echo -e "${GREEN}✅ Backup saved to: $BACKUP_FILE${NC}"
    
    # Create/update latest backup symlink
    ln -sf "$BACKUP_FILE" "$BACKUP_DIR/latest-replica-counts.txt"
}

# Function to scale down deployments
scale_down_deployments() {
    echo -e "${YELLOW}⬇️  Scaling down deployments...${NC}"
    
    local deployments=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$deployments" ]; then
        echo -e "${YELLOW}⚠️  No deployments found in namespace '$NAMESPACE'${NC}"
        return
    fi
    
    for deployment in $deployments; do
        echo -e "${BLUE}  🔽 Scaling down $deployment...${NC}"
        kubectl scale deployment "$deployment" --replicas=0 -n "$NAMESPACE"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    ✅ $deployment scaled to 0 replicas${NC}"
        else
            echo -e "${RED}    ❌ Failed to scale $deployment${NC}"
        fi
    done
}

# Function to wait for pods to terminate
wait_for_termination() {
    echo -e "${YELLOW}⏳ Waiting for pods to terminate...${NC}"
    
    local timeout=300  # 5 minutes timeout
    local elapsed=0
    local interval=5
    
    while [ $elapsed -lt $timeout ]; do
        local running_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
        
        if [ "$running_pods" -eq 0 ]; then
            echo -e "${GREEN}✅ All pods have terminated${NC}"
            return 0
        fi
        
        echo -e "${BLUE}  ⏳ $running_pods pods still running... (${elapsed}s elapsed)${NC}"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo -e "${YELLOW}⚠️  Timeout reached. Some pods may still be terminating.${NC}"
    return 1
}

# Function to show final status
show_final_status() {
    echo -e "${YELLOW}📊 Final cluster status:${NC}"
    echo ""
    
    echo -e "${BLUE}Deployments:${NC}"
    kubectl get deployments -n "$NAMESPACE" -o custom-columns="NAME:.metadata.name,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas,REPLICAS:.spec.replicas"
    echo ""
    
    echo -e "${BLUE}Pods:${NC}"
    local pod_count=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pod_count" -eq 0 ]; then
        echo -e "${GREEN}  ✅ No pods running${NC}"
    else
        kubectl get pods -n "$NAMESPACE"
    fi
    echo ""
    
    echo -e "${BLUE}Services (still available):${NC}"
    kubectl get services -n "$NAMESPACE"
}

# Function to estimate cost savings
show_cost_info() {
    echo ""
    echo -e "${GREEN}💰 Cost Savings Information:${NC}"
    echo -e "${BLUE}  • All compute resources scaled to 0${NC}"
    echo -e "${BLUE}  • Only storage and LoadBalancer costs remain${NC}"
    echo -e "${BLUE}  • Estimated savings: ~80-90% of cluster costs${NC}"
    echo -e "${BLUE}  • Use scale-up.sh to restore the cluster${NC}"
    echo ""
}

# Main execution
main() {
    check_kubectl
    check_namespace
    
    echo -e "${YELLOW}🔍 Current cluster status:${NC}"
    kubectl get deployments -n "$NAMESPACE"
    echo ""
    
    # Confirm action
    read -p "Are you sure you want to scale down all deployments in '$NAMESPACE'? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ Scale down cancelled.${NC}"
        exit 0
    fi
    
    echo ""
    backup_replica_counts
    echo ""
    scale_down_deployments
    echo ""
    wait_for_termination
    echo ""
    show_final_status
    show_cost_info
    
    echo -e "${GREEN}🎉 Cluster scale down completed successfully!${NC}"
    echo -e "${BLUE}💡 To scale back up, run: ./scale-up.sh${NC}"
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