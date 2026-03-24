# 📌 AWS Free Tier Deployment - QUICK SUMMARY

## 🎯 What You Need to Know

**You asked for:** AWS free tier with 1 replica using m7i-flex.large (or cheaper option)

**What I created:**
- ✅ Free tier deployment with 1 replica (minimal resources)
- ✅ Option for t3.micro (actual free tier) or m7i-flex.large
- ✅ Auto-deployment script with just one command
- ✅ Step-by-step manual guide
- ✅ Cost breakdown

---

## 🚀 Deploy in 3 Easy Ways

### **Method 1: ONE COMMAND (Easiest)**
```bash
cd /home/ec2-user/house-price-predictor/deployment/kubernetes
./quick-deploy-free-tier.sh
```
⏱️ Time: ~30 min (automated)
✅ Recommended for beginners

---

### **Method 2: Step-by-Step (Learn & Control)**
See: **FREE-TIER-QUICK-START.md**
```bash
cat deployment/kubernetes/FREE-TIER-QUICK-START.md
```
⏱️ Time: ~30 min
✅ Recommended for learning

---

### **Method 3: Manual Commands (Advanced)**
```bash
# Step 1: Set variables
export CLUSTER_NAME="house-price-predictor-eks"
export REGION="us-east-1"
export INSTANCE_TYPE="t3.micro"  # or m7i-flex.large

# Step 2: Create cluster
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --nodes 1 \
  --node-type $INSTANCE_TYPE \
  --managed \
  --with-oidc

# Continue with remaining steps...
```

---

## 📊 Instance Type Comparison

| Feature | t3.micro (FREE) | m7i-flex.large |
|---------|-----------------|----------------|
| **Cost/month** | Free* or $0 | $50 |
| **CPU cores** | 1 (burstable) | 2 |
| **Memory** | 1 GB | 16 GB |
| **Network** | Low | High |
| **Best for** | Testing/Demo | Production |
| **Free Tier** | ✅ Yes (12 mo) | ❌ No |
| **Recommended** | ✅ YES | 💪 Better perf |

*Free tier eligible for first 12 months

---

## 💰 Total Monthly Cost

```
┌──────────────────────────────────────┐
│  EKS FREE TIER COST BREAKDOWN        │
├──────────────────────────────────────┤
│ EKS Cluster              $73.00/mo   │
│ Compute (t3.micro)       $0.00/mo*   │
│ Load Balancer            $16.00/mo   │
│ Storage                  $0.50/mo    │
│ ────────────────────────────────     │
│ TOTAL                    $89.50/mo*  │
│ * First 12 months with free tier    │
│   After: ~$104.50/mo                │
└──────────────────────────────────────┘

COMPARISON:
m7i-flex.large setup = ~$140/mo
Savings = $50/mo with free tier!
```

---

## 📁 New Files Created

| File | Purpose |
|------|---------|
| **free-tier-quick-start.sh** | Auto-deploy script |
| **quick-deploy-free-tier.sh** | Automated script (executable) |
| **app-deployment-minimal.yaml** | K8s manifest (1 replica) |
| **FREE-TIER-QUICK-START.md** | Step-by-step guide |
| **FREE-TIER-DEPLOYMENT.md** | Detailed reference |

---

## ⏱️ Timeline

```
Time          Action
─────────────────────────────────────────
0: 00-0:05    Read this file & choose method
0: 05-0:25    Create EKS cluster (automated, you wait)
0: 25-0:30    Setup & deploy application
0: 30-0:33    Wait for LoadBalancer IP
0: 33         Get API URL & test
─────────────────────────────────────────
Total:        ~33 minutes
```

---

## 🎯 Next Steps (Choose One)

### IF YOU WANT SPEED:
```bash
./quick-deploy-free-tier.sh
```
Just run command, follow prompts, sit back and wait!

### IF YOU WANT TO LEARN:
```bash
cat deployment/kubernetes/FREE-TIER-QUICK-START.md
# Read and follow each step manually
```

### IF YOU WANT DETAILS:
```bash
cat deployment/kubernetes/FREE-TIER-DEPLOYMENT.md
# More detailed information & options
```

---

## 📋 What Gets Deployed

```
┌─────────────────────────────────────────┐
│  EKS Cluster (1 Node - t3.micro)       │
├─────────────────────────────────────────┤
│  ✅ API Service         (1 replica)     │
│  ✅ Model Service       (1 replica)     │
│  ✅ LoadBalancer        (Public IP)     │
│  ✅ Health checks       (Active)        │
│  ✅ Resource limits     (Optimized)     │
│                                         │
│  ✅ AWS Load Balancer   (ALB)          │
│  ✅ Metrics Server      (Monitoring)    │
│  ✅ Auto-scaling        (Disabled - 1) │
└─────────────────────────────────────────┘
```

---

## 🔗 File Locations

All files are in:
```
/home/ec2-user/house-price-predictor/deployment/kubernetes/
│
├── quick-deploy-free-tier.sh ← RUN THIS
├── FREE-TIER-QUICK-START.md ← READ THIS
├── FREE-TIER-DEPLOYMENT.md
├── app-deployment-minimal.yaml
│
├── (other files from previous setup)
│
└── ... (other documentation)
```

---

## ✅ Check Before Starting

```bash
# Verify you have all required tools
aws --version
kubectl version --client
eksctl version
helm version --short

# Verify AWS credentials
aws sts get-caller-identity

# Get to correct directory
cd /home/ec2-user/house-price-predictor
```

---

## 🚀 START HERE

### OPTION A: Automated (Recommended for most people)
```bash
cd deployment/kubernetes
chmod +x quick-deploy-free-tier.sh
./quick-deploy-free-tier.sh
```

### OPTION B: Step-by-Step (Recommended for learning)
```bash
cat deployment/kubernetes/FREE-TIER-QUICK-START.md
# Follow steps 1-8
```

### OPTION C: Using existing cluster (Fastest)
```bash
kubectl apply -f deployment/kubernetes/app-deployment-minimal.yaml
kubectl get svc -n house-price-predictor
```

---

## 💡 Pro Tips

**Tip 1: Save your variables**
```bash
# Create a script to reuse settings
cat > ~/.eks-setup << 'EOF'
export CLUSTER_NAME="house-price-predictor-eks"
export REGION="us-east-1"
export INSTANCE_TYPE="t3.micro"
EOF

source ~/.eks-setup
```

**Tip 2: Monitor resource usage**
```bash
# Check if t3.micro is enough
watch kubectl top nodes
watch kubectl top pods -n house-price-predictor
```

**Tip 3: Get costs breakdown**
```bash
# Use AWS pricing calculator
# https://calculator.aws/#/
# Search for t3.micro, EKS, ALB
```

---

## 🆘 If Something Goes Wrong

```bash
# Check cluster status
eksctl get cluster --region us-east-1

# Check pod status
kubectl get pods -n house-price-predictor

# See what went wrong
kubectl describe pod -n house-price-predictor <pod-name>

# Check logs
kubectl logs -n house-price-predictor -l app=api-service

# Still stuck? Read the detailed guide
cat deployment/kubernetes/FREE-TIER-DEPLOYMENT.md
```

---

## 🧹 When Done: Delete Everything

```bash
# Delete resources to stop charges
eksctl delete cluster \
  --name house-price-predictor-eks \
  --region us-east-1

# Confirm deletion
eksctl get cluster --region us-east-1
```

---

## 📊 End Result (After Deployment)

```
✅ 1 working EKS cluster
✅ 1 API service running on LoadBalancer
✅ 1 Model service running internally
✅ Public URL to access API (http://<IP>/docs)
✅ Costs: ~$90/mo with free tier
✅ Total time: ~35 minutes
```

---

## 🎉 YOU'RE READY!

Everything is prepared. Just choose your deployment method and run it.

**Most people should:**
```bash
cd deployment/kubernetes
./quick-deploy-free-tier.sh
```

**Done! 🚀**

---

## 📚 Documentation Files

- **FREE-TIER-QUICK-START.md** ← Step-by-step (READ THIS)
- **FREE-TIER-DEPLOYMENT.md** ← Detailed info
- **app-deployment-minimal.yaml** ← K8s manifest
- **quick-deploy-free-tier.sh** ← Automated script

---

**Questions? Check the detailed guides above.**

**Ready to deploy? Run the script!**
