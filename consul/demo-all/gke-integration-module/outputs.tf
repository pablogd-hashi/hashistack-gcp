# Outputs for GKE Southwest CTS Integration

output "integration_status" {
  description = "Status of the CTS integration with GKE Southwest"
  value = {
    cluster_name     = data.google_container_cluster.existing_cluster.name
    cluster_location = data.google_container_cluster.existing_cluster.location
    network_name     = data.google_compute_network.existing_network.name
    services_count   = length(var.services)
    timestamp        = timestamp()
  }
}

output "firewall_rules" {
  description = "Firewall rules created for services"
  value = {
    for name, svc in var.services : name => {
      rule_name = svc.name == "frontend" ? google_compute_firewall.consul_services_ingress[name].name : null
      port      = svc.port
      service   = svc.name
    } if svc.name == "frontend"
  }
}

output "consul_kv_paths" {
  description = "Consul KV paths updated by this module"
  value = [
    "cts/gke-southwest/infrastructure/firewall_rules",
    "cts/gke-southwest/services/current_state"
  ]
}

output "monitoring_config_location" {
  description = "Location of the monitoring configuration file"
  value = local_file.gke_service_monitoring.filename
}