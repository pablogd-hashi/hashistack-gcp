# Consul Enterprise Admin Partitions

## Overview

Consul Enterprise admin partitions provide multi-tenant isolation within a single Consul datacenter. This configuration deploys Consul Enterprise on Google Kubernetes Engine (GKE) with separate partitions for different environments and teams, while maintaining secure service mesh connectivity across partitions.

### What Admin Partitions Provide

**Multi-Tenant Isolation:**
- Complete administrative boundaries between teams/environments
- Separate ACL policies and tokens per partition
- Isolated service mesh and networking policies
- Independent upgrade and maintenance cycles

**Cross-Partition Connectivity:**
- Secure service mesh communication across partitions
- Centralized service discovery and routing
- Shared Consul servers with distributed agents
- Enterprise-grade security and compliance features

This deployment demonstrates a real-world scenario with development, testing, acceptance, and production environments isolated in separate partitions.

## 🎯 Demo Architecture

```
Consul Servers (VMs) - Enterprise
├── Admin Partition: "k8s-west1" 
│   ├── Namespace: "development"
│   ├── Namespace: "testing" 
│   └── Namespace: "acceptance"
└── Admin Partition: "k8s-southwest1"
    ├── Namespace: "development"
    ├── Namespace: "testing"
    └── Namespace: "production"
```

## 📋 Infrastructure Overview

### Consul Servers
- **DC1**: HashiStack servers (europe-southwest1)
- **DC2**: HashiStack servers (europe-west1)
- **Enterprise License**: Required for admin partitions
- **ACLs**: Enabled with bootstrap token

### GKE Clusters
- **k8s-west1 partition**: GKE cluster (europe-west1)
- **k8s-southwest1 partition**: GKE cluster (europe-southwest1)

### Nomad API Gateways
- **DC1**: API Gateway for mesh ingress
- **DC2**: API Gateway for mesh ingress (to be deployed)

## Prerequisites

1. **Consul Enterprise** running on VMs with admin partitions enabled
2. **Two GKE clusters** deployed and accessible
3. **Consul Enterprise License** available
4. **Bootstrap token** from Consul servers
5. **CA certificates** from Consul servers
6. **Nomad clusters** (DC1/DC2) with API gateways

## How to run in tasks

### Phase 1: Environment Setup and Validation

#### Step 1.1: Verify Consul Servers
```bash
# Connect to Consul servers
export CONSUL_HTTP_ADDR="http://<dc1-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<bootstrap-token>"

# Verify cluster status
consul members
consul partition list
consul acl policy list
```

#### Step 1.2: Verify GKE Clusters
```bash
# Check both GKE clusters are accessible
kubectl config get-contexts | grep gke

# Test west1 cluster
kubectl config use-context <gke-west1-context>
kubectl get nodes

# Test southwest1 cluster  
kubectl config use-context <gke-southwest1-context>
kubectl get nodes
```

### Phase 2: ACL Policies and Roles

Before creating policies, ensure you're in the correct directory and have the required environment variables set:

```bash
# Navigate to project root
cd /path/to/hashistack-gcp

# Verify available policy files
ls -la consul/admin-partitions/policies/

# Should show:
# backend-developer-acl-policy.hcl
# finance-acl-policy.hcl  
# frontend-developer-acl-policy.hcl
# k8s-west1-admin-policy.hcl
# k8s-southwest1-admin-policy.hcl
# k8s-west1-development-policy.hcl
# k8s-southwest1-development-policy.hcl
# k8s-west1-testing-policy.hcl
# k8s-southwest1-testing-policy.hcl
# k8s-west1-acceptance-policy.hcl
# k8s-southwest1-production-policy.hcl
```

**Important**: All `consul acl` commands must be run from the project root directory (`hashistack-gcp/`) for the file paths to work correctly.

#### Step 2.1: Create Base Admin Partition Policies

**Policy 1: k8s-west1-admin-policy**
```bash
consul acl policy create \
  -name "k8s-west1-admin-policy" \
  -description "Admin policy for k8s-west1 partition" \
  -rules @consul/admin-partitions/policies/k8s-west1-admin-policy.hcl
```

**Policy 2: k8s-southwest1-admin-policy**
```bash
consul acl policy create \
  -name "k8s-southwest1-admin-policy" \
  -description "Admin policy for k8s-southwest1 partition" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-admin-policy.hcl
```

#### Step 2.2: Create Environment-Specific Policies

**Development Environment Policies:**
```bash
# West1 Development
consul acl policy create \
  -name "k8s-west1-development-policy" \
  -description "Development environment policy for k8s-west1" \
  -rules @consul/admin-partitions/policies/k8s-west1-development-policy.hcl

# Southwest1 Development
consul acl policy create \
  -name "k8s-southwest1-development-policy" \
  -description "Development environment policy for k8s-southwest1" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-development-policy.hcl
```

**Testing Environment Policies:**
```bash
# West1 Testing
consul acl policy create \
  -name "k8s-west1-testing-policy" \
  -description "Testing environment policy for k8s-west1" \
  -rules @consul/admin-partitions/policies/k8s-west1-testing-policy.hcl

# Southwest1 Testing
consul acl policy create \
  -name "k8s-southwest1-testing-policy" \
  -description "Testing environment policy for k8s-southwest1" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-testing-policy.hcl
```

**Production/Acceptance Environment Policies:**
```bash
# West1 Acceptance
consul acl policy create \
  -name "k8s-west1-acceptance-policy" \
  -description "Acceptance environment policy for k8s-west1" \
  -rules @consul/admin-partitions/policies/k8s-west1-acceptance-policy.hcl

# Southwest1 Production
consul acl policy create \
  -name "k8s-southwest1-production-policy" \
  -description "Production environment policy for k8s-southwest1" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-production-policy.hcl
```

#### Step 2.2a: Create Demo/Example Policies (Optional)

These policies demonstrate different partition and namespace access patterns:

```bash
# Backend Developer Policy (web partition, backend namespaces)
consul acl policy create \
  -name "backend-developer-policy" \
  -description "Backend developer access to web partition" \
  -rules @consul/admin-partitions/policies/backend-developer-acl-policy.hcl

# Frontend Developer Policy (web partition, frontend namespaces)
consul acl policy create \
  -name "frontend-developer-policy" \
  -description "Frontend developer access to web partition" \
  -rules @consul/admin-partitions/policies/frontend-developer-acl-policy.hcl

# Finance Policy (finance partition)
consul acl policy create \
  -name "finance-policy" \
  -description "Finance team access to finance partition" \
  -rules @consul/admin-partitions/policies/finance-acl-policy.hcl
```

#### Step 2.3: Create ACL Roles

**Admin Roles:**
```bash
# k8s-west1 admin role
consul acl role create \
  -name "k8s-west1-admin" \
  -description "Admin role for k8s-west1 partition" \
  -policy-name "k8s-west1-admin-policy"

# k8s-southwest1 admin role
consul acl role create \
  -name "k8s-southwest1-admin" \
  -description "Admin role for k8s-southwest1 partition" \
  -policy-name "k8s-southwest1-admin-policy"
```

**Environment-Specific Roles:**
```bash
# Development roles
consul acl role create \
  -name "k8s-west1-developer" \
  -description "Developer role for k8s-west1 development environment" \
  -policy-name "k8s-west1-development-policy"

consul acl role create \
  -name "k8s-southwest1-developer" \
  -description "Developer role for k8s-southwest1 development environment" \
  -policy-name "k8s-southwest1-development-policy"

# Testing roles
consul acl role create \
  -name "k8s-west1-tester" \
  -description "Tester role for k8s-west1 testing environment" \
  -policy-name "k8s-west1-testing-policy"

consul acl role create \
  -name "k8s-southwest1-tester" \
  -description "Tester role for k8s-southwest1 testing environment" \
  -policy-name "k8s-southwest1-testing-policy"

# Production/Acceptance roles
consul acl role create \
  -name "k8s-west1-acceptor" \
  -description "Acceptance role for k8s-west1 acceptance environment" \
  -policy-name "k8s-west1-acceptance-policy"

consul acl role create \
  -name "k8s-southwest1-operator" \
  -description "Production operator role for k8s-southwest1" \
  -policy-name "k8s-southwest1-production-policy"
```

**Demo/Example Roles (Optional):**
```bash
# Demo roles for the example policies
consul acl role create \
  -name "backend-developer" \
  -description "Backend developer role" \
  -policy-name "backend-developer-policy"

consul acl role create \
  -name "frontend-developer" \
  -description "Frontend developer role" \
  -policy-name "frontend-developer-policy"

consul acl role create \
  -name "finance-user" \
  -description "Finance team user role" \
  -policy-name "finance-policy"
```

### Phase 3: Admin Partitions Creation

#### Step 3.1: Create Admin Partitions
```bash
# Create k8s-west1 partition
consul partition create \
  -name "k8s-west1" \
  -description "Admin partition for GKE West1 cluster with dev/test/acceptance environments"

# Create k8s-southwest1 partition
consul partition create \
  -name "k8s-southwest1" \
  -description "Admin partition for GKE Southwest1 cluster with dev/test/production environments"

# Verify partitions
consul partition list
```

#### Step 3.2: Create Admin Partition Tokens

**Important Note**: ACL roles and policies are created in the `default` partition but can grant access to other partitions. Tokens should be created in the `default` partition without specifying the partition parameter.

```bash
# Create k8s-west1 admin token (created in default partition)
consul acl token create \
  -description "Admin token for k8s-west1 partition" \
  -role-name "k8s-west1-admin" | tee consul/admin-partitions/tokens/k8s-west1-admin-token.txt

# Create k8s-southwest1 admin token (created in default partition)
consul acl token create \
  -description "Admin token for k8s-southwest1 partition" \
  -role-name "k8s-southwest1-admin" | tee consul/admin-partitions/tokens/k8s-southwest1-admin-token.txt

# Extract token IDs
cat consul/admin-partitions/tokens/k8s-west1-admin-token.txt | grep SecretID | awk '{print $2}' > consul/admin-partitions/tokens/k8s-west1-admin.token
cat consul/admin-partitions/tokens/k8s-southwest1-admin-token.txt | grep SecretID | awk '{print $2}' > consul/admin-partitions/tokens/k8s-southwest1-admin.token
```

### Phase 4: GKE Consul Deployment

#### Step 4.1: Setup Kubernetes Secrets (k8s-west1)
```bash
# Switch to k8s-west1 cluster context
kubectl config use-context <gke-west1-context>

# Create consul namespace
kubectl create namespace consul

# Create secrets
kubectl create secret generic consul-ent-license \
  --from-literal=key="$CONSUL_ENT_LICENSE" \
  -n consul

kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="$(cat consul/admin-partitions/tokens/k8s-west1-admin.token)" \
  -n consul

# Fetch CA certificates from running Consul servers
# Choose one of the following methods:

# Option 1: Using Boundary SSH (if Boundary is deployed)
# Get DC1 server target ID from Boundary
boundary targets list -scope-id <your-scope-id> | grep dc1.*server

# Connect via Boundary and copy certificates
boundary connect ssh -target-id <dc1-server-target-id> -- "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem
boundary connect ssh -target-id <dc1-server-target-id> -- "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem

# Option 2: Using direct SSH/SCP (if SSH keys are configured)
# First, get the DC1 server IP address
DC1_SERVER_IP=$(gcloud compute instances list --filter='name~hashi-server.*-50' --format='value(natIP)' --limit=1)

# SSH to DC1 server and copy CA certificates
ssh debian@$DC1_SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem
ssh debian@$DC1_SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem

# Alternative: Use SCP (requires sudo permissions setup)
# scp debian@$DC1_SERVER_IP:/etc/consul.d/tls/consul-agent-ca.pem ./consul-agent-ca.pem
# scp debian@$DC1_SERVER_IP:/etc/consul.d/tls/consul-agent-ca-key.pem ./consul-agent-ca-key.pem

# Verify certificates were downloaded
ls -la consul-agent-ca*.pem

# Create CA certificate secrets using the fetched files
kubectl create secret generic consul-ca-cert \
  --from-file=tls.crt=consul-agent-ca.pem \
  -n consul

kubectl create secret generic consul-ca-key \
  --from-file=tls.key=clusters/dc1/terraform/consul-agent-ca-key.pem \
  -n consul
```

#### Step 4.2: Setup Kubernetes Secrets (k8s-southwest1)
```bash
# Switch to k8s-southwest1 cluster context
kubectl config use-context <gke-southwest1-context>

# Create consul namespace
kubectl create namespace consul

# Create secrets
kubectl create secret generic consul-ent-license \
  --from-literal=key="$CONSUL_ENT_LICENSE" \
  -n consul

kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="$(cat consul/admin-partitions/tokens/k8s-southwest1-admin.token)" \
  -n consul

# Fetch CA certificates from DC2 Consul servers (if using southwest1 partition)
# Choose one of the following methods:

# Option 1: Using Boundary SSH (if Boundary is deployed)
# Get DC2 server target ID from Boundary
boundary targets list -scope-id <your-scope-id> | grep dc2.*server

# Connect via Boundary and copy certificates
boundary connect ssh -target-id <dc2-server-target-id> -- "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem
boundary connect ssh -target-id <dc2-server-target-id> -- "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem

# Option 2: Using direct SSH/SCP (if SSH keys are configured)
# Get DC2 server IP address (149 suffix indicates DC2)
DC2_SERVER_IP=$(gcloud compute instances list --filter='name~hashi-server.*-149' --format='value(natIP)' --limit=1)

# SSH to DC2 server and copy CA certificates
ssh debian@$DC2_SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem
ssh debian@$DC2_SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem

# Create CA certificate secrets using the fetched files
kubectl create secret generic consul-ca-cert \
  --from-file=tls.crt=consul-agent-ca.pem \
  -n consul

kubectl create secret generic consul-ca-key \
  --from-file=tls.key=consul-agent-ca-key.pem \
  -n consul
```

#### Step 4.3: Deploy Consul with Helm

**k8s-west1 cluster:**
```bash
# Switch context and populate values
kubectl config use-context <gke-west1-context>
cd clusters/gke-europe-west1/helm
./setup-values.sh

# Deploy Consul
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install consul hashicorp/consul --namespace consul --values values.yaml

# Verify deployment
kubectl get pods -n consul
kubectl get svc -n consul
```

**k8s-southwest1 cluster:**
```bash
# Switch context and populate values
kubectl config use-context <gke-southwest1-context>
cd clusters/gke-southwest/helm
./setup-values.sh

# Deploy Consul
helm install consul hashicorp/consul --namespace consul --values values.yaml

# Verify deployment
kubectl get pods -n consul
kubectl get svc -n consul
```

### Phase 5: Environment Namespaces Setup

#### Step 5.1: Create k8s-west1 Environment Namespaces
```bash
kubectl config use-context <gke-west1-context>

# Create environment namespaces
kubectl create namespace development
kubectl create namespace testing
kubectl create namespace acceptance

# Label namespaces for Consul injection
kubectl label namespace development consul.hashicorp.com/connect-inject=true
kubectl label namespace testing consul.hashicorp.com/connect-inject=true
kubectl label namespace acceptance consul.hashicorp.com/connect-inject=true

# Add Consul namespace annotations
kubectl annotate namespace development consul.hashicorp.com/connect-service-namespace=development
kubectl annotate namespace testing consul.hashicorp.com/connect-service-namespace=testing
kubectl annotate namespace acceptance consul.hashicorp.com/connect-service-namespace=acceptance
```

#### Step 5.2: Create k8s-southwest1 Environment Namespaces
```bash
kubectl config use-context <gke-southwest1-context>

# Create environment namespaces
kubectl create namespace development
kubectl create namespace testing
kubectl create namespace production

# Label namespaces for Consul injection
kubectl label namespace development consul.hashicorp.com/connect-inject=true
kubectl label namespace testing consul.hashicorp.com/connect-inject=true
kubectl label namespace production consul.hashicorp.com/connect-inject=true

# Add Consul namespace annotations
kubectl annotate namespace development consul.hashicorp.com/connect-service-namespace=development
kubectl annotate namespace testing consul.hashicorp.com/connect-service-namespace=testing
kubectl annotate namespace production consul.hashicorp.com/connect-service-namespace=production
```

### Phase 6: Nomad API Gateway Deployment

#### Step 6.1: Deploy API Gateway to DC2
```bash
# Connect to DC2 cluster
export NOMAD_ADDR="http://<dc2-server-ip>:4646"
export NOMAD_TOKEN="<dc2-nomad-token>"

# Deploy API gateway for DC2
nomad job run clusters/dc2/jobs/api-gw.nomad.hcl

# Verify deployment
nomad job status my-api-gateway
nomad alloc status <allocation-id>
```

#### Step 6.2: Verify API Gateways
```bash
# Check DC1 API gateway
export NOMAD_ADDR="http://<dc1-server-ip>:4646"
export NOMAD_TOKEN="<dc1-nomad-token>"
nomad job status my-api-gateway

# Check DC2 API gateway
export NOMAD_ADDR="http://<dc2-server-ip>:4646"
export NOMAD_TOKEN="<dc2-nomad-token>"
nomad job status my-api-gateway
```

### Phase 7: Demo Application Deployment

#### Step 7.1: Deploy Demo-Fake App to k8s-west1 Environments

**Development Environment:**
```bash
kubectl config use-context <gke-west1-context>

# Deploy frontend to development
kubectl apply -n development -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/development/frontend.yaml

# Deploy backend to development
kubectl apply -n development -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/development/backend.yaml
```

**Testing Environment:**
```bash
# Deploy frontend to testing
kubectl apply -n testing -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/testing/frontend.yaml

# Deploy backend to testing
kubectl apply -n testing -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/testing/backend.yaml
```

**Acceptance Environment:**
```bash
# Deploy frontend to acceptance
kubectl apply -n acceptance -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/acceptance/frontend.yaml

# Deploy backend to acceptance
kubectl apply -n acceptance -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/acceptance/backend.yaml
```

#### Step 7.2: Deploy Demo-Fake App to k8s-southwest1 Environments

**Development Environment:**
```bash
kubectl config use-context <gke-southwest1-context>

# Deploy applications to development
kubectl apply -n development -f consul/admin-partitions/manifests/demo-fake-app/k8s-southwest1/development/
```

**Testing Environment:**
```bash
# Deploy applications to testing
kubectl apply -n testing -f consul/admin-partitions/manifests/demo-fake-app/k8s-southwest1/testing/
```

**Production Environment:**
```bash
# Deploy applications to production
kubectl apply -n production -f consul/admin-partitions/manifests/demo-fake-app/k8s-southwest1/production/
```

### Phase 8: Verification and Testing

#### Step 8.1: Verify Admin Partitions
```bash
# Check partitions exist
consul partition list

# Verify services in each partition
consul catalog services -partition k8s-west1
consul catalog services -partition k8s-southwest1
```

#### Step 8.2: Verify Services by Environment
```bash
# k8s-west1 services
consul catalog services -partition k8s-west1 -namespace development
consul catalog services -partition k8s-west1 -namespace testing
consul catalog services -partition k8s-west1 -namespace acceptance

# k8s-southwest1 services
consul catalog services -partition k8s-southwest1 -namespace development
consul catalog services -partition k8s-southwest1 -namespace testing
consul catalog services -partition k8s-southwest1 -namespace production
```

#### Step 8.3: Test Cross-Partition Communication
```bash
# Test communication from k8s-west1 to k8s-southwest1
kubectl config use-context <gke-west1-context>
kubectl exec -n development deployment/frontend -- \
  curl -s http://backend.development.k8s-southwest1.consul:9090/health

# Test communication from k8s-southwest1 to k8s-west1
kubectl config use-context <gke-southwest1-context>
kubectl exec -n development deployment/backend -- \
  curl -s http://frontend.development.k8s-west1.consul:9090/health
```

#### Step 8.4: Test API Gateway Access
```bash
# Get API gateway endpoints
export API_GW_DC1="http://<dc1-client-ip>:8081"
export API_GW_DC2="http://<dc2-client-ip>:8081"

# Test access through gateways
curl $API_GW_DC1/frontend/development
curl $API_GW_DC2/backend/development
```

## 📊 Environment Summary

| Partition | Cluster | Environments | Applications |
|-----------|---------|--------------|-------------|
| k8s-west1 | europe-west1 | development, testing, acceptance | frontend, backend |
| k8s-southwest1 | europe-southwest1 | development, testing, production | frontend, backend |

## 🔍 Troubleshooting Commands

### Common ACL Issues

**Error: "No such ACL role with name"**
- ACL roles and policies must be created in the `default` partition
- Tokens are created in the `default` partition but can access other partitions via roles
- Don't specify `-partition` when creating tokens for admin partition access

**Error: "No such ACL policy with name"**
- Verify policy exists: `consul acl policy list | grep <policy-name>`
- Check policy partition: `consul acl policy read -name <policy-name>`

### Verification Commands

```bash
# Check partition status
consul partition read k8s-west1
consul partition read k8s-southwest1

# Check ACL components
consul acl policy list | grep k8s-southwest1
consul acl role list | grep k8s-southwest1
consul acl token list | grep k8s-southwest1

# Check ACL tokens
consul acl token read -id <token-id>

# Verify role and policy linkage
consul acl role read -name "k8s-southwest1-admin"
consul acl policy read -name "k8s-southwest1-admin-policy"

# Check service mesh connectivity
consul intention check frontend backend.development.k8s-southwest1

# Check Kubernetes pods
kubectl get pods -n consul --all-namespaces
kubectl logs -n consul -l app=consul,component=connect-injector

# Check Nomad API gateway
nomad alloc logs <api-gateway-alloc-id>
```

## 📁 Required Files Structure

```
consul/admin-partitions/
├── README.md                           # This file
├── policies/                           # ACL policy files
│   ├── k8s-west1-admin-policy.hcl
│   ├── k8s-west1-development-policy.hcl
│   ├── k8s-west1-testing-policy.hcl
│   ├── k8s-west1-acceptance-policy.hcl
│   ├── k8s-southwest1-admin-policy.hcl
│   ├── k8s-southwest1-development-policy.hcl
│   ├── k8s-southwest1-testing-policy.hcl
│   └── k8s-southwest1-production-policy.hcl
├── tokens/                             # Generated tokens (local only)
│   ├── k8s-west1-admin-token.txt
│   ├── k8s-west1-admin.token
│   ├── k8s-southwest1-admin-token.txt
│   └── k8s-southwest1-admin.token
└── manifests/                          # Kubernetes manifests (local only)
    └── demo-fake-app/
        ├── k8s-west1/
        │   ├── development/
        │   ├── testing/
        │   └── acceptance/
        └── k8s-southwest1/
            ├── development/
            ├── testing/
            └── production/
```

## 🛍️ Google Boutique Microservices Demo

### Overview

Successfully deployed a minimal Google Boutique microservices application to demonstrate Consul service mesh functionality in the k8s-southwest1 admin partition. This deployment showcases:

- **Service Mesh Integration**: All services running with Consul Connect sidecar injection
- **Cross-Service Communication**: Frontend → Product Catalog, Cart, Currency services
- **Data Persistence**: Cart service → Redis with transparent proxy
- **Admin Partition Configuration**: Services properly registered in k8s-southwest1 partition
- **Service Intentions**: Required for service-to-service communication in Consul Enterprise

### Architecture

```
Frontend (8080) → Product Catalog Service (3550)
              → Cart Service (7070) → Redis (6379)
              → Currency Service (7000)
```

### Deployment Files

**Location**: `/consul/demo-all/boutique-minimal.yaml`

This minimal deployment includes:
- **Frontend**: Web UI for the boutique application
- **Product Catalog Service**: Manages product inventory
- **Cart Service**: Handles shopping cart operations
- **Currency Service**: Provides currency conversion
- **Redis**: Cache/storage for cart data

### Key Configuration

**Critical Settings for k8s-southwest1 partition:**

```yaml
annotations:
  consul.hashicorp.com/connect-inject: "true"
  consul.hashicorp.com/partition: "k8s-southwest1"  # Must match actual partition name
  consul.hashicorp.com/namespace: "development"
  consul.hashicorp.com/connect-service-upstreams: "productcatalogservice.development.k8s-southwest1:3550,cartservice.development.k8s-southwest1:7070,currencyservice.development.k8s-southwest1:7000"
```

### Deployment Steps

#### Automated Deployment (Recommended)

The easiest way to deploy the boutique application is using the provided Taskfile:

```bash
# Complete automated deployment workflow
task deploy-boutique-full

# Or run individual steps:
task deploy-boutique              # Deploy the application
task create-boutique-intentions   # Create service intentions 
task test-boutique               # Test the deployment
task port-forward-frontend       # Access the frontend UI
```

#### Manual Deployment

```bash
# 1. Switch to k8s-southwest1 cluster
kubectl config use-context gke_hc-6e62239184664d288bfcec8c6f8_europe-southwest1_gke-southwest-gke

# 2. Deploy the application
kubectl apply -f consul/demo-all/boutique-minimal.yaml

# 3. Verify deployment
kubectl get pods -n development
# Expected: All pods showing 2/2 Ready (app + consul-dataplane sidecar)

# 4. Create service intentions (required for Enterprise)
consul intention create -allow frontend currencyservice.development.k8s-southwest1
consul intention create -allow frontend productcatalogservice.development.k8s-southwest1
consul intention create -allow frontend cartservice.development.k8s-southwest1
consul intention create -allow cartservice redis-cart.development.k8s-southwest1

# 5. Test the application
kubectl port-forward svc/frontend 8080:80 -n development
curl http://localhost:8080
```

### Available Taskfile Commands

| Command | Description |
|---------|-------------|
| `task deploy-boutique-full` | Complete automated deployment workflow |
| `task deploy-boutique` | Deploy boutique services to k8s-southwest1 |
| `task create-boutique-intentions` | Create service intentions for communication |
| `task test-boutique` | Test application functionality |
| `task status-boutique` | Show deployment status |
| `task logs-boutique` | Show logs from all services |
| `task debug-boutique` | Debug application issues |
| `task clean-boutique` | Remove application and intentions |
| `task redeploy-boutique` | Clean and redeploy application |
| `task port-forward-frontend` | Start port-forward to frontend UI |

### Troubleshooting Guide

#### Issue 1: Partition Name Mismatch

**Problem**: Services registered in different partition than configured in upstreams.

**Symptoms**:
```
rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing: dial tcp 127.0.0.1:7000: connect: connection refused"
```

**Root Cause**: Consul Helm values.yaml had partition name `k8s-southwest1` but application YAML used `k8s-west1`.

**Solution**: Ensure consistency between Helm values and application manifests:

```bash
# Check actual partition name from Envoy clusters
kubectl port-forward deployment/frontend 19000:19000 -n development
curl -s http://localhost:19000/clusters | grep currency
# Look for: currencyservice.development.k8s-southwest1.gcp-dc1.internal...

# Update application YAML to match:
consul.hashicorp.com/partition: "k8s-southwest1"  # Match actual partition
consul.hashicorp.com/connect-service-upstreams: "service.namespace.k8s-southwest1:port"
```

#### Issue 2: Missing Service Intentions

**Problem**: Consul Enterprise requires explicit service intentions for communication.

**Symptoms**: Connection refused errors between services even with correct configuration.

**Solution**: Create allow intentions for all service-to-service communication:

```bash
# Frontend to all backend services
consul intention create -allow frontend.development.k8s-southwest1 currencyservice.development.k8s-southwest1
consul intention create -allow frontend.development.k8s-southwest1 productcatalogservice.development.k8s-southwest1
consul intention create -allow frontend.development.k8s-southwest1 cartservice.development.k8s-southwest1

# Cart service to Redis
consul intention create -allow cartservice.development.k8s-southwest1 redis-cart.development.k8s-southwest1
```

#### Issue 3: xDS Stream Limits (Consul 1.21.0 Bug)

**Problem**: "Too many xDS streams open" prevents large deployments.

**Symptoms**: Pods fail to start with xDS stream limit errors.

**Solution**: Deploy minimal service sets to stay under limits:

- **Phase 1**: Core services (frontend, product catalog, cart, redis) = 4 services
- **Phase 2**: Add payment services = 6 services total
- **Monitor**: Check xDS stream usage in Consul logs

### Verification Commands

```bash
# Check pod status
kubectl get pods -n development

# Verify Consul service registration
export CONSUL_HTTP_ADDR="http://34.88.73.4:8500"
export CONSUL_HTTP_TOKEN="<bootstrap-token>"
consul catalog services -partition k8s-southwest1 -namespace development

# Check service mesh connectivity
kubectl logs deployment/frontend -n development -c server
kubectl logs deployment/frontend -n development -c consul-dataplane

# Test frontend access
kubectl port-forward svc/frontend 8080:80 -n development
curl http://localhost:8080

# Check Envoy configuration
kubectl port-forward deployment/frontend 19000:19000 -n development
curl http://localhost:19000/clusters | grep -E "(currency|cart|product)"
```

### Success Metrics

- ✅ **All pods healthy**: 5 pods showing 2/2 Ready status
- ✅ **Services registered**: All services visible in Consul catalog
- ✅ **Service mesh working**: Frontend can reach all backend services
- ✅ **Web UI functional**: Frontend returns HTTP 200 with product listings
- ✅ **Persistent storage**: Cart operations work with Redis backend

### Known Limitations

1. **xDS Stream Limits**: Consul 1.21.0 has a bug limiting concurrent xDS streams. Keep deployments under ~6-8 services total.
2. **Partition Naming**: Must ensure consistency between Helm values and application annotations.
3. **Service Intentions**: Required for all service-to-service communication in Enterprise mode.
4. **TLS Configuration**: CA certificates must be current and match server IPs.

## ✅ Success Criteria

- [x] Both admin partitions created and accessible
- [x] All ACL policies and roles configured
- [x] Both GKE clusters running Consul with correct partition names
- [x] All environment namespaces created and labeled
- [ ] API gateways deployed to both DC1 and DC2
- [x] Demo applications deployed to all environments
- [x] Cross-partition service discovery working
- [ ] API gateway routing functional
- [x] All services visible in Consul UI with correct partitions/namespaces
- [x] **Google Boutique microservices demo working in k8s-southwest1 partition**