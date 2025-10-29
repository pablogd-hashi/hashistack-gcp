# Image Building with Packer

**Navigation:** [Home](../Home.md) > [Core Infrastructure](Image-Building-with-Packer.md) > Image Building with Packer

> **Quick Links:** [Prerequisites](#prerequisites) | [Quick Start](#quick-start) | [Image Contents](#image-contents)

---

## Overview

Build custom VM images with HashiCorp Consul Enterprise and Nomad Enterprise pre-installed for fast, consistent cluster deployment.

**Why custom images:**
- Faster deployment (binaries pre-installed)
- Consistent configuration across all clusters
- Reduced startup time
- Immutable infrastructure approach

**Build time:** 8-12 minutes

---

## Prerequisites

**Before building images, complete:**
- [Prerequisites and Setup](../getting-started/Prerequisites-and-Setup.md) - GCP project, service account, APIs enabled
- Packer installed (`brew install packer`)
- `GOOGLE_CREDENTIALS` environment variable set with service account JSON

**Required GCP APIs:**
- Compute Engine API (compute.googleapis.com)

**Authentication:**
```bash
# Set credentials from service account JSON
export GOOGLE_CREDENTIALS="$(cat ~/terraform-deployer-key.json)"

# Or use application default credentials
gcloud auth application-default login
```

---

## Quick Start

### Step 1: Configure Variables

Create Packer variables file:

```bash
cd packer/gcp
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

**Edit `variables.pkrvars.hcl`:**
```hcl
# Required
gcp_project = "your-gcp-project-id"
sshuser     = "packer"

# Optional: customize versions
# consul_version = "1.21.2+ent"
# nomad_version = "1.10.3+ent"
# vault_version = "1.14.1"
```

### Step 2: Build Images

**Option A: Using Task (Recommended)**
```bash
# From project root
task build-images
```

**Option B: Direct Packer Command**
```bash
cd packer/gcp
packer build -var-file="variables.pkrvars.hcl" .
```

**Build output:**
```
==> Builds finished. The artifacts of successful builds are:
--> consul-nomad.gcp: A disk image was created: consul-nomad-1-21-2-ent-1-10-3-ent
```

### Step 3: Verify Image

```bash
# List created images
gcloud compute images list --filter="family=hashistack"

# Expected output:
# NAME                                FAMILY      STATUS
# consul-nomad-1-21-2-ent-1-10-3-ent  hashistack  READY
```

---

## Image Contents

### Pre-installed Software

| Software | Version | Purpose |
|----------|---------|---------|
| **Consul Enterprise** | 1.21.2+ent | Service mesh and service discovery |
| **Nomad Enterprise** | 1.10.3+ent | Workload orchestration |
| **Vault** | 1.14.1 | Secrets management (Community) |
| **Docker** | Latest | Container runtime |
| **CNI Plugins** | Latest | Container networking |
| **Envoy Proxy** | Latest | Service mesh data plane |

### System Configuration

- Systemd services configured for Consul, Nomad, Vault
- TLS certificates directory structure (`/etc/consul.d/tls/`, `/etc/nomad.d/tls/`)
- Data directories (`/opt/consul/`, `/opt/nomad/`)
- Docker configured for Nomad integration
- Network optimization for GCP

### Build Process

```
Debian 12 Base Image
├── Install HashiCorp GPG keys
├── Add HashiCorp APT repository
├── Install Consul Enterprise
├── Install Nomad Enterprise
├── Install Vault (Community)
├── Install Docker + CNI plugins + Envoy
├── Configure systemd services
├── Create directory structure
└── Apply security hardening
```

---

## Configuration Options

### Available Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `gcp_project` | GCP Project ID | - | Yes |
| `sshuser` | SSH username for build | `packer` | Yes |
| `gcp_zone` | Build instance zone | `europe-southwest1-a` | No |
| `consul_version` | Consul Enterprise version | `1.21.2+ent` | No |
| `nomad_version` | Nomad Enterprise version | `1.10.3+ent` | No |
| `vault_version` | Vault version | `1.14.1` | No |
| `image` | Base image name | `consul-nomad` | No |
| `image_family` | Image family tag | `hashistack` | No |

### Version Pinning

For consistent builds, pin specific versions:

```hcl
# In variables.pkrvars.hcl
consul_version = "1.21.0+ent"
nomad_version = "1.10.2+ent"
vault_version = "1.14.1"
```

### Zone Selection

Build in the same region as your deployment for faster image availability:

```hcl
# For europe-north1 deployments
gcp_zone = "europe-north1-a"

# For europe-west1 deployments
gcp_zone = "europe-west1-b"
```

---

## HCP Packer Integration (Optional)

Use HCP Packer for image registry and version tracking.

**Setup:**

1. Enable HCP Packer in your HCP organization
2. Generate service principal credentials:
   - Navigate to HCP → Access control → Service principals
   - Create new service principal
   - Note the Client ID and Secret

3. Set environment variables:
```bash
export HCP_CLIENT_ID="your-hcp-client-id"
export HCP_CLIENT_SECRET="your-hcp-client-secret"
export HCP_PROJECT_ID="your-hcp-project-id"
```

4. Build with HCP Packer:
```bash
cd packer/gcp
packer build -var-file="variables.pkrvars.hcl" .
```

Images will be registered in HCP Packer registry with full metadata and version history.

**Documentation:** [HCP Packer](https://developer.hashicorp.com/hcp/docs/packer)

---

## Alternative Build Methods

### Environment Variables

```bash
export PKR_VAR_gcp_project="your-gcp-project-id"
export PKR_VAR_sshuser="packer"

cd packer/gcp
packer build .
```

### Command Line Variables

```bash
cd packer/gcp
packer build \
  -var="gcp_project=your-gcp-project-id" \
  -var="sshuser=packer" \
  .
```

### Validate Before Building

```bash
cd packer/gcp
packer validate -var-file="variables.pkrvars.hcl" .
```

---

## Integration with Terraform

Terraform deployments automatically reference images by family name:

```hcl
# In clusters/dc1/terraform/instances.tf
data "google_compute_image" "hashistack" {
  family  = "hashistack"
  project = var.gcp_project
}

resource "google_compute_instance" "server" {
  boot_disk {
    initialize_params {
      image = data.google_compute_image.hashistack.self_link
    }
  }
}
```

When you build a new image, Terraform will use the latest image from the "hashistack" family on the next deployment.

---

## Build Verification

Test the built image before deploying clusters:

```bash
# Create test instance
gcloud compute instances create test-hashistack \
  --image-family=hashistack \
  --zone=europe-north1-a \
  --machine-type=e2-medium

# SSH to instance
gcloud compute ssh test-hashistack --zone=europe-north1-a

# Verify installations
consul version   # Should show 1.21.2+ent
nomad version    # Should show 1.10.3+ent
vault version    # Should show 1.14.1
docker version   # Should show latest

# Check systemd services
systemctl status consul   # Should be loaded, inactive
systemctl status nomad    # Should be loaded, inactive

# Clean up
exit
gcloud compute instances delete test-hashistack --zone=europe-north1-a --quiet
```

---

## Image Management

### List Images

```bash
# List all hashistack images
gcloud compute images list --filter="family=hashistack"

# List with details
gcloud compute images list \
  --filter="family=hashistack" \
  --format="table(name,family,creationTimestamp,diskSizeGb)"
```

### Delete Old Images

```bash
# Delete specific image
gcloud compute images delete consul-nomad-1-21-0-ent-1-10-2-ent --quiet

# Keep only the latest 3 images (recommended)
gcloud compute images list \
  --filter="family=hashistack" \
  --sort-by="~creationTimestamp" \
  --format="value(name)" \
  | tail -n +4 \
  | xargs -I {} gcloud compute images delete {} --quiet
```

### Image Costs

Images are stored as GCP resources and incur storage costs:
- Standard storage: ~$0.085 per GB per month
- Typical image size: 10-15 GB
- Cost per image: ~$1-2 per month

Clean up old images periodically to reduce costs.

---

## Best Practices

1. **Build images before infrastructure** - Always build images first
2. **Pin versions for production** - Use specific versions in variables
3. **Use HCP Packer** - Track image versions and metadata
4. **Test images** - Verify installations before deploying clusters
5. **Clean up old images** - Keep only 2-3 recent versions
6. **Use automation** - Run `task build-images` for consistency
7. **Document changes** - Note any custom modifications to build scripts

---

## File Structure

```
packer/gcp/
├── consul_gcp.pkr.hcl           # Packer configuration
├── variables.pkrvars.hcl        # Your variables (create from example)
├── variables.pkrvars.hcl.example # Example variables
└── ../
    ├── consul_prep.sh           # Consul installation script
    └── nomad_prep.sh            # Nomad installation script
```

---

## What's Next?

After building images:

1. **[Deploy VM Clusters](VM-Cluster-Deployment.md)** - Deploy DC1 and DC2 servers
2. **Or: [Quick Start Guide](../getting-started/Quick-Start-Guide.md)** - Complete deployment walkthrough

---

**Previous:** [Architecture Overview](../getting-started/Architecture-Overview.md) | **Next:** [VM Cluster Deployment](VM-Cluster-Deployment.md) | **[Back to Top](#image-building-with-packer)**
