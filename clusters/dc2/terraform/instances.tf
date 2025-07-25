# Creating Nomad Bootstrap token
resource "random_uuid" "nomad_bootstrap" {
}

locals {
  # We concatenate the default partition with the list of partitions to create the instances including the default partition
  admin_partitions = distinct(concat(["default"], var.consul_partitions))
  vm_image         = data.google_compute_image.my_image.self_link # HCP Packer disabled for now
  fqdn             = var.dns_zone != "" ? "${trimsuffix(google_dns_record_set.dns[0].name, ".")}" : "${google_compute_address.server_addr[0].address}"

}
# Let's get the zones from the region
data "google_compute_zones" "available" {
  region = var.gcp_region
}
# data "google_compute_zones" "available" {}


# Creating the instance template to be use from instances
resource "google_compute_instance_template" "instance_template" {
  # count = var.numnodes
  name_prefix  = "hashistack-servers-"
  machine_type = var.gcp_instance
  region       = var.gcp_region

  tags = [var.cluster_name, var.owner, "nomad-${var.cluster_name}", "consul-${var.cluster_name}"]

  // boot disk
  disk {
    source_image = local.vm_image
    device_name  = "consul-${var.cluster_name}"
    # source = google_compute_region_disk.vault_disk.name
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link

    access_config {
      # nat_ip = google_compute_address.server_addr.address
    }
  }
  service_account {
    email  = data.google_service_account.owner_project.email
    scopes = ["cloud-platform", "compute-rw", "compute-ro", "userinfo-email", "storage-ro"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_template" "instance_template_clients" {
  # Let's create a count, so we create a template for each consul partition, and use only one if consul_partitions is empty
  count = length(var.consul_partitions) != 0 ? length(var.consul_partitions) : 1

  name_prefix  = "hashistack-clients-${length(var.consul_partitions) != 0 ? var.consul_partitions[count.index] : "default"}-"
  machine_type = var.gcp_instance
  region       = var.gcp_region

  tags = [var.cluster_name, var.owner, "nomad-${var.cluster_name}", "consul-${var.cluster_name}"]

  // boot disk
  disk {
    source_image = local.vm_image
    device_name  = "consul-${var.cluster_name}"
    # source = google_compute_region_disk.vault_disk.name
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link

    access_config {
      # nat_ip = google_compute_address.server_addr.address
    }
  }
  service_account {
    email  = data.google_service_account.owner_project.email
    scopes = ["cloud-platform", "compute-rw", "compute-ro", "userinfo-email", "storage-ro"]
  }

  metadata_startup_script = templatefile("${path.module}/template/template-client.tpl", {
    dc_name         = var.cluster_name,
    gcp_project     = var.gcp_project,
    tag             = var.cluster_name,
    consul_license  = var.consul_license,
    nomad_license   = var.nomad_license,
    bootstrap_token = var.consul_bootstrap_token,
    zone            = var.gcp_region,
    node_name       = "clients-${count.index}",
    partition       = var.consul_partitions != [""] ? element(local.admin_partitions, count.index) : "default"
  })
  labels = {
    node = "client-${count.index}"
  }


  lifecycle {
    create_before_destroy = true
  }
}



# This is the instance template for a node that will be used for Consul Terraform Sync if we deploy it
resource "google_compute_instance_from_template" "vm_cts" {
  count = var.enable_cts ? 1 : 0

  name = "vm-cts-${random_id.server.dec}"
  # zone = var.gcp_zone
  zone = element(var.gcp_zones, count.index)

  source_instance_template = google_compute_instance_template.instance_template_clients[0].id

  // Override fields from instance template
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link
    access_config {}
  }

  # The template used is just an own demo example that won't work by default, but it is just to show how to use the template
  metadata_startup_script = templatefile("${path.module}/template/template-cts.tpl", {
    dc_name         = var.cluster_name,
    gcp_project     = var.gcp_project,
    tag             = var.cluster_name,
    consul_license  = var.consul_license,
    bootstrap_token = var.consul_bootstrap_token,
    node_name       = "client-cts",
    tfc_token       = var.tfc_token,
    zone            = var.gcp_region
  })

  labels = {
    node = "client-cts"
  }
  # lifecycle {
  #   create_before_destroy = true
  # }
}


# Create the instance group from the vms in a region
# Create instance group for the region
resource "google_compute_region_instance_group_manager" "hashi-group" {
  depends_on = [
    google_compute_instance_template.instance_template
  ]
  name = "${var.cluster_name}-server-igm"

  base_instance_name        = "hashi-server"
  region                    = var.gcp_region
  distribution_policy_zones = slice(data.google_compute_zones.available.names, 0, min(3, length(data.google_compute_zones.available.names)))

  version {
    instance_template = google_compute_instance_template.instance_template.self_link
  }

  all_instances_config {
    metadata = {
      component = "server"
    }
    labels = {
      mesh      = "consul"
      scheduler = "nomad"
    }
  }

  stateful_disk {
    device_name = "consul-${var.cluster_name}"
    delete_rule = "ON_PERMANENT_INSTANCE_DELETION"
  }

  update_policy {
    type = "OPPORTUNISTIC"
    # type = "PROACTIVE"
    minimal_action               = "REPLACE"
    instance_redistribution_type = "NONE"
    # replacement_method           = "RECREATE"
    max_surge_fixed = 0
    # Fixed updatePolicy.maxUnavailable for regional managed instance group has to be either 0 or at least equal to the number of zones in the region.
    max_unavailable_fixed = max(length(data.google_compute_zones.available.names), floor(var.numnodes / 2))
  }


  # target_pools = [google_compute_target_pool.appserver.id]
  # target_size  = var.numnodes

  named_port {
    name = "consul"
    port = 8500
  }
  named_port {
    name = "consul-sec"
    port = 8501
  }
  named_port {
    name = "consul-grpc"
    port = 8502
  }
  named_port {
    name = "consul-lan"
    port = 8301
  }
  named_port {
    name = "consul-wan"
    port = 8302
  }
  named_port {
    name = "consul-server"
    port = 8300
  }
  named_port {
    name = "nomad-server"
    port = 4646
  }
  named_port {
    name = "nomad-rpc"
    port = 4647
  }
  named_port {
    name = "nomad-wan"
    port = 4648
  }

  # auto_healing_policies {
  #   health_check      = google_compute_region_health_check.default.self_link
  #   initial_delay_sec = 10
  # }
}


# We do a stateful address for the instances, so the execution script on each instance is not the sam
resource "google_compute_region_per_instance_config" "with_script" {
  count = var.numnodes

  region                        = google_compute_region_instance_group_manager.hashi-group.region
  region_instance_group_manager = google_compute_region_instance_group_manager.hashi-group.name
  name                          = "hashi-server-${count.index}-${random_id.server.dec}"
  preserved_state {
    # internal_ip {
    #   interface_name = "nic0"
    #   ip_address {
    #     address = google_compute_address.server_addr[count.index].id
    #   }
    # }
    metadata = {
      startup-script = templatefile("${path.module}/template/template.tpl", {
        dc_name            = var.cluster_name,
        gcp_project        = var.gcp_project,
        tag                = var.cluster_name,
        consul_license     = var.consul_license,
        nomad_license      = var.nomad_license,
        zone               = var.gcp_region,
        bootstrap_token    = var.consul_bootstrap_token,
        node_name          = "server-${count.index}",
        nomad_token        = random_uuid.nomad_bootstrap.result,
        nomad_bootstrapper = count.index == var.numnodes - 1 ? true : false
      })
      instance_template = google_compute_instance_template.instance_template.self_link
    }
  }
}



# Creating an instance group region for the clients
resource "google_compute_region_instance_group_manager" "clients-group" {
  # We create an instance group for the clients, so we can use the same instance template for all the instances. And we create a groupt per partition.
  depends_on = [
    google_compute_instance_template.instance_template_clients
  ]
  count                     = length(var.consul_partitions) != 0 ? length(var.consul_partitions) : 1
  name                      = "${var.cluster_name}-clients-igm-${count.index}"
  base_instance_name        = length(var.consul_partitions) != 0 ? "hashi-clients-${var.consul_partitions[count.index]}" : "hashi-clients"
  region                    = var.gcp_region
  distribution_policy_zones = slice(data.google_compute_zones.available.names, 0, min(3, length(data.google_compute_zones.available.names)))

  version {
    instance_template = google_compute_instance_template.instance_template_clients[count.index].self_link
  }

  all_instances_config {
    metadata = {
      component = "client"
    }
    labels = {
      mesh      = "consul"
      scheduler = "nomad"
    }
  }

  update_policy {
    # type  = "OPPORTUNISTIC"
    type                         = "PROACTIVE"
    minimal_action               = "REPLACE"
    instance_redistribution_type = "NONE"
    # max_surge_fixed = 0
    # # Fixed updatePolicy.maxUnavailable for regional managed instance group has to be either 0 or at least equal to the number of zones in the region.
    # max_unavailable_fixed = max(length(data.google_compute_zones.available.names),floor(var.numclients / 2))
    max_surge_fixed       = length(data.google_compute_zones.available.names)
    max_unavailable_fixed = 0
  }

  target_size = var.numclients
  named_port {
    name = "frontend"
    port = 8080
  }
}



# ---------------------------------------------------- #
# ############## OLD CONFIGURATION ######################
# This is the old configuration, we are not using it anymore
# In this old configuration we weren't using the instance group manager, and we were creating the instances from the template.
# Saving this for future reference, in case we need to use it again.
# ---------------------------------------------------- #

# resource "google_compute_instance_from_template" "vm_server" {
#   count = var.numnodes
#   name = "vm-server-${count.index}-${random_id.server.dec}"
#   # zone = var.gcp_zone
#   zone = element(var.gcp_zones, count.index)

#   source_instance_template = google_compute_instance_template.instance_template.id

#   // Override fields from instance template
#   network_interface {
#     subnetwork = google_compute_subnetwork.subnet.self_link
#     access_config {
#         nat_ip = google_compute_address.server_addr[count.index].address
#     }
#   }
#   metadata_startup_script = templatefile("${path.module}/template/template.tpl",{
#     dc_name = var.cluster_name,
#     gcp_project = var.gcp_project,
#     tag = var.cluster_name,
#     consul_license = var.consul_license,
#     nomad_license = var.nomad_license,
#     zone = var.gcp_region,
#     bootstrap_token = var.consul_bootstrap_token,
#     node_name = "server-${count.index}",
#     nomad_token = random_uuid.nomad_bootstrap.result,
#     nomad_bootstrapper = count.index == var.numnodes - 1 ? true : false
#   })

#   labels = {
#     node = "server-${count.index}"
#   }
#   # lifecycle {
#   #   create_before_destroy = true
#   # }
# }



# resource "google_compute_instance_from_template" "vm_clients" {
#   depends_on = [ consul_admin_partition.demo_partitions ]
#   count = var.numclients
#   name = "vm-clients-${count.index}-${random_id.server.dec}"
#   # zone = var.gcp_zone
#   zone = element(var.gcp_zones, count.index)

#   source_instance_template = google_compute_instance_template.instance_template_clients.id

#   // Override fields from instance template
#   network_interface {
#     subnetwork = google_compute_subnetwork.subnet.self_link
#     access_config {
#         nat_ip = google_compute_address.client_addr[count.index].address
#     }
#   }

#   metadata_startup_script = templatefile("${path.module}/template/template-client.tpl",{
#     dc_name = var.cluster_name,
#     gcp_project = var.gcp_project,
#     tag = var.cluster_name,
#     consul_license = var.consul_license,
#     nomad_license = var.nomad_license,
#     bootstrap_token = var.consul_bootstrap_token,
#     zone = var.gcp_region,
#     node_name = "client-${count.index}"
#     partition = var.consul_partitions != [""] ? element(local.admin_partitions,count.index) : "default"
#   })

#   labels = {
#     node = "client-${count.index}"
#   }
#   # lifecycle {
#   #   create_before_destroy = true
#   # }
# }


# # Create an instance group from the vms
# resource "google_compute_instance_group" "hashi_group" {
#   depends_on = [
#     google_compute_instance_template.instance_template,
#     google_compute_instance_template.instance_template_clients
#   ]
#   name      = "${var.cluster_name}-instance-group"
#   zone      = var.gcp_zone
#   instances = google_compute_instance_from_template.vm_server.*.self_link
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

#   # lifecycle {
#   #   create_before_destroy = true
#   # }
# }



# # Creating an instance group per zone, as the instances can be spread across zones.
# # We are not using the instance group manager as we could not be using the same instance template for all the instances.
# resource "google_compute_instance_group" "app_group" {
#   depends_on = [
#     # google_compute_instance_template.instance_template,
#     google_compute_instance_template.instance_template_clients
#   ]
#   count = length(distinct(var.gcp_zones))
#   name      = "${var.cluster_name}-instance-group-client"
#   zone      = element(var.gcp_zones, count.index)
#   # instances = google_compute_instance_from_template.vm_clients.*.self_link
#   instances = [
#     for instance in google_compute_instance_from_template.vm_clients :
#     instance.self_link if instance.zone == element(var.gcp_zones, count.index)
#   ]
#   named_port {
#     name = "frontend"
#     port = 8080
#   }
#   # lifecycle {
#   #   create_before_destroy = true
#   # }
# }
