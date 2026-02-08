# Project File Tree

Complete structure of the ArgoCD + AKS GitOps Demo project:

```
poc-argocd-aks-scenario/
│
├── README.md                          # Main project documentation
├── QUICKSTART.md                      # 15-minute quick start guide
├── CONTRIBUTING.md                    # Contribution guidelines
├── LICENSE                            # MIT License
├── .gitignore                         # Git ignore rules
│
├── docs/                              # Detailed documentation
│   ├── 01-prerequisites.md           # Prerequisites & tools
│   ├── 02-aks-setup.md               # AKS cluster deployment
│   ├── 03-argocd-installation.md     # ArgoCD installation
│   ├── 04-app-deployment.md          # Application deployment
│   └── architecture-diagram.md        # Architecture overview
│
├── app/                               # Sample Node.js application
│   ├── README.md                     # App-specific documentation
│   ├── Dockerfile                    # Multi-stage Docker build
│   ├── .dockerignore                 # Docker ignore rules
│   ├── package.json                  # Node.js dependencies
│   └── src/
│       └── server.js                 # Express app with health endpoints
│
├── infrastructure/                    # Infrastructure as Code
│   ├── bicep/                        # Azure Bicep templates
│   │   ├── main.bicep               # Main AKS template
│   │   ├── acr.bicep                # ACR module
│   │   └── parameters.json          # Deployment parameters
│   │
│   └── scripts/                      # Automation scripts
│       ├── setup-aks.sh             # AKS cluster setup
│       └── install-argocd.sh        # ArgoCD installation
│
├── kubernetes/                        # Kubernetes manifests
│   ├── README.md                     # Kustomize structure guide
│   │
│   ├── base/                         # Base configurations
│   │   ├── deployment.yaml          # Base deployment spec
│   │   ├── service.yaml             # ClusterIP service
│   │   ├── configmap.yaml           # Base configuration
│   │   └── kustomization.yaml       # Base kustomization
│   │
│   └── overlays/                     # Environment overlays
│       ├── dev/                      # Development
│       │   ├── kustomization.yaml   # Dev-specific config
│       │   ├── namespace.yaml       # Dev namespace
│       │   └── resource-limits.yaml # Dev resources
│       │
│       └── prod/                     # Production
│           ├── kustomization.yaml   # Prod-specific config
│           ├── namespace.yaml       # Prod namespace
│           ├── resource-limits.yaml # Prod resources
│           └── hpa.yaml             # Horizontal autoscaler
│
├── argocd/                            # ArgoCD configurations
│   ├── applications/                 # Application definitions
│   │   ├── sample-app-dev.yaml      # Dev app definition
│   │   └── sample-app-prod.yaml     # Prod app definition
│   │
│   ├── projects/                     # ArgoCD projects
│   │   └── demo-project.yaml        # Project with RBAC
│   │
│   └── install/                      # ArgoCD setup
│       ├── values.yaml              # Helm values (optional)
│       └── ingress.yaml             # Ingress config (optional)
│
└── .github/                           # GitHub integration
    ├── SETUP.md                      # GitHub Actions setup guide
    └── workflows/
        └── build-push.yaml           # CI/CD pipeline

```

## File Counts

- **Documentation:** 10 files
- **Infrastructure:** 5 files
- **Application:** 5 files
- **Kubernetes:** 11 files
- **ArgoCD:** 5 files
- **CI/CD:** 2 files

**Total:** ~38 production-ready files

## Key Components Overview

### 📚 Documentation Layer
Comprehensive guides for setup, deployment, and troubleshooting.

### 🏗️ Infrastructure Layer
Bicep templates and scripts for automated AKS deployment.

### 🚀 Application Layer
Production-ready Node.js app with health checks and monitoring.

### ☸️ Kubernetes Layer
Multi-environment manifests using Kustomize best practices.

### 🔄 GitOps Layer
ArgoCD configurations for automated deployments.

### 🤖 CI/CD Layer
GitHub Actions workflow for build, test, and deploy.

## Quick Navigation

**Getting Started:**
- Start here: [README.md](README.md)
- Quick setup: [QUICKSTART.md](QUICKSTART.md)
- Prerequisites: [docs/01-prerequisites.md](docs/01-prerequisites.md)

**Deployment:**
- AKS setup: [docs/02-aks-setup.md](docs/02-aks-setup.md)
- ArgoCD: [docs/03-argocd-installation.md](docs/03-argocd-installation.md)
- Application: [docs/04-app-deployment.md](docs/04-app-deployment.md)

**Advanced:**
- Architecture: [docs/architecture-diagram.md](docs/architecture-diagram.md)
- CI/CD setup: [.github/SETUP.md](.github/SETUP.md)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)

## Next Steps

1. **Setup:** Follow [QUICKSTART.md](QUICKSTART.md)
2. **Customize:** Update with your Git repo and ACR
3. **Deploy:** Run the setup scripts
4. **Explore:** Try the GitOps workflow
5. **Extend:** Add your own applications
