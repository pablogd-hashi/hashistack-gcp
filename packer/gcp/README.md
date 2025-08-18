# Packer Image Building

Build custom VM images with HashiCorp Consul Enterprise and Nomad Enterprise pre-installed for fast cluster deployment.

**📖 [Back to Main README](../../README.md)**

## Why Custom Images?

Custom images provide significant deployment advantages:

- **Faster deployment** - HashiCorp binaries are pre-installed
- **Consistent configuration** - Same base image across all clusters
- **Reduced startup time** - No need to download and install software during instance creation
- **Immutable infrastructure** - Consistent, reproducible deployments

## Prerequisites

### Required Tools
- **Packer** v1.9+ installed (`brew install packer` or [download](https://www.packer.io/downloads))
- **Google Cloud SDK** configured with appropriate credentials
- **GCP project** with Compute Engine API enabled

### Required Permissions
- **Compute Instance Admin** role for creating build instances
- **Service Account User** role for using compute service accounts
- **Storage Admin** role for storing built images

## Quick Start

### 1. Configure Variables

Create a variables file with your project details:

```bash
cd packer/gcp
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
vi variables.pkrvars.hcl
```

**Required variables:**
```hcl
gcp_project = "your-gcp-project-id"
sshuser     = "packer"
```

### 2. Build Images

```bash
# From project root
task build-images

# Or manually from packer directory
cd packer/gcp
packer build -var-file="variables.pkrvars.hcl" .
```

### 3. Verify Images

```bash
# List created images
gcloud compute images list --filter="family=hashistack" --format="table(name,family,creationTimestamp)"
```

## Configuration

### Variables File

Create `variables.pkrvars.hcl` based on the example file:

```hcl
# Required: Your GCP project ID
gcp_project = "your-gcp-project-id"

# Required: SSH user for Packer build (keep as "packer")
sshuser = "packer"

# Optional: Override default zone
# gcp_zone = "europe-southwest1-a"

# Optional: Override HashiCorp versions
# consul_version = "1.21.2+ent"  
# nomad_version = "1.10.3+ent"
# vault_version = "1.14.1"

# Optional: Override image naming
# image = "consul-nomad"
# image_family = "hashistack"
```

### Available Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `gcp_project` | GCP Project ID | - | ✅ |
| `sshuser` | SSH username for build | `"packer"` | ✅ |
| `gcp_zone` | Build instance zone | `"europe-southwest1-a"` | - |
| `consul_version` | Consul Enterprise version | `"1.21.2+ent"` | - |
| `nomad_version` | Nomad Enterprise version | `"1.10.3+ent"` | - |
| `vault_version` | Vault version | `"1.14.1"` | - |
| `image` | Base image name | `"consul-nomad"` | - |
| `image_family` | Image family | `"hashistack"` | - |
| `source_image_family` | Source OS image | `"debian-12"` | - |

## Image Contents

The built image includes:

### Pre-installed Software
- **Consul Enterprise** (latest stable + Enterprise license support)
- **Nomad Enterprise** (latest stable + Enterprise license support) 
- **Vault** (Community edition)
- **Docker** (for containerized workloads)
- **CNI plugins** (for networking)
- **Envoy proxy** (for service mesh)

### Configuration
- **Systemd services** configured for all HashiCorp tools
- **TLS certificates** directory structure prepared
- **Data directories** created with proper permissions
- **Network configuration** optimized for GCP

### Build Process
```
Debian 12 Base Image
├── Install HashiCorp GPG keys
├── Add HashiCorp APT repository
├── Install Consul Enterprise
├── Install Nomad Enterprise  
├── Install Vault
├── Install Docker and dependencies
├── Configure systemd services
├── Create directory structure
└── Apply security hardening
```

## Build Process

### What Happens During Build

1. **Instance Creation**: Packer launches a temporary GCP instance
2. **Software Installation**: Runs provisioning scripts to install HashiCorp tools
3. **Configuration**: Sets up systemd services and directory structure
4. **Image Creation**: Creates a snapshot of the configured instance
5. **Cleanup**: Destroys temporary instance, keeping only the image

### Build Scripts

The build process uses these scripts:
- `../consul_prep.sh` - Installs and configures Consul Enterprise
- `../nomad_prep.sh` - Installs and configures Nomad Enterprise

### Build Time
- **Typical duration**: 8-12 minutes
- **Instance type**: e2-standard-2 (optimized for build speed)
- **Network**: Uses default GCP networking

## Advanced Configuration

### Custom Zone Selection
```hcl
# Build in specific zone for faster deployment
gcp_zone = "europe-southwest1-a"  # For DC1 deployments
gcp_zone = "europe-west1-b"       # For DC2 deployments
```

### Version Pinning
```hcl
# Pin specific versions for consistency
consul_version = "1.21.0+ent"
nomad_version = "1.10.2+ent"
vault_version = "1.14.1"
```

### Alternative Build Methods

#### Environment Variables
```bash
export PKR_VAR_gcp_project="your-gcp-project-id"
export PKR_VAR_sshuser="packer"
packer build .
```

#### Command Line Variables
```bash
packer build \
  -var="gcp_project=your-gcp-project-id" \
  -var="sshuser=packer" \
  .
```

### HCP Packer Integration
To enable HCP Packer registry (optional):

```hcl
# Uncomment in consul_gcp.pkr.hcl
hcp_packer_registry {
  bucket_name = "consul-nomad"
  description = "HashiStack images for GCP"
  bucket_labels = {
    "hashicorp" = "Vault,Consul,Nomad",
    "platform"  = "gcp",
    "owner"     = "your-name"
  }
}
```

## Troubleshooting

### Common Issues

**Build Fails with Permission Errors:**
- Ensure GCP credentials are configured: `gcloud auth list`
- Verify Compute Engine API is enabled: `gcloud services enable compute.googleapis.com`
- Check IAM permissions for service account

**SSH Connection Timeouts:**
- Verify VPC firewall rules allow SSH (port 22)
- Check if zone has sufficient compute quota
- Try different zone: `gcp_zone = "europe-west1-b"`

**Image Already Exists Error:**
```bash
# Delete existing image if rebuilding
gcloud compute images delete consul-nomad-1-21-2-ent-1-10-3-ent --quiet
```

**Variables Not Found:**
- Ensure `variables.pkrvars.hcl` exists in `/packer/gcp/` directory
- Check file permissions: `chmod 644 variables.pkrvars.hcl`
- Verify syntax: `packer validate -var-file="variables.pkrvars.hcl" .`

### Debug Commands

```bash
# Validate Packer configuration
packer validate -var-file="variables.pkrvars.hcl" .

# Build with debug logging
PACKER_LOG=1 packer build -var-file="variables.pkrvars.hcl" .

# List available images
gcloud compute images list --filter="family=hashistack"

# Inspect image details
gcloud compute images describe IMAGE_NAME
```

### Build Verification

```bash
# Create test instance from built image
gcloud compute instances create test-hashistack \
  --image-family=hashistack \
  --zone=europe-southwest1-a \
  --machine-type=e2-micro

# SSH to test instance
gcloud compute ssh test-hashistack --zone=europe-southwest1-a

# Verify installations
consul version
nomad version
vault version
docker version

# Clean up test instance
gcloud compute instances delete test-hashistack --zone=europe-southwest1-a --quiet
```

## File Structure

```
packer/gcp/
├── README.md                    # This documentation
├── consul_gcp.pkr.hcl          # Packer configuration
├── variables.pkrvars.hcl       # Your variables (create from example)
└── variables.pkrvars.hcl.example  # Example variables file
```

## Integration with Main Project

The built images are automatically used by:
- **DC1 cluster deployment** in `clusters/dc1/terraform/`
- **DC2 cluster deployment** in `clusters/dc2/terraform/`
- **Taskfile automation** via `task build-images`

The Terraform configurations reference images by family name:
```hcl
# In clusters/*/terraform/instances.tf
source_image_family = "hashistack"
```

## Best Practices

- **Build images first** before deploying infrastructure
- **Pin HashiCorp versions** for production consistency  
- **Use automation** via `task build-images` command
- **Verify images** after building before deploying clusters
- **Clean up old images** periodically to reduce storage costs

## Success Criteria

- ✅ **Image builds successfully** without errors
- ✅ **HashiCorp tools installed** and accessible via PATH
- ✅ **Systemd services configured** for auto-start
- ✅ **Image family tagged** correctly as "hashistack"
- ✅ **Build time under 15 minutes** for efficiency
- ✅ **Compatible with Terraform** infrastructure deployment