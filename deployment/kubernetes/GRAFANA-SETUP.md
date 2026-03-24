# Grafana & Prometheus Monitoring Setup Guide

This guide walks you through setting up comprehensive monitoring for the House Price Predictor application using Prometheus and Grafana on EKS.

## Prerequisites

- EKS cluster already created and configured
- kubectl configured
- Helm 3.x installed
- ArgoCD set up (optional but recommended)

## Step 1: Install Prometheus

### Add Prometheus Helm Repository

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring
```

### Install Prometheus

```bash
# Create custom values file for Prometheus
cat > prometheus-values.yaml << 'EOF'
prometheus:
  prometheusSpec:
    retention: 30d
    
    # Resources
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
    
    # Service monitor selectors
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
    
    # Pod monitor selectors
    podMonitorSelector: {}
    podMonitorNamespaceSelector: {}
    
    # Scrape configurations
    additionalScrapeConfigs: []
    
  service:
    type: ClusterIP
    port: 9090

# Remove default dashboards to reduce memory usage
grafana:
  enabled: false

# AlertManager configuration
alertmanager:
  enabled: true
  alertmanagerSpec:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi

# Node Exporter
nodeExporter:
  enabled: true

# Kube State Metrics
kubeStateMetrics:
  enabled: true

# Prometheus Operator
prometheusOperator:
  enabled: true
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
EOF

# Install Prometheus Operator (kube-prometheus-stack)
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f prometheus-values.yaml \
  --wait
```

### Verify Prometheus Installation

```bash
# Check pods
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring
```

## Step 2: Install Grafana

### Install Grafana via Helm

```bash
# Add Grafana repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create Grafana values file
cat > grafana-values.yaml << 'EOF'
replicas: 2

# Admin credentials
adminPassword: "YOUR_SECURE_PASSWORD"

# Persistence
persistence:
  enabled: true
  type: pvc
  storageClassName: ebs-sc
  size: 10Gi

# Resources
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Service
service:
  type: LoadBalancer
  port: 3000

# Ingress (optional)
ingress:
  enabled: false
  # Enable if you have ingress controller
  # ingressClassName: alb
  # hosts:
  #   - grafana.example.com

# Pre-installed plugins
plugins:
  - grafana-piechart-panel
  - grafana-worldmap-panel

# Data sources configuration
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-operated:9090
      access: proxy
      isDefault: true
      editable: true

# Dashboards (will be auto-provisioned)
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: 'grafana-dashboards'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards/grafana-dashboards

dashboards:
  grafana-dashboards:
    kubernetes-cluster:
      gnetId: 7249
      revision: 1
      datasource: Prometheus
    pod-metrics:
      gnetId: 6417
      revision: 1
      datasource: Prometheus
    node-exporter:
      gnetId: 1860
      revision: 23
      datasource: Prometheus
EOF

# Install Grafana
helm install grafana grafana/grafana \
  -n monitoring \
  -f grafana-values.yaml \
  --wait
```

### Verify Grafana Installation

```bash
# Check Grafana pods
kubectl get pods -n monitoring | grep grafana

# Get LoadBalancer IP
kubectl get svc grafana -n monitoring -w

# Get admin password
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d)
echo "Grafana Admin Password: $GRAFANA_PASSWORD"
```

## Step 3: Access Grafana UI

```bash
# Get Grafana LoadBalancer external IP
GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Access Grafana at: http://$GRAFANA_IP:3000"

# Default credentials
# Username: admin
# Password: <from above or YOUR_SECURE_PASSWORD>
```

## Step 4: Create ServiceMonitor for Application

Create monitoring for your application pods:

```bash
cat > app-service-monitor.yaml << 'EOF'
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
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: model-service
  namespace: house-price-predictor
spec:
  selector:
    matchLabels:
      app: model-service
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
EOF

kubectl apply -f app-service-monitor.yaml
```

## Step 5: Create PrometheusRule for Alerting

```bash
cat > prometheus-rules.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: house-price-predictor-alerts
  namespace: monitoring
spec:
  groups:
  - name: house-price-predictor
    interval: 30s
    rules:
    
    # API Service Alerts
    - alert: APIServiceDown
      expr: up{job="api-service"} == 0
      for: 2m
      annotations:
        summary: "API Service is down"
        description: "API service {{ $labels.pod }} in namespace {{ $labels.namespace }} is down"
    
    - alert: APIHighErrorRate
      expr: rate(http_requests_total{job="api-service", status=~"5.."}[5m]) > 0.05
      for: 5m
      annotations:
        summary: "High error rate in API service"
        description: "API service error rate is above 5%"
    
    - alert: APIHighLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
      for: 5m
      annotations:
        summary: "High latency in API service"
        description: "API service 95th percentile latency is above 1 second"
    
    # Model Service Alerts
    - alert: ModelServiceDown
      expr: up{job="model-service"} == 0
      for: 2m
      annotations:
        summary: "Model service is down"
        description: "Model service {{ $labels.pod }} is down"
    
    # Pod Resource Alerts
    - alert: PodMemoryHighUsage
      expr: (sum(container_memory_usage_bytes) by (pod,namespace) / sum(container_spec_memory_limit_bytes) by (pod,namespace)) > 0.9
      for: 5m
      annotations:
        summary: "Pod memory usage is high"
        description: "Pod {{ $labels.pod }} in {{ $labels.namespace }} is using >90% memory"
    
    - alert: PodCPUHighUsage
      expr: (sum(rate(container_cpu_usage_seconds_total[5m])) by (pod,namespace) / sum(container_spec_cpu_quota/container_spec_cpu_period) by (pod,namespace)) > 0.8
      for: 5m
      annotations:
        summary: "Pod CPU usage is high"
        description: "Pod {{ $labels.pod }} in {{ $labels.namespace }} is using >80% CPU"
    
    # Node Alerts
    - alert: NodeNotReady
      expr: kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 5m
      annotations:
        summary: "Node is not ready"
        description: "Node {{ $labels.node }} is not ready"
    
    - alert: NodeDiskPressure
      expr: kube_node_status_condition{condition="DiskPressure",status="true"} == 1
      for: 5m
      annotations:
        summary: "Node has disk pressure"
        description: "Node {{ $labels.node }} has disk pressure"
    
    - alert: NodeMemoryPressure
      expr: kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
      for: 5m
      annotations:
        summary: "Node has memory pressure"
        description: "Node {{ $labels.node }} has memory pressure"
EOF

kubectl apply -f prometheus-rules.yaml
```

## Step 6: Configure AlertManager

```bash
# Edit AlertManager configuration for notifications (Slack/Email)
kubectl -n monitoring edit secret alertmanager-operated

# Create AlertManager configuration
cat > alertmanager-config.yaml << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'default'
  routes:
  - match:
      alertname: APIServiceDown
    receiver: 'critical'
    continue: true
  - match:
      severity: critical
    receiver: 'critical'

receivers:
- name: 'default'
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    channel: '#alerts'
    
- name: 'critical'
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    channel: '#critical-alerts'
    title: 'Critical Alert'
EOF

# Apply the configuration
kubectl create secret generic alertmanager-config \
  --from-file=alertmanager.yml=alertmanager-config.yaml \
  -n monitoring \
  -o yaml | kubectl apply -f -
```

## Step 7: Import Grafana Dashboards

### Pre-configured Dashboards

These dashboards are commonly used for Kubernetes monitoring:

1. **Kubernetes Cluster Monitoring** (GID: 7249)
2. **Kubernetes Pod Metrics** (GID: 6417)
3. **Node Exporter Full** (GID: 1860)
4. **Prometheus** (GID: 3662)

They should auto-import from the Helm values file, but you can manually import via:

```bash
# In Grafana UI:
1. Click "+" in left sidebar
2. Select "Import"
3. Enter the GID number
4. Select Prometheus as data source
5. Click Import
```

### Create Custom Dashboard for Application

```bash
cat > custom-app-dashboard.json << 'EOF'
{
  "dashboard": {
    "title": "House Price Predictor - Application Metrics",
    "panels": [
      {
        "title": "API Requests Per Minute",
        "targets": [
          {
            "expr": "rate(http_requests_total{job='api-service'}[1m])"
          }
        ]
      },
      {
        "title": "API Response Time (p95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job='api-service'}[5m]))"
          }
        ]
      },
      {
        "title": "Model Service Prediction Latency",
        "targets": [
          {
            "expr": "rate(model_prediction_duration_seconds_sum{job='model-service'}[5m]) / rate(model_prediction_duration_seconds_count{job='model-service'}[5m])"
          }
        ]
      },
      {
        "title": "Pod Memory Usage",
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes{namespace='house-price-predictor'}) by (pod) / 1024 / 1024"
          }
        ]
      },
      {
        "title": "Pod CPU Usage",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{namespace='house-price-predictor'}[5m])) by (pod)"
          }
        ]
      }
    ]
  }
}
EOF
```

## Step 8: Create Storage Class for EBS

```bash
# Create a storage class for persistent volumes
cat > ebs-storage-class.yaml << 'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
allowVolumeExpansion: true
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
EOF

kubectl apply -f ebs-storage-class.yaml
```

## Step 9: Port Forward for Local Access

```bash
# Access Prometheus locally
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &

# Access Grafana locally
kubectl port-forward -n monitoring svc/grafana 3000:3000 &

# Access AlertManager locally
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093 &

# You can now access:
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3000
# - AlertManager: http://localhost:9093
```

## Step 10: Enable CloudWatch Container Insights (Optional)

```bash
# Install CloudWatch Container Insights for EKS
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | \
  sed "s/{{cluster_name}}/house-price-predictor-eks/;s/{{region_name}}/us-east-1/" | \
  kubectl apply -f -

# View container insights in CloudWatch dashboard
# AWS Console > CloudWatch > Container Insights > Performance Monitoring
```

## Step 11: Monitoring Best Practices

### Key Metrics to Monitor

```yaml
# Application Metrics
- http_requests_total                    # Total requests
- http_request_duration_seconds          # Request latency
- http_exceptions_total                  # Error count
- model_predictions_total                # Model prediction count
- model_prediction_duration_seconds      # Model latency

# System Metrics
- up                                     # Service availability
- container_memory_usage_bytes           # Memory consumption
- container_cpu_usage_seconds_total      # CPU usage
- kube_pod_status_phase                  # Pod status
- kube_node_status_condition             # Node health

# Network Metrics
- network_bytes_sent                     # Outbound traffic
- network_bytes_recv                     # Inbound traffic
```

### SLO/SLI Configuration

```bash
# Example SLOs for API Service
- Availability: 99.9% (99.9% of requests should succeed)
- Latency: 95% of requests < 1 second
- Error Rate: < 0.1% error rate
- Throughput: Handle 1000 RPS

# Express as Prometheus queries
- Availability: 100 * (1 - (rate(http_requests_total{status=~"5.."}[30d]) / rate(http_requests_total[30d])))
- Latency SLI: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[30d])) < 1
```

## Troubleshooting

### Prometheus not scraping metrics

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Visit http://localhost:9090/targets

# Check ServiceMonitor
kubectl get servicemonitor -n house-price-predictor

# Check Prometheus config
kubectl get prometheus -n monitoring -o yaml
```

### Grafana datasource not connecting

```bash
# Check if Prometheus service is accessible
kubectl exec -it grafana-0 -n monitoring -- \
  curl http://prometheus-operated:9090/api/v1/query?query=up

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Alert not firing

```bash
# Check AlertManager
kubectl get alerts -n monitoring

# Test alert rule
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Visit http://localhost:9090/alerts
```

## Clean Up

```bash
# Remove monitoring stack
helm uninstall grafana -n monitoring
helm uninstall prometheus -n monitoring

# Remove monitoring namespace
kubectl delete namespace monitoring
```

## References

- Prometheus Docs: https://prometheus.io/docs/
- Grafana Docs: https://grafana.com/docs/
- AlertManager Docs: https://prometheus.io/docs/alerting/latest/alertmanager/
- Kubernetes Monitoring: https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/
- PrometheusRule Examples: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/
