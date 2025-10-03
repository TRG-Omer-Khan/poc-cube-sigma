const express = require('express');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
const PORT = 3333;

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use(express.static(path.join(__dirname)));

// Store current models in memory
let currentModels = {};

// Configuration
const NAMESPACE = 'stcs';
const CONFIGMAP_NAME = 'cube-models';
const CONFIGMAP_PATH = path.join(__dirname, '..', 'k8s', 'configmaps', 'cube-models.yaml');

// Load existing models from ConfigMap file
function loadExistingModels() {
    try {
        const configMapContent = fs.readFileSync(CONFIGMAP_PATH, 'utf8');
        const configMap = yaml.load(configMapContent);
        
        if (configMap && configMap.data) {
            Object.keys(configMap.data).forEach(key => {
                const modelName = key.replace('.js', '');
                currentModels[modelName] = configMap.data[key];
            });
        }
        
        console.log(`Loaded ${Object.keys(currentModels).length} models from ConfigMap`);
        return currentModels;
    } catch (error) {
        console.error('Error loading existing models:', error);
        return {};
    }
}

// Initialize by loading existing models
loadExistingModels();

// API Endpoints

// Get all models
app.get('/api/models', (req, res) => {
    // Reload models from ConfigMap to ensure they're up to date
    loadExistingModels();
    
    res.json({
        success: true,
        models: currentModels
    });
});

// Get a specific model
app.get('/api/models/:name', (req, res) => {
    const modelName = req.params.name;
    
    if (currentModels[modelName]) {
        res.json({
            success: true,
            model: currentModels[modelName]
        });
    } else {
        res.status(404).json({
            success: false,
            message: `Model ${modelName} not found`
        });
    }
});

// Validate a model
app.post('/api/validate', (req, res) => {
    const { code, modelName } = req.body;
    
    try {
        // Basic validation
        if (!code.includes('cube(') && !code.includes('view(')) {
            throw new Error('Model must contain a cube() or view() function');
        }
        
        // Try to evaluate syntax (basic check)
        new Function(code);
        
        res.json({
            success: true,
            message: 'Model is valid'
        });
    } catch (error) {
        res.json({
            success: false,
            message: error.message
        });
    }
});

// Deploy model to cluster
app.post('/api/deploy', async (req, res) => {
    const { modelName, code } = req.body;
    
    try {
        // Update model in memory
        currentModels[modelName] = code;
        
        // Generate new ConfigMap YAML
        const configMap = {
            apiVersion: 'v1',
            kind: 'ConfigMap',
            metadata: {
                name: CONFIGMAP_NAME,
                namespace: NAMESPACE
            },
            data: {}
        };
        
        // Add all models to ConfigMap
        Object.keys(currentModels).forEach(name => {
            configMap.data[`${name}.js`] = currentModels[name];
        });
        
        // Save ConfigMap to file
        const yamlContent = yaml.dump(configMap);
        fs.writeFileSync(CONFIGMAP_PATH, yamlContent);
        
        // Deployment steps
        const steps = [];
        
        // Step 1: Apply ConfigMap
        await executeCommand(
            `kubectl apply -f ${CONFIGMAP_PATH}`,
            'Applying ConfigMap to Kubernetes'
        ).then(output => steps.push({ step: 'apply', output }));
        
        // Step 2: Restart deployment
        await executeCommand(
            `kubectl rollout restart deployment/cube -n ${NAMESPACE}`,
            'Restarting Cube.js deployment'
        ).then(output => steps.push({ step: 'restart', output }));
        
        // Step 3: Check if new model needs volume mount
        const isNewModel = !await checkIfModelMountExists(modelName);
        if (isNewModel) {
            await executeCommand(
                `kubectl patch deployment cube -n ${NAMESPACE} --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {"mountPath": "/cube/conf/model/${modelName}.js", "name": "cube-models-volume", "subPath": "${modelName}.js"}}]'`,
                `Adding volume mount for ${modelName}.js`
            ).then(output => steps.push({ step: 'mount', output }));
        }
        
        // Step 4: Wait for rollout
        await executeCommand(
            `kubectl rollout status deployment/cube -n ${NAMESPACE} --timeout=60s`,
            'Waiting for deployment to be ready'
        ).then(output => steps.push({ step: 'status', output }));
        
        res.json({
            success: true,
            message: 'Deployment successful',
            steps: steps
        });
        
    } catch (error) {
        console.error('Deployment error:', error);
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// Delete a model
app.delete('/api/models/:name', async (req, res) => {
    const modelName = req.params.name;
    
    try {
        // Remove from memory
        delete currentModels[modelName];
        
        // Update ConfigMap
        const configMap = {
            apiVersion: 'v1',
            kind: 'ConfigMap',
            metadata: {
                name: CONFIGMAP_NAME,
                namespace: NAMESPACE
            },
            data: {}
        };
        
        // Add remaining models to ConfigMap
        Object.keys(currentModels).forEach(name => {
            configMap.data[`${name}.js`] = currentModels[name];
        });
        
        // Save and apply
        const yamlContent = yaml.dump(configMap);
        fs.writeFileSync(CONFIGMAP_PATH, yamlContent);
        
        await executeCommand(
            `kubectl apply -f ${CONFIGMAP_PATH}`,
            'Updating ConfigMap'
        );
        
        // Remove volume mount for the deleted model
        const mountExists = await checkIfModelMountExists(modelName);
        if (mountExists) {
            // Get current volume mounts to find the index to remove
            const deploymentYaml = await executeCommand(
                `kubectl get deployment cube -n ${NAMESPACE} -o json`,
                'Getting deployment configuration'
            );
            
            const deployment = JSON.parse(deploymentYaml);
            const volumeMounts = deployment.spec.template.spec.containers[0].volumeMounts;
            const mountIndex = volumeMounts.findIndex(mount => 
                mount.mountPath === `/cube/conf/model/${modelName}.js`
            );
            
            if (mountIndex !== -1) {
                await executeCommand(
                    `kubectl patch deployment cube -n ${NAMESPACE} --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/volumeMounts/${mountIndex}"}]'`,
                    `Removing volume mount for ${modelName}.js`
                );
            }
        }
        
        await executeCommand(
            `kubectl rollout restart deployment/cube -n ${NAMESPACE}`,
            'Restarting deployment'
        );
        
        res.json({
            success: true,
            message: `Model ${modelName} deleted successfully`
        });
        
    } catch (error) {
        console.error('Delete error:', error);
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// Get cluster status
app.get('/api/cluster/status', async (req, res) => {
    try {
        const deploymentStatus = await executeCommand(
            `kubectl get deployment cube -n ${NAMESPACE} -o json`,
            'Getting deployment status'
        );
        
        const status = JSON.parse(deploymentStatus);
        
        res.json({
            success: true,
            status: {
                name: status.metadata.name,
                namespace: status.metadata.namespace,
                replicas: status.status.replicas,
                readyReplicas: status.status.readyReplicas,
                conditions: status.status.conditions
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// Get cluster logs
app.get('/api/cluster/logs', async (req, res) => {
    try {
        const logs = await executeCommand(
            `kubectl logs -n ${NAMESPACE} deployment/cube --tail=50`,
            'Getting Cube.js logs'
        );
        
        res.json({
            success: true,
            logs: logs.split('\n')
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// Test SQL API connection
app.get('/api/test/sql', async (req, res) => {
    try {
        const result = await executeCommand(
            `PGPASSWORD=stcs-production-secret-2024 psql -h 34.42.61.231 -p 15432 -U cube -d cube -c "SELECT 'Connected' as status"`,
            'Testing SQL API connection'
        );
        
        res.json({
            success: true,
            message: 'SQL API is accessible',
            output: result
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'SQL API connection failed',
            error: error.message
        });
    }
});

// Helper function to execute shell commands
function executeCommand(command, description) {
    return new Promise((resolve, reject) => {
        console.log(`Executing: ${description}`);
        
        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error: ${error.message}`);
                reject(error);
                return;
            }
            
            if (stderr && !stderr.includes('Warning')) {
                console.error(`Stderr: ${stderr}`);
            }
            
            console.log(`Success: ${description}`);
            resolve(stdout);
        });
    });
}

// Helper function to check if model volume mount exists
async function checkIfModelMountExists(modelName) {
    try {
        const deploymentYaml = await executeCommand(
            `kubectl get deployment cube -n ${NAMESPACE} -o yaml`,
            'Getting deployment configuration'
        );
        
        // Check if the volume mount for this model already exists
        return deploymentYaml.includes(`/cube/conf/model/${modelName}.js`);
    } catch (error) {
        console.error('Error checking volume mount:', error);
        return false;
    }
}

// Serve the HTML file
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Start server
app.listen(PORT, () => {
    console.log(`
    ╔════════════════════════════════════════╗
    ║     Cube.js Model Editor Server       ║
    ╠════════════════════════════════════════╣
    ║  Server running on:                    ║
    ║  http://localhost:${PORT}               ║
    ║                                        ║
    ║  Features:                             ║
    ║  • Live model editing                  ║
    ║  • Kubernetes deployment               ║
    ║  • Real-time validation                ║
    ║  • Cluster management                  ║
    ╚════════════════════════════════════════╝
    `);
    
    console.log(`Loaded models: ${Object.keys(currentModels).join(', ')}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\nShutting down server...');
    process.exit(0);
});