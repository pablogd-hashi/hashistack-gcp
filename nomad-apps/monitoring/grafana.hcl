variable "datacenter" {
  description = "The datacenter to deploy to"
  type        = string
  default     = "gcp-dc1"
}

job "grafana" {
  region      = "global"
  datacenters = [var.datacenter]
  type = "service"

  group "grafana" {
    count = 1

    network {
      mode = "bridge"
      port "grafana_ui" {
        static = 3000
        to = 3000
      }
    }

    service {
      name = "grafana"
      tags = ["monitoring", "dashboard"]
      port = "grafana_ui"
      address_mode = "host"

      check {
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "3s"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "prometheus"
              local_bind_port  = 9090
            }
          }
        }
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["grafana_ui"]
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