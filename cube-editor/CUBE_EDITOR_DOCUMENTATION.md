# 🚀 Cube.js Model Editor - Complete Documentation

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Installation & Setup](#installation--setup)
- [User Guide](#user-guide)
- [API Reference](#api-reference)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## Overview

The **Cube.js Model Editor** is a professional web-based IDE for managing Cube.js semantic layer models with **live Kubernetes deployment**. It provides a complete CRUD interface for cube definitions, views, and real-time deployment to production clusters.

### 🎯 **Key Benefits**
- **Zero Downtime Editing** - Edit models and deploy instantly
- **Professional UI** - Syntax highlighting, validation, and error handling
- **Kubernetes Native** - Direct integration with K8s ConfigMaps and deployments
- **Auto-Mount Management** - Automatic volume mount creation/deletion
- **Live Feedback** - Real-time logs and deployment status

### 🏗️ **Built For**
- Data Engineers managing semantic layers
- DevOps teams deploying Cube.js on Kubernetes
- Business Intelligence teams needing rapid model iteration
- Organizations requiring production-grade model management

---

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Browser UI    │────►│  Node.js     │────►│   Kubernetes    │
│   (React-like)  │◄────│  Express     │◄────│   ConfigMap     │
│                 │     │  Server      │     │                 │
└─────────────────┘     └──────────────┘     └─────────────────┘
        │                      │                       │
        │                      │                       ▼
    Edit Models           Update YAML           Deploy to Cube.js
    Validate Code         Manage Mounts         Live Semantic Layer
```

### 🔧 **Technology Stack**

**Frontend:**
- **HTML5/CSS3** - Responsive design with CSS Grid
- **Vanilla JavaScript** - No framework dependencies
- **CodeMirror** - Professional code editor
- **Font Awesome** - Icon library

**Backend:**
- **Node.js** - Runtime environment
- **Express.js** - Web framework
- **js-yaml** - YAML processing
- **child_process** - Kubernetes integration

**Infrastructure:**
- **Kubernetes** - Container orchestration
- **ConfigMaps** - Model storage
- **Volume Mounts** - File system integration
- **Deployments** - Rolling updates

---

## Features

### ✨ **Core Features**

#### 🎨 **Visual Model Editor**
- **Syntax Highlighting** - JavaScript with Cube.js awareness
- **Auto-completion** - Bracket matching and code folding
- **Real-time Validation** - Syntax checking before deployment
- **Error Highlighting** - Clear error messages and line numbers

#### 🚀 **One-Click Deployment**
- **ConfigMap Updates** - Automatic YAML generation
- **Volume Mount Management** - Auto-add/remove mounts for new models
- **Rolling Deployments** - Zero-downtime updates
- **Status Monitoring** - Real-time deployment progress

#### 📊 **Model Management**
- **CRUD Operations** - Create, Read, Update, Delete models
- **Model Types** - Support for Cubes and Views
- **Template Generation** - Auto-generate boilerplate code
- **Model Validation** - Pre-deployment syntax checking

#### 🔍 **Monitoring & Debugging**
- **Live Logs** - Real-time server and deployment logs
- **Cluster Status** - Health monitoring and diagnostics
- **Deployment History** - Track changes and rollbacks
- **Error Reporting** - Detailed error messages with context

### 🔧 **Advanced Features**

#### 🎯 **Professional Workflow**
- **Atomic Operations** - All-or-nothing deployments
- **Rollback Support** - Quick revert to previous versions
- **Validation Pipeline** - Multi-stage validation process
- **Progress Tracking** - Step-by-step deployment visibility

#### 🔐 **Enterprise Ready**
- **Kubernetes RBAC** - Role-based access control
- **Audit Logging** - Complete change tracking
- **Error Recovery** - Graceful failure handling
- **Production Safeguards** - Validation before deployment

---

## Installation & Setup

### 📋 **Prerequisites**

```bash
# Required tools
node --version    # v16+ required
kubectl version   # Kubernetes CLI
docker --version  # Container runtime

# Kubernetes cluster access
kubectl config current-context  # Should show your cluster
kubectl get namespace stcs      # Target namespace must exist
```

### 🚀 **Quick Start**

```bash
# 1. Clone or navigate to the cube-editor directory
cd /path/to/cube-editor

# 2. Install dependencies
npm install

# 3. Verify Kubernetes access
kubectl get configmap cube-models -n stcs -o yaml

# 4. Start the server
npm start

# 5. Open in browser
open http://localhost:3333
```

### ⚙️ **Configuration**

**Server Configuration** (`server.js`):
```javascript
const NAMESPACE = 'stcs';                    // Kubernetes namespace
const CONFIGMAP_NAME = 'cube-models';       // ConfigMap name
const PORT = 3333;                          // Server port
```

**Kubernetes Requirements**:
```yaml
# Required RBAC permissions
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "patch", "update"]
```

---

## User Guide

### 🎯 **Getting Started**

#### 1. **Accessing the Editor**
Navigate to `http://localhost:3333` to access the web interface.

**Interface Overview:**
- **Left Sidebar** - Model list and navigation
- **Center Panel** - Code editor with syntax highlighting  
- **Right Panel** - Output logs, deployment status, validation results

#### 2. **Creating Your First Model**

**Create a Cube:**
```javascript
// 1. Click "New Model"
// 2. Name: "MyInventory"
// 3. Type: "Cube"
// 4. Table: "public.products"

cube(`MyInventory`, {
  sql: `SELECT * FROM public.products`,
  
  dimensions: {
    id: {
      sql: `product_id`,
      type: `number`,
      primaryKey: true
    },
    name: {
      sql: `product_name`,
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

**Create a View:**
```javascript
// 1. Click "New Model"
// 2. Name: "SalesOverview"
// 3. Type: "View"

view(`SalesOverview`, {
  description: `Sales analysis view`,
  
  cubes: [
    {
      joinPath: Orders,
      includes: ['order_date', 'total_amount', 'count']
    },
    {
      joinPath: Orders.Customers,
      prefix: true,
      includes: ['company', 'city']
    }
  ]
});
```

#### 3. **Deployment Workflow**

1. **Edit** - Modify your model in the code editor
2. **Validate** - Click "Validate" to check syntax
3. **Deploy** - Click "Deploy" to push to Kubernetes
4. **Monitor** - Watch deployment progress in output panel
5. **Verify** - Check Cube.js API for your changes

### 📝 **Model Templates**

#### **Basic Cube Template**
```javascript
cube(`ModelName`, {
  sql: `SELECT * FROM schema.table`,
  
  joins: {
    RelatedModel: {
      sql: `${CUBE}.foreign_key = ${RelatedModel}.id`,
      relationship: `many_to_one`
    }
  },
  
  dimensions: {
    id: {
      sql: `id`,
      type: `number`,
      primaryKey: true
    },
    name: {
      sql: `name`,
      type: `string`
    },
    created_at: {
      sql: `created_at`,
      type: `time`
    }
  },
  
  measures: {
    count: {
      type: `count`
    },
    total: {
      sql: `amount`,
      type: `sum`
    }
  }
});
```

#### **Basic View Template**
```javascript
view(`ViewName`, {
  description: `Description of the view`,
  
  cubes: [
    {
      joinPath: MainCube,
      includes: ['dimension1', 'measure1']
    },
    {
      joinPath: MainCube.RelatedCube,
      prefix: true,
      includes: ['dimension2']
    }
  ]
});
```

### 🔧 **Advanced Operations**

#### **Model Relationships**
```javascript
// One-to-Many
joins: {
  OrderItems: {
    sql: `${CUBE}.order_id = ${OrderItems}.order_id`,
    relationship: `one_to_many`
  }
}

// Many-to-One
joins: {
  Customer: {
    sql: `${CUBE}.customer_id = ${Customer}.customer_id`,
    relationship: `many_to_one`
  }
}
```

#### **Complex Measures**
```javascript
measures: {
  revenue: {
    sql: `${CUBE.quantity} * ${CUBE.unit_price}`,
    type: `sum`,
    format: `currency`
  },
  
  running_total: {
    sql: `${CUBE.amount}`,
    type: `runningTotal`
  },
  
  conversion_rate: {
    sql: `${CUBE.conversions} / NULLIF(${CUBE.visits}, 0)`,
    type: `number`,
    format: `percent`
  }
}
```

---

## API Reference

### 🌐 **REST Endpoints**

#### **Model Management**

```http
GET /api/models
```
**Description:** Get all models  
**Response:**
```json
{
  "success": true,
  "models": {
    "Customers": "cube(`Customers`, { ... })",
    "Orders": "cube(`Orders`, { ... })"
  }
}
```

```http
GET /api/models/:name
```
**Description:** Get specific model  
**Response:**
```json
{
  "success": true,
  "model": "cube(`Customers`, { ... })"
}
```

```http
POST /api/deploy
```
**Description:** Deploy model to cluster  
**Request:**
```json
{
  "modelName": "MyModel",
  "code": "cube(`MyModel`, { ... })"
}
```
**Response:**
```json
{
  "success": true,
  "message": "Deployment successful",
  "steps": [
    {"step": "apply", "output": "configmap/cube-models configured"},
    {"step": "restart", "output": "deployment.apps/cube restarted"},
    {"step": "mount", "output": "deployment.apps/cube patched"},
    {"step": "status", "output": "deployment rolled out"}
  ]
}
```

```http
DELETE /api/models/:name
```
**Description:** Delete model from cluster  
**Response:**
```json
{
  "success": true,
  "message": "Model MyModel deleted successfully"
}
```

```http
POST /api/validate
```
**Description:** Validate model syntax  
**Request:**
```json
{
  "code": "cube(`Test`, { ... })",
  "modelName": "Test"
}
```

#### **Cluster Operations**

```http
GET /api/cluster/status
```
**Description:** Get cluster health status

```http
GET /api/cluster/logs
```
**Description:** Get Cube.js deployment logs

```http
GET /api/test/sql
```
**Description:** Test SQL API connectivity

### 🔧 **Backend Architecture**

#### **Core Functions**

```javascript
// Load models from ConfigMap
loadExistingModels()

// Execute Kubernetes commands
executeCommand(command, description)

// Check if volume mount exists
checkIfModelMountExists(modelName)

// Deploy workflow steps
async function deployModel(modelName, code) {
  // 1. Update ConfigMap
  // 2. Apply to Kubernetes
  // 3. Check volume mount
  // 4. Add mount if needed
  // 5. Restart deployment
  // 6. Wait for rollout
}
```

---

## Development

### 🛠️ **Development Setup**

```bash
# Install development dependencies
npm install

# Start in development mode with auto-reload
npm run dev

# Or with nodemon
nodemon server.js
```

### 📁 **Project Structure**

```
cube-editor/
├── index.html              # Main UI interface
├── script.js               # Frontend JavaScript
├── server.js               # Backend Express server
├── package.json            # Dependencies
├── README.md               # Basic documentation
├── CUBE_EDITOR_DOCUMENTATION.md  # This file
└── ../k8s/configmaps/
    └── cube-models.yaml    # Kubernetes ConfigMap
```

### 🔍 **Code Overview**

#### **Frontend (`script.js`)**
```javascript
// Key functions
initializeEditor()       // Setup CodeMirror
loadModelsFromServer()   // Fetch models from API
deployToCluster()        // Deploy via API
validateModel()          // Syntax validation
deleteModel()            // Remove model
```

#### **Backend (`server.js`)**
```javascript
// Express routes
app.get('/api/models')           // List models
app.post('/api/deploy')          // Deploy model
app.delete('/api/models/:name')  // Delete model
app.post('/api/validate')        // Validate syntax

// Kubernetes integration
executeCommand()                 // Run kubectl commands
checkIfModelMountExists()        // Check volume mounts
loadExistingModels()            // Load from ConfigMap
```

### 🧪 **Testing**

#### **Manual Testing Workflow**
```bash
# 1. Create test model
curl -X POST http://localhost:3333/api/deploy \
  -H "Content-Type: application/json" \
  -d '{"modelName": "Test", "code": "cube(..."}'

# 2. Verify in Cube.js API
curl http://34.42.61.231:4000/cubejs-api/v1/meta | jq '.cubes[].name'

# 3. Delete test model  
curl -X DELETE http://localhost:3333/api/models/Test

# 4. Verify removal
curl http://localhost:3333/api/models | jq '.models | keys'
```

#### **Integration Testing**
```bash
# Test full deployment pipeline
npm test                 # Run test suite
kubectl get configmap    # Verify ConfigMap updates
kubectl get deployment   # Check deployment status
```

---

## Troubleshooting

### 🚨 **Common Issues**

#### **Server Won't Start**
```bash
# Check kubectl configuration
kubectl config current-context

# Verify namespace exists
kubectl get namespace stcs

# Check file permissions
ls -la /Users/inno/Desktop/stcs/k8s/configmaps/cube-models.yaml
```

#### **Deployment Fails**
```bash
# Check Kubernetes permissions
kubectl auth can-i update configmaps -n stcs
kubectl auth can-i patch deployments -n stcs

# View detailed logs
kubectl logs -n stcs deployment/cube --tail=50

# Check deployment status
kubectl get deployment cube -n stcs -o yaml
```

#### **Models Not Loading**
```bash
# Verify ConfigMap exists and has data
kubectl get configmap cube-models -n stcs -o yaml

# Check volume mounts
kubectl describe deployment cube -n stcs | grep -A 10 "Volume Mounts"

# Test file access in pod
kubectl exec -n stcs deployment/cube -- ls -la /cube/conf/model/
```

#### **Volume Mount Issues**
```bash
# List current mounts
kubectl get deployment cube -n stcs -o json | jq '.spec.template.spec.containers[0].volumeMounts'

# Check if mount exists for model
kubectl get deployment cube -n stcs -o yaml | grep "ModelName.js"

# Manually add mount (if needed)
kubectl patch deployment cube -n stcs --type='json' -p='[{
  "op": "add",
  "path": "/spec/template/spec/containers/0/volumeMounts/-",
  "value": {"mountPath": "/cube/conf/model/ModelName.js", "name": "cube-models-volume", "subPath": "ModelName.js"}
}]'
```

### 🔧 **Debug Commands**

```bash
# Server logs
tail -f server.log

# Kubernetes events
kubectl get events -n stcs --sort-by='.lastTimestamp'

# Pod status
kubectl get pods -n stcs -w

# Test connectivity
curl -v http://localhost:3333/api/cluster/status
```

### 📋 **Error Codes**

| Error | Cause | Solution |
|-------|-------|----------|
| `ENOENT` | ConfigMap file not found | Check file path in server.js |
| `403 Forbidden` | Insufficient K8s permissions | Update RBAC rules |
| `Deployment timeout` | Pod startup issues | Check resource limits and image |
| `Volume mount failed` | ConfigMap key missing | Verify model exists in ConfigMap |

---

## Advanced Configuration

### ⚙️ **Production Deployment**

#### **Docker Container**
```dockerfile
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3333
CMD ["node", "server.js"]
```

#### **Kubernetes Deployment**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cube-editor
  namespace: stcs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cube-editor
  template:
    metadata:
      labels:
        app: cube-editor
    spec:
      serviceAccountName: cube-editor
      containers:
      - name: editor
        image: cube-editor:latest
        ports:
        - containerPort: 3333
        env:
        - name: NAMESPACE
          value: "stcs"
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

#### **Service Account & RBAC**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cube-editor
  namespace: stcs
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cube-editor
  namespace: stcs
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "patch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cube-editor
  namespace: stcs
subjects:
- kind: ServiceAccount
  name: cube-editor
  namespace: stcs
roleRef:
  kind: Role
  name: cube-editor
  apiGroup: rbac.authorization.k8s.io
```

### 🔐 **Security Configuration**

#### **Authentication Middleware**
```javascript
// Add to server.js
const auth = require('basic-auth');

app.use('/api', (req, res, next) => {
  const credentials = auth(req);
  
  if (!credentials || !validateUser(credentials)) {
    res.set('WWW-Authenticate', 'Basic realm="Cube Editor"');
    return res.status(401).send('Access denied');
  }
  
  next();
});
```

#### **Environment Variables**
```bash
# Production configuration
export NODE_ENV=production
export CUBE_EDITOR_AUTH=enabled
export CUBE_EDITOR_SECRET=your-secret-key
export KUBERNETES_NAMESPACE=stcs
export LOG_LEVEL=info
```

### 📊 **Monitoring & Alerting**

#### **Health Checks**
```javascript
// Add to server.js
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: require('./package.json').version,
    kubernetes: {
      namespace: NAMESPACE,
      connected: true  // Add actual health check
    }
  });
});
```

#### **Metrics Collection**
```javascript
// Prometheus metrics
const prometheus = require('prom-client');

const deploymentCounter = new prometheus.Counter({
  name: 'cube_editor_deployments_total',
  help: 'Total number of deployments'
});

const deploymentDuration = new prometheus.Histogram({
  name: 'cube_editor_deployment_duration_seconds',
  help: 'Deployment duration in seconds'
});
```

### 🔄 **Backup & Recovery**

#### **ConfigMap Backup**
```bash
#!/bin/bash
# backup-configmap.sh
DATE=$(date +%Y%m%d_%H%M%S)
kubectl get configmap cube-models -n stcs -o yaml > "backup/cube-models_${DATE}.yaml"
```

#### **Automated Backups**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cube-models-backup
  namespace: stcs
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: kubectl:latest
            command:
            - /bin/sh
            - -c
            - kubectl get configmap cube-models -o yaml > /backup/cube-models-$(date +%Y%m%d).yaml
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          restartPolicy: OnFailure
```

---

## 📚 **Additional Resources**

### 🔗 **Related Documentation**
- [Cube.js Official Documentation](https://cube.dev/docs)
- [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Express.js Guide](https://expressjs.com/en/guide/routing.html)
- [CodeMirror Documentation](https://codemirror.net/doc/manual.html)

### 🛠️ **Development Tools**
- [Visual Studio Code](https://code.visualstudio.com/) - Recommended IDE
- [Kubernetes Extension](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tools)
- [Thunder Client](https://marketplace.visualstudio.com/items?itemName=rangav.vscode-thunder-client) - API testing

### 🎯 **Best Practices**
1. **Always validate** models before deployment
2. **Use semantic versioning** for model changes
3. **Monitor deployment logs** for errors
4. **Backup ConfigMaps** before major changes
5. **Test in staging** before production deployment
6. **Use descriptive names** for models and measures
7. **Document complex calculations** in model descriptions

---

## 📞 **Support & Contributing**

### 🐛 **Reporting Issues**
- Use GitHub Issues for bug reports
- Include logs, error messages, and reproduction steps
- Specify Kubernetes version and cluster configuration

### 🤝 **Contributing**
1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request with detailed description

### 📧 **Contact**
For questions or support, please reach out to the development team.

---

**Built with ❤️ for seamless Cube.js model management on Kubernetes**

*Last updated: October 2025*