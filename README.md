# HashiCorp Enterprise Stack on Google Cloud Platform

Deploy a complete HashiCorp Consul Enterprise and Nomad Enterprise ecosystem on GCP for demos and proof-of-concepts.

## Why This Repository?

This repository automates the deployment of a production-like HashiCorp stack on GCP, complete with:
- Enterprise security features (ACLs, TLS, service mesh)
- Monitoring and observability (Prometheus, Grafana, Traefik)
- Multi-datacenter capabilities with cluster peering
- Admin partitions for multi-tenancy
- Infrastructure automation with HashiCorp Boundary

**⚠️ For demo and PoC purposes only - not for production use**

## Architecture Overview

![HLD](./docs/images/architecture-diagram.png)

**Components:**
- **Packer**: Builds custom VM images with HashiCorp tools pre-installed
- **Terraform**: Deploys infrastructure (networking, compute, load balancers)
- **Taskfile**: Orchestrates the entire deployment workflow
- **Consul Enterprise**: Service discovery, configuration, and service mesh
- **Nomad Enterprise**: Workload orchestration and scheduling

## Prerequisites

### Required Tools

| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| **Task** | v3.0+ | `brew install go-task` or [install guide](https://taskfile.dev/installation/) |
| **Terraform** | v1.5+ | `brew install terraform` or [download](https://www.terraform.io/downloads) |
| **Packer** | v1.9+ | `brew install packer` or [download](https://www.packer.io/downloads) |
| **Google Cloud SDK** | Latest | `brew install google-cloud-sdk` or [install guide](https://cloud.google.com/sdk/docs/install) |
| **kubectl** | v1.25+ | `brew install kubectl` (for GKE features) |

### GCP Setup

1. **Authenticate with Google Cloud:**
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Enable required APIs:**
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable dns.googleapis.com
   gcloud services enable container.googleapis.com
   ```

3. **Required IAM permissions:**
   - Compute Admin
   - DNS Administrator (if using custom domains)
   - Kubernetes Engine Admin (for GKE features)

### Enterprise Licenses

- **Consul Enterprise license** (required for admin partitions and CTS)
- **Nomad Enterprise license** (optional but recommended)

## Quick Start

### 1. Configure Variables

Set up your Terraform variables. You can use either HCP Terraform variable sets or local `.tfvars` files.

**Create variable sets in HCP Terraform or add to `terraform.auto.tfvars`:**

```hcl
# Project Configuration
gcp_project = "your-gcp-project-id"
gcp_region = "europe-north1"
cluster_name = "demo-hashistack"

# Enterprise Licenses
consul_license = "your-consul-enterprise-license"
nomad_license = "your-nomad-enterprise-license"

# SSH Access (REQUIRED)
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E... your-public-key"
ssh_username = "debian"

# Optional: Custom DNS
dns_zone = "your-dns-zone-name"
```

### 2. Build Images

Build custom VM images with HashiCorp tools pre-installed:

```bash
# Build images for your GCP project
task build-images
```

This step is **required** before deploying infrastructure.

### 3. Deploy Infrastructure

Choose your deployment strategy:

**Single datacenter:**
```bash
task deploy-dc1
```

**Multi-datacenter:**
```bash
task deploy-both-dc
```

**Complete deployment with monitoring:**
```bash
task deploy-dc1
task deploy-monitoring-dc1
```

### 4. Configure Environment

After deployment, set up your environment variables:

```bash
# Get environment variables for your cluster
task eval-dc1

# Copy and paste the output into your shell
# This configures CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN, NOMAD_ADDR, NOMAD_TOKEN
```

### 5. Complete Setup

Configure Nomad-Consul integration:

```bash
# Run this after setting environment variables
nomad setup consul -y

# Authenticate to Nomad UI
nomad ui -authenticate
```

## Deployment Workflows

### Basic Workflow
```bash
task build-images      # Build custom images
task deploy-dc1        # Deploy infrastructure
task eval-dc1          # Get connection details
# Copy environment variables to your shell
nomad setup consul -y  # Configure integration
```

### Advanced Multi-Cluster
```bash
task build-images      # Build custom images
task deploy-both-dc    # Deploy both datacenters
task eval-both         # Get connection details for both clusters
# Set up cluster peering
task -t consul/peering/Taskfile.yml consul:deploy-all
```

### With Admin Partitions
```bash
task build-images      # Build custom images
task deploy-dc1        # Deploy base infrastructure
task deploy-both-gke   # Deploy GKE clusters
# Set up admin partitions
task -t consul/admin-partitions/Taskfile.yml consul:deploy-all
```

## Available Tasks

### Infrastructure Management
- `task build-images` - Build HashiStack images with Packer
- `task deploy-dc1` - Deploy primary datacenter
- `task deploy-dc2` - Deploy secondary datacenter
- `task deploy-both-dc` - Deploy both datacenters
- `task destroy-dc1` - Destroy primary datacenter
- `task status` - Show cluster status

### Application Deployment
- `task deploy-monitoring-dc1` - Deploy Prometheus + Grafana
- `task deploy-traefik-dc1` - Deploy Traefik load balancer

### Cluster Operations
- `task eval-dc1` - Get environment variables for DC1
- `task eval-both` - Get environment variables for both clusters
- `task ssh-dc1-server` - SSH to DC1 server node
- `task show-dc1-info` - Show DC1 cluster information
- `task get-all-ips` - Get all server and client IPs

### Advanced Features
- `task -t consul/peering/Taskfile.yml help` - Cluster peering commands
- `task -t consul/admin-partitions/Taskfile.yml help` - Admin partitions commands
- `task -t tasks/boundary-auto.yml help` - Boundary integration commands

## Access Your Services

After deployment, access your services:

**HashiCorp UIs:**
- **Consul**: `http://<server-ip>:8500`
- **Nomad**: `http://<server-ip>:4646`

**Monitoring:**
- **Grafana**: `http://<client-ip>:3000` (admin/admin)
- **Prometheus**: `http://<client-ip>:9090`
- **Traefik**: `http://<client-ip>:8080`

**Get service URLs:**
```bash
task show-dc1-info    # Shows all URLs and connection details
```

## Advanced Features

### Cluster Peering
Set up secure communication between multiple datacenters:
```bash
task -t consul/peering/Taskfile.yml consul:deploy-all
```
📖 **Documentation:** [`consul/peering/README.md`](consul/peering/README.md)

### Admin Partitions
Deploy multi-tenant Consul partitions on GKE:
```bash
task -t consul/admin-partitions/Taskfile.yml consul:deploy-all
```
📖 **Documentation:** [`consul/admin-partitions/README.md`](consul/admin-partitions/README.md)

### Boundary Integration
Secure remote access to infrastructure:
```bash
task -t tasks/boundary-auto.yml boundary:setup-full
```
📖 **Documentation:** [`boundary/README.md`](boundary/README.md)

### Consul-Terraform-Sync
Infrastructure automation based on service changes:
📖 **Documentation:** [`consul/cts/README.md`](consul/cts/README.md)

## Troubleshooting

### Common Issues

**Packer build fails:**
- Ensure GCP APIs are enabled
- Check GCP credentials: `gcloud auth list`
- Verify project permissions

**Terraform apply fails:**
- Check variable configuration
- Ensure enterprise licenses are valid
- Verify GCP quotas and limits

**Cannot access services:**
- Run `task eval-dc1` and copy environment variables
- Check firewall rules in GCP Console
- Verify instances are running: `task status`

**SSH access issues:**
- Ensure `ssh_public_key` is configured in variables
- Check GCP instance metadata for SSH keys
- Use `task ssh-dc1-server` for direct access

### Getting Help

1. **Check task help:** `task --list`
2. **Review logs:** Check GCP Console for instance logs
3. **Verify configuration:** Use `task status` to check cluster health
4. **Read component docs:** Each feature has detailed README files

## Architecture Details

This repository implements several key patterns:

- **Infrastructure as Code**: Terraform modules for repeatable deployments
- **Immutable Infrastructure**: Packer builds base images with software pre-installed
- **Automation**: Taskfile orchestrates complex multi-step deployments
- **Security**: Enterprise ACLs, TLS encryption, and service mesh by default
- **Observability**: Built-in monitoring with Prometheus and Grafana
- **Scalability**: Multi-datacenter and multi-partition support

The result is a production-like HashiCorp stack that's perfect for demos, training, and proof-of-concepts.