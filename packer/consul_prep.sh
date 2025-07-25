#! /bin/bash
env

export CONSUL_VERSION="$CONSUL_VERSION"
# export CONSUL_VERSION="$1"
export CONSUL_URL="https://releases.hashicorp.com/consul"
export DC_NAME="dc1"
export CONSUL_DIR="/etc/consul.d"
export CONSUL_DATA="/opt/consul"
export LINUX_DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')


if [[ "$OSTYPE" == "linux"* ]];then
  echo "Using OS: $OSTYPE. This is supported"
  OS_SUFFIX="linux_amd64"
else
  # WARNING: Let's assume that if the OS is not Linux, then it is a MacOS
  echo "Using OS: $OSTYPE. This may not be supported. Please use a \"linux_amd64\" Arch"
  exit 1
fi

if [[ "$LINUX_DISTRO" == "debian" ]] || [[ "$LINUX_DISTRO" == "ubuntu" ]];then
  echo "Using Linux Distro: $LINUX_DISTRO. This is supported"
else
  # WARNING: Let's assume that if the OS is not Linux, then it is a MacOS
  echo "Using Linux Distro: $LINUX_DISTRO. This may not be supported. Please use a \"debian\" Distro"
  exit 1
fi

# This line is to avoid the "unable to initialize frontend: Dialog" message error from Packer build
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

sudo apt-get update
sudo apt-get install unzip -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    dnsutils \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo groupadd docker
sudo usermod -aG docker $USER


newgrp docker 

# Downloading Consul Enterprise binary according to the version specified in the variables
curl -s -O ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_${OS_SUFFIX}.zip
curl -s -O ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS
curl -s -O ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig

# Installing Consul Enterprise binary and configuring 
unzip -o consul_${CONSUL_VERSION}_${OS_SUFFIX}.zip
sudo chown root:root consul
sudo mv consul /usr/bin/
consul --version

consul -autocomplete-install
complete -C /usr/bin/consul consul

sudo useradd --system --home $CONSUL_DIR --shell /bin/false consul
sudo mkdir -p $CONSUL_DATA
sudo chown -R consul:consul $CONSUL_DATA

# Creating CA Certificate for Consul and saving it 
sudo mkdir -p $CONSUL_DIR/tls
consul tls ca create
sudo mv consul-agent-ca*.pem $CONSUL_DIR/tls

# Saving the gossip encryption key. This should be used in the config from this image and then deleted during installation process
# sudo touch $CONSUL_DIR/keygen.out
ls -l $CONSUL_DIR
consul keygen | sudo tee $CONSUL_DIR/keygen.out
cat $CONSUL_DIR/keygen.out
