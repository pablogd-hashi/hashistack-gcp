# Create Consul Admin Partitions different than default
# The Consul provider will automatically retry until the service is available
resource "consul_admin_partition" "demo_partitions" {
  depends_on = [ 
    google_compute_region_instance_group_manager.hashi-group,
    google_compute_region_per_instance_config.with_script 
  ]
  count       = var.consul_partitions != [] ? length(var.consul_partitions) : 0
  name        = var.consul_partitions[count.index]
  description = "Demo partition named \"${var.consul_partitions[count.index]}\""
}