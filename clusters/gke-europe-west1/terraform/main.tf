terraform {
  cloud {
    organization = "pablogd-hcp-test"

    workspaces {
      name = "GKE-europe-west1"
    }
  }
  
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Collect client config for GCP
data "google_client_config" "current" {}

data "google_service_account" "owner_project" {
  account_id = var.gcp_sa
  project    = var.gcp_project
}

# VPC creation
resource "google_compute_network" "gke_network" {
  name                    = "${var.cluster_name}-gke-network"
  auto_create_subnetworks = false
}

# Subnet creation
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "${var.cluster_name}-gke-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.gke_network.id

  secondary_ip_range {
    range_name    = "gke-pod-range"
    ip_cidr_range = "10.11.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-service-range"
    ip_cidr_range = "10.12.0.0/16"
  }
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.cluster_name}-gke"
  location = var.gcp_region

  # Allow deletion for demo/PoC environments
  deletion_protection = false

  # Use regional cluster for high availability
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.gke_network.name
  subnetwork = google_compute_subnetwork.gke_subnet.name

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pod-range"
    services_secondary_range_name = "gke-service-range"
  }

  # Network policy
  network_policy {
    enabled = true
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.gcp_project}.svc.id.goog"
  }

  # Public cluster configuration
  private_cluster_config {
    enable_private_nodes    = false  # Nodes get public IPs
    enable_private_endpoint = false  # Control plane endpoint is public
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  # Addons
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Maintenance policy
  maintenance_policy {
    recurring_window {
      start_time = "2023-01-01T09:00:00Z"
      end_time   = "2023-01-01T17:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }
}

# Node pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.gcp_region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    preemptible  = var.preemptible_nodes
    machine_type = var.gcp_instance

    # Google recommends custom service accounts with minimal permissions
    service_account = data.google_service_account.owner_project.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Enable Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Disk configuration
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"

    # Labels and tags
    labels = {
      cluster = var.cluster_name
      owner   = var.owner
    }

    tags = ["gke-node", "${var.cluster_name}-node"]
  }

  # Auto-scaling
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Firewall rule for NodePort services
resource "google_compute_firewall" "gke_nodeport" {
  name    = "${var.cluster_name}-gke-nodeport"
  network = google_compute_network.gke_network.name

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-node"]
}

# Firewall rule for health checks
resource "google_compute_firewall" "gke_health_check" {
  name    = "${var.cluster_name}-gke-health-check"
  network = google_compute_network.gke_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "9090", "3000"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["gke-node"]
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  region  = var.gcp_region
  network = google_compute_network.gke_network.id
}

# Cloud NAT for outbound internet access from private nodes
resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}