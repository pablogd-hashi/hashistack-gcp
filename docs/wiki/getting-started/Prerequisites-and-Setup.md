# Prerequisites and Setup

**Navigation:** [Home](../Home.md) > [Getting Started](Prerequisites-and-Setup.md) > Prerequisites and Setup

> **Quick Links:** [Required Tools](#required-tools) | [GCP Setup](#gcp-setup) | [HCP Terraform Setup](#hcp-terraform-setup) | [Variable Sets](#variable-sets)

---

## Overview

This page covers everything you need to install and configure before deploying the HashiStack infrastructure on Google Cloud Platform. This guide assumes you'll use **HCP Terraform** (recommended) for state management and variable storage, with local `tfvars` as an alternative option.

## Required Tools

Install these tools on your local machine:

| Tool | Minimum Version | Installation | Purpose |
|------|----------------|--------------|---------|
| **Task** | v3.0+ | `brew install go-task` or [install guide](https://taskfile.dev/installation/) | Workflow automation and orchestration |
| **Terraform** | v1.5+ | `brew install terraform` or [download](https://www.terraform.io/downloads) | Infrastructure as code deployment |
| **Packer** | v1.9+ | `brew install packer` or [download](https://www.packer.io/downloads) | Custom VM image building |
| **Google Cloud SDK** | Latest | `brew install google-cloud-sdk` or [install guide](https://cloud.google.com/sdk/docs/install) | GCP CLI and API access |
| **kubectl** | v1.25+ | `brew install kubectl` | Kubernetes management (for GKE/Admin Partitions) |
| **Consul CLI** | v1.21+ | `brew install consul` | Consul cluster management |
| **Nomad CLI** | v1.10+ | `brew install nomad` | Nomad cluster management |

**Verify installation:**
```bash
task --version
terraform --version
packer --version
gcloud --version
kubectl version --client
consul version
nomad version
```

---

## GCP Setup

### 1. Create GCP Project

If you don't have a GCP project:

```bash
# Create new project
gcloud projects create YOUR_PROJECT_ID --name="HashiStack Demo"

# Set as default project
gcloud config set project YOUR_PROJECT_ID

# Link billing account (required for compute resources)
gcloud billing projects link YOUR_PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

### 2. Enable Required APIs

```bash
# Enable Compute Engine API (required for VMs)
gcloud services enable compute.googleapis.com

# Enable DNS API (optional - for custom domains)
gcloud services enable dns.googleapis.com

# Enable Kubernetes Engine API (required for GKE/Admin Partitions)
gcloud services enable container.googleapis.com

# Enable IAM API (required for service account management)
gcloud services enable iam.googleapis.com
```

### 3. Create Service Account for Terraform

Create a dedicated service account with necessary permissions:

```bash
# Create service account
gcloud iam service-accounts create terraform-deployer \
  --display-name="Terraform Deployment Service Account" \
  --description="Service account for HashiStack Terraform deployments"

# Grant required roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.admin"

# Optional: DNS admin role (if using custom domains)
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/dns.admin"
```

### 4. Generate Service Account Key (JSON)

**This JSON file will be used as `GOOGLE_CREDENTIALS` in HCP Terraform:**

```bash
# Generate and download service account key
gcloud iam service-accounts keys create ~/terraform-deployer-key.json \
  --iam-account=terraform-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com

# View the JSON content (you'll need this for HCP Terraform)
cat ~/terraform-deployer-key.json
```

**Important:** Keep this JSON file secure. You'll add its entire contents to HCP Terraform as the `GOOGLE_CREDENTIALS` variable.

---

## HCP Terraform Setup

### 1. Create HCP Terraform Account

Sign up at [https://app.terraform.io/signup](https://app.terraform.io/signup)

### 2. Create Organization

1. Log into HCP Terraform
2. Click **Create Organization**
3. Name: `your-org-name`

### 3. Create Workspaces

Create separate workspaces for each deployment component:

**Required workspaces:**
- `hashistack-dc1` - Primary datacenter (VM servers)
- `hashistack-dc2` - Secondary datacenter (VM servers) - *optional for multi-DC*

**Optional workspaces (for advanced features):**
- `gke-europe-west1` - GKE cluster for admin partitions
- `gke-southwest` - Second GKE cluster for admin partitions

**Workspace settings:**
- **Execution Mode:** Remote
- **Terraform Version:** 1.5+
- **Auto Apply:** Disabled (recommended for safety)

### 4. Configure CLI Authentication

```bash
# Login to HCP Terraform from CLI
terraform login

# This opens browser for authentication
# Follow prompts to generate API token
```

---

## Variable Sets

HCP Terraform uses **Variable Sets** to share common variables across multiple workspaces. Create two variable sets:

### Variable Set 1: GCP Common

**Purpose:** GCP authentication and project configuration

**Name:** `GCP Common`

**Variables:**

| Variable Name | Type | Sensitive | Value | Description |
|--------------|------|-----------|-------|-------------|
| `GOOGLE_CREDENTIALS` | Environment | **Yes** | `<entire JSON content>` | Service account JSON key from step 4 above |
| `gcp_project` | Terraform | No | `your-gcp-project-id` | GCP Project ID |
| `gcp_region` | Terraform | No | `europe-north1` | Default GCP region |
| `ssh_public_key` | Terraform | No | `ssh-rsa AAAAB3...` | Your SSH public key for VM access |
| `ssh_username` | Terraform | No | `debian` | SSH username (keep as `debian`) |

**How to add service account JSON:**
1. Open the JSON file: `cat ~/terraform-deployer-key.json`
2. Copy the **entire JSON content** (including `{` and `}`)
3. In HCP Terraform, add variable `GOOGLE_CREDENTIALS` (Environment variable)
4. Mark as **Sensitive**
5. Paste entire JSON as value

**Apply this variable set to:** All workspaces (dc1, dc2, gke-west1, gke-southwest)

### Variable Set 2: HashiStack Common

**Purpose:** HashiCorp product versions and licenses

**Name:** `HashiStack Common`

**Variables:**

| Variable Name | Type | Sensitive | Value | Description |
|--------------|------|-----------|-------|-------------|
| `consul_license` | Terraform | **Yes** | `your-consul-ent-license` | Consul Enterprise license key |
| `nomad_license` | Terraform | **Yes** | `your-nomad-ent-license` | Nomad Enterprise license key |
| `consul_version` | Terraform | No | `1.21.2+ent` | Consul Enterprise version |
| `nomad_version` | Terraform | No | `1.10.3+ent` | Nomad Enterprise version |
| `vault_version` | Terraform | No | `1.14.1` | Vault version |

**Optional variables:**
- `dns_zone` (Terraform, No) - DNS zone name if using custom domains
- `cluster_name` (Terraform, No) - Base name for clusters (e.g., `demo-hashistack`)

**Apply this variable set to:** All workspaces (dc1, dc2, gke-west1, gke-southwest)

---

## Packer Configuration (If Building Custom Images)

If you're building custom VM images with Packer, configure these variables:

### Option A: HCP Packer (Recommended)

Use HCP Packer for image registry and tracking.

**Setup:**
1. Enable HCP Packer in your HCP organization
2. Generate HCP service principal credentials
3. Set environment variables:

```bash
export HCP_CLIENT_ID="your-hcp-client-id"
export HCP_CLIENT_SECRET="your-hcp-client-secret"
export HCP_PROJECT_ID="your-hcp-project-id"
```

**Packer variables file** (`packer/gcp/variables.pkrvars.hcl`):
```hcl
gcp_project = "your-gcp-project-id"
sshuser     = "packer"
```

**Authenticate Packer with GCP:**
```bash
# Use the same service account JSON
export GOOGLE_CREDENTIALS="$(cat ~/terraform-deployer-key.json)"

# Or use application default credentials
gcloud auth application-default login
```

### Option B: Packer without HCP

If not using HCP Packer registry:

**Packer variables file** (`packer/gcp/variables.pkrvars.hcl`):
```hcl
gcp_project = "your-gcp-project-id"
sshuser     = "packer"

# Optional: customize versions
# consul_version = "1.21.2+ent"
# nomad_version = "1.10.3+ent"
# vault_version = "1.14.1"
```

**Authenticate:**
```bash
export GOOGLE_CREDENTIALS="$(cat ~/terraform-deployer-key.json)"
```

**Build images:**
```bash
cd packer/gcp
packer build -var-file="variables.pkrvars.hcl" .
```

**Documentation:** [Packer GCP Builder](https://developer.hashicorp.com/packer/plugins/builders/googlecompute)

---

## Alternative: Local tfvars (Not Recommended)

If you prefer not to use HCP Terraform, you can use local `terraform.auto.tfvars` files.

**Create `clusters/dc1/terraform/terraform.auto.tfvars`:**

```hcl
# GCP Configuration
gcp_project    = "your-gcp-project-id"
gcp_region     = "europe-north1"
cluster_name   = "demo-hashistack"

# SSH Access
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ..."
ssh_username   = "debian"

# HashiCorp Licenses (SENSITIVE - do not commit)
consul_license = "your-consul-enterprise-license"
nomad_license  = "your-nomad-enterprise-license"

# Versions
consul_version = "1.21.2+ent"
nomad_version  = "1.10.3+ent"
vault_version  = "1.14.1"

# Optional
# dns_zone = "your-dns-zone-name"
```

**Set GCP credentials as environment variable:**
```bash
export GOOGLE_CREDENTIALS="$(cat ~/terraform-deployer-key.json)"
```

**Important:** Add `terraform.auto.tfvars` to `.gitignore` to prevent committing secrets.

---

## SSH Key Setup

Generate SSH key pair for VM access:

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f ~/.ssh/hashistack_rsa

# View public key (add to HCP Terraform variable set)
cat ~/.ssh/hashistack_rsa.pub

# Output: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... your-email@example.com
```

Copy the entire public key output and add it to the `ssh_public_key` variable in your **GCP Common** variable set.

---

## Enterprise Licenses

### Obtaining Licenses

- **Consul Enterprise:** Contact HashiCorp sales or use HCP trial
- **Nomad Enterprise:** Contact HashiCorp sales or use HCP trial

**Trial licenses:** Visit [HashiCorp Trial](https://www.hashicorp.com/products/consul/trial) or use HCP free tier.

### Adding Licenses to HCP Terraform

1. Navigate to your organization settings
2. Open **HashiStack Common** variable set
3. Add `consul_license` and `nomad_license` as **sensitive** variables
4. Paste the license strings (they're long - this is normal)

---

## Verification Checklist

Before proceeding to deployment, verify:

- [ ] All required tools installed (`task`, `terraform`, `packer`, `gcloud`, `kubectl`, `consul`, `nomad`)
- [ ] GCP project created and APIs enabled
- [ ] Service account created with proper IAM roles
- [ ] Service account JSON key generated
- [ ] HCP Terraform account created
- [ ] HCP Terraform organization created
- [ ] Workspaces created (at minimum: `hashistack-dc1`)
- [ ] **GCP Common** variable set created with `GOOGLE_CREDENTIALS` (entire JSON)
- [ ] **HashiStack Common** variable set created with licenses
- [ ] Variable sets applied to appropriate workspaces
- [ ] SSH key pair generated and public key added to variables
- [ ] Enterprise licenses obtained and added to variables

---

## What's Next?

You're now ready to begin deployment. The recommended order is:

1. **[Build Custom Images](../infrastructure/Image-Building-with-Packer.md)** - Create VM images with HashiStack pre-installed
2. **[Deploy VM Clusters](../infrastructure/VM-Cluster-Deployment.md)** - Deploy DC1 (and optionally DC2) servers
3. **[Configure Boundary Access](../infrastructure/Secure-Access-with-Boundary.md)** - Set up secure SSH access (recommended)
4. **[Set Up Cluster Peering](../advanced-features/Cluster-Peering.md)** - Connect DC1 and DC2 (if multi-DC)
5. **[Deploy Monitoring](../operations/Monitoring-and-Observability.md)** - Add Prometheus and Grafana
6. **[Deploy Admin Partitions](../advanced-features/Admin-Partitions.md)** - Multi-tenant Kubernetes integration (optional)

Or jump to: **[Quick Start Guide](Quick-Start-Guide.md)** for a streamlined deployment walkthrough.

---

**Next:** [Quick Start Guide](Quick-Start-Guide.md) | **[Back to Top](#prerequisites-and-setup)**
