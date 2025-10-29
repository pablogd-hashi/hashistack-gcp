# Task Automation Reference

**Navigation:** [Home](../Home.md) > [Deployment Workflows](Deployment-Workflows.md) > Task Automation Reference

> **Quick Links:** [Infrastructure](#infrastructure-tasks) | [Consul](#consul-tasks) | [Boundary](#boundary-tasks)

---

## Overview

Complete reference for all Task automation commands.

---

## Infrastructure Tasks

### Image Building
```bash
task build-images        # Build Packer images
```

### Deployment
```bash
task deploy-dc1          # Deploy DC1
task deploy-dc2          # Deploy DC2
task deploy-both-dc      # Deploy both DCs
task deploy-both-gke     # Deploy both GKE clusters
```

### Information
```bash
task eval-dc1            # Get DC1 environment variables
task eval-dc2            # Get DC2 environment variables
task eval-both           # Get both DCs
task show-dc1-info       # Show DC1 cluster info
```

### Cleanup
```bash
task destroy-dc1         # Destroy DC1
task destroy-dc2         # Destroy DC2
```

---

## Consul Tasks

### Admin Partitions
```bash
task -t consul/admin-partitions/Taskfile.yml consul:deploy-all
task -t consul/admin-partitions/Taskfile.yml consul:deploy-policies
task -t consul/admin-partitions/Taskfile.yml consul:deploy-tokens
task -t consul/admin-partitions/Taskfile.yml consul:get-certificates
task -t consul/admin-partitions/Taskfile.yml consul:deploy-gke
```

### Cluster Peering
```bash
task -t consul/peering/Taskfile.yml consul:deploy-all
task -t consul/peering/Taskfile.yml consul:deploy-mesh-gateways
task -t consul/peering/Taskfile.yml consul:create-peering
```

---

## Boundary Tasks

```bash
task -t tasks/boundary-auto.yml boundary:setup-full
task -t tasks/boundary-auto.yml boundary:connect-dc1-server
task -t tasks/boundary-auto.yml boundary:list-all-targets
```

---

## GKE Tasks

```bash
task gke-auth-west       # Authenticate to GKE West
task gke-auth-southwest  # Authenticate to GKE Southwest
```

---

**Previous:** [Deployment Workflows](Deployment-Workflows.md) | **Next:** [Demo Applications](Demo-Applications.md) | **[Back to Top](#task-automation-reference)**
