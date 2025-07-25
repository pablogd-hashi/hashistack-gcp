job "loki" {
  region      = "global"
  datacenters = ["*"]
  type        = "service"

  group "loki" {
    count = 1

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size = 500
    }

    task "loki" {
      driver = "docker"
      leader = true

      template {
        change_mode = "noop"
        destination = "local/loki-config.yml"
        data = <<EOH
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s
  wal:
    enabled: true
    dir: /alloc/data/loki/wal

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /alloc/data/loki/index
  filesystem:
    directory: /alloc/data/loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  volume_enabled: true

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOH
      }

      config {
        image = "grafana/loki:2.9.0"
        ports = ["loki"]

        volumes = [
          "local/loki-config.yml:/etc/loki/local-config.yaml"
        ]

        args = [
          "-config.file=/etc/loki/local-config.yaml"
        ]
      }

      service {
        name = "loki"
        tags = ["logging", "loki"]
        port = 3100
        address_mode = "driver"

        check {
          name     = "loki alive"
          type     = "http"
          path     = "/ready"
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

    task "promtail" {
      driver = "docker"

      template {
        change_mode = "restart"
        destination = "local/promtail-config.yml"
        data = <<EOH
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  # Nomad/Consul system logs via syslog (accessible via host network)
  - job_name: syslog
    syslog:
      listen_address: 0.0.0.0:1514
      labels:
        job: syslog
        host: {{ env "NOMAD_NODE_NAME" }}
    relabel_configs:
      - source_labels: [__syslog_message_app_name]
        regex: '(consul|nomad)'
        action: keep
      - source_labels: [__syslog_message_app_name]
        target_label: 'service'
    pipeline_stages:
      - match:
          selector: '{service=~"(consul|nomad)"}'
          stages:
            - regex:
                expression: '\[(?P<level>\w+)\]\s+(?P<message>.*)'
            - labels:
                level:

  # Prometheus logs (co-located in same group)
  - job_name: local-prometheus
    static_configs:
      - targets:
          - localhost
        labels:
          job: prometheus-logs
          __path__: /alloc/logs/prometheus*.std*
    pipeline_stages:
      - regex:
          expression: 'level=(?P<level>\w+).*msg="(?P<message>[^"]*)"'
      - labels:
          level:

  # Grafana logs (co-located in same group)  
  - job_name: local-grafana
    static_configs:
      - targets:
          - localhost
        labels:
          job: grafana-logs
          __path__: /alloc/logs/grafana*.std*
    pipeline_stages:
      - regex:
          expression: 't=(?P<timestamp>[^\\s]+)\\s+lvl=(?P<level>\\w+)\\s+msg="(?P<message>[^"]*)"'
      - labels:
          level:
EOH
      }

      config {
        image = "grafana/promtail:2.9.0"
        network_mode = "host"
        
        volumes = [
          "local/promtail-config.yml:/etc/promtail/config.yml"
        ]

        args = [
          "-config.file=/etc/promtail/config.yml"
        ]
      }

      service {
        name = "promtail"
        tags = ["logging", "promtail"]
        port = 9080
        address_mode = "driver"

        check {
          name     = "promtail alive"
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
          address_mode = "driver"
        }
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }

    network {
      port "loki" {
        static = 3100
        to     = 3100
      }
      port "promtail" {
        static = 9080
        to     = 9080
      }
    }
  }
}