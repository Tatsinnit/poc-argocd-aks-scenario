# Prerequisites & Setup

Before starting with this ArgoCD + AKS deployment pipeline, ensure you have all necessary tools and permissions.

## 📋 Required Tools

### 1. Azure CLI

Install the latest version of Azure CLI:

**macOS:**
```bash
brew update && brew install azure-cli
```

**Windows:**
```powershell
winget install Microsoft.AzureCLI
```

**Linux:**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Verify installation:
```bash
az --version
az login
```

### 2. kubectl

Install Kubernetes command-line tool:

**macOS:**
```bash
brew install kubectl
```

**Windows:**
```powershell
winget install Kubernetes.kubectl
```

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Verify:
```bash
kubectl version --client
```

### 3. Docker

Install Docker Desktop:

- **macOS/Windows:** Download from [docker.com](https://www.docker.com/products/docker-desktop)
- **Linux:** Follow [official guide](https://docs.docker.com/engine/install/)

Verify:
```bash
docker --version
docker run hello-world
```

### 4. Git

Most systems have Git pre-installed. If not:

```bash
# macOS
brew install git

# Windows
winget install Git.Git

# Linux
sudo apt-get install git
```

Verify:
```bash
git --version
```

## 🔑 Azure Requirements

### Azure Subscription

You need an active Azure subscription with:

- **Contributor** or **Owner** role
- Ability to create resource groups
- Ability to create AKS clusters
- Ability to create container registries

Check your subscriptions:
```bash
az account list --output table
az account set --subscription <subscription-id>
```

### Resource Quotas

Ensure your subscription has sufficient quotas:

- **Virtual Machines:** At least 3 Standard_DS2_v2 VMs
- **Public IP Addresses:** At least 1
- **Load Balancers:** At least 1

Check quotas:
```bash
az vm list-usage --location eastus --output table
```

## 🌐 Network Requirements

If you're behind a corporate firewall, ensure access to:

- `*.azure.com`
- `*.azurecr.io`
- `*.githubusercontent.com`
- `*.docker.io`
- `quay.io` (for ArgoCD images)

## 🔧 Optional Tools

### Helm (for ArgoCD installation)

```bash
# macOS
brew install helm

# Windows
winget install Helm.Helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### VS Code Extensions

Recommended extensions:
- Kubernetes
- YAML
- Docker
- Azure Account
- Bicep

## ✅ Verification Checklist

Before proceeding, verify:

- [ ] Azure CLI installed and logged in
- [ ] kubectl installed
- [ ] Docker installed and running
- [ ] Git configured
- [ ] Azure subscription selected
- [ ] Sufficient Azure quotas
- [ ] Network access to required endpoints

## 🎓 Knowledge Prerequisites

Basic understanding of:

- **Kubernetes concepts:** Pods, Services, Deployments
- **Docker:** Building images, running containers
- **Git:** Commits, push/pull, branches
- **YAML:** Configuration file format
- **Command-line:** Terminal/PowerShell usage

Don't worry if you're not an expert! This guide is designed to be beginner-friendly.

## 💰 Cost Considerations

Running this demo will incur Azure costs:

- **AKS Cluster:** ~$0.10/hour for cluster management + VM costs
- **VMs (3x Standard_DS2_v2):** ~$0.40/hour total
- **Container Registry (Basic):** ~$5/month
- **Load Balancer:** ~$0.025/hour

**Estimated total:** ~$0.50/hour or ~$12/day

💡 **Tip:** Delete resources when not in use to minimize costs!

```bash
az group delete --name rg-argocd-demo --yes
```

## 🆘 Troubleshooting

### "az: command not found"

Restart your terminal after installing Azure CLI or add it to PATH.

### Docker daemon not running

Start Docker Desktop application.

### kubectl not connected

After creating AKS cluster, get credentials:
```bash
az aks get-credentials --resource-group rg-argocd-demo --name aks-argocd-demo
```

### Azure login issues

Clear cached credentials:
```bash
az logout
az login --use-device-code
```

## 📚 Next Steps

Once all prerequisites are met, proceed to:
➡️ [AKS Cluster Deployment](02-aks-setup.md)
