variable "services" {
  description = "Services from Consul"
  type = map(object({
    id      = string
    name    = string
    address = string
    port    = number
    tags    = list(string)
  }))
}

# Generate firewall rules file that we can copy to HCP workspace
resource "local_file" "firewall_rules" {
  filename = "/tmp/firewall-rules.tf"
  content = templatefile("${path.module}/firewall-template.tftpl", {
    services = var.services
  })
  
  # Trigger push to HCP when file changes
  provisioner "local-exec" {
    command = "${path.module}/../push-to-hcp.sh"
  }
}

# Output the services for monitoring
output "detected_services" {
  value = {
    for name, service in var.services : name => {
      service_name = service.name
      port = service.port
      firewall_rule_name = "auto-${service.name}-${service.port}"
    }
  }
}