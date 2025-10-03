# Cube.js Model Update Guide

## Quick Reference for Updating Cubes

### 🚀 Fast Update Workflow

#### 1. Edit Models
```bash
# Edit the main ConfigMap file
vim k8s/configmaps/cube-models.yaml
```

#### 2. Apply Changes
```bash
# Apply updated ConfigMap
kubectl apply -f k8s/configmaps/cube-models.yaml

# Restart deployment to load changes
kubectl rollout restart deployment/cube -n stcs

# Wait for deployment to complete
kubectl rollout status deployment/cube -n stcs
```

#### 3. Verify Changes
```bash
# Check if models loaded successfully
kubectl logs -n stcs deployment/cube --tail=20

# Test SQL API
PGPASSWORD=stcs-production-secret-2024 psql -h $(kubectl get svc cube -n stcs -o jsonpath='{.status.loadBalancer.ingress[0].ip}') -p 15432 -U cube -d cube -c "\dt"
```

### 📝 Common Model Changes

#### Adding a New Dimension
```javascript
// In cube definition, add to dimensions object:
new_field: {
  sql: `new_field_name`,
  type: `string`  // or number, boolean, time
}
```

#### Adding a New Measure
```javascript
// In cube definition, add to measures object:
total_revenue: {
  sql: `SUM(${CUBE.amount})`,
  type: `sum`,
  description: `Total revenue across all orders`
}
```

#### Adding a Join
```javascript
// In cube definition, add to joins object:
NewTable: {
  sql: `${CUBE}.foreign_key = ${NewTable}.primary_key`,
  relationship: `many_to_one`  // or one_to_many, one_to_one
}
```

#### Creating a New View
```javascript
// Add new entry to ConfigMap data section:
NewView.js: |
  view(`NewView`, {
    description: `Description of the view`,
    
    cubes: [
      {
        joinPath: MainCube,
        includes: [`dimension1`, `measure1`]
      },
      {
        joinPath: MainCube.JoinedCube,
        prefix: true,
        includes: [`dimension2`]
      }
    ]
  });
```

### 🔧 Troubleshooting Quick Fixes

#### Model Not Loading
```bash
# Check for syntax errors in logs
kubectl logs -n stcs deployment/cube --tail=50 | grep -i error

# Common issues:
# - Missing comma after dimension/measure
# - Incorrect SQL syntax
# - Invalid join relationships
```

#### Column Not Found Error
```bash
# Verify column exists in source table
kubectl exec -n stcs deployment/trino-coordinator -- trino --execute "DESCRIBE postgresql.public.table_name"

# Fix: Update model to match actual schema
```

#### Type Mismatch Error
```javascript
// Cast to correct type in SQL
dimension_name: {
  sql: `CAST(column_name AS VARCHAR)`,  // or TIMESTAMP, INTEGER, etc.
  type: `string`
}
```

### 📋 Model Development Checklist

Before deploying model changes:

- [ ] Test SQL syntax is valid
- [ ] Verify all referenced columns exist
- [ ] Check join relationships are correct
- [ ] Ensure proper data types are used
- [ ] Add descriptions for new measures
- [ ] Update views that might need new fields

### 🛠️ Development vs Production

#### Local Development (Optional)
```bash
# If developing locally, you can use YAML for prototyping
# Then convert to JavaScript for production deployment

# Local cube example (YAML):
# model/cubes/example.yml
cubes:
  - name: Example
    sql: SELECT * FROM table
    dimensions:
      field:
        sql: field
        type: string
```

#### Production Deployment (JavaScript)
```javascript
// k8s/configmaps/cube-models.yaml
Example.js: |
  cube(`Example`, {
    sql: `SELECT * FROM table`,
    dimensions: {
      field: {
        sql: `field`,
        type: `string`
      }
    }
  });
```

### 🔄 Rollback Procedure

If a deployment breaks:

```bash
# 1. Restore previous ConfigMap
kubectl apply -f backup-models-YYYYMMDD.yaml

# 2. Restart deployment
kubectl rollout restart deployment/cube -n stcs

# 3. Verify rollback
kubectl rollout status deployment/cube -n stcs
```

### 📊 Performance Optimization

#### Add Pre-aggregations
```javascript
// In cube definition:
preAggregations: {
  main: {
    type: `rollup`,
    measureReferences: [`count`, `totalRevenue`],
    dimensionReferences: [`category`, `date`],
    timeDimensionReference: `createdAt`,
    granularity: `day`
  }
}
```

#### Optimize Large Tables
```javascript
// Use SQL filters for large datasets
cube(`LargeTable`, {
  sql: `SELECT * FROM large_table WHERE created_at >= '2023-01-01'`,
  // ... rest of definition
});
```

### 🔐 Security Considerations

#### Row-Level Security
```javascript
// Add security context to cube
cube(`SecureCube`, {
  sql: `SELECT * FROM table WHERE tenant_id = '${SECURITY_CONTEXT.tenantId}'`,
  // ... rest of definition
});
```

#### Sensitive Data
```javascript
// Mark sensitive dimensions
email: {
  sql: `email`,
  type: `string`,
  meta: {
    secure: true
  }
}
```

---

*Keep this guide handy for quick model updates and troubleshooting!*