variable "front_version" {
  type = string
  default = "v0.26.2"
}

variable "datacenter" {
  type = string
  default = "dc1"
}

job "front-service" {
  datacenters = [var.datacenter]

  group "frontend" {
    network {
      mode = "bridge"
      port "http" {
        static = 8081
        to = 8081
      }
    }
    service {
      name = "front-service"
      tags = ["web","frontend"]
      port = 8081
      # # For TProxy and Consul Connect we need to use the port and address of the Allocation
      # address_mode = "alloc"
    
      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
            # upstreams {
            #   destination_name = "external-nginx"
            #   local_bind_port = 8080
            #   mesh_gateway {
            #     mode = "local"
            #   }
            # }
          } 
        }
      }
    }

    task "web" {
      driver = "docker"

      config {
        image          = "nicholasjackson/fake-service:${var.front_version}"
        ports          = ["http"]
      }

      # identity {
      #   env  = true
      #   file = true
      # }

      # resources {
      #   cpu    = 500
      #   memory = 256
      # }
      env {
        PORT = "8081"
        LISTEN_ADDR = "0.0.0.0:8081"
        MESSAGE = "Hello World fron Frontend V1 @${NOMAD_DC}"
        NAME = "web"
        UPSTREAM_URIS = "http://public-api.virtual.consul:9090,http://private-api.virtual.consul:9090,http://private-api.virtual.gcp-dc2-default.peer.consul:9090"
      }
    }
  }
}
