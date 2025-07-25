variable "back_version" {
  type = string
  default = "v0.26.2"
}
variable "datacenter" {
  type = string
  default = "dc1"
}
variable "replicas_private" {
  type = number
  default = 2
}
variable "replicas_public" {
  type = number
  default = 2
}

job "backend-services" {
  datacenters = [var.datacenter]
  group "public" {
    count = var.replicas_public
    network {
      mode = "bridge"
      port "public-api" {
        static = 8082
        to = 9090
      }
    }
    service {
      name = "public-api"
      tags = ["api","public"]
      port = "public-api"
      # For TProxy and Consul Connect we need to use the port and address of the Allocation when using port names
      address_mode = "alloc"

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          } 
        }
      }
    }

    task "public-api" {
      driver = "docker"

      config {
        image          = "nicholasjackson/fake-service:${var.back_version}"
      }

      env {
        PORT = "${NOMAD_PORT_public-api}"
        LISTEN_ADDR = "0.0.0.0:9090"
        MESSAGE = "Hello World from Public API @${NOMAD_DC}"
        NAME = "Public_API@${NOMAD_DC}"
      }
    }
  }
  group "private" {
    count = var.replicas_private
    network {
      mode = "bridge"
      port "private-api" {
        static = 8083
        to = 9090
      }
      # port "connect-proxy-private-api" {
      #   static = 25000
      # }
    }
    service {
      name = "private-api"
      tags = ["api","private"]
      port = "private-api"
      # For TProxy and Consul Connect we need to use the port and address of the Allocation when using port names
      address_mode = "alloc"

      connect {
        sidecar_service {
          # port = "connect-proxy-private-api"
          proxy {
            transparent_proxy {}
          } 
        }
      }
    }

    task "private-api" {
      driver = "docker"

    
      config {
        image          = "nicholasjackson/fake-service:${var.back_version}"
        ports          = ["private-api"]
      }

      # identity {
      #   env  = true
      #   file = true
      # }

      env {
        PORT = "9090"
        LISTEN_ADDR = "0.0.0.0:9090"
        MESSAGE = "Hello World from Private API @${NOMAD_DC}"
        NAME = "Private_API@${NOMAD_DC}"
      }
    }
  }
}
