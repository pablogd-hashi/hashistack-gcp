# Installation Guide

## Prerequisites

### 1. Install Task (Task Runner)

**macOS:**
```bash
brew install go-task/tap/go-task
```

**Linux:**
```bash
# Download latest release
curl -sL https://github.com/go-task/task/releases/latest/download/task_linux_amd64.tar.gz | tar -xz
sudo mv task /usr/local/bin/
```

**Windows:**
```powershell
# Using Chocolatey
choco install go-task

# Or using Scoop
scoop install task
```

**Or install via Go:**
```bash
go install github.com/go-task/task/v3/cmd/task@latest
```

### 2. Required Tools

- **Terraform** ≥ 1.0: https://terraform.io/downloads
- **Packer** (for custom images): https://packer.io/downloads  
- **Nomad CLI** (for job management): https://nomadproject.io/downloads
- **Consul CLI** (for cluster management): https://consul.io/downloads
- **jq** (for JSON processing): https://jqlang.github.io/jq/download/
- **Google Cloud SDK**: https://cloud.google.com/sdk/docs/install

### 3. GCP Setup

```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
source ~/.bashrc

# Authenticate
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

### 4. Terraform Cloud Setup (Optional)

1. Create account at https://app.terraform.io
2. Create organization and workspace
3. Update `terraform/versions.tf` with your org/workspace names

## Quick Start

1. **Clone and configure:**
   ```bash
   git clone <repository>
   cd nomad-consul-terramino
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **See available tasks:**
   ```bash
   task
   ```

3. **Deploy everything:**
   ```bash
   task demo
   ```

## Task Commands Reference

### Infrastructure Management
- `task tf:init` - Initialize Terraform
- `task tf:plan` - Plan infrastructure changes
- `task tf:apply` - Deploy infrastructure
- `task tf:destroy` - Destroy infrastructure
- `task tokens` - Get all authentication tokens

### Application Deployment
- `task deploy:core` - Deploy core services (Traefik, Prometheus, Grafana)
- `task deploy:terramino` - Deploy demo application
- `task deploy:all` - Deploy everything
- `task jobs:status` - Check job status

### Image Building (Optional)
- `task packer:build:server` - Build server image
- `task packer:build:client` - Build client image
- `task packer:build:all` - Build all images

### Development & Testing
- `task test:all` - Run all validation tests
- `task status` - Show system status
- `task ssh:server` - SSH to first server
- `task clean:all` - Clean everything

### Environment Setup
- `task env:setup` - Show environment variables to set
- `eval "$(task env:setup:eval)"` - Set environment variables

## Configuration Files

### Required Configuration

1. **terraform/terraform.tfvars** (copy from example):
   ```hcl
   project_id     = "your-gcp-project"
   gcp_sa         = "service-account@project.iam.gserviceaccount.com"
   ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
   consul_license = "02MV4UU43BK5HGYTOJZWFQZLE52BQ..."
   nomad_license  = "02MV4UU43BK5HGYTOJZWFQZLE52BQ..."
   ```

2. **packer/variables/common.pkrvars.hcl** (if building custom images):
   ```hcl
   project_id = "your-gcp-project"
   region     = "us-central1"
   zone       = "us-central1-a"
   ```

### Environment Variables

For HCP Packer (if building custom images):
```bash
export HCP_CLIENT_ID="your-hcp-client-id"
export HCP_CLIENT_SECRET="your-hcp-client-secret"
```

## Deployment Workflow

1. **Full deployment:**
   ```bash
   task demo
   ```

2. **Step-by-step deployment:**
   ```bash
   # 1. Deploy infrastructure
   task tf:apply
   
   # 2. Get access tokens
   task tokens
   
   # 3. Set environment
   eval "$(task env:setup:eval)"
   
   # 4. Deploy services
   task deploy:all
   
   # 5. Check status
   task status
   ```

3. **Custom images (optional):**
   ```bash
   # Build custom images first
   task packer:build:all
   
   # Then deploy infrastructure
   task tf:apply
   ```

## Troubleshooting

### Common Issues

1. **"Task not found"**
   - Install Task: `brew install go-task/tap/go-task`
   
2. **"terraform.tfvars not found"**
   - Copy example: `cp terraform/terraform.tfvars.example terraform/terraform.tfvars`
   - Edit with your values
   
3. **"Nomad not accessible"**
   - Check if infrastructure deployed: `task tf:output`
   - Set environment: `eval "$(task env:setup:eval)"`
   
4. **"Permission denied"**
   - Check GCP authentication: `gcloud auth list`
   - Verify service account permissions

### Getting Help

- List all tasks: `task`
- Show system status: `task status`
- Get access tokens: `task tokens`
- View logs: `task ssh:server` then `journalctl -u consul`