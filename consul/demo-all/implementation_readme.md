# Service Intentions Demo - k8s-southwest1 Admin Partition
## Development to Production Promotion with CTS Automation

**Customer Story**: Demonstrate governance-driven service promotion from development to production with automated infrastructure updates through Consul Terraform Sync (CTS).

## Prerequisites

Before starting this demo, ensure you have completed the following setup:

### 1. Admin Partitions Setup
This demo requires Consul Enterprise admin partitions to be properly configured. Follow the complete setup guide:

**📖 [Admin Partitions Setup Guide](../admin-partitions/README.md)**

Key requirements:
- ✅ DC1 HashiStack cluster deployed with Consul Enterprise
- ✅ GKE clusters configured as admin partition clients
- ✅ k8s-southwest1 admin partition created and connected
- ✅ Consul Connect service mesh enabled
- ✅ Cross-partition networking configured

### 2. Nomad API Gateway Deployment
The demo uses a Nomad-deployed API Gateway for external access. Deploy it following:

**📖 [API Gateway Deployment Guide](../../nomad-apps/api-gw.nomad/README.md)**

Key requirements:
- ✅ API Gateway running in Nomad cluster (port 8081)
- ✅ HTTP listener configured for external traffic
- ✅ Consul integration enabled for service discovery
- ✅ Gateway registered in Consul service catalog

### 3. Environment Validation

Verify your setup is ready:

```bash
# Check admin partition connectivity
export CONSUL_HTTP_ADDR="http://<dc1-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<bootstrap-token>"
consul partition list

# Check API Gateway is running
nomad job status my-api-gateway
consul catalog services | grep api-gateway

# Check GKE cluster connectivity
kubectl get nodes
kubectl get pods -n consul
```

**Expected Results:**
- Consul should show `k8s-southwest1` partition in the list
- Nomad should show `my-api-gateway` job as running
- API Gateway should be registered in Consul services
- GKE cluster should have Consul pods running

## Architecture Overview

```
k8s-southwest1 Admin Partition
├── Development Namespace (testing)
├── Production Namespace (live traffic via API Gateway)
├── API Gateway (port 8081, external access)
├── Mesh Gateway (service exports)
└── CTS (watches intentions → updates load balancer)
```

## Step 1: Setup ACL Policies and Tokens

**What we're doing**: Creating permission boundaries for development and production teams using Consul Enterprise ACL policies. Development gets full access to their namespace, production gets additional permissions for CTS and gateways.

**Expected outcome**: Two distinct ACL tokens that enforce namespace isolation while enabling the required integrations.

```bash
# Development policy
cat > dev-policy.hcl << 'EOF'
partition_prefix "" {
  namespace "development" {
    service_prefix "" {
      policy = "write"
      intentions = "write"
    }
    node_prefix "" {
      policy = "read"
    }
  }
}
EOF

# Production policy with CTS permissions
cat > prod-policy.hcl << 'EOF'
partition_prefix "" {
  namespace "production" {
    service_prefix "" {
      policy = "write"
      intentions = "write"
    }
    node_prefix "" {
      policy = "read"
    }
    key_prefix "cts/" {
      policy = "write"
    }
  }
  namespace "production" {
    service "api-gateway" {
      policy = "write"
    }
    service "mesh-gateway" {
      policy = "write"
    }
  }
}
EOF

# Create policies and tokens
consul acl policy create -name "dev-policy" -rules @dev-policy.hcl
consul acl policy create -name "prod-policy" -rules @prod-policy.hcl

export DEV_TOKEN=$(consul acl token create -policy-name "dev-policy" -format json | jq -r .SecretID)
export PROD_TOKEN=$(consul acl token create -policy-name "prod-policy" -format json | jq -r .SecretID)

echo "Development token: $DEV_TOKEN"
echo "Production token: $PROD_TOKEN"
```

**Verification**: 
- You should see two policy creation confirmations
- Two tokens should be displayed
- Test with: `consul acl token read -id $DEV_TOKEN` should show development policy attached

## Step 2: Deploy Minimal Boutique to Development

**What we're doing**: Deploying a **minimal version** of Google's Online Boutique (5 core services) to the k8s-southwest1 partition development namespace with Consul Connect sidecar injection. This avoids xDS stream limits while providing a working e-commerce demo.

**Expected outcome**: Five pods running in development namespace, all registered in Consul service catalog with Connect sidecars.

```bash
# Create development namespace
kubectl create namespace development

# Deploy minimal boutique services (5 services to avoid xDS limits)
cat > boutique-minimal.yaml << 'EOF'
---
# ServiceAccounts for minimal boutique (5 services)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: productcatalogservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cartservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: currencyservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: redis-cart
  namespace: development
---
# Frontend Service + Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-southwest1"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/connect-service-upstreams: "productcatalogservice.development.k8s-southwest1:3550,cartservice.development.k8s-southwest1:7070,currencyservice.development.k8s-southwest1:7000"
    spec:
      serviceAccountName: frontend
      containers:
        - name: server
          image: gcr.io/google-samples/microservices-demo/frontend:v0.8.0
          ports:
            - containerPort: 8080
          env:
            - name: PORT
              value: "8080"
            - name: PRODUCT_CATALOG_SERVICE_ADDR
              value: "localhost:3550"
            - name: CART_SERVICE_ADDR
              value: "localhost:7070"
            - name: CURRENCY_SERVICE_ADDR
              value: "localhost:7000"
            # Disable missing services
            - name: RECOMMENDATION_SERVICE_ADDR
              value: ""
            - name: SHIPPING_SERVICE_ADDR
              value: ""
            - name: CHECKOUT_SERVICE_ADDR
              value: ""
            - name: AD_SERVICE_ADDR
              value: ""
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: development
spec:
  ports:
    - port: 80
      name: http
      targetPort: 8080
  selector:
    app: frontend
---
# Product Catalog Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productcatalogservice
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productcatalogservice
  template:
    metadata:
      labels:
        app: productcatalogservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-southwest1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: productcatalogservice
      containers:
        - name: server
          image: gcr.io/google-samples/microservices-demo/productcatalogservice:v0.8.0
          ports:
            - containerPort: 3550
          env:
            - name: PORT
              value: "3550"
---
apiVersion: v1
kind: Service
metadata:
  name: productcatalogservice
  namespace: development
spec:
  ports:
    - port: 3550
      name: grpc
      targetPort: 3550
  selector:
    app: productcatalogservice
---
# Cart Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cartservice
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cartservice
  template:
    metadata:
      labels:
        app: cartservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-southwest1"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/connect-service-upstreams: "redis-cart.development.k8s-southwest1:6379"
    spec:
      serviceAccountName: cartservice
      containers:
        - name: server
          image: gcr.io/google-samples/microservices-demo/cartservice:v0.8.0
          ports:
            - containerPort: 7070
          env:
            - name: PORT
              value: "7070"
            - name: REDIS_ADDR
              value: "localhost:6379"
---
apiVersion: v1
kind: Service
metadata:
  name: cartservice
  namespace: development
spec:
  ports:
    - port: 7070
      name: grpc
      targetPort: 7070
  selector:
    app: cartservice
---
# Currency Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: currencyservice
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: currencyservice
  template:
    metadata:
      labels:
        app: currencyservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-southwest1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: currencyservice
      containers:
        - name: server
          image: gcr.io/google-samples/microservices-demo/currencyservice:v0.8.0
          ports:
            - containerPort: 7000
          env:
            - name: PORT
              value: "7000"
            - name: DISABLE_PROFILER
              value: "1"
---
apiVersion: v1
kind: Service
metadata:
  name: currencyservice
  namespace: development
spec:
  ports:
    - port: 7000
      name: grpc
      targetPort: 7000
  selector:
    app: currencyservice
---
# Redis Cart
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cart
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-cart
  template:
    metadata:
      labels:
        app: redis-cart
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-southwest1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: redis-cart
      containers:
        - name: redis
          image: redis:alpine
          ports:
            - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis-cart
  namespace: development
spec:
  ports:
    - port: 6379
      name: redis
      targetPort: 6379
  selector:
    app: redis-cart
EOF

kubectl apply -f boutique-minimal.yaml
kubectl wait --for=condition=Ready pod -l app=frontend -n development --timeout=300s
```

**Verification**:
- `kubectl get pods -n development` should show 5 pods with 2/2 ready (frontend, productcatalogservice, cartservice, currencyservice, redis-cart)
- `consul catalog services -partition k8s-southwest1 -namespace development` should list all 5 services
- Check Connect sidecars: `kubectl get pods -n development -o wide` should show 2/2 containers per pod
- **Basic functionality test**: `kubectl port-forward svc/frontend 8080:80 -n development` and browse to http://localhost:8080

## Step 3: Apply Zero Trust and Fix with Service Intentions

**What we're doing**: Testing that our minimal app works normally, then applying Consul's zero-trust model (default deny all traffic), observing it break, then fixing it with minimal service intentions for the 5-service deployment.

**Expected outcome**: App works → App breaks with zero trust → App works again with minimal service intentions.

```bash
# Set development context
export CONSUL_HTTP_TOKEN="$DEV_TOKEN"
export CONSUL_PARTITION="k8s-southwest1"
export CONSUL_NAMESPACE="development"

# Test working app first
kubectl port-forward svc/frontend 8080:80 -n development &
curl -s http://localhost:8080 | grep -q "Online Boutique" && echo "✅ Minimal app working"

# Apply zero trust (breaks app)
consul intention create -deny -source "*" -destination "*" -description "Zero trust default deny"
curl -s http://localhost:8080 | grep -q "error\|timeout\|failed" && echo "❌ App broken by zero trust"

# Fix with minimal service intentions (5 services only)
echo "Creating minimal frontend service intentions..."
consul intention create -allow -source "frontend" -destination "productcatalogservice" -description "Frontend needs product catalog" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "frontend" -destination "currencyservice" -description "Frontend needs currency conversion" -meta "environment=development,cts_managed=true" 
consul intention create -allow -source "frontend" -destination "cartservice" -description "Frontend needs cart access" -meta "environment=development,cts_managed=true"

echo "Creating backend service intentions..."
consul intention create -allow -source "cartservice" -destination "redis-cart" -description "Cart needs Redis storage" -meta "environment=development,cts_managed=true"

sleep 10
curl -s http://localhost:8080 | grep -q "Online Boutique" && echo "✅ Minimal app functionality restored with 4 service intentions"
```

**Verification**:
- **Step 1**: Curl should return HTML containing "Online Boutique" with basic e-commerce functionality
- **Step 2**: After default deny, curl should timeout or show connection errors
- **Step 3**: After 4 minimal intentions, app should work: browse products, view cart, see currency conversion
- `consul intention list` should show exactly 4 allow intentions for minimal service communication
- **Basic test**: Browse to http://localhost:8080, add items to cart - core features should work

## Step 4: Setup Consul Terraform Sync (CTS)

**What we're doing**: Setting up CTS to watch for service intention changes in production and automatically update infrastructure. CTS runs locally on your laptop and connects to the Consul servers.

**Expected outcome**: CTS service running locally and ready to respond to service intention changes in the k8s-southwest1 partition.

**CTS Installation (run on your laptop):**
```bash
# Install CTS binary on your laptop
curl -fsSL https://releases.hashicorp.com/consul-terraform-sync/0.7.0/consul-terraform-sync_0.7.0_darwin_arm64.zip -o cts.zip
unzip cts.zip
sudo mv consul-terraform-sync /usr/local/bin/
```

**CTS Configuration with Hybrid HCP Terraform Integration:**
```bash
# Set your GCP Consul server details
export CONSUL_SERVER_IP="<your-dc1-server-ip>"  # Your DC1 server IP
export CONSUL_HTTP_ADDR="http://$CONSUL_SERVER_IP:8500"
export CONSUL_HTTP_TOKEN="<your-bootstrap-token>"  # Your bootstrap token

# CTS configuration for k8s-southwest1 partition with hybrid HCP Terraform integration
# Note: CTS runs locally but generates Terraform config for your HCP workspace
cat > consul-terraform-sync.hcl << 'EOF'
log_level = "INFO"
port = 8558

consul {
  address = "http://<your-dc1-server-ip>:8500"  # Direct connection to GCP Consul server
  token = "<your-bootstrap-token>"               # Your bootstrap token
}

driver "terraform" {
  log = true
  path = "/tmp/cts-terraform"
  
  # For local execution - CTS doesn't support remote backend directly
  required_providers {
    consul = {
      source = "hashicorp/consul"
    }
    google = {
      source = "hashicorp/google"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

task {
  name = "boutique-gke-infrastructure-sync"
  description = "Update GKE infrastructure when production services change for minimal boutique"
  enabled = true
  
  # Updated syntax for CTS v0.8.0
  condition "services" {
    names = [
      "frontend",
      "productcatalogservice", 
      "cartservice",
      "currencyservice",
      "redis-cart"
    ]
  }
  
  # Use GKE integration module that works with existing infrastructure
  module = "./gke-integration-module"
}
EOF

# Create GKE integration module that works with your existing HCP Terraform workspace
mkdir -p gke-integration-module
cat > gke-integration-module/main.tf << 'EOF'
# CTS Integration with Existing GKE Southwest Infrastructure
# This module integrates CTS with your existing GKE-southwest workspace
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.0"
    }
  }
}

# Variable that CTS provides - services discovered from Consul
variable "services" {
  description = "Services monitored by CTS from Consul k8s-southwest1 partition"
  type        = map(object({
    id      = string
    name    = string
    address = string
    port    = number
    tags    = list(string)
  }))
}

# Reference your existing GKE cluster from the GKE-southwest workspace
data "google_container_cluster" "existing_cluster" {
  name     = "gke-southwest-gke"  # Based on your ${var.cluster_name}-gke pattern
  location = "europe-southwest1"  # Your GKE region
}

# Reference your existing network from the GKE-southwest workspace
data "google_compute_network" "existing_network" {
  name = "gke-southwest-gke-network"  # Based on your ${var.cluster_name}-gke-network pattern
}

# Create additional firewall rules for discovered services
resource "google_compute_firewall" "consul_services_ingress" {
  for_each = { for name, svc in var.services : name => svc if svc.name == "frontend" }
  
  name    = "cts-boutique-${replace(each.key, ".", "-")}-ingress"
  network = data.google_compute_network.existing_network.name

  allow {
    protocol = "tcp"
    ports    = [tostring(each.value.port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-node"]
  description   = "CTS managed firewall rule for ${each.value.name} service"
}

# Create Consul KV entries to track CTS infrastructure changes
resource "consul_keys" "cts_infrastructure_state" {
  key {
    path  = "cts/gke-southwest/infrastructure/firewall_rules"
    value = jsonencode({
      timestamp = timestamp()
      rules_created = length([for s in var.services : s if s.name == "frontend"])
      service_ports = [for name, svc in var.services : "${svc.name}:${svc.port}"]
      cluster_name = data.google_container_cluster.existing_cluster.name
      network_name = data.google_compute_network.existing_network.name
    })
  }
  
  key {
    path  = "cts/gke-southwest/services/current_state"
    value = jsonencode({
      timestamp = timestamp()
      total_services = length(var.services)
      services = {
        for name, svc in var.services : name => {
          name = svc.name
          address = svc.address
          port = svc.port
          tags = svc.tags
        }
      }
      partition = "k8s-southwest1"
      namespace = "production"
    })
  }
}

# Create monitoring configuration for the boutique services
resource "local_file" "gke_service_monitoring" {
  filename = "/tmp/gke-southwest-services.json"
  content = jsonencode({
    timestamp = timestamp()
    cluster = data.google_container_cluster.existing_cluster.name
    location = data.google_container_cluster.existing_cluster.location
    network = data.google_compute_network.existing_network.name
    services = {
      for name, service in var.services : name => {
        name = service.name
        endpoint = "${service.address}:${service.port}"
        firewall_rule = service.name == "frontend" ? google_compute_firewall.consul_services_ingress[name].name : null
        monitoring_target = "${service.address}:${service.port}"
        health_check_url = "http://${service.address}:${service.port}/health"
      }
    }
    infrastructure_updates = {
      firewall_rules_created = length([for s in var.services : s if s.name == "frontend"])
      consul_kv_updated = true
    }
  })
}

# Output integration summary
output "gke_integration_summary" {
  value = {
    timestamp = timestamp()
    cluster_integration = {
      cluster_name = data.google_container_cluster.existing_cluster.name
      cluster_location = data.google_container_cluster.existing_cluster.location
      network_name = data.google_compute_network.existing_network.name
      services_integrated = length(var.services)
    }
    infrastructure_updates = {
      firewall_rules = [
        for name, svc in var.services : 
        google_compute_firewall.consul_services_ingress[name].name 
        if svc.name == "frontend"
      ]
      monitoring_config = local_file.gke_service_monitoring.filename
      consul_kv_entries = [
        "cts/gke-southwest/infrastructure/firewall_rules",
        "cts/gke-southwest/services/current_state"
      ]
    }
    service_discovery = {
      partition = "k8s-southwest1"
      namespace = "production"
      services_monitored = [for name, svc in var.services : svc.name]
      frontend_services = [for name, svc in var.services : svc.name if svc.name == "frontend"]
    }
  }
}
EOF

# Start CTS with HCP Terraform integration - connects to both GCP Consul and HCP Terraform
consul-terraform-sync start -config-file=consul-terraform-sync.hcl &
sleep 10
curl -s http://localhost:8558/v1/status | jq '.status' && echo "✅ CTS running locally, connected to GCP Consul and HCP Terraform"
```

**Verification**:
- CTS should start without errors (check logs if needed)
- `curl http://localhost:8558/v1/status` should return JSON with status information
- You should see "✅ CTS running locally, connected to GCP Consul and HCP Terraform" message
- CTS is configured to watch the 5 minimal boutique services
- **HCP Terraform Integration**: CTS will execute Terraform runs in your existing `GKE-southwest` workspace
- **Infrastructure Integration**: Module references your existing GKE cluster and network infrastructure

**Demonstrating CTS Infrastructure Automation with Hybrid HCP Terraform Integration:**

```bash
# 1. Check initial CTS task status
curl -s http://localhost:8558/v1/status/tasks | jq '.tasks[0].status'

# 2. Trigger infrastructure update by scaling services (simulates service changes)
kubectl scale deployment frontend --replicas=3 -n production
kubectl scale deployment productcatalogservice --replicas=2 -n production

# 3. Wait for CTS to detect changes and generate new Terraform config
sleep 30

# 4. Check that CTS executed Terraform locally
curl -s http://localhost:8558/v1/status/tasks | jq '.tasks[0]'

# 5. View the generated Terraform configuration for HCP integration
cat /tmp/cts-generated-config.tf
echo "📋 This config can be copied to your GKE-southwest workspace"

# 6. View the infrastructure monitoring file that was created
cat /tmp/gke-southwest-services.json | jq '.'  # GKE service integration status

# 7. Check Consul KV for infrastructure state tracking
consul kv get cts/gke-southwest/infrastructure/firewall_rules | jq '.'
consul kv get cts/gke-southwest/services/current_state | jq '.'

# 8. Apply the generated config to your HCP Terraform workspace (manual step)
echo "🚀 To integrate with HCP Terraform:"
echo "1. Copy content from /tmp/cts-generated-config.tf"
echo "2. Add it to your GKE-southwest workspace repository"
echo "3. Commit and push to trigger HCP Terraform run"
echo "4. Monitor at: https://app.terraform.io/app/pablogd-hcp-test/workspaces/GKE-southwest"

# 9. Scale back and watch CTS generate updated config
kubectl scale deployment frontend --replicas=1 -n production
sleep 30
echo "Updated configuration:"
cat /tmp/cts-generated-config.tf | grep -A 5 "services_discovered"
```

**What This Demonstrates:**
- **Hybrid Integration**: CTS runs locally but generates HCP Terraform-compatible configurations
- **Real Infrastructure Automation**: Firewall rules and monitoring configs generated based on service discovery
- **Service Discovery Integration**: CTS monitors Consul service registry in k8s-southwest1 partition  
- **Infrastructure Audit Trail**: Consul KV stores detailed infrastructure change history
- **HCP Terraform Compatibility**: Generated configs use your existing workspace structure
- **GitOps Workflow**: Generated configs can be committed to trigger HCP Terraform runs

## Step 5: Promote to Production

**What we're doing**: Taking our tested minimal application from development and promoting it to the production namespace. This simulates the real-world workflow where code moves through environments.

**Expected outcome**: Same 5-service application now running in production namespace, ready for production-grade service intentions.

```bash
# Create production namespace
kubectl create namespace production

# Deploy minimal boutique to production (k8s-southwest1 partition)
sed 's/namespace: development/namespace: production/g' boutique-minimal.yaml | kubectl apply -f -
kubectl wait --for=condition=Ready pod -l app=frontend -n production --timeout=300s

echo "✅ Minimal boutique promoted to production namespace"
```

**Verification**:
- `kubectl get pods -n production` should show 5 pods (frontend, productcatalogservice, cartservice, currencyservice, redis-cart) with 2/2 ready
- `consul catalog services -partition k8s-southwest1 -namespace production` should show services in production namespace
- You should see the success message about promotion

## Step 6: Configure API Gateway

**What we're doing**: Setting up Consul's API Gateway to provide external access to our production services in the k8s-southwest1 partition. This creates a controlled entry point that we can secure with service intentions.

**Expected outcome**: API Gateway configured to route external traffic to internal services via service mesh.

```bash
# Set production context
export CONSUL_HTTP_TOKEN="$PROD_TOKEN"
export CONSUL_NAMESPACE="production"

# API Gateway configuration for k8s-southwest1
cat > api-gateway-config.hcl << 'EOF'
Kind = "api-gateway"
Name = "boutique-gateway"
Partition = "k8s-southwest1"
Namespace = "production"

Listeners = [
  {
    Name = "boutique-listener"
    Port = 8081
    Protocol = "http"
    
    Routes = [
      {
        Name = "boutique-route"
        Match = { HTTP = { PathPrefix = "/boutique/" } }
        Services = [
          {
            Name = "frontend"
            Namespace = "production"
            Partition = "k8s-southwest1"
          }
        ]
        Filters = { URLRewrite = { PathPrefix = "/" } }
      }
    ]
  }
]
EOF

consul config write api-gateway-config.hcl
echo "✅ API Gateway configured for k8s-southwest1 external access"
```

**Verification**:
- `consul config read -kind api-gateway -name boutique-gateway` should show your gateway configuration
- Gateway should be configured for k8s-southwest1 partition
- Routes should be configured to forward `/boutique/` traffic to frontend service

## Step 7: Production Service Intentions with CTS Integration

**What we're doing**: Applying production-grade service intentions for our minimal 5-service deployment that include metadata for CTS automation. These intentions control service communication and trigger infrastructure updates through CTS.

**Expected outcome**: Zero-trust production environment with explicit service communication permissions for minimal boutique services.

```bash
# Apply production zero trust
consul intention create -deny -source "*" -destination "*" -description "Production zero trust"

# Create minimal production service intentions with CTS metadata
echo "Creating production frontend service intentions (minimal set)..."
consul intention create -allow -source "frontend" -destination "productcatalogservice" -description "Production: Frontend to product catalog" -meta "environment=production,cts_managed=true,destination_port=3550"
consul intention create -allow -source "frontend" -destination "currencyservice" -description "Production: Frontend to currency service" -meta "environment=production,cts_managed=true,destination_port=7000"
consul intention create -allow -source "frontend" -destination "cartservice" -description "Production: Frontend to cart service" -meta "environment=production,cts_managed=true,destination_port=7070"

echo "Creating backend service intentions..."
consul intention create -allow -source "cartservice" -destination "redis-cart" -description "Production: Cart to Redis storage" -meta "environment=production,cts_managed=true,destination_port=6379"

# Trigger CTS update for production infrastructure
consul kv put "cts/production/intentions/last_update" "$(date -Iseconds)"
consul kv put "cts/production/intentions/services_count" "5"
echo "🔧 CTS triggered - load balancer updating for minimal boutique services..."

sleep 30
curl -s http://localhost:8558/v1/status | jq '.tasks[0].status' && echo "✅ CTS execution complete - infrastructure updated for minimal application"
```

**Verification**:
- `consul intention list` in production namespace should show 4 allow intentions for minimal service communication
- CTS status should show successful task execution with infrastructure updates for service ports: 3550, 7000, 7070, 6379
- Check intentions metadata: `consul intention list -detailed` should show CTS-related metadata and port information
- **Minimal production test**: Access via API Gateway should provide core e-commerce functionality
- **Port verification**: CTS should have updated load balancer for the 4 core service ports

## Step 8: Configure Service Exports

**What we're doing**: Configuring service exports to make selected production services from our minimal boutique available to other Consul partitions via mesh gateway. This enables controlled cross-partition service sharing.

**Expected outcome**: Minimal production services available for consumption by other partitions through secure mesh gateway connections.

```bash
# Service export configuration for minimal boutique
cat > service-exports.hcl << 'EOF'
Kind = "exported-services"
Name = "boutique-exports"
Partition = "k8s-southwest1"

Services = [
  {
    Name = "frontend"
    Namespace = "production"
    Consumers = [
      { Partition = "analytics-cluster" },
      { Partition = "mobile-backend" }
    ]
  },
  {
    Name = "productcatalogservice"
    Namespace = "production"
    Consumers = [
      { Partition = "analytics-cluster" },
      { Partition = "mobile-backend" },
      { Partition = "partner-integrations" }
    ]
  },
  {
    Name = "currencyservice"
    Namespace = "production"
    Consumers = [
      { Partition = "mobile-backend" },
      { Partition = "partner-integrations" }
    ]
  }
]

Meta = {
  "cts_managed" = "true"
  "mesh_gateway_integration" = "enabled"
  "minimal_deployment" = "true"
}
EOF

consul config write service-exports.hcl
echo "✅ Minimal boutique services exported via mesh gateway"
```

**Verification**:
- `consul config read -kind exported-services -name boutique-exports` should show your export configuration with 3 minimal services
- **Services exported**: frontend, productcatalogservice, currencyservice (core business logic)
- **Consumer partitions**: analytics-cluster, mobile-backend, partner-integrations
- Mesh gateway should be configured to handle cross-partition traffic for minimal service set

## Step 9: Verify Complete Setup

**What we're doing**: Final verification that all components are working together with our minimal 5-service deployment - checking service intentions across both namespaces, confirming CTS is operational, and validating that our complete governance workflow is in place.

**Expected outcome**: Complete audit trail showing minimal service intentions, CTS automation, and cross-partition exports all functioning together.

```bash
echo "📊 Minimal Boutique Demo Summary:"
echo "================================="

# Show development intentions
export CONSUL_NAMESPACE="development"
echo "Development intentions (minimal set):"
consul intention list

# Show production intentions
export CONSUL_NAMESPACE="production"
echo "Production intentions (minimal set):"
consul intention list

# Show API Gateway status
consul catalog services | grep api-gateway

# Show CTS status
echo "CTS Status:"
curl -s http://localhost:8558/v1/status | jq '.tasks[] | {name, status}'

echo ""
echo "✅ Complete Minimal Demo Achieved:"
echo "- ✅ k8s-southwest1 admin partition with ACL governance"
echo "- ✅ Minimal 5-service boutique deployment (avoids xDS limits)"
echo "- ✅ Development → Production promotion workflow"
echo "- ✅ API Gateway for external access (port 8081)"
echo "- ✅ CTS automation updating load balancer based on intentions"
echo "- ✅ Service exports via mesh gateway (3 core services)"
echo "- ✅ Zero trust with explicit service intentions"
```

**Final Verification Checklist**:
- **Development intentions**: Should see 4 allow intentions for minimal service communication
- **Production intentions**: Should see 4 allow intentions for minimal service stack  
- **CTS status**: Should show successful task execution with infrastructure updates for 4 service ports
- **Service exports**: Should show 3 core services exported to 3 different partitions
- **API Gateway**: Should be configured and routing external traffic to functional minimal e-commerce app
- **Audit trail**: Complete history of 8 service communication approvals across both environments

**Success indicators**:
- **Core e-commerce functionality**: Browse products, add to cart, currency conversion working
- **Zero unauthorized communication**: All service-to-service communication explicitly approved
- **Production-ready**: Infrastructure automation via CTS for minimal service set
- **Cross-cluster ready**: Core services exported and ready for cluster peering demonstrations
- **Scalable foundation**: Can add more services incrementally without hitting xDS limits

**Minimal Boutique Services Ready for Cross-Partition Demo**:
- **Frontend service**: Available to analytics-cluster and mobile-backend partitions
- **Product catalog**: Available to analytics, mobile-backend, and partner-integrations  
- **Currency service**: Available to mobile-backend and partner-integrations

This gives you a solid, working foundation for demonstrating cross-cluster service sharing scenarios with a proven minimal deployment!

## Key Demo Points

1. **Governance**: ACL policies enforce namespace boundaries in k8s-southwest1 partition
2. **Zero Trust**: Default deny with explicit allow intentions for minimal service set
3. **Automation**: CTS watches production intentions and updates infrastructure for 4 core services
4. **External Access**: API Gateway provides controlled entry point to k8s-southwest1
5. **Cross-Partition**: Service exports enable controlled external access for core services
6. **Audit Trail**: All service communication explicitly approved and logged
7. **xDS Limits**: Minimal 5-service deployment avoids Consul 1.21.0 stream limits

## Test the Complete Flow

```bash
# Set your environment to connect directly to GCP Consul
export CONSUL_HTTP_ADDR="http://<your-dc1-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<your-bootstrap-token>"

# Access minimal boutique via kubectl port-forward (for testing)
kubectl port-forward svc/frontend 8080:80 -n production &
curl http://localhost:8080

# Or test via API Gateway (if configured)
# curl http://your-api-gateway:8081/boutique/

# CTS monitors and updates load balancer automatically
# When new intentions are created in production for k8s-southwest1 partition
```