# CTS Module: Automatic GCP Firewall Rules for Discovered Services
# This addresses the customer requirement: deploy app on port 8085 → auto-open firewall

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Variables are defined in variables.tf - this keeps main.tf clean

# Reference existing GKE network (dynamically from your HCP Terraform workspace)
data "google_compute_network" "existing_network" {
  name    = "${var.cluster_name}-gke-network"
  project = var.gcp_project
}

# Automatically create firewall rules for discovered services
# Example: New service on port 8085 → firewall rule created automatically
resource "google_compute_firewall" "service_ingress" {
  for_each = var.services
  
  name    = "cts-auto-${each.value.name}-${each.value.port}"
  network = data.google_compute_network.existing_network.name

  allow {
    protocol = "tcp"
    ports    = [tostring(each.value.port)]
  }

  source_ranges = ["0.0.0.0/0"]  # Adjust for your security requirements
  target_tags   = ["gke-node"]
  
  description = "CTS auto-created: ${each.value.name} service on port ${each.value.port}"
}

# Outputs are defined in outputs.tf