# 🚀 AWS Free Tier Deployment - Step by Step (1 Replica)

**For 1 replica with minimal resources on free tier (t3.micro) or m7i-flex.large**

---

## ⚡ Quick Start (FASTEST - 5 min command)

If you want to deploy immediately with one command:

```bash
cd deployment/kubernetes
./quick-deploy-free-tier.sh
```

The script will:
1. ✅ Ask which instance type you want
2. ✅ Create EKS cluster (15-20 min automated)
3. ✅ Deploy 1 API replica + 1 Model replica
4. ✅ Setup LoadBalancer
5. ✅ Give you the access URL

---

## 📋 Step-by-Step Manual Deployment (If you prefer to do it manually)

### **Step 1: Setup Environment Variables** (1 min)

Open your terminal and run:

```bash
# Set configuration
export CLUSTER_NAME="house-price-predictor-eks"
export REGION="us-east-1"
export NODEGROUP_NAME="app-nodegroup"
export NODE_COUNT="1"

# Choose instance type:
# Option A: FREE TIER (Recommended)
export INSTANCE_TYPE="t3.micro"

# Option B: Better performance but NOT free tier
# export INSTANCE_TYPE="m7i-flex.large"
```

---

### **Step 2: Create EKS Cluster** (15-20 min)

This is the longest step. Run:

```bash
# Create the cluster
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

# You'll see lots of output, just wait for "✓ EKS cluster resources...created!"
```

**Expected output when done:**
```
✓ EKS cluster 'house-price-predictor-eks' in 'us-east-1' created
✓ Created 1 node group(s) in cluster
✓ Cluster created successfully!
```

---

### **Step 3: Setup kubectl Connection** (1 min)

```bash
# Connect kubectl to your cluster
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $REGION

# Verify connection
kubectl cluster-info
kubectl get nodes

# Expected: Shows 1 node (if t3.micro) or 1 node (if m7i-flex.large)
```

---

### **Step 4: Install Metrics Server** (2 min)

```bash
# Install for monitoring
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get deployment metrics-server -n kube-system
# Should show: 1/1 Running
```

---

### **Step 5: Install AWS Load Balancer Controller** (5 min)

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

# Install the controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
# Should show: 1/1 Running
```

---

### **Step 6: Deploy Application (1 Replica)** (2 min)

```bash
# Deploy with minimal resources (1 replica)
kubectl apply -f deployment/kubernetes/app-deployment-minimal.yaml

# Verify deployment
kubectl get all -n house-price-predictor

# Expected output:
# NAME                                 READY   STATUS
# pod/api-service-xxx                  1/1     Running
# pod/model-service-xxx                1/1     Running
```

---

### **Step 7: Wait for LoadBalancer IP** (2-3 min)

```bash
# Watch for external IP (wait 2-3 minutes)
kubectl get svc api-service-lb -n house-price-predictor -w

# You'll see something like:
# NAME              TYPE          EXTERNAL-IP    PORT
# api-service-lb    LoadBalancer  pending...     80
# (After 2-3 min)
# api-service-lb    LoadBalancer  abc123.elb...  80

# Save the external IP
export API_IP=$(kubectl get svc api-service-lb -n house-price-predictor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "API is at: http://$API_IP/docs"
```

---

### **Step 8: Test the API** (1 min)

```bash
# 1. Test health endpoint
curl http://$API_IP/health

# Expected response:
# {"status":"healthy","model_loaded":true}

# 2. Open in browser (Swagger UI)
echo "http://$API_IP/docs"
# Open this URL in your browser

# 3. Test a prediction (optional)
curl -X POST http://$API_IP/predict \
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

# Expected: A prediction with price estimate
```

---

## 📊 Total Deployment Time

| Step | Time | Command |
|------|------|---------|
| 1. Set variables | 1 min | `export ...` |
| 2. Create cluster | 15-20 min | `eksctl create cluster ...` |
| 3. Setup kubectl | 1 min | `aws eks update-kubeconfig ...` |
| 4. Metrics Server | 2 min | `kubectl apply ...` |
| 5. Load Balancer | 5 min | `helm install ...` |
| 6. Deploy app | 2 min | `kubectl apply -f app-deployment-minimal.yaml` |
| 7. Wait for IP | 2-3 min | `kubectl get svc ... -w` |
| 8. Test | 1 min | `curl ...` |
| **TOTAL** | **28-35 min** | |

---

## 💰 Cost Breakdown

### FREE TIER (t3.micro) - RECOMMENDED
```
EKS Cluster:        $73/month
EC2 (t3.micro):     Free (first 12 months) or $0/month
Load Balancer:      $16/month
Storage:            $0.50/month
────────────────────────────────
Total:              $89.50/month first year
                    (Free tier clients)
```

### m7i-flex.large (Better Performance)
```
EKS Cluster:        $73/month
EC2 (m7i-flex.large):  $50/month
Load Balancer:      $16/month
Storage:            $0.50/month
────────────────────────────────
Total:              $139.50/month
```

**Savings with free tier:** ~$50/month for first year!

---

## ✅ Verification Checklist

After deployment, verify:

```bash
# ✅ Check cluster is running
kubectl cluster-info
kubectl get nodes

# ✅ Check application pods
kubectl get pods -n house-price-predictor

# ✅ Check services
kubectl get svc -n house-price-predictor

# ✅ Check resource usage (should be low)
kubectl top nodes
kubectl top pods -n house-price-predictor

# ✅ Test API health
curl http://$API_IP/health

# ✅ Get Swagger UI
echo "Open browser: http://$API_IP/docs"
```

---

## 🔍 Monitor Deployment Logs

If something goes wrong, check logs:

```bash
# API service logs
kubectl logs -n house-price-predictor -l app=api-service -f

# Model service logs
kubectl logs -n house-price-predictor -l app=model-service -f

# Pod details if not running
kubectl describe pod -n house-price-predictor <pod-name>

# Check events
kubectl get events -n house-price-predictor --sort-by='.lastTimestamp'
```

---

## 📈 Monitor Resource Usage

Since we're on 1 small instance:

```bash
# Check node resources
kubectl top nodes

# Results should show:
# NAME                          CPU(cores)   MEMORY(bytes)
# ip-10-0-x-x.ec2.internal     150m         600Mi (out of 1000m / 1024Mi)

# Check pod usage
kubectl top pods -n house-price-predictor

# If usage is high (>80% on t3.micro), the node is stressed
# Solution: Upgrade to m7i-flex.large or add another node
```

---

## 🚨 Troubleshooting

### Problem: Pods stuck in Pending state

```bash
# Check why
kubectl describe pod -n house-price-predictor <pod-name>

# Common reasons:
# 1. Insufficient resources (t3.micro is limited)
# 2. Node not ready yet (wait a few minutes)
# 3. Image pull issues (check node logs)

# Solution for t3.micro:
# - Reduce replica count (already at 1)
# - Upgrade to m7i-flex.large
# - Add another node
```

### Problem: LoadBalancer IP not appearing

```bash
# Wait a bit longer (3-5 minutes is normal)
kubectl get svc api-service-lb -n house-price-predictor -w

# If still pending after 5 minutes:
# Check Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
```

### Problem: Out of memory errors on t3.micro

```bash
# If you see "OOM Killed" errors:
# The 1GB RAM might not be enough under load

# Solution options:
# 1. Upgrade to m7i-flex.large (recommended)
# 2. Add another t3.micro node
# 3. Reduce resource requests in manifest

# To upgrade instance (delete node and create new one):
eksctl delete nodegroup --cluster=$CLUSTER_NAME --name=$NODEGROUP_NAME --region=$REGION
eksctl create nodegroup \
  --cluster=$CLUSTER_NAME \
  --name=app-nodegroup-large \
  --nodes=1 \
  --node-type=m7i-flex.large \
  --region=$REGION
```

### Problem: Cannot authenticate with AWS

```bash
# Verify credentials
aws sts get-caller-identity

# If failing, reconfigure
aws configure

# Enter your:
# AWS Access Key ID
# AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

---

## 🔧 Useful Commands

```bash
# Get API endpoint anytime
kubectl get svc api-service-lb -n house-price-predictor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# View all resources
kubectl get all -n house-price-predictor

# Watch pods
kubectl get pods -n house-price-predictor -w

# Check pod status
kubectl describe pod -n house-price-predictor <pod-name>

# View pod logs
kubectl logs -n house-price-predictor -l app=api-service

# SSH into a pod (for debugging)
kubectl exec -it -n house-price-predictor <pod-name> -- /bin/bash

# Delete and redeploy
kubectl delete -f deployment/kubernetes/app-deployment-minimal.yaml
kubectl apply -f deployment/kubernetes/app-deployment-minimal.yaml
```

---

## 🧹 When Done: Cleanup & Delete Resources

**⚠️ WARNING: This will delete everything and stop charges!**

```bash
# 1. Delete application
kubectl delete -f deployment/kubernetes/app-deployment-minimal.yaml

# 2. Delete EKS cluster (takes 10-15 minutes)
eksctl delete cluster \
  --name $CLUSTER_NAME \
  --region $REGION

# This will:
# - Delete all pods
# - Delete all services & load balancers
# - Delete EC2 instances
# - Delete VPC and networking
# - Stop all AWS charges
```

---

## 📝 Optional: Save Configuration

To reuse the same setup, save your settings:

```bash
# Create a file: eks-setup.sh
cat > eks-setup.sh << 'EOF'
#!/bin/bash
export CLUSTER_NAME="house-price-predictor-eks"
export REGION="us-east-1"
export NODEGROUP_NAME="app-nodegroup"
export NODE_COUNT="1"
export INSTANCE_TYPE="t3.micro"  # or m7i-flex.large
EOF

# Use it in future sessions
source eks-setup.sh
```

---

## 🎯 Summary

| What | When | Command |
|------|------|---------|
| **Deploy (automated)** | NOW | `./quick-deploy-free-tier.sh` |
| **Deploy (manual)** | If you prefer | Follow steps 1-8 above |
| **Check status** | Anytime | `kubectl get all -n house-price-predictor` |
| **Get API URL** | After step 7 | `kubectl get svc api-service-lb -n house-price-predictor` |
| **View logs** | If issues | `kubectl logs -n house-price-predictor ...` |
| **Delete** | When done | `eksctl delete cluster ...` |

---

## 🚀 You're Ready!

Choose your path:

### **OPTION 1: Use Automated Script (Easiest)**
```bash
cd deployment/kubernetes
./quick-deploy-free-tier.sh
```

### **OPTION 2: Manual Steps (Learn more)**
Follow steps 1-8 above

### **OPTION 3: Existing EKS Cluster (Fastest)**
```bash
kubectl apply -f deployment/kubernetes/app-deployment-minimal.yaml
```

---

**Happy Deploying! 🎉**

**Expected total time: 28-35 minutes**
