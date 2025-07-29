# HashiCorp Boundary Integration

## Overview

HashiCorp Boundary integration provides secure, authenticated remote access to your HashiStack infrastructure without exposing SSH keys or requiring VPN connections. This integration automatically discovers your deployed infrastructure and creates secure SSH access targets.

### What This Integration Provides

**Secure Access Targets:**
- SSH access to Consul/Nomad server nodes
- SSH access to Nomad client nodes

**Enterprise Features:**
- Centralized access control and policies
- Session recording and audit logs
- Just-in-time credential injection
- Multi-factor authentication support
- Role-based access control (RBAC)

**Infrastructure Integration:**
- Automatic discovery of deployed instances
- Dynamic host catalog updates
- Integration with existing SSH keys
- Works with both DC1 and DC2 clusters

## Prerequisites

**Required Services:**
- HCP Boundary cluster (or self-managed Boundary cluster)
- Deployed HashiStack infrastructure (DC1 and/or DC2)
- Valid SSH private key for instance access

**Required Information:**
- HCP Boundary cluster URL and ID
- Boundary authentication method ID
- HCP client credentials
- Admin user credentials for Boundary

**Permissions:**
- Boundary cluster administrator access
- GCP compute instance list permissions
- SSH key access for credential injection

## How to run in tasks

### 1. Deploy Base Infrastructure

Deploy your HashiStack infrastructure first:

```bash
# Deploy primary cluster
task deploy-dc1

# Or deploy both clusters
task deploy-both
```

### 2. Configure Boundary Variables

Edit `boundary/terraform/terraform.auto.tfvars` with your configuration:

```hcl
# HCP Boundary Configuration
hcp_boundary_cluster_id = "your-boundary-cluster-id"
boundary_addr = "https://your-boundary-cluster.boundary.hashicorp.cloud"
boundary_auth_method_id = "your-auth-method-id"
boundary_admin_login_name = "your-admin-username"

# Deployment Configuration
dc1_deployed = true
dc2_deployed = false  # Set to true if DC2 is deployed

# GCP Configuration
gcp_project = "your-gcp-project-id"

# HCP Configuration  
hcp_client_id = "your-hcp-client-id"
hcp_client_secret = "your-hcp-client-secret"

# SSH Private Key (for credential injection)
ssh_private_key = <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
your-ssh-private-key-content
-----END OPENSSH PRIVATE KEY-----
EOF
```

### 3. Set Admin Password

Set your Boundary admin password as an environment variable:

```bash
export TF_VAR_boundary_admin_password="your-boundary-admin-password"
```

### 4. Deploy Boundary Integration

```bash
cd boundary/terraform
terraform init
terraform plan
terraform apply
```

## Architecture

The Boundary integration creates the following organizational structure:

```
Global Scope
├── Development Org
│   ├── DC1 Development Project
│   │   ├── DC1 Host Catalog
│   │   ├── SSH Credential Store
│   │   └── Access Targets:
│   │       ├── dc1-servers-ssh
│   │       └── dc1-clients-ssh
│   └── DC2 Development Project (if deployed)
│       └── Similar target structure
└── Operations Org
    ├── DC1 Production Project  
    └── DC2 Production Project
```

**Roles and Permissions:**
- **Management Users**: Full administrative access
- **Developers**: Access to development projects and targets
- **Operations**: Access to production projects and targets

## Usage

### Authentication

Authenticate with your Boundary cluster:

```bash
export BOUNDARY_ADDR="https://your-cluster.boundary.hashicorp.cloud"
boundary authenticate password -auth-method-id your-auth-method-id -login-name your-username
```

### SSH Access

Connect to infrastructure via SSH:

```bash
# SSH to DC1 servers
boundary connect ssh -target-id <dc1-servers-ssh-target-id>

# SSH to DC1 clients  
boundary connect ssh -target-id <dc1-clients-ssh-target-id>

# SSH to specific host (if multiple available)
boundary connect ssh -target-id <target-id> -host-id <specific-host-id>
```

### Direct Infrastructure Access

For accessing web UIs, use the infrastructure's load balancer endpoints directly or SSH port forwarding:

```bash
# SSH with port forwarding for Consul UI
boundary connect ssh -target-id <dc1-servers-ssh-target-id> -- -L 8500:localhost:8500

# SSH with port forwarding for Nomad UI  
boundary connect ssh -target-id <dc1-servers-ssh-target-id> -- -L 4646:localhost:4646
```

### Get Connection Commands

The Terraform output provides ready-to-use connection commands:

```bash
# View all connection commands
terraform output connection_commands

# View discovered infrastructure
terraform output discovered_infrastructure

# View target information
terraform output boundary_targets
```

## Configuration Details

### Automatic Infrastructure Discovery

The integration automatically discovers your infrastructure using the same gcloud commands as the main project:

```bash
# Server discovery
gcloud compute instances list --filter='name~hashi-server' --format='value(EXTERNAL_IP)'

# Client discovery  
gcloud compute instances list --filter='name~hashi-clients' --format='value(EXTERNAL_IP)'
```

### Host Catalogs and Sets

**Host Catalogs**: Container for organizing hosts by cluster
- `dc1_host_catalog`: Contains all DC1 infrastructure
- `dc2_host_catalog`: Contains all DC2 infrastructure (if deployed)

**Host Sets**: Logical groupings of hosts for targeting
- `dc1_servers`: All DC1 Consul/Nomad server nodes
- `dc1_clients`: All DC1 Nomad client nodes
- Similar sets for DC2 if deployed

### Credential Management

**SSH Credential Store**: Stores SSH private keys for authentication
- Automatically injects SSH credentials during connections
- Uses the same SSH key that was used for infrastructure deployment
- Credentials are securely managed and never exposed

### Target Types

**SSH Targets**: For shell access to instances
- Default port: 22
- Automatic credential injection
- Session recording (if enabled)
- Direct access to servers and clients

## Security Features

**Access Control:**
- Role-based permissions for different user types
- Project-level isolation between development and production
- Credential injection eliminates need for key distribution

**Audit and Compliance:**
- All access sessions are logged and auditable
- Session recording capabilities (configurable)
- Integration with SIEM systems via audit logs

**Network Security:**
- No direct network exposure of infrastructure
- All access goes through Boundary proxy
- Encrypted tunnels for all connections

## Troubleshooting

**Common Issues:**

1. **Authentication Failures**: Verify boundary admin password and auth method ID
2. **Host Discovery Issues**: Check GCP permissions and project configuration
3. **SSH Connection Failures**: Verify SSH private key matches deployed public key
4. **Empty Host Lists**: Ensure infrastructure is deployed and instances are running

**Useful Commands:**

```bash
# Check Boundary authentication
boundary authenticate password -auth-method-id <auth-method> -login-name <username>

# List available targets
boundary targets list -scope-id <project-scope-id>

# Check host catalog status
boundary host-catalogs list -scope-id <project-scope-id>

# View specific target details
boundary targets read -id <target-id>
```

**Debugging Infrastructure Discovery:**

```bash
# Test gcloud commands manually
gcloud compute instances list --filter='name~hashi-server' --format='value(EXTERNAL_IP)'
gcloud compute instances list --filter='name~hashi-clients' --format='value(EXTERNAL_IP)'

# Check Terraform external data sources
terraform console
> data.external.dc1_server_ips[0].result
> data.external.dc1_client_ips[0].result
```

## Advanced Configuration

### Multi-Region Deployment

For multi-region deployments, adjust the DC2 configuration:

```hcl
dc2_deployed = true
dc2_remote_state_config = {
  organization = "your-hcp-terraform-org"
  workspaces = {
    name = "dc2-hashistack-cluster"  
  }
}
```

### Custom IP Overrides

Override automatic discovery with manual IP lists:

```hcl
dc1_server_ips = ["10.0.1.10", "10.0.1.11", "10.0.1.12"]
dc1_client_ips = ["10.0.2.10", "10.0.2.11"]
```

### Additional Roles and Permissions

Customize roles by modifying the grant strings in `main.tf`:

```hcl
resource "boundary_role" "custom_role" {
  name        = "Custom Role"
  description = "Custom permissions"
  scope_id    = "global"
  grant_strings = [
    "ids=*;type=target;actions=authorize-session",
    "ids=*;type=session;actions=read,cancel"
  ]
}
```

## Integration with CI/CD

The Boundary integration can be automated in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Deploy Boundary Integration
  run: |
    cd boundary/terraform
    terraform init
    terraform plan
    terraform apply -auto-approve
  env:
    TF_VAR_boundary_admin_password: ${{ secrets.BOUNDARY_PASSWORD }}
```

This integration provides secure, auditable, and automated access to your HashiStack infrastructure while maintaining enterprise security standards and compliance requirements.