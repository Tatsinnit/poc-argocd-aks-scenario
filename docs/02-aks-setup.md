# AKS Cluster Deployment

This guide walks you through creating an Azure Kubernetes Service (AKS) cluster with Azure Container Registry (ACR).

## 🎯 What We'll Create

- **Resource Group:** `rg-argocd-demo`
- **AKS Cluster:** `aks-argocd-demo` (3 nodes, Standard_DS2_v2)
- **Azure Container Registry:** `acrargocdemo<random>`
- **System-assigned managed identity** for AKS
- **AcrPull role assignment** for accessing ACR

## 🚀 Deployment Options

Choose one of the following methods:

### Option 1: Automated Script (Recommended)

```bash
cd infrastructure/scripts
chmod +x setup-aks.sh
./setup-aks.sh
```

The script will:
1. Create resource group
2. Create ACR
3. Create AKS cluster with managed identity
4. Attach ACR to AKS
5. Get cluster credentials

**Execution time:** ~5-10 minutes

### Option 2: Azure Bicep (Infrastructure as Code)

```bash
cd infrastructure/bicep

# Create resource group
az group create --name rg-argocd-demo --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group rg-argocd-demo \
  --template-file main.bicep \
  --parameters parameters.json
```

### Option 3: Manual Azure CLI Commands

```bash

# Set variables
RG_NAME="rg-argocd-demo"
LOCATION="eastus"
AKS_NAME="aks-argocd-demo"
ACR_NAME="acrargocdemo$RANDOM"

# Create resource group
az group create --name $RG_NAME --location $LOCATION

# Create ACR
az acr create \
  --resource-group $RG_NAME \
  --name $ACR_NAME \
  --sku Basic \
  --location $LOCATION

# Create AKS cluster
az aks create \
  --resource-group $RG_NAME \
  --name $AKS_NAME \
  --node-count 3 \
  --node-vm-size Standard_DS2_v2 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --location $LOCATION \
  --attach-acr $ACR_NAME

# Get credentials
az aks get-credentials \
  --resource-group $RG_NAME \
  --name $AKS_NAME \
  --overwrite-existing
```

## ✅ Verify Deployment

### 1. Check Cluster Status

```bash
az aks show \
  --resource-group rg-argocd-demo \
  --name aks-argocd-demo \
  --query '{Name:name, Status:provisioningState, K8sVersion:kubernetesVersion}' \
  --output table
```

Expected output:
```
Name              Status     K8sVersion
----------------  ---------  ------------
aks-argocd-demo   Succeeded  1.28.x
```

### 2. Verify kubectl Connection

```bash
kubectl get nodes
```

Expected output:
```
NAME                                STATUS   ROLES   AGE   VERSION
aks-nodepool1-12345678-vmss000000   Ready    agent   5m    v1.28.x
aks-nodepool1-12345678-vmss000001   Ready    agent   5m    v1.28.x
aks-nodepool1-12345678-vmss000002   Ready    agent   5m    v1.28.x
```

### 3. Check Namespaces

```bash
kubectl get namespaces
```

### 4. Verify ACR Access

```bash
ACR_NAME=$(az acr list --resource-group rg-argocd-demo --query '[0].name' -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)

echo "ACR Login Server: $ACR_LOGIN_SERVER"

# Test ACR login
az acr login --name $ACR_NAME
```

## 🔍 Understanding the Architecture

### AKS Cluster Components

```
┌─────────────────────────────────────────┐
│         Azure Resource Group            │
│  ┌───────────────────────────────────┐  │
│  │     AKS Cluster                   │  │
│  │  ┌─────────────┐ ┌─────────────┐ │  │
│  │  │  Node Pool  │ │   Control   │ │  │
│  │  │  (3 VMs)    │ │   Plane     │ │  │
│  │  └─────────────┘ └─────────────┘ │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  Azure Container Registry (ACR)  │  │
│  │  - Private image storage          │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Node Pool Configuration

- **VM Size:** Standard_DS2_v2 (2 vCPUs, 7 GB RAM)
- **Node Count:** 3 (for high availability)
- **OS Disk Size:** 128 GB
- **Network Plugin:** kubenet (default)

### Managed Identity

The cluster uses **system-assigned managed identity** for:
- Accessing ACR (AcrPull role)
- Managing Azure resources
- No manual credential management needed

## 🎛️ Configuration Parameters

Edit `infrastructure/bicep/parameters.json` to customize:

```json
{
  "clusterName": "aks-argocd-demo",
  "nodeCount": 3,
  "vmSize": "Standard_DS2_v2",
  "kubernetesVersion": "1.28",
  "location": "eastus"
}
```

### Recommended VM Sizes

| Size | vCPUs | RAM | Use Case | Cost/month* |
|------|-------|-----|----------|-------------|
| Standard_B2s | 2 | 4 GB | Dev/Test | ~$30 |
| Standard_DS2_v2 | 2 | 7 GB | **Demo** | ~$70 |
| Standard_D4s_v3 | 4 | 16 GB | Production | ~$140 |

*Approximate costs per node

## 🔧 Advanced Configuration

### Enable Azure Monitor

```bash
az aks enable-addons \
  --resource-group rg-argocd-demo \
  --name aks-argocd-demo \
  --addons monitoring
```

### Scale Node Pool

```bash
az aks scale \
  --resource-group rg-argocd-demo \
  --name aks-argocd-demo \
  --node-count 5
```

### Upgrade Kubernetes Version

```bash
# Check available versions
az aks get-upgrades \
  --resource-group rg-argocd-demo \
  --name aks-argocd-demo \
  --output table

# Upgrade
az aks upgrade \
  --resource-group rg-argocd-demo \
  --name aks-argocd-demo \
  --kubernetes-version 1.29.0
```

## 🐛 Troubleshooting

### Cluster Creation Failed

Check activity log:
```bash
az monitor activity-log list \
  --resource-group rg-argocd-demo \
  --max-events 50
```

### Nodes Not Ready

```bash
kubectl describe nodes
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Cannot Access ACR

Verify role assignment:
```bash
az role assignment list \
  --scope /subscriptions/<sub-id>/resourceGroups/rg-argocd-demo
```

Re-attach ACR:
```bash
az aks update \
  --resource-group rg-argocd-demo \
  --name aks-argocd-demo \
  --attach-acr $ACR_NAME
```

### kubectl Connection Issues

Reset credentials:
```bash
az aks get-credentials \
  --resource-group rg-argocd-demo \
  --name aks-argocd-demo \
  --overwrite-existing

kubectl cluster-info
```

## 💰 Cost Optimization Tips

1. **Use spot VMs** for non-production (up to 90% discount)
2. **Scale down** when not in use
3. **Delete resources** after testing
4. **Choose appropriate VM sizes** for your workload
5. **Use Basic SKU** for ACR in dev/test

## 🧹 Cleanup

To delete everything:

```bash
az group delete --name rg-argocd-demo --yes --no-wait
```

This removes:
- AKS cluster
- All VMs
- ACR
- Network resources
- All associated costs

## 📚 Next Steps

Cluster is ready! Now let's install ArgoCD:
➡️ [ArgoCD Installation](03-argocd-installation.md)
