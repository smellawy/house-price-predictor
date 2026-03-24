#!/bin/bash

# Quick Free Tier Deployment Script for House Price Predictor
# This script deploys with 1 replica on free tier or m7i-flex.large instance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_MANIFEST="$SCRIPT_DIR/app-deployment-minimal.yaml"
CLUSTER_NAME="${CLUSTER_NAME:-house-price-predictor-eks}"
REGION="${REGION:-us-east-1}"
NODEGROUP_NAME="${NODEGROUP_NAME:-app-nodegroup}"
NODE_COUNT="${NODE_COUNT:-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"  # FREE TIER default

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

show_options() {
    echo ""
    echo -e "${BLUE}Instance Type Options:${NC}"
    echo "1) t3.micro (FREE TIER - Recommended)"
    echo "2) t2.micro (FREE TIER)"
    echo "3) m7i-flex.large (Better performance, but NOT free tier)"
    echo ""
    read -p "Choose instance type (1-3): " choice
    
    case $choice in
        1) INSTANCE_TYPE="t3.micro" ;;
        2) INSTANCE_TYPE="t2.micro" ;;
        3) INSTANCE_TYPE="m7i-flex.large" ;;
        *) print_warning "Invalid choice, using t3.micro"; INSTANCE_TYPE="t3.micro" ;;
    esac
    
    echo -e "${GREEN}Selected: $INSTANCE_TYPE${NC}"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("AWS CLI v2")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v eksctl &> /dev/null; then
        missing_tools+=("eksctl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("Helm 3")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi
    
    print_success "All prerequisites installed"
}

verify_aws_credentials() {
    print_info "Verifying AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS credentials verified (Account: $ACCOUNT_ID)"
}

create_eks_cluster() {
    print_info "Creating EKS cluster with 1 node ($INSTANCE_TYPE)..."
    
    if eksctl get cluster --name=$CLUSTER_NAME --region=$REGION &> /dev/null; then
        print_warning "Cluster already exists"
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
        --zones ${REGION}a,${REGION}b
    
    print_success "EKS cluster created"
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
    
    kubectl wait --for=condition=ready pod -l app=metrics-server -n kube-system --timeout=300s 2>/dev/null || true
    
    print_success "Metrics Server installed"
}

install_aws_load_balancer_controller() {
    print_info "Installing AWS Load Balancer Controller..."
    
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update

    VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query "cluster.resourcesVpcConfig.vpcId" --output text)
    
    eksctl create iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --region=$REGION \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --attach-policy-arn=arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy \
        --override-existing-serviceaccounts \
        --approve 2>/dev/null || true
    
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=$REGION \
        --set vpcId=$VPC_ID \
        --wait 2>/dev/null || print_warning "LB Controller install/upgrade needs manual check"
    
    print_success "AWS Load Balancer Controller installed"
}

deploy_application() {
    print_info "Deploying application (1 replica - minimal)..."

    if [ ! -f "$APP_MANIFEST" ]; then
        print_error "Manifest not found at $APP_MANIFEST"
        exit 1
    fi
    
    kubectl apply -f "$APP_MANIFEST"
    
    print_success "Application manifests applied"
    print_info "Waiting for pods to be ready..."
    
    kubectl wait --for=condition=ready pod -l app=api-service -n house-price-predictor --timeout=300s 2>/dev/null || true
    
    print_success "Application deployed"
}

show_next_steps() {
    echo ""
    print_success "========================================="
    print_success "Deployment Complete!"
    print_success "========================================="
    echo ""
    
    print_info "Checking for API endpoint..."
    sleep 3
    
    API_EXTERNAL_IP=$(kubectl get svc api-service-lb -n house-price-predictor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "1. Get the LoadBalancer IP (waits 1-2 minutes):"
    echo "   kubectl get svc api-service-lb -n house-price-predictor -w"
    echo ""
    
    if [ "$API_EXTERNAL_IP" != "pending" ]; then
        echo "2. Access the API:"
        echo "   http://$API_EXTERNAL_IP/docs"
        echo ""
        echo "3. Test health check:"
        echo "   curl http://$API_EXTERNAL_IP/health"
        echo ""
    else
        echo "2. Once you have the EXTERNAL-IP, access:"
        echo "   http://<EXTERNAL-IP>/docs"
        echo ""
    fi
    
    echo "3. View logs:"
    echo "   kubectl logs -n house-price-predictor -l app=api-service -f"
    echo ""
    
    echo "4. Check resource usage:"
    echo "   kubectl top nodes"
    echo "   kubectl top pods -n house-price-predictor"
    echo ""
    
    echo -e "${YELLOW}Important:${NC}"
    echo "- Cluster cost: ~$73/month"
    echo "- Instance cost (t3.micro): ~$0-15/month (or free first 12 months)"
    echo "- Total: ~$73-88/month"
    echo ""
    
    print_success "========================================="
}

# Main execution
main() {
    echo -e "${BLUE}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════╗
    ║   House Price Predictor - Free Tier EKS Deployment      ║
    ║              (1 Replica - Minimal Setup)                ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    print_info "Starting deployment..."
    echo ""
    
    check_prerequisites
    verify_aws_credentials
    show_options
    
    echo ""
    print_warning "This will create AWS resources!"
    read -p "Continue? (yes/no): " -r
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
    
    show_next_steps
}

main "$@"
