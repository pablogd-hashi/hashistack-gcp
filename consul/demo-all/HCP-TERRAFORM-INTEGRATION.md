# CTS Integration with HCP Terraform - Hybrid Approach

Since CTS doesn't directly support HCP Terraform's remote backend, this document outlines a hybrid approach that combines local CTS execution with HCP Terraform workspace integration.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Consul        │    │      CTS         │    │  HCP Terraform      │
│  (GCP Cluster)  │───▶│   (Local Run)    │───▶│   GKE-southwest     │
│                 │    │                  │    │    Workspace        │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  Generated       │
                       │  Terraform       │
                       │  Configuration   │
                       └──────────────────┘
```

## How It Works

1. **CTS monitors** Consul services in k8s-southwest1 partition
2. **When services change**, CTS executes Terraform locally
3. **Terraform generates** HCP-compatible configuration files
4. **Configuration files** can be committed to your workspace repository
5. **HCP Terraform** applies changes via standard GitOps workflow

## Key Benefits

- **No CTS limitations**: Works around CTS remote backend restrictions
- **Existing workspace integration**: Uses your current GKE-southwest workspace
- **GitOps compatibility**: Generated configs follow standard Git workflows
- **Audit trail**: Full visibility in both Consul KV and HCP Terraform
- **Production-ready**: Real firewall rules and infrastructure updates

## Generated Configuration Example

CTS generates Terraform configuration like this:

```hcl
terraform {
  cloud {
    organization = "pablogd-hcp-test"
    workspaces {
      name = "GKE-southwest"
    }
  }
}

# CTS-discovered services (5 services found)
locals {
  cts_services = {
    "frontend" = {
      address = "10.20.1.5"
      port = 8080
      name = "frontend"
      tags = ["k8s-southwest1", "production"]
    }
    # ... other services
  }
}

# Reference existing infrastructure
data "google_container_cluster" "existing_cluster" {
  name     = "gke-southwest-gke"
  location = "europe-southwest1"
}

data "google_compute_network" "existing_network" {
  name = "gke-southwest-gke-network"
}

# CTS-managed firewall rules
resource "google_compute_firewall" "cts_frontend_ingress" {
  name    = "cts-boutique-frontend-ingress"
  network = data.google_compute_network.existing_network.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-node"]
  description   = "CTS managed: frontend service (10.20.1.5:8080)"
}
```

## Integration Workflow

### 1. Local CTS Execution
```bash
consul-terraform-sync start -config-file=consul-terraform-sync.hcl
```

### 2. Monitor Generated Configuration
```bash
# View generated config
cat /tmp/cts-generated-config.tf

# View service discovery status
cat /tmp/gke-southwest-services.json | jq '.'

# Check Consul KV state
consul kv get cts/gke-southwest/services/current_state | jq '.'
```

### 3. HCP Terraform Integration
```bash
# Option A: Manual integration
cp /tmp/cts-generated-config.tf ~/path/to/gke-southwest-repo/cts-config.tf
cd ~/path/to/gke-southwest-repo
git add cts-config.tf
git commit -m "Update CTS-discovered infrastructure"
git push  # Triggers HCP Terraform run

# Option B: Automated script (future enhancement)
./scripts/sync-cts-to-hcp.sh
```

## File Locations

- **CTS Config**: `consul-terraform-sync.hcl`
- **Generated Terraform**: `/tmp/cts-generated-config.tf`
- **Service Monitoring**: `/tmp/gke-southwest-services.json`
- **Consul KV State**: `cts/gke-southwest/infrastructure/*`

## Security Considerations

- **Local GCP credentials**: Ensure proper authentication for GKE data sources
- **Consul tokens**: Use appropriate ACL tokens for service discovery
- **Firewall rules**: Review generated rules before applying to production
- **HCP Terraform**: Use workspace-specific variables for sensitive data

## Monitoring and Troubleshooting

### CTS Status
```bash
curl -s http://localhost:8558/v1/status | jq '.'
curl -s http://localhost:8558/v1/status/tasks | jq '.'
```

### Generated Config Validation
```bash
cd /tmp && terraform validate cts-generated-config.tf
```

### HCP Terraform Monitoring
- Monitor runs at: https://app.terraform.io/app/pablogd-hcp-test/workspaces/GKE-southwest
- Check variables and environment settings
- Review plan outputs before applying

## Future Enhancements

1. **Automated Git Integration**: Script to automatically commit and push generated configs
2. **Multi-Workspace Support**: Extend to GKE-europe-west1 workspace
3. **Advanced Filtering**: More sophisticated service discovery rules
4. **Notification Integration**: Slack/Teams notifications for infrastructure changes
5. **Rollback Capability**: Automated rollback on HCP Terraform apply failures

## Conclusion

This hybrid approach provides the best of both worlds:
- Real-time service discovery through CTS
- Enterprise-grade infrastructure management through HCP Terraform
- Existing workspace and workflow integration
- Full audit trail and change management

The generated Terraform configurations are production-ready and integrate seamlessly with your existing GKE Southwest infrastructure.