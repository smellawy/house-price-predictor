# ArgoCD GitOps Setup Guide

This guide walks you through setting up ArgoCD for GitOps-based deployment and management of the House Price Predictor application on EKS.

## Prerequisites

- EKS cluster already created and configured (see EKS-SETUP.md)
- kubectl configured
- GitHub account with your project repository
- Git CLI installed
- Helm 3.x installed: https://helm.sh/docs/intro/install/

## Step 1: Install ArgoCD

### Add Helm Repository

```bash
# Add ArgoCd Helm repository
helm repo add argo https://argoproj-helm.github.io/argo-helm
helm repo update

# Or using direct manifests
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Verify Installation

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Wait for all pods to be running
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

## Step 2: Access ArgoCD UI

### Port Forward to Access UI

```bash
# Forward port to access ArgoCD UI locally
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access at: https://localhost:8080
```

### Get Initial Admin Password

```bash
# Get the initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"

# Login credentials:
# Username: admin
# Password: <from above>
```

### Change Admin Password

```bash
# Install ArgoCD CLI (optional but recommended)
# On macOS:
brew install argocd

# On Linux:
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Login via CLI
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure

# Change password
argocd account update-password --account admin --current-password $ARGOCD_PASSWORD --new-password <your-new-password>
```

## Step 3: Expose ArgoCD via LoadBalancer (Optional)

### Create LoadBalancer Service

```bash
# Create service manifest
cat > argocd-service-lb.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-lb
  namespace: argocd
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 8080
  selector:
    app.kubernetes.io/name: argocd-server
EOF

kubectl apply -f argocd-service-lb.yaml

# Get LoadBalancer IP
kubectl get svc argocd-server-lb -n argocd -w
```

## Step 4: Configure GitHub Access for ArgoCD

### Create GitHub Personal Access Token

```bash
# Go to GitHub Settings > Developer Settings > Personal Access Tokens
# Create a new token with the following scopes:
# - repo (full control of private repositories)
# - workflow (to update GitHub Actions workflows)
# - read:org
# Copy the token and save it securely
```

### Add GitHub Repository to ArgoCD

```bash
# Set variables
export GITHUB_USER="your-github-username"
export GITHUB_REPO="house-price-predictor"
export GITHUB_TOKEN="your-github-personal-access-token"
export GITHUB_BRANCH="main"

# Via CLI
argocd repo add https://github.com/$GITHUB_USER/$GITHUB_REPO \
  --username $GITHUB_USER \
  --password $GITHUB_TOKEN \
  --insecure-skip-server-verification

# List configured repos
argocd repo list
```

## Step 5: Create GitOps Repository Structure

Push this structure to your GitHub repository:

```
house-price-predictor/
├── argocd-apps/          # ArgoCD Application manifests
│   └── house-price-predictor-app.yaml
├── deployment/
│   └── kubernetes/
│       └── app-deployment.yaml  # Your deployment manifest
└── README.md
```

### Sample ArgoCD Application Manifest

Save this as `argocd-apps/house-price-predictor-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: house-price-predictor
  namespace: argocd
spec:
  # The project the application belongs to
  project: default
  
  # Source of the application manifests
  source:
    repoURL: https://github.com/YOUR-USERNAME/house-price-predictor
    path: deployment/kubernetes
    targetRevision: main
    
    # If using Kustomize
    # kustomize:
    #   images:
    #   - mohamedadel9988/house-pricemodel:latest
    #   - mohamedadel9988/fastapi:b89009d7291fcfc20f4ce57d8a9fb472472523eb

  # Destination where the application will be deployed
  destination:
    server: https://kubernetes.default.svc
    namespace: house-price-predictor

  # Sync policy
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      
    syncOptions:
    - CreateNamespace=true
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  # Notification settings
  info:
  - name: Documentation
    value: https://github.com/YOUR-USERNAME/house-price-predictor
  - name: Author
    value: Your Name
```

## Step 6: Deploy Application Using ArgoCD

### Via CLI

```bash
# Create the ArgoCD Application
kubectl apply -f argocd-apps/house-price-predictor-app.yaml

# Or create via CLI
argocd app create house-price-predictor \
  --repo https://github.com/$GITHUB_USER/$GITHUB_REPO \
  --path deployment/kubernetes \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace house-price-predictor \
  --auto-prune \
  --self-heal

# Sync the application
argocd app sync house-price-predictor

# Wait for sync to complete
argocd app wait house-price-predictor --sync
```

### Monitor Deployment

```bash
# Get application status
argocd app get house-price-predictor

# Watch application in real-time
argocd app get house-price-predictor --watch

# Check application history
argocd app history house-price-predictor

# View application details
kubectl get applications -n argocd house-price-predictor -o yaml
```

## Step 7: Set Up Notifications

### Create ArgoCD Notifier (Optional - Slack/Email)

```bash
# Create a secret for your notification service
kubectl create secret generic argocd-notifications-secret \
  -n argocd \
  --from-literal=slack-token=xoxb-YOUR-SLACK-TOKEN \
  --from-literal=slack-channel=YOUR-SLACK-CHANNEL \
  -o yaml | kubectl apply -f -
```

### Configure Notification Triggers

```bash
# ArgoCD notifications can be configured for:
# - Application sync succeeded
# - Application sync failed
# - Application health degraded
# - Applications require attention
```

## Step 8: Set Up Automatic Image Updates (Optional)

### Using ArgoCD Image Updater

```bash
# Install ArgoCD Image Updater
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Create service account
kubectl create serviceaccount argocd-image-updater -n argocd
kubectl create clusterrolebinding argocd-image-updater \
  --clusterrole=argocd-image-updater \
  --serviceaccount=argocd-image-updater:argocd-image-updater

# Add annotations to your Application manifest for automatic updates
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: house-pricemodel,fastapi
    argocd-image-updater.argoproj.io/house-pricemodel.update-strategy: latest
    argocd-image-updater.argoproj.io/fastapi.update-strategy: latest
```

## Step 9: GitOps Workflow

### Standard Deployment Flow

```bash
# 1. In your local machine, make changes
# 2. Update deployment manifests
# 3. Commit and push to GitHub
git add deployment/kubernetes/app-deployment.yaml
git commit -m "Update image version"
git push origin main

# 4. ArgoCD automatically detects changes (polling or webhook)
# 5. ArgoCD syncs the changes to the cluster
# 6. Monitor the sync via ArgoCD UI or CLI
argocd app sync house-price-predictor
argocd app get house-price-predictor
```

### Manual Rollback

```bash
# View application history
argocd app history house-price-predictor

# Rollback to a previous sync
argocd app rollback house-price-predictor 1

# Verify rollback
argocd app get house-price-predictor
```

## Step 10: Advanced ArgoCD Configuration

### Enable ArgoCD Server with Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - host: argocd.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
```

### Enable RBAC in ArgoCD

```bash
# Create a policy for developers
kubectl -n argocd patch configmap argocd-rbac-cm -p '
{
  "data": {
    "policy.default": "role:readonly",
    "policy.csv": "p, role:developers, applications, get, */*, allow\np, role:developers, applications, sync, */*, allow",
    "g": "g, my-github-org:backend-team, role:developers"
  }
}'
```

## Troubleshooting

### Application sync stuck

```bash
# Check application status
argocd app get house-price-predictor

# View sync issues
kubectl get applications -n argocd house-price-predictor -o yaml
```

### ArgoCD pod not running

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl describe pod -n argocd <pod-name>
```

### Repository connection issues

```bash
# Test repository connection
argocd repo get https://github.com/$GITHUB_USER/$GITHUB_REPO

# Refresh repository
argocd repo refresh https://github.com/$GITHUB_USER/$GITHUB_REPO
```

## Best Practices

1. **Separate Git Repos**: Keep application code separate from infrastructure
2. **Environment Branches**: Use branches for different environments (dev, staging, prod)
3. **Code Review**: Require PR reviews before merging to main
4. **Notifications**: Set up Slack/email notifications for sync events
5. **RBAC**: Implement proper access control for team members
6. **Secrets Management**: Use sealed-secrets or external-secrets for sensitive data
7. **GitOps Principles**: All infrastructure changes should go through Git
8. **Version Control**: Tag releases and maintain changelog

## Next Steps

- Configure Grafana for monitoring
- Set up backup and disaster recovery
- Integrate with CI/CD pipeline
- Implement Kustomize for environment-specific configs
- Set up Flux (alternative to ArgoCD)

## References

- ArgoCD Official Docs: https://argo-cd.readthedocs.io/
- ArgoCD GitHub: https://github.com/argoproj/argo-cd
- GitOps Best Practices: https://www.gitops.tech/
