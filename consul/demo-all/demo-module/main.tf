# CTS Integration with Existing GCP Infrastructure
# This module updates your actual GCP infrastructure based on Consul service changes

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
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

# Get existing GCP project info (from your existing infrastructure)
data "google_project" "current" {}

# Update GCP Load Balancer Backend Service with current Consul services
# This could update your existing client load balancer with boutique service targets
resource "google_compute_backend_service" "boutique_services" {
  name        = "cts-boutique-backend"
  description = "Backend service managed by CTS for boutique services"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  
  # Health check for the boutique frontend
  health_checks = [google_compute_health_check.boutique_health.id]
  
  # Backend based on current Consul services
  dynamic "backend" {
    for_each = { for name, svc in var.services : name => svc if svc.name == "frontend" }
    content {
      description = "Backend for ${backend.value.name} service"
      group       = data.google_compute_instance_group.gke_nodes.self_link
    }
  }

  lifecycle {
    ignore_changes = [backend]
  }
}

# Health check for boutique services
resource "google_compute_health_check" "boutique_health" {
  name = "cts-boutique-health-check"
  
  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# Data source for your existing GKE instance group
data "google_compute_instance_group" "gke_nodes" {
  name = "gke-gke-southwest-gke-default-pool"  # Your GKE node pool
  zone = "europe-southwest1-a"                # Your GKE zone
}

# Cloud DNS record for service discovery
resource "google_dns_record_set" "boutique_services" {
  for_each = { for name, svc in var.services : name => svc if svc.name == "frontend" }
  
  name = "${each.value.name}.k8s-southwest1.${data.google_dns_managed_zone.main.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.main.name
  rrdatas      = [each.value.address]
}

# Data source for your existing DNS zone (if you have one)
data "google_dns_managed_zone" "main" {
  name = "your-dns-zone-name"  # Update with your actual DNS zone name
}

# Create Consul KV entries to track infrastructure state
resource "consul_keys" "infrastructure_state" {
  key {
    path  = "cts/infrastructure/gcp/backend_services"
    value = jsonencode({
      timestamp = timestamp()
      services_count = length(var.services)
      backend_service_name = google_compute_backend_service.boutique_services.name
      health_check_name = google_compute_health_check.boutique_health.name
    })
  }
  
  key {
    path  = "cts/infrastructure/gcp/dns_records"
    value = jsonencode({
      for name, svc in var.services : name => {
        dns_name = "${svc.name}.k8s-southwest1"
        address = svc.address
        port = svc.port
      }
    })
  }
}

# Output infrastructure updates for monitoring
output "gcp_infrastructure_updates" {
  value = {
    timestamp = timestamp()
    project = data.google_project.current.project_id
    updates = {
      backend_service = google_compute_backend_service.boutique_services.name
      health_check = google_compute_health_check.boutique_health.name
      services_tracked = length(var.services)
      dns_records_created = length([for s in var.services : s if s.name == "frontend"])
    }
    consul_integration = {
      partition = "k8s-southwest1"
      namespace = "production"
      services_monitored = [for name, svc in var.services : svc.name]
    }
  }
}

output "service_endpoints" {
  value = {
    for name, service in var.services : name => {
      internal_endpoint = "${service.address}:${service.port}"
      external_dns = service.name == "frontend" ? "${service.name}.k8s-southwest1.${data.google_dns_managed_zone.main.dns_name}" : null
      load_balancer = service.name == "frontend" ? google_compute_backend_service.boutique_services.self_link : null
    }
  }
}