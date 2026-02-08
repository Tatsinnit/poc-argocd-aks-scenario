# ArgoCD Configuration Files

This directory contains ArgoCD application definitions, projects, and installation configurations.

## Directory Structure

```
argocd/
├── applications/          # Application definitions
│   ├── sample-app-dev.yaml   # Development environment
│   └── sample-app-prod.yaml  # Production environment
│
├── projects/              # ArgoCD projects
│   └── demo-project.yaml # Demo project with RBAC
│
└── install/               # Installation configurations
    ├── values.yaml       # Helm values (optional)
    └── ingress.yaml      # Ingress config (optional)
```

## Quick Start

### Deploy an Application

```bash
# Deploy to development
kubectl apply -f applications/sample-app-dev.yaml

# Deploy to production
kubectl apply -f applications/sample-app-prod.yaml
```

### Create a Project

```bash
kubectl apply -f projects/demo-project.yaml
```

## Application Structure

Each ArgoCD Application defines:
- **Source:** Git repository and path
- **Destination:** Target cluster and namespace
- **Sync Policy:** Automated or manual sync
- **Health Checks:** Application health monitoring

## Common Issues & Solutions

### ⚠️ CRD Annotation Size Error

If you see this error during ArgoCD installation:
```
The CustomResourceDefinition "applicationsets.argoproj.io" is invalid: 
metadata.annotations: Too long: may not be more than 262144 bytes
```

**Quick Fix:**
```bash
# Use server-side apply (recommended)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --server-side --force-conflicts
```

**Why this happens:**
- ArgoCD CRDs have large annotations
- Client-side `kubectl apply` stores full config in annotations
- Exceeds Kubernetes' 256KB annotation limit

**Prevention:**
- Always use `--server-side` flag with ArgoCD
- Or use Helm installation method
- Our installation script handles this automatically

See [docs/03-argocd-installation.md](../docs/03-argocd-installation.md) for details.

## Customization

### Update Git Repository

Before deploying, update the `repoURL` in application files:

```yaml
# applications/sample-app-dev.yaml
spec:
  source:
    repoURL: https://github.com/Tatsinnit/poc-argocd-aks-scenario.git  # Update this
```

### Add New Environment

1. Create overlay in `kubernetes/overlays/<env-name>/`
2. Create new application YAML:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Tatsinnit/poc-argocd-aks-scenario.git
    targetRevision: main
    path: kubernetes/overlays/staging
  destination:
    server: https://kubernetes.default.svc
    namespace: staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

3. Apply the application:
```bash
kubectl apply -f applications/sample-app-staging.yaml
```

## Sync Policies

### Automated Sync (Recommended for Dev)

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources removed from Git
    selfHeal: true   # Revert manual changes
```

### Manual Sync (Recommended for Prod)

```yaml
syncPolicy: {}  # No automated sync
```

Trigger manually:
```bash
argocd app sync sample-app-prod
```

## Best Practices

1. **Use GitOps** - All config in Git, never `kubectl apply` directly
2. **Separate environments** - Different applications per environment
3. **Use projects** - Organize apps and apply RBAC
4. **Enable notifications** - Get alerts on sync failures
5. **Monitor health** - Check app status regularly
6. **Version manifests** - Use Git tags for releases

## Troubleshooting

### Application Won't Sync

```bash
# Force refresh
argocd app get sample-app-dev --refresh

# Check application status
kubectl describe application -n argocd sample-app-dev

# View sync logs
argocd app logs sample-app-dev
```

### Application Stuck in Progressing

```bash
# Check pod status
kubectl get pods -n dev

# Check events
kubectl get events -n dev --sort-by='.lastTimestamp'
```

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Application Deployment Guide](../docs/04-app-deployment.md)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
