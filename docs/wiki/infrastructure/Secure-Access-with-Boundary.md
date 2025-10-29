# Secure Access with Boundary

**Navigation:** [Home](../Home.md) > [Core Infrastructure](Image-Building-with-Packer.md) > Secure Access with Boundary

> **Quick Links:** [Prerequisites](#prerequisites) | [Quick Start](#quick-start) | [Connect to Infrastructure](#connect-to-infrastructure)

---

## Overview

Set up HashiCorp Boundary for secure, zero-trust SSH access to your infrastructure without VPN or SSH key distribution.

**Benefits:**
- No SSH key management
- Session recording and audit logs
- Just-in-time access
- No VPN required

---

## Prerequisites

**Required:**

1. **[VM Cluster Deployment](VM-Cluster-Deployment.md)** - DC1 (and optionally DC2) deployed

2. **HCP Boundary cluster** or self-managed Boundary instance

3. **SSH private key** (matches public key in GCP Common variable set)

4. **HCP API credentials** for automation

---

## Quick Start

### Step 1: Configure Boundary Variables

Add to HCP Terraform workspace or local tfvars:

```hcl
# Boundary connection
boundary_addr = "https://your-cluster.boundary.hashicorp.cloud"
boundary_auth_method_id = "ampw_xxxxx"
boundary_admin_login_name = "admin"
boundary_admin_password = "your-password"  # Sensitive

# HCP API
hcp_client_id = "your-hcp-client-id"  # Sensitive
hcp_client_secret = "your-hcp-client-secret"  # Sensitive

# SSH credentials
ssh_private_key = "-----BEGIN PRIVATE KEY-----\n..."  # Sensitive

# Deployment flags
dc1_deployed = true
dc2_deployed = false  # Set true if DC2 exists
```

### Step 2: Deploy Boundary Configuration

```bash
cd boundary/terraform
terraform init
terraform apply
```

This automatically:
- Discovers all deployed VMs
- Creates host catalogs
- Sets up SSH targets
- Configures credential stores

### Step 3: Authenticate to Boundary

```bash
export BOUNDARY_ADDR="https://your-cluster.boundary.hashicorp.cloud"

boundary authenticate password \
  -auth-method-id ampw_xxxxx \
  -login-name admin
```

### Step 4: Connect to Infrastructure

```bash
# List available targets
boundary targets list

# Connect to DC1 server
boundary connect ssh -target-id ttcp_xxxxx

# Or use task automation
task -t tasks/boundary-auto.yml boundary:connect-dc1-server
```

---

## Using Task Automation

```bash
# Complete automated setup
task -t tasks/boundary-auto.yml boundary:setup-full

# List all targets
task -t tasks/boundary-auto.yml boundary:list-all-targets

# Connect shortcuts
task -t tasks/boundary-auto.yml boundary:connect-dc1-server
task -t tasks/boundary-auto.yml boundary:connect-dc1-client
task -t tasks/boundary-auto.yml boundary:connect-dc2-server
task -t tasks/boundary-auto.yml boundary:connect-dc2-client
```

---

## Connect to Infrastructure

### SSH to Server

```bash
# Using Boundary CLI
boundary connect ssh -target-id ttcp_server_target_id

# With username override
boundary connect ssh -target-id ttcp_server_target_id -username debian

# Execute command
boundary connect ssh -target-id ttcp_server_target_id -- consul members
```

### Port Forwarding

```bash
# Forward Consul UI
boundary connect ssh -target-id ttcp_server_target_id -- -L 8500:localhost:8500

# Access at http://localhost:8500
```

---

## Organizational Structure

Boundary creates this organization:

```
Development Org
├── DC1 Project
│   ├── DC1 Host Catalog (dynamic, GCP)
│   ├── SSH Credential Store
│   └── Targets:
│       ├── dc1-servers-ssh (3 hosts)
│       └── dc1-clients-ssh (2-4 hosts)
└── DC2 Project (if deployed)
    └── Similar structure
```

---

## What's Next?

After setting up Boundary:

1. **[Deploy Monitoring](../operations/Monitoring-and-Observability.md)** - Add observability stack
2. **[Set Up Cluster Peering](../advanced-features/Cluster-Peering.md)** - Connect DC1 and DC2
3. **[Deploy Admin Partitions](../advanced-features/Admin-Partitions.md)** - Add GKE integration

---

**Previous:** [OpenShift Integration](OpenShift-Integration.md) | **Next:** [Admin Partitions](../advanced-features/Admin-Partitions.md) | **[Back to Top](#secure-access-with-boundary)**
