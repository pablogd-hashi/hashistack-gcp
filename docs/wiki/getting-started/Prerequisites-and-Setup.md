# Prerequisites and Setup

**Navigation:** [Home](../Home.md) > [Getting Started](Prerequisites-and-Setup.md) > Prerequisites and Setup

> **Quick Links:** [Required Tools](#required-tools) | [GCP Setup](#gcp-setup) | [Enterprise Licenses](#enterprise-licenses)

---

## Overview

This page covers everything you need to install and configure before deploying the HashiStack infrastructure on Google Cloud Platform.

## Required Tools

Install these tools on your local machine before beginning deployment:

| Tool | Minimum Version | Installation | Purpose |
|------|----------------|--------------|---------|
| **Task** | v3.0+ | `brew install go-task` or [install guide](https://taskfile.dev/installation/) | Workflow automation and orchestration |
| **Terraform** | v1.5+ | `brew install terraform` or [download](https://www.terraform.io/downloads) | Infrastructure as code deployment |
| **Packer** | v1.9+ | `brew install packer` or [download](https://www.packer.io/downloads) | Custom VM image building |
| **Google Cloud SDK** | Latest | `brew install google-cloud-sdk` or [install guide](https://cloud.google.com/sdk/docs/install) | GCP CLI and authentication |
| **kubectl** | v1.25+ | `brew install kubectl` | Kubernetes management (for GKE features) |
| **Consul CLI** | v1.21+ | `brew install consul` | Consul cluster management |
| **Nomad CLI** | v1.10+ | `brew install nomad` | Nomad cluster management |

### Verification

After installation, verify all tools are accessible:

```bash
# Check installed versions
task --version
terraform --version
packer --version
gcloud --version
kubectl version --client
consul version
nomad version
```

## GCP Setup

### 1. Authenticate with Google Cloud

```bash
# Login to your Google Cloud account
gcloud auth login

# Set your default project
gcloud config set project YOUR_PROJECT_ID

# Enable application default credentials (required for Terraform)
gcloud auth application-default login
```

### 2. Enable Required APIs

Enable these GCP APIs for your project:

```bash
# Enable Compute Engine API (required for VMs)
gcloud services enable compute.googleapis.com

# Enable DNS API (if using custom domains)
gcloud services enable dns.googleapis.com

# Enable Kubernetes Engine API (for GKE features)
gcloud services enable container.googleapis.com
```

**Verify enabled services:**
```bash
gcloud services list --enabled
```

### 3. Configure IAM Permissions

Your GCP account needs these IAM roles:

| Role | Purpose | Required For |
|------|---------|--------------|
| **Compute Admin** | Create and manage VMs, networks, firewall rules | VM deployment |
| **DNS Administrator** | Manage DNS zones and records | Custom domains (optional) |
| **Kubernetes Engine Admin** | Create and manage GKE clusters | Admin partitions |
| **Service Account User** | Use service accounts for compute instances | All deployments |

**Check your current roles:**
```bash
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL"
```

### 4. Configure Service Account (Optional but Recommended)

For production-like deployments, use a dedicated service account:

```bash
# Create service account
gcloud iam service-accounts create hashistack-deployer \
  --display-name="HashiStack Deployment Service Account"

# Grant necessary roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:hashistack-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

# Create and download key
gcloud iam service-accounts keys create ~/hashistack-sa-key.json \
  --iam-account=hashistack-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Activate service account
gcloud auth activate-service-account \
  --key-file=~/hashistack-sa-key.json
```

## Enterprise Licenses

### Required Licenses

You'll need enterprise licenses for full functionality:

- **Consul Enterprise License** - Required for:
  - Admin partitions
  - Consul-Terraform-Sync (CTS)
  - Advanced multi-tenancy features

- **Nomad Enterprise License** - Optional but recommended for:
  - Resource quotas
  - Sentinel policies
  - Automated backups

### Obtaining Licenses

**Trial licenses:** Contact HashiCorp sales or use HashiCorp Cloud Platform (HCP) trial.

**Developer licenses:** Available through HashiCorp developer programs.

### Storing Licenses

Store licenses securely in one of these locations:

**Option 1: HCP Terraform Variable Sets (Recommended)**
```hcl
# Create sensitive variable in HCP Terraform workspace
consul_license = "your-consul-enterprise-license"
nomad_license = "your-nomad-enterprise-license"
```

**Option 2: Local tfvars file**
```bash
# Create terraform.auto.tfvars (add to .gitignore!)
cat > clusters/dc1/terraform/terraform.auto.tfvars <<EOF
consul_license = "your-consul-enterprise-license"
nomad_license = "your-nomad-enterprise-license"
EOF
```

**Option 3: Environment Variables**
```bash
export TF_VAR_consul_license="your-consul-enterprise-license"
export TF_VAR_nomad_license="your-nomad-enterprise-license"
```

## Terraform Configuration

### HCP Terraform Setup (Recommended)

Using HCP Terraform (formerly Terraform Cloud) provides remote state management and collaboration:

1. **Create HCP Terraform account:** https://app.terraform.io/signup

2. **Create organization and workspaces:**
   - `hashistack-dc1` - Primary datacenter
   - `hashistack-dc2` - Secondary datacenter (optional)
   - `gke-europe-west1` - GKE cluster west (for admin partitions)
   - `gke-southwest` - GKE cluster southwest (for admin partitions)

3. **Configure variable sets:**

Create a shared variable set with common values:

```hcl
# HashiStack Common Variables
consul_license = "your-consul-enterprise-license"     # Sensitive
nomad_license = "your-nomad-enterprise-license"       # Sensitive
gcp_project = "your-gcp-project-id"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."        # Your public key
ssh_username = "debian"

# Optional
dns_zone = "your-dns-zone-name"
```

4. **Link workspaces to VCS (optional):**
   Connect your GitHub repository for automated planning.

### Local Terraform Setup

For local development without HCP Terraform:

```bash
# Initialize Terraform in each cluster directory
cd clusters/dc1/terraform
terraform init

# Create local tfvars
cp terraform.tfvars.example terraform.auto.tfvars
# Edit with your values
```

## SSH Keys

SSH access is **required** for infrastructure management and troubleshooting.

### Generate SSH Key Pair

If you don't have SSH keys:

```bash
# Generate new SSH key pair
ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f ~/.ssh/hashistack

# View public key (add to Terraform variables)
cat ~/.ssh/hashistack.pub

# Keep private key secure
chmod 600 ~/.ssh/hashistack
```

### Configure SSH in Terraform

Add your public key to Terraform variables:

```hcl
# In HCP Terraform or terraform.auto.tfvars
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDexample... your-email@example.com"
ssh_username = "debian"  # Default user for Debian images
```

This key will be automatically added to all deployed VMs.

## Network Configuration

### Default Network Settings

The deployment creates isolated VPC networks:

- **DC1 VMs:** `10.0.0.0/16`
- **DC2 VMs:** `10.1.0.0/16`
- **GKE West:** `10.10.0.0/24` (pods: `10.11.0.0/16`, services: `10.12.0.0/16`)
- **GKE Southwest:** `10.20.0.0/24` (pods: `10.21.0.0/16`, services: `10.22.0.0/16`)

### Firewall Rules

Automatic firewall rules allow:
- SSH (port 22) from your IP
- Consul (8300-8302, 8500, 8501, 8502, 8600)
- Nomad (4646, 4647, 4648)
- Service mesh (20000, 21000-21255)

### Custom DNS (Optional)

If using custom DNS domains:

```bash
# Create DNS zone in GCP
gcloud dns managed-zones create your-zone-name \
  --dns-name="yourdomain.com." \
  --description="HashiStack DNS zone"

# Add zone to Terraform variables
dns_zone = "your-zone-name"
```

## Verification Checklist

Before proceeding to deployment, verify:

- [ ] All required tools installed and accessible
- [ ] GCP authentication configured (`gcloud auth list`)
- [ ] Required GCP APIs enabled
- [ ] IAM permissions granted
- [ ] Enterprise licenses obtained and stored securely
- [ ] HCP Terraform workspaces created (if using remote state)
- [ ] SSH keys generated and public key added to variables
- [ ] GCP project ID configured
- [ ] Network requirements understood

## Next Steps

Once prerequisites are complete:

1. **Build Custom Images:** [Image Building with Packer](../infrastructure/Image-Building-with-Packer.md)
2. **Or Jump to Quick Start:** [Quick Start Guide](Quick-Start-Guide.md)

## Troubleshooting

### GCP Authentication Issues

**Problem:** `gcloud` commands fail with authentication errors

**Solution:**
```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login

# Verify active account
gcloud auth list
```

### API Not Enabled Errors

**Problem:** Terraform fails with "API not enabled" errors

**Solution:**
```bash
# Enable all required APIs
gcloud services enable compute.googleapis.com dns.googleapis.com container.googleapis.com

# Wait 2-3 minutes for APIs to propagate
```

### Permission Denied Errors

**Problem:** Cannot create resources due to permissions

**Solution:**
```bash
# Check your current roles
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL"

# Contact GCP admin to grant required roles
```

## Related Pages

- [Quick Start Guide](Quick-Start-Guide.md) - Deploy your first cluster
- [Architecture Overview](Architecture-Overview.md) - Understand the system design
- [Image Building with Packer](../infrastructure/Image-Building-with-Packer.md) - Build custom VM images

---

**Previous:** [Home](../Home.md) | **Next:** [Quick Start Guide](Quick-Start-Guide.md) | **[Back to Top](#prerequisites-and-setup)**
