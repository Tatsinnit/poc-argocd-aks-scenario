# Application Deployment Guide

This guide walks through deploying the sample Node.js application using ArgoCD and GitOps practices.

## 🎯 Overview

We'll deploy a simple Node.js Express application that demonstrates:
- Container image building and pushing to ACR
- Kubernetes manifest management with Kustomize
- GitOps-based deployment with ArgoCD
- Multi-environment configuration

## 📦 The Sample Application

Located in `app/src/server.js`, it provides:

- **Health endpoint:** `GET /health` - Returns health status
- **Version endpoint:** `GET /version` - Shows app version
- **Root endpoint:** `GET /` - Hello World message

## 🚀 Deployment Steps

### Step 1: Build and Push Docker Image

```bash
# Navigate to app directory
cd app

# Set variables
ACR_NAME=$(az acr list --resource-group rg-argocd-demo --query '[0].name' -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
IMAGE_TAG="v1.0.0"

# Login to ACR
az acr login --name $ACR_NAME

# Build image
docker build -t $ACR_LOGIN_SERVER/sample-app:$IMAGE_TAG .

# Push to ACR
docker push $ACR_LOGIN_SERVER/sample-app:$IMAGE_TAG
```

Verify image in ACR:
```bash
az acr repository show-tags --name $ACR_NAME --repository sample-app --output table
```

### Step 2: Update Kubernetes Manifests

Update the image reference in your environment overlay:

```bash
cd ../kubernetes/overlays/dev

# Edit kustomization.yaml to reference your image
# Replace <your-acr>.azurecr.io with actual ACR login server
```

Example `kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
  - ../../base

images:
  - name: sample-app
    newName: <your-acr>.azurecr.io/sample-app
    newTag: v1.0.0

replicas:
  - name: sample-app
    count: 2
```

### Step 3: Commit and Push Changes

```bash
git add .
git commit -m "Deploy sample-app v1.0.0 to dev"
git push origin main
```

### Step 4: Deploy via ArgoCD

#### Option A: Using kubectl

```bash
cd ../../../argocd/applications

# Update sample-app.yaml with your Git repo URL
# Then apply:
kubectl apply -f sample-app.yaml
```

#### Option B: Using ArgoCD CLI

```bash
argocd app create sample-app \
  --repo https://github.com/yourusername/poc-argocd-aks-scenario.git \
  --path kubernetes/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

#### Option C: Using ArgoCD UI

1. Navigate to https://localhost:8080
2. Click "New App"
3. Fill in details:
   - **Application Name:** sample-app
   - **Project:** default
   - **Sync Policy:** Automatic
   - **Repository URL:** Your Git repo
   - **Path:** kubernetes/overlays/dev
   - **Cluster:** https://kubernetes.default.svc
   - **Namespace:** dev
4. Click "Create"

### Step 5: Monitor Deployment

```bash
# Watch ArgoCD sync
argocd app get sample-app --watch

# Check pod status
kubectl get pods -n dev

# View deployment
kubectl get deployment -n dev

# Check service
kubectl get svc -n dev
```

## ✅ Verify Deployment

### Check Application Health

```bash
# Port-forward to the service
kubectl port-forward -n dev svc/sample-app 3000:80

# In another terminal, test endpoints:
curl http://localhost:3000/
curl http://localhost:3000/health
curl http://localhost:3000/version
```

Expected responses:
```json
// GET /
{"message": "Hello from AKS with ArgoCD!", "timestamp": "..."}

// GET /health
{"status": "healthy", "uptime": 123}

// GET /version
{"version": "v1.0.0", "environment": "dev"}
```

### Check ArgoCD Application Status

```bash
argocd app get sample-app
```

Look for:
- **Health Status:** Healthy
- **Sync Status:** Synced
- **Last Sync:** Recent timestamp

### View in ArgoCD UI

1. Open https://localhost:8080
2. Click on `sample-app`
3. View the application tree showing:
   - Namespace
   - Deployment
   - ReplicaSet
   - Pods
   - Service

## 🔄 GitOps Workflow Demonstration

### Update Application (New Version)

```bash
# Make a code change
cd app/src
# Edit server.js - change the message

# Build and push new version
cd ..
docker build -t $ACR_LOGIN_SERVER/sample-app:v1.1.0 .
docker push $ACR_LOGIN_SERVER/sample-app:v1.1.0

# Update Kubernetes manifest
cd ../kubernetes/overlays/dev
# Edit kustomization.yaml - change newTag to v1.1.0

# Commit and push
git add .
git commit -m "Update to v1.1.0"
git push origin main
```

**Result:** ArgoCD automatically detects the change and syncs within ~3 minutes (or instantly with webhooks).

### Rollback to Previous Version

```bash
# Via ArgoCD UI: Click "History & Rollback", select previous revision

# Via CLI:
argocd app rollback sample-app <revision-number>

# Via Git:
git revert HEAD
git push origin main
```

## 🌍 Multi-Environment Deployment

### Deploy to Production

```bash
# Create production overlay if not exists
cd kubernetes/overlays/prod

# Update kustomization.yaml with production settings
# (different replicas, resource limits, etc.)

# Create ArgoCD application for prod
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/poc-argocd-aks-scenario.git
    targetRevision: main
    path: kubernetes/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

### Environment Differences

| Setting | Dev | Prod |
|---------|-----|------|
| Replicas | 2 | 3 |
| CPU Request | 100m | 250m |
| Memory Request | 128Mi | 256Mi |
| Auto-scaling | No | Yes (2-10) |
| Ingress | Internal | External |

## 📊 Monitoring and Observability

### View Application Logs

```bash
# All pods
kubectl logs -n dev -l app=sample-app --tail=100 -f

# Specific pod
kubectl logs -n dev <pod-name> -f
```

### Check Resource Usage

```bash
kubectl top pods -n dev
kubectl top nodes
```

### View Events

```bash
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### ArgoCD Sync History

```bash
argocd app history sample-app
```

## 🎯 Deployment Strategies

### Rolling Update (Default)

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### Blue-Green Deployment

Use ArgoCD Rollouts plugin:
```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### Canary Deployment

Configure progressive delivery:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: sample-app
spec:
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 1h}
      - setWeight: 50
      - pause: {duration: 1h}
```

## 🔧 Troubleshooting

### Application Not Syncing

```bash
# Refresh application
argocd app get sample-app --refresh

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Manual sync
argocd app sync sample-app
```

### Pods CrashLooping

```bash
kubectl describe pod -n dev <pod-name>
kubectl logs -n dev <pod-name> --previous
```

### Image Pull Errors

```bash
# Verify ACR attachment
az aks show --resource-group rg-argocd-demo --name aks-argocd-demo \
  --query "addonProfiles.acrPull"

# Re-attach ACR
az aks update --resource-group rg-argocd-demo --name aks-argocd-demo \
  --attach-acr $ACR_NAME
```

### Service Not Accessible

```bash
# Check service
kubectl get svc -n dev sample-app

# Check endpoints
kubectl get endpoints -n dev sample-app

# Verify pod labels match service selector
kubectl get pods -n dev --show-labels
```

## 🎓 Best Practices

### 1. Version Tags

✅ **Do:** Use semantic versioning (v1.0.0, v1.1.0)  
❌ **Don't:** Use `latest` tag in production

### 2. Health Checks

Always define liveness and readiness probes:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30
readinessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 5
```

### 3. Resource Limits

Always set resource requests and limits:
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

### 4. Git Practices

- One application per directory
- Environment-specific overlays
- Meaningful commit messages
- Tag releases in Git

### 5. Security

- Don't commit secrets to Git
- Use Sealed Secrets or Azure Key Vault
- Scan images for vulnerabilities
- Use minimal base images

## 📈 Next Steps

- Set up CI/CD pipeline: See `.github/workflows/build-push.yaml`
- Configure monitoring with Prometheus/Grafana
- Implement automated testing
- Add ingress controller for external access
- Set up SSL/TLS certificates

## 🔗 Additional Resources

- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD Application CRD](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
