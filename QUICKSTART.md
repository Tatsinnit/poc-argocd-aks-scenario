# 🚀 Quick Start Guide

Get your ArgoCD + AKS GitOps pipeline running in 15 minutes!

## Prerequisites Checklist

- [ ] Azure subscription with contributor access
- [ ] Azure CLI installed (`az --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Docker installed (for local testing)
- [ ] Git configured

## Step 1: Clone & Setup (1 min)

```bash
git clone <your-fork-url>
cd poc-argocd-aks-scenario
```

## Step 2: Deploy AKS Infrastructure (7 min)

```bash
cd infrastructure/scripts
chmod +x setup-aks.sh
./setup-aks.sh
```

**What this does:**
- Creates resource group `rg-argocd-demo`
- Creates AKS cluster with 3 nodes
- Creates Azure Container Registry
- Configures kubectl access

**Wait for:** "AKS Cluster Setup Complete!"

## Step 3: Install ArgoCD (3 min)

```bash
chmod +x install-argocd.sh
./install-argocd.sh
```

**What this does:**
- Installs ArgoCD in the cluster
- Retrieves admin password
- Displays access instructions

**Save the admin password!**

## Step 4: Access ArgoCD UI (1 min)

```bash
# Terminal 1: Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Terminal 2: Get password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Open: https://localhost:8080
- Username: `admin`
- Password: `<from above command>`

## Step 5: Build & Push App (2 min)

```bash
cd ../../app

# Get ACR details
ACR_NAME=$(cat ../infrastructure/scripts/.acr-name)
az acr login --name $ACR_NAME

# Build and push
docker build -t $ACR_NAME.azurecr.io/sample-app:v1.0.0 .
docker push $ACR_NAME.azurecr.io/sample-app:v1.0.0
```

## Step 6: Update Manifests (1 min)

```bash
cd ../kubernetes/overlays/dev

# Update with your ACR name
ACR_LOGIN_SERVER="$ACR_NAME.azurecr.io"
sed -i.bak "s|<your-acr>|$ACR_LOGIN_SERVER|g" kustomization.yaml

# Commit changes
git add kustomization.yaml
git commit -m "Update ACR name"
git push
```

## Step 7: Deploy with ArgoCD (1 min)

```bash
# Update ArgoCD app with your Git repo
cd ../../../argocd/applications

# Edit sample-app-dev.yaml - replace <your-username>/<your-repo>
# Then apply:
kubectl apply -f sample-app-dev.yaml
```

## Step 8: Verify Deployment (1 min)

**In ArgoCD UI:**
1. Click on `sample-app-dev`
2. Check status: Should show "Synced" + "Healthy"

**In Terminal:**
```bash
# Check pods
kubectl get pods -n dev

# Port forward to app
kubectl port-forward -n dev svc/sample-app 3000:80

# Test (in another terminal)
curl http://localhost:3000/health
```

## 🎉 Success!

You now have:
✅ AKS cluster running  
✅ ArgoCD installed and configured  
✅ Sample app deployed via GitOps  
✅ Automated sync enabled  

## Next Steps

### Test GitOps Workflow

```bash
# 1. Make a code change
cd app/src
# Edit server.js - change the welcome message

# 2. Build new version
cd ..
docker build -t $ACR_LOGIN_SERVER/sample-app:v1.0.1 .
docker push $ACR_LOGIN_SERVER/sample-app:v1.0.1

# 3. Update manifest
cd ../kubernetes/overlays/dev
sed -i 's/v1.0.0/v1.0.1/g' kustomization.yaml

# 4. Commit and watch ArgoCD sync!
git add kustomization.yaml
git commit -m "Update to v1.0.1"
git push
```

Watch in ArgoCD UI as it automatically detects and deploys the change!

### Setup CI/CD

See [.github/SETUP.md](.github/SETUP.md) for GitHub Actions configuration.

### Deploy to Production

```bash
# Update prod overlay
cd kubernetes/overlays/prod
sed -i.bak "s|<your-acr>|$ACR_LOGIN_SERVER|g" kustomization.yaml

# Apply prod application
kubectl apply -f ../../argocd/applications/sample-app-prod.yaml
```

## Troubleshooting

### Pods not starting?

```bash
kubectl describe pod -n dev <pod-name>
kubectl logs -n dev <pod-name>
```

### ArgoCD not syncing?

```bash
# Refresh the app
kubectl get application -n argocd sample-app-dev -o yaml

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Cannot access ArgoCD UI?

```bash
# Check service
kubectl get svc -n argocd argocd-server

# Restart port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Cleanup

When done testing:

```bash
# Delete everything
az group delete --name rg-argocd-demo --yes --no-wait
```

## Need Help?

- 📚 [Full Documentation](docs/)
- 🐛 [Report Issues](https://github.com/yourusername/poc-argocd-aks-scenario/issues)
- 💬 [Discussions](https://github.com/yourusername/poc-argocd-aks-scenario/discussions)

---

**Estimated total time:** 15-20 minutes  
**Estimated cost:** ~$0.50/hour (remember to delete resources!)
