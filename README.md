# HashiCorp Enterprise Stack on Google Cloud Platform

## Overview

A demonstration deployment of HashiCorp Consul Enterprise and Nomad Enterprise on Google Cloud Platform with monitoring, security, and enterprise features. 
This repository provides infrastructure-as-code for deploying a complete HashiCorp stack ONLY for demo and PoC purposes. Do not deploy this in Production.

### What This Repository Deploys

This repository creates a complete HashiCorp enterprise ecosystem on GCP including:

**Core Infrastructure:**
- 3 x Consul/Nomad server nodes (combined server architecture)
- 2-4 x Nomad client nodes for application workloads
- GCP Load Balancers with DNS integration

**HashiCorp Services:**
- Consul Enterprise 1.21.0+ent with ACLs and TLS
- Nomad Enterprise 1.10.3+ent with ACLs and secure variables
- Consul Connect service mesh for zero-trust networking
**Applications and Monitoring:**
- Traefik v3.0 API Gateway and load balancer
- Prometheus metrics collection
- Grafana dashboards and alerting
- Demo applications (Terramino game, fake services)

**Security Features:**
- Enterprise ACLs for both Consul and Nomad
- TLS encryption for all HashiCorp services
- Service mesh with Consul Connect
- Firewall rules and network segmentation

# High Level Architecture

![HLD](./docs/images/architecture-diagram.png)


## Prerequisites

Before deploying this stack, ensure you have:

**Required Tools:**
- Terraform >= 1.0.0
- Google Cloud SDK (gcloud) authenticated
- Packer >= 1.8.0 (for custom image builds)
- kubectl (for GKE components)
- Task ([(https://taskfile.dev/)]) - 
**Required Permissions:**
- GCP Project Owner or Editor role
- Ability to create compute instances, networks, and load balancers
- DNS zone management (if using custom domains)

**Required Licenses:**
- Consul Enterprise license ( only if using admin-partitions or CTS)
- Nomad Enterprise license ( optional if not using namespaces but recommended)

**GCP Setup:**
- GCP project with billing enabled
- Compute Engine API enabled
- DNS API enabled (if using custom domains)
- Service account with appropriate permissions

## How to run in tasks

### 1. Configure Variable Sets (HCP Terraform) or terraform.auto.tfvars

If using HCP Terraform, create these variable sets:

**HashiStack Common Variables:**
```
consul_license = "your-consul-enterprise-license"
nomad_license = "your-nomad-enterprise-license"
consul_version = "1.21.0+ent"
nomad_version = "1.10.3+ent"
consul_bootstrap_token = "ConsulR0cks" # Change in production
enable_acls = true
```
**only if using boundary**
```
boundary_addr="https://YOUR-BOUNDARY-CLUSTER.boundary.hashicorp.cloud"
boundary_auth_method_id="your-auth-method-id"
boundary_admin_login_name="admin"
boundary_admin_password="your-boundary-password"
```

**GCP Common Variables:**
```
gcp_project = "your-gcp-project-id"  
gcp_region = "europe-north1"
machine_type_server = "e2-standard-2"
machine_type_client = "e2-standard-4"
```

**SSH Access Variables (REQUIRED):**
```
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E... your-public-key"
ssh_private_key = "-----BEGIN PRIVATE KEY-----\n..." # For Boundary integration
ssh_username = "debian" # Default, can be customized
```

**Workspace-Specific Variables:**
```
dns_zone = "your-dns-zone-name" # Optional
cluster_name = "your-cluster-name"
```

If not using HCP Terraform, create `terraform.auto.tfvars` files in each cluster directory with these variables.

### 2. Build Custom Images (Required)

Build HashiCorp images with Packer before deploying infrastructure:

```bash
# Build images for your GCP project
task build-images

# Or manually:
cd packer/gcp
packer build .
```

This creates custom images with Consul and Nomad pre-installed and configured.

### 3. Deploy Infrastructure

Choose your deployment approach:

**Single Cluster (DC1):**
```bash
task deploy-dc1
```

**Multi-Cluster (DC1 + DC2):**
```bash
task deploy-both
```

**With Applications:**
```bash
task deploy-dc1
task deploy-monitoring-dc1
task deploy-traefik-dc1
task deploy-demo-apps-dc1
```

### 4. Post-Deployment Configuration (REQUIRED)

After deploying clusters, complete these **critical** configuration steps:

#### 4.1 Setup Environment Variables

**Export environment variables to connect to your clusters:**
```bash
# Get environment variables for both clusters
task eval-both

# Copy and paste the output into your shell
# This configures CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN, NOMAD_ADDR, NOMAD_TOKEN
```

**Note**: SSH access requires the `ssh_public_key` and `ssh_private_key` variables to be configured in your Terraform Cloud workspace. Without these, you cannot SSH directly to instances or use Boundary SSH connections.

#### 4.2 Configure Nomad-Consul Integration

# Configure Nomad workload identity with Consul
nomad setup consul -y
```

#### 4.3 Authenticate to Nomad UI

**For UI access, authenticate with Nomad:**
```bash
# This opens the browser and authenticates using your NOMAD_TOKEN
nomad ui -authenticate
```

These steps are **required** before setting up cluster peering or deploying applications that use service mesh features.

## Functionality Breakdown

### Multi-Cluster Peering

For federating multiple Consul datacenters with cluster peering:

**Documentation:** [`consul/peering/README.md`](consul/peering/README.md)

**Quick Start:**
```
# Setup peering
task peering:setup
task peering:establish
task peering:complete
```

### Admin Partitions (Multi-Tenancy)

For deploying Consul Enterprise admin partitions on GKE:

**Documentation:** [`consul/admin-partitions/README.md`](consul/admin-partitions/README.md)

**Quick Start:**
```bash
# Deploy base infrastructure
task deploy-dc1

# Deploy GKE clusters with admin partitions
task deploy-all-gke
task gke-setup-secrets
task gke-deploy-consul
```

### Consul Terraform Sync (CTS)

For infrastructure automation with Consul-Terraform-Sync:

**Documentation:** [`consul/cts/README.md`](consul/cts/README.md)

**Features:**
- Automated DNS updates based on service registration
- Infrastructure provisioning triggered by service changes
- Integration with external systems

### Boundary Integration (Optional)

For secure remote access to infrastructure with HashiCorp Boundary:

**Documentation:** [`boundary/README.md`](boundary/README.md)

#### Prerequisites:
1. **HCP Boundary cluster** running and accessible
2. **SSH keys** configured in Terraform Cloud workspace variables:
   - `ssh_public_key` - Your SSH public key content (required for all clusters)
   - `ssh_private_key` - Your SSH private key content (sensitive, required for Boundary)
   - `ssh_username` - SSH username (defaults to "debian")


#### Automated Deployment:
```bash
# Complete automated setup (recommended)
task -t tasks/boundary-auto.yml setup-full

# Or step-by-step:
task -t tasks/boundary-auto.yml discover-targets    # Auto-discover infrastructure
task -t tasks/boundary-auto.yml deploy-complete     # Deploy with credential injection
task -t tasks/boundary-auto.yml list-all-targets    # List all configured targets
```

#### Quick Connection Examples:
```bash
# Connect to DC1 server via Boundary
task -t tasks/boundary-auto.yml connect-dc1-server

# Connect to DC2 client via Boundary  
task -t tasks/boundary-auto.yml connect-dc2-client

# Manual connection using target ID
boundary connect ssh -target-id <target-id>
```

**Features:**
- **Auto-discovery** of all DC1 and DC2 infrastructure (servers + clients)
- **Automatic credential injection** using workspace SSH keys
- **Target management** with host catalogs and credential stores
- **Quick connection helpers** for common access patterns



## Common Commands

**Infrastructure Management:**
```bash
task deploy-dc1              # Deploy primary cluster
task deploy-dc2              # Deploy secondary cluster  
task deploy-both             # Deploy both clusters
task destroy-dc1             # Destroy primary cluster
task status                  # Check cluster status
```

**Application Deployment:**
```bash
task deploy-monitoring       # Deploy Prometheus + Grafana
task deploy-traefik         # Deploy Traefik load balancer
task deploy-demo-apps       # Deploy sample applications
```

**Cluster Operations:**
```bash
task get-server-ips         # Get instance IP addresses
task ssh-dc1-server         # SSH to DC1 server
task show-urls              # Display all service URLs
task eval-vars              # Show environment variables
```

**Peering and Federation:**
```bash
task peering:setup          # Initialize cluster peering
task peering:establish      # Create peering connection
task peering:verify         # Verify peering status
```

## Access Points

After deployment, services are accessible at:

**HashiCorp UIs:**
- Consul: `http://consul.your-domain.com:8500` or load balancer IP
- Nomad: `http://nomad.your-domain.com:4646` or load balancer IP

**Monitoring:**
- Grafana: `http://grafana.your-domain.com:3000` (admin/admin)
- Prometheus: `http://prometheus.your-domain.com:9090`
- Traefik: `http://traefik.your-domain.com:8080`

**Applications:**
- Terramino Game: `http://terramino.your-domain.com`
- Demo Services: Various ports on client load balancer

