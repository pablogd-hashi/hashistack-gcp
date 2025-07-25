# Let's wait for the Consul server instances to be ready before we proceed with the rest of the configuration.
resource "null_resource" "wait_for_service" {
  depends_on = [
    google_compute_region_instance_group_manager.hashi-group,
    google_compute_region_per_instance_config.with_script      
  ]
  provisioner "local-exec" {
    command = <<EOF
echo "Waiting for Consul service to be ready..."
sleep 60
max_attempts=60
attempt=0
until $(curl -k --output /dev/null --silent --head --fail http://${trimsuffix(local.fqdn,".")}:8500); do
  printf '.'
  sleep 10
  attempt=$((attempt + 1))
  if [ $attempt -ge $max_attempts ]; then
    echo "Timeout waiting for Consul service at http://${trimsuffix(local.fqdn,".")}:8500"
    exit 1
  fi
done
echo "Consul service is ready!"
EOF
  }
}

# Create Consul Admin Partitions different than default
resource "consul_admin_partition" "demo_partitions" {
  depends_on = [ null_resource.wait_for_service ]
  count = var.consul_partitions != [] ? length(var.consul_partitions) : 0
  name        = var.consul_partitions[count.index]
  description = "Demo partition named \"${var.consul_partitions[count.index]}\""
}