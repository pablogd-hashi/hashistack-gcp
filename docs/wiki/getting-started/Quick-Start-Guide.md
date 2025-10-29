# Quick Start Guide

**Navigation:** [Home](../Home.md) > [Getting Started](Prerequisites-and-Setup.md) > Quick Start Guide

> **Quick Links:** [Configure Variables](#step-1-configure-variables) | [Build Images](#step-2-build-images) | [Deploy](#step-3-deploy-infrastructure) | [Verify](#step-5-verify-deployment)

---

## Overview

This guide will walk you through deploying your first HashiStack cluster on GCP in approximately 30-45 minutes.

**What you'll deploy:**
- 3 Consul/Nomad server nodes (high availability)
- 2-4 Nomad client nodes (workload execution)
- Complete ACL security with TLS encryption
- Service mesh with Consul Connect
- Monitoring with Prometheus and Grafana (optional)

**Prerequisites:** Complete [Prerequisites and Setup](Prerequisites-and-Setup.md) first.

---

## Step 1: Configure Variables

Set up your Terraform variables using either HCP Terraform variable sets or local `.tfvars` files.

### Option A: HCP Terraform Variable Sets (Recommended)

1. **Log into HCP Terraform:** https://app.terraform.io

2. **Create workspace:**
   - Organization: Your org name
   - Workspace name: `hashistack-dc1`
   - VCS connection: Optional (can run locally)

3. **Add variable set:**

Navigate to your organization settings → Variable Sets → Create variable set

**Variable Set Name:** `HashiStack Common`

**Variables to add:**

| Variable | Value | Sensitive | Category |
|----------|-------|-----------|----------|
| `gcp_project` | `your-gcp-project-id` | No | Terraform |
| `gcp_region` | `europe-north1` | No | Terraform |
| `cluster_name` | `demo-hashistack` | No | Terraform |
| `consul_license` | `your-consul-ent-license` | **Yes** | Terraform |
| `nomad_license` | `your-nomad-ent-license` | **Yes** | Terraform |
| `ssh_public_key` | `ssh-rsa AAAAB3...` | No | Terraform |
| `ssh_username` | `debian` | No | Terraform |

**Optional variables:**
```hcl
dns_zone = "your-dns-zone-name"  # If using custom DNS
```

4. **Apply variable set to workspace:** Link the variable set to `hashistack-dc1` workspace

### Option B: Local tfvars File

Create a local variables file:

```bash
cd clusters/dc1/terraform

# Create terraform.auto.tfvars
cat > terraform.auto.tfvars <<'EOF'
# Project Configuration
gcp_project  = "your-gcp-project-id"
gcp_region   = "europe-north1"
cluster_name = "demo-hashistack"

# Enterprise Licenses (SENSITIVE - add to .gitignore)
consul_license = "your-consul-enterprise-license"
nomad_license  = "your-nomad-enterprise-license"

# SSH Access (REQUIRED)
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... your-email@example.com"
ssh_username   = "debian"

# Optional: Custom DNS
# dns_zone = "your-dns-zone-name"
EOF

# Add to .gitignore to prevent committing secrets
echo "terraform.auto.tfvars" >> .gitignore
```

---

## Step 2: Build Images

Build custom VM images with HashiCorp tools pre-installed using Packer.

### Why Build Images First?

Custom images significantly speed up deployment by pre-installing:
- Consul Enterprise binaries
- Nomad Enterprise binaries
- Docker and CNI plugins
- Systemd service configurations

### Build Process

```bash
# From project root directory
task build-images
```

**What happens:**
1. Packer launches temporary GCP instance
2. Installs Consul, Nomad, Vault, Docker
3. Configures systemd services
4. Creates image snapshot
5. Destroys temporary instance

**Build time:** 8-12 minutes

**Output example:**
```
==> Builds finished. The artifacts of successful builds are:
--> consul-nomad.gcp: A disk image was created: consul-nomad-1-21-2-ent-1-10-3-ent
```

### Verify Images

```bash
# List created images
gcloud compute images list --filter="family=hashistack"
```

**Expected output:**
```
NAME                              FAMILY      PROJECT            STATUS
consul-nomad-1-21-2-ent-1-10-3-ent hashistack your-gcp-project  READY
```

**More details:** [Image Building with Packer](../infrastructure/Image-Building-with-Packer.md)

---

## Step 3: Deploy Infrastructure

Deploy the complete HashiStack cluster using Terraform and Task automation.

### Deploy DC1 (Primary Datacenter)

```bash
# From project root
task deploy-dc1
```

**What this deploys:**
- VPC network with subnets and firewall rules
- 3 server nodes (Consul + Nomad servers)
- 2-4 client nodes (Nomad clients)
- Load balancers for UI access
- ACL bootstrapping and TLS certificates

**Deployment time:** 5-8 minutes

**Output example:**
```
Apply complete! Resources: 24 added, 0 changed, 0 destroyed.

Outputs:

cluster_info = {
  "consul_servers" = ["35.228.1.100", "35.228.1.101", "35.228.1.102"]
  "nomad_clients" = ["35.228.2.100", "35.228.2.101"]
  ...
}
```

### Manual Deployment (Alternative)

If you prefer manual Terraform commands:

```bash
cd clusters/dc1/terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply
```

---

## Step 4: Configure Environment

After deployment, set up your environment variables to access the cluster.

### Get Environment Variables

```bash
# From project root
task eval-dc1
```

**Output example:**
```bash
# === DC1 Cluster Environment ===
export CONSUL_HTTP_ADDR="http://35.228.1.100:8500"
export CONSUL_HTTP_TOKEN="a1b2c3d4-e5f6-7890-abcd-ef1234567890"
export NOMAD_ADDR="http://35.228.1.100:4646"
export NOMAD_TOKEN="e5f6g7h8-i9j0-1234-cdef-567890abcdef"

# Consul UI: http://35.228.1.100:8500
# Nomad UI: http://35.228.1.100:4646
```

### Apply Environment Variables

**Copy and paste the export commands into your terminal:**

```bash
export CONSUL_HTTP_ADDR="http://35.228.1.100:8500"
export CONSUL_HTTP_TOKEN="a1b2c3d4-e5f6-7890-abcd-ef1234567890"
export NOMAD_ADDR="http://35.228.1.100:4646"
export NOMAD_TOKEN="e5f6g7h8-i9j0-1234-cdef-567890abcdef"
```

### Complete Nomad-Consul Integration

```bash
# Configure Nomad to use Consul for service discovery
nomad setup consul -y
```

**Expected output:**
```
✓ Consul configuration updated successfully
✓ Service registration enabled
✓ Service mesh integration configured
```

### Authenticate to UIs

```bash
# Open Nomad UI and auto-authenticate
nomad ui -authenticate
```

This opens your browser to the Nomad UI with automatic token authentication.

---

## Step 5: Verify Deployment

Verify that all components are running correctly.

### Check Cluster Status

```bash
# View cluster information
task show-dc1-info
```

### Verify Consul

```bash
# List Consul members
consul members

# Expected output:
# Node          Address          Status  Type    Build      Protocol  DC   Partition  Segment
# hashi-server-0  10.0.1.10:8301  alive   server  1.21.2+ent  2         dc1  default    <all>
# hashi-server-1  10.0.1.11:8301  alive   server  1.21.2+ent  2         dc1  default    <all>
# hashi-server-2  10.0.1.12:8301  alive   server  1.21.2+ent  2         dc1  default    <all>

# Check Consul services
consul catalog services
```

### Verify Nomad

```bash
# Check Nomad server status
nomad server members

# Expected output:
# Name                 Address     Port  Status  Leader  Raft Version  Protocol  Version
# hashi-server-0.dc1  10.0.1.10   4648  alive   true    3             2         1.10.3+ent

# Check Nomad clients
nomad node status

# Expected output:
# ID        Node Class  DC   Drain  Eligibility  Status
# abc123... <none>      dc1  false  eligible     ready
# def456... <none>      dc1  false  eligible     ready
```

### Access Web UIs

Open these URLs in your browser (use IPs from `task eval-dc1` output):

**Consul UI:**
```
http://<consul-server-ip>:8500
```
- Login with token from `CONSUL_HTTP_TOKEN`
- Navigate to Services → Should see consul, nomad services

**Nomad UI:**
```
http://<nomad-server-ip>:4646
```
- Login with token from `NOMAD_TOKEN`
- Navigate to Topology → Should see server and client nodes

---

## Step 6: Deploy Optional Components

### Monitoring Stack (Prometheus + Grafana)

```bash
# Deploy monitoring to DC1
task deploy-monitoring-dc1
```

**Access Grafana:**
```
http://<client-ip>:3000
Username: admin
Password: admin
```

Pre-configured dashboards show Consul and Nomad metrics.

### Traefik Load Balancer

```bash
# Deploy Traefik ingress
task deploy-traefik-dc1
```

**Access Traefik Dashboard:**
```
http://<client-ip>:8080
```

**More details:** [Monitoring and Observability](../operations/Monitoring-and-Observability.md)

---

## Next Steps

Now that you have a running cluster, explore advanced features:

### Learn More About Your Deployment
- **[Architecture Overview](Architecture-Overview.md)** - Understand component relationships
- **[VM Cluster Deployment](../infrastructure/VM-Cluster-Deployment.md)** - Deep dive into cluster configuration

### Deploy Advanced Features
- **[Cluster Peering](../advanced-features/Cluster-Peering.md)** - Connect multiple datacenters
- **[Admin Partitions](../advanced-features/Admin-Partitions.md)** - Multi-tenant Kubernetes integration
- **[Boundary Integration](../infrastructure/Secure-Access-with-Boundary.md)** - Secure SSH access

### Run Demo Applications
- **[Demo Applications](../workflows/Demo-Applications.md)** - Deploy sample microservices

---

## Common Tasks

### SSH to Server Node

```bash
# SSH to first server
task ssh-dc1-server

# Or manually
ssh debian@<server-ip>
```

### Check Logs

```bash
# SSH to server first
task ssh-dc1-server

# View Consul logs
sudo journalctl -u consul -f

# View Nomad logs
sudo journalctl -u nomad -f
```

### Run a Test Workload

```bash
# Simple Nomad job
nomad job init
nomad job run example.nomad.hcl

# Check job status
nomad job status example
```

---

## Troubleshooting

### Deployment Fails

**Problem:** Terraform apply fails with errors

**Common causes:**
- GCP APIs not enabled → See [Prerequisites](Prerequisites-and-Setup.md#gcp-setup)
- Invalid licenses → Check license format and expiration
- Insufficient quotas → Check GCP quotas in Console

**Solution:**
```bash
# Check GCP APIs
gcloud services list --enabled

# Validate Terraform configuration
cd clusters/dc1/terraform
terraform validate

# Review detailed error in terraform output
```

### Cannot Access UIs

**Problem:** Consul/Nomad UIs not accessible

**Solution:**
```bash
# Verify instances are running
gcloud compute instances list --filter='name~hashi-server'

# Check firewall rules
gcloud compute firewall-rules list

# Test direct connectivity
curl http://<server-ip>:8500/v1/status/leader
```

### Environment Variables Not Working

**Problem:** CLI commands fail with connection errors

**Solution:**
```bash
# Re-run eval command
task eval-dc1

# Copy ALL export statements including tokens
# Verify variables are set
echo $CONSUL_HTTP_ADDR
echo $CONSUL_HTTP_TOKEN
```

**Full troubleshooting guide:** [Troubleshooting Guide](../operations/Troubleshooting-Guide.md)

---

## Cleanup

When you're done testing, destroy the infrastructure:

```bash
# Destroy DC1 cluster
task destroy-dc1

# Or manually
cd clusters/dc1/terraform
terraform destroy
```

**Cost note:** Running clusters incur GCP compute costs. Destroy when not in use.

---

## Summary

You've successfully deployed:
- Custom VM images with HashiCorp tools
- High-availability Consul cluster (3 servers)
- Nomad cluster with server and client nodes
- Complete ACL security with TLS encryption
- Service mesh with Consul Connect
- Optional monitoring and ingress

## Related Pages

- [Deployment Workflows](../workflows/Deployment-Workflows.md) - More deployment patterns
- [Task Automation Reference](../workflows/Task-Automation-Reference.md) - All available tasks
- [Troubleshooting Guide](../operations/Troubleshooting-Guide.md) - Common issues and solutions

---

**Previous:** [Prerequisites and Setup](Prerequisites-and-Setup.md) | **Next:** [Architecture Overview](Architecture-Overview.md) | **[Back to Top](#quick-start-guide)**
