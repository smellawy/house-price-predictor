# AWS EKS Free Tier Deployment - Step by Step Guide

This guide deploys the House Price Predictor with minimal resources (1 replica) for cost optimization.

## ⚠️ Important: Instance Type Options

### Option 1: Free Tier Eligible (**RECOMMENDED**)
- **Instance:** t3.micro or t2.micro
- **Cost:** ~$0-15/month (or free for first 12 months with AWS free tier)
- **EKS Cluster:** $73/month (non-negotiable)
- **Total:** ~$73-88/month

### Option 2: m7i-flex.large (NOT Free Tier)
- **Instance:** m7i-flex.large
- **Cost:** ~$50/month (1 instance)
- **EKS Cluster:** $73/month
- **Total:** ~$123/month

**Recommendation:** Use `t3.micro` for true free tier experience.

---

## 📋 Prerequisites

```bash
# 1. Install tools (same as before)
aws --version
kubectl version --client
eksctl version
helm version --short
git --version

# 2. Configure AWS
aws configure
aws sts get-caller-identity
```

---

## 🚀 Step-by-Step Deployment (Free Tier - 1 Replica)

### Step 1: Create EKS Cluster (15-20 min)

**For FREE TIER:**
```bash
# Set environment variables
export CLUSTER_NAME="house-price-predictor-eks"
export REGION="us-east-1"
export NODEGROUP_NAME="app-nodegroup"
export NODE_COUNT="1"
export INSTANCE_TYPE="t3.micro"  # FREE TIER

# Create cluster
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --nodegroup-name $NODEGROUP_NAME \
  --nodes $NODE_COUNT \
  --node-type $INSTANCE_TYPE \
  --managed \
  --enable-ssm \
  --with-oidc \
  --zones ${REGION}a,${REGION}b

echo "Cluster creation started... (takes 15-20 minutes)"
```

**Alternative for m7i-flex.large:**
```bash
export INSTANCE_TYPE="m7i-flex.large"
# Same eksctl command as above
```

### Step 2: Update kubeconfig (5 min)

```bash
# Update kubeconfig to connect to cluster
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $REGION

# Verify connection
kubectl cluster-info
kubectl get nodes

# Expected: 1 node running
```

### Step 3: Install Metrics Server (3 min)

```bash
# Install Metrics Server for monitoring
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get deployment metrics-server -n kube-system
```

### Step 4: Install AWS Load Balancer Controller (5 min)

```bash
# Add Helm repo
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

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Step 5: Deploy Application (1 replica) (3 min)

```bash
# Deploy application with minimal resources
kubectl apply -f deployment/kubernetes/app-deployment-minimal.yaml

# Verify deployment
kubectl get all -n house-price-predictor
kubectl get pods -n house-price-predictor -w

# Wait for pods to be Running
```

### Step 6: Get API Endpoint (2-3 min wait)

```bash
# Get LoadBalancer external IP (may take 2-3 minutes)
kubectl get svc api-service-lb -n house-price-predictor -w

# Once EXTERNAL-IP appears, save it
export API_ENDPOINT=$(kubectl get svc api-service-lb -n house-price-predictor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "API is running at: http://$API_ENDPOINT/docs"
```

### Step 7: Test API

```bash
# Health check
curl http://$API_ENDPOINT/health

# Expected response:
# {"status":"healthy","model_loaded":true}

# Test prediction
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
```

### Step 8 (Optional): Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get ArgoCD password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Port forward to access ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access at: https://localhost:8080
# Username: admin
# Password: <from above>
```

### Step 9 (Optional): Install Monitoring

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus (minimal)
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --wait

# Install Grafana (minimal)
helm install grafana grafana/grafana \
  -n monitoring \
  --set service.type=LoadBalancer \
  --set persistence.enabled=false \
  --wait

# Get Grafana IP
kubectl get svc grafana -n monitoring

# Get Grafana password
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

---

## 📊 Total Deployment Time

| Step | Time |
|------|------|
| 1. Create EKS cluster | 15-20 min |
| 2. Update kubeconfig | 1 min |
| 3. Metrics Server | 1 min |
| 4. Load Balancer Controller | 3 min |
| 5. Deploy application | 2 min |
| 6. Get endpoint | 3 min |
| 7. Test API | 1 min |
| **Total** | **~26-31 min** |

---

## 💰 Cost Comparison

### Free Tier (t3.micro)
```
EKS Cluster:        $73/month
EC2 (t3.micro):     $0-15/month (or free first 12 months)
Load Balancer:      $16/month
Storage:            $0.50/month
─────────────────────────────
Total:              ~$90-104/month (or ~$90/month first year)
```

### m7i-flex.large (NOT free tier)
```
EKS Cluster:        $73/month
EC2 (m7i-flex.large):  $50/month
Load Balancer:      $16/month
Storage:            $0.50/month
─────────────────────────────
Total:              ~$140/month
```

---

## ✅ Verification Checklist

```bash
# ✅ Check cluster
kubectl cluster-info
kubectl get nodes

# ✅ Check application
kubectl get pods -n house-price-predictor
kubectl get svc -n house-price-predictor

# ✅ Check pod resources
kubectl top nodes
kubectl describe pod -n house-price-predictor <pod-name>

# ✅ Get API endpoint
kubectl get svc api-service-lb -n house-price-predictor
```

---

## 🔍 Monitor Resource Usage

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -n house-price-predictor

# Expected for t3.micro:
# - Total CPU: 1000m (1 core)
# - Total RAM: 1024Mi (1GB)
# - After deployment: ~30% CPU, ~60% RAM used
```

---

## 🚨 Troubleshooting

### Issue: Pods stuck in Pending

```bash
# Check why pod is pending
kubectl describe pod -n house-price-predictor <pod-name>

# Usually due to:
# 1. Insufficient CPU/memory
# 2. Node not ready yet
# 3. Image pull issues

# Solution: Give it more time or add another node
eksctl scale nodegroup --cluster=$CLUSTER_NAME --nodes=2 --region=$REGION
```

### Issue: LoadBalancer IP not showing

```bash
# Wait a bit longer (takes 2-3 minutes for AWS ALB creation)
kubectl get svc api-service-lb -n house-price-predictor -w

# Check ALB controller logs if still not appearing
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Issue: Out of Memory errors

```bash
# If t3.micro runs out of memory, scale up
eksctl scale nodegroup --cluster=$CLUSTER_NAME \
  --nodes=1 \
  --nodes-max=2 \
  --region=$REGION

# Or change instance type (stop deployment first)
# Better: Use t3.small or m7i-flex.large
```

---

## 📝 Next Steps

1. **Deploy Application** - Follow steps 1-7 above
2. **Configure GitOps** (optional) - Use Step 8
3. **Set up Monitoring** (optional) - Use Step 9
4. **Commit to Git**
   ```bash
   git add deployment/kubernetes/app-deployment-minimal.yaml
   git commit -m "Deploy with 1 replica on free tier"
   git push origin main
   ```

---

## 🧹 Cleanup (Save Costs)

When done, delete the cluster:

```bash
# Delete application
kubectl delete -f deployment/kubernetes/app-deployment-minimal.yaml

# Delete ArgoCD (if installed)
kubectl delete namespace argocd

# Delete monitoring (if installed)
kubectl delete namespace monitoring

# Delete EKS cluster (DELETES EVERYTHING - takes 10-15 min)
eksctl delete cluster \
  --name $CLUSTER_NAME \
  --region $REGION
```

**Warning:** This will delete all resources. Make sure to backup any data first!

---

## 💡 Performance Expectations (t3.micro)

| Metric | Expected |
|--------|----------|
| Max concurrent requests | 5-10 |
| Avg response time | 200-500ms |
| CPU usage | 50-80% under load |
| Memory usage | 70-90% under load |
| Model prediction latency | 100-200ms |

**Recommendation:** If you need better performance, upgrade to m7i-flex.large or add more nodes.

---

## 🎯 Summary

**Free Tier Setup (t3.micro):**
- ✅ 1 node, 1 replica
- ✅ Cost: ~$90/month (cheaper options available)
- ✅ Deployment time: ~30 min
- ✅ Good for testing/learning

**m7i-flex.large Setup:**
- ✅ Better performance
- ✅ Cost: ~$140/month
- ✅ Same deployment process
- ✅ Better for production

Choose based on your needs!
