#!/bin/bash

# Cube.js Cluster Status Script
# This script provides comprehensive status information about the stcs cluster
# Use this to monitor cluster health and troubleshoot issues

set -e

NAMESPACE="stcs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}📊 Cube.js Cluster Status Dashboard${NC}"
echo "=================================================="

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

# Function to show deployment status
show_deployments() {
    echo -e "${CYAN}🚀 DEPLOYMENTS${NC}"
    echo "----------------------------------------"
    
    local deployments=$(kubectl get deployments -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$deployments" ]; then
        echo -e "${YELLOW}  ⚠️  No deployments found${NC}"
        return
    fi
    
    # Header
    printf "%-20s %-10s %-12s %-10s %-8s %s\n" "NAME" "READY" "UP-TO-DATE" "AVAILABLE" "AGE" "STATUS"
    echo "--------------------------------------------------------------------------------"
    
    while read -r name ready uptodate available age; do
        local status_color="$GREEN"
        local status_text="✅ Healthy"
        
        # Parse ready field (format: ready/desired)
        local current_ready=$(echo "$ready" | cut -d'/' -f1)
        local desired_ready=$(echo "$ready" | cut -d'/' -f2)
        
        if [ "$current_ready" != "$desired_ready" ]; then
            if [ "$current_ready" -eq 0 ]; then
                status_color="$RED"
                status_text="🔴 Scaled Down"
            else
                status_color="$YELLOW"
                status_text="🟡 Starting"
            fi
        fi
        
        printf "%-20s %-10s %-12s %-10s %-8s %s\n" "$name" "$ready" "$uptodate" "$available" "$age" "$(echo -e "${status_color}${status_text}${NC}")"
        
    done <<< "$deployments"
    
    echo ""
}

# Function to show pod status
show_pods() {
    echo -e "${CYAN}🏗️  PODS${NC}"
    echo "----------------------------------------"
    
    local pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pods" ]; then
        echo -e "${GREEN}  ✅ No pods running (cluster scaled down)${NC}"
        echo ""
        return
    fi
    
    # Header
    printf "%-35s %-12s %-8s %-8s %s\n" "NAME" "STATUS" "RESTARTS" "AGE" "NODE"
    echo "--------------------------------------------------------------------------------"
    
    while read -r name ready status restarts age; do
        local status_color="$GREEN"
        local status_icon="✅"
        
        case "$status" in
            "Running")
                status_color="$GREEN"
                status_icon="✅"
                ;;
            "Pending")
                status_color="$YELLOW"
                status_icon="🟡"
                ;;
            "ContainerCreating"|"PodInitializing")
                status_color="$BLUE"
                status_icon="🔄"
                ;;
            "Error"|"CrashLoopBackOff"|"ImagePullBackOff")
                status_color="$RED"
                status_icon="🔴"
                ;;
            "Terminating")
                status_color="$PURPLE"
                status_icon="🟣"
                ;;
            *)
                status_color="$YELLOW"
                status_icon="❓"
                ;;
        esac
        
        # Get node name
        local node=$(kubectl get pod "$name" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "unknown")
        
        printf "%-35s %-12s %-8s %-8s %s\n" "$name" "$(echo -e "${status_color}${status_icon} ${status}${NC}")" "$restarts" "$age" "$node"
        
    done <<< "$pods"
    
    echo ""
}

# Function to show service status
show_services() {
    echo -e "${CYAN}🌐 SERVICES${NC}"
    echo "----------------------------------------"
    
    local services=$(kubectl get services -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$services" ]; then
        echo -e "${YELLOW}  ⚠️  No services found${NC}"
        echo ""
        return
    fi
    
    # Header
    printf "%-20s %-15s %-15s %-40s %-8s %s\n" "NAME" "TYPE" "CLUSTER-IP" "EXTERNAL-IP" "PORT(S)" "AGE"
    echo "--------------------------------------------------------------------------------"
    
    while read -r name type cluster_ip external_ip ports age; do
        local ip_color="$GREEN"
        local ip_display="$external_ip"
        
        if [ "$external_ip" = "<none>" ] || [ "$external_ip" = "<pending>" ]; then
            ip_color="$YELLOW"
            ip_display="$external_ip"
        fi
        
        printf "%-20s %-15s %-15s %-40s %-8s %s\n" "$name" "$type" "$cluster_ip" "$(echo -e "${ip_color}${ip_display}${NC}")" "$ports" "$age"
        
    done <<< "$services"
    
    echo ""
}

# Function to test connectivity
test_connectivity() {
    echo -e "${CYAN}🔍 CONNECTIVITY TESTS${NC}"
    echo "----------------------------------------"
    
    local cube_external_ip=$(kubectl get svc cube-lb -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -z "$cube_external_ip" ] || [ "$cube_external_ip" = "null" ]; then
        echo -e "${YELLOW}  ⚠️  Cube service external IP not available${NC}"
        echo ""
        return
    fi
    
    echo -e "${BLUE}  🌐 External IP: $cube_external_ip${NC}"
    echo ""
    
    # Test REST API
    echo -e "${BLUE}  🔍 Testing REST API (port 4000)...${NC}"
    if timeout 5 curl -s "http://$cube_external_ip:4000/cubejs-api/v1/meta" > /dev/null 2>&1; then
        echo -e "${GREEN}    ✅ REST API responding${NC}"
    else
        echo -e "${RED}    ❌ REST API not responding${NC}"
    fi
    
    # Test Dev Dashboard
    echo -e "${BLUE}  🔍 Testing Dev Dashboard (port 3001)...${NC}"
    if timeout 5 curl -s "http://$cube_external_ip:3001" > /dev/null 2>&1; then
        echo -e "${GREEN}    ✅ Dev Dashboard responding${NC}"
    else
        echo -e "${RED}    ❌ Dev Dashboard not responding${NC}"
    fi
    
    # Test SQL API
    echo -e "${BLUE}  🔍 Testing SQL API (port 15432)...${NC}"
    if timeout 5 nc -z "$cube_external_ip" 15432 2>/dev/null; then
        echo -e "${GREEN}    ✅ SQL API port accessible${NC}"
    else
        echo -e "${RED}    ❌ SQL API port not accessible${NC}"
    fi
    
    echo ""
}

# Function to show resource usage
show_resource_usage() {
    echo -e "${CYAN}📈 RESOURCE USAGE${NC}"
    echo "----------------------------------------"
    
    local pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pods" ]; then
        echo -e "${GREEN}  ✅ No resources in use (cluster scaled down)${NC}"
        echo ""
        return
    fi
    
    # Check if metrics-server is available
    if ! kubectl top pods -n "$NAMESPACE" &>/dev/null; then
        echo -e "${YELLOW}  ⚠️  Resource metrics not available (metrics-server not installed)${NC}"
        echo ""
        return
    fi
    
    echo -e "${BLUE}  Pod Resource Usage:${NC}"
    kubectl top pods -n "$NAMESPACE" 2>/dev/null | while read line; do
        echo "    $line"
    done
    
    echo ""
}

# Function to show recent events
show_recent_events() {
    echo -e "${CYAN}📋 RECENT EVENTS${NC}"
    echo "----------------------------------------"
    
    local events=$(kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' --no-headers 2>/dev/null | tail -10 || echo "")
    
    if [ -z "$events" ]; then
        echo -e "${GREEN}  ✅ No recent events${NC}"
        echo ""
        return
    fi
    
    echo "$events" | while read line; do
        local event_type=$(echo "$line" | awk '{print $4}')
        local color="$BLUE"
        
        case "$event_type" in
            "Warning")
                color="$YELLOW"
                ;;
            "Error")
                color="$RED"
                ;;
            "Normal")
                color="$GREEN"
                ;;
        esac
        
        echo -e "  ${color}${line}${NC}"
    done
    
    echo ""
}

# Function to show access information
show_access_info() {
    echo -e "${CYAN}🔗 ACCESS INFORMATION${NC}"
    echo "----------------------------------------"
    
    local cube_external_ip=$(kubectl get svc cube-lb -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -z "$cube_external_ip" ] || [ "$cube_external_ip" = "null" ]; then
        echo -e "${YELLOW}  ⚠️  Services not yet accessible (cluster may be scaled down or starting)${NC}"
        echo ""
        return
    fi
    
    echo -e "${GREEN}  🌐 External IP: $cube_external_ip${NC}"
    echo -e "${BLUE}  📊 Dev Dashboard: http://$cube_external_ip:3001${NC}"
    echo -e "${BLUE}  🔗 REST API: http://$cube_external_ip:4000/cubejs-api/v1${NC}"
    echo -e "${BLUE}  🗄️  SQL API: $cube_external_ip:15432${NC}"
    echo ""
    echo -e "${BLUE}  📝 SQL Connection Example:${NC}"
    echo -e "${GREEN}    PGPASSWORD=stcs-production-secret-2024 psql -h $cube_external_ip -p 15432 -U cube -d cube${NC}"
    echo ""
}

# Function to show cluster summary
show_summary() {
    echo -e "${CYAN}📝 CLUSTER SUMMARY${NC}"
    echo "----------------------------------------"
    
    local total_deployments=$(kubectl get deployments -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local running_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local services=$(kubectl get services -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    echo -e "${BLUE}  📊 Deployments: $total_deployments${NC}"
    echo -e "${BLUE}  🏗️  Pods: $running_pods/$total_pods running${NC}"
    echo -e "${BLUE}  🌐 Services: $services${NC}"
    
    # Determine overall cluster status
    if [ "$running_pods" -eq 0 ]; then
        echo -e "${YELLOW}  📉 Status: Scaled Down${NC}"
        echo -e "${BLUE}  💡 Use ./scale-up.sh to start the cluster${NC}"
    elif [ "$running_pods" -eq "$total_deployments" ]; then
        echo -e "${GREEN}  📈 Status: Fully Operational${NC}"
    else
        echo -e "${YELLOW}  📊 Status: Partially Running${NC}"
    fi
    
    echo ""
}

# Function to show available actions
show_actions() {
    echo -e "${CYAN}🛠️  AVAILABLE ACTIONS${NC}"
    echo "----------------------------------------"
    echo -e "${BLUE}  📈 Scale up cluster: ./scale-up.sh${NC}"
    echo -e "${BLUE}  📉 Scale down cluster: ./scale-down.sh${NC}"
    echo -e "${BLUE}  🔄 Restart deployment: kubectl rollout restart deployment/cube -n $NAMESPACE${NC}"
    echo -e "${BLUE}  📋 View logs: kubectl logs -n $NAMESPACE deployment/cube --tail=50${NC}"
    echo -e "${BLUE}  🔍 Watch pods: kubectl get pods -n $NAMESPACE --watch${NC}"
    echo ""
}

# Main execution
main() {
    check_kubectl
    check_namespace
    
    # Parse command line arguments
    case "${1:-}" in
        "--watch"|"-w")
            echo -e "${BLUE}👀 Watching cluster status (press Ctrl+C to exit)...${NC}"
            echo ""
            while true; do
                clear
                echo -e "${BLUE}📊 Cube.js Cluster Status Dashboard (Live)${NC}"
                echo "=================================================="
                show_summary
                show_deployments
                show_pods
                sleep 5
            done
            ;;
        "--connectivity"|"-c")
            test_connectivity
            ;;
        "--events"|"-e")
            show_recent_events
            ;;
        "--help"|"-h")
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  (no args)     Show complete cluster status"
            echo "  -w, --watch   Watch cluster status in real-time"
            echo "  -c, --connectivity  Test connectivity only"
            echo "  -e, --events  Show recent events only"
            echo "  -h, --help    Show this help message"
            echo ""
            ;;
        *)
            show_summary
            show_deployments
            show_pods
            show_services
            test_connectivity
            show_resource_usage
            show_recent_events
            show_access_info
            show_actions
            ;;
    esac
}

# Handle script interruption for watch mode
cleanup() {
    echo ""
    echo -e "${YELLOW}👋 Exiting cluster status monitor...${NC}"
    exit 0
}

trap cleanup INT TERM

# Run main function
main "$@"