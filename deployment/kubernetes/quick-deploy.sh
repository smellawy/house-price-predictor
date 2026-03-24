#!/bin/bash

# Quick Deployment Script for House Price Predictor on AWS EKS
# This script automates the initial setup process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-house-price-predictor-eks}"
REGION="${REGION:-us-east-1}"
NODEGROUP_NAME="${NODEGROUP_NAME:-app-nodegroup}"
NODE_COUNT="${NODE_COUNT:-3}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        missing_tools+=("AWS CLI v2")
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    # Check eksctl
    if ! command -v eksctl &> /dev/null; then
        missing_tools+=("eksctl")
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        missing_tools+=("Helm 3")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        print_info "Please install the missing tools and try again."
        echo "Installation guide: deployment/kubernetes/COMPLETE-DEPLOYMENT-GUIDE.md#prerequisites"
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

verify_aws_credentials() {
    print_info "Verifying AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        echo "Run: aws configure"
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS credentials verified (Account: $ACCOUNT_ID)"
}

create_eks_cluster() {
    print_info "Creating EKS cluster..."
    print_info "Cluster Name: $CLUSTER_NAME"
    print_info "Region: $REGION"
    print_info "Nodes: $NODE_COUNT x $INSTANCE_TYPE"
    
    if eksctl get cluster --name=$CLUSTER_NAME --region=$REGION &> /dev/null; then
        print_warning "Cluster already exists, skipping creation"
        return
    fi
    
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $REGION \
        --nodegroup-name $NODEGROUP_NAME \
        --nodes $NODE_COUNT \
        --node-type $INSTANCE_TYPE \
        --managed \
        --enable-ssm \
        --with-oidc \
        --zones ${REGION}a,${REGION}b,${REGION}c
    
    print_success "EKS cluster created successfully"
}

setup_kubeconfig() {
    print_info "Updating kubeconfig..."
    
    aws eks update-kubeconfig \
        --name $CLUSTER_NAME \
        --region $REGION
    
    print_success "Kubeconfig updated"
}

install_metrics_server() {
    print_info "Installing Metrics Server..."
    
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # Wait for metrics server
    kubectl wait --for=condition=ready pod -l app=metrics-server -n kube-system --timeout=300s 2>/dev/null || true
    
    print_success "Metrics Server installed"
}

install_aws_load_balancer_controller() {
    print_info "Installing AWS Load Balancer Controller..."
    
    # Add repo
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Create service account
    eksctl create iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --region=$REGION \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --attach-policy-arn=arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy \
        --approve 2>/dev/null || true
    
    # Install controller
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --wait 2>/dev/null || print_warning "Load Balancer Controller may already be installed"
    
    print_success "AWS Load Balancer Controller installed"
}

deploy_application() {
    print_info "Deploying application..."
    
    kubectl apply -f deployment/kubernetes/app-deployment.yaml
    
    print_success "Application manifests applied"
    print_info "Waiting for pods to be ready..."
    
    kubectl wait --for=condition=ready pod -l app=api-service -n house-price-predictor --timeout=300s 2>/dev/null || true
    
    print_success "Application deployed"
}

install_argocd() {
    print_info "Installing ArgoCD..."
    
    kubectl create namespace argocd 2>/dev/null || true
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD server
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s 2>/dev/null || true
    
    print_success "ArgoCD installed"
}

install_monitoring() {
    print_info "Installing Prometheus and Grafana..."
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    kubectl create namespace monitoring 2>/dev/null || true
    
    helm install prometheus prometheus-community/kube-prometheus-stack \
        -n monitoring \
        --set grafana.enabled=false \
        --wait 2>/dev/null || print_warning "Prometheus may already be installed"
    
    helm install grafana grafana/grafana \
        -n monitoring \
        --set adminPassword="grafana-admin-password" \
        --set service.type=LoadBalancer \
        --set persistence.enabled=true \
        --set persistence.size=10Gi \
        --wait 2>/dev/null || print_warning "Grafana may already be installed"
    
    print_success "Monitoring components installed"
}

show_next_steps() {
    echo ""
    print_success "========================================="
    print_success "Deployment Phase 1 Complete!"
    print_success "========================================="
    echo ""
    
    API_EXTERNAL_IP=$(kubectl get svc api-service-lb -n house-price-predictor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "1. Check if API is accessible:"
    echo "   kubectl get svc api-service-lb -n house-price-predictor -w"
    echo ""
    
    if [ "$API_EXTERNAL_IP" != "pending" ]; then
        echo "2. Access the API:"
        echo "   http://$API_EXTERNAL_IP/docs"
        echo ""
    fi
    
    echo "3. Configure ArgoCD:"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   Default password: kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo ""
    
    echo "4. Access Monitoring:"
    echo "   kubectl get svc grafana -n monitoring -w"
    echo ""
    
    echo "5. Full documentation:"
    echo "   - Complete Guide: deployment/kubernetes/COMPLETE-DEPLOYMENT-GUIDE.md"
    echo "   - EKS Setup: deployment/kubernetes/EKS-SETUP.md"
    echo "   - ArgoCD Setup: deployment/kubernetes/ARGOCD-SETUP.md"
    echo "   - Monitoring Setup: deployment/kubernetes/GRAFANA-SETUP.md"
    echo ""
    print_success "========================================="
}

# Main execution
main() {
    echo -e "${BLUE}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════╗
    ║   House Price Predictor - Quick EKS Deployment Script    ║
    ║                        v1.0                              ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    print_info "Starting deployment..."
    echo ""
    
    # Run deployment steps
    check_prerequisites
    verify_aws_credentials
    
    # Ask for confirmation before creating cluster
    echo ""
    print_warning "This will create AWS resources and incur costs!"
    read -p "Continue with deployment? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    echo ""
    create_eks_cluster
    setup_kubeconfig
    install_metrics_server
    install_aws_load_balancer_controller
    deploy_application
    install_argocd
    install_monitoring
    
    # Show results
    show_next_steps
}

# Run main function
main "$@"
