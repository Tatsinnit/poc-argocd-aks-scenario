# GitOps-Driven AKS Deployment with ArgoCD

A comprehensive, beginner-friendly guide to deploying applications on Azure Kubernetes Service (AKS) using ArgoCD for GitOps-based continuous deployment.

## 🎯 What You'll Build

- **AKS Cluster** with Azure Container Registry (ACR)
- **Sample Node.js Application** containerized and deployed
- **ArgoCD** for automated GitOps deployments
- **CI/CD Pipeline** using GitHub Actions
- **Multi-environment setup** (dev/prod) with Kustomize

## 📋 Prerequisites

- Azure subscription with contributor access
- Azure CLI installed (`az --version`)
- kubectl installed (`kubectl version --client`)
- Docker installed (for local testing)
- Git and GitHub account
- Basic knowledge of Kubernetes concepts

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd poc-argocd-aks-scenario
```

### 2. Deploy AKS Infrastructure

```bash
cd infrastructure/scripts
chmod +x setup-aks.sh
./setup-aks.sh
```

This creates:
- Resource Group: `rg-argocd-demo`
- AKS Cluster: `aks-argocd-demo`
- Azure Container Registry: `acrargocdemo<random>`

### 3. Install ArgoCD

```bash
chmod +x install-argocd.sh
./install-argocd.sh
```

### 4. Deploy Sample Application

```bash
# Build and push Docker image
cd ../../app
docker build -t <your-acr>.azurecr.io/sample-app:v1.0.0 .
docker push <your-acr>.azurecr.io/sample-app:v1.0.0

# Apply ArgoCD application
kubectl apply -f ../argocd/applications/sample-app.yaml
```

### 5. Access Your Application

```bash
# Get ArgoCD UI password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access: https://localhost:8080
# Username: admin
# Password: <from above command>
```

## 📚 Detailed Documentation

- [Prerequisites & Setup](docs/01-prerequisites.md)
- [AKS Cluster Deployment](docs/02-aks-setup.md)
- [ArgoCD Installation](docs/03-argocd-installation.md)
- [Application Deployment](docs/04-app-deployment.md)
- [Architecture Overview](docs/architecture-diagram.md)

## 🏗️ Project Structure

```
.
├── app/                    # Sample Node.js application
├── kubernetes/             # K8s manifests with Kustomize
├── argocd/                 # ArgoCD application definitions
├── infrastructure/         # Azure Bicep templates
├── .github/workflows/      # CI/CD pipelines
└── docs/                   # Detailed documentation
```

## 🔄 GitOps Workflow

1. **Developer commits** code changes to Git
2. **GitHub Actions** builds Docker image and pushes to ACR
3. **Developer updates** Kubernetes manifests (image tag)
4. **ArgoCD detects** changes in Git repository
5. **ArgoCD syncs** automatically to deploy new version

## 🛠️ Key Technologies

- **Azure Kubernetes Service (AKS)** - Managed Kubernetes
- **ArgoCD** - GitOps continuous delivery
- **Kustomize** - Kubernetes native configuration management
- **Azure Container Registry** - Private container registry
- **GitHub Actions** - CI/CD automation

## 🎓 Learning Objectives

After completing this project, you'll understand:

- How to provision AKS clusters using Bicep/Azure CLI
- ArgoCD installation and configuration
- GitOps principles and practices
- Kubernetes manifest management with Kustomize
- Building CI/CD pipelines for containers
- Multi-environment deployments

## 🔧 Customization

### Change Application

Replace the Node.js app in `app/src` with your own application.

### Add Environments

Create new overlays in `kubernetes/overlays/<env-name>`.

### Modify Infrastructure

Edit Bicep templates in `infrastructure/bicep/`.

## 🔧 Troubleshooting

### Common Issues

**ArgoCD CRD Installation Error**

If you see: `metadata.annotations: Too long: may not be more than 262144 bytes`

**Solution:** The installation script automatically handles this with `--server-side` flag. If installing manually:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --server-side --force-conflicts
```

See [docs/03-argocd-installation.md](docs/03-argocd-installation.md#crd-annotation-size-error) for details.

**Pods Not Starting**

```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**ArgoCD Not Syncing**

```bash
# Check application status
kubectl get application -n argocd

# Force refresh
argocd app get <app-name> --refresh
```

**Cannot Access Services**

```bash
# Verify services are running
kubectl get svc -n <namespace>

# Check port-forwarding
kubectl port-forward svc/<service-name> -n <namespace> <local-port>:<service-port>
```

For detailed troubleshooting, see individual documentation pages.

## 🧹 Cleanup

```bash
# Delete AKS cluster and all resources
az group delete --name rg-argocd-demo --yes --no-wait
```

## 📖 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Principles](https://www.gitops.tech/)

## 🤝 Contributing

Feel free to open issues or submit pull requests for improvements!

## 📝 License

MIT License - feel free to use this project for learning and development.

---

**Happy GitOps-ing! 🚀**
