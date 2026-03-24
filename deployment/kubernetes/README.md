# Kubernetes Deployment for House Price Predictor on AWS EKS

This directory contains all Kubernetes manifests, configuration files, and documentation for deploying the House Price Predictor application to AWS EKS (Elastic Kubernetes Service) using GitOps and monitoring.

## 📁 Files Structure

```
deployment/kubernetes/
├── README.md                       # This file
├── app-deployment.yaml            # Complete K8s manifests for deployment and services
├── COMPLETE-DEPLOYMENT-GUIDE.md   # Step-by-step guide for full setup
├── EKS-SETUP.md                   # EKS cluster creation and configuration
├── ARGOCD-SETUP.md                # GitOps setup with ArgoCD
└── GRAFANA-SETUP.md               # Monitoring setup with Prometheus & Grafana
```

## 🚀 Quick Start

### Prerequisites
- AWS Account with appropriate IAM permissions
- AWS CLI v2, kubectl, eksctl, and Helm 3 installed
- Docker images available on Docker Hub:
	- `mohamedadel9988/house-pricemodel:latest`
	- `mohamedadel9988/fastapi:b89009d7291fcfc20f4ce57d8a9fb472472523eb`

### Deploy in 5 Steps

```bash
# Step 1: Create EKS Cluster
export CLUSTER_NAME="house-price-predictor-eks"
export REGION="us-east-1"
eksctl create cluster \
	--name $CLUSTER_NAME \
	--region $REGION \
	--nodes 3 \
	--node-type t3.medium \
	--managed \
	--with-oidc

# Step 2: Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Step 3: Deploy Application
kubectl apply -f app-deployment.yaml

# Step 4: Get Access Point
kubectl get svc api-service-lb -n house-price-predictor

# Step 5: Access API (once LoadBalancer has external IP)
# Open http://<EXTERNAL-IP>/docs for Swagger UI
```

## 📖 Documentation

### [COMPLETE-DEPLOYMENT-GUIDE.md](./COMPLETE-DEPLOYMENT-GUIDE.md)
**Read this first!** Complete end-to-end guide covering:
- Prerequisites installation
- EKS cluster setup
- Application deployment
- ArgoCD GitOps configuration
- Grafana monitoring setup
- Verification and testing
- Troubleshooting guide

### [EKS-SETUP.md](./EKS-SETUP.md)
Detailed EKS cluster setup guide including:
- Cluster creation with eksctl
- Node group configuration
- Add-ons installation (metrics-server, ALB controller, EBS CSI)
- Cluster health verification
- Cost optimization tips
- Security best practices

### [ARGOCD-SETUP.md](./ARGOCD-SETUP.md)
GitOps setup with ArgoCD including:
- ArgoCD installation and access
- GitHub repository configuration
- Application deployment via ArgoCD
- Automated sync policies
- Manual rollback procedures
- Advanced RBAC configuration

### [GRAFANA-SETUP.md](./GRAFANA-SETUP.md)
Monitoring and observability setup with:
- Prometheus installation
- Grafana dashboards
- Alert rules and AlertManager
- Service monitoring configuration
- Custom application metrics
- Troubleshooting monitoring issues

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────┐
│          AWS EKS Cluster                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  house-price-predictor Namespace          │  │
│  ├───────────────────────────────────────────┤  │
│  │  API Service Deployment (3 replicas)      │  │
│  │  └─ FastAPI application                   │  │
│  │  └─ LoadBalancer Service → External IP   │  │
│  │                                            │  │
│  │  Model Service Deployment (2 replicas)    │  │
│  │  └─ ML Model serving                      │  │
│  │  └─ ClusterIP Service → Internal API      │  │
│  │                                            │  │
│  │  HPA (Auto-scaling) configured            │  │
│  │  Network Policies for security             │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  argocd Namespace                         │  │
│  ├───────────────────────────────────────────┤  │
│  │  ArgoCD Server → GitOps Management        │  │
│  │  ArgoCD Repo Server → Git sync            │  │
│  │  ArgoCD Application Controller             │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  monitoring Namespace                     │  │
│  ├───────────────────────────────────────────┤  │
│  │  Prometheus → Metrics collection          │  │
│  │  Grafana → Dashboards & visualization    │  │
│  │  AlertManager → Alert routing             │  │
│  │  Node Exporter → System metrics           │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
				│                     │
				▼                     ▼
		┌────────┐           ┌─────────┐
		│ GitHub │           │ Docker  │
		│ (GitOps)          │ Hub     │
		└────────┘           └─────────┘
```

## 📊 Application Manifests

The [app-deployment.yaml](./app-deployment.yaml) includes:
- **Namespace**: Isolated namespace for application
- **ConfigMap**: Environment configuration
- **Model Service Deployment**: 2 replicas with health checks
- **API Service Deployment**: 3 replicas with health checks
- **Services**: ClusterIP and LoadBalancer
- **HorizontalPodAutoscaler**: Auto-scaling policies
- **NetworkPolicy**: Traffic restrictions for security
- **ServiceMonitor**: Prometheus metrics scraping (for monitoring)

## 🔄 GitOps Workflow

```
1. Developer commits code change → GitHub
											↓
2. GitHub webhook notifies ArgoCD
											↓
3. ArgoCD fetches latest manifests from GitHub
											↓
4. ArgoCD compares desired state (GitHub) vs actual state (Cluster)
											↓
5. ArgoCD automatically syncs changes to cluster
											↓
6. Kubernetes deploys new version
											↓
7. Grafana alerts on deployment and health
```

## 📈 Monitoring Strategy

- **Application Metrics**: HTTP requests, response times, error rates
- **System Metrics**: CPU, memory, disk usage
- **Pod Metrics**: Pod status, restart counts, resource utilization
- **Node Metrics**: Node health, capacity, resource availability
- **Custom Alerts**: Service down, high error rates, resource exhaustion

## 🔐 Security Features

The deployment includes:
- Network policies for pod-to-pod communication
- Resource limits and requests
- Health checks for pod readiness
- Service accounts for workloads
- RBAC (Role-Based Access Control)
- TLS for external communication

## ⚙️ Configuration

### Resource Limits
- **API Service**: 250m CPU / 512Mi RAM (request), 500m / 1Gi (limit)
- **Model Service**: 100m CPU / 256Mi RAM (request), 250m / 512Mi (limit)

### Auto-scaling
- **API Service**: 3-10 replicas based on CPU/memory
- **Model Service**: 2-5 replicas based on CPU/memory

### Health Checks
- **Liveness Probe**: Checks service is alive (30s initial delay)
- **Readiness Probe**: Checks service is ready for traffic (10s initial delay)

## 🐛 Troubleshooting

### Quick Diagnostics

```bash
# Check cluster nodes
kubectl get nodes

# Check application deployment
kubectl get pods -n house-price-predictor -w

# View pod logs
kubectl logs -n house-price-predictor <pod-name> -f

# Describe problematic pod
kubectl describe pod -n house-price-predictor <pod-name>

# Check events
kubectl get events -n house-price-predictor --sort-by='.lastTimestamp'

# Check resource availability
kubectl top nodes
kubectl top pods -n house-price-predictor
```

For detailed troubleshooting, see:
- [COMPLETE-DEPLOYMENT-GUIDE.md#troubleshooting](./COMPLETE-DEPLOYMENT-GUIDE.md#troubleshooting)
- [EKS-SETUP.md#troubleshooting](./EKS-SETUP.md#troubleshooting)
- [ARGOCD-SETUP.md#troubleshooting](./ARGOCD-SETUP.md#troubleshooting)
- [GRAFANA-SETUP.md#troubleshooting](./GRAFANA-SETUP.md#troubleshooting)

## 🧹 Cleanup

When you're done, clean up AWS resources:

```bash
# Delete application
kubectl delete -f app-deployment.yaml

# Delete ArgoCD
helm uninstall argocd -n argocd

# Delete monitoring
helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring

# Delete EKS cluster (takes 10-15 minutes)
eksctl delete cluster --name house-price-predictor-eks --region us-east-1
```

## 📚 References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [eksctl Getting Started](https://eksctl.io/introduction/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## 📞 Support

For issues:
1. Check the relevant guide's troubleshooting section
2. Review AWS CloudTrail logs
3. Check kubectl events: `kubectl get events -n <namespace>`
4. Check pod logs: `kubectl logs -n <namespace> <pod-name>`
5. Refer to official documentation

## 🎯 Next Steps

After initial setup:
1. Configure backup strategies
2. Set up CI/CD pipeline integration
3. Implement secret management (Sealed Secrets)
4. Configure log aggregation (CloudWatch, ELK)
5. Enable AWS GuardDuty for security
6. Create disaster recovery procedures
7. Optimize costs with reserved instances or spot instances

---

**Happy Deploying! 🚀**

