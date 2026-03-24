# AWS EKS Setup Guide

This guide walks you through creating and configuring an AWS EKS cluster for deploying the House Price Predictor application.

## Prerequisites

Before starting, ensure you have:
- AWS Account with appropriate IAM permissions
- AWS CLI v2 installed: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- kubectl installed: https://kubernetes.io/docs/tasks/tools/
- eksctl installed: https://eksctl.io/introduction/#installation
- Docker images available in Docker Hub:
  - `mohamedadel9988/house-pricemodel:latest`
  - `mohamedadel9988/fastapi:b89009d7291fcfc20f4ce57d8a9fb472472523eb`

## Step 1: Configure AWS Credentials

```bash
# Configure AWS CLI with your credentials
aws configure

# Verify configuration
aws sts get-caller-identity
```

## Step 2: Create EKS Cluster Using eksctl

```bash
# Set variables for your cluster
export CLUSTER_NAME="house-price-predictor-eks"
export REGION="us-east-1"  # Change to your preferred region
export NODEGROUP_NAME="app-nodegroup"
export NODE_COUNT="3"
export INSTANCE_TYPE="t3.medium"  # Cost-effective instance type

# Create the EKS cluster (this takes 10-15 minutes)
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --nodegroup-name $NODEGROUP_NAME \
  --nodes $NODE_COUNT \
  --node-type $INSTANCE_TYPE \
  --managed \
  --enable-ssm \
  --with-oidc \
  --ssh-access

echo "EKS Cluster creation in progress..."
```

### Alternative: Create Cluster with Custom Configuration File

Save the following as `eks-cluster.yaml`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: house-price-predictor-eks
  region: us-east-1
  version: "1.27"

nodeGroups:
  - name: app-nodegroup
    desiredCapacity: 3
    minSize: 2
    maxSize: 5
    instanceType: t3.medium
    spot: false
    ssh:
      allow: true
    iam:
      withAddonPolicy:
        ebs: true
        efs: true
        cloudWatch: true

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: ebs-csi-driver
    wellKnownPolicies:
      ebsCSIDriverPolicy: true
  - name: efs-csi-driver
    wellKnownPolicies:
      efsCSIDriverPolicy: true

iamIdentityMapping:
  - arn: arn:aws:iam::ACCOUNT_ID:user/YOUR_IAM_USER
    username: admin
    groups:
      - system:masters
```

Then create the cluster:

```bash
eksctl create cluster -f eks-cluster.yaml
```

## Step 3: Update kubeconfig

```bash
# Update your kubeconfig to connect to the cluster
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $REGION

# Verify connection
kubectl cluster-info
kubectl get nodes
```

## Step 4: Install Essential Add-ons

### Install Metrics Server (for HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify installation
kubectl get deployment metrics-server -n kube-system
```

### Install AWS Load Balancer Controller

```bash
# Add EKS repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Create service account for AWS Load Balancer Controller
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

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Install AWS EBS CSI Driver (for persistent storage)

```bash
# Create service account
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --namespace=kube-system \
  --name=ebs-csi-controller-sa \
  --attach-policy-arn=arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

# Add EBS CSI driver add-on
aws eks create-addon \
  --cluster-name $CLUSTER_NAME \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn=$(aws iam get-role \
    --role-name "eksctl-$CLUSTER_NAME-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa-Role1" \
    --query 'Role.Arn' --output text 2>/dev/null) \
  --region $REGION
```

## Step 5: Verify Cluster Health

```bash
# Check cluster status
kubectl get nodes -o wide

# Check all pods
kubectl get pods --all-namespaces

# Verify DNS
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
  # Inside the pod: nslookup kubernetes.default
  # exit
```

## Step 6: Deploy the Application

```bash
# Create namespace and deploy using the manifest
kubectl apply -f deployment/kubernetes/app-deployment.yaml

# Verify deployment
kubectl get namespace house-price-predictor
kubectl get all -n house-price-predictor
kubectl get pods -n house-price-predictor

# Watch pod status
kubectl get pods -n house-price-predictor -w
```

## Step 7: Access the Application

```bash
# Get the LoadBalancer external IP
kubectl get svc api-service-lb -n house-price-predictor -w

# Wait for EXTERNAL-IP to appear (may take 2-3 minutes)
# Then access the API at: http://<EXTERNAL-IP>/docs (Swagger UI)
# Or test health: curl http://<EXTERNAL-IP>/health
```

## Step 8: View Logs

```bash
# View API service logs
kubectl logs -n house-price-predictor -l app=api-service --tail=100 -f

# View model service logs
kubectl logs -n house-price-predictor -l app=model-service --tail=100 -f

# Describe a pod for more details
kubectl describe pod -n house-price-predictor <pod-name>
```

## Step 9: Scale Deployments (Optional)

```bash
# Manually scale API service
kubectl scale deployment api-service -n house-price-predictor --replicas=5

# Scale model service
kubectl scale deployment model-service -n house-price-predictor --replicas=3

# Check HPA status
kubectl get hpa -n house-price-predictor
```

## Cleanup (When Done)

```bash
# Delete the application
kubectl delete -f deployment/kubernetes/app-deployment.yaml

# Delete the EKS cluster
eksctl delete cluster \
  --name $CLUSTER_NAME \
  --region $REGION
```

## Troubleshooting

### Pod stuck in pending state
```bash
kubectl describe pod -n house-price-predictor <pod-name>
kubectl get events -n house-price-predictor --sort-by='.lastTimestamp'
```

### Image pull errors
```bash
# Check if image exists
docker pull mohamedadel9988/house-pricemodel:latest

# Check node logs
kubectl get nodes
kubectl describe node <node-name>
```

### Service LoadBalancer pending
```bash
# Check service status
kubectl describe svc api-service-lb -n house-price-predictor

# Check AWS Load Balancer Controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Check resource usage
```bash
kubectl top nodes
kubectl top pods -n house-price-predictor
```

## Cost Optimization Tips

1. Use spot instances for non-critical workloads
2. Set appropriate resource requests and limits
3. Use node auto-scaling
4. Schedule batch jobs during off-peak hours
5. Monitor CloudWatch metrics for unused resources

## Security Best Practices

1. Restrict RBAC permissions
2. Use NetworkPolicies (already included in manifest)
3. Enable Pod Security Policies
4. Scan images for vulnerabilities
5. Use IAM roles for service accounts (IRSA)

## Next Steps

- Set up ArgoCD for GitOps
- Configure Grafana monitoring
- Set up backup strategies
- Enable CloudWatch Container Insights
- Implement auto-scaling policies
