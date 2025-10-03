# Technical Decisions & Architecture Rationale

## Overview
This document captures the key technical decisions made during the implementation of the Cube.js semantic layer on Kubernetes, including the rationale behind each choice and lessons learned.

## 1. Model Format: JavaScript vs YAML

### Decision: Use JavaScript for Kubernetes Production Deployment

#### Background
Initially attempted to use YAML model files in Kubernetes deployment, similar to local development setup.

#### Problem Discovered
- **Root Cause**: Cube.js runtime **does not support YAML model files** in production
- **Symptoms**: 
  - Models not visible in dev dashboard
  - Empty cubes/views list
  - No error messages indicating YAML parsing issues
- **Investigation**: 
  - Local development tools parse YAML but don't reflect production behavior
  - Cube.js documentation inconsistent about YAML support
  - Runtime expects JavaScript `cube()` and `view()` functions

#### Solution Implemented
```javascript
// BEFORE (YAML - doesn't work in production)
cubes:
  - name: Customers
    sql: SELECT * FROM customers
    dimensions:
      id:
        sql: customer_id
        type: number

// AFTER (JavaScript - works in production)
cube(`Customers`, {
  sql: `SELECT * FROM customers`,
  dimensions: {
    id: {
      sql: `customer_id`,
      type: `number`
    }
  }
});
```

#### Impact
- ✅ Models now visible and functional in production
- ✅ Proper semantic layer functionality
- ✅ BI tool integration working correctly
- ⚠️ Requires conversion step from local YAML to production JavaScript

#### Lessons Learned
1. **Always test in production-like environment** - Local development tools may not reflect production behavior
2. **Verify documentation claims** - Official docs may not always be accurate
3. **Check runtime requirements** - Development and production environments may have different capabilities

## 2. Configuration Management: Kubernetes ConfigMaps

### Decision: Use ConfigMaps for Model Storage

#### Alternatives Considered
1. **Embedded in Docker Image**: Bundle models in custom image
2. **Volume Mounts**: Use persistent volumes for model files
3. **ConfigMaps**: Store models as Kubernetes ConfigMaps
4. **External Configuration**: Use external config management systems

#### Rationale for ConfigMaps
```yaml
# Pros:
✅ GitOps friendly - version controlled deployments
✅ Native Kubernetes resource - no external dependencies
✅ Hot reloading - update without rebuilding images
✅ Atomic updates - all models updated together
✅ Easy rollback - previous ConfigMap versions
✅ Kubernetes RBAC integration

# Cons:
⚠️ Size limitations (1MB per ConfigMap)
⚠️ Manual conversion from YAML to JavaScript
⚠️ Requires deployment restart for updates
```

#### Implementation Pattern
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cube-models
data:
  Customers.js: |
    cube(`Customers`, { ... });
  Orders.js: |
    cube(`Orders`, { ... });
```

#### Update Workflow
```bash
# 1. Edit ConfigMap
vim k8s/configmaps/cube-models.yaml

# 2. Apply changes
kubectl apply -f k8s/configmaps/cube-models.yaml

# 3. Restart to load new models
kubectl rollout restart deployment/cube -n stcs
```

## 3. Data Architecture: Multi-Layer Approach

### Decision: PostgreSQL → Trino → Cube.js → BI Tools

#### Architecture Rationale
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐    ┌──────────────┐
│   BI Tools      │    │   Cube.js    │    │     Trino       │    │ PostgreSQL   │
│  (Sigma, etc.)  │◄──►│ Semantic     │◄──►│   Federation    │◄──►│   Database   │
│                 │    │   Layer      │    │     Layer       │    │              │
└─────────────────┘    └──────────────┘    └─────────────────┘    └──────────────┘
```

#### Layer Responsibilities

**PostgreSQL (Data Layer)**
- Raw operational data storage
- ACID compliance for transactional data
- Optimized for write operations

**Trino (Federation Layer)**
- Distributed query processing
- Multi-source data integration
- SQL standardization across sources
- Performance optimization for analytical queries

**Cube.js (Semantic Layer)**
- Business logic centralization
- Metric definitions and calculations
- Pre-aggregations and caching
- Security and access control
- Consistent API for BI tools

**Benefits of Multi-Layer Architecture**
1. **Separation of Concerns**: Each layer has specific responsibilities
2. **Scalability**: Can scale each layer independently
3. **Flexibility**: Easy to add new data sources via Trino
4. **Performance**: Optimized for both operational and analytical workloads
5. **Governance**: Centralized business logic and security

## 4. Deployment Platform: Kubernetes (GKE Autopilot)

### Decision: Use Kubernetes for Container Orchestration

#### Why Kubernetes?
```yaml
Advantages:
  ✅ Container orchestration and scaling
  ✅ Service discovery and load balancing
  ✅ Health checks and auto-recovery
  ✅ Rolling deployments with zero downtime
  ✅ Resource management and limits
  ✅ Native configuration management (ConfigMaps/Secrets)
  ✅ Cloud provider integration (GKE)
```

#### Why GKE Autopilot?
```yaml
GKE Autopilot Benefits:
  ✅ Fully managed node infrastructure
  ✅ Automatic security patches and updates
  ✅ Pay-per-pod pricing model
  ✅ Built-in security best practices
  ✅ Simplified cluster management
  ✅ Automatic scaling
```

#### Kubernetes Resources Used
```yaml
# Deployment - Application lifecycle management
apiVersion: apps/v1
kind: Deployment

# Service - Network exposure
apiVersion: v1
kind: Service

# ConfigMap - Configuration management
apiVersion: v1
kind: ConfigMap

# Secret - Credential management
apiVersion: v1
kind: Secret
```

## 5. API Strategy: SQL API for BI Integration

### Decision: Expose Cube.js SQL API Instead of REST API

#### Why SQL API?
```yaml
SQL API Advantages:
  ✅ Universal BI tool compatibility
  ✅ PostgreSQL protocol compliance
  ✅ Familiar SQL syntax for analysts
  ✅ Standard database connector usage
  ✅ No custom integration required

REST API Limitations:
  ⚠️ Custom integration per BI tool
  ⚠️ Limited BI tool support
  ⚠️ Learning curve for analysts
  ⚠️ Additional development effort
```

#### Implementation
```yaml
# Cube.js SQL API Configuration
env:
- name: CUBEJS_SQL_API
  value: "true"
- name: CUBEJS_SQL_PORT
  value: "15432"
- name: CUBEJS_PG_SQL_PORT
  value: "15432"

# Service exposure
ports:
- port: 15432
  targetPort: 15432
  name: sql-api
```

#### BI Tool Integration
```sql
-- Connection String for BI Tools
Host: EXTERNAL_IP
Port: 15432
Database: cube
Username: cube
Password: SECRET

-- Available Tables (Semantic Layer)
SELECT * FROM "Customers";
SELECT * FROM "Orders";
SELECT * FROM "Sales";  -- View
```

## 6. Error Handling & Type Casting

### Decision: Explicit Type Casting for Database Compatibility

#### Problem: Date Type Mismatches
```
Arrow error: Type of value must be a time or timestamp
Column 'customers.tags' cannot be resolved
```

#### Root Causes
1. **Database vs Cube.js Type Differences**: PostgreSQL `date` vs Cube.js `time`
2. **Non-existent Columns**: Models referencing columns not in source tables
3. **Type Inference Issues**: Automatic type detection failures

#### Solutions Implemented
```javascript
// Explicit type casting for dates
launch_date: {
  sql: `CAST(launch_date AS TIMESTAMP)`,
  type: `time`
}

// Remove non-existent columns
// REMOVED: tags dimension (column doesn't exist)

// Proper join references
product_name: {
  sql: `${Products.product_name}`,
  type: `string`
}
```

#### Best Practices Established
1. **Verify Column Existence**: Check source schema before adding dimensions
2. **Explicit Type Casting**: Don't rely on automatic type inference
3. **Test Iteratively**: Deploy and test each model change
4. **Monitor Logs**: Check Cube.js logs for runtime errors

## 7. Security Implementation

### Decision: Implement SQL Authentication with Secrets

#### Authentication Flow
```javascript
// cube.js configuration
module.exports = {
  checkSqlAuth: (req, username) => {
    if (username === 'cube') {
      return {
        password: process.env.CUBEJS_SQL_PASSWORD
      };
    }
    throw new Error('Please provide valid credentials');
  }
};
```

#### Kubernetes Secret Management
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-secrets
data:
  cube-sql-password: <base64-encoded-password>
```

#### Security Benefits
- ✅ Credential isolation from code
- ✅ Kubernetes-native secret management
- ✅ Rotation capability
- ✅ RBAC integration

## 8. Performance Considerations

### Decisions Made for Performance

#### Caching Strategy
```javascript
// Memory cache for development
env:
- name: CUBEJS_CACHE_AND_QUEUE_DRIVER
  value: "memory"

// Future: Redis for production scaling
```

#### Resource Allocation
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "500m"
  limits:
    memory: "4Gi"
    cpu: "1000m"
```

#### SQL Optimization
```javascript
// Efficient SQL generation
cube(`Customers`, {
  sql: `SELECT * FROM public.customers`,  // Let Cube.js optimize
  // vs
  sql: `SELECT col1, col2, ... FROM public.customers`  // Manual optimization
});
```

## 9. Monitoring and Observability

### Decisions for Production Readiness

#### Health Checks
```yaml
readinessProbe:
  httpGet:
    path: /cubejs-api/v1/meta
    port: 4000
  initialDelaySeconds: 30

livenessProbe:
  httpGet:
    path: /cubejs-api/v1/meta
    port: 4000
  initialDelaySeconds: 60
```

#### Logging Strategy
```yaml
# Kubernetes logs
kubectl logs -n stcs deployment/cube

# Cube.js structured logging
{"level":"info","message":"Query completed","duration":25}
```

## 10. Future Considerations

### Scalability Decisions

#### Horizontal Scaling
```yaml
# Current: Single replica
replicas: 1

# Future: Multiple replicas with shared cache
replicas: 3
# Requires: Redis/external cache
```

#### Pre-aggregations
```javascript
// Future optimization
preAggregations: {
  main: {
    type: `rollup`,
    measureReferences: [`count`],
    dimensionReferences: [`category`],
    timeDimensionReference: `createdAt`,
    granularity: `day`
  }
}
```

### Multi-Environment Strategy
```yaml
# Development
namespace: stcs-dev

# Staging  
namespace: stcs-staging

# Production
namespace: stcs-prod
```

## Summary

The implemented architecture successfully addresses:
- ✅ **Scalable semantic layer** with proper business logic abstraction
- ✅ **BI tool integration** via standard SQL interface
- ✅ **Production-ready deployment** on Kubernetes
- ✅ **Maintainable configuration** with GitOps workflow
- ✅ **Performance optimization** through caching and federation
- ✅ **Security** with proper credential management

Key learnings:
1. **Test production behavior early** - Development environments may not reflect production
2. **Explicit configuration** - Don't rely on defaults or automatic inference
3. **Layer responsibilities** - Each architectural layer should have clear purpose
4. **Operational considerations** - Design for maintenance and updates from the start

---

*These decisions form the foundation for a scalable, maintainable semantic layer that can evolve with business needs.*