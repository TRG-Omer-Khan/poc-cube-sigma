# Cube.js Semantic Layer Documentation

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Local Development Setup](#local-development-setup)
3. [Kubernetes Deployment](#kubernetes-deployment)
4. [Model Development Workflow](#model-development-workflow)
5. [Technical Decisions](#technical-decisions)
6. [Troubleshooting](#troubleshooting)
7. [Maintenance & Updates](#maintenance--updates)
8. [BI Tool Integration](#bi-tool-integration)

## Architecture Overview

### System Architecture
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐    ┌──────────────┐
│   BI Tools      │    │   Cube.js    │    │     Trino       │    │ PostgreSQL   │
│  (Sigma, etc.)  │◄──►│ Semantic     │◄──►│   Federation    │◄──►│   Database   │
│                 │    │   Layer      │    │     Layer       │    │              │
└─────────────────┘    └──────────────┘    └─────────────────┘    └──────────────┘
      │                        │                       │                     │
      │                        │                       │                     │
   REST/SQL API         SQL/REST API            SQL Queries           Raw Data
   Port: 4000/15432     Ports: 4000/15432      Port: 8080            Port: 5432
```

### Data Flow
1. **Raw Data**: PostgreSQL stores operational data (customers, orders, products, etc.)
2. **Federation Layer**: Trino provides unified SQL interface across data sources
3. **Semantic Layer**: Cube.js adds business logic, metrics, and semantic modeling
4. **BI Integration**: Tools connect via Cube.js SQL API for consistent data access

### Key Components
- **PostgreSQL**: Primary data store
- **Trino**: Distributed SQL query engine for federation
- **Cube.js**: Semantic layer with pre-aggregations and caching
- **Kubernetes (GKE Autopilot)**: Container orchestration platform
- **ConfigMaps**: Kubernetes-native configuration management

## Local Development Setup

### Prerequisites
```bash
# Required tools
- Node.js 16+
- Docker & Docker Compose
- kubectl
- PostgreSQL client (psql)
```

### Local Environment Structure
```
/Users/inno/Desktop/stcs/
├── model/
│   ├── cubes/           # Individual cube definitions (YAML format for local dev)
│   │   ├── customers.yml
│   │   ├── orders.yml
│   │   ├── products.yml
│   │   └── order_items.yml
│   └── views/           # View definitions
│       ├── sales.yml
│       ├── customer_360.yml
│       └── inventory.yml
├── k8s/                 # Kubernetes deployment manifests
│   ├── deployments/
│   ├── configmaps/
│   └── services/
├── cube/               # Cube.js configuration
│   └── conf/
└── docs/               # Documentation
```

### Local Development Commands
```bash
# Start local Cube.js development server
npm run dev

# Access development dashboard
open http://localhost:4000

# Connect to local SQL API
psql -h localhost -p 15432 -U cube -d cube
```

## Kubernetes Deployment

### Deployment Architecture
The Kubernetes deployment uses a different approach than local development due to Cube.js limitations with YAML files.

#### Why JavaScript Instead of YAML?
**Critical Discovery**: Cube.js **only supports JavaScript model files** in production environments. YAML files are not supported by the Cube.js runtime, despite appearing in some documentation.

**Problem Encountered**:
- Local YAML models worked with development tooling
- Production deployment couldn't parse YAML files
- Cubes and views were invisible in the dashboard

**Solution Implemented**:
- Converted all YAML models to JavaScript format
- Used proper `cube()` and `view()` function syntax
- Mounted JavaScript files via Kubernetes ConfigMaps

### Kubernetes Components

#### 1. Cube.js Deployment (`k8s/deployments/cube.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cube
  namespace: stcs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cube
  template:
    spec:
      containers:
      - name: cube
        image: cubejs/cube:latest
        ports:
        - containerPort: 4000   # REST API
        - containerPort: 3001   # Dev Dashboard
        - containerPort: 15432  # SQL API
        env:
        - name: CUBEJS_DEV_MODE
          value: "true"
        - name: CUBEJS_DB_TYPE
          value: "trino"
        - name: CUBEJS_DB_HOST
          value: "trino-coordinator"
        - name: CUBEJS_SQL_API
          value: "true"
        volumeMounts:
        - name: cube-models-volume
          mountPath: /cube/conf/model/Customers.js
          subPath: Customers.js
        # ... other model files
      volumes:
      - name: cube-models-volume
        configMap:
          name: cube-models
```

#### 2. Model ConfigMap (`k8s/configmaps/cube-models.yaml`)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cube-models
  namespace: stcs
data:
  Customers.js: |
    cube(`Customers`, {
      sql: `SELECT * FROM public.customers`,
      joins: {},
      dimensions: {
        customer_id: {
          sql: `customer_id`,
          type: `number`,
          primaryKey: true
        },
        # ... other dimensions
      },
      measures: {
        count: {
          type: `count`
        }
      }
    });
```

### Deployment Commands
```bash
# Apply all Kubernetes manifests
kubectl apply -f k8s/

# Update models only
kubectl apply -f k8s/configmaps/cube-models.yaml

# Restart deployment to pick up changes
kubectl rollout restart deployment/cube -n stcs

# Check deployment status
kubectl rollout status deployment/cube -n stcs

# Get external IP
kubectl get services -n stcs

# Check logs
kubectl logs -n stcs deployment/cube --tail=50
```

## Model Development Workflow

### 1. Local Development (YAML)
For local development and prototyping, you can use YAML files:

```yaml
# model/cubes/customers.yml
cubes:
  - name: Customers
    sql: SELECT * FROM public.customers
    
    dimensions:
      customer_id:
        sql: customer_id
        type: number
        primary_key: true
      
      first_name:
        sql: first_name
        type: string
    
    measures:
      count:
        type: count
```

### 2. Production Conversion (JavaScript)
Convert YAML to JavaScript for Kubernetes deployment:

```javascript
// ConfigMap: Customers.js
cube(`Customers`, {
  sql: `SELECT * FROM public.customers`,
  
  dimensions: {
    customer_id: {
      sql: `customer_id`,
      type: `number`,
      primaryKey: true
    },
    
    first_name: {
      sql: `first_name`,
      type: `string`
    }
  },
  
  measures: {
    count: {
      type: `count`
    }
  }
});
```

### 3. Views and Joins
```javascript
// SalesView.js
view(`Sales`, {
  description: `A unified view for sales analysis.`,
  
  cubes: [
    {
      joinPath: Orders,
      includes: [
        `count`,
        `order_status`,
        `order_date`
      ]
    },
    {
      joinPath: Orders.Customers,
      prefix: true,
      includes: [
        `company`,
        `email`,
        `city`
      ]
    }
  ]
});
```

### 4. Update Process
1. **Develop locally** using YAML files
2. **Convert to JavaScript** for production
3. **Update ConfigMap** with new JavaScript models
4. **Apply changes** to Kubernetes
5. **Restart deployment** to load new models

## Technical Decisions

### Why Cube.js Over Direct Database Access?
1. **Semantic Layer**: Business logic centralization
2. **Performance**: Pre-aggregations and caching
3. **Security**: Row-level security and data governance
4. **Consistency**: Single source of truth for metrics
5. **BI Integration**: Standard SQL interface for all tools

### Why Trino Federation?
1. **Multi-source**: Can connect to multiple databases
2. **Performance**: Distributed query processing
3. **Scalability**: Handles large datasets efficiently
4. **Flexibility**: Easy to add new data sources

### Why Kubernetes ConfigMaps?
1. **Native Configuration**: Kubernetes-native approach
2. **Version Control**: GitOps-friendly deployment
3. **Hot Reloading**: Updates without rebuilding images
4. **Security**: Separation of code and configuration

### Why JavaScript Models in Production?
1. **Runtime Support**: Only format supported by Cube.js runtime
2. **Advanced Features**: Access to full JavaScript capabilities
3. **Dynamic Logic**: Conditional model generation
4. **Performance**: Compiled execution vs. interpreted YAML

## Troubleshooting

### Common Issues and Solutions

#### 1. Models Not Visible in Dashboard
**Symptoms**: Empty cubes/views list in dev dashboard
**Root Cause**: YAML files used instead of JavaScript
**Solution**: Convert models to JavaScript format

#### 2. Column Resolution Errors
**Symptoms**: `Column 'table.column' cannot be resolved`
**Root Cause**: Model references non-existent database columns
**Solution**: 
- Verify column exists in source table
- Remove invalid column references
- Use proper SQL casting for type mismatches

#### 3. Date/Time Type Errors
**Symptoms**: `Type of value must be a time or timestamp`
**Root Cause**: Database date types don't match Cube.js expectations
**Solution**: Cast columns to proper types
```javascript
launch_date: {
  sql: `CAST(launch_date AS TIMESTAMP)`,
  type: `time`
}
```

#### 4. Authentication Failures
**Symptoms**: `password authentication failed for user 'cube'`
**Root Cause**: Incorrect SQL API authentication configuration
**Solution**: Implement proper `checkSqlAuth` function

#### 5. Join Path Errors
**Symptoms**: `Can't find join path to join 'Orders', 'Orders,Customers'`
**Root Cause**: Missing join definitions in cube models
**Solution**: Add proper join relationships
```javascript
joins: {
  Customers: {
    sql: `${CUBE}.customer_id = ${Customers}.customer_id`,
    relationship: `many_to_one`
  }
}
```

### Debugging Commands
```bash
# Check pod status
kubectl get pods -n stcs

# View logs
kubectl logs -n stcs deployment/cube --tail=100 -f

# Test SQL API connection
PGPASSWORD=stcs-production-secret-2024 psql -h EXTERNAL_IP -p 15432 -U cube -d cube

# List available tables
\dt

# Test cube query
SELECT * FROM "Customers" LIMIT 5;
```

## Maintenance & Updates

### Regular Maintenance Tasks

#### 1. Model Updates
```bash
# 1. Edit the ConfigMap
vim k8s/configmaps/cube-models.yaml

# 2. Apply changes
kubectl apply -f k8s/configmaps/cube-models.yaml

# 3. Restart deployment
kubectl rollout restart deployment/cube -n stcs

# 4. Verify deployment
kubectl rollout status deployment/cube -n stcs
```

#### 2. Schema Changes
When database schema changes:
1. Update model definitions to match new schema
2. Test locally if possible
3. Deploy to staging/production
4. Verify BI tool connectivity

#### 3. Performance Optimization
- Monitor query performance in Cube.js dashboard
- Add pre-aggregations for frequently used queries
- Optimize join relationships
- Review and tune cache settings

#### 4. Security Updates
- Regular container image updates
- Secret rotation for database credentials
- Review and audit data access permissions

### Backup and Recovery
```bash
# Backup current models
kubectl get configmap cube-models -n stcs -o yaml > backup-models-$(date +%Y%m%d).yaml

# Restore from backup
kubectl apply -f backup-models-YYYYMMDD.yaml
```

### Monitoring and Alerting
- Set up monitoring for Cube.js API endpoints
- Monitor query performance and error rates
- Alert on deployment failures or configuration errors

## BI Tool Integration

### Sigma Computing Integration
1. **Connection Details**:
   - Host: `EXTERNAL_IP` (from `kubectl get svc`)
   - Port: `15432`
   - Database: `cube`
   - Username: `cube`
   - Password: `stcs-production-secret-2024`

2. **Available Tables**:
   - `Customers` - Customer data with demographics
   - `Orders` - Order information with status
   - `Products` - Product catalog
   - `OrderItems` - Order line items
   - `Sales` - Unified sales view

3. **Key Features**:
   - Semantic layer abstraction
   - Pre-calculated metrics
   - Consistent business logic
   - Row-level security (when configured)

### Other BI Tools
The same SQL API can be used with:
- Tableau (PostgreSQL connector)
- Power BI (PostgreSQL connector)
- Looker (PostgreSQL connection)
- Grafana (PostgreSQL data source)

## Key Learnings and Milestones

### Major Milestones Achieved
1. ✅ **Multi-layer Architecture**: PostgreSQL → Trino → Cube.js → BI Tools
2. ✅ **Kubernetes Deployment**: Production-ready containerized deployment
3. ✅ **Semantic Layer**: Business logic centralization with proper metrics
4. ✅ **BI Integration**: Successful Sigma Computing connectivity
5. ✅ **Model Standardization**: Consistent approach to cube and view definitions

### Critical Technical Discoveries
1. **YAML Limitation**: Cube.js only supports JavaScript models in production
2. **ConfigMap Strategy**: Kubernetes-native configuration management
3. **Type Casting**: Database type compatibility requirements
4. **Join Relationships**: Proper semantic modeling for complex queries

### Best Practices Established
1. **Development Workflow**: Local YAML → Production JavaScript conversion
2. **Deployment Strategy**: ConfigMap-based model management
3. **Error Handling**: Systematic troubleshooting approach
4. **Documentation**: Comprehensive knowledge capture

---

*This documentation represents the complete journey from initial setup to production deployment of the Cube.js semantic layer on Kubernetes, including all technical decisions, troubleshooting steps, and operational procedures.*