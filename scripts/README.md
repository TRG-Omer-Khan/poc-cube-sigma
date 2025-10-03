# Cube.js Cluster Management Scripts

## 🚀 Quick Start

These scripts help you manage your Cube.js cluster on Kubernetes, including scaling up/down to save costs and monitoring cluster status.

### 📋 Available Scripts

| Script | Purpose | Usage |
|--------|---------|--------|
| **[cluster-status.sh](#cluster-statussh)** | Monitor cluster health | `./cluster-status.sh` |
| **[scale-down.sh](#scale-downsh)** | Scale cluster to 0 (save costs) | `./scale-down.sh` |
| **[scale-up.sh](#scale-upsh)** | Restore cluster to original state | `./scale-up.sh` |

## 📊 cluster-status.sh

Comprehensive cluster monitoring and status dashboard.

### Basic Usage
```bash
# Show complete cluster status
./cluster-status.sh

# Watch status in real-time
./cluster-status.sh --watch

# Test connectivity only
./cluster-status.sh --connectivity

# Show recent events
./cluster-status.sh --events

# Show help
./cluster-status.sh --help
```

### Features
- ✅ **Deployment Status** - Health of all deployments
- ✅ **Pod Monitoring** - Real-time pod status and health
- ✅ **Service Information** - External IPs and port accessibility
- ✅ **Connectivity Tests** - Automated API endpoint testing
- ✅ **Resource Usage** - CPU/Memory consumption (if metrics-server available)
- ✅ **Recent Events** - Kubernetes events for troubleshooting
- ✅ **Access Information** - URLs and connection strings
- ✅ **Available Actions** - Quick commands for common tasks

### Example Output
```
📊 Cube.js Cluster Status Dashboard
==================================================

📝 CLUSTER SUMMARY
----------------------------------------
  📊 Deployments: 3
  🏗️  Pods: 3/3 running
  🌐 Services: 4
  📈 Status: Fully Operational

🚀 DEPLOYMENTS
----------------------------------------
NAME                 READY      UP-TO-DATE   AVAILABLE  AGE      STATUS
--------------------------------------------------------------------------------
cube                 1/1        1            1          7h       ✅ Healthy
postgres-cube        1/1        1            1          7h       ✅ Healthy
trino-coordinator    1/1        1            1          7h       ✅ Healthy
```

## 📉 scale-down.sh

Scales all deployments to 0 replicas to save costs while preserving configuration.

### Usage
```bash
./scale-down.sh
```

### What It Does
1. **Backup Current State** - Saves replica counts for restoration
2. **Scale to Zero** - Sets all deployments to 0 replicas
3. **Wait for Termination** - Monitors pod shutdown process
4. **Verify Completion** - Confirms all pods have terminated
5. **Show Cost Savings** - Estimates cost reduction

### Cost Savings
- 🟢 **~80-90% cost reduction** - Only storage and LoadBalancer costs remain
- 🟢 **Preserves Configuration** - All services and ConfigMaps remain
- 🟢 **Quick Restoration** - Use scale-up.sh to restore

### Example Usage
```bash
$ ./scale-down.sh

🔽 Cube.js Cluster Scale Down Script
==================================================

🔍 Current cluster status:
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
cube                1/1     1            1           7h32m
postgres-cube       1/1     1            1           7h35m
trino-coordinator   1/1     1            1           7h34m

Are you sure you want to scale down all deployments in 'stcs'? (y/N): y

📦 Backing up current replica counts...
  📋 cube: 1 replicas
  📋 postgres-cube: 1 replicas
  📋 trino-coordinator: 1 replicas
✅ Backup saved to: scaling-backups/replica-counts-20251001_143022.txt

⬇️  Scaling down deployments...
  🔽 Scaling down cube...
    ✅ cube scaled to 0 replicas
  🔽 Scaling down postgres-cube...
    ✅ postgres-cube scaled to 0 replicas
  🔽 Scaling down trino-coordinator...
    ✅ trino-coordinator scaled to 0 replicas

⏳ Waiting for pods to terminate...
✅ All pods have terminated

💰 Cost Savings Information:
  • All compute resources scaled to 0
  • Only storage and LoadBalancer costs remain
  • Estimated savings: ~80-90% of cluster costs
  • Use scale-up.sh to restore the cluster

🎉 Cluster scale down completed successfully!
💡 To scale back up, run: ./scale-up.sh
```

## 📈 scale-up.sh

Restores the cluster to its original state using backed-up replica counts.

### Usage
```bash
./scale-up.sh
```

### What It Does
1. **Load Backup** - Reads saved replica counts or uses defaults
2. **Scale Up Deployments** - Restores original replica counts
3. **Wait for Ready** - Monitors deployment rollout
4. **Verify Services** - Tests API endpoint accessibility
5. **Show Access Info** - Provides connection details

### Smart Restoration
- 🟢 **Uses Backup Data** - Restores exact previous state
- 🟢 **Fallback to Defaults** - Works even without backup
- 🟢 **Health Monitoring** - Waits for all services to be ready
- 🟢 **Connectivity Testing** - Verifies APIs are accessible

### Example Usage
```bash
$ ./scale-up.sh

🔼 Cube.js Cluster Scale Up Script
==================================================

🔍 Current cluster status:
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
cube                0/0     0            0           7h45m
postgres-cube       0/0     0            0           7h48m
trino-coordinator   0/0     0            0           7h47m

📦 Found replica backup: scaling-backups/latest-replica-counts.txt
  📋 cube: 1 replicas
  📋 postgres-cube: 1 replicas
  📋 trino-coordinator: 1 replicas

Are you sure you want to scale up all deployments in 'stcs'? (y/N): y

⬆️  Scaling up deployments...
  🔼 Scaling up cube to 1 replicas...
    ✅ cube scaled to 1 replicas
  🔼 Scaling up postgres-cube to 1 replicas...
    ✅ postgres-cube scaled to 1 replicas
  🔼 Scaling up trino-coordinator to 1 replicas...
    ✅ trino-coordinator scaled to 1 replicas

⏳ Waiting for deployments to be ready...
✅ All deployments are ready!

🔍 Verifying service accessibility...
  ✅ Cube service external IP: 34.42.61.231
  🔍 Testing Cube.js API accessibility...
    ✅ Cube.js REST API is responding
  🔍 Testing SQL API accessibility...
    ✅ SQL API port is accessible

🌐 Access Information:
  🌐 External IP: 34.42.61.231
  📊 Dev Dashboard: http://34.42.61.231:3001
  🔗 REST API: http://34.42.61.231:4000/cubejs-api/v1
  🗄️  SQL API: 34.42.61.231:15432 (PostgreSQL protocol)

  📝 SQL Connection Example:
    PGPASSWORD=stcs-production-secret-2024 psql -h 34.42.61.231 -p 15432 -U cube -d cube

🎉 Cluster scale up completed successfully!
💡 Monitor status with: ./cluster-status.sh
```

## 🔄 Typical Workflow

### Daily Development
```bash
# Check cluster status
./cluster-status.sh

# Scale down when finished (save costs)
./scale-down.sh

# Scale up when starting work
./scale-up.sh
```

### Monitoring
```bash
# Real-time monitoring
./cluster-status.sh --watch

# Quick connectivity check
./cluster-status.sh --connectivity

# Check for issues
./cluster-status.sh --events
```

### Cost Optimization
```bash
# End of workday
./scale-down.sh

# Start of workday
./scale-up.sh

# Weekend shutdown
./scale-down.sh
# (Scale up Monday morning)
```

## 📁 File Structure

```
scripts/
├── README.md              # This documentation
├── cluster-status.sh      # Status monitoring script
├── scale-down.sh          # Scale down script
├── scale-up.sh            # Scale up script
└── scaling-backups/       # Backup directory (auto-created)
    ├── replica-counts-YYYYMMDD_HHMMSS.txt
    └── latest-replica-counts.txt -> (symlink to latest)
```

## 🛠️ Troubleshooting

### Scripts Won't Run
```bash
# Make scripts executable
chmod +x *.sh

# Check if kubectl is available
kubectl version --client
```

### Scale Operations Fail
```bash
# Check cluster connectivity
kubectl get nodes

# Verify namespace exists
kubectl get namespace stcs

# Check permissions
kubectl auth can-i "*" "*" --namespace=stcs
```

### Services Not Accessible After Scale Up
```bash
# Wait for external IP assignment (can take 2-5 minutes)
kubectl get svc cube -n stcs --watch

# Check pod readiness
kubectl get pods -n stcs

# Check recent events
./cluster-status.sh --events
```

### Backup Files Missing
```bash
# Scale up will use default replica counts
# Default: cube=1, postgres-cube=1, trino-coordinator=1
./scale-up.sh
```

## 🔐 Security Notes

- Scripts require `kubectl` access to the `stcs` namespace
- Backup files contain replica count information only (no sensitive data)
- Scripts use confirmation prompts to prevent accidental operations
- All operations are logged with clear output

## 🚀 Advanced Usage

### Automated Scheduling
```bash
# Scale down at 6 PM weekdays
0 18 * * 1-5 /path/to/scale-down.sh

# Scale up at 8 AM weekdays
0 8 * * 1-5 /path/to/scale-up.sh
```

### Integration with CI/CD
```bash
# In deployment pipeline
./scale-up.sh
# ... run tests ...
./scale-down.sh
```

### Custom Replica Counts
Edit backup files manually if needed:
```bash
# Edit scaling-backups/latest-replica-counts.txt
cube=2
postgres-cube=1
trino-coordinator=3
```

---

*These scripts provide a complete cluster lifecycle management solution for cost-effective Kubernetes operations.*