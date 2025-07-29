# HashiCorp Enterprise Multi-Cluster Stack on GCP

A production-ready multi-cluster deployment of HashiCorp Consul Enterprise 1.21.0+ent, Nomad Enterprise 1.10.0+ent, and supporting applications on Google Cloud Platform with comprehensive monitoring, load balancing, and enterprise security features.

**🎮 Complete Service Intentions Demo**: [**Service Intentions Demo with CTS & Admin Partitions**](consul/demo-all/implementation_readme.md) - Full end-to-end demo featuring service intentions, Consul Terraform Sync (CTS), admin partitions, and Google Online Boutique microservices deployment.

## 🎯 Demo Options

This project provides two complete demonstrations:

### 1. **Main Demo**: Nomad + Consul on GCE
- **Path**: `clusters/dc1/` and `clusters/dc2/`  
- **Technology**: Consul + Nomad Enterprise on Google Compute Engine
- **Features**: Multi-cluster deployment, cluster peering, application orchestration

### 2. **Admin Partitions Demo**: Consul on GKE  
- **Path**: `consul/admin-partitions/`
- **Technology**: Consul Enterprise Admin Partitions on Google Kubernetes Engine  
- **Features**: Multi-tenant isolation, cross-partition service mesh, DTAP environments

**→ For Admin Partitions demo, see [`consul/admin-partitions/README.md`](consul/admin-partitions/README.md)**

## 🏗️ Architecture Overview

![HashiCorp Multi-Cluster Architecture](docs/images/architecture-diagram.png)

This project deploys a complete HashiCorp ecosystem with:

- **3 Server Nodes**: Combined Consul/Nomad servers with enterprise licenses (e2-standard-2)
- **2 Client Nodes**: Nomad workers for application workloads (e2-standard-4) 
- **Enterprise Security**: ACLs enabled, TLS encryption, service mesh with Consul Connect
- **Load Balancing**: Traefik v3.0 + GCP HTTP Load Balancer with DNS integration
- **Monitoring Stack**: Prometheus + Grafana with pre-configured dashboards
- **Infrastructure**: Managed instance groups, auto-healing, regional distribution
- **Admin Partitions**: GKE clusters with Consul Enterprise admin partitions for multi-tenancy

## 🔧 Admin Partitions Architecture

```
Consul Enterprise DC1 (europe-southwest1)
├── 📁 default partition
│   ├── 🔧 consul service
│   ├── 🔧 nomad service  
│   └── 🔧 nomad-client service
├── 📁 k8s-west1 partition (GKE europe-north1)
│   ├── 📂 development namespace
│   ├── 📂 testing namespace
│   ├── 📂 acceptance namespace
│   └── 📂 default namespace
└── 📁 k8s-southwest1 partition (GKE europe-southwest1)
    ├── 📂 development namespace
    ├── 📂 testing namespace
    ├── 📂 production namespace
    └── 📂 default namespace
```

## 📋 Prerequisites

### Required Accounts & Licenses
- **GCP Project** with the following IAM roles:
  - `roles/owner` or `roles/editor`
  - `roles/iam.serviceAccountUser`
  - `roles/compute.admin`
  - `roles/dns.admin` (if using DNS zones)
- **HashiCorp Consul Enterprise License** (1.21.0+ent compatible)
- **HashiCorp Nomad Enterprise License** (1.10.0+ent compatible)

### Required Tools
- **Terraform CLI** v1.0+ or **HCP Terraform** access
- **HashiCorp Packer** for custom image building
- **gcloud CLI** configured with appropriate credentials

## 🛠️ Quick Start

### Using the Taskfile (Recommended)

This project includes a modular Taskfile system organized into logical sections for easy management:

```bash
# Show all available task sections and help
task help
task                    # Same as 'task help'

# List all available tasks
task --list
```

### Modular Task Structure

The Taskfile is now organized into sections using namespace prefixes:

- **`infra:`** - Infrastructure deployment (Nomad/Consul VMs)
- **`gke:`** - GKE Kubernetes cluster management  
- **`apps:`** - Application deployment (Nomad jobs)
- **`peering:`** - Consul cluster peering

### Quick Start Commands

```bash
# === Main Commands ===
task deploy-all           # Deploy DC1, DC2, and GKE clusters
task deploy-all-gke       # Deploy both GKE clusters only
task status               # Show infrastructure status
task destroy-all          # Destroy all clusters

# === Infrastructure (Nomad/Consul VMs) ===
task infra:build-images   # Build custom images with Packer (REQUIRED first)
task infra:deploy-both    # Deploy DC1 and DC2 clusters
task infra:deploy-dc1     # Deploy DC1 cluster (europe-southwest1)
task infra:deploy-dc2     # Deploy DC2 cluster (europe-west1)
task infra:ssh-dc1-server # SSH to DC1 server
task infra:ssh-dc2-server # SSH to DC2 server
task infra:destroy-both   # Destroy both clusters

# === GKE Kubernetes Clusters ===
task gke:deploy-consul-both           # Deploy both GKE clusters with Consul admin partitions
task gke:deploy-consul-southwest-full # Deploy GKE Southwest + Consul (k8s-southwest1 partition)
task gke:deploy-consul-full           # Deploy GKE West1 + Consul (k8s-west1 partition)
task gke:deploy-gke                   # Deploy GKE West1 cluster only
task gke:deploy-gke-southwest         # Deploy GKE Southwest cluster only
task gke:auth                         # Authenticate with GKE West1
task gke:auth-southwest               # Authenticate with GKE Southwest
task gke:deploy-consul-auto           # Deploy Consul to existing GKE West1 (automated)
task gke:deploy-consul-southwest-auto # Deploy Consul to existing GKE Southwest (automated)
task gke:status-both                  # Check both GKE clusters

# === Applications (Nomad Jobs) ===
task apps:deploy-traefik                    # Deploy Traefik to both clusters
task apps:deploy-monitoring                 # Deploy Prometheus/Grafana stack
task apps:deploy-demo-apps                  # Deploy demo applications
task apps:deploy-microservices-demo-dc1     # Deploy microservices demo to DC1
task apps:deploy-microservices-demo-dc2     # Deploy microservices demo to DC2
task apps:deploy-microservices-demo-both    # Deploy microservices demo to both clusters
task apps:status-microservices-demo-both    # Check microservices demo status
task apps:cleanup-microservices-demo-both   # Remove microservices demo from both clusters
task apps:show-urls                         # Show all access URLs

# === Consul Cluster Peering ===
task peering:help         # Show peering setup instructions
task peering:setup        # Start peering setup
task peering:establish    # Establish peering connection
task peering:verify       # Verify peering works

# === Environment Variables ===
task infra:eval-vars      # Show environment setup for both clusters
task infra:eval-vars-dc1  # Show DC1 environment variables
task infra:eval-vars-dc2  # Show DC2 environment variables

# === Status and Information ===
task infra:status-dc1     # Show DC1 status
task infra:status-dc2     # Show DC2 status
task infra:get-server-ips # Get external server IPs for both clusters
```

### Benefits of Modular Structure

- **Organized Sections**: Tasks grouped by logical function (infrastructure, GKE, applications, peering)
- **Namespace Prefixes**: Clear separation using `infra:`, `gke:`, `apps:`, `peering:` prefixes
- **Maintainable**: Each section is in a separate file (`tasks/infrastructure.yml`, `tasks/gke.yml`, etc.)
- **Discoverable**: Use `task <section>:` to see section-specific tasks
- **Preserved Functionality**: All original tasks work with new namespaces

## 🚢 GKE Admin Partitions Deployment Guide

This section provides step-by-step instructions for deploying Consul Enterprise admin partitions on GKE clusters, integrated with your existing HashiStack infrastructure.

### Prerequisites

1. **DC1 HashiStack cluster deployed** and running
2. **Consul Enterprise license** available as environment variable
3. **GKE clusters** deployed in target regions
4. **kubectl** configured with appropriate contexts

### 🚀 One-Command Deployment

```bash
# Deploy both GKE clusters and Consul admin partitions in one go
task gke:deploy-consul-both

# Or deploy individually with full automation
task gke:deploy-consul-southwest-full  # Deploy GKE southwest + Consul
task gke:deploy-consul-full            # Deploy GKE north + Consul

# Individual steps with automation
task gke:deploy-consul-southwest-auto  # Deploy Consul to existing southwest GKE
task gke:deploy-consul-auto            # Deploy Consul to existing north GKE
```

### Manual Step-by-Step Deployment

#### Phase 1: Deploy and Authenticate with GKE Clusters

```bash
# Deploy GKE clusters
task gke:deploy-gke-southwest    # Deploy GKE southwest cluster
task gke:deploy-gke              # Deploy GKE north cluster (optional)

# Authenticate with clusters
task gke:auth-southwest          # Authenticate with southwest cluster
task gke:auth                    # Authenticate with north cluster
```

#### Phase 2: Create Admin Partitions on DC1 Consul

```bash
# Set up environment variables (get DC1 load balancer IP)
export CONSUL_HTTP_ADDR="http://$(cd clusters/dc1/terraform && terraform output -json load_balancers | jq -r '.global_lb.ip'):8500"
export CONSUL_HTTP_TOKEN="ConsulR0cks"

# Create admin partitions
consul partition create -name k8s-west1 -description "Kubernetes West1 Admin Partition"
consul partition create -name k8s-southwest1 -description "Kubernetes Southwest1 Admin Partition"

# Create namespaces within partitions
consul namespace create -name development -partition k8s-west1 -description "Development namespace for k8s-west1"
consul namespace create -name testing -partition k8s-west1 -description "Testing namespace for k8s-west1"
consul namespace create -name acceptance -partition k8s-west1 -description "Acceptance namespace for k8s-west1"

consul namespace create -name development -partition k8s-southwest1 -description "Development namespace for k8s-southwest1"
consul namespace create -name testing -partition k8s-southwest1 -description "Testing namespace for k8s-southwest1"
consul namespace create -name production -partition k8s-southwest1 -description "Production namespace for k8s-southwest1"
```

#### Phase 3: Deploy Consul to GKE Clusters

```bash
# Deploy Consul to southwest cluster
kubectl config use-context gke_PROJECT_europe-southwest1_gke-southwest-gke
./create-consul-secrets.sh southwest  # Automated secrets creation
helm install consul hashicorp/consul --namespace consul --values values.yaml

# Deploy Consul to north cluster
kubectl config use-context gke_PROJECT_europe-north1_gcp-dc1-gke
./create-consul-secrets.sh north      # Automated secrets creation
helm install consul hashicorp/consul --namespace consul --values values.yaml
```

#### Automated Secrets Creation Script

For each cluster, use the automated script that handles all secrets:

```bash
#!/bin/bash
# create-consul-secrets.sh
CLUSTER_TYPE=$1  # "southwest" or "north"

# Get DC1 info
DC1_LB_IP=$(cd ../../dc1/terraform && terraform output -json load_balancers | jq -r '.global_lb.ip')
BOOTSTRAP_TOKEN=$(cd ../../dc1/terraform && terraform output -json auth_tokens | jq -r '.consul_token')
GOSSIP_KEY=$(export CONSUL_HTTP_ADDR="http://$DC1_LB_IP:8500" && export CONSUL_HTTP_TOKEN="$BOOTSTRAP_TOKEN" && consul keyring -list | grep -E "^\s+[A-Za-z0-9+/=]+$" | head -1 | xargs)

# Create namespace
kubectl create namespace consul

# Create secrets
kubectl create secret generic consul-ent-license --namespace=consul --from-literal=key="$CONSUL_ENT_LICENSE"
kubectl create secret generic consul-bootstrap-token --namespace=consul --from-literal=token="$BOOTSTRAP_TOKEN"
kubectl create secret generic consul-gossip-encryption-key --namespace=consul --from-literal=key="$GOSSIP_KEY"
kubectl create secret generic consul-ca-cert --namespace=consul --from-file=tls.crt=../../dc1/terraform/consul-agent-ca.pem
kubectl create secret generic consul-ca-key --namespace=consul --from-file=tls.key=../../dc1/terraform/consul-agent-ca-key.pem
kubectl create secret generic consul-dns-token --namespace=consul --from-literal=token="$BOOTSTRAP_TOKEN"

# Update values.yaml with correct endpoints
if [ "$CLUSTER_TYPE" == "southwest" ]; then
    K8S_ENDPOINT=$(kubectl cluster-info | grep "Kubernetes control plane" | sed 's/.*https:\/\/\([^\/]*\).*/\1/')
    sed -i "s/k8sAuthMethodHost: \"https:\/\/.*\"/k8sAuthMethodHost: \"https:\/\/$K8S_ENDPOINT\"/" values.yaml
    sed -i "s/- \".*\"/- \"$DC1_LB_IP\"/" values.yaml
fi

echo "All secrets created for $CLUSTER_TYPE cluster!"
```

#### Phase 4: Configure Consul Helm Values

Update the values.yaml file with proper configuration:

```yaml
global:
  enabled: true
  name: consul
  datacenter: gcp-dc1  # Match your DC1 datacenter name
  image: hashicorp/consul-enterprise:1.21.0-ent
  imageK8S: hashicorp/consul-k8s-control-plane:1.6.2
  
  adminPartitions:
    enabled: true
    name: "k8s-southwest1"  # Must match created partition
  
  enterpriseLicense:
    secretName: consul-ent-license
    secretKey: key
    
  tls:
    enabled: true
    enableAutoEncrypt: true
    verify: false
    caCert:
      secretName: consul-ca-cert
      secretKey: tls.crt
    caKey:
      secretName: consul-ca-key  
      secretKey: tls.key

externalServers:
  enabled: true
  hosts:
    - "DC1_LOAD_BALANCER_IP"  # e.g., "34.88.211.141"
  httpsPort: 8501
  grpcPort: 8502
  tlsServerName: server.gcp-dc1.consul
  k8sAuthMethodHost: "https://GKE_CLUSTER_ENDPOINT"

server:
  enabled: false  # Using external servers

client:
  enabled: false  # Using external servers

connectInject:
  enabled: true
  transparentProxy:
    defaultEnabled: true
```

#### Phase 5: Deploy Consul to GKE

```bash
# Add HashiCorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Consul with admin partitions
helm install consul hashicorp/consul --namespace consul --values values.yaml --wait --timeout=300s

# Verify deployment
kubectl get pods -n consul
kubectl logs -f deployment/consul-connect-injector -n consul
```

#### Phase 6: Verify Admin Partition Integration

```bash
# Check partition was created/joined
export CONSUL_HTTP_ADDR="http://consul.YOUR_DOMAIN:8500"
export CONSUL_HTTP_TOKEN="ConsulR0cks"
consul partition list

# Check services in partition
consul catalog services -partition k8s-southwest1

# Verify namespaces
consul namespace list -partition k8s-southwest1
```

### Troubleshooting Common Issues

#### TLS Certificate Errors
- **Critical Issue**: `certificate signed by unknown authority` errors
- **Root Cause**: Using outdated/stale agent CA certificates from local terraform files
- **Solution**: Always get current CA certificates directly from live Consul servers

**Step-by-step fix:**
```bash
# 1. Get current agent CA from live server (replace with your server IP/zone)
gcloud compute ssh hashi-server-0-108 --zone=europe-north1-b \
  --command="sudo cat /etc/consul.d/tls/consul-agent-ca.pem" \
  --quiet > /tmp/current-agent-ca.pem

# 2. Verify this CA matches the server certificate issuer
openssl x509 -in /tmp/current-agent-ca.pem -text -noout | grep "Subject:"

# 3. Update Kubernetes secret with current CA
kubectl delete secret consul-ca-cert --namespace consul
kubectl create secret generic consul-ca-cert \
  --from-file=tls.crt=/tmp/current-agent-ca.pem --namespace consul

# 4. Redeploy Consul with correct certificates
helm uninstall consul -n consul
helm install consul hashicorp/consul --namespace consul --values values.yaml
```

#### Wrong Partition Name
- **Problem**: Partition init fails with "partition not found"
- **Solution**: Ensure the partition name in values.yaml matches exactly what was created on the Consul servers

#### Bootstrap Token Issues
- **Problem**: `permission denied` errors
- **Solution**: Verify the bootstrap token secret contains the correct token from DC1

#### TLS Server Name Mismatch
- **Problem**: TLS handshake fails with wrong server name
- **Solution**: Use correct format `server.DATACENTER.consul` (e.g., `server.gcp-dc1.consul`)

### Admin Partition Benefits

✅ **Multi-Tenancy**: Complete isolation between teams/environments  
✅ **Security**: Partition-scoped ACL policies and tokens  
✅ **Scalability**: Independent scaling per partition  
✅ **Governance**: Separate namespace management per partition  
✅ **Service Mesh**: Cross-partition service discovery and communication

## 🔐 HCP Boundary Integration (Simplified)

This project includes **automatic** integration with HCP Boundary for secure, identity-aware access to your HashiStack infrastructure. The integration automatically discovers your deployed DC1/DC2 clusters and reuses existing HCP Terraform variables.

### ✨ Key Features

**Automatic Discovery:**
- Detects deployed DC1 and DC2 clusters automatically
- Retrieves IP addresses from existing infrastructure
- Reuses SSH keys and HCP credentials from existing variable sets

**Zero-Trust Access:**
- SSH access to all HashiStack nodes
- UI access to Consul (8500), Nomad (4646), Grafana (3000), Prometheus (9090)
- Identity-aware connections with full audit trail
- No VPN or bastion host required

**Organizational Structure:**
- **Development Org**: DC1 Dev and DC2 Dev projects
- **Operations Org**: DC1 Prod and DC2 Prod projects
- **Role-Based Access**: Management, Developers, Operations roles

### Prerequisites

1. **Deployed HashiStack**: DC1 or DC2 clusters must be running
2. **HCP Boundary Cluster**: Create a cluster in HCP Portal
3. **Existing HCP Terraform**: Uses your existing variable sets (no duplicate config)

### 🚀 Quick Start (5 Steps)

1. **Ensure HashiStack is Deployed**:
   ```bash
   task infra:deploy-dc1    # Deploy DC1 if not already deployed
   # or
   task infra:deploy-dc2    # Deploy DC2 if not already deployed
   ```

2. **Create HCP Boundary Cluster**:
   - Go to HCP Portal → Boundary
   - Create new cluster
   - Note the cluster ID and URL

3. **Initialize Boundary Configuration**:
   ```bash
   task boundary:setup    # Automatically discovers clusters and creates config
   ```

4. **Update Minimal Configuration**:
   ```bash
   # Edit boundary/terraform/terraform.auto.tfvars with ONLY these 3 values:
   hcp_boundary_cluster_id = "your-cluster-id"
   boundary_addr = "https://your-cluster-id.boundary.hashicorp.cloud"
   boundary_auth_method_id = "ampw_your-auth-method-id"
   # All other variables are automatic!
   
   # Set admin password securely via environment variable:
   export TF_VAR_boundary_admin_password="your-admin-password"
   ```

5. **Deploy and Connect**:
   ```bash
   task boundary:deploy     # Deploy to HCP Boundary
   task boundary:connect    # Show connection commands
   ```

### That's It! 🎉

The integration automatically:
- ✅ Discovers your DC1/DC2 clusters
- ✅ Gets IP addresses from deployed infrastructure
- ✅ Reuses existing HCP credentials and SSH keys
- ✅ Creates organizational structure and roles
- ✅ Sets up access targets for all services

### Available Commands

```bash
# Setup and management
task boundary:help     # Show help and quick start guide
task boundary:setup    # Initialize configuration (auto-discovers clusters)
task boundary:deploy   # Deploy to HCP Boundary
task boundary:status   # Check deployment status
task boundary:connect  # Show connection commands
task boundary:destroy  # Clean up

# Worker setup (optional)
task boundary:setup-workers  # Deploy workers to clusters
```

### Advanced Configuration

#### Variable Sets in HCP Terraform

The integration automatically uses these existing variable sets:

**HashiStack Common:**
- `hcp_client_id` / `hcp_client_secret`
- `ssh_private_key`

**GCP Common:**
- `gcp_project`

**Only 3 New Variables Needed:**
- `hcp_boundary_cluster_id` (in tfvars)
- `boundary_addr` (in tfvars)
- `boundary_auth_method_id` (in tfvars)
- `TF_VAR_boundary_admin_password` (environment variable - secure!)

#### Deployment Flags

Control which clusters are integrated:
```hcl
dc1_deployed = true   # Set to false if DC1 not deployed
dc2_deployed = true   # Set to false if DC2 not deployed
dc1_region = "europe-southwest1"  # Update if different
dc2_region = "europe-west1"       # Update if different
```

### Using Boundary

After deployment, use these commands:

#### Authentication
```bash
# Get connection commands
task boundary:connect

# Or manually:
export BOUNDARY_ADDR=https://your-cluster-id.boundary.hashicorp.cloud
boundary authenticate password -auth-method-id ampw_your-auth-method-id -login-name admin
```

#### SSH Connections
```bash
# The exact target IDs are shown by 'task boundary:connect'
boundary connect ssh -target-id [dc1-servers-target-id]  # DC1 servers
boundary connect ssh -target-id [dc1-clients-target-id]  # DC1 clients
boundary connect ssh -target-id [dc2-servers-target-id]  # DC2 servers
boundary connect ssh -target-id [dc2-clients-target-id]  # DC2 clients
```

#### UI Access
```bash
# Access HashiStack UIs through secure tunnels
boundary connect -target-id [consul-target-id] -listen-port 8500  # Consul UI
boundary connect -target-id [nomad-target-id] -listen-port 4646   # Nomad UI
boundary connect -target-id [grafana-target-id] -listen-port 3000 # Grafana
boundary connect -target-id [prometheus-target-id] -listen-port 9090 # Prometheus
```

### What Gets Created

The integration automatically creates:

**Organizational Structure:**
- Development and Operations scopes
- DC1/DC2 project scopes under each org
- Management, Developer, and Operations roles

**Access Targets (per deployed cluster):**
- SSH access to servers and clients
- UI access to Consul, Nomad, Grafana, Prometheus
- Automatic credential injection using existing SSH keys

**Security Features:**
- Identity-aware access control
- Full session audit logging
- Zero-trust network architecture
- Just-in-time credential access

### Troubleshooting

#### Prerequisites Not Met
```bash
task boundary:setup  # Will check and report missing prerequisites
```

#### Deployment Issues
```bash
task boundary:status  # Check deployment status
terraform plan        # Review planned changes
```

#### Connection Problems
```bash
task boundary:connect  # Get current connection commands
boundary targets list  # List all available targets
```

For detailed troubleshooting, check the Boundary logs in HCP Portal or run `boundary --help` for CLI options.

## 🔧 Variable Configuration

### HCP Terraform Configuration (Recommended)

If using HCP Terraform, I recommend organizing your variables into variable sets:

#### Variable Set: "HashiStack Common" (reusable across all workspaces)
```hcl
# Enterprise Licenses (mark as sensitive)
consul_license = "02MV4UU43BK5HGYY..."  # Your Consul Enterprise license
nomad_license = "02MV4UU43BK5HGYY..."   # Your Nomad Enterprise license

# HashiCorp Versions
consul_version = "1.17.0+ent"
nomad_version = "1.7.2+ent"

# Security Settings
enable_tls = true
doormat-accountid = "your-doormat-id"  # If using Doormat authentication
```

#### Variable Set: "GCP Common" (reusable across GCP workspaces)
```hcl
# GCP Configuration
gcp_project = "hc-1031dcc8d7c24bfdbb4c08979b0"
gcp_sa = "hc-1031dcc8d7c24bfdbb4c08979b0"
hcp_project_id = "your-hcp-project-id"
dns_zone = "your-dns-zone-name"

# Instance Configuration
gcp_instance = "e2-standard-2"
machine_type_client = "e2-standard-4"
subnet_cidr = "10.0.0.0/16"

# SSH Access (mark as sensitive)
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAA..."
```

#### Workspace-Specific Variables

**DC1 Workspace (DB-cluster-1):**
```hcl
gcp_region = "europe-southwest1"
cluster_name = "gcp-dc1"
owner = "ownername"  # Note: Use hyphens, not dots.
```

**DC2 Workspace (DC-cluster-2):**
```hcl
gcp_region = "europe-west1"
cluster_name = "gcp-dc2"
owner = "ownername" 
```

> **⚠️ Important**: GCP tags must match the regex `(?:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?)`. Use hyphens instead of dots in the `owner` variable.

### Manual Deployment (Alternative)

#### 1. Build Custom Images
```bash
cd packer/gcp
# Edit gcp/consul_gcp.auth.pkvars.hcl with your GCP project
packer build .
```

#### 2. Configure Variables for Each Cluster
```bash
# For DC1
cd clusters/dc1/terraform
cp terraform.tfvars.example terraform.auto.tfvars

# For DC2
cd clusters/dc2/terraform
cp terraform.tfvars.example terraform.auto.tfvars
```

Required variables for each cluster:
```hcl
# DC1 Configuration (clusters/dc1/terraform/terraform.auto.tfvars)
gcp_region = "europe-southwest1"
gcp_project = "your-gcp-project-id" 
gcp_sa = "your-service-account@project.iam.gserviceaccount.com"
gcp_instance = "e2-standard-2"
machine_type_client = "e2-standard-4"
subnet_cidr = "10.0.0.0/16"
cluster_name = "gcp-dc1"
owner = "pablo-diaz"  # Note: Use hyphens, not dots for GCP compatibility
hcp_project_id = "your-hcp-project-id"
dns_zone = "your-dns-zone-name"        # Optional: for FQDN access
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAA..."

# HashiCorp Configuration
consul_license = "02MV4UU43BK5HGYY..." # Your Consul Enterprise license
nomad_license = "02MV4UU43BK5HGYY..."  # Your Nomad Enterprise license
consul_version = "1.17.0+ent"
nomad_version = "1.7.2+ent"
enable_tls = true

# DC2 Configuration (clusters/dc2/terraform/terraform.auto.tfvars)
gcp_region = "europe-west1"
cluster_name = "gcp-dc2"
# All other variables remain the same
```

#### 3. Deploy Infrastructure
```bash
# Deploy DC1
cd clusters/dc1/terraform
terraform init
terraform plan
terraform apply

# Deploy DC2
cd clusters/dc2/terraform
terraform init
terraform plan
terraform apply
```

#### 4. Configure Environment & Setup Consul-Nomad Integration
```bash
# For DC1
cd clusters/dc1/terraform
eval "$(terraform output -json environment_setup | jq -r .bash_export)"

# SSH to DC1 server and configure Consul-Nomad integration
ssh ubuntu@$(terraform output -json server_nodes | jq -r '.hashi_servers."server-1".public_ip')
sudo nomad setup consul -y

# For DC2
cd clusters/dc2/terraform
eval "$(terraform output -json environment_setup | jq -r .bash_export)"

# SSH to DC2 server and configure Consul-Nomad integration
ssh ubuntu@$(terraform output -json server_nodes | jq -r '.hashi_servers."server-1".public_ip')
sudo nomad setup consul -y
```

**⚠️ CRITICAL:** After infrastructure deployment, you MUST run `nomad setup consul -y` on each cluster's server nodes to establish proper Consul-Nomad integration. This is required for service discovery and Connect mesh functionality.

## 🌐 Multi-Cluster Access Points

### Getting Access URLs

```bash
# Show all service URLs for both clusters
task show-urls

# Get load balancer IPs for direct access
cd clusters/dc1/terraform && terraform output load_balancers
cd clusters/dc2/terraform && terraform output load_balancers
```

### DC1 (europe-southwest1) Access Points

#### Via Load Balancer (with DNS - if configured)
- **Consul UI**: `http://consul-<cluster-name>.<your-domain>:8500`
- **Nomad UI**: `http://nomad-<cluster-name>.<your-domain>:4646`
- **Grafana**: `http://grafana-<cluster-name>.<your-domain>:3000` (admin/admin)
- **Traefik Dashboard**: `http://traefik-<cluster-name>.<your-domain>:8080`
- **Prometheus**: `http://prometheus-<cluster-name>.<your-domain>:9090`

#### Direct IP Access (Always Available)
Get the load balancer IPs: `terraform output load_balancers`
- **Global LB**: `http://<global_lb_ip>:8500` (Consul), `http://<global_lb_ip>:4646` (Nomad)
- **Clients LB**: `http://<clients_lb_ip>:3000` (Grafana), `http://<clients_lb_ip>:8080` (Traefik)
- **API Gateway**: `http://<clients_lb_ip>:8081`
- **Prometheus**: `http://<clients_lb_ip>:9090`

#### Direct Instance Access
```bash
# Using Taskfile
task ssh-dc1-server       # SSH to DC1 server node

# Manual access
cd clusters/dc1/terraform
terraform output quick_commands
ssh ubuntu@$(terraform output -json server_nodes | jq -r '.hashi_servers."server-1".public_ip')
```

### DC2 (europe-west1) Access Points

#### Via Load Balancer (with DNS - if configured)
- **Consul UI**: `http://consul-<cluster-name>.<your-domain>:8500`
- **Nomad UI**: `http://nomad-<cluster-name>.<your-domain>:4646`
- **Traefik Dashboard**: `http://traefik-<cluster-name>.<your-domain>:8080`

#### Direct IP Access (Always Available)
Get the load balancer IPs: `terraform output load_balancers`
- **Global LB**: `http://<global_lb_ip>:8500` (Consul), `http://<global_lb_ip>:4646` (Nomad)
- **Clients LB**: `http://<clients_lb_ip>:3000` (Grafana), `http://<clients_lb_ip>:8080` (Traefik)
- **API Gateway**: `http://<clients_lb_ip>:8081`
- **Prometheus**: `http://<clients_lb_ip>:9090`

#### Direct Instance Access
```bash
# Using Taskfile
task ssh-dc2-server       # SSH to DC2 server node

# Manual access
cd clusters/dc2/terraform
terraform output quick_commands
ssh ubuntu@$(terraform output -json server_nodes | jq -r '.hashi_servers."server-1".public_ip')
```

### Quick Access Commands
```bash
# Show all URLs for both clusters
task show-urls

# Get environment variables for both clusters
task eval-vars

# Check status of both clusters
task status-dc1
task status-dc2
```

## 🚀 Multi-Cluster Application Deployment

### Using Taskfile (Recommended)
```bash
# Setup Consul-Nomad integration (REQUIRED after infrastructure deployment)
task infra:setup-consul-nomad-both    # Setup integration for both clusters
task infra:setup-consul-nomad-dc1     # Setup integration for DC1 only
task infra:setup-consul-nomad-dc2     # Setup integration for DC2 only

# Deploy networking (Traefik) to both clusters
task apps:deploy-traefik

# Deploy monitoring stack to both clusters
task apps:deploy-monitoring

# Deploy to specific cluster
task apps:deploy-traefik-dc1    # Deploy Traefik to DC1 only
task apps:deploy-traefik-dc2    # Deploy Traefik to DC2 only
task apps:deploy-monitoring-dc1 # Deploy monitoring to DC1 only
task apps:deploy-monitoring-dc2 # Deploy monitoring to DC2 only

# Deploy demo applications
task apps:deploy-demo-apps
task apps:deploy-demo-apps-dc1
task apps:deploy-demo-apps-dc2
```

### Manual Deployment

#### Deploy to DC1 (europe-southwest1)
```bash
cd clusters/dc1
# Get environment variables
eval "$(cd terraform && terraform output -json environment_setup | jq -r .bash_export)"

# Deploy applications
nomad job run jobs/monitoring/traefik.hcl
nomad job run jobs/monitoring/prometheus.hcl  
nomad job run jobs/monitoring/grafana.hcl
```

#### Deploy to DC2 (europe-west1)
```bash
cd clusters/dc2
# Get environment variables
eval "$(cd terraform && terraform output -json environment_setup | jq -r .bash_export)"

# Deploy applications
nomad job run jobs/monitoring/traefik.hcl
nomad job run jobs/monitoring/prometheus.hcl  
nomad job run jobs/monitoring/grafana.hcl
```

### Demo Applications
```bash
# Using Taskfile (Recommended)
task apps:deploy-demo-apps     # Deploy to both clusters
task apps:deploy-demo-apps-dc1 # Deploy to DC1 only
task apps:deploy-demo-apps-dc2 # Deploy to DC2 only

# Manual deployment
nomad job run jobs/terramino.nomad.hcl
nomad job status

# Deploy API Gateway and demo services manually
nomad job run nomad-apps/api-gw.nomad/api-gw.nomad.hcl
nomad job run nomad-apps/demo-fake-service/backend.nomad.hcl
nomad job run nomad-apps/demo-fake-service/frontend.nomad.hcl

# Configure Consul API Gateway
consul config write consul/peering/configs/api-gateway/listener.hcl
consul config write consul/peering/configs/api-gateway/httproute.hcl
```

## 🛍️ Google Cloud Microservices Demo

This project includes a complete Google Cloud microservices demo application that can be deployed on both Nomad and Kubernetes (GKE) platforms with Consul Connect service mesh integration.

### Features

- **11 Microservices**: Complete e-commerce application with frontend, backend services, and Redis
- **Dual Platform Support**: Available as both Nomad jobs and Kubernetes manifests
- **Consul Connect**: Full service mesh integration with automatic TLS
- **Load Balancing**: Traefik integration for HTTP routing
- **Health Checks**: Comprehensive health monitoring for all services
- **Service Discovery**: Consul-native service registration and discovery

### Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Traefik LB    │    │   Consul UI     │
│   (Port 80)     │    │   (Port 8500)   │
└─────────────────┘    └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         │              │ Consul Connect  │
         │              │  Service Mesh   │
         │              └─────────────────┘
         │                       │
┌─────────────────┐              │
│    Frontend     │◄─────────────┘
│   (Port 8080)   │
└─────────────────┘
         │
    ┌────┴────┐
    │ Backend │
    │Services │
    └────┬────┘
         │
┌─────────────────┐
│   Redis Cart    │
│   (Port 6379)   │
└─────────────────┘
```

### Services Included

1. **Frontend** - Web UI (React-based)
2. **Product Catalog** - Product information service
3. **Recommendation** - ML-powered product recommendations
4. **Cart Service** - Shopping cart management
5. **Checkout Service** - Order processing
6. **Payment Service** - Payment processing
7. **Email Service** - Email notifications
8. **Shipping Service** - Shipping calculations
9. **Ad Service** - Advertisement service
10. **Currency Service** - Currency conversion
11. **Redis** - Session and cart storage

### Deployment Options

#### Option 1: Nomad Deployment (Recommended)

```bash
# Deploy to both DC1 and DC2
task apps:deploy-microservices-demo-both

# Deploy to specific cluster
task apps:deploy-microservices-demo-dc1   # Deploy to DC1
task apps:deploy-microservices-demo-dc2   # Deploy to DC2

# Check deployment status
task apps:status-microservices-demo-both

# Manual deployment
cd nomad-apps/microservices-demo
./deploy-all.sh        # Deploy services individually (recommended)
./deploy-monolith.sh   # Deploy as single job
```

#### Option 2: Kubernetes (GKE) Deployment

```bash
# Deploy to both GKE clusters (all namespaces)
task gke:deploy-microservices-all

# Deploy to specific cluster
task gke:deploy-microservices-west1       # k8s-west1 partition
task gke:deploy-microservices-southwest1  # k8s-southwest1 partition

# Check status
task gke:status-microservices
task gke:get-frontend-urls

# Manual deployment
cd consul/admin-partitions/manifests/microservices-demo
./deploy-all.sh        # Deploy to both clusters
./deploy-k8s-west1.sh  # Deploy to k8s-west1 partition only
```

### Access Points

#### Nomad Deployment
- **Frontend**: Via Traefik load balancer
- **Services**: Internal service mesh communication
- **Monitoring**: Consul UI shows all registered services

#### Kubernetes Deployment
- **Frontend**: External LoadBalancer per namespace
- **Services**: Cross-namespace and cross-partition communication
- **Monitoring**: Each environment has its own frontend LoadBalancer

### Resource Requirements

- **Nomad**: ~1.2 CPU cores, ~1.5GB memory total
- **Kubernetes**: ~1.5 CPU cores, ~2GB memory per namespace
- **Network**: Bridge networking with service mesh sidecars
- **Storage**: Redis uses local ephemeral storage

### Cleanup

```bash
# Remove from Nomad clusters
task apps:cleanup-microservices-demo-both

# Remove from Kubernetes clusters  
cd consul/admin-partitions/manifests/microservices-demo
kubectl delete -f k8s-west1/development/microservices-demo.yaml
kubectl delete -f k8s-west1/testing/microservices-demo.yaml
# ... (repeat for all namespaces)
```

### File Locations

- **Nomad Jobs**: `nomad-apps/microservices-demo/`
- **Kubernetes Manifests**: `consul/admin-partitions/manifests/microservices-demo/`
- **Documentation**: Each directory contains detailed README files

## 🔗 Consul Cluster Peering

Once both clusters are deployed and running, you can configure cluster peering to enable cross-datacenter service mesh connectivity, load balancing, and failover capabilities.

### Quick Peering Setup

```bash
# 1. Get environment setup instructions
task peering:env-setup

# 2. Set environment variables for both clusters (copy/paste from above)
export DC1_CONSUL_ADDR=http://[DC1_IP]:8500
export DC1_NOMAD_ADDR=http://[DC1_IP]:4646
# ... etc (see output from peering:env-setup)

# 3. Start peering setup (phases 1-8)
task peering:setup

# 4. Establish peering connection
task peering:establish

# 5. Complete peering configuration (phases 9-13)
task peering:complete

# 6. Verify peering works
task peering:verify
```

### Advanced Peering Features

```bash
# Configure failover with sameness groups (recommended)
task peering:sameness-groups

# Or configure service resolver for failover
task peering:service-resolver

# Check peering status
task status                    # Shows peering status if env vars set

# Clean up peering
task peering:cleanup
```

### What Cluster Peering Provides

- **Cross-Datacenter Service Discovery**: Services in DC1 can discover and connect to services in DC2
- **Service Mesh Connectivity**: Secure, encrypted communication between services across clusters
- **Load Balancing**: Distribute traffic across multiple datacenters
- **Failover**: Automatic failover to secondary datacenter when primary is unavailable
- **API Gateway**: Single entry point routing traffic to services across both clusters

### Detailed Setup Guide

For detailed step-by-step instructions, including all configuration phases, troubleshooting, and advanced scenarios:

📖 **[Consul Peering Setup Guide](consul/peering/README.md)**

## 🔧 Key Features

### Enterprise Security
- **ACL System**: Bootstrap tokens, fine-grained permissions
- **TLS Encryption**: All HashiCorp services encrypted in transit
- **Service Mesh**: Consul Connect for zero-trust networking
- **Firewall Rules**: Restricted access, internal communication secured

### High Availability
- **Instance Groups**: Auto-healing, rolling updates, zone distribution
- **Load Balancers**: Multi-tier (GCP Global + Traefik)
- **Health Checks**: Application and infrastructure monitoring
- **Backup Strategy**: Persistent disks, stateful configurations

### Monitoring & Observability
- **Prometheus**: Metrics collection from all HashiCorp services
- **Grafana**: Pre-configured dashboards for Consul, Nomad, and infrastructure
- **Traefik**: Request routing, load balancing, and traffic metrics
- **Logging**: Centralized via systemd journal

## 📊 Terraform Outputs

The deployment provides comprehensive outputs:

```bash
# View all outputs
terraform output

# Specific information
terraform output cluster_info          # Basic cluster details
terraform output hashistack_urls      # Consul/Nomad access URLs  
terraform output monitoring_urls      # Grafana/Prometheus URLs
terraform output server_nodes         # Server instance group info
terraform output client_nodes         # Client instance groups info
terraform output auth_tokens          # Enterprise tokens (sensitive)
terraform output quick_commands       # Useful management commands
terraform output load_balancers       # Load balancer IP addresses
```

### Load Balancer Access Points

Each cluster provides two load balancer IPs for different services:

```bash
# Get load balancer IPs
terraform output load_balancers

# Direct IP access (when DNS is not configured)
# Global LB (HashiCorp Stack)
http://<global_lb_ip>:8500    # Consul UI
http://<global_lb_ip>:4646    # Nomad UI

# Clients LB (Applications & Monitoring)
http://<clients_lb_ip>:3000   # Grafana (admin/admin)
http://<clients_lb_ip>:8080   # Traefik Dashboard
http://<clients_lb_ip>:8081   # API Gateway
http://<clients_lb_ip>:9090   # Prometheus
```

### Port Configuration

The load balancer exposes the following ports (limited to 5 by GCP):
- **Port 80**: HTTP traffic
- **Port 3000**: Grafana dashboard
- **Port 8080**: Traefik dashboard
- **Port 8081**: Consul API Gateway (NEW)
- **Port 9090**: Prometheus metrics

*Note: HTTPS (port 443) removed to stay within GCP's 5-port limit for demo purposes.*

## 🔐 Security Considerations

- **Enterprise Licenses**: Stored as sensitive Terraform variables
- **Bootstrap Tokens**: Auto-generated, marked sensitive in outputs
- **TLS Certificates**: Self-signed CA, server certificates auto-generated
- **Network Security**: VPC isolation, firewall rules, internal communication only
- **Access Control**: ACLs enabled by default, least-privilege principles

## 🛠️ Multi-Cluster Operations

### Taskfile Management
```bash
# Infrastructure management
task infra:deploy-both          # Deploy both clusters
task infra:destroy-both         # Destroy both clusters
task deploy-all                 # Deploy DC1, DC2, and GKE clusters

# Application management
task apps:deploy-traefik        # Deploy Traefik to both clusters
task apps:deploy-monitoring     # Deploy Prometheus + Grafana to both clusters
task apps:deploy-demo-apps      # Deploy demo applications to both clusters

# Status and monitoring
task apps:show-urls             # Show all service URLs
task infra:eval-vars            # Show environment variables for both clusters
task infra:status-dc1           # Show DC1 cluster status
task infra:status-dc2           # Show DC2 cluster status
task status                     # Show overall infrastructure status
```

### Cluster Management
```bash
# Check cluster health (DC1)
task infra:eval-vars-dc1 && eval "$(task infra:eval-vars-dc1 --silent)"
consul members
nomad server members
nomad node status

# Check cluster health (DC2)
task infra:eval-vars-dc2 && eval "$(task infra:eval-vars-dc2 --silent)"
consul members
nomad server members
nomad node status

# View job status
nomad job status
nomad alloc status <allocation-id>

# Scale applications
nomad job scale <job-name> <count>
```

### Troubleshooting
```bash
# Check service status on nodes (SSH required)
task infra:ssh-dc1-server  # SSH to DC1 server
task infra:ssh-dc2-server  # SSH to DC2 server

# On server nodes:
sudo systemctl status consul
sudo systemctl status nomad
sudo journalctl -u consul -f
sudo journalctl -u nomad -f

# View application logs
nomad alloc logs <allocation-id>
nomad alloc logs -f <allocation-id>
```

### Infrastructure Updates
```bash
# Update specific cluster
cd clusters/dc1/terraform
terraform plan
terraform apply

# Update both clusters
task infra:deploy-both

# Rolling update (managed instance groups handle this automatically)
# Check status in GCP Console > Compute Engine > Instance Groups
```

## 📁 Multi-Cluster Project Structure

```
├── Taskfile.yml                      # Main task automation (modular structure)
├── tasks/                            # Modular taskfile sections
│   ├── infrastructure.yml            # Infrastructure deployment tasks
│   ├── gke.yml                      # GKE cluster management tasks
│   ├── applications.yml             # Application deployment tasks
│   └── peering.yml                  # Consul cluster peering tasks
├── docs/                              # Documentation and assets
│   └── images/                        # Architecture diagrams and images
├── clusters/                          # Nomad + Consul on GCE
│   ├── dc1/                          # DC1 cluster (europe-southwest1)
│   │   ├── terraform/                # DC1 infrastructure
│   │   │   ├── main.tf               # Core networking, load balancers, DNS
│   │   │   ├── instances.tf          # Instance groups, templates, configs
│   │   │   ├── variables.tf          # Input variables
│   │   │   ├── outputs.tf            # Structured outputs
│   │   │   └── consul.tf             # Consul-specific resources
│   │   └── jobs/                     # DC1 Nomad job definitions
│   │       └── monitoring/           # Monitoring stack jobs
│   │           ├── traefik.hcl       # Load balancer
│   │           ├── prometheus.hcl    # Metrics collection
│   │           └── grafana.hcl       # Monitoring dashboard
│   └── dc2/                          # DC2 cluster (europe-west1)
│       ├── terraform/                # DC2 infrastructure (identical to DC1)
│       └── jobs/                     # DC2 Nomad job definitions (identical to DC1)
├── consul/                           # Consul configurations
│   ├── admin-partitions/             # Admin Partitions on GKE
│   │   ├── terraform/                # Infrastructure as code
│   │   │   ├── server-east/          # Consul servers (us-east1)
│   │   │   ├── server-west/          # Consul servers (us-west1)
│   │   │   ├── client-east/          # k8s-east partition (us-east4)
│   │   │   └── client-west/          # k8s-west partition (us-west2)
│   │   ├── helm/                     # Consul Helm configurations
│   │   │   ├── server-east/          # Server cluster configurations
│   │   │   ├── server-west/          # Server cluster configurations
│   │   │   ├── client-east/          # Admin partition client configs
│   │   │   └── client-west/          # Admin partition client configs
│   │   ├── apps/                     # Demo applications
│   │   │   └── fake-service/         # Frontend/backend services
│   │   ├── configs/                  # Gateway configurations
│   │   │   ├── api-gateway/          # Modern API Gateway (v2)
│   │   │   └── mesh-gateway/         # Cross-partition communication
│   │   ├── Taskfile.yml              # Admin partitions automation
│   │   └── README.md                 # Admin partitions guide
│   └── peering/                      # Consul Connect and peering configs
│       └── configs/
│           └── api-gateway/
│               ├── listener.hcl      # API Gateway listener (port 8081)
│               └── httproute.hcl     # HTTP routing rules
├── packer/                           # Custom image builds
│   └── gcp/                         # GCP-specific Packer configs
├── nomad-apps/                       # Application definitions
│   ├── api-gw.nomad/                # Consul API Gateway
│   │   └── api-gw.nomad.hcl         # API Gateway Nomad job
│   ├── demo-fake-service/           # Demo microservices
│   │   ├── backend.nomad.hcl        # Backend API services
│   │   └── frontend.nomad.hcl       # Frontend service
│   ├── monitoring/                  # Monitoring stack
│   │   ├── traefik.hcl             # Load balancer
│   │   ├── prometheus.hcl          # Metrics collection
│   │   └── grafana.hcl             # Monitoring dashboard
│   └── terramino.hcl               # Demo Tetris game
└── scripts/                         # Deployment automation
```

### Key Architecture Notes

- **Identical Configurations**: DC1 and DC2 have identical Terraform configurations and Nomad jobs
- **Regional Separation**: DC1 deploys to europe-southwest1, DC2 deploys to europe-west1
- **Centralized Management**: Taskfile provides unified commands for both clusters
- **Independent Operation**: Each cluster operates independently with its own resources
- **Consistent Naming**: Resources are named with cluster-specific prefixes (gcp-dc1, gcp-dc2)
- **HCP Terraform Integration**: Uses workspaces `DB-cluster-1` and `DC-cluster-2`
- **Custom Images**: Built with Packer containing Consul Enterprise 1.21.0+ent and Nomad Enterprise 1.10.0+ent

## 📁 Project Structure

```
nomad-consul-terramino/
├── README.md                          # This file
├── Taskfile.yml                       # Main task orchestration
├── CLAUDE.md                          # Claude AI development guidance
├── clusters/                          # Multi-cluster infrastructure
│   ├── dc1/                          # DC1 cluster (europe-southwest1)
│   │   ├── terraform/                # Terraform infrastructure
│   │   └── jobs/                     # Nomad job definitions
│   ├── dc2/                          # DC2 cluster (europe-west1)
│   │   ├── terraform/                # Terraform infrastructure
│   │   └── jobs/                     # Nomad job definitions
│   ├── gke-europe-west1/             # GKE cluster (k8s-west1 partition)
│   │   ├── terraform/                # GKE infrastructure
│   │   └── helm/                     # Consul Helm charts
│   └── gke-southwest/                # GKE cluster (k8s-southwest1 partition)
│       ├── terraform/                # GKE infrastructure
│       └── helm/                     # Consul Helm charts
├── nomad-apps/                       # Nomad job applications
│   ├── microservices-demo/           # Google Cloud microservices demo
│   │   ├── microservices-demo.nomad.hcl    # Complete stack job
│   │   ├── frontend.nomad.hcl              # Frontend service
│   │   ├── backend-services.nomad.hcl      # Backend services
│   │   ├── redis-cart.nomad.hcl            # Redis cache
│   │   ├── deploy-all.sh                   # Deployment script
│   │   └── README.md                       # Detailed documentation
│   ├── demo-fake-service/            # Demo applications
│   ├── monitoring/                   # Monitoring stack
│   └── api-gw.nomad/                # API Gateway
├── consul/                           # Consul configuration
│   └── admin-partitions/             # Admin partitions demo
│       ├── README.md                 # Step-by-step deployment guide
│       ├── policies/                 # ACL policies
│       └── manifests/                # Kubernetes manifests
│           └── microservices-demo/   # K8s microservices demo
│               ├── k8s-west1/        # k8s-west1 partition manifests
│               ├── k8s-southwest1/   # k8s-southwest1 partition manifests
│               └── deploy-all.sh     # Deployment script
├── tasks/                            # Modular task definitions
│   ├── infrastructure.yml           # Infrastructure deployment
│   ├── applications.yml             # Application deployment
│   ├── gke.yml                     # GKE management
│   ├── peering.yml                 # Consul peering
│   └── packer.yml                  # Image building
├── packer/                          # Custom image building
│   ├── gcp/                        # GCP Packer templates
│   └── aws/                        # AWS Packer templates
└── docs/                           # Documentation
    └── images/                     # Architecture diagrams
```

### Key Directories

- **`clusters/`**: Contains infrastructure code for each cluster (DC1, DC2, GKE)
- **`nomad-apps/`**: Nomad job definitions for applications and services
- **`consul/admin-partitions/`**: Kubernetes manifests and admin partitions configuration
- **`tasks/`**: Modular Taskfile definitions organized by function
- **`packer/`**: Custom image building templates for GCP and AWS

### Application Deployment Files

The project provides applications in multiple formats:
- **Nomad Jobs**: Located in `nomad-apps/` for VM-based deployments
- **Kubernetes Manifests**: Located in `consul/admin-partitions/manifests/` for GKE deployments
- **Both platforms**: Support the same Google Cloud microservices demo application

## 🤝 Contributing

This is a demonstration repository. For production use:

1. Review and adapt security configurations
2. Implement proper backup strategies  
3. Configure monitoring alerts
4. Establish CI/CD pipelines
5. Review network security policies

## 📝 License

This project is for demonstration purposes. Ensure you have proper HashiCorp Enterprise licenses before deploying.

---

**Note**: This deployment creates billable GCP resources. Remember to run `terraform destroy` when done testing.
