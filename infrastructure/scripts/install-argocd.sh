#!/bin/bash

################################################################################
# ArgoCD Installation Script
# 
# This script installs ArgoCD on an existing AKS cluster
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"

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

info() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed. Please install it first."
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster. Please run setup-aks.sh first."
    fi
    
    log "Prerequisites check passed ✓"
}

# Create ArgoCD namespace
create_namespace() {
    info "Creating namespace: $ARGOCD_NAMESPACE..."
    
    if kubectl get namespace "$ARGOCD_NAMESPACE" &> /dev/null; then
        warn "Namespace $ARGOCD_NAMESPACE already exists. Skipping creation."
    else
        kubectl create namespace "$ARGOCD_NAMESPACE"
        log "Namespace created ✓"
    fi
}

# Install ArgoCD
install_argocd() {
    info "Installing ArgoCD..."
    
    local MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
    
    log "Downloading and applying ArgoCD manifest from $MANIFEST_URL"
    kubectl apply -n "$ARGOCD_NAMESPACE" -f "$MANIFEST_URL"
    
    log "ArgoCD components installed ✓"
}

# Wait for ArgoCD pods to be ready
wait_for_pods() {
    info "Waiting for ArgoCD pods to be ready..."
    log "This may take 2-3 minutes. Please wait..."
    
    kubectl wait --for=condition=ready pod \
        --all \
        -n "$ARGOCD_NAMESPACE" \
        --timeout=300s || {
        warn "Some pods may still be starting. Checking status..."
        kubectl get pods -n "$ARGOCD_NAMESPACE"
    }
    
    log "Pods are ready ✓"
}

# Get ArgoCD admin password
get_admin_password() {
    info "Retrieving ArgoCD admin password..."
    
    local PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    
    if [ -z "$PASSWORD" ]; then
        warn "Could not retrieve admin password. The secret may not exist yet."
        return 1
    fi
    
    echo "$PASSWORD" > .argocd-admin-password
    log "Admin password saved to .argocd-admin-password ✓"
    
    return 0
}

# Display access information
display_access_info() {
    log "Checking ArgoCD service..."
    kubectl get svc -n "$ARGOCD_NAMESPACE" argocd-server
}

# Print summary
print_summary() {
    local PASSWORD=""
    if [ -f .argocd-admin-password ]; then
        PASSWORD=$(cat .argocd-admin-password)
    else
        PASSWORD="<retrieving password failed - see instructions below>"
    fi
    
    echo ""
    echo "=========================================="
    echo "  ArgoCD Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Namespace:  $ARGOCD_NAMESPACE"
    echo "Username:   admin"
    echo "Password:   $PASSWORD"
    echo ""
    echo "To retrieve the password manually:"
    echo "  kubectl -n argocd get secret argocd-initial-admin-secret \\"
    echo "    -o jsonpath=\"{.data.password}\" | base64 -d && echo"
    echo ""
    echo "Access ArgoCD UI:"
    echo ""
    echo "  Option 1: Port Forward (Development)"
    echo "  --------------------------------"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  Then navigate to: https://localhost:8080"
    echo "  (Accept the self-signed certificate warning)"
    echo ""
    echo "  Option 2: LoadBalancer (Production)"
    echo "  --------------------------------"
    echo "  kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'"
    echo "  kubectl get svc argocd-server -n argocd"
    echo "  (Wait for EXTERNAL-IP, then access via that IP)"
    echo ""
    echo "Install ArgoCD CLI (Optional):"
    echo "  macOS:   brew install argocd"
    echo "  Linux:   curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    echo "           chmod +x argocd && sudo mv argocd /usr/local/bin/"
    echo ""
    echo "Next steps:"
    echo "  1. Access the ArgoCD UI using one of the methods above"
    echo "  2. Login with username 'admin' and the password above"
    echo "  3. Deploy your application:"
    echo "     kubectl apply -f ../argocd/applications/sample-app.yaml"
    echo ""
    echo "ArgoCD Resources:"
    echo "  kubectl get all -n argocd"
    echo "=========================================="
}

# Verify installation
verify_installation() {
    info "Verifying ArgoCD installation..."
    
    log "ArgoCD pods:"
    kubectl get pods -n "$ARGOCD_NAMESPACE"
    
    log "ArgoCD services:"
    kubectl get svc -n "$ARGOCD_NAMESPACE"
    
    log "Verification complete ✓"
}

# Main execution
main() {
    log "Starting ArgoCD installation..."
    echo ""
    
    check_prerequisites
    create_namespace
    install_argocd
    wait_for_pods
    verify_installation
    get_admin_password || true
    display_access_info
    print_summary
}

# Run main function
main
