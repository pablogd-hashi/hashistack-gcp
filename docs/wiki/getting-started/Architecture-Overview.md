# Architecture Overview

**Navigation:** [Home](../Home.md) > [Getting Started](Prerequisites-and-Setup.md) > Architecture Overview

> **Quick Links:** [Components](#key-components) | [Network Architecture](#network-architecture) | [Deployment Patterns](#deployment-patterns)

---

## Overview

This page explains the architecture of the HashiStack deployment on Google Cloud Platform. The repository is focused on **Consul Enterprise** and **Nomad Enterprise** as the primary products, with Vault, Boundary, Packer, and Terraform supporting the deployment workflow and infrastructure automation.

## High-Level Architecture

![Architecture Diagram](../../images/architecture-diagram.png)

The architecture consists of:

1. **VM-based Consul/Nomad Servers** - Core control plane running on GCP VMs
2. **Kubernetes Integration** - GKE clusters for admin partitions (multi-tenancy)
3. **Service Mesh** - Consul Connect for secure service-to-service communication
4. **Secure Access** - HashiCorp Boundary for zero-trust SSH access
5. **Infrastructure Automation** - Consul-Terraform-Sync for dynamic infrastructure updates
6. **Monitoring** - Prometheus and Grafana for observability

---

## Key Components

### Consul Enterprise (Primary Focus)

**Purpose:** Service discovery, service mesh, and multi-tenancy

**Deployment modes:**
- **VM Servers:** 3-node cluster on GCP Compute Engine (DC1 and optionally DC2)
- **Admin Partitions:** Separate administrative boundaries for GKE clusters
- **Service Mesh:** Consul Connect with Envoy sidecars

**Key features enabled:**
- ACLs for security
- TLS encryption for all communication
- Admin partitions for multi-tenancy
- Cluster peering for multi-datacenter
- Service mesh with intentions

### Nomad Enterprise (Primary Focus)

**Purpose:** Workload orchestration and scheduling

**Deployment:**
- **Server nodes:** Co-located with Consul servers (3 nodes)
- **Client nodes:** Dedicated worker nodes (2-4 nodes per datacenter)
- **Integration:** Native Consul integration for service registration

**Workload types:**
- Docker containers
- Raw exec tasks
- System jobs (monitoring, ingress)

### Supporting Products

**Packer:**
- Builds custom VM images with HashiStack pre-installed
- Reduces deployment time
- Ensures consistent base configuration

**Terraform:**
- Infrastructure as Code for GCP resources
- Managed via HCP Terraform for state and variables
- Modular design for repeatable deployments

**Vault:**
- Pre-installed on images (Community edition)
- Available for secrets management
- Not configured by default

**Boundary:**
- Secure SSH access to infrastructure
- No VPN required
- Session recording and audit logging
- Optional but recommended

**Consul-Terraform-Sync (CTS):**
- Automates infrastructure changes based on Consul service catalog
- Event-driven Terraform execution
- Optional advanced feature

---

## Network Architecture

### VM Clusters (DC1/DC2)

**Network Layout:**
```
DC1 (europe-north1)
├── VPC: 10.0.0.0/16
├── Subnet: 10.0.1.0/24 (servers)
├── Subnet: 10.0.2.0/24 (clients)
└── External IPs for UI/API access

DC2 (europe-west1) - Optional
├── VPC: 10.1.0.0/16
├── Subnet: 10.1.1.0/24 (servers)
├── Subnet: 10.1.2.0/24 (clients)
└── External IPs for UI/API access
```

**Firewall Rules:**
- Consul ports: 8300-8302, 8500-8502, 8600
- Nomad ports: 4646-4648
- Service mesh: 20000, 21000-21255
- SSH: 22 (via Boundary preferred)
- Mesh gateway: 8443 (for peering)

### GKE Clusters (Admin Partitions)

**Network Layout:**
```
GKE West1 (europe-west1)
├── Cluster VPC: 10.10.0.0/24
├── Pod network: 10.11.0.0/16
├── Service network: 10.12.0.0/16
└── Consul partition: k8s-west1

GKE Southwest (europe-southwest1)
├── Cluster VPC: 10.20.0.0/24
├── Pod network: 10.21.0.0/16
├── Service network: 10.22.0.0/16
└── Consul partition: k8s-southwest1
```

**Connectivity:**
- GKE clusters connect to VM Consul servers via external IPs
- Consul agents run as partition clients in Kubernetes
- Service mesh communication via mesh gateways

---

## Deployment Patterns

### Pattern 1: Single Datacenter

**Use case:** Development, testing, demos

**Components:**
- DC1 VM cluster (3 servers, 2-4 clients)
- Consul + Nomad with ACLs and TLS
- Optional: Monitoring stack

**Deployment time:** ~15 minutes

**Workflow:**
1. Build Packer images
2. Deploy DC1 with Terraform
3. Configure Nomad-Consul integration
4. Deploy applications

### Pattern 2: Multi-Datacenter with Peering

**Use case:** Multi-region applications, high availability

**Components:**
- DC1 and DC2 VM clusters
- Cluster peering between datacenters
- Mesh gateways for cross-DC traffic
- Service exports and intentions

**Deployment time:** ~25 minutes

**Workflow:**
1. Build Packer images
2. Deploy DC1 and DC2
3. Configure peering
4. Set up mesh gateways
5. Export services between clusters

### Pattern 3: Admin Partitions on Kubernetes

**Use case:** Multi-tenant Kubernetes integration

**Prerequisites:**
- DC1 deployed with ACLs enabled
- GKE clusters deployed

**Components:**
- VM Consul servers (DC1)
- Multiple GKE clusters as partition clients
- Separate admin partitions per cluster
- Namespaces within partitions

**Deployment time:** ~35 minutes

**Workflow:**
1. Deploy DC1 VM servers
2. Create admin partitions via Consul CLI
3. Deploy GKE clusters
4. Deploy Consul to GKE as partition clients
5. Configure service mesh across partitions

### Pattern 4: Complete Enterprise Setup

**Use case:** Full-featured demo environment

**Components:**
- Multi-DC VM clusters with peering
- GKE admin partitions
- Boundary secure access
- Monitoring stack
- CTS automation

**Deployment time:** ~60 minutes

**Workflow:**
1. Build Packer images
2. Deploy VM clusters (DC1, DC2)
3. Configure Boundary
4. Set up cluster peering
5. Deploy monitoring
6. Deploy GKE clusters
7. Configure admin partitions
8. Deploy demo applications

---

## Data Flow

### Service Registration

```
Nomad Job → Consul Agent → Consul Servers
                ↓
         Service Catalog
                ↓
    DNS / API / Service Mesh
```

### Service Mesh Communication

```
App A (with Envoy sidecar)
    ↓ (localhost:20000)
Envoy Proxy
    ↓ (mTLS via Consul)
Consul Service Mesh
    ↓ (mTLS)
Envoy Proxy
    ↓ (localhost:port)
App B (with Envoy sidecar)
```

### Cross-Partition Communication

```
App in k8s-west1 partition
    ↓
Envoy sidecar
    ↓
Mesh Gateway (k8s-west1)
    ↓ (8443, mTLS)
Mesh Gateway (k8s-southwest1)
    ↓
Envoy sidecar
    ↓
App in k8s-southwest1 partition
```

---

## Security Architecture

### ACL System

**Bootstrap tokens:**
- Consul bootstrap token (generated during deployment)
- Nomad bootstrap token (generated during deployment)

**Token hierarchy:**
- Global management token
- Datacenter-specific tokens
- Partition-specific tokens
- Application tokens

### TLS Encryption

**CA structure:**
- Self-signed CA generated during deployment
- Server certificates for Consul/Nomad
- Client certificates for agents
- Service mesh certificates (auto-generated by Consul)

**Encrypted communication:**
- Consul gossip (Serf)
- Consul RPC
- Nomad RPC
- Service mesh (mTLS)

### Network Security

**Firewall rules:**
- Minimal port exposure
- Source IP restrictions where possible
- Internal-only communication for sensitive ports

**Boundary access:**
- Zero-trust SSH access
- No permanent SSH keys on VMs
- Session recording
- Just-in-time credentials

---

## Scalability Considerations

### Vertical Scaling

**Server nodes:**
- Start: e2-medium (2 vCPU, 4GB RAM)
- Production: e2-standard-4 (4 vCPU, 16GB RAM)

**Client nodes:**
- Start: e2-standard-2 (2 vCPU, 8GB RAM)
- Production: e2-standard-8 (8 vCPU, 32GB RAM)

### Horizontal Scaling

**Consul:**
- 3-5 servers per datacenter (odd numbers)
- Unlimited clients
- Admin partitions for isolation

**Nomad:**
- 3-5 servers (matches Consul)
- Scale clients based on workload
- Multiple datacenters for geo-distribution

### High Availability

**Server redundancy:**
- 3 servers tolerate 1 failure
- 5 servers tolerate 2 failures

**Multi-datacenter:**
- Independent failure domains
- Cluster peering for cross-DC services
- Mesh gateways for resilient traffic routing

---

## Monitoring and Observability

**Metrics collection:**
- Consul metrics exposed on port 9107
- Nomad metrics exposed on port 4646
- Envoy metrics for service mesh

**Monitoring stack:**
- Prometheus for metrics collection
- Grafana for visualization
- Pre-configured dashboards for Consul/Nomad

**Logging:**
- Systemd journal for service logs
- Application logs via Docker logging drivers
- Audit logs for Consul (Enterprise)

---

## Related Pages

- [Prerequisites and Setup](Prerequisites-and-Setup.md) - Get started with deployment
- [Quick Start Guide](Quick-Start-Guide.md) - Deploy your first cluster
- [VM Cluster Deployment](../infrastructure/VM-Cluster-Deployment.md) - Detailed VM deployment
- [Admin Partitions](../advanced-features/Admin-Partitions.md) - Multi-tenant Kubernetes

---

**Previous:** [Quick Start Guide](Quick-Start-Guide.md) | **Next:** [Image Building with Packer](../infrastructure/Image-Building-with-Packer.md) | **[Back to Top](#architecture-overview)**
