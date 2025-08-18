#!/bin/bash

CONSUL_DIR="/etc/consul.d"

NODE_HOSTNAME=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/hostname)
PUBLIC_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
PRIVATE_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
DC="${dc_name}"
CONSUL_LICENSE="${consul_license}"
NOMAD_LICENSE="${nomad_license}"
NOMAD_DIR="/etc/nomad.d"
NOMAD_URL="https://releases.hashicorp.com/nomad"
CNI_PLUGIN_VERSION="v1.5.1"


# ---- Check directories ----
if [ -d "$CONSUL_DIR" ];then
    echo "Consul configurations will be created in $CONSUL_DIR" >> /tmp/consul-log.out
else
    echo "Consul configurations directoy does not exist. Exiting..." >> /tmp/consul-log.out
    exit 1
fi

if [ -d "/opt/consul" ]; then
    echo "Consul data directory will be created at existing /opt/consul" >> /tmp/consul-log.out
else
    echo "/opt/consul does not exist. Check that VM image is the right one. Creating directory anyway..."
    sudo mkdir -p /opt/consul
    sudo chown -R consul:consul /opt/consul
fi

# Creating a directory for audit
sudo mkdir -p /tmp/consul/audit


# ---- Enterprise Licenses ----
echo $CONSUL_LICENSE | sudo tee $CONSUL_DIR/license.hclic > /dev/null
echo $NOMAD_LICENSE | sudo tee $NOMAD_DIR/license.hclic > /dev/null

# ---- Preparing certificates ----
echo "==> Adding server certificates to /etc/consul.d"
consul tls cert create -server -dc $DC \
    -ca "$CONSUL_DIR"/tls/consul-agent-ca.pem \
    -key  "$CONSUL_DIR"/tls/consul-agent-ca-key.pem
sudo mv "$DC"-server-consul-*.pem "$CONSUL_DIR"/tls/

# ----------------------------------
echo "==> Generating Consul configs"

sudo tee $CONSUL_DIR/consul.hcl > /dev/null <<EOF
datacenter = "$DC"
data_dir = "/opt/consul"
node_name = "${node_name}"
node_meta = {
  hostname = "$(hostname)"
  gcp_instance = "$(curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")"
  gcp_zone = "$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" | awk -F / '{print $NF}')"
}
encrypt = "$(cat $CONSUL_DIR/keygen.out)"
retry_join = ["provider=gce project_name=${gcp_project} tag_value=${tag} zone_pattern=\"${zone}-[a-z]\""]
license_path = "$CONSUL_DIR/license.hclic"
log_level = "TRACE"

tls {
   defaults {
      ca_file = "$CONSUL_DIR/tls/consul-agent-ca.pem"
      cert_file = "$CONSUL_DIR/tls/$DC-server-consul-0.pem"
      key_file = "/etc/consul.d/tls/$DC-server-consul-0-key.pem"
      verify_incoming = false
      verify_outgoing = true
      verify_server_hostname = false
   }
   internal_rpc {
      verify_server_hostname = true
   }
}


auto_encrypt {
  allow_tls = true
}

acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens = {
    initial_management = "${bootstrap_token}"
    agent = "${bootstrap_token}"
    dns = "${bootstrap_token}"
  }
}

audit {
  enabled = true
  sink "${dc_name}_sink" {
    type   = "file"
    format = "json"
    path   = "/opt/consul/audit/audit.json"
    delivery_guarantee = "best-effort"
    rotate_duration = "24h"
    rotate_max_files = 15
    rotate_bytes = 25165824
    mode = "644"
  }
}

reporting {
  license {
    enabled = false
  }
}


EOF

sudo tee $CONSUL_DIR/server.hcl > /dev/null <<EOF
server = true
bootstrap_expect = 3

# Service mesh configuration
# Note: Consul limits configuration moved to performance tuning section if needed

ui = true
client_addr = "0.0.0.0"
bind_addr = "{{ GetDefaultInterfaces | attr \"address\" }}"
advertise_addr_wan = "$PUBLIC_IP"

connect {
  enabled = true
}

ui_config {
  enabled = true
  metrics_provider = "prometheus"
  metrics_proxy {
    base_url = "http://localhost:9090"
  }
  dashboard_url_templates {
    service = "http://localhost:3000/d/lDlaj-NGz/service-overview?orgId=1&var-service={{Service.Name}}&var-namespace={{Service.Namespace}}&var-partition={{Service.Partition}}&var-dc={{Datacenter}}"
  }
}

ports {
  https = 8501
  grpc_tls = 8502
}


EOF

echo "==> Creating the Consul service"
sudo tee /usr/lib/systemd/system/consul.service > /dev/null <<EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$CONSUL_DIR/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/bin/consul agent -config-dir="$CONSUL_DIR"/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Let's set some permissions to read certificates from Consul
echo "==> Changing permissions"
sudo chown -R consul:consul "$CONSUL_DIR"/tls
sudo chown -R consul:consul /tmp/consul/audit

# ---------------

# ----- NOMAD CONFIG --------


# ---- Check directories ----
if [ -d "$NOMAD_DIR" ];then
    echo "Nomad configurations will be created in $NOMAD_DIR" >> /tmp/nomad-log.out
else
    echo "Nomad configurations directoy does not exist. Exiting..." >> /tmp/nomad-log.out
    exit 1
fi

if [ -d "/opt/nomad" ]; then
    echo "Consul data directory will be created at existing /opt/nomad" >> /tmp/nomad-log.out
else
    echo "/opt/nomad does not exist. Check that VM image is the right one. Creating directory anyway..."
    sudo mkdir -p /opt/nomad
    sudo chown -R nomad:nomad /opt/nomad
fi

# Installing CNI plugins
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGIN_VERSION/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-$CNI_PLUGIN_VERSION.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz


# ----------------------------------
echo "==> Generating Nomad configs"

sudo tee $NOMAD_DIR/nomad.hcl > /dev/null <<EOF
datacenter = "$DC"
data_dir = "/opt/nomad"
acl  {
  enabled = true
}
consul {
  token = "${bootstrap_token}"
  enabled = true

  service_identity {
    aud = ["consul.io"]
    ttl = "1h"
  }

  task_identity {
    aud = ["consul.io"]
    ttl = "1h"
  }
}
EOF

sudo tee $NOMAD_DIR/server.hcl > /dev/null <<EOF
server {
  enabled = true
  bootstrap_expect = 3
  server_join {
    retry_join = ["provider=gce project_name=${gcp_project} tag_value=${tag}"]
  }
  license_path = "$NOMAD_DIR/license.hclic"
}
EOF

sudo tee $NOMAD_DIR/client.hcl > /dev/null <<EOF
client {
  enabled = false
}
EOF

sudo tee $NOMAD_DIR/nomad_bootstrap > /dev/null <<EOF
${nomad_token}
EOF

echo "==> Creating the Nomad service"
sudo tee /usr/lib/systemd/system/nomad.service > /dev/null <<EOF
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

# When using Nomad with Consul it is not necessary to start Consul first. These
# lines start Consul before Nomad as an optimization to avoid Nomad logging
# that Consul is unavailable at startup.
#Wants=consul.service
#After=consul.service

[Service]

# Nomad server should be run as the nomad user. Nomad clients
# should be run as root
User=nomad
Group=nomad

ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/bin/nomad agent -config $NOMAD_DIR
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
Restart=on-failure
RestartSec=2

## Configure unit start rate limiting. Units which are started more than
## *burst* times within an *interval* time span are not permitted to start any
## more. Use `StartLimitIntervalSec` or `StartLimitInterval` (depending on
## systemd version) to configure the checking interval and `StartLimitBurst`
## to configure how many starts per interval are allowed. The values in the
## commented lines are defaults.

# StartLimitBurst = 5

## StartLimitIntervalSec is used for systemd versions >= 230
# StartLimitIntervalSec = 10s

## StartLimitInterval is used for systemd versions < 230
# StartLimitInterval = 10s

TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF


# Let's set some permissions to read certificates from Consul
echo "==> Changing permissions"
sudo chown -R nomad:nomad "$NOMAD_DIR"/tls


# INIT SERVICES

echo "==> Starting Consul..."
sudo systemctl start consul

echo "==> Starting Nomad..."
sudo systemctl start nomad



# We select the last node as the Nomad bootstrapper
%{ if nomad_bootstrapper }
# But wait for the Nomad leader to be elected
HTTP_STATUS=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:4646/v1/status/leader)
counter=0
while [ $HTTP_STATUS -ne 200 ]; do
  echo "==> Waiting for Nomad to start..."
  sleep 10
  HTTP_STATUS=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:4646/v1/status/leader)
  counter=$((counter+1))
  if [ $counter -eq 10 ]; then
    echo "==> Nomad failed to start. Exiting..."
    break
  fi
done
echo "==> Bootstrap Nomad..."
# sleep 20
nomad acl bootstrap $NOMAD_DIR/nomad_bootstrap
%{ endif }

