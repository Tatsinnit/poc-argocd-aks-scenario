# System Verification Guide

This guide helps you verify that all components are properly connected and working together.

## 🔍 Quick Health Check

Run this command to check everything at once:

```bash
# Run from project root
./verify-system.sh
```

Or check each component individually below:

## 1️⃣ Azure Infrastructure

### Check AKS Cluster
```bash
# Verify cluster exists and is running
az aks show --resource-group rg-argocd-demo --name aks-argocd-demo \
  --query "{Name:name, Status:provisioningState, K8sVersion:kubernetesVersion}" \
  --output table

# Check node status
kubectl get nodes
```

**Expected:** 3 nodes in "Ready" state

### Check Azure Container Registry
```bash
# Verify ACR exists
az acr show --resource-group rg-argocd-demo \
  --name $(cat infrastructure/scripts/.acr-name 2>/dev/null || echo "YOUR_ACR_NAME") \
  --query "{Name:name, LoginServer:loginServer, Status:provisioningState}" \
  --output table

# Check images in ACR
az acr repository list --name $(cat infrastructure/scripts/.acr-name 2>/dev/null || echo "YOUR_ACR_NAME")
```

**Expected:** ACR exists with "sample-app" repository

### Check kubectl Connection
```bash
# Verify kubectl is connected to correct cluster
kubectl cluster-info

# Check current context
kubectl config current-context
```

**Expected:** Context shows your AKS cluster

## 2️⃣ ArgoCD Installation

### Check ArgoCD Pods
```bash
# All pods should be Running
kubectl get pods -n argocd

# Check specific components
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

**Expected:** All pods in "Running" state, 1/1 Ready

### Check ArgoCD Services
```bash
# Verify services are created
kubectl get svc -n argocd

# Check ArgoCD server endpoint
kubectl get svc argocd-server -n argocd
```

**Expected:** argocd-server service exists

### Test ArgoCD Access
```bash
# Port-forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
sleep 3

# Get admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

echo "ArgoCD URL: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"

# Test if UI is accessible
curl -k https://localhost:8080/api/version 2>/dev/null && echo "✅ ArgoCD API is accessible" || echo "❌ ArgoCD API not accessible"
```

## 3️⃣ ArgoCD Applications

### Check Application Definitions
```bash
# List all ArgoCD applications
kubectl get applications -n argocd

# Get detailed status
kubectl get applications -n argocd -o wide

# Check specific application
kubectl get application sample-app-dev -n argocd -o yaml
```

**Expected:** Applications show "Synced" and "Healthy"

### Check Application Sync Status
```bash
# Using ArgoCD CLI (if installed)
argocd app list

# Or using kubectl
kubectl get applications -n argocd \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\n"}{end}'
```

**Expected Output:**
```
sample-app-dev    Synced    Healthy
sample-app-prod   Synced    Healthy
```

## 4️⃣ Application Deployment

### Check Namespaces
```bash
# Verify dev and prod namespaces exist
kubectl get namespaces | grep -E "dev|prod"
```

**Expected:** Both `dev` and `prod` namespaces exist

### Check Deployments
```bash
# Check dev environment
kubectl get deployments -n dev
kubectl get pods -n dev
kubectl get svc -n dev

# Check prod environment
kubectl get deployments -n prod
kubectl get pods -n prod
kubectl get svc -n prod
```

**Expected:** 
- Dev: 2 pods running
- Prod: 3 pods running (or more if HPA scaled up)

### Test Application Endpoints
```bash
# Port-forward to dev app
kubectl port-forward svc/sample-app -n dev 3000:80 &
sleep 2

# Test endpoints
echo "Testing dev environment:"
curl -s http://localhost:3000/ | jq .
curl -s http://localhost:3000/health | jq .
curl -s http://localhost:3000/version | jq .

# Kill port-forward
pkill -f "port-forward.*sample-app.*dev"
```

**Expected:** All endpoints return valid JSON

## 5️⃣ Git Integration

### Check Git Repository Connection
```bash
# View ArgoCD application source
kubectl get application sample-app-dev -n argocd \
  -o jsonpath='{.spec.source.repoURL}{"\n"}'

# Check if path exists in repo
kubectl get application sample-app-dev -n argocd \
  -o jsonpath='{.spec.source.path}{"\n"}'
```

**Expected:** Shows your GitHub repository URL and correct path

### Verify Kustomize Configuration
```bash
# Preview what will be deployed to dev
kubectl kustomize kubernetes/overlays/dev

# Preview what will be deployed to prod
kubectl kustomize kubernetes/overlays/prod
```

**Expected:** Valid Kubernetes manifests output

## 6️⃣ CI/CD Pipeline

### Check GitHub Secrets
```bash
# Note: Run this on your local machine, not in cluster
echo "Check GitHub Settings → Secrets and variables → Actions"
echo ""
echo "Required secrets:"
echo "  ✓ ACR_NAME"
echo "  ✓ AZURE_CLIENT_ID (if using OIDC)"
echo "  ✓ AZURE_TENANT_ID (if using OIDC)"
echo "  ✓ AZURE_SUBSCRIPTION_ID (if using OIDC)"
echo "  OR"
echo "  ✓ AZURE_CREDENTIALS (if using service principal)"
```

### Check Workflow Status
```bash
# View last workflow run (requires GitHub CLI)
gh run list --limit 5 2>/dev/null || echo "Install GitHub CLI: brew install gh"
```

## 7️⃣ Container Image Flow

### Check Image in ACR
```bash
ACR_NAME=$(cat infrastructure/scripts/.acr-name 2>/dev/null || echo "YOUR_ACR_NAME")

# List all tags for sample-app
az acr repository show-tags --name $ACR_NAME --repository sample-app --output table

# Check if image is being used
kubectl get deployment -n dev -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

**Expected:** Image tag matches what's deployed

## 8️⃣ End-to-End Flow Test

### Complete GitOps Workflow Test
```bash
echo "Testing complete GitOps flow..."

# 1. Check current image version
CURRENT_TAG=$(kubectl get deployment sample-app -n dev -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d: -f2)
echo "Current image tag: $CURRENT_TAG"

# 2. Check ArgoCD sync status
SYNC_STATUS=$(kubectl get application sample-app-dev -n argocd -o jsonpath='{.status.sync.status}')
echo "Sync status: $SYNC_STATUS"

# 3. Verify auto-sync is enabled
AUTO_SYNC=$(kubectl get application sample-app-dev -n argocd -o jsonpath='{.spec.syncPolicy.automated}')
echo "Auto-sync enabled: $AUTO_SYNC"

# 4. Check last sync time
LAST_SYNC=$(kubectl get application sample-app-dev -n argocd -o jsonpath='{.status.operationState.finishedAt}')
echo "Last sync: $LAST_SYNC"
```

## 🔗 Connection Map

```
Developer → Git Push
    ↓
GitHub Repository (main branch)
    ↓
GitHub Actions Workflow
    ↓
Build Docker Image
    ↓
Push to Azure Container Registry
    ↓
Update kubernetes/overlays/*/kustomization.yaml
    ↓
Commit back to Git
    ↓
ArgoCD detects change (polls every 3min or webhook)
    ↓
ArgoCD pulls latest manifests
    ↓
ArgoCD applies to AKS cluster
    ↓
Pods deploy/update in dev/prod namespaces
    ↓
Application running!
```

## ✅ Success Criteria

Everything is working if:

- [ ] AKS cluster has 3 nodes in Ready state
- [ ] ArgoCD pods all Running (7 pods)
- [ ] Applications show "Synced" and "Healthy"
- [ ] Dev namespace has 2 pods running
- [ ] Prod namespace has 3+ pods running
- [ ] App endpoints respond correctly
- [ ] ACR contains sample-app images
- [ ] Git repository URL matches in ArgoCD apps
- [ ] Auto-sync is enabled

## 🐛 Common Issues

### ArgoCD shows "OutOfSync"
```bash
# Force refresh
argocd app get sample-app-dev --refresh
# Or manually sync
argocd app sync sample-app-dev
```

### Pods not starting
```bash
kubectl describe pod -n dev <pod-name>
kubectl logs -n dev <pod-name>
```

### Image pull errors
```bash
# Check ACR integration
az aks check-acr --resource-group rg-argocd-demo --name aks-argocd-demo --acr $ACR_NAME
```

### ArgoCD can't reach Git
```bash
# Check repository credentials
kubectl get secret -n argocd | grep repo
argocd repo list
```

## 📊 Monitoring Dashboard

```bash
# Quick status overview
echo "=== System Status ==="
echo ""
echo "Cluster Nodes:"
kubectl get nodes --no-headers | wc -l
echo ""
echo "ArgoCD Applications:"
kubectl get applications -n argocd --no-headers | wc -l
echo ""
echo "Dev Pods:"
kubectl get pods -n dev --no-headers 2>/dev/null | wc -l
echo ""
echo "Prod Pods:"
kubectl get pods -n prod --no-headers 2>/dev/null | wc -l
```

## 🔧 Advanced Verification

### Check ArgoCD Sync Waves
```bash
kubectl get application sample-app-dev -n argocd -o jsonpath='{.status.operationState.syncResult}'
```

### View ArgoCD Events
```bash
kubectl get events -n argocd --sort-by='.lastTimestamp' | tail -20
```

### Check Resource Health
```bash
kubectl get application sample-app-dev -n argocd -o jsonpath='{.status.resources[*].health.status}' | tr ' ' '\n' | sort | uniq -c
```

---

**Need help?** Check [docs/](../docs/) for detailed guides.
