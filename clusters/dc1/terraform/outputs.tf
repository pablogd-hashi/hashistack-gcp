# ============================================================================
# CLUSTER INFRASTRUCTURE OUTPUTS
# ============================================================================

output "cluster_info" {
  description = "Basic cluster information"
  value = {
    name         = var.cluster_name
    region       = var.gcp_region
    project      = var.gcp_project
    server_count = var.numnodes
    client_count = var.numclients
    domain       = var.dns_zone != "" ? trimsuffix(google_dns_record_set.dns[0].name, ".") : "IP-based access"
  }
}

# ============================================================================
# HASHICORP STACK ACCESS URLS
# ============================================================================

output "hashistack_urls" {
  description = "HashiCorp stack service URLs"
  value = {
    consul = {
      ui_url = var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.consul[0].name, ".")}:8500" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:8500"
      api    = var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.consul[0].name, ".")}:8500" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:8500"
    }
    nomad = {
      ui_url = var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.dns[0].name, ".")}:4646" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:4646"
      api    = var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.dns[0].name, ".")}:4646" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:4646"
    }
  }
}

# ============================================================================
# APPLICATION MONITORING URLS
# ============================================================================

output "monitoring_urls" {
  description = "Monitoring and application service URLs"
  value = {
    traefik = {
      dashboard = var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.traefik[0].name, ".")}:8080" : "http://${google_compute_forwarding_rule.clients-lb[0].ip_address}:8080"
      api       = var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.traefik[0].name, ".")}:8080/api" : "http://${google_compute_forwarding_rule.clients-lb[0].ip_address}:8080/api"
    }
    grafana = {
      dashboard = "http://${google_compute_forwarding_rule.clients-lb[0].ip_address}:3000"
      login     = "admin/admin"
    }
    prometheus = {
      ui  = "http://${google_compute_forwarding_rule.clients-lb[0].ip_address}:9090"
      api = "http://${google_compute_forwarding_rule.clients-lb[0].ip_address}:9090/api/v1"
    }
  }
}

# ============================================================================
# SERVER NODE INFORMATION
# ============================================================================

output "server_nodes" {
  description = "HashiCorp server node details (managed by instance group)"
  value = {
    instance_group = google_compute_region_instance_group_manager.hashi-group.name
    base_name      = google_compute_region_instance_group_manager.hashi-group.base_instance_name
    region         = google_compute_region_instance_group_manager.hashi-group.region
    target_size    = var.numnodes
    status         = google_compute_region_instance_group_manager.hashi-group.status[0].is_stable ? "stable" : "updating"
    note           = "Individual instance IPs available via: gcloud compute instances list --filter='name~hashi-server'"
  }
}

# ============================================================================
# CLIENT NODE INFORMATION  
# ============================================================================

output "client_nodes" {
  description = "Nomad client node details for applications (managed by instance groups)"
  value = {
    groups = {
      for i, group in google_compute_region_instance_group_manager.clients-group : "group-${i}" => {
        instance_group = group.name
        base_name      = group.base_instance_name
        region         = group.region
        target_size    = group.target_size
        status         = length(group.status) > 0 ? (group.status[0].is_stable ? "stable" : "updating") : "unknown"
      }
    }
    note = "Individual instance IPs available via: gcloud compute instances list --filter='name~hashi-clients'"
  }
}

# ============================================================================
# AUTHENTICATION TOKENS
# ============================================================================

output "auth_tokens" {
  description = "Authentication tokens for HashiCorp services"
  value = {
    consul_token = var.consul_bootstrap_token
    nomad_token  = random_uuid.nomad_bootstrap.result
  }
  sensitive = true
}

# ============================================================================
# ENVIRONMENT SETUP COMMANDS
# ============================================================================

output "environment_setup" {
  description = "Commands to configure your local environment"
  value = {
    bash_export = <<-EOT
      # HashiCorp Stack Environment Setup
      export CONSUL_HTTP_ADDR="${var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.consul[0].name, ".")}:8500" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:8500"}"
      export CONSUL_HTTP_TOKEN="${var.consul_bootstrap_token}"
      export CONSUL_HTTP_SSL_VERIFY=false
      export NOMAD_ADDR="${var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.dns[0].name, ".")}:4646" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:4646"}"
      export NOMAD_TOKEN="${random_uuid.nomad_bootstrap.result}"
      
      # Quick access commands
      alias consul-ui='open ${var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.consul[0].name, ".")}:8500" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:8500"}'
      alias nomad-ui='open ${var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.dns[0].name, ".")}:4646" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:4646"}'
      alias grafana-ui='open http://${google_compute_forwarding_rule.clients-lb[0].ip_address}:3000'
      alias prometheus-ui='open http://${google_compute_forwarding_rule.clients-lb[0].ip_address}:9090'
    EOT
    
    powershell_export = <<-EOT
      # HashiCorp Stack Environment Setup (PowerShell)
      $env:CONSUL_HTTP_ADDR="${var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.consul[0].name, ".")}:8500" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:8500"}"
      $env:CONSUL_HTTP_TOKEN="${var.consul_bootstrap_token}"
      $env:CONSUL_HTTP_SSL_VERIFY="false"
      $env:NOMAD_ADDR="${var.dns_zone != "" ? "http://${trimsuffix(google_dns_record_set.dns[0].name, ".")}:4646" : "http://${google_compute_forwarding_rule.global-lb.ip_address}:4646"}"
      $env:NOMAD_TOKEN="${random_uuid.nomad_bootstrap.result}"
    EOT
  }
  sensitive = true
}

# ============================================================================
# QUICK ACCESS COMMANDS
# ============================================================================

output "quick_commands" {
  description = "Useful commands for cluster management"
  value = {
    get_consul_token    = "terraform output -raw auth_tokens | jq -r '.consul_token'"
    get_nomad_token     = "terraform output -raw auth_tokens | jq -r '.nomad_token'"
    setup_env           = "eval \"$(terraform output -raw environment_setup | grep 'bash_export' -A 20 | tail -n +2 | head -n -1)\""
    list_server_instances = "gcloud compute instances list --filter='name~hashi-server' --format='table(name,zone,status,natIP)'"
    list_client_instances = "gcloud compute instances list --filter='name~hashi-clients' --format='table(name,zone,status,natIP)'"
    ssh_server_example    = "ssh debian@$(gcloud compute instances list --filter='name~hashi-server' --format='value(natIP)' --limit=1)"
    ssh_client_example    = "ssh debian@$(gcloud compute instances list --filter='name~hashi-clients' --format='value(natIP)' --limit=1)"
  }
}

# ============================================================================
# LOAD BALANCER INFORMATION
# ============================================================================

output "load_balancers" {
  description = "Load balancer IP addresses"
  value = {
    global_lb = {
      ip          = google_compute_forwarding_rule.global-lb.ip_address
      description = "Main load balancer for HashiCorp stack"
    }
    clients_lb = {
      ip          = google_compute_forwarding_rule.clients-lb[0].ip_address  
      description = "Client load balancer for applications"
    }
  }
}