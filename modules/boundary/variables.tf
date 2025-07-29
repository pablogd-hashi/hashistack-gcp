# Boundary module variables

variable "enabled" {
  description = "Enable Boundary integration for this cluster"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the cluster (used for resource naming)"
  type        = string
}

variable "parent_scope_id" {
  description = "Parent Boundary scope ID (organization scope)"
  type        = string
}

variable "server_instance_ips" {
  description = "List of server instance IP addresses from Terraform outputs"
  type        = list(string)
  default     = []
}

variable "client_instance_ips" {
  description = "List of client instance IP addresses from Terraform outputs"
  type        = list(string)
  default     = []
}

variable "ssh_username" {
  description = "SSH username for accessing instances"
  type        = string
  default     = "debian"
}

variable "ssh_private_key" {
  description = "SSH private key for accessing instances"
  type        = string
  sensitive   = true
}