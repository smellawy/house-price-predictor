# 📋 AWS EKS Deployment Package - Complete Index

Complete solution for deploying House Price Predictor to AWS EKS with GitOps and monitoring.

## 📁 File Structure

```
deployment/kubernetes/
├── 📄 GETTING-STARTED.md                ← START HERE! Quick overview & checklist
├── 📄 COMPLETE-DEPLOYMENT-GUIDE.md      ← Full end-to-end walkthrough
├── 📄 EKS-SETUP.md                      ← EKS cluster creation & configuration
├── 📄 ARGOCD-SETUP.md                   ← GitOps with ArgoCD
├── 📄 GRAFANA-SETUP.md                  ← Monitoring with Prometheus & Grafana
├── 🤖 quick-deploy.sh                   ← One-command automated deployment
├── ⚙️  app-deployment.yaml              ← Complete Kubernetes manifests
└── 📄 README.md                         ← Overview of all files
```

---

## 🎯 Quick Navigation

### I want to... 

**Deploy the application quickly**
→ Run `./quick-deploy.sh` (fully automated)
→ Or read [GETTING-STARTED.md](./GETTING-STARTED.md)

**Understand the full process**
→ Read [COMPLETE-DEPLOYMENT-GUIDE.md](./COMPLETE-DEPLOYMENT-GUIDE.md)

**Set up EKS cluster**
→ Follow [EKS-SETUP.md](./EKS-SETUP.md)

**Configure GitOps**
→ Follow [ARGOCD-SETUP.md](./ARGOCD-SETUP.md)

**Set up monitoring**
→ Follow [GRAFANA-SETUP.md](./GRAFANA-SETUP.md)

**Fix a problem**
→ Check troubleshooting in the relevant guide

---

## 📚 Documentation Reference

### [GETTING-STARTED.md](./GETTING-STARTED.md)
**Quick reference guide (15 min read)**
- What's included
- 3 deployment methods
- Verification checklist
- Common tasks
- Cost estimation
- **Status:** ✅ Use this first!

### [COMPLETE-DEPLOYMENT-GUIDE.md](./COMPLETE-DEPLOYMENT-GUIDE.md)
**Full end-to-end guide (1-1.5 hours to follow)**

**Contents:**
- Prerequisites installation
- Phase 1: EKS Cluster Setup (Steps 1.1-1.5)
- Phase 2: Deploy Application (Steps 2.1-2.5)
- Phase 3: Git Repository Setup (Steps 3.1-3.2)
- Phase 4: ArgoCD GitOps (Steps 4.1-4.6)
- Phase 5: Grafana Monitoring (Steps 5.1-5.6)
- Phase 6: Verification & Testing (Steps 6.1-6.4)
- Troubleshooting section
- Cleanup procedures

**Status:** ✅ Most comprehensive guide

### [EKS-SETUP.md](./EKS-SETUP.md)
**EKS cluster creation and configuration (30-45 min)**

**Contents:**
- Prerequisites
- Step 1-2: Create cluster using eksctl
- Step 3-4: Install add-ons (metrics server, aws-load-balancer-controller, ebs-csi-driver)
- Step 5-6: Verification and access
- Step 7-9: Deploy application and access endpoints
- Troubleshooting
- Cost optimization tips
- Security best practices

**Status:** ✅ All EKS operations covered

### [ARGOCD-SETUP.md](./ARGOCD-SETUP.md)
**GitOps configuration with ArgoCD (30-40 min)**

**Contents:**
- Step 1: Install ArgoCD
- Step 2: Access ArgoCD UI and get password
- Step 3: Expose via LoadBalancer (optional)
- Step 4: Add GitHub repository
- Step 5: Create GitOps repository structure
- Step 6: Deploy via ArgoCD
- Step 7: Notifications setup
- Step 8: Automatic image updates
- Step 9: GitOps workflow explanation
- Step 10: Advanced RBAC configuration
- Troubleshooting

**Status:** ✅ Full GitOps workflow covered

### [GRAFANA-SETUP.md](./GRAFANA-SETUP.md)
**Monitoring with Prometheus & Grafana (30-40 min)**

**Contents:**
- Step 1: Install Prometheus
- Step 2: Install Grafana
- Step 3: Access Grafana UI
- Step 4: Create ServiceMonitor
- Step 5: Create PrometheusRule for alerts
- Step 6: Configure AlertManager
- Step 7: Import dashboards
- Step 8: EBS storage class
- Step 9: Port forwarding
- Step 10: CloudWatch Container Insights
- Step 11: Best practices
- Troubleshooting

**Status:** ✅ Complete monitoring setup covered

---

## 🤖 Automation Files

### [quick-deploy.sh](./quick-deploy.sh)
**One-command automated deployment (15-20 min execution)**

**What it does:**
1. ✅ Checks all prerequisites
2. ✅ Verifies AWS credentials
3. ✅ Creates EKS cluster
4. ✅ Sets up kubeconfig
5. ✅ Installs metrics server
6. ✅ Installs AWS Load Balancer Controller
7. ✅ Deploys application
8. ✅ Installs ArgoCD
9. ✅ Installs Prometheus & Grafana
10. ✅ Shows next steps

**How to use:**
```bash
cd deployment/kubernetes
chmod +x quick-deploy.sh
./quick-deploy.sh
```

**Status:** ✅ Production-ready automation

---

## ⚙️ Manifest Files

### [app-deployment.yaml](./app-deployment.yaml)
**Complete Kubernetes deployment manifests**

**Includes:**
- Namespace: `house-price-predictor`
- ConfigMap: `api-config`
- Deployments:
  - `model-service` (2 replicas)
  - `api-service` (3 replicas)
- Services:
  - `model-service` (ClusterIP)
  - `api-service` (ClusterIP)
  - `api-service-lb` (LoadBalancer)
- HorizontalPodAutoscalers:
  - `model-service-hpa` (2-5 replicas)
  - `api-service-hpa` (3-10 replicas)
- NetworkPolicy: `allow-api-to-model`

**Features:**
- ✅ Health checks (liveness & readiness probes)
- ✅ Resource limits and requests
- ✅ Pod anti-affinity for high availability
- ✅ Auto-scaling based on CPU/memory
- ✅ Network policies for security
- ✅ Prometheus annotations for monitoring

**Status:** ✅ Production-ready manifests

---

## 📊 What Gets Deployed

### Components

```
AWS EKS Cluster
├── Node Group (3x t3.medium instances)
├── house-price-predictor Namespace
│   ├── API Service (3 pods)
│   ├── Model Service (2 pods)
│   ├── ConfigMap
│   ├── LoadBalancer Service
│   ├── HPA (Auto-scaling)
│   └── Network Policies
├── argocd Namespace
│   ├── ArgoCD Server
│   ├── Repo Server
│   └── Application Controller
├── monitoring Namespace
│   ├── Prometheus
│   ├── Grafana
│   ├── AlertManager
│   └── Node Exporter
└── kube-system Namespace
    ├── Metrics Server
    ├── AWS Load Balancer Controller
    └── CoreDNS
```

### Services Exposed

| Service | Type | Port | Access Method |
|---------|------|------|----------------|
| API | LoadBalancer | 80 | External IP |
| ArgoCD | ClusterIP | 443 | Port-forward |
| Grafana | LoadBalancer | 3000 | External IP |
| Prometheus | ClusterIP | 9090 | Port-forward |

---

## 🚀 Deployment Flow

```
1. Prerequisites Check
   ↓
2. Create EKS Cluster (15-20 min)
   ↓
3. Deploy Kubernetes Manifests
   ↓
4. Install ArgoCD for GitOps
   ↓
5. Install Prometheus & Grafana
   ↓
6. Verify All Components
   ↓
7. Access Applications
   ├─ API: http://<LoadBalancer-IP>/docs
   ├─ Grafana: http://<LoadBalancer-IP>:3000
   └─ ArgoCD: https://localhost:8080 (port-forward)
```

---

## 📊 Estimated Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Prerequisites | 10 min | Install tools, AWS config |
| EKS Setup | 20 min | Cluster creation, add-ons |
| App Deployment | 5 min | Deploy manifests |
| ArgoCD Setup | 5 min | Install ArgoCD |
| Monitoring Setup | 5 min | Install Prometheus & Grafana |
| Verification | 5 min | Test endpoints |
| **Total** | **50 min** | Full deployment |

---

## 🎓 Learning Path

### Beginner (Just Deploy)
1. Read [GETTING-STARTED.md](./GETTING-STARTED.md)
2. Run `./quick-deploy.sh`
3. Verify endpoints work

### Intermediate (Understand)
1. Read [COMPLETE-DEPLOYMENT-GUIDE.md](./COMPLETE-DEPLOYMENT-GUIDE.md)
2. Follow step-by-step manually
3. Modify configuration as needed

### Advanced (Customize)
1. Study [EKS-SETUP.md](./EKS-SETUP.md) for cluster options
2. Use [ARGOCD-SETUP.md](./ARGOCD-SETUP.md) for advanced GitOps
3. Create custom dashboards in [GRAFANA-SETUP.md](./GRAFANA-SETUP.md)

---

## 🔒 Security Features

✅ Network policies restricting pod-to-pod traffic
✅ Resource limits preventing DoS
✅ Health checks ensuring availability
✅ RBAC for access control
✅ TLS for external communication
✅ IAM roles for service accounts (IRSA)
✅ Pod security standards
✅ Regular health monitoring

---

## 💰 Cost Breakdown

**Monthly Costs (us-east-1):**
- EKS Cluster: $73
- Compute (3x t3.medium): $75
- Load Balancer (ALB): $20
- Storage: $1
- **Total: ~$169/month**

**Optimization Options:**
- Use Spot Instances for 70% cost reduction
- Use Reserved Instances for 30-50% cost reduction
- Schedule non-production clusters

---

## ✅ Pre-Requisite Checklist

Before starting, ensure:

- [ ] AWS Account with IAM permissions
- [ ] AWS CLI v2 installed and configured
- [ ] kubectl installed
- [ ] eksctl installed
- [ ] Helm 3 installed
- [ ] Git installed
- [ ] GitHub account with repository access
- [ ] Docker images pulled to Docker Hub:
  - [ ] mohamedadel9988/house-pricemodel:latest
  - [ ] mohamedadel9988/fastapi:b89009d7291fcfc20f4ce57d8a9fb472472523eb

**Verification:**
```bash
aws --version
kubectl version --client
eksctl version
helm version --short
git --version
```

---

## 🐛 Troubleshooting Quick Links

| Issue | Solution |
|-------|----------|
| Pod stuck in pending | → EKS-SETUP.md#troubleshooting |
| Cannot access API | → COMPLETE-DEPLOYMENT-GUIDE.md#troubleshooting |
| ArgoCD not syncing | → ARGOCD-SETUP.md#troubleshooting |
| Grafana not showing metrics | → GRAFANA-SETUP.md#troubleshooting |
| Cluster creation failed | → EKS-SETUP.md#troubleshooting |
| Pods keep restarting | → Check pod logs: `kubectl logs -n <namespace> <pod>` |

---

## 📞 Support Resources

**Official Documentation:**
- AWS EKS: https://docs.aws.amazon.com/eks/
- Kubernetes: https://kubernetes.io/docs/
- ArgoCD: https://argo-cd.readthedocs.io/
- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/

**Community:**
- Kubernetes Slack: https://kubernetes.slack.com/
- AWS Forums: https://forums.aws.amazon.com/
- ArgoCD Community: https://github.com/argoproj/argo-cd/discussions

---

## 🎯 Next Steps After Deployment

1. **Commit to GitHub** - Push all manifests to your repository
2. **Configure Webhooks** - Auto-sync from GitHub on changes
3. **Create Dashboards** - Build custom Grafana dashboards
4. **Set up Alerts** - Configure Slack/Email notifications
5. **Performance Testing** - Load test the API
6. **Backup Strategy** - Implement EBS snapshots
7. **CI/CD Pipeline** - Integrate with your build system
8. **Cost Optimization** - Review and optimize AWS usage

---

## 📋 Checklist After Deployment

- [ ] API is accessible at http://<IP>/docs
- [ ] Health check passes: `curl http://<IP>/health`
- [ ] ArgoCD UI is accessible
- [ ] Grafana dashboards show metrics
- [ ] HPA is active and scaling works
- [ ] Pods are healthy and running
- [ ] Load Balancer has external IP
- [ ] Monitoring alerts are configured

---

## 🎉 Summary

You have everything needed to:
1. ✅ Create a production-grade EKS cluster
2. ✅ Deploy a scalable Kubernetes application
3. ✅ Implement GitOps with ArgoCD
4. ✅ Monitor with Prometheus & Grafana
5. ✅ Auto-scale based on metrics
6. ✅ Manage infrastructure as code

**Choose your path:**
- 🚀 Quick: Run `./quick-deploy.sh`
- 📖 Learning: Follow `COMPLETE-DEPLOYMENT-GUIDE.md`
- 🎯 Reference: Use individual guides as needed

---

**Happy Deploying! 🚀**

*For the latest version and updates, check the GitHub repository.*
