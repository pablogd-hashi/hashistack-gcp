Understood. Here's the **entire `README.md` as a single markdown file**, with **everything fully integrated in one document**—no separations, no repeated sections, fully sequential, and copy-paste ready for your repo:

````markdown
# HashiCorp Enterprise Stack on Google Cloud Platform

This repository deploys a full HashiCorp enterprise environment on Google Cloud Platform (GCP), using **Consul Enterprise** and **Nomad Enterprise** with built-in security, observability, and optional multi-cluster federation. It leverages **Workload Identity Federation** for secure GCP authentication without static credentials.

---

## Overview

This stack includes most of the HashiCorp ecosystem:

- 3x combined **Consul/Nomad Enterprise servers**
- 2x **Nomad clients** for workload execution
- **GCP Load Balancers** with optional DNS integration
- **Workload Identity Federation** for secure cloud auth
- **Packer** (local or HCP) to build custom images
- **Consul Enterprise** `1.21.0+ent` with ACLs and TLS
- **Nomad Enterprise** `1.10.3+ent` with ACLs and secure variables
- **Consul Connect** for service mesh and L4/L7 zero-trust networking
- **Consul-Terraform-Sync (CTS)** for automated infra responses
- [Optional] **Boundary** for secure remote access
- **Traefik v3**, **Prometheus**, and **Grafana** for observability
- [Optional] **API Gateway** if using service mesh

> **By default**, only **Grafana**, **Prometheus**, and **Traefik** are deployed via Nomad.  
> The [Boutique App](https://github.com/GoogleCloudPlatform/microservices-demo) is **only deployed** when using **GKE as an Admin Partition**.

---

## Requirements

### Tools

- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.0  
- [Packer](https://developer.hashicorp.com/packer/downloads) ≥ 1.8  
- [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)  
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (only for GKE)  
- [`task`](https://taskfile.dev/#/installation) (recommended)

### GCP Project Setup

- A GCP project with billing enabled
- Required APIs: Compute, DNS
- IAM roles: Project Owner or Editor, DNS Admin
- A service account or Workload Identity with sufficient permissions

### Licenses

- Valid Consul Enterprise and Nomad Enterprise licenses

---

## Configuration

Create a `terraform.auto.tfvars` or use HCP Terraform variable sets with the following values:

```hcl
gcp_project            = "your-gcp-project-id"
gcp_region             = "europe-north1"
machine_type_server    = "e2-standard-2"
machine_type_client    = "e2-standard-4"
consul_license         = "your-consul-license"
nomad_license          = "your-nomad-license"
consul_version         = "1.21.0+ent"
nomad_version          = "1.10.3+ent"
ssh_public_key         = "your-ssh-key"
dns_zone               = "your-dns-zone"  # optional
cluster_name           = "your-cluster-name"
enable_acls            = true
consul_bootstrap_token = "ConsulR0cks"  # change this
````

---

## Build Custom Images

Custom images are used for Nomad servers and clients. Use Packer to build images:

```bash
# If using task
task build-images

# Or manually
cd packer/gcp
packer build .
```

---

## Deploy Infrastructure

You can deploy a single datacenter or a full multi-cluster environment.

```bash
# Single DC
task deploy-dc1

# Multi-Cluster
task deploy-both
```

---

## Deploy Applications

Default applications include:

* **Grafana**
* **Prometheus**
* **Traefik**

Optional apps:

* [**Boutique App**](https://github.com/GoogleCloudPlatform/microservices-demo): Only available when using GKE + Admin Partition
* **API Gateway**: Optional if using Consul service mesh

Deployment:

```bash
task deploy-monitoring-dc1
task deploy-traefik-dc1
task deploy-demo-apps-dc1
```

---

## Access Points

| Service    | URL                                      |
| ---------- | ---------------------------------------- |
| Consul UI  | `http://consul.your-domain.com:8500`     |
| Nomad UI   | `http://nomad.your-domain.com:4646`      |
| Grafana    | `http://grafana.your-domain.com:3000`    |
| Prometheus | `http://prometheus.your-domain.com:9090` |
| Traefik    | `http://traefik.your-domain.com:8080`    |
| Demo App   | `http://terramino.your-domain.com`       |

---

## Useful Commands

```bash
# Infra lifecycle
task deploy-dc1
task deploy-dc2
task deploy-both
task destroy-dc1
task destroy-both
task status

# Applications
task deploy-monitoring
task deploy-traefik
task deploy-demo-apps

# Node info & debugging
task get-server-ips
task ssh-dc1-server
task show-urls
task eval-vars

# Peering
task peering:setup
task peering:establish
task peering:verify
```

---

## Directory Structure

```text
clusters/
  dc1/terraform/              # Primary datacenter
  dc2/terraform/              # Optional second DC
  gke-*/                      # GKE Admin Partition support

consul/
  admin-partitions/           # Admin Partition configuration
  peering/                    # Cluster peering config
  cts/                        # Consul-Terraform-Sync automation

boundary/                     # Optional Boundary setup
packer/                       # Packer templates for GCP
nomad-apps/                   # Nomad job specs
scripts/                      # Utility scripts
```

---

## Related Links

* [Consul Admin Partitions](https://developer.hashicorp.com/consul/docs/enterprise/admin-partitions)
* [Consul Cluster Peering](https://developer.hashicorp.com/consul/docs/connect/cluster-peering)
* [Consul-Terraform-Sync](https://developer.hashicorp.com/consul/docs/integrations/consul-terraform-sync)
* [Google Cloud Boutique App](https://github.com/GoogleCloudPlatform/microservices-demo)

```

Let me know if you want this saved to a file or committed to a specific repo.
```
