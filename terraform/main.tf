terraform { 
  cloud { 
    organization = "pablogd-hcp-test" 

    workspaces { 
      name = "hashistack-terramino-nomad-consul"
    } 
  } 
}

terraform {
  required_version = ">= 1.0.0"
  # backend "remote" {
  # }
}

resource "random_id" "server" {
  byte_length = 1
}

# Collect client config for GCP
data "google_client_config" "current" {
}
data "google_service_account" "owner_project" {
  account_id = var.gcp_sa
}



## ----- Network capabilities ------
# VPC creation
resource "google_compute_network" "network" {
  name = "${var.cluster_name}-network"
}


# Subnet creation
resource "google_compute_subnetwork" "subnet" {
  name = "${var.cluster_name}-subnetwork"

  ip_cidr_range = "10.2.0.0/16"
  region        = var.gcp_region
  network       = google_compute_network.network.id
}

# Create an ip address for the load balancer
resource "google_compute_address" "global-ip" {
  name = "lb-ip"
  region = var.gcp_region
}

# External IP addresses
resource "google_compute_address" "server_addr" {
  count = var.numnodes
  name  = "server-addr-${count.index}"
  # subnetwork = google_compute_subnetwork.subnet.id
  region = var.gcp_region
}

resource "google_compute_address" "client_addr" {
  count = var.numclients
  name  = "client-addr-${count.index}"
  # subnetwork = google_compute_subnetwork.subnet.id
  region = var.gcp_region
}

# Create firewall rules

resource "google_compute_firewall" "default" {
  name    = "hashi-rules-${random_id.server.dec}"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
    ports    = ["80","443","8500","8501","8502","8503","22","8300","8301","8400","8302","8600","4646","4647","4648","8443","8080","3000","9090"]
  }
  allow {
    protocol = "udp"
    ports = ["8600","8301","8302"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.cluster_name,"nomad-${var.cluster_name}","consul-${var.cluster_name}"]
}
# These are internal rules for communication between the nodes internally
resource "google_compute_firewall" "internal" {
  name    = "hashi-internal-rules-${random_id.server.dec}"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }

  source_tags = [var.cluster_name,"nomad-${var.cluster_name}","consul-${var.cluster_name}"]
  target_tags   = [var.cluster_name,"nomad-${var.cluster_name}","consul-${var.cluster_name}"]
}     

# Creating Load Balancing with different required resources
resource "google_compute_region_backend_service" "default" {
  name          = "${var.cluster_name}-backend-service"
  health_checks = [
    google_compute_region_health_check.default.id
  ]
  region = var.gcp_region
  protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  backend {
    # group  = google_compute_instance_group.hashi_group.id
    group = google_compute_region_instance_group_manager.hashi-group.instance_group
    # balancing_mode = "CONNECTION"
  }
}

resource "google_compute_region_backend_service" "apps" {
  count = length(google_compute_region_instance_group_manager.clients-group)
  name          = "${var.cluster_name}-apigw-${count.index}"
  health_checks = [
    google_compute_region_health_check.apps.id
  ]
  region = var.gcp_region
  protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  backend {
    # group  = google_compute_instance_group.app_group.id
    group = google_compute_region_instance_group_manager.clients-group[count.index].instance_group
    balancing_mode = "UTILIZATION"
  }
}

# resource "google_compute_target_pool" "vm-pool" {
#   name = "instance-pool"

#   instances = google_compute_instance_from_template.vm_clients.*.self_link

#   health_checks = [
#     google_compute_http_health_check.apps.id,
#   ]
# }

resource "google_compute_region_health_check" "default" {
  name = "health-check"
  # request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
  region = var.gcp_region

  # http_health_check {
  #   port = "8500"
  #   request_path = "/ui"
  # }
  tcp_health_check {
    port = "8500"
  }
}

resource "google_compute_region_health_check" "apps" {
  name = "health-check-apigw"
  check_interval_sec = 1
  timeout_sec        = 1
  region = var.gcp_region

  # http_health_check {
  #   port = "8080"
  #   request_path = "/"
  # }
  tcp_health_check {
    port = "8080"
  }
}
# resource "google_compute_http_health_check" "apps" {
#   name               = "default"
#   request_path       = "/"
#   check_interval_sec = 1
#   timeout_sec        = 1
#   port = 8080
# }

resource "google_compute_forwarding_rule" "global-lb" {
  name       = "hashistack-lb"
  # ip_address = google_compute_global_address.global-ip.address
  ip_address = google_compute_address.global-ip.address
  # target     = google_compute_target_pool.vm-pool.self_link
  backend_service = google_compute_region_backend_service.default.id
  region = var.gcp_region
  ip_protocol = "TCP"
  ports = ["4646-4648","8500-8503","8600","9701-9702","8443"]
}

# The number of LBs for the apps will be equal to the number of region instance groups (one per admin partition)
resource "google_compute_forwarding_rule" "clients-lb" {
  count = length(google_compute_region_backend_service.apps)
  name       = "clients-lb"
  #  ip_address = google_compute_address.global-ip.address
  backend_service = google_compute_region_backend_service.apps[count.index].id
  # target    = google_compute_target_pool.vm-pool.self_link
  region = var.gcp_region
  ip_protocol = "TCP"
  ports = ["80","443","8443","8080"]
}





# SSL Certificates and HTTPS Load Balancer
resource "google_compute_managed_ssl_certificate" "monitoring_ssl" {
  count = var.dns_zone != "" ? 1 : 0
  name = "monitoring-ssl-cert"

  managed {
    domains = [
      trimsuffix(google_dns_record_set.traefik[0].name, "."),
      trimsuffix(google_dns_record_set.grafana[0].name, "."),
      trimsuffix(google_dns_record_set.prometheus[0].name, "."),
      trimsuffix(google_dns_record_set.consul[0].name, "."),
      trimsuffix(google_dns_record_set.dns[0].name, ".")
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Global IP for HTTPS load balancer
resource "google_compute_global_address" "https_ip" {
  count = var.dns_zone != "" ? 1 : 0
  name  = "https-lb-ip"
}

# Global forwarding rule for HTTPS
resource "google_compute_global_forwarding_rule" "https-lb" {
  count      = var.dns_zone != "" ? 1 : 0
  name       = "https-forwarding-rule"
  target     = google_compute_target_https_proxy.https_proxy[0].id
  ip_address = google_compute_global_address.https_ip[0].address
  port_range = "443"
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  count   = var.dns_zone != "" ? 1 : 0
  name    = "https-proxy"
  url_map = google_compute_url_map.https_lb[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.monitoring_ssl[0].id]
}

# URL map for routing (simplified - route based on host headers)
resource "google_compute_url_map" "https_lb" {
  count           = var.dns_zone != "" ? 1 : 0
  name            = "https-url-map"
  default_service = google_compute_backend_service.https_backend[0].id
}

# Backend service for HTTPS (points to client nodes with Traefik)
resource "google_compute_backend_service" "https_backend" {
  count       = var.dns_zone != "" ? 1 : 0
  name        = "https-backend-service"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_instance_group_manager.clients-group[0].instance_group
    balancing_mode = "UTILIZATION"
  }

  health_checks = [google_compute_health_check.http.id]
}

# Health check for HTTPS backend
resource "google_compute_health_check" "http" {
  name = "http-health-check"

  http_health_check {
    port = "8080"
    request_path = "/ping"
  }
}

# HTTP to HTTPS redirect
resource "google_compute_url_map" "http_redirect" {
  count = var.dns_zone != "" ? 1 : 0
  name  = "http-redirect"

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "http_proxy" {
  count   = var.dns_zone != "" ? 1 : 0
  name    = "http-proxy"
  url_map = google_compute_url_map.http_redirect[0].id
}

resource "google_compute_global_forwarding_rule" "http_redirect" {
  count      = var.dns_zone != "" ? 1 : 0
  name       = "http-redirect-rule"
  target     = google_compute_target_http_proxy.http_proxy[0].id
  ip_address = google_compute_global_address.https_ip[0].address
  port_range = "80"
}

data "google_compute_image" "my_image" {
  family  = var.image_family
  project = var.gcp_project
}

# Let's take the image from HCP Packer
# Commented out to avoid HCP provider initialization when use_hcp_packer = false
# data "hcp_packer_version" "hardened-source" {
#   count = var.use_hcp_packer ? 1 : 0
#   bucket_name  = var.hcp_packer_bucket
#   channel_name = var.hcp_packer_channel
# }

# data "hcp_packer_artifact" "consul-nomad" {
#   count              = var.use_hcp_packer ? 1 : 0
#   bucket_name         = var.hcp_packer_bucket
#   version_fingerprint = data.hcp_packer_version.hardened-source[0].fingerprint
#   platform            = "gce"
#   region              = var.hcp_packer_region
# }


data "google_dns_managed_zone" "doormat_dns_zone" {
  count = var.dns_zone != "" ? 1 : 0
  name = var.dns_zone
}

resource "google_dns_record_set" "dns" {
  count = var.dns_zone != "" ? 1 : 0
  name = "nomad.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_forwarding_rule.global-lb.ip_address]
}

# DNS records for monitoring services (use static IP to avoid circular dependency)
resource "google_dns_record_set" "traefik" {
  count = var.dns_zone != "" ? 1 : 0
  name = "traefik.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_global_address.https_ip[0].address]
}

resource "google_dns_record_set" "grafana" {
  count = var.dns_zone != "" ? 1 : 0
  name = "grafana.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_global_address.https_ip[0].address]
}

resource "google_dns_record_set" "prometheus" {
  count = var.dns_zone != "" ? 1 : 0
  name = "prometheus.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_global_address.https_ip[0].address]
}

resource "google_dns_record_set" "consul" {
  count = var.dns_zone != "" ? 1 : 0
  name = "consul.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_global_address.https_ip[0].address]
}

# resource "google_compute_global_forwarding_rule" "hashicups" {
#   name                  = "hashicups-global-lb"
#   ip_protocol           = "TCP"
#   load_balancing_scheme = "EXTERNAL"
#   port_range            = "80"
#   target                = google_compute_target_http_proxy.hashicups.id
#   # ip_address            = google_compute_global_address.default.id
# }

# # http proxy
# resource "google_compute_target_http_proxy" "hashicups" {
#   name     = "hashicups-proxy"
#   # provider = google-beta
#   url_map  = google_compute_url_map.hashicups.id
# }

# # url map
# resource "google_compute_url_map" "hashicups" {
#   name            = "url-map-hashicups"
#   # provider        = google-beta
#   default_service = google_compute_region_backend_service.default.id
# }





# resource "google_compute_region_instance_group_manager" "appserver" {
#   name = "appserver-igm"

#   base_instance_name         = "app"
#   region                     = var.region
#   # distribution_policy_zones  = ["us-central1-a", "us-central1-f"]

#   version {
#     instance_template = google_compute_instance_template.appserver.id
#   }

#   all_instances_config {
#     metadata = {
#       metadata_key = "metadata_value"
#     }
#     labels = {
#       node = "my_node_-"
#     }
#   }

#   # target_pools = [google_compute_target_pool.appserver.id]
#   target_size  = var.numnodes

#   named_port {
#     name = "consul"
#     port = 8500
#   }
#   named_port {
#     name = "consul-sec"
#     port = 8501
#   }
#   named_port {
#     name = "consul-grpc"
#     port = 8502
#   }
#   named_port {
#     name = "consul-lan"
#     port = 8301
#   }
#   named_port {
#     name = "consul-wan"
#     port = 8302
#   }
#   named_port {
#     name = "consul-server"
#     port = 8300
#   }
#   named_port {
#     name = "nomad-server"
#     port = 4646
#   }
#   named_port {
#     name = "nomad-rpc"
#     port = 4647
#   }
#   named_port {
#     name = "nomad-wan"
#     port = 4648
#   }

#   auto_healing_policies {
#     health_check      = google_compute_health_check.autohealing.id
#     initial_delay_sec = 300
#   }
# }

# resource "google_compute_region_instance_group_manager" "rigm" {
#   name = "dc-igm"

#   base_instance_name = "consul-server"
#   region = var.gcp_region
#   distribution_policy_zones = local.zones

#   version {
#     instance_template = google_compute_instance_template.instance_template.id
#   }

#   # target_pools = [google_compute_target_pool.pool.id]
#   target_size  = var.numnodes

#   wait_for_instances = true

#   update_policy {
#     type                         = "OPPORTUNISTIC"
#     instance_redistribution_type = "NONE"
#     minimal_action               = "REPLACE"
#     max_surge_fixed = 0
#     max_unavailable_fixed = length(data.google_compute_zones.available)
#   }
#   named_port {
#     name = "consul"
#     port = 8500
#   }
#   named_port {
#     name = "consul-sec"
#     port = 8501
#   }
#   named_port {
#     name = "grpc"
#     port = 8502
#   }
#   named_port {
#     name = "lan"
#     port = 8301
#   }
#   named_port {
#     name = "wan"
#     port = 8302
#   }
#   named_port {
#     name = "server"
#     port = 8300
#   }
#   # # If want to implement autohealing for the instances in the group
#   # auto_healing_policies {
#   #   health_check      = google_compute_health_check.https_health_check.id
#   #   initial_delay_sec = 300
#   # }
#   stateful_disk {
#     device_name = "consul-${var.cluster_name}"
#   }
# }


# Observability additions



