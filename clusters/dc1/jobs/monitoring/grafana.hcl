job "grafana" {
  region      = "global"
  datacenters = ["*"]
  type = "service"

  group "grafana" {
    count = 1



    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        network_mode = "host"
        mount {
          type   = "bind"
          source = "local/prometheus-datasource.yml"
          target = "/etc/grafana/provisioning/datasources/prometheus.yml"
        }
        mount {
          type   = "bind"
          source = "local/dashboard-provider.yml"
          target = "/etc/grafana/provisioning/dashboards/dashboard-provider.yml"
        }
      }

      template {
        data = <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: false
    
  - name: Loki
    type: loki
    access: proxy
    url: http://loki.service.consul:3100
    editable: false
EOF
        destination = "local/prometheus-datasource.yml"
      }

      template {
        data = <<EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF
        destination = "local/dashboard-provider.yml"
      }



      service {
        name = "grafana"
        tags = [
          "monitoring", 
          "dashboard",
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=PathPrefix(`/grafana`)",
          "traefik.http.routers.grafana.entrypoints=web",
          "traefik.http.services.grafana.loadbalancer.server.port=3000"
        ]
        port = 3000
        address_mode = "driver"

        check {
          type     = "http"
          path     = "/api/health"
          interval = "10s"
          timeout  = "3s"
          address_mode = "driver"
        }
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD = "admin"
        GF_PATHS_PROVISIONING = "/etc/grafana/provisioning"
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }
  }
}