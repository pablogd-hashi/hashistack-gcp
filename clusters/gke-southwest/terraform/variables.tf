variable "gcp_region" {
  description = "Google Cloud region"
  default     = "europe-southwest1"
}

variable "gcp_zones" {
  description = "Zones to spread the nodes. This is a list of zones"
  type        = list(string)
  default     = ["europe-southwest1-a", "europe-southwest1-b", "europe-southwest1-c"]
  
  validation {
    condition     = alltrue([for zone in var.gcp_zones : can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]+$", zone))])
    error_message = "The GCP zones must be in format region-zone (e.g., europe-southwest1-a)."
  }
}

variable "gcp_project" {
  description = "Cloud project"
}

variable "gcp_sa" {
  description = "GCP Service Account to use for scopes"
}

variable "gcp_instance" {
  description = "Machine type for nodes"
  default     = "e2-standard-4"
}

variable "cluster_name" {
  description = "Name of the cluster"
  default     = "gke-southwest"
}

variable "owner" {
  description = "Owner of the cluster"
}

variable "node_count" {
  description = "Number of nodes per zone"
  default     = 1
}

variable "min_node_count" {
  description = "Minimum number of nodes per zone"
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes per zone"
  default     = 1
}

variable "disk_size_gb" {
  description = "Disk size in GB for each node"
  default     = 50
}

variable "preemptible_nodes" {
  description = "Use preemptible nodes to reduce cost"
  default     = false
}

variable "dns_zone" {
  description = "An already existing DNS zone in your GCP project"
  default     = ""
}