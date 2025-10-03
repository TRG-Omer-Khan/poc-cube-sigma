# Cube.js Model Editor UI

## 🚀 Overview

A web-based UI for editing Cube.js models with **live Kubernetes deployment**. Edit your semantic layer models in a visual interface and deploy them directly to your Kubernetes cluster with one click!

![Cube Model Editor](https://img.shields.io/badge/Cube.js-Model_Editor-667eea?style=for-the-badge&logo=kubernetes)

## ✨ Features

- 📝 **Visual Model Editor** - Syntax-highlighted JavaScript editor with CodeMirror
- 🚀 **One-Click Deployment** - Deploy models directly to Kubernetes
- ✅ **Real-time Validation** - Validate models before deployment
- 🔄 **Live ConfigMap Updates** - Automatically updates Kubernetes ConfigMaps
- 📊 **Cluster Status** - Monitor deployment status and logs
- 🎨 **Beautiful UI** - Modern, responsive interface
- ⚡ **Hot Reload** - Changes reflect immediately after deployment

## 🛠️ Installation

### Prerequisites
- Node.js 16+
- kubectl configured with cluster access
- Kubernetes cluster with Cube.js deployed

### Setup

1. **Install dependencies:**
```bash
cd cube-editor
npm install
```

2. **Start the server:**
```bash
npm start
```

3. **Open in browser:**
```
http://localhost:3333
```

## 📋 How It Works

### Architecture
```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Browser UI    │────►│  Node.js     │────►│   Kubernetes    │
│   (Editor)      │◄────│  Server      │◄────│   ConfigMap     │
└─────────────────┘     └──────────────┘     └─────────────────┘
        │                      │                       │
        │                      │                       ▼
    Edit Models           Update YAML           Deploy to Cube.js
```

### Workflow

1. **Edit Model** - Use the visual editor to modify Cube.js models
2. **Validate** - Click "Validate" to check syntax and structure
3. **Deploy** - Click "Deploy" to update the Kubernetes cluster
4. **Auto-Process**:
   - Updates ConfigMap YAML file
   - Applies ConfigMap to Kubernetes
   - Restarts Cube.js deployment
   - Verifies deployment status

## 🎯 UI Components

### Model List (Left Sidebar)
- Shows all available models
- Click to switch between models
- Add new models with the "New Model" button

### Code Editor (Center)
- Syntax-highlighted JavaScript editor
- Auto-completion and bracket matching
- Full Cube.js model syntax support

### Output Panel (Right)
- **Output Tab**: Real-time logs and messages
- **Deployment Tab**: Step-by-step deployment progress
- **Validation Tab**: Syntax and structure validation results

## 🔧 API Endpoints

The server provides the following REST API:

| Endpoint | Method | Description |
|----------|---------|------------|
| `/api/models` | GET | Get all models |
| `/api/models/:name` | GET | Get specific model |
| `/api/validate` | POST | Validate model syntax |
| `/api/deploy` | POST | Deploy model to cluster |
| `/api/models/:name` | DELETE | Delete a model |
| `/api/cluster/status` | GET | Get cluster status |
| `/api/cluster/logs` | GET | Get Cube.js logs |
| `/api/test/sql` | GET | Test SQL API connection |

## ⌨️ Keyboard Shortcuts

- **Cmd/Ctrl + S** - Save and deploy model
- **Cmd/Ctrl + Shift + V** - Validate model

## 📝 Model Templates

### Creating a New Cube
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

### Creating a New View
```javascript
view(`ViewName`, {
  description: `Description of the view`,
  
  cubes: [
    {
      joinPath: MainCube,
      includes: [`dimension1`, `measure1`]
    },
    {
      joinPath: MainCube.RelatedCube,
      prefix: true,
      includes: [`dimension2`]
    }
  ]
});
```

## 🚨 Deployment Process

When you click "Deploy", the following happens:

1. **Save Model** - Updates in-memory model storage
2. **Update ConfigMap** - Regenerates cube-models.yaml
3. **Apply to K8s** - `kubectl apply -f cube-models.yaml`
4. **Restart Deployment** - `kubectl rollout restart deployment/cube`
5. **Verify Status** - `kubectl rollout status deployment/cube`

## 🔐 Security Considerations

- **Authentication**: Add authentication middleware for production use
- **RBAC**: Ensure proper Kubernetes RBAC permissions
- **Validation**: Server-side validation prevents malicious code
- **Audit**: Consider adding audit logging for model changes

## 🐛 Troubleshooting

### Server won't start
- Check if kubectl is configured: `kubectl config current-context`
- Verify namespace exists: `kubectl get namespace stcs`

### Deployment fails
- Check Kubernetes permissions: `kubectl auth can-i update configmaps -n stcs`
- View logs: `kubectl logs -n stcs deployment/cube`

### Models not loading
- Check ConfigMap: `kubectl get configmap cube-models -n stcs -o yaml`
- Verify file path: `/k8s/configmaps/cube-models.yaml`

## 🔄 Development Mode

For development with auto-reload:
```bash
npm install -g nodemon
npm run dev
```

## 📦 Production Deployment

### Option 1: Docker Container
```dockerfile
FROM node:16-alpine
WORKDIR /app
COPY . .
RUN npm install --production
EXPOSE 3333
CMD ["node", "server.js"]
```

### Option 2: Kubernetes Deployment
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
    spec:
      containers:
      - name: editor
        image: cube-editor:latest
        ports:
        - containerPort: 3333
        env:
        - name: NAMESPACE
          value: "stcs"
```

## 🎯 Future Enhancements

- [ ] Multi-user support with authentication
- [ ] Version control for model changes
- [ ] Diff view for model comparisons
- [ ] Auto-save and drafts
- [ ] Model testing interface
- [ ] Performance metrics dashboard
- [ ] WebSocket for real-time logs
- [ ] Dark mode theme

## 📄 License

MIT

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

---

**Built with ❤️ for seamless Cube.js model management on Kubernetes**