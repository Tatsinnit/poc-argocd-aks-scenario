# ArgoCD Installation & Configuration

This guide covers installing and configuring ArgoCD on your AKS cluster for GitOps-based continuous deployment.

## 🎯 What is ArgoCD?

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It:

- 🔄 Automatically syncs applications from Git to Kubernetes
- 👁️ Provides visibility into application state
- 🔐 Offers role-based access control (RBAC)
- 📊 Shows deployment history and rollback capabilities
- 🎯 Enables multi-cluster and multi-environment deployments

## 🚀 Installation Methods

### Option 1: Automated Script (Recommended)

```bash
cd infrastructure/scripts
chmod +x install-argocd.sh
./install-argocd.sh
```

This script:
1. Creates `argocd` namespace
2. Installs ArgoCD using official manifests
3. Waits for all pods to be ready
4. Retrieves admin password
5. Sets up port forwarding

**Execution time:** ~3-5 minutes

### Option 2: Manual kubectl Installation

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD using server-side apply (avoids CRD annotation size issues)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --server-side --force-conflicts

# Wait for pods to be ready
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s
```

> **💡 Note:** The `--server-side` flag prevents "metadata.annotations: Too long" errors with ArgoCD CRDs.

### Option 3: Helm Installation (Custom Values)

```bash
# Add ArgoCD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install with custom values
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values ../argocd/install/values.yaml
```

## ✅ Verify Installation

### 1. Check ArgoCD Pods

```bash
kubectl get pods -n argocd
```

Expected output (all Running):
```
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-application-controller-0       1/1     Running   0          2m
argocd-applicationset-controller-x    1/1     Running   0          2m
argocd-dex-server-x                   1/1     Running   0          2m
argocd-notifications-controller-x     1/1     Running   0          2m
argocd-redis-x                        1/1     Running   0          2m
argocd-repo-server-x                  1/1     Running   0          2m
argocd-server-x                       1/1     Running   0          2m
```

### 2. Check Services

```bash
kubectl get svc -n argocd
```

```
NAME                    TYPE        CLUSTER-IP     PORT(S)
argocd-server           ClusterIP   10.0.x.x       80/TCP,443/TCP
argocd-repo-server      ClusterIP   10.0.x.x       8081/TCP
argocd-redis            ClusterIP   10.0.x.x       6379/TCP
argocd-dex-server       ClusterIP   10.0.x.x       5556/TCP,5557/TCP
```

## 🔑 Access ArgoCD UI

### Get Initial Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Save this password! You'll use it to login.

### Access Methods

#### Method 1: Port Forwarding (Development)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access: https://localhost:8080
- Username: `admin`
- Password: `<from above command>`

⚠️ **Note:** You'll see a certificate warning - this is normal for self-signed certs.

#### Method 2: LoadBalancer Service (Production)

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get external IP (may take a few minutes)
kubectl get svc argocd-server -n argocd -w
```

Access via the EXTERNAL-IP address.

#### Method 3: Ingress with SSL (Recommended for Production)

See the ingress configuration in `argocd/install/ingress.yaml`.

## 🔧 Initial Configuration

### 1. Login via CLI

```bash
# Install ArgoCD CLI
brew install argocd  # macOS
# or
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login localhost:8080 --insecure --username admin --password <your-password>
```

### 2. Change Admin Password

```bash
argocd account update-password
```

### 3. Add Git Repository

```bash
# Public repository (no credentials needed)
argocd repo add https://github.com/yourusername/your-repo.git

# Private repository (with SSH)
argocd repo add git@github.com:yourusername/your-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Private repository (with HTTPS token)
argocd repo add https://github.com/yourusername/your-repo.git \
  --username your-username \
  --password your-token
```

### 4. Create ArgoCD Project (Optional)

```bash
kubectl apply -f ../argocd/projects/demo-project.yaml
```

This creates a project with:
- Allowed source repos
- Allowed destination clusters
- Resource whitelist/blacklist

## 🎯 Deploy Your First Application

### Create ArgoCD Application

```bash
kubectl apply -f ../argocd/applications/sample-app.yaml
```

This creates an ArgoCD Application that:
- Monitors your Git repository
- Syncs Kubernetes manifests to the cluster
- Auto-heals if manual changes are made
- Auto-syncs when Git changes are detected

### View in UI

1. Navigate to https://localhost:8080
2. Login with admin credentials
3. You'll see the `sample-app` application
4. Click on it to view the tree of deployed resources

### Check Application Status

```bash
# Via CLI
argocd app list
argocd app get sample-app

# Via kubectl
kubectl get applications -n argocd
```

## 📊 Understanding ArgoCD Architecture

```
┌──────────────────────────────────────────────────┐
│                  Git Repository                  │
│         (Source of Truth for Config)             │
└────────────────┬─────────────────────────────────┘
                 │
                 │ Polls for changes
                 ▼
┌──────────────────────────────────────────────────┐
│            ArgoCD (Running in AKS)               │
│  ┌──────────────────────────────────────────┐   │
│  │  Application Controller                  │   │
│  │  - Monitors Git repo                     │   │
│  │  - Compares desired vs actual state      │   │
│  │  - Syncs differences                     │   │
│  └──────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────┐   │
│  │  Repo Server                             │   │
│  │  - Clones Git repos                      │   │
│  │  - Generates manifests                   │   │
│  └──────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────┐   │
│  │  Server/UI                               │   │
│  │  - Web UI & API                          │   │
│  │  - CLI interface                         │   │
│  └──────────────────────────────────────────┘   │
└────────────────┬─────────────────────────────────┘
                 │
                 │ Applies manifests
                 ▼
┌──────────────────────────────────────────────────┐
│            Kubernetes Cluster (AKS)              │
│         (Actual Running Applications)            │
└──────────────────────────────────────────────────┘
```

## 🔄 Sync Strategies

### Auto-Sync

```yaml
spec:
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Revert manual changes
```

### Manual Sync

```bash
argocd app sync sample-app
```

### Selective Sync

Sync only specific resources:
```bash
argocd app sync sample-app --resource Deployment:sample-app
```

## 🎛️ ArgoCD Configuration Options

### Enable Metrics

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: argocd-metrics
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-metrics
spec:
  ports:
  - port: 8082
    protocol: TCP
    targetPort: 8082
  selector:
    app.kubernetes.io/name: argocd-application-controller
EOF
```

### Configure Webhooks

For instant sync instead of polling (3-minute default):

In GitHub repository settings:
1. Go to Settings → Webhooks → Add webhook
2. Payload URL: `https://<argocd-url>/api/webhook`
3. Content type: `application/json`
4. Secret: Generate a random string
5. Events: Select "Just the push event"

Update ArgoCD:
```bash
kubectl -n argocd patch cm argocd-cm --patch "$(cat <<EOF
data:
  webhook.github.secret: your-webhook-secret
EOF
)"
```

### Notification Configuration

Get notified on Slack/Email when:
- Sync status changes
- Health status changes
- Deployment succeeds/fails

See `argocd/install/notifications.yaml` for configuration.

## 🔐 Security Best Practices

1. **Change default admin password** immediately
2. **Use RBAC** to limit user permissions
3. **Enable SSO** (GitHub, Google, Azure AD)
4. **Use sealed secrets** for sensitive data
5. **Enable audit logging**
6. **Restrict network access** to ArgoCD UI
7. **Use separate service accounts** for applications

### Example: Create Read-Only User

```bash
kubectl -n argocd patch cm argocd-cm --patch "$(cat <<EOF
data:
  accounts.developer: apiKey, login
EOF
)"

kubectl -n argocd patch cm argocd-rbac-cm --patch "$(cat <<EOF
data:
  policy.csv: |
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, list, */*, allow
    g, developer, role:developer
EOF
)"
```

## 🐛 Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod -n argocd <pod-name>
kubectl logs -n argocd <pod-name>
```

### Application Stuck in "Progressing"

```bash
argocd app get sample-app --refresh
kubectl get events -n <app-namespace> --sort-by='.lastTimestamp'
```

### Sync Failing

```bash
# Check sync status
argocd app get sample-app

# View detailed logs
argocd app logs sample-app
```

### Out of Sync Despite No Changes

This can happen with auto-generated fields. Configure diff customizations:
```yaml
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
```

### CRD Annotation Size Error

**Error:** `The CustomResourceDefinition "applicationsets.argoproj.io" is invalid: metadata.annotations: Too long: may not be more than 262144 bytes`

**Cause:** ArgoCD CRDs have large annotations that exceed Kubernetes' 256KB limit when using client-side apply.

**Solution 1: Use Server-Side Apply (Recommended)**
```bash
# Re-apply with server-side flag
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --server-side --force-conflicts
```

**Solution 2: Use kubectl replace**
```bash
# Download manifest
curl -o argocd-install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply with replace
kubectl replace -n argocd -f argocd-install.yaml --force

# Or for first-time install
kubectl create -n argocd -f argocd-install.yaml
```

**Solution 3: Use Helm (Avoids the issue entirely)**
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace
```

**Prevention:** Always use `--server-side` flag when applying ArgoCD manifests.

## 📚 Next Steps

ArgoCD is installed and ready! Now deploy your application:
➡️ [Application Deployment](04-app-deployment.md)

## 🔗 Additional Resources

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://www.gitops.tech/)
