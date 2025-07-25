variable "datacenter" {
  description = "The datacenter to deploy the mesh gateway in."
  default = "dc1"
}

locals {
  # The datacenter to deploy the mesh gateway in. This is because the GCP network used is called "<datacenter>-network".
  wan_attribute = "$${attr.unique.platform.gce.network.${var.datacenter}-network.external-ip.0}"
}

job "mesh-gateway" {
  datacenters = [var.datacenter]

  group "mesh-gateway-one" {
    network {
      # mode = "bridge"
      mode = "host"

      # A mesh gateway will require a host_network configured on at least one
      # Nomad client that can establish cross-datacenter connections. Nomad will
      # automatically schedule the mesh gateway task on compatible Nomad clients.
      port "mesh_wan" {
        host_network = "default"
        static = 8443
        to    = 8443
      }
    }

    service {
      name = "mesh-gateway"

      # The mesh gateway connect service should be configured to use a port from
      # the host_network capable of cross-datacenter connections.
      port = "mesh_wan"
      # address = "${attr.unique.platform.gce.network.dcanadillas-network.external-ip.0}"
      tagged_addresses {
        # wan_ipv4 = "${attr.unique.platform.gce.network.dcanadillas-network.external-ip.0}"
        # wan = "${attr.unique.platform.gce.network.dcanadillas-network.external-ip.0}"
        wan_ipv4 = "${local.wan_attribute}"
        # wan = "${local.wan_attribute}"
      }

      connect {
        gateway {
          mesh {
            # No configuration options in the mesh block.
          }

          # Consul gateway [envoy] proxy options.
          proxy {
            # envoy_gateway_no_default_bind = true
            envoy_gateway_bind_tagged_addresses = true
            # envoy_gateway_bind_addresses "lan_ipv4" {
            #   address = "0.0.0.0"
            #   port    = 8443
            # }
            # envoy_gateway_bind_addresses "wan" {
            #   address = "${attr.unique.platform.gce.network.dcanadillas-network.external-ip.0}"
            #   port    = 8443
            # }
            # Additional options are documented at
            # https://developer.hashicorp.com/nomad/docs/job-specification/gateway#proxy-parameters
          }
        }
      }
    }
  }


}
