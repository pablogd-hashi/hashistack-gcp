job "node-exporter" {
  region      = "global"
  datacenters = ["*"]
  type        = "system"

  group "node-exporter" {
    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    network {
      port "node_exporter" {
        static = 9100
        to     = 9100
      }
    }

    service {
      name = "node-exporter"
      port = "node_exporter"
      
      tags = [
        "monitoring",
        "metrics",
        "node-exporter"
      ]

      check {
        name     = "Node Exporter"
        http     = "http://${NOMAD_ADDR_node_exporter}/metrics"
        interval = "10s"
        timeout  = "3s"
      }

      connect {
        sidecar_service {}
      }
    }

    task "node-exporter" {
      driver = "docker"

      config {
        image = "prom/node-exporter:latest"
        ports = ["node_exporter"]
        
        args = [
          "--path.procfs=/host/proc",
          "--path.sysfs=/host/sys",
          "--path.rootfs=/host/root",
          "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($|/)",
          "--collector.netdev.device-exclude=^lo$",
          "--collector.diskstats.ignored-devices=^(ram|loop|fd|(h|s|v)d[a-z]|nvme\\d+n\\d+p)\\d+$"
        ]

        mount {
          type     = "bind"
          source   = "/proc"
          target   = "/host/proc"
          readonly = true
        }

        mount {
          type     = "bind"
          source   = "/sys"
          target   = "/host/sys"
          readonly = true
        }

        mount {
          type     = "bind"
          source   = "/"
          target   = "/host/root"
          readonly = true
        }

        privileged = true
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}