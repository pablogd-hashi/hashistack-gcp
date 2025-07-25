# GKE Cluster (europe-west1)

Google Kubernetes Engine cluster deployed in europe-west1 region, co-located with DC1 HashiCorp infrastructure.

## Configuration

- **Region**: europe-west1
- **Zones**: europe-west1-b, europe-west1-c, europe-west1-d
- **Cluster Name**: gke-cluster
- **TFC Workspace**: GKE-europe-west1
- **Node Type**: e2-standard-4
- **Auto-scaling**: 1-3 nodes per zone

## Quick Start

```bash
# Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# Get cluster info
terraform output cluster_info
terraform output kubectl_commands

# Authenticate with cluster
eval "$(terraform output -raw gke_auth_command)"

# Verify connection
kubectl get nodes
kubectl get namespaces
```

## Network Configuration

- **VPC**: Dedicated GKE network (10.10.0.0/24)
- **Pods**: 10.11.0.0/16
- **Services**: 10.12.0.0/16
- **Private Cluster**: Nodes in private subnets
- **Network Policy**: Enabled for micro-segmentation

## Features

- **Regional Cluster**: High availability across 3 zones
- **Workload Identity**: Secure GCP service integration
- **Auto-scaling**: Node pools scale based on demand
- **Auto-repair/upgrade**: Managed node maintenance
- **Private Nodes**: Enhanced security
- **Network Policy**: Pod-to-pod traffic control

## Integration with HashiCorp Stack

This GKE cluster is positioned to integrate with the existing HashiCorp infrastructure:

- **Consul Connect**: Service mesh across K8s and Nomad
- **Consul Service Discovery**: Cross-platform service registration
- **Shared Monitoring**: Prometheus/Grafana visibility
- **Network Connectivity**: VPC peering potential

## Access Points

After deployment, use:

```bash
# Get authentication command
terraform output gke_auth_command

# Connect to cluster
gcloud container clusters get-credentials <cluster-name> --region europe-west1 --project <project-id>

# Verify cluster access
kubectl cluster-info
kubectl get nodes -o wide
```