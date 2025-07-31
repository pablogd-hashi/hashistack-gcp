variable "datacenter" {
  description = "The datacenter to deploy to"
  type        = string
  default     = "gcp-dc1"
}

job "traefik" {
  region      = "global"
  datacenters = [var.datacenter]
  type = "service"

  group "traefik" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        static = 80
        to = 80
      }
      port "api" {
        static = 8080
        to = 8080
      }
    }

    service {
      name = "traefik"
      tags = ["loadbalancer", "proxy"]
      port = "http"

      check {
        name     = "alive"
        type     = "http"
        port     = "api"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "grafana"
              local_bind_port  = 3001
            }
            upstreams {
              destination_name = "prometheus"
              local_bind_port  = 9091
            }
          }
        }
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "traefik:v3.0"
        ports = ["http", "api"]
        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--entrypoints.web.address=:80",
          "--entrypoints.traefik.address=:8080",
          "--providers.consul.endpoints=127.0.0.1:8500",
          "--ping=true"
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}