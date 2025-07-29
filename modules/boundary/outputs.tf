# Boundary module outputs

output "boundary_targets" {
  description = "Created Boundary targets for this cluster"
  value = var.enabled ? {
    ssh_servers = length(boundary_target.servers_ssh) > 0 ? boundary_target.servers_ssh[0].id : null
    ssh_clients = length(boundary_target.clients_ssh) > 0 ? boundary_target.clients_ssh[0].id : null
    consul_ui   = length(boundary_target.consul_ui) > 0 ? boundary_target.consul_ui[0].id : null
    nomad_ui    = length(boundary_target.nomad_ui) > 0 ? boundary_target.nomad_ui[0].id : null
    grafana     = length(boundary_target.grafana) > 0 ? boundary_target.grafana[0].id : null
    prometheus  = length(boundary_target.prometheus) > 0 ? boundary_target.prometheus[0].id : null
    traefik     = length(boundary_target.traefik) > 0 ? boundary_target.traefik[0].id : null
  } : {}
}

output "boundary_scope_id" {
  description = "Boundary project scope ID for this cluster"
  value       = var.enabled && length(boundary_scope.cluster_project) > 0 ? boundary_scope.cluster_project[0].id : null
}

output "discovered_instances" {
  description = "Discovered instance information"
  value = var.enabled ? {
    server_ips = local.server_ips
    client_ips = local.client_ips
    total_servers = length(local.server_ips)
    total_clients = length(local.client_ips)
  } : {}
}