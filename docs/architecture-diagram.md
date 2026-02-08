# Architecture Overview

This document provides a comprehensive view of the ArgoCD + AKS GitOps deployment architecture.

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Developer                               │
│                     (Makes Code Changes)                        │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ git push
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Repository                          │
│  ┌───────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │  Application  │  │  Kubernetes  │  │  Infrastructure   │   │
│  │     Code      │  │   Manifests  │  │   (Bicep/IaC)     │   │
│  └───────────────┘  └──────────────┘  └───────────────────┘   │
└────────────┬────────────────────────────────────┬───────────────┘
             │                                    │
             │ Webhook/Poll                       │
             ▼                                    │
┌─────────────────────────────────────────────────┼───────────────┐
│              GitHub Actions (CI)                │               │
│  ┌──────────────────────────────────────────┐  │               │
│  │  1. Run tests                            │  │               │
│  │  2. Build Docker image                   │  │               │
│  │  3. Push to Azure Container Registry     │  │               │
│  │  4. Update manifest with new image tag   │  │               │
│  └──────────────────────────────────────────┘  │               │
└────────────┬────────────────────────────────────┘               │
             │                                                    │
             │ Image pushed                                       │
             ▼                                                    │
┌─────────────────────────────────────────────────────────────────┤
│           Azure Container Registry (ACR)                        │
│                  (Private Image Storage)                        │
└────────────┬────────────────────────────────────────────────────┘
             │                                                    │
             │ Pull image                   Monitors Git repo     │
             │                                    │               │
             │                                    ▼               │
┌────────────┼────────────────────────────────────────────────────┐
│            │         Azure Kubernetes Service (AKS)            │
│            │                                                    │
│  ┌─────────┼──────────────────────────────────────────────┐   │
│  │         │   ArgoCD (GitOps Controller)                  │   │
│  │         │                                                │   │
│  │  ┌──────▼─────────────────────────────────────────────┐ │   │
│  │  │  Application Controller                            │ │   │
│  │  │  - Monitors Git repository for changes             │ │   │
│  │  │  - Compares desired state (Git) vs actual (K8s)    │ │   │
│  │  │  - Syncs differences automatically                 │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  │                                                          │   │
│  │  ┌──────────────────────────────────────────────────┐   │   │
│  │  │  Web UI & API Server                             │   │   │
│  │  │  - Visualization of deployments                  │   │   │
│  │  │  - Manual sync triggers                          │   │   │
│  │  │  - RBAC management                               │   │   │
│  │  └──────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Application Namespaces                      │   │
│  │                                                           │   │
│  │  ┌─────────────────┐       ┌─────────────────┐          │   │
│  │  │   Namespace:dev │       │  Namespace:prod │          │   │
│  │  │  ┌────────────┐ │       │  ┌────────────┐ │          │   │
│  │  │  │ Deployment │ │       │  │ Deployment │ │          │   │
│  │  │  │  Pods: 2   │ │       │  │  Pods: 3   │ │          │   │
│  │  │  └────────────┘ │       │  └────────────┘ │          │   │
│  │  │  ┌────────────┐ │       │  ┌────────────┐ │          │   │
│  │  │  │  Service   │ │       │  │  Service   │ │          │   │
│  │  │  └────────────┘ │       │  └────────────┘ │          │   │
│  │  │  ┌────────────┐ │       │  ┌────────────┐ │          │   │
│  │  │  │ ConfigMap  │ │       │  │ ConfigMap  │ │          │   │
│  │  │  └────────────┘ │       │  └────────────┘ │          │   │
│  │  └─────────────────┘       └─────────────────┘          │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

## 🔄 GitOps Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                       Developer Workflow                        │
└─────────────────────────────────────────────────────────────────┘

1. CODE CHANGE
   Developer modifies application code
   └─> git commit -m "Fix bug in authentication"
   └─> git push origin main

2. CI PIPELINE (GitHub Actions)
   └─> Checkout code
   └─> Run tests (unit, integration)
   └─> Build Docker image
       docker build -t acr.azurecr.io/app:v1.2.3
   └─> Push to ACR
   └─> Update Kubernetes manifest
       Edit kubernetes/overlays/dev/kustomization.yaml
       newTag: v1.2.3
   └─> Commit manifest change
   └─> Push to Git

3. ARGOCD DETECTION
   └─> ArgoCD polls Git every 3 minutes (or webhook instant)
   └─> Detects manifest change
   └─> Compares desired state (Git) vs actual state (Kubernetes)
   └─> Status: OutOfSync

4. ARGOCD SYNC
   └─> Generate manifests (Kustomize build)
   └─> Apply to Kubernetes cluster
       kubectl apply -f deployment.yaml
   └─> Wait for health checks
   └─> Status: Synced + Healthy

5. KUBERNETES DEPLOYMENT
   └─> Rolling update strategy
   └─> Create new ReplicaSet
   └─> Spin up new pods with v1.2.3
   └─> Wait for readiness probes
   └─> Terminate old pods
   └─> Deployment complete

6. VERIFICATION
   └─> Developer checks ArgoCD UI
   └─> Application shows "Synced" + "Healthy"
   └─> Users access new version
```

## 🧩 Component Details

### Azure Kubernetes Service (AKS)

**Configuration:**
- **Node Count:** 3 (for high availability)
- **VM Size:** Standard_DS2_v2 (2 vCPU, 7GB RAM)
- **Kubernetes Version:** 1.28+
- **Networking:** Kubenet
- **Identity:** System-assigned managed identity

**Node Pool:**
```
aks-nodepool1
├── Node 1 (Ready)
├── Node 2 (Ready)
└── Node 3 (Ready)
```

### Azure Container Registry (ACR)

**Purpose:** Private Docker image repository

**Features:**
- Integrated with AKS (AcrPull role)
- Geographic replication (optional)
- Vulnerability scanning
- Image retention policies

**Image Tags:**
```
acr.azurecr.io/sample-app:
├── v1.0.0
├── v1.0.1
├── v1.1.0
└── latest (not recommended for prod)
```

### ArgoCD Components

**1. Application Controller**
- Monitors Git repositories
- Reconciles desired vs actual state
- Executes sync operations
- Manages application lifecycle

**2. Repo Server**
- Clones Git repositories
- Generates Kubernetes manifests
- Supports Helm, Kustomize, plain YAML
- Caches repository data

**3. API Server / UI**
- RESTful API
- Web-based dashboard
- CLI interface
- Webhook endpoints

**4. Dex (SSO)**
- Authentication provider
- Supports GitHub, Google, LDAP, SAML
- RBAC integration

**5. Redis**
- Caching layer
- Improves performance
- Stores temporary data

### Kustomize Structure

```
kubernetes/
├── base/                       # Common base configuration
│   ├── deployment.yaml         # Base deployment spec
│   ├── service.yaml            # Base service spec
│   ├── configmap.yaml          # Base config
│   └── kustomization.yaml      # Base kustomization
│
└── overlays/                   # Environment-specific overrides
    ├── dev/
    │   ├── kustomization.yaml  # Dev-specific settings
    │   │   └─> namespace: dev
    │   │   └─> replicas: 2
    │   │   └─> image: acr.azurecr.io/app:v1.0.0
    │   └── patches/
    │       └── resource-limits.yaml
    │
    └── prod/
        ├── kustomization.yaml  # Prod-specific settings
        │   └─> namespace: prod
        │   └─> replicas: 3
        │   └─> image: acr.azurecr.io/app:v1.0.0
        └── patches/
            ├── resource-limits.yaml
            └── horizontal-pod-autoscaler.yaml
```

## 🔐 Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Security Layers                          │
└─────────────────────────────────────────────────────────────────┘

1. IDENTITY & ACCESS
   ├── Azure AD Authentication
   ├── Managed Identity (AKS → ACR)
   ├── RBAC (Kubernetes)
   └── ArgoCD SSO + RBAC

2. NETWORK SECURITY
   ├── Network Policies (pod-to-pod)
   ├── Azure NSG (node-level)
   ├── Private Endpoints (optional)
   └── TLS/SSL (ingress)

3. IMAGE SECURITY
   ├── Private ACR (not public)
   ├── Image scanning (vulnerabilities)
   ├── Signed images (optional)
   └── Minimal base images

4. SECRETS MANAGEMENT
   ├── Kubernetes Secrets
   ├── Azure Key Vault integration
   ├── Sealed Secrets (encrypted in Git)
   └── External Secrets Operator

5. RUNTIME SECURITY
   ├── Pod Security Standards
   ├── Read-only root filesystem
   ├── Non-root containers
   └── Resource limits
```

## 📊 Data Flow Diagram

```
Code Commit → GitHub → CI Build → ACR → ArgoCD Sync → AKS Deployment
     │                    │         │         │              │
     │                    │         │         │              │
     ▼                    ▼         ▼         ▼              ▼
  Version              Docker    Image    Manifest      Pod Creation
  Control              Image     Pull     Apply         & Scheduling
```

## 🎯 Deployment Environments

| Aspect | Development | Production |
|--------|-------------|------------|
| Namespace | `dev` | `prod` |
| Replicas | 2 | 3 |
| Auto-sync | Yes | Yes (with approval) |
| Self-heal | Yes | Yes |
| Resource Limits | Low | High |
| HPA | No | Yes (2-10 pods) |
| Ingress | Internal | External + SSL |
| Monitoring | Basic | Full (Prometheus) |

## 🔄 Sync Policies

### Automated Sync
```yaml
syncPolicy:
  automated:
    prune: true      # Delete removed resources
    selfHeal: true   # Revert manual changes
```

**When to use:** Development, staging environments

### Manual Sync
```yaml
syncPolicy: {}  # No automated policy
```

**When to use:** Production (with approval workflows)

## 🚀 Scaling Architecture

### Horizontal Pod Autoscaler (HPA)

```
         CPU > 70%
             │
             ▼
    ┌────────────────┐
    │      HPA       │
    │   (monitors)   │
    └────────┬───────┘
             │
             │ scales
             ▼
    ┌────────────────┐
    │   Deployment   │
    │   2 → 5 pods   │
    └────────────────┘
```

### Cluster Autoscaler

```
    Pod pending (no resources)
             │
             ▼
    ┌────────────────┐
    │    Cluster     │
    │  Autoscaler    │
    └────────┬───────┘
             │
             │ adds node
             ▼
    ┌────────────────┐
    │   Node Pool    │
    │   3 → 4 nodes  │
    └────────────────┘
```

## 📈 Monitoring & Observability

```
Application Metrics
       │
       ├─> Prometheus (scrapes /metrics)
       │         │
       │         └─> Grafana (visualizes)
       │
       ├─> Azure Monitor (platform metrics)
       │         │
       │         └─> Log Analytics
       │
       └─> ArgoCD Metrics
                 │
                 └─> Application health, sync status
```

## 🔗 Integration Points

1. **GitHub ↔ GitHub Actions:** Webhook on push
2. **GitHub Actions ↔ ACR:** Service principal auth
3. **ACR ↔ AKS:** Managed identity (AcrPull)
4. **Git ↔ ArgoCD:** SSH/HTTPS repo access
5. **ArgoCD ↔ Kubernetes:** In-cluster service account
6. **Developer ↔ ArgoCD:** SSO + RBAC

## 🎓 Key Benefits of This Architecture

✅ **GitOps:** Git as single source of truth  
✅ **Automated:** Minimal manual intervention  
✅ **Auditable:** All changes tracked in Git  
✅ **Declarative:** Desired state, not imperative steps  
✅ **Recoverable:** Easy rollback via Git history  
✅ **Secure:** RBAC, secrets management, private registry  
✅ **Scalable:** Auto-scaling at pod and node level  
✅ **Observable:** Metrics, logs, health checks  

---

This architecture provides a production-ready foundation for modern cloud-native applications on Azure.
