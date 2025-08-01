# HashiCorp Boundary Integration

Secure access to your HashiStack infrastructure without SSH keys, VPN connections, or network exposure.

**📖 [Back to Main README](../README.md)**

## Why Boundary Integration?

Boundary provides zero-trust secure access to your HashiStack infrastructure:

- **Eliminate SSH key distribution** with automatic credential injection
- **Remove VPN complexity** with direct secure tunnels
- **Centralized access control** with role-based permissions
- **Complete audit trail** with session recording and logging
- **Just-in-time access** with dynamic credential injection
- **Multi-factor authentication** support for enhanced security

This integration automatically discovers your deployed infrastructure and creates secure SSH access targets for all servers and clients.

## Architecture Overview

```
Boundary HCP Cluster
         │
    ┌────▼────┐
    │ Boundary │ ◄─── Admin Authentication
    │ Proxy    │
    └────┬────┘
         │ Encrypted Tunnels
    ┌────▼────┐    ┌────────────┐
    │ DC1     │    │ DC2        │
    │ Servers │    │ Servers    │
    │ Clients │    │ Clients    │
    └─────────┘    └────────────┘
```

**Components:**
- **HCP Boundary Cluster**: Managed control plane for secure access
- **Automatic Discovery**: Finds deployed infrastructure via GCP APIs
- **Host Catalogs**: Organize infrastructure by datacenter and function
- **SSH Targets**: Secure access points with credential injection
- **Role-Based Access**: Different permissions for dev, ops, and admin users

## Prerequisites

### Required Infrastructure
- **HCP Boundary cluster** (or self-managed Boundary)
- **HashiStack infrastructure** deployed (DC1/DC2 clusters)
- **SSH keys configured** in Terraform Cloud workspace variables

### Required Credentials
- **Boundary admin credentials** for configuration
- **HCP client credentials** for API access
- **SSH private key** for credential injection
- **GCP permissions** for infrastructure discovery

### Required Variables

**SSH Configuration (Critical):**
```hcl
# Required in Terraform Cloud workspace or terraform.auto.tfvars
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E... your-public-key"
ssh_private_key = "-----BEGIN PRIVATE KEY-----\n..." # Sensitive variable
ssh_username = "debian" # Default username
```

**Boundary Configuration:**
```hcl
# HCP Boundary cluster details
hcp_boundary_cluster_id = "your-boundary-cluster-id"
boundary_addr = "https://your-cluster.boundary.hashicorp.cloud"
boundary_auth_method_id = "your-auth-method-id"
boundary_admin_login_name = "admin"
boundary_admin_password = "your-boundary-password" # Sensitive

# HCP API credentials
hcp_client_id = "your-hcp-client-id"
hcp_client_secret = "your-hcp-client-secret" # Sensitive

# Deployment flags
dc1_deployed = true
dc2_deployed = false # Set to true if DC2 is deployed
```

## Quick Start

### 1. Deploy Base Infrastructure
```bash
# Deploy your HashiStack infrastructure first
task deploy-dc1

# Or deploy both datacenters
task deploy-both-dc
```

### 2. Automated Boundary Setup
```bash
# Complete automated deployment
task -t tasks/boundary-auto.yml boundary:setup-full

# This automatically:
# - Discovers all deployed infrastructure
# - Creates host catalogs and credential stores
# - Sets up SSH targets with credential injection
# - Configures role-based access control
```

### 3. Connect to Infrastructure
```bash
# Authenticate with Boundary
boundary authenticate password -auth-method-id <auth-method-id> -login-name admin

# Connect to DC1 server
task -t tasks/boundary-auto.yml boundary:connect-dc1-server

# Connect to DC1 client
task -t tasks/boundary-auto.yml boundary:connect-dc1-client
```

### 4. Verify Access
```bash
# List all available targets
task -t tasks/boundary-auto.yml boundary:list-all-targets

# Test all connections
task -t tasks/boundary-auto.yml boundary:test-all-connections
```

## Deployment Workflows

### Automated Setup (Recommended)
```bash
# Complete end-to-end setup
task -t tasks/boundary-auto.yml boundary:setup-full

# View available targets
task -t tasks/boundary-auto.yml boundary:list-all-targets

# Test connectivity
task -t tasks/boundary-auto.yml boundary:test-all-connections
```

### Manual Setup
```bash
# Configure variables
cd boundary/terraform
vi terraform.auto.tfvars

# Set admin password
export TF_VAR_boundary_admin_password="your-password"

# Deploy
terraform init
terraform plan
terraform apply

# Get connection commands
terraform output connection_commands
```

## Available Tasks

Use the boundary-auto Taskfile for automated operations:

### Setup Tasks
- `task -t tasks/boundary-auto.yml boundary:discover-targets` - Auto-discover infrastructure
- `task -t tasks/boundary-auto.yml boundary:inject-credentials` - Configure SSH credentials
- `task -t tasks/boundary-auto.yml boundary:deploy-complete` - Deploy with full automation

### Connection Tasks
- `task -t tasks/boundary-auto.yml boundary:connect-dc1-server` - Connect to DC1 server
- `task -t tasks/boundary-auto.yml boundary:connect-dc2-server` - Connect to DC2 server
- `task -t tasks/boundary-auto.yml boundary:connect-dc1-client` - Connect to DC1 client
- `task -t tasks/boundary-auto.yml boundary:connect-dc2-client` - Connect to DC2 client

### Management Tasks
- `task -t tasks/boundary-auto.yml boundary:list-all-targets` - List all configured targets
- `task -t tasks/boundary-auto.yml boundary:update-discovery` - Refresh target discovery
- `task -t tasks/boundary-auto.yml boundary:status-full` - Show complete deployment status

### Complete Setup
- `task -t tasks/boundary-auto.yml boundary:setup-full` - Full automated setup

### Cleanup
- `task -t tasks/boundary-auto.yml boundary:cleanup-all` - Remove all Boundary resources

## Usage Examples

### Basic SSH Access
```bash
# Authenticate with Boundary
export BOUNDARY_ADDR="https://your-cluster.boundary.hashicorp.cloud"
boundary authenticate password -auth-method-id <auth-method-id> -login-name admin

# SSH to any discovered target
boundary connect ssh -target-id <target-id-from-list>

# SSH to specific host (if multiple available)
boundary connect ssh -target-id <target-id> -host-id <specific-host-id>
```

### Port Forwarding for UIs
```bash
# Access Consul UI via SSH tunnel
boundary connect ssh -target-id <dc1-servers-target-id> -- -L 8500:localhost:8500
# Then access http://localhost:8500

# Access Nomad UI via SSH tunnel
boundary connect ssh -target-id <dc1-servers-target-id> -- -L 4646:localhost:4646
# Then access http://localhost:4646

# Access multiple services
boundary connect ssh -target-id <target-id> -- -L 8500:localhost:8500 -L 4646:localhost:4646
```

### Infrastructure Management
```bash
# SSH to server for cluster management
boundary connect ssh -target-id <dc1-servers-target-id>

# Once connected, use Consul/Nomad commands
consul members
nomad node status
systemctl status consul
```

## Infrastructure Discovery

The integration automatically discovers your infrastructure using GCP APIs:

### Discovery Process
```bash
# Server discovery
gcloud compute instances list --filter='name~hashi-server' --format='value(EXTERNAL_IP)'

# Client discovery  
gcloud compute instances list --filter='name~hashi-clients' --format='value(EXTERNAL_IP)'
```

### Organizational Structure
```
Global Scope
├── Development Org
│   ├── DC1 Development Project
│   │   ├── DC1 Host Catalog
│   │   ├── SSH Credential Store
│   │   └── Access Targets:
│   │       ├── dc1-servers-ssh (3 server nodes)
│   │       └── dc1-clients-ssh (2-4 client nodes)
│   └── DC2 Development Project
│       └── Similar structure for DC2 infrastructure
└── Operations Org
    ├── DC1 Production Project  
    └── DC2 Production Project
```

### Target Types
- **Server Targets**: Access to Consul/Nomad server nodes for cluster management
- **Client Targets**: Access to Nomad client nodes for application troubleshooting
- **Automatic Grouping**: Servers and clients are automatically grouped by datacenter

## Security Features

### Access Control
- **Role-based permissions** for different user types (admin, developer, operator)
- **Project-level isolation** between development and production environments
- **Credential injection** eliminates need for SSH key distribution
- **Session-based access** with automatic credential cleanup

### Audit and Compliance
- **Complete audit trail** of all access sessions
- **Session recording** capabilities (configurable)  
- **Integration with SIEM** systems via structured audit logs
- **Just-in-time access** with credential rotation support

### Network Security
- **Zero network exposure** of infrastructure SSH ports
- **Encrypted tunnels** for all connections via Boundary proxy
- **No VPN required** reducing network attack surface
- **Dynamic host discovery** with automatic target updates

## Verification Commands

### Check Boundary Configuration
```bash
# List all targets
boundary targets list -scope-id <project-scope-id>

# Check specific target details
boundary targets read -id <target-id>

# List host catalogs
boundary host-catalogs list -scope-id <project-scope-id>

# Check credential stores
boundary credential-stores list -scope-id <project-scope-id>
```

### Test Infrastructure Access
```bash
# Test direct SSH (should work before Boundary)
ssh debian@$(gcloud compute instances list --filter='name~hashi-server' --format='value(natIP)' --limit=1)

# Test Boundary SSH
boundary connect ssh -target-id <target-id>

# Test port forwarding
boundary connect ssh -target-id <target-id> -- -L 8500:localhost:8500
```

### Check Discovery Status
```bash
# View discovered infrastructure
terraform output discovered_infrastructure

# View target mappings
terraform output boundary_targets

# View connection commands
terraform output connection_commands
```

## Troubleshooting

### Common Issues

**SSH Connection Failures:**
- Ensure SSH keys are properly configured in Terraform Cloud workspace
- Verify `ssh_public_key` matches the private key used for credential injection
- Test direct SSH access before using Boundary

**Authentication Issues:**
- Verify Boundary admin credentials and auth method ID
- Check HCP client credentials for API access
- Ensure boundary_admin_password environment variable is set

**Target Discovery Issues:**
- Verify GCP permissions for instance listing
- Check that infrastructure is deployed and instances are running
- Refresh discovery with `task -t tasks/boundary-auto.yml boundary:update-discovery`

**Credential Injection Failures:**
- Ensure SSH private key format includes proper headers and newlines
- Verify private key matches the public key deployed to infrastructure
- Check that credential store is properly configured

### Debug Commands
```bash
# Test gcloud infrastructure discovery
gcloud compute instances list --filter='name~hashi-server'
gcloud compute instances list --filter='name~hashi-clients'

# Test Boundary authentication
boundary authenticate password -auth-method-id <auth-method> -login-name admin

# Check Terraform external data sources
cd boundary/terraform
terraform console
> data.external.dc1_server_ips[0].result
> data.external.dc1_client_ips[0].result

# Verify SSH key format
cat ~/.ssh/id_rsa | head -1  # Should show -----BEGIN OPENSSH PRIVATE KEY-----
```

### Getting Help

1. **Check prerequisites**: Ensure all required variables are configured
2. **Verify infrastructure**: Confirm HashiStack clusters are deployed and accessible
3. **Test incrementally**: Test SSH access directly before using Boundary
4. **Review logs**: Check Terraform apply output for discovery and configuration errors

## Advanced Configuration

### Multi-Datacenter Setup
```hcl
# Enable both datacenters
dc1_deployed = true
dc2_deployed = true

# Configure remote state for DC2
dc2_remote_state_config = {
  organization = "your-hcp-terraform-org"
  workspaces = {
    name = "dc2-hashistack-cluster"  
  }
}
```

### Custom IP Overrides
```hcl
# Override automatic discovery
dc1_server_ips = ["10.0.1.10", "10.0.1.11", "10.0.1.12"]
dc1_client_ips = ["10.0.2.10", "10.0.2.11"]
dc2_server_ips = ["10.1.1.10", "10.1.1.11", "10.1.1.12"]
dc2_client_ips = ["10.1.2.10", "10.1.2.11"]
```

### Custom Roles and Permissions
```hcl
# Add custom role for specific access patterns
resource "boundary_role" "devops_role" {
  name        = "DevOps Role"
  description = "DevOps team access to all infrastructure"
  scope_id    = boundary_scope.dev_project.id
  grant_strings = [
    "ids=*;type=target;actions=authorize-session",
    "ids=*;type=session;actions=read,cancel",
    "ids=*;type=host;actions=read"
  ]
}
```

## Integration with CI/CD

Automate Boundary deployment in your CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Deploy Boundary Integration
  run: |
    cd boundary/terraform
    terraform init
    terraform plan
    terraform apply -auto-approve
  env:
    TF_VAR_boundary_admin_password: ${{ secrets.BOUNDARY_PASSWORD }}
    TF_VAR_hcp_client_secret: ${{ secrets.HCP_CLIENT_SECRET }}
    TF_VAR_ssh_private_key: ${{ secrets.SSH_PRIVATE_KEY }}
```

## Success Criteria

- ✅ **Infrastructure discovered** automatically via GCP APIs
- ✅ **Host catalogs created** for DC1 and DC2 (if deployed)
- ✅ **SSH targets configured** with automatic credential injection
- ✅ **Role-based access** implemented for different user types
- ✅ **SSH connectivity working** via Boundary proxy
- ✅ **Port forwarding functional** for UI access
- ✅ **Audit logging enabled** for all access sessions
- ✅ **Zero SSH key distribution** with secure credential injection

This integration provides enterprise-grade secure access to your HashiStack infrastructure while maintaining complete audit trails and eliminating traditional SSH key management challenges.