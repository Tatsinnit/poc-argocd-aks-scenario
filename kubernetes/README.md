# Kubernetes Manifests Structure

This directory contains Kubernetes manifests organized using Kustomize for multi-environment deployments.

## Directory Structure

```
kubernetes/
├── base/                           # Base configurations (shared)
│   ├── deployment.yaml            # Base Deployment spec
│   ├── service.yaml               # Base Service spec
│   ├── configmap.yaml             # Base ConfigMap
│   └── kustomization.yaml         # Base Kustomize config
│
└── overlays/                      # Environment-specific overlays
    ├── dev/                       # Development environment
    │   ├── kustomization.yaml     # Dev-specific config
    │   ├── namespace.yaml         # Dev namespace
    │   └── resource-limits.yaml   # Dev resource limits
    │
    └── prod/                      # Production environment
        ├── kustomization.yaml     # Prod-specific config
        ├── namespace.yaml         # Prod namespace
        ├── resource-limits.yaml   # Prod resource limits
        └── hpa.yaml               # Horizontal Pod Autoscaler
```

## Base Configuration

The `base/` directory contains common configurations shared across all environments:

- **Deployment:** Pod template, container specs, probes
- **Service:** ClusterIP service exposing the app
- **ConfigMap:** Application configuration

## Environment Overlays

Each overlay modifies the base configuration for specific environments:

### Development (`overlays/dev/`)

- **Namespace:** `dev`
- **Replicas:** 2
- **Resources:** Lower limits for cost savings
- **Log Level:** `debug`
- **Auto-sync:** Enabled

### Production (`overlays/prod/`)

- **Namespace:** `prod`
- **Replicas:** 3 (with HPA: 2-10)
- **Resources:** Higher limits for performance
- **Log Level:** `info`
- **Auto-sync:** Enabled with approval

## Usage

### Preview Generated Manifests

```bash
# Development
kubectl kustomize overlays/dev

# Production
kubectl kustomize overlays/prod
```

### Apply Directly (Not Recommended with ArgoCD)

```bash
# Development
kubectl apply -k overlays/dev

# Production
kubectl apply -k overlays/prod
```

### Use with ArgoCD (Recommended)

ArgoCD applications point to these overlays and automatically sync changes.

See `argocd/applications/` for application definitions.

## Customization

### Adding a New Environment

1. Create new overlay directory:
   ```bash
   mkdir -p overlays/staging
   ```

2. Create `kustomization.yaml`:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   
   namespace: staging
   
   resources:
     - ../../base
     - namespace.yaml
   
   images:
     - name: sample-app
       newName: <your-acr>.azurecr.io/sample-app
       newTag: v1.0.0
   ```

3. Create `namespace.yaml`:
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: staging
   ```

4. Create ArgoCD application pointing to this overlay

### Modifying Resources

Edit files in `base/` for changes across all environments.

Edit files in `overlays/<env>/` for environment-specific changes.

### Adding Patches

Create a patch file:

```yaml
# overlays/dev/custom-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  template:
    spec:
      containers:
      - name: sample-app
        env:
        - name: CUSTOM_VAR
          value: "custom-value"
```

Add to `kustomization.yaml`:

```yaml
patches:
  - path: custom-patch.yaml
```

## Best Practices

1. **Keep base minimal** - Only common configurations
2. **Use overlays for differences** - Environment-specific settings
3. **Don't duplicate** - Use Kustomize features (patches, generators)
4. **Version control everything** - Commit all changes
5. **Test manifests** - Preview before applying
6. **Use labels** - For better organization and filtering

## Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/)
- [ArgoCD Kustomize Support](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
