# How It All Fits Together 🔄

A simple visual guide to understanding your GitOps pipeline.

## The Big Picture

```
┌─────────────┐
│  Developer  │  You write code
└──────┬──────┘
       │ git push
       ▼
┌─────────────────────┐
│   GitHub Repo       │  Source of truth
│   (Git = Truth)     │
└──────┬──────────────┘
       │
       ├──────────────────────┐
       │                      │
       ▼                      ▼
┌──────────────┐      ┌──────────────┐
│ GitHub       │      │   ArgoCD     │
│ Actions      │      │  (Watcher)   │
│ (Builder)    │      │              │
└──────┬───────┘      └──────┬───────┘
       │                     │
       │ builds image        │ detects change
       ▼                     │
┌──────────────┐            │
│ Azure ACR    │            │
│ (Images)     │            │
└──────┬───────┘            │
       │                     │
       │ stores image        │
       │                     │
       └──────────┬──────────┘
                  │
                  ▼
          ┌──────────────┐
          │     AKS      │  Your cluster
          │  (Runtime)   │
          └──────────────┘
                  │
                  ▼
          ┌──────────────┐
          │     App      │  Users access
          │   Running    │
          └──────────────┘
```

## The 5 Key Components

### 1. **Git Repository** (Source of Truth)
**What:** Your GitHub repo  
**Contains:**
- Application code (`app/`)
- Kubernetes manifests (`kubernetes/`)
- Infrastructure templates (`infrastructure/`)
- ArgoCD configs (`argocd/`)

**Role:** Single source of truth for everything

### 2. **GitHub Actions** (CI - Continuous Integration)
**What:** Automated build pipeline  
**Triggers:** When you push code to `main` branch  
**Does:**
1. Builds Docker image
2. Pushes to Azure Container Registry
3. Updates Kubernetes manifests with new image tag
4. Commits changes back to Git

**Location:** `.github/workflows/build-push.yaml`

### 3. **Azure Container Registry (ACR)** (Image Storage)
**What:** Private Docker registry  
**Stores:** Container images  
**Usage:** AKS pulls images from here  
**Security:** Integrated with AKS using managed identity

### 4. **ArgoCD** (CD - Continuous Deployment)
**What:** GitOps deployment tool running in AKS  
**Does:**
1. Watches Git repo every 3 minutes
2. Compares Git (desired) vs Cluster (actual)
3. Automatically syncs differences
4. Keeps cluster in sync with Git

**Key Feature:** Auto-healing (reverts manual changes)

### 5. **Azure Kubernetes Service (AKS)** (Runtime)
**What:** Your Kubernetes cluster  
**Runs:**
- ArgoCD (manages deployments)
- Your applications (dev, prod)
- 3 worker nodes

**Namespaces:**
- `argocd` - ArgoCD components
- `dev` - Development environment
- `prod` - Production environment

## The GitOps Workflow (Step by Step)

### Scenario: You update the app

```
Step 1: Developer makes change
    │
    └─> Edit app/src/server.js
    └─> git commit -m "Add new feature"
    └─> git push origin main
    
Step 2: GitHub Actions triggered
    │
    └─> Detects change in app/
    └─> Runs tests
    └─> Builds Docker image: sample-app:v1.0.1
    └─> Pushes to ACR: youracr.azurecr.io/sample-app:v1.0.1
    └─> Updates kubernetes/overlays/dev/kustomization.yaml
        Changes: newTag: v1.0.0 → v1.0.1
    └─> Commits manifest change to Git
    
Step 3: ArgoCD detects change (within 3 minutes)
    │
    └─> Polls Git repo
    └─> Sees kustomization.yaml changed
    └─> Status: OutOfSync
    
Step 4: ArgoCD syncs automatically
    │
    └─> Pulls new manifests from Git
    └─> Runs: kubectl kustomize kubernetes/overlays/dev
    └─> Applies to AKS cluster
    └─> Creates new pods with v1.0.1
    └─> Waits for readiness probes
    └─> Terminates old pods
    └─> Status: Synced & Healthy
    
Step 5: New version running!
    │
    └─> Users access updated application
```

## Key Concepts

### GitOps Principles

**1. Git is the source of truth**
- Everything declared in Git
- No manual `kubectl apply` commands
- All changes tracked in Git history

**2. Declarative configuration**
- Define WHAT you want (desired state)
- Not HOW to get there (imperative steps)
- Kubernetes figures out the steps

**3. Automatic synchronization**
- ArgoCD constantly reconciles
- Cluster state matches Git state
- Self-healing system

**4. Version control**
- Easy rollbacks (revert Git commit)
- Audit trail (who changed what, when)
- Reproducible deployments

### Why This Architecture?

**Separation of Concerns:**
- **CI (GitHub Actions):** Build and test
- **CD (ArgoCD):** Deploy and manage
- **Git:** Source of truth
- **ACR:** Image storage
- **AKS:** Runtime

**Benefits:**
- ✅ No credentials in CI for cluster access
- ✅ Declarative, not imperative
- ✅ Self-documenting (Git is the doc)
- ✅ Disaster recovery (rebuild from Git)
- ✅ Multi-environment (dev, prod)

## Data Flow Examples

### Example 1: Code Change

```
Developer
  └─> git push
       └─> GitHub Actions
            └─> Docker build → ACR
                 └─> Update manifest → Git
                      └─> ArgoCD detects
                           └─> Deploy to AKS
```

**Time:** ~5-10 minutes end-to-end

### Example 2: Configuration Change

```
Developer
  └─> Edit kubernetes/overlays/prod/resource-limits.yaml
       └─> git push
            └─> ArgoCD detects (within 3 min)
                 └─> Apply new limits to pods
                      └─> Pods restart with new limits
```

**Time:** ~3-5 minutes

### Example 3: Rollback

```
Developer
  └─> git revert HEAD
       └─> git push
            └─> ArgoCD detects previous version
                 └─> Deploys previous image tag
                      └─> Pods rollback
```

**Time:** ~3-5 minutes

## File Organization

### What's Where?

```
Repository Structure:
├── app/                          ← Your application
│   ├── src/server.js            ← App code
│   ├── Dockerfile               ← How to build image
│   └── package.json             ← Dependencies
│
├── kubernetes/                   ← K8s manifests
│   ├── base/                    ← Common config
│   └── overlays/
│       ├── dev/                 ← Dev-specific
│       └── prod/                ← Prod-specific
│
├── argocd/                       ← ArgoCD config
│   ├── applications/            ← What to deploy
│   │   ├── sample-app-dev.yaml  ← Dev app definition
│   │   └── sample-app-prod.yaml ← Prod app definition
│   └── projects/                ← Project RBAC
│
├── infrastructure/               ← Azure setup
│   ├── bicep/                   ← IaC templates
│   └── scripts/                 ← Setup scripts
│
└── .github/workflows/            ← CI pipeline
    └── build-push.yaml          ← Build automation
```

### What Each File Does

**argocd/applications/sample-app-dev.yaml:**
- Points ArgoCD to kubernetes/overlays/dev
- Says: "Watch this Git path"
- Says: "Deploy to dev namespace"
- Says: "Auto-sync when changes detected"

**kubernetes/overlays/dev/kustomization.yaml:**
- Specifies image: `youracr.azurecr.io/sample-app:v1.0.1`
- Sets replicas: 2
- Applies dev-specific configs

**app/Dockerfile:**
- Recipe to build container image
- Copies code, installs deps
- Defines how to run app

## Quick Reference

### To Deploy a Change:
```bash
# 1. Make code change
vim app/src/server.js

# 2. Push to Git
git add app/
git commit -m "Update feature"
git push

# 3. Watch ArgoCD sync (automatic)
kubectl get applications -n argocd -w
```

### To Check Status:
```bash
# All components at once
./verify-system.sh

# Or individually
kubectl get nodes                    # AKS
kubectl get pods -n argocd          # ArgoCD
kubectl get applications -n argocd  # Apps
kubectl get pods -n dev             # Dev env
```

### To Debug:
```bash
# Check ArgoCD status
argocd app get sample-app-dev

# Check pod logs
kubectl logs -n dev -l app=sample-app

# Check events
kubectl get events -n dev --sort-by='.lastTimestamp'
```

## Visual: Components in AKS Cluster

```
AKS Cluster
├── argocd namespace
│   ├── argocd-server (UI)
│   ├── argocd-application-controller (syncs apps)
│   ├── argocd-repo-server (pulls from Git)
│   └── argocd-redis (cache)
│
├── dev namespace
│   ├── sample-app-pod-1 (running v1.0.1)
│   ├── sample-app-pod-2 (running v1.0.1)
│   └── sample-app-service (exposes pods)
│
└── prod namespace
    ├── sample-app-pod-1 (running v1.0.0)
    ├── sample-app-pod-2 (running v1.0.0)
    ├── sample-app-pod-3 (running v1.0.0)
    └── sample-app-service (exposes pods)
```

## Summary: The Core Loop

```
Code Change → Git → CI Build → ACR Image → Git Manifest Update → ArgoCD Sync → AKS Deploy

                    ↑                                                              │
                    └──────────────────────────────────────────────────────────────┘
                                    (Continuous Loop)
```

**Remember:**
- Git = Truth
- ArgoCD = Enforcer
- AKS = Runtime

**The only way to deploy is through Git!**

---

For verification steps, see [VERIFICATION.md](VERIFICATION.md)  
For detailed docs, see [docs/](docs/)
