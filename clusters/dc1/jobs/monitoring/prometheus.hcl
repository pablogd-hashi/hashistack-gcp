job "prometheus" {
  region      = "global"
  datacenters = ["*"]
  type        = "service"

  group "monitoring" {
    count = 1



    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size = 300
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
    - targets: ['localhost:4646']
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    scrape_interval: 10s

  - job_name: 'nomad-clients'
    static_configs: 
    - targets: ['localhost:4646']
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    scrape_interval: 10s

  - job_name: 'consul-agent'
    static_configs:
    - targets: ['localhost:8500']
    metrics_path: /v1/agent/metrics
    params:
      format: ['prometheus']
    bearer_token: 'ConsulR0cks'
    scrape_interval: 10s

  - job_name: 'consul-services'
    consul_sd_configs:
    - server: 'localhost:8500'
      datacenter: 'gcp-dc1'
      token: 'ConsulR0cks'
    relabel_configs:
    - source_labels: [__meta_consul_tags]
      regex: .*,metrics,.*
      action: keep
    - source_labels: [__meta_consul_service]
      target_label: job
    - source_labels: [__meta_consul_service_address, __meta_consul_service_port]
      target_label: __address__
      separator: ':'
    - source_labels: [__meta_consul_service_id]
      target_label: instance
    - source_labels: [__meta_consul_datacenter]
      target_label: datacenter
    - source_labels: [__meta_consul_node]
      target_label: node
    scrape_interval: 10s

  - job_name: 'consul-connect-envoy'
    consul_sd_configs:
    - server: 'localhost:8500'
      datacenter: 'gcp-dc1'
      services: ['*-sidecar-proxy']
      token: 'ConsulR0cks'
    relabel_configs:
    - source_labels: [__meta_consul_service]
      regex: '(.*)-sidecar-proxy'
      target_label: service
      replacement: '${1}'
    - source_labels: [__meta_consul_service_address, __meta_consul_service_port]
      target_label: __address__
      separator: ':'
    - target_label: __metrics_path__
      replacement: /stats/prometheus
    - source_labels: [__meta_consul_service_id]
      target_label: instance
    scrape_interval: 15s
EOH
      }

      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        network_mode = "host"

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]

      }

      service {
        name = "prometheus"
        tags = ["monitoring", "metrics"]
        port = 9090
        address_mode = "driver"

        check {
          name     = "prometheus_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
          address_mode = "driver"
        }
      }


      resources {
        cpu    = 200
        memory = 512
      }
    }
  }
}