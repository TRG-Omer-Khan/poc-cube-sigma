# Cube.js Semantic Layer Documentation

## 📚 Documentation Index

This repository contains comprehensive documentation for the Cube.js semantic layer implementation on Kubernetes.

### 🎯 Quick Start

**Need to update a cube right now?** → [CUBE_UPDATE_GUIDE.md](./CUBE_UPDATE_GUIDE.md)

**Setting up from scratch?** → [CUBE_SEMANTIC_LAYER_WIKI.md](./CUBE_SEMANTIC_LAYER_WIKI.md)

**Understanding technical decisions?** → [TECHNICAL_DECISIONS.md](./TECHNICAL_DECISIONS.md)

### 📖 Document Overview

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[CUBE_SEMANTIC_LAYER_WIKI.md](./CUBE_SEMANTIC_LAYER_WIKI.md)** | Complete implementation guide | Setting up from scratch, understanding architecture |
| **[CUBE_UPDATE_GUIDE.md](./CUBE_UPDATE_GUIDE.md)** | Quick reference for updates | Daily operations, model changes |
| **[TECHNICAL_DECISIONS.md](./TECHNICAL_DECISIONS.md)** | Architecture rationale | Understanding why choices were made |

## 🚀 Common Tasks

### Update Models
```bash
# 1. Edit ConfigMap
vim k8s/configmaps/cube-models.yaml

# 2. Apply and restart
kubectl apply -f k8s/configmaps/cube-models.yaml
kubectl rollout restart deployment/cube -n stcs
```

### Check Status
```bash
# Deployment status
kubectl get pods -n stcs

# Application logs
kubectl logs -n stcs deployment/cube --tail=20

# Test SQL connection
PGPASSWORD=stcs-production-secret-2024 psql -h $(kubectl get svc cube -n stcs -o jsonpath='{.status.loadBalancer.ingress[0].ip}') -p 15432 -U cube -d cube
```

### Access Interfaces
- **Dev Dashboard**: `http://EXTERNAL_IP:3001`
- **REST API**: `http://EXTERNAL_IP:4000/cubejs-api/v1`
- **SQL API**: `EXTERNAL_IP:15432` (PostgreSQL protocol)

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐    ┌──────────────┐
│   BI Tools      │    │   Cube.js    │    │     Trino       │    │ PostgreSQL   │
│  (Sigma, etc.)  │◄──►│ Semantic     │◄──►│   Federation    │◄──►│   Database   │
│                 │    │   Layer      │    │     Layer       │    │              │
└─────────────────┘    └──────────────┘    └─────────────────┘    └──────────────┘
      │                        │                       │                     │
   REST/SQL API         SQL/REST API            SQL Queries           Raw Data
   Port: 4000/15432     Ports: 4000/15432      Port: 8080            Port: 5432
```

## 📊 Available Data Models

### Cubes (Base Models)
- **Customers** - Customer demographics and contact information
- **Orders** - Order details with status and payment information  
- **Products** - Product catalog with inventory data
- **OrderItems** - Individual line items for orders

### Views (Aggregated Models)
- **Sales** - Unified sales analysis view
- **Customer360** - Complete customer overview
- **InventoryManagement** - Product inventory tracking

## 🔧 Key Technical Decisions

### Why JavaScript Models?
- **Cube.js only supports JavaScript in production** (not YAML)
- YAML works in local development but fails in Kubernetes
- Solution: Convert YAML → JavaScript for deployment

### Why Kubernetes ConfigMaps?
- GitOps-friendly configuration management
- Native Kubernetes integration
- Easy rollback and version control
- Hot reloading without image rebuilds

### Why Multi-Layer Architecture?
- **PostgreSQL**: Optimized for transactional data
- **Trino**: Distributed analytics and federation
- **Cube.js**: Business logic and semantic modeling
- **BI Tools**: Consistent data access via SQL API

## 🎯 Success Metrics Achieved

- ✅ **Production Deployment**: Kubernetes-ready with proper health checks
- ✅ **BI Integration**: Sigma Computing successfully connected
- ✅ **Semantic Layer**: Centralized business logic and metrics
- ✅ **Performance**: Caching and pre-aggregation capabilities
- ✅ **Maintainability**: ConfigMap-based model management
- ✅ **Security**: Proper authentication and credential management

## 🛠️ Development Workflow

### Local Development
1. Create/edit YAML models in `model/` directory
2. Test locally with Cube.js dev server
3. Convert YAML to JavaScript for production

### Production Deployment
1. Update `k8s/configmaps/cube-models.yaml` with JavaScript models
2. Apply ConfigMap changes
3. Restart deployment to load new models
4. Verify through logs and SQL API testing

## 🚨 Emergency Procedures

### Rollback Deployment
```bash
# Restore previous ConfigMap
kubectl apply -f backup-models-YYYYMMDD.yaml
kubectl rollout restart deployment/cube -n stcs
```

### Debug Issues
```bash
# Check logs for errors
kubectl logs -n stcs deployment/cube --tail=50 | grep -i error

# Verify external connectivity
kubectl get svc -n stcs

# Test SQL API
telnet EXTERNAL_IP 15432
```

## 📞 Support & Resources

### Internal Resources
- Configuration files: `/k8s/configmaps/`
- Model definitions: `/model/` (local YAML)
- Deployment manifests: `/k8s/deployments/`

### External Resources
- [Cube.js Documentation](https://cube.dev/docs)
- [Kubernetes ConfigMap Guide](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Trino Documentation](https://trino.io/docs/)

## 🔄 Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-10-01 | v1.0 | Initial production deployment |
| | | YAML → JavaScript model conversion |
| | | Sigma Computing integration |
| | | Complete documentation set |

---

*For detailed implementation steps, troubleshooting, and architectural decisions, see the individual documentation files linked above.*