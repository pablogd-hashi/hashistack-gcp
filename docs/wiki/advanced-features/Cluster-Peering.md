# Cluster Peering

**Navigation:** [Home](../Home.md) > [Advanced Features](Admin-Partitions.md) > Cluster Peering

> **Quick Links:** [Prerequisites](#prerequisites) | [Setup](#setup-peering) | [Service Exports](#export-services)

---

## Overview

Connect multiple Consul datacenters with cluster peering for secure, modern alternative to WAN federation.

**Prerequisites:**
- [VM Cluster Deployment](../infrastructure/VM-Cluster-Deployment.md) - Both DC1 and DC2 deployed
- ACLs enabled on both clusters
- Nomad-Consul integration completed

---

## Setup Peering

### Automated Setup (Recommended)

```bash
# Deploy complete peering configuration
task -t consul/peering/Taskfile.yml consul:deploy-all
```

This automatically:
- Configures mesh gateway ACLs
- Deploys mesh gateways to Nomad
- Establishes peering connection
- Sets up service exports

### Manual Setup

```bash
# 1. Deploy mesh gateways
task -t consul/peering/Taskfile.yml consul:deploy-mesh-gateways

# 2. Create peering connection
task -t consul/peering/Taskfile.yml consul:create-peering

# 3. Export services
task -t consul/peering/Taskfile.yml consul:export-services
```

---

## Export Services

Configure which services are visible across datacenters:

```bash
# Example: Export backend services from DC2 to DC1
consul config write - <<EOF
Kind = "exported-services"
Name = "default"
Services = [
  {
    Name = "backend-api"
    Consumers = [
      {
        Peer = "gcp-dc1-default"
      }
    ]
  }
]
EOF
```

---

## Verification

```bash
# Check peering status
consul peering list

# Check services from peer
consul catalog services -peer gcp-dc2-default

# Test cross-DC service discovery
consul catalog nodes -peer gcp-dc2-default
```

---

## What's Next?

After cluster peering:

- Deploy services across datacenters
- Configure service intentions for cross-DC traffic
- Set up failover policies

---

**Previous:** [Admin Partitions](Admin-Partitions.md) | **Next:** [Consul-Terraform-Sync](Consul-Terraform-Sync.md) | **[Back to Top](#cluster-peering)**
