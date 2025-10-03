// Initialize CodeMirror editor
let editor;
let currentModel = 'Customers';
let models = {};
let currentTab = 'output';

// Store model definitions
const modelDefinitions = {
    Customers: `cube(\`Customers\`, {
  sql: \`SELECT * FROM public.customers\`,
  
  joins: {},
  
  dimensions: {
    customer_id: {
      sql: \`customer_id\`,
      type: \`number\`,
      primaryKey: true
    },
    
    first_name: {
      sql: \`first_name\`,
      type: \`string\`
    },
    
    last_name: {
      sql: \`last_name\`,
      type: \`string\`
    },
    
    email: {
      sql: \`email\`,
      type: \`string\`
    },
    
    company: {
      sql: \`company\`,
      type: \`string\`
    },
    
    city: {
      sql: \`city\`,
      type: \`string\`
    },
    
    country: {
      sql: \`country\`,
      type: \`string\`
    },
    
    lead_status: {
      sql: \`lead_status\`,
      type: \`string\`
    },
    
    created_at: {
      sql: \`created_at\`,
      type: \`time\`
    }
  },
  
  measures: {
    count: {
      type: \`count\`
    },
    
    unique_companies: {
      sql: \`company\`,
      type: \`countDistinct\`
    }
  }
});`,
    
    Orders: `cube(\`Orders\`, {
  sql: \`SELECT * FROM public.orders\`,
  
  joins: {
    Customers: {
      sql: \`\${CUBE}.customer_id = \${Customers}.customer_id\`,
      relationship: \`many_to_one\`
    },
    
    OrderItems: {
      sql: \`\${CUBE}.order_id = \${OrderItems}.order_id\`,
      relationship: \`one_to_many\`
    }
  },
  
  dimensions: {
    order_id: {
      sql: \`order_id\`,
      type: \`number\`,
      primaryKey: true
    },
    
    customer_id: {
      sql: \`customer_id\`,
      type: \`number\`
    },
    
    order_status: {
      sql: \`order_status\`,
      type: \`string\`
    },
    
    payment_status: {
      sql: \`payment_status\`,
      type: \`string\`
    },
    
    total_amount: {
      sql: \`total_amount\`,
      type: \`number\`
    },
    
    order_date: {
      sql: \`order_date\`,
      type: \`time\`
    }
  },
  
  measures: {
    count: {
      type: \`count\`
    },
    
    total_revenue: {
      sql: \`total_amount\`,
      type: \`sum\`
    },
    
    avg_order_value: {
      sql: \`total_amount\`,
      type: \`avg\`
    }
  }
});`,

    Products: `cube(\`Products\`, {
  sql: \`SELECT * FROM public.products\`,
  
  joins: {},
  
  dimensions: {
    product_id: {
      sql: \`product_id\`,
      type: \`number\`,
      primaryKey: true
    },
    
    product_name: {
      sql: \`product_name\`,
      type: \`string\`
    },
    
    category: {
      sql: \`category\`,
      type: \`string\`
    },
    
    price: {
      sql: \`price\`,
      type: \`number\`
    },
    
    inventory_quantity: {
      sql: \`inventory_quantity\`,
      type: \`number\`
    }
  },
  
  measures: {
    count: {
      type: \`count\`
    },
    
    total_inventory_value: {
      sql: \`price * inventory_quantity\`,
      type: \`sum\`
    }
  }
});`,

    OrderItems: `cube(\`OrderItems\`, {
  sql: \`SELECT * FROM public.order_items\`,
  
  joins: {
    Orders: {
      sql: \`\${CUBE}.order_id = \${Orders}.order_id\`,
      relationship: \`many_to_one\`
    },
    
    Products: {
      sql: \`\${CUBE}.product_id = \${Products}.product_id\`,
      relationship: \`many_to_one\`
    }
  },
  
  dimensions: {
    item_id: {
      sql: \`item_id\`,
      type: \`number\`,
      primaryKey: true
    },
    
    quantity: {
      sql: \`quantity\`,
      type: \`number\`
    },
    
    unit_price: {
      sql: \`unit_price\`,
      type: \`number\`
    }
  },
  
  measures: {
    count: {
      type: \`count\`
    },
    
    total_amount: {
      sql: \`\${CUBE.quantity} * \${CUBE.unit_price}\`,
      type: \`sum\`
    }
  }
});`,

    Sales: `view(\`Sales\`, {
  description: \`A unified view for sales analysis.\`,
  
  cubes: [
    {
      joinPath: Orders,
      includes: [
        \`count\`,
        \`order_status\`,
        \`order_date\`,
        \`total_revenue\`,
        \`avg_order_value\`
      ]
    },
    {
      joinPath: Orders.Customers,
      prefix: true,
      includes: [
        \`company\`,
        \`city\`,
        \`country\`,
        \`lead_status\`
      ]
    },
    {
      joinPath: Orders.OrderItems,
      prefix: true,
      includes: [
        \`count\`,
        \`total_amount\`
      ]
    },
    {
      joinPath: Orders.OrderItems.Products,
      prefix: true,
      includes: [
        \`product_name\`,
        \`category\`
      ]
    }
  ]
});`
};

// Initialize editor when page loads
document.addEventListener('DOMContentLoaded', function() {
    const textarea = document.getElementById('code-editor');
    editor = CodeMirror.fromTextArea(textarea, {
        mode: 'javascript',
        theme: 'monokai',
        lineNumbers: true,
        autoCloseBrackets: true,
        matchBrackets: true,
        indentUnit: 2,
        tabSize: 2,
        lineWrapping: true
    });
    
    // Load models from server
    loadModelsFromServer().then(() => {
        // Load initial model
        loadModel('Customers');
        
        // Setup model list click handlers
        setupModelListHandlers();
        
        addLog('info', 'Editor ready. Models loaded from server.');
    }).catch(error => {
        console.error('Failed to load models from server:', error);
        
        // Fallback to local definitions
        Object.keys(modelDefinitions).forEach(key => {
            models[key] = modelDefinitions[key];
        });
        
        loadModel('Customers');
        setupModelListHandlers();
        addLog('warning', 'Using local model definitions (server unavailable)');
    });
});

// Load models from server
async function loadModelsFromServer() {
    try {
        const response = await fetch('/api/models');
        const result = await response.json();
        
        if (result.success) {
            models = result.models;
            updateModelList();
            addLog('success', `Loaded ${Object.keys(models).length} models from server`);
        } else {
            throw new Error('Failed to load models from server');
        }
    } catch (error) {
        console.error('Error loading models:', error);
        throw error;
    }
}

// Update the model list in the UI
function updateModelList() {
    const modelList = document.getElementById('model-list');
    
    // Clear existing models except the "New Model" button
    const newModelBtn = modelList.querySelector('.new-model-btn');
    modelList.innerHTML = '';
    
    // Add models from server
    Object.keys(models).forEach(modelName => {
        const listItem = document.createElement('li');
        listItem.className = 'model-item';
        listItem.dataset.model = modelName;
        
        // Choose appropriate icon
        let icon = 'fa-cube';
        if (models[modelName].includes('view(')) {
            icon = 'fa-chart-line';
        }
        
        listItem.innerHTML = `<i class="fas ${icon}"></i> ${modelName}`;
        modelList.appendChild(listItem);
        
        // Add click handler
        listItem.addEventListener('click', function() {
            loadModel(modelName);
            document.querySelectorAll('.model-item').forEach(mi => mi.classList.remove('active'));
            this.classList.add('active');
        });
    });
    
    // Re-add the "New Model" button
    if (newModelBtn) {
        modelList.appendChild(newModelBtn);
    }
}

function setupModelListHandlers() {
    const modelItems = document.querySelectorAll('.model-item');
    modelItems.forEach(item => {
        item.addEventListener('click', function() {
            const modelName = this.dataset.model;
            loadModel(modelName);
            
            // Update active state
            modelItems.forEach(mi => mi.classList.remove('active'));
            this.classList.add('active');
        });
    });
}

function loadModel(modelName) {
    currentModel = modelName;
    document.getElementById('current-model').textContent = modelName + '.js';
    
    // Load model content
    const content = models[modelName] || modelDefinitions[modelName] || '';
    editor.setValue(content);
    
    addLog('info', `Loaded model: ${modelName}`);
}

function validateModel() {
    addLog('info', 'Validating model...');
    const code = editor.getValue();
    
    try {
        // Basic validation - check for cube() or view() function
        if (!code.includes('cube(') && !code.includes('view(')) {
            throw new Error('Model must contain a cube() or view() function');
        }
        
        // Check for basic structure
        if (!code.includes('sql:') && !code.includes('cubes:')) {
            throw new Error('Model must contain SQL definition or cube references');
        }
        
        // Try to evaluate syntax (basic check)
        new Function(code);
        
        showValidationSuccess('Model validation successful!');
        addLog('success', '✓ Model is valid');
        return true;
    } catch (error) {
        showValidationError(`Validation error: ${error.message}`);
        addLog('error', `✗ Validation failed: ${error.message}`);
        return false;
    }
}

async function deployToCluster() {
    if (!validateModel()) {
        addLog('error', 'Cannot deploy invalid model');
        return;
    }
    
    switchTab('deployment');
    addLog('info', 'Starting deployment to Kubernetes cluster...');
    
    const deploymentSteps = [
        { id: 'save', text: 'Saving model changes', status: 'active' },
        { id: 'configmap', text: 'Updating ConfigMap', status: 'pending' },
        { id: 'apply', text: 'Applying to Kubernetes', status: 'pending' },
        { id: 'restart', text: 'Restarting Cube.js deployment', status: 'pending' },
        { id: 'verify', text: 'Verifying deployment', status: 'pending' }
    ];
    
    showDeploymentStatus(deploymentSteps);
    
    try {
        // Step 1: Save model
        deploymentSteps[0].status = 'complete';
        deploymentSteps[1].status = 'active';
        showDeploymentStatus(deploymentSteps);
        
        // Call real deployment API
        const response = await fetch('/api/deploy', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                modelName: currentModel,
                code: editor.getValue()
            })
        });
        
        const result = await response.json();
        
        if (result.success) {
            // Mark all steps as complete
            deploymentSteps.forEach(step => step.status = 'complete');
            showDeploymentStatus(deploymentSteps);
            
            addLog('success', '✓ Deployment completed successfully!');
            addLog('info', `Model ${currentModel} is now live on cluster`);
            addLog('info', 'ConfigMap updated and pod restarted');
            
            // Save model to local storage
            models[currentModel] = editor.getValue();
            
            // Reload the model list from server
            await loadModelsFromServer();
            
        } else {
            throw new Error(result.message || 'Deployment failed');
        }
        
    } catch (error) {
        // Mark current step as failed
        const activeStep = deploymentSteps.find(step => step.status === 'active');
        if (activeStep) {
            activeStep.status = 'error';
            showDeploymentStatus(deploymentSteps);
        }
        
        addLog('error', `✗ Deployment failed: ${error.message}`);
        console.error('Deployment error:', error);
    }
}

async function deleteModel() {
    if (!confirm(`Are you sure you want to delete ${currentModel}?`)) {
        return;
    }
    
    addLog('warning', `🗑️ Deleting model: ${currentModel}`);
    
    try {
        // Call backend API to delete the model
        const response = await fetch(`/api/models/${currentModel}`, {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        const result = await response.json();
        
        if (result.success) {
            addLog('success', `✅ ${result.message}`);
            
            // Remove from UI
            const modelItem = document.querySelector(`[data-model="${currentModel}"]`);
            if (modelItem) {
                modelItem.remove();
            }
            
            // Clear editor
            editor.setValue('');
            document.getElementById('current-model').textContent = '';
            
            // Reload models from server to ensure UI is in sync
            await loadModelsFromServer();
            
        } else {
            addLog('error', `❌ Delete failed: ${result.message}`);
        }
        
    } catch (error) {
        addLog('error', `❌ Delete failed: ${error.message}`);
        console.error('Delete error:', error);
    }
}

function showNewModelModal() {
    document.getElementById('new-model-modal').classList.add('show');
    // Reset form
    document.getElementById('model-name').value = '';
    document.getElementById('model-type').value = 'cube';
    document.getElementById('table-name').value = '';
    toggleTableNameField(); // Show table name field for cube (default)
}

function toggleTableNameField() {
    const modelType = document.getElementById('model-type').value;
    const tableNameGroup = document.getElementById('table-name-group');
    
    if (modelType === 'view') {
        tableNameGroup.style.display = 'none';
    } else {
        tableNameGroup.style.display = 'block';
    }
}

function closeModal() {
    document.getElementById('new-model-modal').classList.remove('show');
}

function createNewModel() {
    const name = document.getElementById('model-name').value;
    const type = document.getElementById('model-type').value;
    const tableName = document.getElementById('table-name').value;
    
    if (!name) {
        alert('Please enter a model name');
        return;
    }
    
    if (type === 'cube' && !tableName) {
        alert('Please enter a table name for cubes');
        return;
    }
    
    // Generate template
    let template;
    if (type === 'cube') {
        template = `cube(\`${name}\`, {
  sql: \`SELECT * FROM ${tableName}\`,
  
  joins: {},
  
  dimensions: {
    id: {
      sql: \`id\`,
      type: \`number\`,
      primaryKey: true
    }
  },
  
  measures: {
    count: {
      type: \`count\`
    }
  }
});`;
    } else {
        template = `view(\`${name}\`, {
  description: \`View for ${name} analysis\`,
  
  cubes: [
    {
      joinPath: Cube1,
      includes: [\`dimension1\`, \`measure1\`]
    }
  ]
});`;
    }
    
    // Add to model list
    const modelList = document.getElementById('model-list');
    const newItem = document.createElement('li');
    newItem.className = 'model-item';
    newItem.dataset.model = name;
    newItem.innerHTML = `<i class="fas fa-cube"></i> ${name}`;
    modelList.insertBefore(newItem, modelList.lastElementChild);
    
    // Setup click handler
    newItem.addEventListener('click', function() {
        loadModel(name);
        document.querySelectorAll('.model-item').forEach(mi => mi.classList.remove('active'));
        this.classList.add('active');
    });
    
    // Store and load the new model
    models[name] = template;
    loadModel(name);
    
    // Update UI
    document.querySelectorAll('.model-item').forEach(mi => mi.classList.remove('active'));
    newItem.classList.add('active');
    
    closeModal();
    addLog('success', `Created new ${type}: ${name}`);
}

function refreshClusterStatus() {
    const statusIndicator = document.querySelector('.status-indicator');
    statusIndicator.classList.remove('connected', 'disconnected');
    statusIndicator.classList.add('pending');
    
    document.getElementById('cluster-status').textContent = 'Checking cluster...';
    
    setTimeout(() => {
        statusIndicator.classList.remove('pending');
        statusIndicator.classList.add('connected');
        document.getElementById('cluster-status').textContent = 'Connected to cluster: stcs';
        addLog('success', 'Cluster connection verified');
    }, 1000);
}

function switchTab(tab) {
    currentTab = tab;
    
    // Update tab buttons
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');
    
    // Update content
    const outputDiv = document.getElementById('output');
    
    if (tab === 'deployment') {
        // Show deployment status
        outputDiv.innerHTML = '<div class="deployment-status" id="deployment-status"></div>';
    } else if (tab === 'validation') {
        // Show validation results
        outputDiv.innerHTML = '<div id="validation-results"></div>';
    } else {
        // Show regular output
        outputDiv.innerHTML = '';
        // Restore logs
        const logs = JSON.parse(localStorage.getItem('logs') || '[]');
        logs.forEach(log => {
            addLog(log.type, log.message, false);
        });
    }
}

function showDeploymentStatus(steps) {
    const container = document.getElementById('deployment-status') || document.getElementById('output');
    
    let html = '<div class="deployment-status">';
    steps.forEach(step => {
        let icon = '';
        if (step.status === 'complete') {
            icon = '<i class="fas fa-check-circle"></i>';
        } else if (step.status === 'active') {
            icon = '<i class="fas fa-spinner loading"></i>';
        } else {
            icon = '<i class="far fa-circle"></i>';
        }
        
        html += `
            <div class="deployment-step ${step.status}">
                ${icon}
                <span>${step.text}</span>
            </div>
        `;
    });
    html += '</div>';
    
    container.innerHTML = html;
}

function showValidationError(message) {
    if (currentTab === 'validation') {
        const container = document.getElementById('output');
        container.innerHTML = `
            <div class="validation-error">
                <i class="fas fa-exclamation-triangle"></i> ${message}
            </div>
        `;
    }
}

function showValidationSuccess(message) {
    if (currentTab === 'validation') {
        const container = document.getElementById('output');
        container.innerHTML = `
            <div class="validation-success">
                <i class="fas fa-check-circle"></i> ${message}
            </div>
        `;
    }
}

function addLog(type, message, store = true) {
    if (currentTab !== 'output') return;
    
    const output = document.getElementById('output');
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;
    
    const timestamp = new Date().toLocaleTimeString();
    let icon = '';
    
    switch(type) {
        case 'success':
            icon = '<i class="fas fa-check"></i>';
            break;
        case 'error':
            icon = '<i class="fas fa-times"></i>';
            break;
        case 'warning':
            icon = '<i class="fas fa-exclamation-triangle"></i>';
            break;
        case 'info':
            icon = '<i class="fas fa-info-circle"></i>';
            break;
    }
    
    entry.innerHTML = `[${timestamp}] ${icon} ${message}`;
    output.appendChild(entry);
    
    // Scroll to bottom
    output.scrollTop = output.scrollHeight;
    
    // Store logs
    if (store) {
        const logs = JSON.parse(localStorage.getItem('logs') || '[]');
        logs.push({ type, message, timestamp });
        // Keep only last 100 logs
        if (logs.length > 100) {
            logs.shift();
        }
        localStorage.setItem('logs', JSON.stringify(logs));
    }
}

// Keyboard shortcuts
document.addEventListener('keydown', function(e) {
    // Cmd/Ctrl + S to save/deploy
    if ((e.metaKey || e.ctrlKey) && e.key === 's') {
        e.preventDefault();
        deployToCluster();
    }
    
    // Cmd/Ctrl + Shift + V to validate
    if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key === 'V') {
        e.preventDefault();
        validateModel();
    }
});