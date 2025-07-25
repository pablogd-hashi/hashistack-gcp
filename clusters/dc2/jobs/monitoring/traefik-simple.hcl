job "traefik" {
  region      = "global"
  datacenters = ["*"]
  type = "service"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 80
      }
      port "api" {
        static = 8080
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
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.0"
        network_mode = "host"
        ports        = ["http", "api"]
        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--entrypoints.web.address=:80",
          "--entrypoints.traefik.address=:8080",
          "--providers.consul.endpoints=127.0.0.1:8500",
          "--providers.consul.watch=true",
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