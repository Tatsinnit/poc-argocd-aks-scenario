#!/bin/bash

################################################################################
# AKS Cluster Setup Script
# 
# This script automates the creation of an AKS cluster with ACR for ArgoCD demo
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
RG_NAME="${RG_NAME:-rg-argocd-demo}"
LOCATION="${LOCATION:-eastus}"
AKS_NAME="${AKS_NAME:-aks-argocd-demo}"
ACR_NAME="${ACR_NAME:-acrargocdemo$RANDOM}"
NODE_COUNT="${NODE_COUNT:-3}"
NODE_VM_SIZE="${NODE_VM_SIZE:-Standard_DS2_v2}"
K8S_VERSION="${K8S_VERSION:-1.28}"

# Helper functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        error "Azure CLI is not installed. Please install it first."
    fi
    
    if ! command -v kubectl &> /dev/null; then
        warn "kubectl is not installed. You'll need it to interact with the cluster."
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        error "Not logged in to Azure. Please run 'az login' first."
    fi
    
    log "Prerequisites check passed ✓"
}

# Create resource group
create_resource_group() {
    log "Creating resource group: $RG_NAME in $LOCATION..."
    
    if az group show --name "$RG_NAME" &> /dev/null; then
        warn "Resource group $RG_NAME already exists. Skipping creation."
    else
        az group create \
            --name "$RG_NAME" \
            --location "$LOCATION" \
            --output table
        log "Resource group created ✓"
    fi
}

# Create Azure Container Registry
create_acr() {
    log "Creating Azure Container Registry: $ACR_NAME..."
    
    if az acr show --name "$ACR_NAME" --resource-group "$RG_NAME" &> /dev/null; then
        warn "ACR $ACR_NAME already exists. Skipping creation."
    else
        az acr create \
            --resource-group "$RG_NAME" \
            --name "$ACR_NAME" \
            --sku Basic \
            --location "$LOCATION" \
            --output table
        log "ACR created ✓"
    fi
    
    # Save ACR name for later use
    echo "$ACR_NAME" > .acr-name
}

# Create AKS cluster
create_aks() {
    log "Creating AKS cluster: $AKS_NAME..."
    log "This may take 5-10 minutes. Please wait..."
    
    if az aks show --name "$AKS_NAME" --resource-group "$RG_NAME" &> /dev/null; then
        warn "AKS cluster $AKS_NAME already exists. Skipping creation."
    else
        az aks create \
            --resource-group "$RG_NAME" \
            --name "$AKS_NAME" \
            --node-count "$NODE_COUNT" \
            --node-vm-size "$NODE_VM_SIZE" \
            --kubernetes-version "$K8S_VERSION" \
            --enable-managed-identity \
            --generate-ssh-keys \
            --attach-acr "$ACR_NAME" \
            --location "$LOCATION" \
            --output table
        
        log "AKS cluster created ✓"
    fi
}

# Get AKS credentials
get_credentials() {
    log "Getting AKS credentials..."
    
    az aks get-credentials \
        --resource-group "$RG_NAME" \
        --name "$AKS_NAME" \
        --overwrite-existing
    
    log "Credentials configured ✓"
}

# Verify cluster
verify_cluster() {
    log "Verifying cluster..."
    
    log "Cluster info:"
    kubectl cluster-info
    
    log "Nodes:"
    kubectl get nodes
    
    log "Cluster verification complete ✓"
}

# Print summary
print_summary() {
    local ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RG_NAME" --query loginServer -o tsv)
    
    echo ""
    echo "=========================================="
    echo "  AKS Cluster Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Resource Group:    $RG_NAME"
    echo "Location:          $LOCATION"
    echo "AKS Cluster:       $AKS_NAME"
    echo "ACR Name:          $ACR_NAME"
    echo "ACR Login Server:  $ACR_LOGIN_SERVER"
    echo "Node Count:        $NODE_COUNT"
    echo "Node VM Size:      $NODE_VM_SIZE"
    echo "K8s Version:       $K8S_VERSION"
    echo ""
    echo "Next steps:"
    echo "  1. Run './install-argocd.sh' to install ArgoCD"
    echo "  2. Build and push your container image:"
    echo "     az acr login --name $ACR_NAME"
    echo "     docker build -t $ACR_LOGIN_SERVER/sample-app:v1.0.0 ."
    echo "     docker push $ACR_LOGIN_SERVER/sample-app:v1.0.0"
    echo ""
    echo "To delete all resources:"
    echo "  az group delete --name $RG_NAME --yes --no-wait"
    echo "=========================================="
}

# Main execution
main() {
    log "Starting AKS cluster setup..."
    log "Configuration:"
    log "  Resource Group: $RG_NAME"
    log "  Location: $LOCATION"
    log "  AKS Name: $AKS_NAME"
    log "  ACR Name: $ACR_NAME"
    log "  Node Count: $NODE_COUNT"
    log "  Node VM Size: $NODE_VM_SIZE"
    echo ""
    
    check_prerequisites
    create_resource_group
    create_acr
    create_aks
    get_credentials
    verify_cluster
    print_summary
}

# Run main function
main
