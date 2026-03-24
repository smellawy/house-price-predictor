# Complete AWS EKS Deployment Guide with GitOps & Monitoring

This is a comprehensive step-by-step guide for deploying the House Price Predictor application to AWS EKS with ArgoCD GitOps and Grafana monitoring.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: EKS Cluster Setup](#phase-1-eks-cluster-setup)
3. [Phase 2: Deploy Application](#phase-2-deploy-application)
4. [Phase 3: Git Repository Setup](#phase-3-git-repository-setup)
5. [Phase 4: ArgoCD GitOps Setup](#phase-4-argocd-gitops-setup)
6. [Phase 5: Monitoring with Grafana](#phase-5-monitoring-with-grafana)
7. [Phase 6: Verification & Testing](#phase-6-verification--testing)
8. [Troubleshooting](#troubleshooting)
9. [Next Steps](#next-steps)

---

## Prerequisites

Before starting, install the following tools:

```bash
# 1. AWS CLI v2
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version

# 2. kubectl
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client

# 3. eksctl
# macOS
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Verify
eksctl version

# 4. Helm 3
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version

# 5. Docker (optional for testing locally)
# macOS
brew install docker   # or use Docker Desktop

# Linux
sudo yum install docker    # or apt-get

# 6. Git
# macOS
brew install git

# Linux
sudo yum install git   # or apt-get
```

Configure AWS credentials:

```bash
# Configure AWS CLI
aws configure

# Enter:
# AWS Access Key ID: <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region: us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

---

## Phase 1: EKS Cluster Setup

### Step 1.1: Create EKS Cluster

```bash
# Set environment variables
export CLUSTER_NAME="house-price-predictor-eks"
export REGION="us-east-1"
export NODEGROUP_NAME="app-nodegroup"
export NODE_COUNT="3"
export INSTANCE_TYPE="t3.medium"

# Create the cluster using eksctl
# This takes 15-20 minutes
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --nodegroup-name $NODEGROUP_NAME \
  --nodes $NODE_COUNT \
  --node-type $INSTANCE_TYPE \
  --managed \
  --enable-ssm \
  --with-oidc \
  --ssh-access \
  --zones ${REGION}a,${REGION}b,${REGION}c

echo "Cluster creation initiated..."
```

### Step 1.2: Update kubeconfig

```bash
# Update kubeconfig to access the cluster
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $REGION

# Verify cluster access
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces

# Expected output: 3 nodes running
```

### Step 1.3: Install Metrics Server (for HPA)

```bash
# Install Metrics Server for Horizontal Pod Autoscaler
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify installation
kubectl get deployment metrics-server -n kube-system
```

### Step 1.4: Install AWS Load Balancer Controller

```bash
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Create IAM service account
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Step 1.5: Verify Cluster Health

```bash
# Run comprehensive health checks
echo "=== Checking Nodes ==="
kubectl get nodes -o wide

echo "=== Checking Node Resources ==="
kubectl top nodes

echo "=== Checking System Pods ==="
kubectl get pods -n kube-system

echo "=== Checking Metrics Server ==="
kubectl get deployment metrics-server -n kube-system

echo "=== Checking AWS Load Balancer Controller ==="
kubectl get deployment -n kube-system aws-load-balancer-controller

# All should show as running/active
```

---

## Phase 2: Deploy Application

### Step 2.1: Create Application Namespace

```bash
# Create namespace
kubectl create namespace house-price-predictor

# Verify
kubectl get namespace house-price-predictor
```

### Step 2.2: Deploy Application Manifests

```bash
# Apply the Kubernetes manifest containing both services and deployments
kubectl apply -f deployment/kubernetes/app-deployment.yaml

# Verify deployment
kubectl get all -n house-price-predictor
kubectl get pods -n house-price-predictor -w

# Wait for all pods to be in Running state
```

### Step 2.3: Monitor Initial Deployment

```bash
# Watch pod status in real-time
kubectl get pods -n house-price-predictor -w

# In another terminal, check logs
kubectl logs -n house-price-predictor -l app=api-service --tail=50 -f

# Check pod details if any fail
kubectl describe pod -n house-price-predictor <pod-name>
```

### Step 2.4: Access the Application

```bash
# Get the LoadBalancer external IP (may take 2-3 minutes to appear)
kubectl get svc api-service-lb -n house-price-predictor -w

# Once EXTERNAL-IP appears, save it
export API_ENDPOINT=$(kubectl get svc api-service-lb -n house-price-predictor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "API Endpoint: http://$API_ENDPOINT"
echo "API Docs: http://$API_ENDPOINT/docs"
echo "Health Check: http://$API_ENDPOINT/health"

# Test the API
curl http://$API_ENDPOINT/health

# Expected output: {"status":"healthy","model_loaded":true}
```

### Step 2.5: Test API Endpoints

```bash
# Test prediction endpoint
curl -X POST http://$API_ENDPOINT/predict \
  -H "Content-Type: application/json" \
  -d '{
    "crim": 0.03237,
    "zn": 0,
    "indus": 2.18,
    "chas": 0,
    "nox": 0.458,
    "rm": 6.998,
    "age": 45.8,
    "dis": 6.5622,
    "rad": 3,
    "tax": 222,
    "ptratio": 18.7,
    "b": 394.63,
    "lstat": 2.94
  }'

# Expected output: prediction with price estimate
```

---

## Phase 3: Git Repository Setup

### Step 3.1: Push Code to GitHub

```bash
# Initialize git if not already done
cd /home/ec2-user/house-price-predictor
git init
git add .
git commit -m "Initial setup for EKS deployment with GitOps"

# Add remote repository (replace with your GitHub repo)
git remote add origin https://github.com/YOUR-USERNAME/house-price-predictor.git
git branch -M main
git push -u origin main

# Verify files are pushed
git log --oneline | head -10
```

### Step 3.2: Create GitOps Directory Structure

```bash
# Create ArgoCD applications directory
mkdir -p argocd-apps

# Create the ArgoCD Application manifest
cat > argocd-apps/house-price-predictor-app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: house-price-predictor
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR-USERNAME/house-price-predictor
    path: deployment/kubernetes
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: house-price-predictor
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
EOF

# Commit and push
git add argocd-apps/
git commit -m "Add ArgoCD application manifest"
git push origin main
```

---

## Phase 4: ArgoCD GitOps Setup

### Step 4.1: Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD using manifests
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods to be running
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s

echo "ArgoCD installation complete"
```

### Step 4.2: Access ArgoCD UI

```bash
# Forward port to access ArgoCD locally
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Get admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Access ArgoCD UI
echo "Access ArgoCD at: https://localhost:8080"
# Username: admin
# Password: <from above>
```

### Step 4.3: Install ArgoCD CLI (Optional)

```bash
# Install ArgoCD CLI
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Log in
argocd login localhost:8080 \
  --username admin \
  --password $ARGOCD_PASSWORD \
  --insecure

# Verify
argocd version
```

### Step 4.4: Add GitHub Repository to ArgoCD

```bash
# For HTTPS (requires personal access token):
# 1. Create GitHub Personal Access Token:
#    - Go to https://github.com/settings/tokens
#    - Click "Generate new token"
#    - Select scopes: repo, workflow
#    - Copy the token

export GITHUB_TOKEN="your-github-token"
export GITHUB_USER="your-username"
export GITHUB_REPO="house-price-predictor"

# Add repository via CLI
argocd repo add https://github.com/$GITHUB_USER/$GITHUB_REPO \
  --username $GITHUB_USER \
  --password $GITHUB_TOKEN \
  --insecure-skip-server-verification

# Verify
argocd repo list
```

### Step 4.5: Deploy Application via ArgoCD

```bash
# Method 1: Create Application manifest
kubectl apply -f argocd-apps/house-price-predictor-app.yaml

# Method 2: Create via CLI
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
argocd app wait house-price-predictor

# Check status
argocd app get house-price-predictor
```

### Step 4.6: Verify GitOps Deployment

```bash
# List all ArgoCD applications
kubectl get applications -n argocd

# Check application status
argocd app list

# Detailed status
argocd app get house-price-predictor

# View application in EKS
kubectl get all -n house-price-predictor
```

---

## Phase 5: Monitoring with Grafana

### Step 5.1: Install Prometheus and Grafana

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus Operator (kube-prometheus-stack)
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.enabled=false \
  --set alertmanager.enabled=true \
  --wait

# Install Grafana
helm install grafana grafana/grafana \
  -n monitoring \
  --set adminPassword="grafana-admin-password" \
  --set service.type=LoadBalancer \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --wait

echo "Prometheus and Grafana installation complete"
```

### Step 5.2: Access Grafana

```bash
# Get Grafana LoadBalancer IP
kubectl get svc grafana -n monitoring -w

# When external IP appears:
export GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Access Grafana at: http://$GRAFANA_IP:3000"

# Get admin password
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d)
echo "Grafana Admin Password: $GRAFANA_PASSWORD"

# Credentials:
# Username: admin
# Password: <from above>
```

### Step 5.3: Configure Prometheus as Datasource

```bash
# In Grafana UI:
# 1. Click Configuration (gear icon) in left sidebar
# 2. Select Data Sources
# 3. Click Add data source
# 4. Choose Prometheus
# 5. Set URL to: http://prometheus-operated:9090
# 6. Click Save & Test
```

### Step 5.4: Import Kubernetes Dashboards

```bash
# In Grafana UI, import dashboards:
# 1. Click "+" in left sidebar
# 2. Select "Import"
# 3. Enter dashboard ID and import:

# Kubernetes Cluster Monitoring - ID: 7249
# Kubernetes Pod Metrics - ID: 6417
# Node Exporter Full - ID: 1860

# Or use URL method for each dashboard
```

### Step 5.5: Create Application Monitoring

```bash
# Create ServiceMonitor for application
cat > monitoring-servicemonitor.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: house-price-predictor
  namespace: house-price-predictor
spec:
  selector:
    matchLabels:
      app: api-service
  endpoints:
  - port: http
    interval: 30s
EOF

kubectl apply -f monitoring-servicemonitor.yaml
```

### Step 5.6: Set Up Alerts

```bash
# Create Prometheus alerts for application
cat > monitoring-alerts.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: house-price-predictor-alerts
  namespace: monitoring
spec:
  groups:
  - name: application
    interval: 30s
    rules:
    - alert: APIServiceDown
      expr: up{job="api-service"} == 0
      for: 2m
      annotations:
        summary: "API Service is down"
      
    - alert: APIHighErrorRate
      expr: rate(http_requests_total{job="api-service",status=~"5.."}[5m]) > 0.01
      for: 5m
      annotations:
        summary: "High error rate in API"
EOF

kubectl apply -f monitoring-alerts.yaml
```

---

## Phase 6: Verification & Testing

### Step 6.1: Verify All Components

```bash
echo "=== EKS Cluster Status ==="
kubectl get nodes
kubectl cluster-info

echo "=== Application Pods ==="
kubectl get pods -n house-price-predictor

echo "=== ArgoCD ==="
kubectl get applications -n argocd
argocd app list

echo "=== Monitoring ==="
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

### Step 6.2: Test Application API

```bash
# Get API endpoint
export API_ENDPOINT=$(kubectl get svc api-service-lb -n house-price-predictor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Health check
curl http://$API_ENDPOINT/health

# Make predictions
curl -X POST http://$API_ENDPOINT/predict \
  -H "Content-Type: application/json" \
  -d '{
    "crim": 0.03237,
    "zn": 0,
    "indus": 2.18,
    "chas": 0,
    "nox": 0.458,
    "rm": 6.998,
    "age": 45.8,
    "dis": 6.5622,
    "rad": 3,
    "tax": 222,
    "ptratio": 18.7,
    "b": 394.63,
    "lstat": 2.94
  }'

# Swagger UI
echo "Open Swagger UI: http://$API_ENDPOINT/docs"
```

### Step 6.3: Test Auto-scaling

```bash
# Generate load to trigger auto-scaling
kubectl run -it --rm load-generator --image=busybox /bin/sh

# Inside the pod:
# while sleep 0.01; do wget -q -O- http://api-service:8000/health; done

# In another terminal, watch HPA
kubectl get hpa -n house-price-predictor -w

# Watch pods scale up
kubectl get pods -n house-price-predictor -w
```

### Step 6.4: Test GitOps Workflow

```bash
# Make a change to deployment manifest
# Edit deployment/kubernetes/app-deployment.yaml
# Increase replicas from 3 to 4 for api-service

# Commit and push
git add deployment/kubernetes/app-deployment.yaml
git commit -m "Increase API replicas to 4"
git push origin main

# ArgoCD will automatically detect and sync
# Check sync status
argocd app get house-price-predictor --watch

# Verify in cluster
kubectl get pods -n house-price-predictor | grep api-service
```

---

## Troubleshooting

### Cluster Creation Issues

```bash
# Check cluster status
eksctl get cluster --region us-east-1

# Describe cluster
eksctl utils describe-stacks --region us-east-1 --cluster=$CLUSTER_NAME

# Check CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name eksctl-$CLUSTER_NAME-cluster \
  --region us-east-1
```

### Pod Issues

```bash
# Pod stuck in pending
kubectl describe pod <pod-name> -n house-price-predictor

# Check events
kubectl get events -n house-price-predictor --sort-by='.lastTimestamp'

# Check resource availability
kubectl top nodes

# View logs
kubectl logs <pod-name> -n house-price-predictor -f
```

### ArgoCD Issues

```bash
# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Test repository connection
argocd repo get https://github.com/$GITHUB_USER/$GITHUB_REPO

# Refresh application
argocd app refresh house-price-predictor
```

### Monitoring Issues

```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090
# Visit http://localhost:9090/targets

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

---

## Cost Optimization

- Use spot instances for non-critical workloads
- Set appropriate resource requests/limits
- Enable auto-scaling
- Monitor CloudWatch for unused resources
- Use EC2 Fleet for cost optimization

---

## Security Best Practices

- Keep EKS and node AMIs updated
- Use IAM roles for service accounts (IRSA)
- Enable RBAC and network policies
- Scan container images for vulnerabilities
- Use secrets for sensitive data
- Restrict API server access

---

## Next Steps

1. **Set up backup strategies** for EKS and persistent volumes
2. **Configure CD/CI pipeline** for automated deployments
3. **Implement Sealed Secrets** for sensitive configuration
4. **Set up log aggregation** with CloudWatch or ELK
5. **Enable AWS GuardDuty** for threat detection
6. **Create disaster recovery plan** with backup clusters

---

## Cleanup

```bash
# Delete application
kubectl delete -f deployment/kubernetes/app-deployment.yaml

# Delete ArgoCD
helm uninstall argocd -n argocd
kubectl delete namespace argocd

# Delete monitoring
helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring
kubectl delete namespace monitoring

# Delete EKS cluster (takes 10-15 minutes)
eksctl delete cluster \
  --name $CLUSTER_NAME \
  --region $REGION
```

---

## References

- **EKS Documentation**: https://docs.aws.amazon.com/eks/
- **eksctl Documentation**: https://eksctl.io/
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/
- **Kubernetes Documentation**: https://kubernetes.io/docs/

---

## Support & Feedback

For issues or questions:
1. Check the troubleshooting section
2. Review your AWS CloudTrail logs
3. Check EKS events and pod logs
4. Refer to official documentation
5. Open an issue on GitHub
