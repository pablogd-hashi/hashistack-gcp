# Variables for GKE Southwest CTS Integration Module

variable "cluster_name" {
  description = "Name of the GKE cluster (should match your existing cluster)"
  type        = string
  default     = "gke-southwest"
}

variable "gcp_region" {
  description = "GCP region where the cluster is located"
  type        = string
  default     = "europe-southwest1"
}

variable "dns_zone_name" {
  description = "Name of the Cloud DNS managed zone for service discovery"
  type        = string
  default     = "your-dns-zone"  # Update with your actual DNS zone
}

variable "domain_name" {
  description = "Domain name for service discovery records"
  type        = string
  default     = "example.com"  # Update with your actual domain
}

variable "enable_dns_records" {
  description = "Whether to create DNS records for services"
  type        = bool
  default     = false  # Set to true if you have a DNS zone configured
}

variable "consul_partition" {
  description = "Consul partition where services are registered"
  type        = string
  default     = "k8s-southwest1"
}

variable "consul_namespace" {
  description = "Consul namespace where services are registered"
  type        = string
  default     = "production"
}