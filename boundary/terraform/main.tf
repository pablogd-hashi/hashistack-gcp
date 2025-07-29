terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "~> 1.1.0"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.78.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

# Configure the Boundary provider
provider "boundary" {
  addr                   = var.boundary_addr
  auth_method_id         = var.boundary_auth_method_id
  auth_method_login_name = var.boundary_admin_login_name
  auth_method_password   = var.boundary_admin_password
}

# Configure the HCP provider - uses existing HCP credentials from variable sets
provider "hcp" {
  client_id     = var.hcp_client_id
  client_secret = var.hcp_client_secret
}

# Configure Google provider - uses existing GCP credentials from variable sets
provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

# Data source for existing HCP Boundary cluster
data "hcp_boundary_cluster" "main" {
  cluster_id = var.hcp_boundary_cluster_id
}

# Get instance IPs from DC cluster Terraform remote state
data "terraform_remote_state" "dc1" {
  count   = var.dc1_deployed ? 1 : 0
  backend = var.remote_state_backend
  config  = var.dc1_remote_state_config
}

data "terraform_remote_state" "dc2" {
  count   = var.dc2_deployed ? 1 : 0
  backend = var.remote_state_backend
  config  = var.dc2_remote_state_config
}

# Get instance IPs using external data sources (matching taskfile commands)
data "external" "dc1_server_ips" {
  count = var.dc1_deployed ? 1 : 0
  program = ["bash", "-c", <<-EOT
    ips=$(gcloud compute instances list --filter='name~hashi-server' --project='${var.gcp_project}' --format='value(EXTERNAL_IP)' | tr '\n' ',' | sed 's/,$//')
    echo "{\"servers\": \"$ips\"}"
  EOT
  ]
}

data "external" "dc1_client_ips" {
  count = var.dc1_deployed ? 1 : 0
  program = ["bash", "-c", <<-EOT
    ips=$(gcloud compute instances list --filter='name~hashi-clients' --project='${var.gcp_project}' --format='value(EXTERNAL_IP)' | tr '\n' ',' | sed 's/,$//')
    echo "{\"clients\": \"$ips\"}"
  EOT
  ]
}

data "external" "dc2_server_ips" {
  count = var.dc2_deployed ? 1 : 0
  program = ["bash", "-c", <<-EOT
    ips=$(gcloud compute instances list --filter='name~hashi-server' --project='${var.gcp_project}' --format='value(EXTERNAL_IP)' | tr '\n' ',' | sed 's/,$//')
    echo "{\"servers\": \"$ips\"}"
  EOT
  ]
}

data "external" "dc2_client_ips" {
  count = var.dc2_deployed ? 1 : 0
  program = ["bash", "-c", <<-EOT
    ips=$(gcloud compute instances list --filter='name~hashi-clients' --project='${var.gcp_project}' --format='value(EXTERNAL_IP)' | tr '\n' ',' | sed 's/,$//')
    echo "{\"clients\": \"$ips\"}"
  EOT
  ]
}

# Local values - use provided IPs or discover from external data sources
locals {
  dc1_server_ips = var.dc1_deployed ? (
    length(var.dc1_server_ips) > 0 ? var.dc1_server_ips : 
    split(",", data.external.dc1_server_ips[0].result.servers)
  ) : []
  
  dc1_client_ips = var.dc1_deployed ? (
    length(var.dc1_client_ips) > 0 ? var.dc1_client_ips : 
    split(",", data.external.dc1_client_ips[0].result.clients)
  ) : []
  
  dc2_server_ips = var.dc2_deployed ? (
    length(var.dc2_server_ips) > 0 ? var.dc2_server_ips : 
    split(",", data.external.dc2_server_ips[0].result.servers)
  ) : []
  
  dc2_client_ips = var.dc2_deployed ? (
    length(var.dc2_client_ips) > 0 ? var.dc2_client_ips : 
    split(",", data.external.dc2_client_ips[0].result.clients)
  ) : []
}

# Create organizational scopes
resource "boundary_scope" "development" {
  name                     = "Development"
  description              = "Development organization scope"
  scope_id                 = "global"
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "operations" {
  name                     = "Operations"
  description              = "Operations organization scope"
  scope_id                 = "global"
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create project scopes under Development
resource "boundary_scope" "dc1_dev" {
  count                    = var.dc1_deployed ? 1 : 0
  name                     = "DC1 Development"
  description              = "DC1 Development environment"
  scope_id                 = boundary_scope.development.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "dc2_dev" {
  count                    = var.dc2_deployed ? 1 : 0
  name                     = "DC2 Development"
  description              = "DC2 Development environment"
  scope_id                 = boundary_scope.development.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create project scopes under Operations
resource "boundary_scope" "dc1_prod" {
  count                    = var.dc1_deployed ? 1 : 0
  name                     = "DC1 Production"
  description              = "DC1 Production environment"
  scope_id                 = boundary_scope.operations.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "dc2_prod" {
  count                    = var.dc2_deployed ? 1 : 0
  name                     = "DC2 Production"
  description              = "DC2 Production environment"
  scope_id                 = boundary_scope.operations.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create global roles
resource "boundary_role" "management_users" {
  name        = "Management Users"
  description = "Role for users responsible for managing and configuring Boundary resources"
  scope_id    = "global"
  grant_strings = [
    "ids=*;type=*;actions=*"
  ]
}

resource "boundary_role" "developers" {
  name        = "Developers"
  description = "Role for development teams requiring access to development-related projects"
  scope_id    = "global"
  grant_strings = concat([
    "ids=${boundary_scope.development.id};actions=*",
    "ids=*;type=target;actions=*",
    "ids=*;type=session;actions=*"
  ], var.dc1_deployed ? [
    "ids=${boundary_scope.dc1_dev[0].id};actions=*"
  ] : [], var.dc2_deployed ? [
    "ids=${boundary_scope.dc2_dev[0].id};actions=*"
  ] : [])
}

resource "boundary_role" "operations" {
  name        = "Operations"
  description = "Role for operations teams managing production environments"
  scope_id    = "global"
  grant_strings = concat([
    "ids=${boundary_scope.operations.id};actions=*",
    "ids=*;type=target;actions=*",
    "ids=*;type=session;actions=*"
  ], var.dc1_deployed ? [
    "ids=${boundary_scope.dc1_prod[0].id};actions=*"
  ] : [], var.dc2_deployed ? [
    "ids=${boundary_scope.dc2_prod[0].id};actions=*"
  ] : [])
}

# Create auth method for password authentication
resource "boundary_auth_method" "password" {
  name        = "corporate_password_auth"
  description = "Password authentication for corporate users"
  type        = "password"
  scope_id    = "global"
}

# Create credential store for SSH keys in DC1 development project
resource "boundary_credential_store_static" "ssh_keys" {
  count       = var.dc1_deployed ? 1 : 0
  name        = "ssh_credential_store"
  description = "Static credential store for SSH keys"
  scope_id    = boundary_scope.dc1_dev[0].id
}

# Create SSH credential using existing SSH key
resource "boundary_credential_ssh_private_key" "ssh_key" {
  count               = var.dc1_deployed ? 1 : 0
  name                = "hashistack_ssh_key"
  description         = "SSH private key for accessing HashiStack instances"
  credential_store_id = boundary_credential_store_static.ssh_keys[0].id
  username            = "debian"
  private_key         = var.ssh_private_key
}

# DC1 Resources
# Create host catalog for DC1
resource "boundary_host_catalog_static" "dc1_hosts" {
  count       = var.dc1_deployed ? 1 : 0
  name        = "dc1_host_catalog"
  description = "Host catalog for DC1 cluster"
  scope_id    = boundary_scope.dc1_dev[0].id
}

# Create hosts for DC1 servers
resource "boundary_host_static" "dc1_servers" {
  count           = var.dc1_deployed ? length(local.dc1_server_ips) : 0
  name            = "dc1-server-${count.index + 1}"
  description     = "DC1 HashiStack server node ${count.index + 1}"
  address         = local.dc1_server_ips[count.index]
  host_catalog_id = boundary_host_catalog_static.dc1_hosts[0].id
}

# Create hosts for DC1 clients
resource "boundary_host_static" "dc1_clients" {
  count           = var.dc1_deployed ? length(local.dc1_client_ips) : 0
  name            = "dc1-client-${count.index + 1}"
  description     = "DC1 Nomad client node ${count.index + 1}"
  address         = local.dc1_client_ips[count.index]
  host_catalog_id = boundary_host_catalog_static.dc1_hosts[0].id
}

# Create host sets for DC1
resource "boundary_host_set_static" "dc1_servers" {
  count           = var.dc1_deployed ? 1 : 0
  name            = "dc1_servers"
  description     = "DC1 HashiStack server nodes"
  host_catalog_id = boundary_host_catalog_static.dc1_hosts[0].id
  host_ids        = [for host in boundary_host_static.dc1_servers : host.id]
}

resource "boundary_host_set_static" "dc1_clients" {
  count           = var.dc1_deployed ? 1 : 0
  name            = "dc1_clients"
  description     = "DC1 Nomad client nodes"
  host_catalog_id = boundary_host_catalog_static.dc1_hosts[0].id
  host_ids        = [for host in boundary_host_static.dc1_clients : host.id]
}

# DC2 Resources
# Create host catalog for DC2
resource "boundary_host_catalog_static" "dc2_hosts" {
  count       = var.dc2_deployed ? 1 : 0
  name        = "dc2_host_catalog"
  description = "Host catalog for DC2 cluster"
  scope_id    = boundary_scope.dc2_dev[0].id
}

# Create hosts for DC2 servers
resource "boundary_host_static" "dc2_servers" {
  count           = var.dc2_deployed ? length(local.dc2_server_ips) : 0
  name            = "dc2-server-${count.index + 1}"
  description     = "DC2 HashiStack server node ${count.index + 1}"
  address         = local.dc2_server_ips[count.index]
  host_catalog_id = boundary_host_catalog_static.dc2_hosts[0].id
}

# Create hosts for DC2 clients
resource "boundary_host_static" "dc2_clients" {
  count           = var.dc2_deployed ? length(local.dc2_client_ips) : 0
  name            = "dc2-client-${count.index + 1}"
  description     = "DC2 Nomad client node ${count.index + 1}"
  address         = local.dc2_client_ips[count.index]
  host_catalog_id = boundary_host_catalog_static.dc2_hosts[0].id
}

# Create host sets for DC2
resource "boundary_host_set_static" "dc2_servers" {
  count           = var.dc2_deployed ? 1 : 0
  name            = "dc2_servers"
  description     = "DC2 HashiStack server nodes"
  host_catalog_id = boundary_host_catalog_static.dc2_hosts[0].id
  host_ids        = [for host in boundary_host_static.dc2_servers : host.id]
}

resource "boundary_host_set_static" "dc2_clients" {
  count           = var.dc2_deployed ? 1 : 0
  name            = "dc2_clients"
  description     = "DC2 Nomad client nodes"
  host_catalog_id = boundary_host_catalog_static.dc2_hosts[0].id
  host_ids        = [for host in boundary_host_static.dc2_clients : host.id]
}

# Create targets for SSH access
resource "boundary_target" "dc1_servers_ssh" {
  count                    = var.dc1_deployed ? 1 : 0
  type                     = "ssh"
  name                     = "dc1-servers-ssh"
  description              = "SSH access to DC1 HashiStack servers (Consul + Nomad)"
  scope_id                 = boundary_scope.dc1_dev[0].id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_static.dc1_servers[0].id
  ]
  injected_application_credential_source_ids = [
    boundary_credential_ssh_private_key.ssh_key[0].id
  ]
}

resource "boundary_target" "dc1_clients_ssh" {
  count                    = var.dc1_deployed ? 1 : 0
  type                     = "ssh"
  name                     = "dc1-clients-ssh"
  description              = "SSH access to DC1 Nomad clients"
  scope_id                 = boundary_scope.dc1_dev[0].id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_static.dc1_clients[0].id
  ]
  injected_application_credential_source_ids = [
    boundary_credential_ssh_private_key.ssh_key[0].id
  ]
}

resource "boundary_target" "dc2_servers_ssh" {
  count                    = var.dc2_deployed ? 1 : 0
  type                     = "ssh"
  name                     = "dc2-servers-ssh"
  description              = "SSH access to DC2 HashiStack servers (Consul + Nomad)"
  scope_id                 = boundary_scope.dc2_dev[0].id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_static.dc2_servers[0].id
  ]
  injected_application_credential_source_ids = [
    boundary_credential_ssh_private_key.ssh_key[0].id
  ]
}

resource "boundary_target" "dc2_clients_ssh" {
  count                    = var.dc2_deployed ? 1 : 0
  type                     = "ssh"
  name                     = "dc2-clients-ssh"
  description              = "SSH access to DC2 Nomad clients"
  scope_id                 = boundary_scope.dc2_dev[0].id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_static.dc2_clients[0].id
  ]
  injected_application_credential_source_ids = [
    boundary_credential_ssh_private_key.ssh_key[0].id
  ]
}

# UI targets removed - only SSH access to servers and clients