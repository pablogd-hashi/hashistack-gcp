# Deployment Workflows

**Navigation:** [Home](../Home.md) > [Deployment Workflows](Deployment-Workflows.md) > Deployment Workflows

> **Quick Links:** [Single DC](#single-datacenter) | [Multi-DC](#multi-datacenter-with-peering) | [Complete Enterprise](#complete-enterprise-setup)

---

## Overview

Common deployment workflows for different use cases.

---

## Single Datacenter

**Use case:** Development, testing, demos

**Time:** ~20 minutes

### Step-by-Step

```bash
# 1. Build images
task build-images

# 2. Deploy DC1
task deploy-dc1

# 3. Configure environment
task eval-dc1
# Copy exports to terminal

# 4. Complete setup
nomad setup consul -y
```

**What you get:**
- 3 Consul/Nomad servers
- 2-4 Nomad clients
- ACLs and TLS enabled
- Ready for application deployment

---

## Multi-Datacenter with Peering

**Use case:** Multi-region, high availability

**Prerequisites:** Single DC completed

**Time:** +15 minutes

### Step-by-Step

```bash
# 1. Deploy DC2
task deploy-dc2

# 2. Get DC2 environment
task eval-dc2

# 3. Set up peering
task -t consul/peering/Taskfile.yml consul:deploy-all

# 4. Verify
consul peering list
```

---

## Admin Partitions on Kubernetes

**Use case:** Multi-tenant Kubernetes integration

**Prerequisites:** DC1 deployed with ACLs

**Time:** +25 minutes

### Step-by-Step

```bash
# 1. Deploy GKE clusters
task deploy-both-gke

# 2. Create admin partitions
task -t consul/admin-partitions/Taskfile.yml consul:deploy-partitions
task -t consul/admin-partitions/Taskfile.yml consul:deploy-tokens

# 3. Get certificates
task -t consul/admin-partitions/Taskfile.yml consul:get-certificates

# 4. Deploy Consul to GKE
task -t consul/admin-partitions/Taskfile.yml consul:deploy-gke
```

---

## Complete Enterprise Setup

**Use case:** Full-featured demo

**Prerequisites:** None

**Time:** ~60 minutes

### Step-by-Step

```bash
# 1. Build images
task build-images

# 2. Deploy infrastructure
task deploy-both-dc
task deploy-both-gke

# 3. Configure Boundary
task -t tasks/boundary-auto.yml boundary:setup-full

# 4. Set up peering
task -t consul/peering/Taskfile.yml consul:deploy-all

# 5. Deploy monitoring
task deploy-monitoring-dc1

# 6. Set up admin partitions
task -t consul/admin-partitions/Taskfile.yml consul:deploy-all

# 7. Deploy demo apps
task -t consul/admin-partitions/Taskfile.yml deploy-boutique-full
```

---

**Previous:** [Service Intentions](../advanced-features/Service-Intentions.md) | **Next:** [Task Automation Reference](Task-Automation-Reference.md) | **[Back to Top](#deployment-workflows)**
