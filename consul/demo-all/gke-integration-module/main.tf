# CTS Integration with Existing GKE Southwest Infrastructure
# This module integrates CTS with your existing GKE-southwest workspace
# to update infrastructure based on Consul service changes

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.0"
    }
  }
}

# Variable that CTS provides - services discovered from Consul
variable "services" {
  description = "Services monitored by CTS from Consul k8s-southwest1 partition"
  type        = map(object({
    id      = string
    name    = string
    address = string
    port    = number
    tags    = list(string)
  }))
}

# Get current project info
data "google_client_config" "current" {}

# Reference your existing GKE cluster from the GKE-southwest workspace
data "google_container_cluster" "existing_cluster" {
  name     = "gke-southwest-gke"  # Based on your ${var.cluster_name}-gke pattern
  location = "europe-southwest1"  # Your GKE region
}

# Reference your existing network from the GKE-southwest workspace
data "google_compute_network" "existing_network" {
  name = "gke-southwest-gke-network"  # Based on your ${var.cluster_name}-gke-network pattern
}

# Create additional firewall rules for discovered services
resource "google_compute_firewall" "consul_services_ingress" {
  for_each = { for name, svc in var.services : name => svc if svc.name == "frontend" }
  
  name    = "cts-boutique-${replace(each.key, ".", "-")}-ingress"
  network = data.google_compute_network.existing_network.name

  allow {
    protocol = "tcp"
    ports    = [tostring(each.value.port)]
  }

  source_ranges = ["0.0.0.0/0"]  # Adjust based on your security requirements
  target_tags   = ["gke-node"]

  description = "CTS managed firewall rule for ${each.value.name} service"
}

# Create Cloud DNS record sets for service discovery
resource "google_dns_record_set" "service_discovery" {
  for_each = { for name, svc in var.services : name => svc if svc.name == "frontend" }
  
  name = "${each.value.name}.k8s-southwest1.example.com."  # Update with your actual domain
  type = "A"
  ttl  = 300

  managed_zone = "your-dns-zone"  # Update with your actual DNS zone name
  rrdatas      = [each.value.address]

  # This will only work if you have a DNS zone configured
  # Comment out if you don't have one
  lifecycle {
    ignore_changes = [managed_zone]
  }
}

# Create Consul KV entries to track CTS infrastructure changes
resource "consul_keys" "cts_infrastructure_state" {
  key {
    path  = "cts/gke-southwest/infrastructure/firewall_rules"
    value = jsonencode({
      timestamp = timestamp()
      rules_created = length([for s in var.services : s if s.name == "frontend"])
      service_ports = [for name, svc in var.services : "${svc.name}:${svc.port}"]
      cluster_name = data.google_container_cluster.existing_cluster.name
      network_name = data.google_compute_network.existing_network.name
    })
  }
  
  key {
    path  = "cts/gke-southwest/services/current_state"
    value = jsonencode({
      timestamp = timestamp()
      total_services = length(var.services)
      services = {
        for name, svc in var.services : name => {
          name = svc.name
          address = svc.address
          port = svc.port
          tags = svc.tags
        }
      }
      partition = "k8s-southwest1"
      namespace = "production"
    })
  }
}

# Create monitoring configuration for the boutique services
resource "local_file" "gke_service_monitoring" {
  filename = "/tmp/gke-southwest-services.json"
  content = jsonencode({
    timestamp = timestamp()
    cluster = data.google_container_cluster.existing_cluster.name
    location = data.google_container_cluster.existing_cluster.location
    network = data.google_compute_network.existing_network.name
    services = {
      for name, service in var.services : name => {
        name = service.name
        endpoint = "${service.address}:${service.port}"
        firewall_rule = service.name == "frontend" ? google_compute_firewall.consul_services_ingress[name].name : null
        dns_record = service.name == "frontend" ? "${service.name}.k8s-southwest1.example.com" : null
        monitoring_target = "${service.address}:${service.port}"
        health_check_url = "http://${service.address}:${service.port}/health"
      }
    }
    infrastructure_updates = {
      firewall_rules_created = length([for s in var.services : s if s.name == "frontend"])
      dns_records_created = length([for s in var.services : s if s.name == "frontend"])
      consul_kv_updated = true
    }
  })
}

# Output infrastructure integration details
output "gke_integration_summary" {
  value = {
    timestamp = timestamp()
    cluster_integration = {
      cluster_name = data.google_container_cluster.existing_cluster.name
      cluster_location = data.google_container_cluster.existing_cluster.location
      network_name = data.google_compute_network.existing_network.name
      services_integrated = length(var.services)
    }
    infrastructure_updates = {
      firewall_rules = [
        for name, svc in var.services : 
        google_compute_firewall.consul_services_ingress[name].name 
        if svc.name == "frontend"
      ]
      monitoring_config = local_file.gke_service_monitoring.filename
      consul_kv_entries = [
        "cts/gke-southwest/infrastructure/firewall_rules",
        "cts/gke-southwest/services/current_state"
      ]
    }
    service_discovery = {
      partition = "k8s-southwest1"
      namespace = "production"
      services_monitored = [for name, svc in var.services : svc.name]
      frontend_services = [for name, svc in var.services : svc.name if svc.name == "frontend"]
    }
  }
}

# Output service endpoints for external consumption
output "service_endpoints" {
  value = {
    for name, service in var.services : name => {
      internal_endpoint = "${service.address}:${service.port}"
      external_firewall = service.name == "frontend" ? google_compute_firewall.consul_services_ingress[name].name : null
      dns_name = service.name == "frontend" ? "${service.name}.k8s-southwest1.example.com" : null
      gke_cluster = data.google_container_cluster.existing_cluster.name
      network = data.google_compute_network.existing_network.name
    }
  }
}