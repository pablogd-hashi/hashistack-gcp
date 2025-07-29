# Boundary integration module for HashiStack clusters
# This module creates Boundary resources using provided instance IPs

terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "~> 1.1.0"
    }
  }
}

# Local values for instance IPs (passed as variables)
locals {
  server_ips = var.enabled ? var.server_instance_ips : []
  client_ips = var.enabled ? var.client_instance_ips : []
}

# Create project scope for this cluster
resource "boundary_scope" "cluster_project" {
  count                    = var.enabled ? 1 : 0
  name                     = var.cluster_name
  description              = "Project scope for ${var.cluster_name} cluster"
  scope_id                 = var.parent_scope_id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create credential store for SSH keys
resource "boundary_credential_store_static" "ssh_keys" {
  count       = var.enabled ? 1 : 0
  name        = "${var.cluster_name}_ssh_credentials"
  description = "SSH credentials for ${var.cluster_name} cluster"
  scope_id    = boundary_scope.cluster_project[0].id
}

# Create SSH credential
resource "boundary_credential_ssh_private_key" "ssh_key" {
  count               = var.enabled ? 1 : 0
  name                = "${var.cluster_name}_ssh_key"
  description         = "SSH private key for ${var.cluster_name} instances"
  credential_store_id = boundary_credential_store_static.ssh_keys[0].id
  username            = var.ssh_username
  private_key         = var.ssh_private_key
}

# Create host catalog
resource "boundary_host_catalog_static" "cluster_hosts" {
  count       = var.enabled ? 1 : 0
  name        = "${var.cluster_name}_host_catalog"
  description = "Host catalog for ${var.cluster_name} cluster"
  scope_id    = boundary_scope.cluster_project[0].id
}

# Create hosts for servers
resource "boundary_host_static" "servers" {
  count           = var.enabled ? length(local.server_ips) : 0
  name            = "${var.cluster_name}-server-${count.index + 1}"
  description     = "${var.cluster_name} HashiStack server node ${count.index + 1}"
  address         = local.server_ips[count.index]
  host_catalog_id = boundary_host_catalog_static.cluster_hosts[0].id
}

# Create hosts for clients
resource "boundary_host_static" "clients" {
  count           = var.enabled ? length(local.client_ips) : 0
  name            = "${var.cluster_name}-client-${count.index + 1}"
  description     = "${var.cluster_name} Nomad client node ${count.index + 1}"
  address         = local.client_ips[count.index]
  host_catalog_id = boundary_host_catalog_static.cluster_hosts[0].id
}

# Create host sets
resource "boundary_host_set_static" "servers" {
  count           = var.enabled && length(local.server_ips) > 0 ? 1 : 0
  name            = "${var.cluster_name}_servers"
  description     = "${var.cluster_name} HashiStack server nodes"
  host_catalog_id = boundary_host_catalog_static.cluster_hosts[0].id
  host_ids        = [for host in boundary_host_static.servers : host.id]
}

resource "boundary_host_set_static" "clients" {
  count           = var.enabled && length(local.client_ips) > 0 ? 1 : 0
  name            = "${var.cluster_name}_clients"
  description     = "${var.cluster_name} Nomad client nodes"
  host_catalog_id = boundary_host_catalog_static.cluster_hosts[0].id
  host_ids        = [for host in boundary_host_static.clients : host.id]
}

# SSH targets
resource "boundary_target" "servers_ssh" {
  count                    = var.enabled && length(local.server_ips) > 0 ? 1 : 0
  type                     = "ssh"
  name                     = "${var.cluster_name}-servers-ssh"
  description              = "SSH access to ${var.cluster_name} HashiStack servers (Consul + Nomad)"
  scope_id                 = boundary_scope.cluster_project[0].id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_static.servers[0].id
  ]
  brokered_credential_source_ids = [
    boundary_credential_ssh_private_key.ssh_key[0].id
  ]
}

resource "boundary_target" "clients_ssh" {
  count                    = var.enabled && length(local.client_ips) > 0 ? 1 : 0
  type                     = "ssh"
  name                     = "${var.cluster_name}-clients-ssh"
  description              = "SSH access to ${var.cluster_name} Nomad clients"
  scope_id                 = boundary_scope.cluster_project[0].id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_static.clients[0].id
  ]
  brokered_credential_source_ids = [
    boundary_credential_ssh_private_key.ssh_key[0].id
  ]
}

# Service UI targets
resource "boundary_target" "consul_ui" {
  count                    = var.enabled && length(local.server_ips) > 0 ? 1 : 0
  type                     = "tcp"
  name                     = "${var.cluster_name}-consul-ui"
  description              = "Access to ${var.cluster_name} Consul UI (port 8500)"
  scope_id                 = boundary_scope.cluster_project[0].id
  session_connection_limit = -1
  default_port             = 8500
  host_source_ids = [
    boundary_host_set_static.servers[0].id
  ]
}

resource "boundary_target" "nomad_ui" {
  count                    = var.enabled && length(local.server_ips) > 0 ? 1 : 0
  type                     = "tcp"
  name                     = "${var.cluster_name}-nomad-ui"
  description              = "Access to ${var.cluster_name} Nomad UI (port 4646)"
  scope_id                 = boundary_scope.cluster_project[0].id
  session_connection_limit = -1
  default_port             = 4646
  host_source_ids = [
    boundary_host_set_static.servers[0].id
  ]
}

# Monitoring targets (only if clients exist)
resource "boundary_target" "grafana" {
  count                    = var.enabled && length(local.client_ips) > 0 ? 1 : 0
  type                     = "tcp"
  name                     = "${var.cluster_name}-grafana"
  description              = "Access to ${var.cluster_name} Grafana (port 3000)"
  scope_id                 = boundary_scope.cluster_project[0].id
  session_connection_limit = -1
  default_port             = 3000
  host_source_ids = [
    boundary_host_set_static.clients[0].id
  ]
}

resource "boundary_target" "prometheus" {
  count                    = var.enabled && length(local.client_ips) > 0 ? 1 : 0
  type                     = "tcp"
  name                     = "${var.cluster_name}-prometheus"
  description              = "Access to ${var.cluster_name} Prometheus (port 9090)"
  scope_id                 = boundary_scope.cluster_project[0].id
  session_connection_limit = -1
  default_port             = 9090
  host_source_ids = [
    boundary_host_set_static.clients[0].id
  ]
}

resource "boundary_target" "traefik" {
  count                    = var.enabled && length(local.client_ips) > 0 ? 1 : 0
  type                     = "tcp"
  name                     = "${var.cluster_name}-traefik"
  description              = "Access to ${var.cluster_name} Traefik dashboard (port 8080)"
  scope_id                 = boundary_scope.cluster_project[0].id
  session_connection_limit = -1
  default_port             = 8080
  host_source_ids = [
    boundary_host_set_static.clients[0].id
  ]
}