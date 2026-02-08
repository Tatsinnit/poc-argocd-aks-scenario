# ArgoCD AKS Sample App

Simple Node.js Express application for demonstrating GitOps deployment with ArgoCD on Azure Kubernetes Service.

## Features

- 💚 Health check endpoints
- 📊 System information endpoints
- 🐳 Containerized with Docker
- ☸️ Kubernetes-ready with probes
- 📈 Production-ready logging

## Local Development

### Prerequisites

- Node.js 18+ installed
- Docker (for container testing)

### Run Locally

```bash
# Install dependencies
npm install

# Start in development mode
npm run dev

# Start in production mode
npm start
```

### Test Endpoints

```bash
# Welcome message
curl http://localhost:3000/

# Health check
curl http://localhost:3000/health

# Version info
curl http://localhost:3000/version

# System info
curl http://localhost:3000/info

# Readiness probe
curl http://localhost:3000/ready

# Liveness probe
curl http://localhost:3000/live
```

## Docker

### Build Image

```bash
docker build -t sample-app:v1.0.0 .
```

### Run Container

```bash
docker run -p 3000:3000 \
  -e APP_VERSION=v1.0.0 \
  -e ENVIRONMENT=development \
  sample-app:v1.0.0
```

### Push to ACR

```bash
# Login to ACR
az acr login --name <your-acr-name>

# Tag image
docker tag sample-app:v1.0.0 <your-acr>.azurecr.io/sample-app:v1.0.0

# Push image
docker push <your-acr>.azurecr.io/sample-app:v1.0.0
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `3000` |
| `APP_VERSION` | Application version | `v1.0.0` |
| `ENVIRONMENT` | Environment name | `development` |
| `NODE_ENV` | Node environment | `production` |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Welcome message with basic info |
| `/health` | GET | Health status and uptime |
| `/version` | GET | Version and environment info |
| `/info` | GET | Detailed system information |
| `/ready` | GET | Readiness probe (K8s) |
| `/live` | GET | Liveness probe (K8s) |

## Kubernetes Deployment

This app is designed to run in Kubernetes with:

- **Liveness probe:** `/live`
- **Readiness probe:** `/ready`
- **Resource limits:** Configurable
- **Graceful shutdown:** Handles SIGTERM/SIGINT

See `../kubernetes/` directory for manifests.

## License

MIT
