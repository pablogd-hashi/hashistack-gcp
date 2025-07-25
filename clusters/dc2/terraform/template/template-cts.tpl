#!/bin/bash

CONSUL_DIR="/etc/consul.d"

NODE_HOSTNAME=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/hostname)
PUBLIC_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
PRIVATE_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
DC="${dc_name}"
CONSUL_LICENSE="${consul_license}"

# ---- Adding some extra packages for CTS ----
curl --fail --silent --show-error --location https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo dd of=/usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
 sudo tee -a /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update

sudo apt-get install consul-terraform-sync-enterprise jq -y 





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
sudo mkdir -p /opt/consul/audit


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

tls {
   defaults {
      ca_file = "$CONSUL_DIR/tls/consul-agent-ca.pem"

      verify_incoming = false
      verify_outgoing = true
   }
   internal_rpc {
      verify_server_hostname = false
   }
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


client_addr = "0.0.0.0"
bind_addr = "$PRIVATE_IP"

ports {
  https = 8501
  grpc = 8502
  grpc_tls = 8503
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
echo "==> Changing permissions for Consul"
sudo chown -R consul:consul "$CONSUL_DIR"/tls
sudo chown -R consul:consul /tmp/consul/audit


# ---------------



# ----- CTS CONFIG --------

# CTS NIA config
sudo useradd --system --home /etc/consul-nia.d --shell /bin/false consul-nia
sudo mkdir -p /opt/consul-nia && sudo mkdir -p /etc/consul-nia.d

echo "==> Changing permissions for Consul Terraform Sync"
sudo chown --recursive consul-nia:consul-nia /opt/consul-nia && \
  sudo chmod -R 0750 /opt/consul-nia && \
  sudo chown --recursive consul-nia:consul-nia /etc/consul-nia.d && \
  sudo chmod -R 0750 /etc/consul-nia.d

echo "==> Creating the CTS service"
sudo tee /usr/lib/systemd/system/consul-terraform-sync.service > /dev/null <<EOF
[Unit]
Description="HashiCorp Consul-Terraform-Sync - A Network Infrastructure Automation solution"
Documentation=https://www.consul.io/docs/nia
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul-nia.d/config.hcl

[Service]
# EnvironmentFile=/etc/consul-nia.d/consul-nia.env
User=consul-nia
Group=consul-nia
ExecStart=/usr/bin/consul-terraform-sync start -config-dir=/etc/consul-nia.d/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

EOF


echo "==> Creating the CTS config file"
sudo tee /etc/consul-nia.d/config.hcl > /dev/null <<EOF
log_level   = "INFO"
working_dir = "/opt/consul-nia"
port        = 8558

syslog {
  enabled = "true"
  facility = "local0"
  name = "consul-terraform-sync"

}

buffer_period {
  enabled = true
  min     = "5s"
  max     = "20s"
}

vault {
  token = ""
  address = "https://vault-cluster-dev.vault.b2183a96-0a11-442f-a42a-e7234b964a27.aws.hashicorp.cloud:8200"
  namespace = ""
}

consul {
  address = "localhost:8500"
  token = "${bootstrap_token}"
}

# driver "terraform" {
#   # version = "0.14.0"
#   path = "/opt/consul-nia"
#   log         = false
#   persist_log = false
#
#   backend "consul" {
#     gzip = true
#   }
# }

driver "terraform-cloud" {
  hostname     = "https://app.terraform.io"
  organization = "hc-dcanadillas"
  # token = "{{ with secret \"terraform/creds/cts-new-demo\" }}{{ .Data.token }}{{ end }}"
  token = "${tfc_token}"
  # Optionally set the token to be securely queried from Vault instead of
  # written directly to the configuration file.
  # token = "{{ with secret \"secret/my/path\" }}{{ .Data.data.foo }}{{ end }}"
}

# task {
#  name        = "cts-demo"
#  description = "Example task with one service services"
#  module      = "findkim/print/cts"
#  # module = "app.terraform.io/hc-dcanadillas/vm/aws"
#  # version = "0.1.5"
#  version     = "0.1.0"
#  condition "services" {
#   names = ["frontend"]
#  }
# }

# task {
#   name        = "cts-backend"
#   description = "Example task with backend services"
#   module      = "mkam/hello/cts"
#   version     = "0.1.0"
#   condition "services" {
#     names = ["backend"]
#   }
# }

terraform_provider "aws" {
  region = "eu-west-1"
  task_env {
    # AWS_ACCESS_KEY_ID = "{{ with secret \"cts/static_aws\" }}{{ .Data.data.AWS_ACCESS_KEY }}{{ end }}"
    # AWS_SECRET_ACCESS_KEY = "{{ with secret \"cts/static_aws\" }}{{ .Data.data.AWS_SECRET_ACCESS_KEY }}{{ end }}"
    # AWS_SESSION_TOKEN = "{{ with secret \"cts/static_aws\" }}{{ .Data.data.AWS_SESSION_TOKEN }}{{ end }}"
    # AWS_SESSION_EXPIRATION = "{{ with secret \"cts/static_aws\" }}{{ .Data.data.AWS_SESSION_EXPIRATION }}{{ end }}"
  }

}

task {
 name        = "cts-aws"
 description = "Example task with one service services"
 module = "app.terraform.io/hc-dcanadillas/aws-sg/cts"
 version = "0.0.4"
 providers = ["aws"]
 condition "services" {
  names = ["frontend"]
 }
 terraform_cloud_workspace {
    execution_mode = "agent"
    # execution_mode = "agent"
    # agent_pool_id = "apool-6YdmXKtaBjmXkRXz"
    agent_pool_name = "AgentWorkshop"
  }
}
EOF

# ---------------

# INIT SERVICES

echo "==> Starting Consul..."
sudo systemctl start consul
