# DC1 Cluster (us-east2)

Primary HashiCorp cluster deployed in us-east2 region.

## Configuration

- **Region**: us-east2
- **Cluster Name**: gcp-dc1
- **HCP Workspace**: hashistack-terramino-nomad-consul
- **DNS Prefix**: *-gcp-dc1.yourdomain.com

## Quick Start

```bash
# Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# Get access information
terraform output cluster_info
terraform output hashistack_urls
terraform output monitoring_urls

# Set up environment
eval "$(terraform output -raw environment_setup | grep 'bash_export' -A 10)"

# Deploy applications
ssh ubuntu@$(gcloud compute instances list --filter='name~hashi-server' --format='value(natIP)' --limit=1)
export NOMAD_ADDR=http://localhost:4646
export NOMAD_TOKEN="$(terraform output -raw auth_tokens | jq -r '.nomad_token')"

nomad job run jobs/core/traefik.nomad.hcl
nomad job run jobs/monitoring/prometheus.hcl
nomad job run jobs/monitoring/grafana.hcl
```

## Access URLs

- **Consul UI**: Use `terraform output hashistack_urls`
- **Nomad UI**: Use `terraform output hashistack_urls`
- **Grafana**: Use `terraform output monitoring_urls`
- **Traefik**: Use `terraform output monitoring_urls`