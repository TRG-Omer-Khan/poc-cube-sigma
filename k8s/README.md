# STCS Data Architecture - GKE Autopilot Deployment

## Overview

This directory contains Kubernetes manifests and deployment scripts for deploying the STCS Data Architecture Stack to Google Kubernetes Engine (GKE) Autopilot.

## Architecture on GKE

```
Internet → Load Balancer → Ingress → Services → Pods
                                  ├── Trino Coordinator
                                  ├── Cube.js Semantic Layer  
                                  └── PostgreSQL (Metadata)
```

## Prerequisites

1. **GKE Autopilot Cluster**: Create a GKE Autopilot cluster
2. **Google Cloud SDK**: Install and configure `gcloud` CLI
3. **kubectl**: Install Kubernetes CLI
4. **Domain Name**: (Optional) For custom domain and SSL

## Quick Deployment

### 1. Configure Your Environment

Edit `deploy.sh` and update these variables:
```bash
CLUSTER_NAME="your-gke-cluster"     # Your GKE cluster name
REGION="us-central1"                # Your GCP region
PROJECT_ID="your-project-id"        # Your GCP project ID
```

### 2. Deploy to GKE

```bash
cd k8s
./deploy.sh
```

### 3. Get Service Endpoints

```bash
kubectl get svc -n stcs
```

## Manual Deployment Steps

If you prefer manual deployment:

### 1. Connect to Your Cluster

```bash
gcloud container clusters get-credentials your-cluster --region=your-region
```

### 2. Deploy Components in Order

```bash
# Create namespace and secrets
kubectl apply -f namespace.yaml
kubectl apply -f secrets/
kubectl apply -f configmaps/

# Deploy infrastructure
kubectl apply -f deployments/postgres-cube.yaml

# Wait for PostgreSQL
kubectl wait --for=condition=available --timeout=300s deployment/postgres-cube -n stcs

# Deploy Trino
kubectl apply -f deployments/trino-coordinator.yaml
kubectl wait --for=condition=available --timeout=300s deployment/trino-coordinator -n stcs

# Deploy Cube.js
kubectl apply -f deployments/cube.yaml
kubectl wait --for=condition=available --timeout=300s deployment/cube -n stcs

# Deploy networking
kubectl apply -f ingress/
```

## File Structure

```
k8s/
├── README.md                           # This file
├── deploy.sh                           # Automated deployment script
├── namespace.yaml                      # Kubernetes namespace
├── monitoring.yaml                     # HPA and monitoring configs
├── configmaps/
│   ├── trino-config.yaml              # Trino configuration
│   ├── cube-config.yaml               # Cube.js configuration
│   └── cube-models.yaml               # Data model definitions
├── secrets/
│   └── database-secrets.yaml          # Database credentials
├── deployments/
│   ├── postgres-cube.yaml             # PostgreSQL metadata storage
│   ├── trino-coordinator.yaml         # Trino query engine
│   └── cube.yaml                      # Cube.js semantic layer
└── ingress/
    └── ingress.yaml                    # Load balancers and ingress
```

## Service Resources

### Resource Allocation (GKE Autopilot Optimized)

| Service | CPU Request | Memory Request | CPU Limit | Memory Limit |
|---------|-------------|----------------|-----------|--------------|
| PostgreSQL | 250m | 512Mi | 500m | 1Gi |
| Trino | 1000m | 4Gi | 2000m | 8Gi |
| Cube.js | 500m | 2Gi | 1000m | 4Gi |

### Auto-Scaling Configuration

- **Cube.js**: 1-5 replicas based on CPU (70%) and Memory (80%)
- **Trino**: 1-3 replicas based on CPU (80%) and Memory (85%)
- **PostgreSQL**: Single replica (metadata storage)

## Networking

### Internal Services (ClusterIP)
- `postgres-cube:5432` - PostgreSQL metadata storage
- `trino-coordinator:8080` - Trino query engine
- `cube:4000,3001,15432` - Cube.js APIs

### External Access (LoadBalancer)
- `trino-coordinator-lb` - Trino UI access
- `cube-lb` - Cube.js APIs and dev dashboard

### Ports Exposed

| Service | Port | Purpose |
|---------|------|---------|
| Trino | 8080 | Web UI and API |
| Cube.js | 4000 | REST API |
| Cube.js | 3001 | Development Dashboard |
| Cube.js | 15432 | SQL API (PostgreSQL-compatible) |

## Monitoring and Scaling

### Health Checks
- **Readiness Probes**: Ensure services are ready to receive traffic
- **Liveness Probes**: Restart unhealthy containers
- **Startup Probes**: Handle slow-starting applications

### Horizontal Pod Autoscaling
```bash
# Check HPA status
kubectl get hpa -n stcs

# View scaling events
kubectl describe hpa cube-hpa -n stcs
```

## Security Considerations

### Secrets Management
- Database credentials stored in Kubernetes secrets
- Consider using Google Secret Manager for production
- Rotate secrets regularly

### Network Security
- Services communicate via internal cluster networking
- External access controlled through LoadBalancer services
- Consider network policies for additional security

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n stcs
kubectl describe pod <pod-name> -n stcs
```

### View Logs
```bash
# Cube.js logs
kubectl logs -f deployment/cube -n stcs

# Trino logs
kubectl logs -f deployment/trino-coordinator -n stcs

# PostgreSQL logs
kubectl logs -f deployment/postgres-cube -n stcs
```

### Check Service Connectivity
```bash
# Test internal service connectivity
kubectl exec -it deployment/cube -n stcs -- curl http://trino-coordinator:8080/v1/info
```

### Resource Usage
```bash
# Check resource usage
kubectl top pods -n stcs
kubectl top nodes
```

## Sigma Computing Connection

Once deployed, connect Sigma Computing using:

1. Get the Cube.js LoadBalancer IP:
   ```bash
   kubectl get svc cube-lb -n stcs
   ```

2. Use these connection details in Sigma:
   - **Host**: `<CUBE_LB_EXTERNAL_IP>`
   - **Port**: `15432`
   - **Database**: `cube`
   - **Username**: `cube`
   - **Password**: `stcs-production-secret-2024`

## Production Enhancements

### SSL/TLS
- Update `ingress.yaml` with your domain
- Configure managed SSL certificates
- Enable HTTPS redirects

### Monitoring
- Integrate with Google Cloud Monitoring
- Set up alerting for critical metrics
- Configure log aggregation

### Backup and Recovery
- Configure automated PostgreSQL backups
- Implement disaster recovery procedures
- Test restoration processes

### Security Hardening
- Implement network policies
- Use Google Secret Manager
- Enable audit logging
- Configure Pod Security Standards

## Cost Optimization

### GKE Autopilot Benefits
- Pay only for requested resources
- Automatic node management
- Built-in security hardening
- No cluster management overhead

### Resource Right-Sizing
- Monitor actual resource usage
- Adjust requests and limits based on metrics
- Use HPA to handle traffic spikes efficiently

## Support

For issues with this deployment:
1. Check the troubleshooting section above
2. Review pod logs for error messages
3. Verify network connectivity between services
4. Ensure external database access is configured correctly