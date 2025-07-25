variable "consul_domain" {
  description = "The consul domain for DNS. This is usually .consul in most configurations. Do not include the dot (.) in the value, just the name."
  default = "global"
}

variable "datacenter" {
  type = string
  default = "dc1"
}
job "terramino" {
  type = "service"

  spread {
    attribute = "${node.datacenter}"
  }

  group "terramino-redis" {
    count = 1
    network {
      mode = "bridge"
      port "redis" {
        static = 6379
      }
    }

    service {
      name     = "terramino-redis"
      port     = "redis"
      provider = "consul"



      check {
        name      = "Redis ready"
        type      = "script"
        command   = "/usr/local/bin/redis-cli"
        args      = ["ping"]
        interval  = "5s"
        timeout   = "2s"
        on_update = "ignore_warnings"
        task      = "terramino-redis-task"
      }

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          } 
        }
      }
    }

    task "terramino-redis-task" {
      driver = "docker"

      config {
        image = "redis:alpine"
        ports = ["redis"]
      }
    }
  }

  group "terramino-backend" {
    count = 1
    network {
      mode = "bridge"
      port "backend" {
        static = 8100
      }
      
    }

    service {
      name     = "terramino-backend"
      port     = "backend"
      provider = "consul"

      check {
        type = "http"
        name = "terramino backend Health"
        path = "/"
        interval = "20s"
        timeout = "5s"
      }

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          } 
        }
      }
    }

    task "terramino-backend-task" {
      driver = "docker"

      config {
        image = "_TERRAMINO_BACKEND_IMAGE"
        ports = ["backend"]
      }
      env {
        REDIS_HOST = "terramino-redis.service.dc1.${var.consul_domain}"
        REDIS_PORT = 6379
        TERRAMINO_PORT = 8100
      }
    }
  }

  group "terramino-frontend" {
    count = 1
    network {
      mode = "bridge"
      port "frontend" {
        static = 8101
        to = 8200
      }
      
    }

    service {
      name     = "terramino-frontend"
      port     = "frontend"
      provider = "consul"

      check {
        type = "http"
        name = "terramino frontend Health"
        path = "/health"
        interval = "20s"
        timeout = "5s"
      }

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          } 
        }
      }
    }

    task "terramino-frontend-task" {
      driver = "docker"

      config {
        image = "_TERRAMINO_FRONTEND_IMAGE"
        ports = ["frontend"]
        mount {
          type   = "bind"
          source = "local/default.conf"
          target = "/etc/nginx/conf.d/default.conf"
        }
      }
      template {
        data        = <<EOF
          server {
            listen 8200;
            server_name {{ env "NOMAD_IP_frontend" }};

            # Add a health check endpoint that always returns OK
            location /health {
                access_log off;
                add_header Content-Type application/json;
                return 200 '{"status":"OK"}';
            }

            location / {
                root /usr/share/nginx/html;
                index index.html;
                try_files $uri $uri/ /index.html;
            }

            # Combined location block for all backend endpoints
            location ~ ^/(redis|score|info|env) {
                proxy_pass http://terramino-backend.service.dc1.${var.consul_domain}:8100;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_connect_timeout 1s;  # Add one second timeouts (no timeout)
                proxy_read_timeout 1s;
                proxy_send_timeout 1s;
                proxy_intercept_errors on;
                error_page 502 503 504 = @backend_down;
            }

            location @backend_down {
                default_type application/json;
                return 503 'SVC_DOWN';
            }
        } 
        EOF
        destination = "local/default.conf"
      }
    }
  }
}