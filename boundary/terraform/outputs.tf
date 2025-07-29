# Boundary Cluster Information
output "boundary_cluster_url" {
  description = "URL to access the Boundary cluster"
  value       = data.hcp_boundary_cluster.main.cluster_url
}

output "boundary_cluster_id" {
  description = "HCP Boundary cluster ID"
  value       = data.hcp_boundary_cluster.main.cluster_id
}

output "boundary_auth_method_id" {
  description = "Boundary auth method ID"
  value       = var.boundary_auth_method_id
}

# Discovered Infrastructure Information
output "discovered_infrastructure" {
  description = "Automatically discovered infrastructure"
  value = {
    dc1 = var.dc1_deployed ? {
      deployed     = true
      server_ips   = local.dc1_server_ips
      client_ips   = local.dc1_client_ips
      server_count = length(local.dc1_server_ips)
      client_count = length(local.dc1_client_ips)
    } : {
      deployed     = false
      server_ips   = []
      client_ips   = []
      server_count = 0
      client_count = 0
    }
    dc2 = var.dc2_deployed ? {
      deployed     = true
      server_ips   = local.dc2_server_ips
      client_ips   = local.dc2_client_ips
      server_count = length(local.dc2_server_ips)
      client_count = length(local.dc2_client_ips)
    } : {
      deployed     = false
      server_ips   = []
      client_ips   = []
      server_count = 0
      client_count = 0
    }
  }
}

# Scope Information
output "boundary_scopes" {
  description = "Created Boundary scopes"
  value = {
    development = {
      id   = boundary_scope.development.id
      name = boundary_scope.development.name
    }
    operations = {
      id   = boundary_scope.operations.id
      name = boundary_scope.operations.name
    }
    dc1_dev = var.dc1_deployed ? {
      id   = boundary_scope.dc1_dev[0].id
      name = boundary_scope.dc1_dev[0].name
    } : null
    dc2_dev = var.dc2_deployed ? {
      id   = boundary_scope.dc2_dev[0].id
      name = boundary_scope.dc2_dev[0].name
    } : null
    dc1_prod = var.dc1_deployed ? {
      id   = boundary_scope.dc1_prod[0].id
      name = boundary_scope.dc1_prod[0].name
    } : null
    dc2_prod = var.dc2_deployed ? {
      id   = boundary_scope.dc2_prod[0].id
      name = boundary_scope.dc2_prod[0].name
    } : null
  }
}

# Role Information
output "boundary_roles" {
  description = "Created Boundary roles"
  value = {
    management_users = {
      id   = boundary_role.management_users.id
      name = boundary_role.management_users.name
    }
    developers = {
      id   = boundary_role.developers.id
      name = boundary_role.developers.name
    }
    operations = {
      id   = boundary_role.operations.id
      name = boundary_role.operations.name
    }
  }
}

# Target Information
output "boundary_targets" {
  description = "Created Boundary targets"
  value = merge(
    var.dc1_deployed ? {
      dc1_servers_ssh = {
        id   = boundary_target.dc1_servers_ssh[0].id
        name = boundary_target.dc1_servers_ssh[0].name
        type = "ssh"
        port = 22
      }
      dc1_clients_ssh = {
        id   = boundary_target.dc1_clients_ssh[0].id
        name = boundary_target.dc1_clients_ssh[0].name
        type = "ssh"
        port = 22
      }
      dc1_consul_ui = {
        id   = boundary_target.dc1_consul_ui[0].id
        name = boundary_target.dc1_consul_ui[0].name
        type = "tcp"
        port = 8500
      }
      dc1_nomad_ui = {
        id   = boundary_target.dc1_nomad_ui[0].id
        name = boundary_target.dc1_nomad_ui[0].name
        type = "tcp"
        port = 4646
      }
      dc1_grafana = {
        id   = boundary_target.dc1_grafana[0].id
        name = boundary_target.dc1_grafana[0].name
        type = "tcp"
        port = 3000
      }
      dc1_prometheus = {
        id   = boundary_target.dc1_prometheus[0].id
        name = boundary_target.dc1_prometheus[0].name
        type = "tcp"
        port = 9090
      }
    } : {},
    var.dc2_deployed ? {
      dc2_servers_ssh = {
        id   = boundary_target.dc2_servers_ssh[0].id
        name = boundary_target.dc2_servers_ssh[0].name
        type = "ssh"
        port = 22
      }
      dc2_clients_ssh = {
        id   = boundary_target.dc2_clients_ssh[0].id
        name = boundary_target.dc2_clients_ssh[0].name
        type = "ssh"
        port = 22
      }
      dc2_consul_ui = {
        id   = boundary_target.dc2_consul_ui[0].id
        name = boundary_target.dc2_consul_ui[0].name
        type = "tcp"
        port = 8500
      }
      dc2_nomad_ui = {
        id   = boundary_target.dc2_nomad_ui[0].id
        name = boundary_target.dc2_nomad_ui[0].name
        type = "tcp"
        port = 4646
      }
      dc2_grafana = {
        id   = boundary_target.dc2_grafana[0].id
        name = boundary_target.dc2_grafana[0].name
        type = "tcp"
        port = 3000
      }
      dc2_prometheus = {
        id   = boundary_target.dc2_prometheus[0].id
        name = boundary_target.dc2_prometheus[0].name
        type = "tcp"
        port = 9090
      }
    } : {}
  )
}

# Connection Commands
output "connection_commands" {
  description = "Ready-to-use connection commands"
  value = {
    authentication = [
      "export BOUNDARY_ADDR=${data.hcp_boundary_cluster.main.cluster_url}",
      "boundary authenticate password -auth-method-id ${var.boundary_auth_method_id} -login-name admin"
    ]
    ssh_commands = concat(
      var.dc1_deployed ? [
        "boundary connect ssh -target-id ${boundary_target.dc1_servers_ssh[0].id}  # DC1 servers",
        "boundary connect ssh -target-id ${boundary_target.dc1_clients_ssh[0].id}  # DC1 clients"
      ] : [],
      var.dc2_deployed ? [
        "boundary connect ssh -target-id ${boundary_target.dc2_servers_ssh[0].id}  # DC2 servers",
        "boundary connect ssh -target-id ${boundary_target.dc2_clients_ssh[0].id}  # DC2 clients"
      ] : []
    )
    ui_commands = concat(
      var.dc1_deployed ? [
        "boundary connect -target-id ${boundary_target.dc1_consul_ui[0].id} -listen-port 8500  # DC1 Consul UI -> http://localhost:8500",
        "boundary connect -target-id ${boundary_target.dc1_nomad_ui[0].id} -listen-port 4646   # DC1 Nomad UI -> http://localhost:4646",
        "boundary connect -target-id ${boundary_target.dc1_grafana[0].id} -listen-port 3000    # DC1 Grafana -> http://localhost:3000",
        "boundary connect -target-id ${boundary_target.dc1_prometheus[0].id} -listen-port 9090  # DC1 Prometheus -> http://localhost:9090"
      ] : [],
      var.dc2_deployed ? [
        "boundary connect -target-id ${boundary_target.dc2_consul_ui[0].id} -listen-port 8501  # DC2 Consul UI -> http://localhost:8501",
        "boundary connect -target-id ${boundary_target.dc2_nomad_ui[0].id} -listen-port 4647   # DC2 Nomad UI -> http://localhost:4647",
        "boundary connect -target-id ${boundary_target.dc2_grafana[0].id} -listen-port 3001    # DC2 Grafana -> http://localhost:3001",
        "boundary connect -target-id ${boundary_target.dc2_prometheus[0].id} -listen-port 9091  # DC2 Prometheus -> http://localhost:9091"
      ] : []
    )
  }
}

# Summary Output
output "boundary_summary" {
  description = "Boundary deployment summary"
  value = {
    cluster_url = data.hcp_boundary_cluster.main.cluster_url
    clusters_integrated = compact([
      var.dc1_deployed ? "DC1" : null,
      var.dc2_deployed ? "DC2" : null
    ])
    total_targets = length(keys(merge(
      var.dc1_deployed ? {
        dc1_servers_ssh = "ssh", dc1_clients_ssh = "ssh",
        dc1_consul_ui = "tcp", dc1_nomad_ui = "tcp",
        dc1_grafana = "tcp", dc1_prometheus = "tcp"
      } : {},
      var.dc2_deployed ? {
        dc2_servers_ssh = "ssh", dc2_clients_ssh = "ssh",
        dc2_consul_ui = "tcp", dc2_nomad_ui = "tcp",
        dc2_grafana = "tcp", dc2_prometheus = "tcp"
      } : {}
    )))
    total_hosts = (var.dc1_deployed ? (length(local.dc1_server_ips) + length(local.dc1_client_ips)) : 0) + (var.dc2_deployed ? (length(local.dc2_server_ips) + length(local.dc2_client_ips)) : 0)
    next_steps = [
      "Run 'task boundary:connect' to see connection commands",
      "Run 'task boundary:setup-workers' to deploy workers",
      "Visit ${data.hcp_boundary_cluster.main.cluster_url} to manage users and permissions"
    ]
  }
}