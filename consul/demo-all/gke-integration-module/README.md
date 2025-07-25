# GKE Southwest CTS Integration Module

This Terraform module integrates Consul Terraform Sync (CTS) with your existing GKE-southwest HCP Terraform workspace. It automatically updates infrastructure based on service changes detected by Consul.

## What This Module Does

When CTS detects changes in your k8s-southwest1 partition services, this module:

1. **Firewall Integration**: Creates additional firewall rules for frontend services
2. **Service Discovery**: Optionally creates DNS records for external service access
3. **Monitoring Integration**: Updates monitoring configurations with current service endpoints
4. **Consul KV Tracking**: Stores infrastructure state in Consul KV for audit trails

## Integration with Existing Infrastructure

This module references your existing GKE Southwest infrastructure:

- **GKE Cluster**: `gke-southwest-gke` in `europe-southwest1`
- **Network**: `gke-southwest-gke-network`
- **Firewall Rules**: Adds rules to existing network for service access
- **HCP Terraform Workspace**: `GKE-southwest`

## Configuration

The module is configured to work with:

- **Consul Partition**: `k8s-southwest1`
- **Consul Namespace**: `production`
- **Target Services**: frontend, productcatalogservice, cartservice, currencyservice, redis-cart

## Prerequisites

1. Existing GKE Southwest cluster deployed via HCP Terraform
2. Consul Enterprise with k8s-southwest1 partition configured
3. CTS running with access to both Consul and HCP Terraform
4. Appropriate GCP permissions for firewall and DNS management

## Outputs

- `gke_integration_summary`: Details of infrastructure integration
- `service_endpoints`: Service endpoint information for external consumption

## DNS Configuration

To enable DNS record creation:

1. Update `dns_zone_name` variable with your actual Cloud DNS zone
2. Update `domain_name` variable with your domain
3. Set `enable_dns_records = true`

## Security Considerations

- Firewall rules are created with appropriate source ranges
- Service access is controlled through Consul service mesh
- Infrastructure changes are tracked in Consul KV for audit trails