variable "datacenter" {
  description = "The datacenter to deploy to"
  type        = string
  default     = "gcp-dc1"
}

job "prometheus" {
  region      = "global"
  datacenters = [var.datacenter]
  type        = "service"

  group "monitoring" {
    count = 1

    network {
      mode = "bridge"
      port "prometheus_ui" {
        static = 9090
        to = 9090
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size = 300
    }

    service {
      name = "prometheus"
      tags = ["monitoring", "metrics"]
      port = "prometheus_ui"

      check {
        name     = "prometheus_ui port alive"
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "2s"
      }

      connect {
        sidecar_service {}
      }
    }

    task "prometheus" {
      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"

        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

scrape_configs:

  - job_name: 'nomad-servers'
    static_configs:
    - targets: ['{{ env "NOMAD_IP_prometheus_ui" }}:4646']
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    scrape_interval: 10s

  - job_name: 'nomad-clients'
    static_configs: 
    - targets: ['{{ env "NOMAD_IP_prometheus_ui" }}:4646']
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    scrape_interval: 10s

  - job_name: 'consul'
    static_configs:
    - targets: ['{{ env "NOMAD_IP_prometheus_ui" }}:8500']
    metrics_path: /v1/agent/metrics
    params:
      format: ['prometheus']
    scrape_interval: 10s
EOH
      }

      driver = "docker"

      config {
        image = "prom/prometheus:latest"

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]

        ports = ["prometheus_ui"]
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }
  }
}