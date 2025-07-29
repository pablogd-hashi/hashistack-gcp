# Consul Terraform Sync (CTS)

## Overview

Consul Terraform Sync (CTS) enables infrastructure automation by monitoring Consul's service catalog and automatically executing Terraform modules when services register, deregister, or change state. This integration provides automated infrastructure provisioning and updates based on service discovery events.

### What CTS Provides

**Infrastructure Automation:**
- Automated Terraform execution based on service events
- Dynamic infrastructure provisioning and deprovisioning
- Integration with external systems (DNS, load balancers, firewalls)
- Event-driven infrastructure updates

**Service-Driven Automation:**
- Monitor service registration and health status
- Trigger infrastructure changes when services change
- Automated scaling and configuration management
- Integration with service mesh and networking

**Enterprise Integration:**
- Works with Consul Enterprise admin partitions
- Supports ACL-secured environments
- Integration with Nomad workload scheduling
- Production-ready automation workflows

## Use Cases

**DNS Automation:**
- Automatically update DNS records when services register
- Remove DNS entries when services become unhealthy
- Dynamic load balancer configuration

**Network Security:**
- Create firewall rules for new services
- Update security groups based on service topology
- Automated certificate provisioning and renewal

**Infrastructure Scaling:**
- Provision additional resources when services scale up
- Decommission resources when services scale down
- Dynamic capacity management

## Architecture

CTS monitors Consul's service catalog and executes Terraform modules based on configured tasks:

```
Consul Service Catalog
         │
         ▼
  CTS Task Monitor
         │
         ▼ (Service Change Detected)
  Terraform Module Execution
         │
         ▼
  Infrastructure Update
  (DNS, Firewall, Load Balancer, etc.)
```

## Prerequisites

- Consul Enterprise or OSS with service discovery enabled
- Terraform >= 1.0.0 installed on CTS host
- Appropriate provider credentials (GCP, AWS, DNS, etc.)
- Consul ACL token with required permissions for service monitoring
- Network connectivity to Consul servers
- Write access to Terraform working directory

## Configuration Examples

### Basic CTS Configuration

Create a CTS configuration file (`consul-terraform-sync.hcl`):

```hcl
# Consul connection
consul {
  address = "localhost:8500"
  token   = "your-consul-token"
}

# Terraform configuration
terraform {
  log         = true
  working_dir = "/opt/consul-terraform-sync/terraform"
}

# Driver configuration
driver "terraform" {
  version = "1.0.0"
  log     = true
}

# Task to update DNS records
task {
  name        = "dns-updates"
  description = "Update DNS records based on service registration"
  module      = "./dns-module"
  providers   = ["dns"]
  
  # Monitor specific services
  services = ["web", "api", "database"]
  
  # Trigger conditions
  condition "services" {
    names = ["web", "api"]
  }
}

# Task to update firewall rules
task {
  name        = "firewall-updates"
  description = "Update firewall rules for new services"
  module      = "./firewall-module"
  providers   = ["google"]
  
  # Monitor all services in a specific datacenter
  condition "services" {
    datacenter = "dc1"
    filter     = "Service.Tags contains \"public\""
  }
}
```

### Advanced Task Configuration

```hcl
# Production boutique automation task
task {
  name        = "production-boutique-automation"
  description = "Automated infrastructure for boutique application"
  module      = "./sync-tasks/production-boutique-automation"
  providers   = ["google", "consul"]
  
  # Buffer period to avoid rapid changes
  buffer_period {
    enabled = true
    min     = "10s"
    max     = "20s"
  }
  
  # Condition to monitor boutique services
  condition "services" {
    names = [
      "frontend",
      "productcatalogservice", 
      "cartservice",
      "checkoutservice"
    ]
    datacenter = "dc1"
    namespace  = "production"
    filter     = "Service.Meta.version != \"\""
  }
  
  # Variable inputs for Terraform module
  variable_files = ["terraform.tfvars"]
}
```

## Terraform Modules

### DNS Module Example

Create a Terraform module (`dns-module/main.tf`) that CTS will execute:

```hcl
# Input from CTS
variable "services" {
  description = "Services monitored by CTS"
  type = map(object({
    id              = string
    name            = string
    address         = string
    port            = number
    status          = string
    tags            = list(string)
    datacenter      = string
    namespace       = string
  }))
}

# Create DNS records for healthy services
resource "google_dns_record_set" "service_records" {
  for_each = {
    for id, service in var.services : id => service
    if service.status == "passing"
  }
  
  managed_zone = "your-dns-zone"
  name         = "${each.value.name}.your-domain.com."
  type         = "A"
  ttl          = 300
  rrdatas      = [each.value.address]
}
```

### Firewall Module Example

Create a firewall module (`firewall-module/main.tf`):

```hcl
variable "services" {
  description = "Services monitored by CTS"
  type = map(object({
    id         = string
    name       = string
    address    = string
    port       = number
    tags       = list(string)
    datacenter = string
  }))
}

# Create firewall rules for public services
resource "google_compute_firewall" "service_access" {
  for_each = {
    for id, service in var.services : id => service
    if contains(service.tags, "public")
  }
  
  name    = "allow-${each.value.name}-${each.value.port}"
  network = "default"
  
  allow {
    protocol = "tcp"
    ports    = [tostring(each.value.port)]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${each.value.name}-server"]
}
```

## How to run in tasks

### Running CTS

1. **Install CTS:**
```bash
# Download and install Consul Terraform Sync
wget https://releases.hashicorp.com/consul-terraform-sync/0.7.0/consul-terraform-sync_0.7.0_linux_amd64.zip
unzip consul-terraform-sync_0.7.0_linux_amd64.zip
sudo mv consul-terraform-sync /usr/local/bin/
```

2. **Configure CTS:**
```bash
# Create configuration directory
mkdir -p /etc/consul-terraform-sync
cp consul-terraform-sync.hcl /etc/consul-terraform-sync/

# Create working directory
mkdir -p /opt/consul-terraform-sync/terraform
```

3. **Run CTS:**
```bash
# Run CTS with configuration
consul-terraform-sync start -config-file=/etc/consul-terraform-sync/consul-terraform-sync.hcl
```

### Running as Nomad Job

Deploy CTS as a Nomad job for production use:

```hcl
job "consul-terraform-sync" {
  datacenters = ["dc1"]
  type        = "service"
  
  group "cts" {
    count = 1
    
    task "cts" {
      driver = "docker"
      
      config {
        image = "hashicorp/consul-terraform-sync:0.7.0"
        args  = ["start", "-config-file=/etc/cts/consul-terraform-sync.hcl"]
        
        volumes = [
          "/opt/cts/config:/etc/cts",
          "/opt/cts/terraform:/opt/consul-terraform-sync/terraform"
        ]
      }
      
      resources {
        cpu    = 500
        memory = 512
      }
      
      service {
        name = "consul-terraform-sync"
        port = "api"
        
        check {
          type     = "http"
          path     = "/status"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }
  }
}
```

## Integration with Admin Partitions

CTS can monitor services across Consul Enterprise admin partitions:

```hcl
# Task monitoring services in specific partition
task {
  name        = "partition-dns-updates"
  description = "DNS updates for k8s-southwest1 partition"
  module      = "./dns-module"
  
  condition "services" {
    datacenter = "dc1"
    namespace  = "production"
    partition  = "k8s-southwest1"
    names      = ["frontend", "backend"]
  }
}
```

## Monitoring and Observability

### CTS Status API

CTS provides a status API for monitoring:

```bash
# Check overall status
curl http://localhost:8558/status

# Check specific task status
curl http://localhost:8558/status/tasks/dns-updates

# Check Terraform state
curl http://localhost:8558/status/tasks/dns-updates/terraform
```

### Logging and Debugging

Configure logging for troubleshooting:

```hcl
# Enhanced logging configuration
terraform {
  log         = true
  working_dir = "/opt/consul-terraform-sync/terraform"
}

driver "terraform" {
  log = true
  
  # Terraform log level
  env = {
    TF_LOG = "DEBUG"
  }
}
```

## Production Considerations

**High Availability:**
- Run multiple CTS instances with leader election
- Use shared storage for Terraform state
- Implement proper backup and recovery procedures

**Security:**
- Use Consul ACL tokens with minimal required permissions
- Secure Terraform provider credentials
- Enable audit logging for compliance

**Performance:**
- Configure appropriate buffer periods to avoid rapid changes
- Monitor resource usage and scale accordingly
- Use efficient Consul queries with filters

**Testing:**
- Test Terraform modules independently before CTS integration  
- Use staging environments for CTS configuration validation
- Implement rollback procedures for failed automation

## Examples in This Repository

The repository includes several CTS examples:

**DNS Automation:**
- Location: `consul/demo-all/simple-module/`
- Updates DNS records based on service registration
- Demonstrates basic CTS functionality

**Production Boutique Automation:**
- Location: `consul/demo-all/sync-tasks/production-boutique-automation/`
- Complex multi-service automation
- Integration with GKE and service mesh

**Firewall Management:**
- Automated firewall rule creation
- Service-aware security policies
- Integration with GCP security groups

## Troubleshooting

**Common Issues:**

1. **Task Not Triggering**: Check service conditions and filters
2. **Terraform Failures**: Verify module syntax and provider credentials
3. **Permission Errors**: Ensure proper Consul ACL permissions
4. **State Conflicts**: Check for concurrent Terraform executions

**Useful Commands:**

```bash
# Check CTS logs
journalctl -u consul-terraform-sync -f

# Validate configuration
consul-terraform-sync start -config-file=config.hcl -dry-run

# Manual task execution
consul-terraform-sync task run -task-name=dns-updates
```

This CTS integration provides powerful infrastructure automation capabilities that scale with your service architecture while maintaining security and compliance requirements.