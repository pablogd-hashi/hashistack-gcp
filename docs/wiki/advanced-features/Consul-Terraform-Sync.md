# Consul-Terraform-Sync

**Navigation:** [Home](../Home.md) > [Advanced Features](Admin-Partitions.md) > Consul-Terraform-Sync

> **Quick Links:** [Overview](#overview) | [Use Cases](#use-cases) | [Configuration](#configuration)

---

## Overview

Consul-Terraform-Sync (CTS) automates infrastructure changes based on Consul service catalog events.

**Key capabilities:**
- Automated Terraform execution on service changes
- DNS record updates
- Load balancer configuration
- Firewall rule management
- Integration with external systems

---

## Use Cases

### DNS Automation
Automatically update DNS records when services register/deregister

### Network Security
Create firewall rules for new services dynamically

### Infrastructure Scaling
Provision resources when services scale

---

## Configuration

**Basic CTS configuration:**

```hcl
consul {
  address = "localhost:8500"
  token   = "your-consul-token"
}

driver "terraform" {
  version = "1.5.0"
}

task {
  name = "dns-updates"
  description = "Update DNS for services"
  module = "./dns-module"
  providers = ["dns"]
  condition "services" {
    names = ["web", "api"]
  }
}
```

**Documentation:** [Consul-Terraform-Sync Docs](https://developer.hashicorp.com/consul/docs/nia)

---

**Previous:** [Cluster Peering](Cluster-Peering.md) | **Next:** [Service Intentions](Service-Intentions.md) | **[Back to Top](#consul-terraform-sync)**
