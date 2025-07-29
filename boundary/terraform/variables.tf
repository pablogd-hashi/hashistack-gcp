# HCP Boundary Configuration
variable "hcp_boundary_cluster_id" {
  description = "HCP Boundary cluster ID"
  type        = string
}

variable "boundary_addr" {
  description = "Boundary cluster address"
  type        = string
}

variable "boundary_auth_method_id" {
  description = "Boundary auth method ID for initial authentication"
  type        = string
}

variable "boundary_admin_login_name" {
  description = "Boundary admin login name"
  type        = string
  default     = "admin"
}

variable "boundary_admin_password" {
  description = "Boundary admin password (use environment variable TF_VAR_boundary_admin_password)"
  type        = string
  sensitive   = true
  default     = null
}

# HCP Configuration (reuses existing variables from HCP Terraform)
variable "hcp_client_id" {
  description = "HCP client ID (from existing HCP Terraform variable set)"
  type        = string
}

variable "hcp_client_secret" {
  description = "HCP client secret (from existing HCP Terraform variable set)"
  type        = string
  sensitive   = true
}

# GCP Configuration (reuses existing variables from HCP Terraform)
variable "gcp_project" {
  description = "GCP project ID (from existing HCP Terraform variable set)"
  type        = string
}

variable "gcp_region" {
  description = "GCP region (from existing HCP Terraform variable set)"
  type        = string
  default     = "us-central1"
}

# SSH Configuration (reuses existing SSH key from HCP Terraform)
variable "ssh_private_key" {
  description = "SSH private key for accessing instances (from existing HCP Terraform variable set)"
  type        = string
  sensitive   = true
}

# Deployment flags to indicate which clusters are deployed
variable "dc1_deployed" {
  description = "Whether DC1 cluster is deployed"
  type        = bool
  default     = true
}

variable "dc2_deployed" {
  description = "Whether DC2 cluster is deployed"
  type        = bool
  default     = true
}

# Remote State Configuration
variable "remote_state_backend" {
  description = "Backend type for remote state (e.g., 'remote' for HCP Terraform, 'gcs' for Google Cloud Storage)"
  type        = string
  default     = "remote"
}

variable "dc1_remote_state_config" {
  description = "Configuration for DC1 remote state backend"
  type = object({
    organization = string
    workspaces = object({
      name = string
    })
  })
  default = {
    organization = "your-hcp-terraform-org"
    workspaces = {
      name = "dc1-hashistack-cluster"
    }
  }
}

variable "dc2_remote_state_config" {
  description = "Configuration for DC2 remote state backend"
  type = object({
    organization = string
    workspaces = object({
      name = string
    })
  })
  default = {
    organization = "your-hcp-terraform-org"
    workspaces = {
      name = "dc2-hashistack-cluster"
    }
  }
}

# IP address overrides (optional)
variable "dc1_server_ips" {
  description = "DC1 server IP addresses (overrides auto-discovery)"
  type        = list(string)
  default     = []
}

variable "dc1_client_ips" {
  description = "DC1 client IP addresses (overrides auto-discovery)"
  type        = list(string)
  default     = []
}

variable "dc2_server_ips" {
  description = "DC2 server IP addresses (overrides auto-discovery)"
  type        = list(string)
  default     = []
}

variable "dc2_client_ips" {
  description = "DC2 client IP addresses (overrides auto-discovery)"
  type        = list(string)
  default     = []
}