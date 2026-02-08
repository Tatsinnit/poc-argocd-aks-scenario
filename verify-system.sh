#!/bin/bash

################################################################################
# System Verification Script
# 
# Quickly verify all components are properly connected
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

echo "=========================================="
echo "  GitOps System Verification"
echo "=========================================="
echo ""

# 1. Check kubectl connection
info "Checking kubectl connection..."
if kubectl cluster-info &>/dev/null; then
    pass "kubectl connected to cluster"
    CONTEXT=$(kubectl config current-context)
    echo "   Context: $CONTEXT"
else
    fail "kubectl not connected to cluster"
    exit 1
fi
echo ""

# 2. Check AKS cluster
info "Checking AKS cluster..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NODE_COUNT" -ge 3 ]; then
    pass "AKS cluster has $NODE_COUNT nodes"
else
    fail "Expected 3+ nodes, found $NODE_COUNT"
fi

READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
if [ "$READY_NODES" -ge 3 ]; then
    pass "All nodes are Ready"
else
    warn "Only $READY_NODES nodes are Ready"
fi
echo ""

# 3. Check ArgoCD installation
info "Checking ArgoCD installation..."
if kubectl get namespace argocd &>/dev/null; then
    pass "ArgoCD namespace exists"
else
    fail "ArgoCD namespace not found"
    exit 1
fi

ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$ARGOCD_PODS" -ge 7 ]; then
    pass "ArgoCD pods are running ($ARGOCD_PODS pods)"
else
    warn "Expected 7+ ArgoCD pods, found $ARGOCD_PODS running"
fi
echo ""

# 4. Check ArgoCD applications
info "Checking ArgoCD applications..."
APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$APP_COUNT" -gt 0 ]; then
    pass "Found $APP_COUNT ArgoCD application(s)"
    
    # Check sync status
    while IFS= read -r line; do
        APP_NAME=$(echo "$line" | awk '{print $1}')
        SYNC_STATUS=$(kubectl get application "$APP_NAME" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
        HEALTH_STATUS=$(kubectl get application "$APP_NAME" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
        
        if [ "$SYNC_STATUS" = "Synced" ] && [ "$HEALTH_STATUS" = "Healthy" ]; then
            pass "  $APP_NAME: Synced & Healthy"
        else
            warn "  $APP_NAME: $SYNC_STATUS / $HEALTH_STATUS"
        fi
    done < <(kubectl get applications -n argocd --no-headers 2>/dev/null)
else
    warn "No ArgoCD applications found"
fi
echo ""

# 5. Check application namespaces
info "Checking application deployments..."

for NS in dev prod; do
    if kubectl get namespace "$NS" &>/dev/null; then
        PODS=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        DEPLOYMENTS=$(kubectl get deployments -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
        
        if [ "$PODS" -gt 0 ]; then
            pass "  $NS: $PODS pod(s) running, $DEPLOYMENTS deployment(s)"
        else
            warn "  $NS namespace exists but no pods running"
        fi
    else
        warn "  $NS namespace not found"
    fi
done
echo ""

# 6. Check ACR integration
info "Checking Azure Container Registry..."
if [ -f "infrastructure/scripts/.acr-name" ]; then
    ACR_NAME=$(cat infrastructure/scripts/.acr-name)
    pass "ACR name found: $ACR_NAME"
    
    # Check if az CLI is available
    if command -v az &>/dev/null; then
        if az acr show --name "$ACR_NAME" &>/dev/null; then
            pass "ACR is accessible"
            
            # Check if images exist
            REPO_COUNT=$(az acr repository list --name "$ACR_NAME" 2>/dev/null | grep -c "sample-app" || echo "0")
            if [ "$REPO_COUNT" -gt 0 ]; then
                pass "sample-app repository exists in ACR"
            else
                warn "sample-app repository not found in ACR"
            fi
        else
            warn "Cannot access ACR (check permissions)"
        fi
    else
        info "Azure CLI not installed, skipping ACR checks"
    fi
else
    warn "ACR name file not found (run setup-aks.sh)"
fi
echo ""

# 7. Check Git repository configuration
info "Checking Git repository configuration..."
for APP in sample-app-dev sample-app-prod; do
    if kubectl get application "$APP" -n argocd &>/dev/null; then
        REPO_URL=$(kubectl get application "$APP" -n argocd -o jsonpath='{.spec.source.repoURL}' 2>/dev/null)
        PATH=$(kubectl get application "$APP" -n argocd -o jsonpath='{.spec.source.path}' 2>/dev/null)
        
        if [[ "$REPO_URL" == *"github.com"* ]]; then
            pass "  $APP: Connected to Git"
            echo "     Repo: $REPO_URL"
            echo "     Path: $PATH"
        else
            warn "  $APP: Check repository URL"
        fi
    fi
done
echo ""

# 8. Test application endpoints
info "Testing application endpoints..."
if kubectl get svc sample-app -n dev &>/dev/null; then
    # Start port-forward in background
    kubectl port-forward svc/sample-app -n dev 3333:80 &>/dev/null &
    PF_PID=$!
    sleep 3
    
    # Test health endpoint
    if curl -s http://localhost:3333/health &>/dev/null; then
        pass "Dev application is responding"
    else
        warn "Dev application not responding"
    fi
    
    # Kill port-forward
    kill $PF_PID 2>/dev/null || true
else
    warn "Dev service not found"
fi
echo ""

# Summary
echo "=========================================="
echo "  Verification Summary"
echo "=========================================="
echo ""

TOTAL_CHECKS=8
PASSED_CHECKS=0

# Count passed checks (simplified)
if [ "$NODE_COUNT" -ge 3 ]; then ((PASSED_CHECKS++)); fi
if [ "$READY_NODES" -ge 3 ]; then ((PASSED_CHECKS++)); fi
if [ "$ARGOCD_PODS" -ge 7 ]; then ((PASSED_CHECKS++)); fi
if [ "$APP_COUNT" -gt 0 ]; then ((PASSED_CHECKS++)); fi

echo "Checks passed: $PASSED_CHECKS/$TOTAL_CHECKS"
echo ""

if [ "$PASSED_CHECKS" -ge 6 ]; then
    pass "System verification PASSED"
    echo ""
    echo "Next steps:"
    echo "  - Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  - View applications: kubectl get applications -n argocd"
    echo "  - Check logs: kubectl logs -n dev -l app=sample-app"
else
    warn "System verification INCOMPLETE"
    echo ""
    echo "Review failed checks above and refer to VERIFICATION.md for details"
fi

echo "=========================================="
