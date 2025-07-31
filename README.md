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

## 🎉 Current Status (Deployment Ready)

This repository includes **working clusters** with all issues resolved:

**✅ Infrastructure Status:**
- **DC1 (europe-north1):** 3 Consul servers + 2 clients running
- **DC2 (europe-central2):** 3 Consul servers + 2 clients running  
- **Both clusters:** Consul Enterprise v1.21.2+ent healthy and connected
- **Templates:** Fixed Consul configuration issues for future deployments

**🚀 Available Features:**
- **Core Infrastructure:** `task deploy-both-dc` (working)
- **Environment Setup:** `task eval-both` (required)
- **Cluster Peering:** `task -t tasks/peering.yml help`
- **Admin Partitions:** `task -t tasks/admin-partitions.yml help`
- **Automated Boundary:** `task -t tasks/boundary-auto.yml help` (new!)
- **CTS Integration:** `task -t tasks/cts.yml help`

**📖 Quick Commands:**
```bash
# Get environment variables (copy/paste to shell)
task eval-both

# Configure Nomad-Consul integration (required)
task setup-consul-nomad-both

# Access cluster UIs
task show-all-urls
```

## Prerequisites

Before deploying this stack, ensure you have:

**Required Tools:**
- Terraform >= 1.0.0
- Google Cloud SDK (gcloud) authenticated
- Packer >= 1.8.0 (for custom image builds)
- kubectl (for GKE components)
- Task (taskfile) - optional but recommended

**Required Permissions:**
- GCP Project Owner or Editor role
- Ability to create compute instances, networks, and load balancers
- DNS zone management (if using custom domains)

**Required Licenses:**
- Consul Enterprise license
- Nomad Enterprise license

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

**Execute on both DC1 and DC2 servers AFTER setting environment variables:**
```bash
# SSH to each cluster's server nodes
task ssh-dc1-server  # or task ssh-dc2-server

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

### 5. Current Deployment Status

After completing the infrastructure deployment and post-configuration steps:

**✅ DC1 Cluster (europe-north1):**
- 3 Consul servers + 2 clients running
- Consul Enterprise v1.21.2+ent healthy
- Full cluster connectivity established

**✅ DC2 Cluster (europe-central2):**  
- 3 Consul servers + 2 clients running
- Consul Enterprise v1.21.2+ent healthy
- Full cluster connectivity established

**🔧 Fixed Issues:**
- Resolved Consul startup failures caused by invalid `limits.grpc_max_requests_per_stream` configuration
- Updated Terraform templates to prevent future occurrences
- Both clusters now fully operational

## Functionality Breakdown

### Multi-Cluster Peering

For federating multiple Consul datacenters with cluster peering:

**Documentation:** [`consul/peering/README.md`](consul/peering/README.md)

**Quick Start:**
```bash
# Deploy both clusters first
task deploy-both

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
3. **Boundary variables** configured in Terraform Cloud or tfvars:
   ```bash
   # HCP Boundary Configuration
   hcp_boundary_cluster_id = "your-boundary-cluster-id"
   boundary_addr = "https://your-cluster.boundary.hashicorp.cloud"
   boundary_auth_method_id = "your-auth-method-id" 
   boundary_admin_login_name = "admin"
   boundary_admin_password = "your-boundary-password" # Use as sensitive variable
   
   # HCP Credentials (reuse from existing variable set)
   hcp_client_id = "your-hcp-client-id"
   hcp_client_secret = "your-hcp-client-secret" # Sensitive
   
   # Remote State Configuration (for workspace integration)
   dc1_remote_state_config = {
     organization = "your-hcp-terraform-org"
     workspaces = { name = "your-dc1-workspace-name" }
   }
   dc2_remote_state_config = {
     organization = "your-hcp-terraform-org"
     workspaces = { name = "your-dc2-workspace-name" }
   }
   ```

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

## Directory Structure

```
├── clusters/                    # Infrastructure deployments
│   ├── dc1/terraform/          # Primary cluster (europe-north1)
│   ├── dc2/terraform/          # Secondary cluster (europe-central2)
│   └── gke-*/                  # GKE clusters for admin partitions
├── consul/                     # Consul-specific configurations
│   ├── admin-partitions/       # Admin partitions setup
│   ├── peering/               # Cluster peering configuration
│   └── cts/                   # Consul-Terraform-Sync
├── boundary/                   # Boundary integration (optional)
├── packer/                     # Custom image builds
├── nomad-apps/                # Nomad job definitions
└── scripts/                   # Automation and helper scripts
```

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

## Security Considerations

**Enterprise Features:**
- ACLs enabled by default for Consul and Nomad
- TLS encryption for all inter-service communication
- Enterprise licenses required for advanced features

**Network Security:**
- Firewall rules restrict access to necessary ports only
- Internal communication uses private networks
- Service mesh provides zero-trust networking

**Secrets Management:**
- Sensitive variables marked as sensitive in Terraform
- Nomad secure variables for application secrets
- Consul ACL tokens for service authentication

## Troubleshooting

**Common Issues:**

1. **License Errors**: Ensure valid enterprise licenses are configured
2. **Image Not Found**: Run `task build-images` before deployment
3. **DNS Issues**: Verify DNS zone configuration and permissions
4. **Connectivity**: Check firewall rules and network configuration
5. **SSH Access Denied**: Ensure `ssh_public_key` variable is configured in Terraform Cloud
6. **Boundary Connection Closed**: Verify both `ssh_public_key` and `ssh_private_key` are configured

**Useful Commands:**
```bash
# Check service status on nodes
sudo systemctl status consul
sudo systemctl status nomad

# View service logs
sudo journalctl -u consul -f
sudo journalctl -u nomad -f

# Check cluster membership
consul members
nomad server members
nomad node status
```

**Getting Help:**
- Check individual README files in each directory for specific functionality
- Review Terraform outputs for connection information
- Use `task status` for overall cluster health
- Examine logs on individual instances for detailed debugging

## Contributing

This repository follows infrastructure-as-code best practices:
- All changes should be made through Terraform
- Test changes in development environments first
- Follow HashiCorp configuration conventions
- Document new features and configurations

For specific functionality (peering, admin partitions, CTS, boundary), refer to the respective README files in each directory.