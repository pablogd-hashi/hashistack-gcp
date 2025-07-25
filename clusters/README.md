# Multi-Cluster Deployment

This directory contains separate configurations for deploying multiple HashiCorp clusters in different regions.

## Directory Structure

```
clusters/
├── dc1-us-east2/           # Primary cluster (us-east2)
│   ├── terraform/          # Terraform configuration
│   ├── jobs/              # Nomad job definitions
│   └── README.md
└── dc2-us-west2/           # Secondary cluster (us-west2)
    ├── terraform/          # Terraform configuration
    ├── jobs/              # Nomad job definitions
    └── README.md
```

## Prerequisites

1. **HCP Terraform Workspaces**: Create separate workspaces for each cluster
   - `hashistack-terramino-nomad-consul` (dc1)
   - `hashistack-terramino-nomad-consul-dc2` (dc2)

2. **Variable Sets**: Configure in HCP Terraform with same variable values for both workspaces
   - HashiStack Common (licenses, versions)
   - GCP Common (credentials, service account)

## Deployment Instructions

### Deploy DC1 (us-east2)
```bash
cd clusters/dc1-us-east2/terraform
terraform init
terraform plan
terraform apply
```

### Deploy DC2 (us-west2)
```bash
cd clusters/dc2-us-west2/terraform
terraform init
terraform plan
terraform apply
```

## Key Differences Between Clusters

| Configuration | DC1 (us-east2) | DC2 (us-west2) |
|---------------|----------------|----------------|
| Region        | us-east2       | us-west2       |
| Cluster Name  | gcp-dc1        | gcp-dc2        |
| HCP Workspace | hashistack-terramino-nomad-consul | hashistack-terramino-nomad-consul-dc2 |
| DNS Names     | *-gcp-dc1.domain.com | *-gcp-dc2.domain.com |

## Access Points

Each cluster will have its own set of URLs:

### DC1 Access
- Consul: `https://consul-gcp-dc1.yourdomain.com`
- Nomad: `https://nomad-gcp-dc1.yourdomain.com`
- Grafana: `https://grafana-gcp-dc1.yourdomain.com`

### DC2 Access
- Consul: `https://consul-gcp-dc2.yourdomain.com`
- Nomad: `https://nomad-gcp-dc2.yourdomain.com`
- Grafana: `https://grafana-gcp-dc2.yourdomain.com`

## Cluster Interconnection

For connecting clusters (consul federation, nomad federation, etc.), refer to:
- `/peering/` directory for Consul cluster peering
- `/configs/sameness-groups/` for cross-cluster service mesh

## Management Commands

```bash
# Get cluster info
cd clusters/dc1-us-east2/terraform && terraform output cluster_info
cd clusters/dc2-us-west2/terraform && terraform output cluster_info

# Get access tokens
cd clusters/dc1-us-east2/terraform && terraform output -raw auth_tokens
cd clusters/dc2-us-west2/terraform && terraform output -raw auth_tokens

# SSH to clusters
cd clusters/dc1-us-east2/terraform && terraform output quick_commands
cd clusters/dc2-us-west2/terraform && terraform output quick_commands
```

## Cleanup

```bash
# Destroy DC2 first
cd clusters/dc2-us-west2/terraform && terraform destroy

# Then destroy DC1
cd clusters/dc1-us-east2/terraform && terraform destroy
```

## Notes

- Each cluster is completely independent
- Shared Packer images can be used across both clusters
- DNS zones are shared but with different subdomain prefixes
- Enterprise licenses are the same for both clusters