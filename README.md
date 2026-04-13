# Argo CD + Argo Workflows CI/CD Setup

## Status

- **Argo CD Application**: `weather-app` - Synced & Healthy
- **Argo CD UI**: https://localhost:8080/applications
- **Deployed Resources**: guestbook-ui + weather-app pods running

## Repository Structure

```
/home/martin/argoCICD/
├── app/                    # Application code
│   ├── server.js
│   └── package.json
├── k8s/                    # Kubernetes manifests
│   ├── deployment.yaml
│   └── argocd-application.yaml
├── cicd/                   # Workflow definitions
│   └── workflow.yaml
└── deploy.sh              # Deployment script
```

## Quick Commands

```bash
# View application in Argo CD UI
open https://localhost:8080/applications

# Check application status
argocd app list

# Check deployed resources
kubectl get all -n weather-app

# Access application
kubectl port-forward -n weather-app svc/weather-app 8081:80
curl http://localhost:8081
```

## CI/CD Flow

1. **Argo Workflows** (cicd namespace):
   - `ci-pipeline` - Clone, test, build, push
   - `cd-pipeline` - Deploy to environments

2. **Argo CD** (argocd namespace):
   - Auto-syncs from Git repo
   - Shows app status in UI

## Workflow Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| repo-url | Git repository | https://github.com/... |
| image-name | Docker image | weatherlab/weather-app |
| image-tag | Image tag | (empty) |
| environment | Target env | dev |

## Troubleshooting

```bash
# Check application sync
argocd app sync weather-app

# View app details
argocd app get weather-app

# Check pods
kubectl get pods -n weather-app -w

# View logs
kubectl logs -n weather-app -l app=weather-app
```