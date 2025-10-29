# Service Intentions

**Navigation:** [Home](../Home.md) > [Advanced Features](Admin-Partitions.md) > Service Intentions

> **Quick Links:** [Overview](#overview) | [Create Intentions](#create-intentions)

---

## Overview

Service intentions control service-to-service communication in the Consul service mesh, providing zero-trust networking.

**Prerequisites:**
- Service mesh enabled (connectInject)
- Services registered with Consul

---

## Create Intentions

### Allow Communication

```bash
# Allow frontend to call backend
consul intention create -allow frontend backend

# Allow with specific partition/namespace
consul intention create -allow \
  default/default/frontend \
  default/default/backend
```

### Deny Communication

```bash
# Deny unauthorized access
consul intention create -deny untrusted backend
```

### Cross-Partition Intentions

```bash
# Allow k8s-west1 frontend to call k8s-southwest1 backend
consul intention create -allow \
  k8s-west1/default/frontend \
  k8s-southwest1/default/backend
```

---

## Verify Intentions

```bash
# List all intentions
consul intention list

# Check specific intention
consul intention check frontend backend

# Get intention details
consul intention get frontend backend
```

---

**Previous:** [Consul-Terraform-Sync](Consul-Terraform-Sync.md) | **Next:** [Deployment Workflows](../workflows/Deployment-Workflows.md) | **[Back to Top](#service-intentions)**
