# Consul Enterprise Admin Partitions

Deploy multi-tenant Consul partitions on Google Kubernetes Engine (GKE) for complete administrative isolation between teams and environments.

**📖 [Back to Main README](../../README.md)**

## Why Admin Partitions?

Admin partitions provide enterprise-grade multi-tenancy within a single Consul datacenter:

- **Complete isolation** between teams, environments, and applications
- **Independent ACL policies** and security boundaries for each partition
- **Secure service mesh** communication across partitions
- **Separate upgrade cycles** and maintenance windows per partition

This setup demonstrates real-world scenarios with development, testing, acceptance, and production environments isolated in separate partitions.

## Architecture Overview

```
Consul Servers (VMs) - Enterprise
├── Admin Partition: "k8s-west1" (europe-west1)
│   ├── Namespace: "development"
│   ├── Namespace: "testing" 
│   └── Namespace: "acceptance"
└── Admin Partition: "k8s-southwest1" (europe-southwest1)
    ├── Namespace: "development"
    ├── Namespace: "testing"
    └── Namespace: "production"
```

**Components:**
- **Consul Servers**: Enterprise VM cluster providing partition management
- **GKE Clusters**: Kubernetes clusters running Consul agents in partitions
- **Nomad API Gateways**: Service mesh ingress for external traffic
- **Demo Applications**: Multi-service applications in each environment

## Prerequisites

### Required Infrastructure
- **Consul Enterprise** running on VMs (DC1/DC2) with admin partitions enabled
- **Two GKE clusters** deployed and accessible via kubectl
- **Nomad clusters** (DC1/DC2) for API gateway deployment

### Required Tools
- **kubectl** configured for both GKE clusters
- **consul CLI** with access to Enterprise servers
- **helm** for Consul deployment to Kubernetes

### Required Credentials
- **Consul Enterprise license** key
- **Bootstrap token** from Consul servers
- **CA certificates** from running Consul servers

## Quick Start

### 1. Set Up Environment
```bash
# Set Consul connection details
export CONSUL_HTTP_ADDR="http://<dc1-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<bootstrap-token>"

# Verify Consul cluster
consul members
consul partition list
```

### 2. Deploy Admin Partitions
```bash
# Deploy complete admin partitions setup
task -t consul/admin-partitions/Taskfile.yml "consul:deploy-all"

# This creates:
# - ACL policies for each partition and environment
# - ACL roles linking policies
# - Admin partitions (k8s-west1, k8s-southwest1)  
# - Partition tokens for GKE access
```

### 3. Set Up GKE Clusters
```bash
# Get CA certificates from Consul servers
task -t consul/admin-partitions/Taskfile.yml "consul:get-certificates"

# Deploy Kubernetes secrets for both clusters
task -t consul/admin-partitions/Taskfile.yml "consul:deploy-secrets"

# Deploy Consul to GKE with partitions
task -t consul/admin-partitions/Taskfile.yml "consul:deploy-gke"
```

### 4. Verify Deployment
```bash
# Check partitions exist
consul partition list

# Verify services in each partition
consul catalog services -partition k8s-west1
consul catalog services -partition k8s-southwest1

# Check GKE pods
kubectl get pods -n consul --context <gke-west1-context>
kubectl get pods -n consul --context <gke-southwest1-context>
```

## Deployment Workflows

### Complete Automated Setup
```bash
# Deploy all components
task -t consul/admin-partitions/Taskfile.yml "consul:deploy-all"

# Set up GKE integration
task -t consul/admin-partitions/Taskfile.yml "consul:get-certificates"
task -t consul/admin-partitions/Taskfile.yml "consul:deploy-secrets"
task -t consul/admin-partitions/Taskfile.yml "consul:deploy-gke"
```

### Manual Step-by-Step Setup

#### Phase 1: Create ACL Policies and Roles
```bash
# Navigate to project root (required for correct file paths)
cd /path/to/hashistack-gcp

# Create admin partition policies
consul acl policy create \
  -name "k8s-west1-admin-policy" \
  -description "Admin policy for k8s-west1 partition" \
  -rules @consul/admin-partitions/policies/k8s-west1-admin-policy.hcl

consul acl policy create \
  -name "k8s-southwest1-admin-policy" \
  -description "Admin policy for k8s-southwest1 partition" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-admin-policy.hcl

# Create k8s-west1 environment-specific policies
consul acl policy create \
  -name "k8s-west1-development-policy" \
  -description "Development environment policy for k8s-west1" \
  -rules @consul/admin-partitions/policies/k8s-west1-development-policy.hcl

consul acl policy create \
  -name "k8s-west1-testing-policy" \
  -description "Testing environment policy for k8s-west1" \
  -rules @consul/admin-partitions/policies/k8s-west1-testing-policy.hcl

consul acl policy create \
  -name "k8s-west1-acceptance-policy" \
  -description "Acceptance environment policy for k8s-west1" \
  -rules @consul/admin-partitions/policies/k8s-west1-acceptance-policy.hcl

# Create k8s-southwest1 environment-specific policies
consul acl policy create \
  -name "k8s-southwest1-development-policy" \
  -description "Development environment policy for k8s-southwest1" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-development-policy.hcl

consul acl policy create \
  -name "k8s-southwest1-testing-policy" \
  -description "Testing environment policy for k8s-southwest1" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-testing-policy.hcl

consul acl policy create \
  -name "k8s-southwest1-production-policy" \
  -description "Production environment policy for k8s-southwest1" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-production-policy.hcl

# Create application team policies
consul acl policy create \
  -name "frontend-developer-acl-policy" \
  -description "Frontend developer access policy" \
  -rules @consul/admin-partitions/policies/frontend-developer-acl-policy.hcl

consul acl policy create \
  -name "backend-developer-acl-policy" \
  -description "Backend developer access policy" \
  -rules @consul/admin-partitions/policies/backend-developer-acl-policy.hcl

consul acl policy create \
  -name "finance-acl-policy" \
  -description "Finance team access policy" \
  -rules @consul/admin-partitions/policies/finance-acl-policy.hcl
```

#### Phase 2: Create Admin Partitions
```bash
# Create partitions
consul partition create \
  -name "k8s-west1" \
  -description "Admin partition for GKE West1 cluster"

consul partition create \
  -name "k8s-southwest1" \
  -description "Admin partition for GKE Southwest1 cluster"

# Verify creation
consul partition list
```

#### Phase 3: Generate Partition Tokens
```bash
# Create admin roles
consul acl role create \
  -name "k8s-west1-admin" \
  -description "Admin role for k8s-west1 partition" \
  -policy-name "k8s-west1-admin-policy"

# Create partition tokens
consul acl token create \
  -description "Admin token for k8s-west1 partition" \
  -role-name "k8s-west1-admin" | tee consul/admin-partitions/tokens/k8s-west1-admin-token.txt

# Extract token IDs
cat consul/admin-partitions/tokens/k8s-west1-admin-token.txt | grep SecretID | awk '{print $2}' > consul/admin-partitions/tokens/k8s-west1-admin.token
```

#### Phase 4: Deploy to GKE

**Get CA Certificates:**
```bash
# Option 1: Direct SSH (if SSH keys configured)
DC1_SERVER_IP=$(gcloud compute instances list --filter='name~hashi-server.*-50' --format='value(natIP)' --limit=1)
ssh debian@$DC1_SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem
ssh debian@$DC1_SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem

# Option 2: Boundary SSH (if Boundary deployed)
boundary connect ssh -target-id <dc1-server-target-id> -- "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem
```

**Set up k8s-west1 cluster:**
```bash
# Switch to k8s-west1 context
kubectl config use-context <gke-west1-context>

# Create consul namespace and secrets
kubectl create namespace consul
kubectl create secret generic consul-ent-license --from-literal=key="$CONSUL_ENT_LICENSE" -n consul
kubectl create secret generic consul-bootstrap-token --from-literal=token="$(cat consul/admin-partitions/tokens/k8s-west1-admin.token)" -n consul
kubectl create secret generic consul-ca-cert --from-file=tls.crt=consul-agent-ca.pem -n consul
kubectl create secret generic consul-ca-key --from-file=tls.key=consul-agent-ca-key.pem -n consul

# Deploy Consul with Helm
cd clusters/gke-europe-west1/helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install consul hashicorp/consul --namespace consul --values values.yaml
```

**Set up k8s-southwest1 cluster:**
```bash
# Switch context and repeat for southwest1
kubectl config use-context <gke-southwest1-context>
# ... repeat secret creation and Helm deployment
```

#### Phase 5: Create Environment Namespaces
```bash
# k8s-west1 environments
kubectl config use-context <gke-west1-context>
kubectl create namespace development
kubectl create namespace testing
kubectl create namespace acceptance

# Enable Consul injection
kubectl label namespace development consul.hashicorp.com/connect-inject=true
kubectl label namespace testing consul.hashicorp.com/connect-inject=true
kubectl label namespace acceptance consul.hashicorp.com/connect-inject=true
```

## Available Tasks

Use the admin partitions Taskfile for automated operations:

### Setup Tasks
- `task -t consul/admin-partitions/Taskfile.yml "consul:deploy-policies"` - Create ACL policies
- `task -t consul/admin-partitions/Taskfile.yml "consul:deploy-roles"` - Create ACL roles
- `task -t consul/admin-partitions/Taskfile.yml "consul:deploy-partitions"` - Create admin partitions
- `task -t consul/admin-partitions/Taskfile.yml "consul:deploy-tokens"` - Generate partition tokens

### GKE Integration Tasks
- `task -t consul/admin-partitions/Taskfile.yml "consul:get-certificates"` - Fetch CA certificates from servers
- `task -t consul/admin-partitions/Taskfile.yml "consul:deploy-secrets"` - Set up Kubernetes secrets
- `task -t consul/admin-partitions/Taskfile.yml "consul:deploy-gke"` - Deploy Consul to GKE clusters

### Complete Setup
- `task -t consul/admin-partitions/Taskfile.yml "consul:deploy-all"` - Full automated setup

## Demo Applications

### Google Boutique Microservices

Deploy a production-like microservices application to demonstrate admin partitions:

```bash
# Deploy boutique application to k8s-southwest1 partition
task deploy-boutique-full

# Access the frontend
kubectl port-forward svc/frontend 8080:80 -n development
curl http://localhost:8080
```

**Services deployed:**
- **Frontend**: Web UI (port 8080)
- **Product Catalog**: Product inventory service (port 3550)
- **Cart Service**: Shopping cart operations (port 7070) 
- **Currency Service**: Currency conversion (port 7000)
- **Redis**: Cart data storage (port 6379)

All services run with Consul Connect service mesh and are properly registered in the k8s-southwest1 partition.

## Verification Commands

### Check Admin Partitions
```bash
# List all partitions
consul partition list

# Check services in each partition
consul catalog services -partition k8s-west1
consul catalog services -partition k8s-southwest1

# Check services by environment
consul catalog services -partition k8s-west1 -namespace development
consul catalog services -partition k8s-southwest1 -namespace production
```

### Test Cross-Partition Communication
```bash
# Test from k8s-west1 to k8s-southwest1
kubectl config use-context <gke-west1-context>
kubectl exec -n development deployment/frontend -- \
  curl -s http://backend.development.k8s-southwest1.consul:9090/health

# Verify service intentions
consul intention check frontend.development.k8s-west1 backend.development.k8s-southwest1
```

### Check GKE Deployment
```bash
# Verify Consul pods
kubectl get pods -n consul --context <gke-west1-context>
kubectl get pods -n consul --context <gke-southwest1-context>

# Check service registration
kubectl logs -n consul -l app=consul,component=connect-injector
```

## Environment Summary

| Partition | GKE Cluster | Environments | Location |
|-----------|-------------|--------------|----------|
| k8s-west1 | gke-europe-west1 | development, testing, acceptance | europe-west1 |
| k8s-southwest1 | gke-southwest | development, testing, production | europe-southwest1 |

## Troubleshooting

### Common Issues

**ACL Permission Errors:**
- Ensure all ACL policies and roles are created in the `default` partition
- Tokens are created in `default` but grant access to target partitions
- Don't specify `-partition` when creating admin partition tokens

**Service Registration Issues:**
- Verify partition names match between Helm values and pod annotations
- Check that CA certificates are current and match server configuration
- Ensure Kubernetes secrets contain correct token IDs

**Cross-Partition Communication Fails:**
- Create service intentions for all required service-to-service communication
- Verify partition and namespace names in service upstreams configuration
- Check Envoy proxy configuration with `kubectl port-forward deployment/app 19000:19000`

### Debug Commands
```bash
# Check ACL configuration
consul acl policy read -name "k8s-southwest1-admin-policy"
consul acl role read -name "k8s-southwest1-admin"
consul acl token read -id <token-id>

# Check Consul agent status
kubectl logs -n consul -l app=consul,component=client

# Check service mesh connectivity
kubectl exec -n development deployment/frontend -- env | grep CONSUL
kubectl port-forward deployment/frontend 19000:19000 -n development
curl http://localhost:19000/clusters | grep -E "(currency|cart|product)"
```

### Getting Help

1. **Check logs**: Use `kubectl logs` to examine Consul agent and application logs
2. **Verify configuration**: Compare Helm values with pod annotations for consistency  
3. **Test incrementally**: Deploy one service at a time to isolate issues
4. **Review ACLs**: Ensure proper policies and tokens are configured for each partition

## File Structure

```
consul/admin-partitions/
├── README.md                           # This documentation
├── Taskfile.yml                        # Automation tasks
├── policies/                           # ACL policy definitions
│   ├── k8s-west1-admin-policy.hcl
│   ├── k8s-west1-development-policy.hcl
│   ├── k8s-southwest1-admin-policy.hcl
│   └── k8s-southwest1-production-policy.hcl
├── tokens/                             # Generated tokens (gitignored)
│   ├── k8s-west1-admin-token.txt
│   └── k8s-southwest1-admin.token
└── manifests/                          # Demo application manifests
    └── boutique-minimal.yaml
```

## Success Criteria

- ✅ **Admin partitions created** and visible in Consul UI
- ✅ **ACL policies and roles** configured for all environments
- ✅ **GKE clusters** running Consul agents in correct partitions
- ✅ **Environment namespaces** created with proper injection labels
- ✅ **Demo applications** deployed and functional in all environments
- ✅ **Cross-partition communication** working with proper service intentions
- ✅ **Service mesh** providing secure communication between services
- ✅ **Google Boutique microservices** demonstrating real-world usage patterns