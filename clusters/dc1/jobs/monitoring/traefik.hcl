job "traefik" {
  region      = "global"
  datacenters = ["*"]
  type = "service"

  group "traefik" {
    count = 1



    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.0"
        network_mode = "host"
        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--entrypoints.web.address=:80",
          "--entrypoints.traefik.address=:8080",
          "--providers.consul.endpoints=127.0.0.1:8500",
          "--ping=true"
        ]
      }

      service {
        name = "traefik"
        tags = ["loadbalancer", "proxy"]
        port = 80
        address_mode = "driver"

        check {
          name     = "alive"
          type     = "http"
          port     = 8080
          path     = "/ping"
          interval = "10s"
          timeout  = "2s"
          address_mode = "driver"
        }
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}