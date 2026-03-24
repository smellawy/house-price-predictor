# 🚀 AWS EKS Deployment - Getting Started Summary

This document provides a quick overview of what has been set up for deploying the House Price Predictor application to AWS EKS with GitOps and monitoring.

## 📦 What's Included

You now have a complete production-ready deployment setup with:

### 1. **Kubernetes Manifests** (`app-deployment.yaml`)
- ✅ Model Service Deployment (2 replicas)
- ✅ API Service Deployment (3 replicas)
- ✅ LoadBalancer and ClusterIP Services
- ✅ Horizontal Pod Autoscaler
- ✅ Network Policies for security
- ✅ ConfigMaps for configuration
- ✅ Health checks (liveness & readiness probes)
- ✅ Resource limits and requests

### 2. **Comprehensive Documentation**
- 📖 **COMPLETE-DEPLOYMENT-GUIDE.md** - Full end-to-end guide (READ THIS FIRST!)
- 📖 **EKS-SETUP.md** - EKS cluster creation and configuration
- 📖 **ARGOCD-SETUP.md** - GitOps setup with ArgoCD
- 📖 **GRAFANA-SETUP.md** - Monitoring with Prometheus & Grafana

### 3. **Automation Script**
- 🤖 **quick-deploy.sh** - Automated deployment script (for single-command deployment)

---

## ⚡ Quick Start (3 Methods)

### Method 1: Use Quick Deploy Script (RECOMMENDED)

```bash
cd deployment/kubernetes

# Make script executable (already done)
chmod +x quick-deploy.sh

# Run the deployment script
./quick-deploy.sh

# Follow the prompts and wait for completion
```

**Advantages:**
- Fully automated
- Error checking
- Best practices implemented
- Detailed output

---

### Method 2: Step-by-Step Manual (LEARN MODE)

Follow the **COMPLETE-DEPLOYMENT-GUIDE.md**:

```bash
# Read the complete guide
cat deployment/kubernetes/COMPLETE-DEPLOYMENT-GUIDE.md

# Follow Phase 1-5 step by step
```

---

### Method 3: Use Existing EKS Cluster

If you already have an EKS cluster:

```bash
# Update kubeconfig
aws eks update-kubeconfig --name your-cluster-name --region us-east-1

# Deploy application
kubectl apply -f deployment/kubernetes/app-deployment.yaml

# Verify
kubectl get pods -n house-price-predictor -w
```

---

## 🎯 Typical Deployment Timeline

| Step | Time | Action |
|------|------|--------|
| 1 | 5 min | Install prerequisites |
| 2 | 15-20 min | Create EKS cluster |
| 3 | 3 min | Deploy application |
| 4 | 3 min | Install ArgoCD |
| 5 | 5 min | Install monitoring |
| 6 | 2-3 min | Get endpoints |
| **Total** | **~35-40 min** | Full deployment |

---

## 📋 Deployment Checklist

After running the script or following the guide, verify:

```bash
# ✅ Check cluster
kubectl cluster-info
kubectl get nodes

# ✅ Check application
kubectl get pods -n house-price-predictor
kubectl get svc -n house-price-predictor

# ✅ Check ArgoCD
kubectl get pods -n argocd
kubectl get applications -n argocd

# ✅ Check monitoring
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# ✅ Get endpoints
kubectl get svc api-service-lb -n house-price-predictor
kubectl get svc argocd-server -n argocd
kubectl get svc grafana -n monitoring
```

---

## 🔗 Access Points

After deployment, you can access:

| Service | URL | Purpose |
|---------|-----|---------|
| **API** | `http://<API-LB-IP>/docs` | Swagger UI for testing |
| **API Health** | `http://<API-LB-IP>/health` | Health check endpoint |
| **ArgoCD** | `http://localhost:8080` (port-forward) | GitOps management |
| **Grafana** | `http://<Grafana-LB-IP>:3000` | Monitoring dashboards |
| **Prometheus** | `http://localhost:9090` (port-forward) | Metrics database |

---

## 🔑 Default Credentials

After deployment:

| Service | Username | Password | How to Get |
|---------|----------|----------|-----------|
| **ArgoCD** | admin | random | `kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |
| **Grafana** | admin | `grafana-admin-password` | Set in Helm values (see GRAFANA-SETUP.md) |

---

## 📚 Documentation Structure

```
deployment/kubernetes/
├── README.md                          # Overview of all files
├── COMPLETE-DEPLOYMENT-GUIDE.md       # Start here! Full guide
├── EKS-SETUP.md                       # EKS cluster setup
├── ARGOCD-SETUP.md                    # GitOps configuration
├── GRAFANA-SETUP.md                   # Monitoring setup
├── app-deployment.yaml                # Kubernetes manifests
├── quick-deploy.sh                    # Automated deployment
└── GETTING-STARTED.md                 # This file
```

**Read Order:**
1. This file (GETTING-STARTED.md) ← You are here
2. COMPLETE-DEPLOYMENT-GUIDE.md (full walkthrough)
3. Specific guides as needed (EKS-SETUP.md, ARGOCD-SETUP.md, etc.)

---

## 🔍 Verify Deployment

### Check API is running:

```bash
# Get the LoadBalancer IP
API_IP=$(kubectl get svc api-service-lb -n house-price-predictor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://$API_IP/health

# Expected response:
# {"status":"healthy","model_loaded":true}

# Open Swagger UI in browser:
# http://$API_IP/docs
```

### Check pods are running:

```bash
# Watch pods
kubectl get pods -n house-price-predictor -w

# Expected state: All pods Running (3 API + 2 Model)
```

### Check auto-scaling:

```bash
# View HPA status
kubectl get hpa -n house-price-predictor

# View scale ranges
# API Service: 3-10 replicas
# Model Service: 2-5 replicas
```

---

## 🚨 Troubleshooting Quick Reference

### Problem: Pods stuck in pending state

```bash
kubectl describe pod -n house-price-predictor <pod-name>
kubectl get events -n house-price-predictor
```

### Problem: LoadBalancer IP not appearing

```bash
# Wait a bit longer (AWS ALB creation takes 2-3 minutes)
kubectl get svc api-service-lb -n house-price-predictor -w
```

### Problem: Cannot connect to API

```bash
# Check if pod is running
kubectl get pods -n house-price-predictor

# Check pod logs
kubectl logs -n house-price-predictor <pod-name>

# Check service
kubectl describe svc api-service-lb -n house-price-predictor
```

### Problem: Need more help

→ See **COMPLETE-DEPLOYMENT-GUIDE.md#troubleshooting**

---

## 💡 Common Tasks

### View Application Logs

```bash
# Last 50 lines
kubectl logs -n house-price-predictor -l app=api-service --tail=50

# Stream logs (follow)
kubectl logs -n house-price-predictor -l app=api-service -f

# All pods at once
kubectl logs -n house-price-predictor --all-containers=true -f
```

### Scale Deployments

```bash
# Manual scaling
kubectl scale deployment api-service -n house-price-predictor --replicas=5

# Check HPA scaling limits
kubectl get hpa -n house-price-predictor
```

### Update Application (GitOps Way)

```bash
# 1. Edit deployment manifest
vim deployment/kubernetes/app-deployment.yaml

# 2. Commit and push (ArgoCD will auto-sync)
git add deployment/kubernetes/app-deployment.yaml
git commit -m "Update image version"
git push origin main

# 3. Check sync status
kubectl get applications -n argocd house-price-predictor
```

### Port Forward for Local Access

```bash
# Access ArgoCD locally
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access Prometheus locally
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090 &

# Access Grafana locally
kubectl port-forward svc/grafana -n monitoring 3000:3000 &
```

---

## 📊 Architecture Diagram

```
Internet
  ↓
  ├─→ LoadBalancer (AWS ALB)
       ├─→ API Service Pod 1
       ├─→ API Service Pod 2
       └─→ API Service Pod 3
            ↓
            Calls Model Service (internal)
            Model Service Pods (2+ instances)

Behind the scenes:
- ArgoCD syncs changes from GitHub every 3 minutes
- Prometheus scrapes metrics every 30 seconds
- Grafana displays dashboards from Prometheus
- AlertManager sends alerts on issues
```

---

## 🔐 Security Considerations

The deployment includes:
- ✅ Network policies restricting pod communication
- ✅ Resource limits preventing resource exhaustion
- ✅ Health checks ensuring service availability
- ✅ RBAC for access control
- ✅ TLS for external communication
- ⚠️ **TODO:** Configure secret management for sensitive data

---

## 💰 Estimated Costs (AWS)

| Component | Resource | Estimated Cost/Month |
|-----------|----------|---------------------|
| EKS Cluster | Control plane | $73 |
| EC2 Nodes | 3x t3.medium on-demand | ~$75 |
| Load Balancer | ALB | ~$20 |
| Storage | 10GB EBS for Grafana | ~$1 |
| **Total** | | **~$169/month** |

**Cost optimization:** Use spot instances for non-critical workloads to reduce by 70%.

---

## 🎓 Learning Resources

### Kubernetes
- https://kubernetes.io/docs/concepts/
- https://kubernetes.io/docs/tasks/

### AWS EKS
- https://docs.aws.amazon.com/eks/
- https://eksctl.io/

### ArgoCD & GitOps
- https://argo-cd.readthedocs.io/
- https://www.gitops.tech/

### Monitoring
- https://prometheus.io/docs/
- https://grafana.com/docs/

---

## ✅ Next Steps After Deployment

1. **Commit to Git** - Push all deployment files to your GitHub repo
2. **Configure ArgoCD** - Set up webhook from GitHub for auto-sync
3. **Create Custom Dashboards** - Build application-specific Grafana dashboards
4. **Set up Alerts** - Configure Slack/Email notifications
5. **Performance Testing** - Load test the API to verify scaling
6. **Backup Strategy** - Implement EBS snapshot backups
7. **CI/CD Integration** - Connect build pipeline to deployment
8. **Cost Optimization** - Review and optimize AWS resource usage

---

## 🆘 Need Help?

1. **Quick issues**: Check "Troubleshooting" section above
2. **Detailed help**: Read the specific guide file
3. **Full deployment walkthrough**: Follow COMPLETE-DEPLOYMENT-GUIDE.md
4. **Specific topics**:
   - EKS cluster: See EKS-SETUP.md
   - GitOps: See ARGOCD-SETUP.md
   - Monitoring: See GRAFANA-SETUP.md

---

## 🎯 Summary

| What | How | Where |
|------|-----|-------|
| **Quick deploy** | Run script | `./quick-deploy.sh` |
| **Manual deploy** | Follow guide | `COMPLETE-DEPLOYMENT-GUIDE.md` |
| **API access** | Browser | `http://<API-LB-IP>/docs` |
| **Monitoring** | Browser | `http://<Grafana-LB-IP>:3000` |
| **GitOps** | Browser | `https://localhost:8080` (port-forward) |
| **Help** | Read files | `deployment/kubernetes/*.md` |

---

## 🎉 You're Ready!

You now have:
- ✅ Complete Kubernetes deployment manifest
- ✅ EKS cluster setup automation
- ✅ GitOps workflow with ArgoCD
- ✅ Monitoring with Prometheus & Grafana
- ✅ Comprehensive documentation
- ✅ Quick deployment script
- ✅ Troubleshooting guides

**Start with:** `./quick-deploy.sh` or read `COMPLETE-DEPLOYMENT-GUIDE.md`

---

**Happy deploying! 🚀**

Last updated: 2026-03-24
