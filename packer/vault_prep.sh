#! /bin/bash
env

export VAULT_VERSION="$VAULT_VERSION"
# export VAULT_VERSION="$1"
export VAULT_URL="https://releases.hashicorp.com/vault"
export VAULT_DIR="/etc/vault.d"
export VAULT_DATA="/opt/vault"
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

# Downloading Vault binary according to the version specified in the variables
curl -s -O ${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_${OS_SUFFIX}.zip
curl -s -O ${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS
curl -s -O ${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS.sig

# Installing Vault binary and configuring 
unzip -o vault_${VAULT_VERSION}_${OS_SUFFIX}.zip
sudo chown root:root vault
sudo mv vault /usr/bin/
vault --version

vault -autocomplete-install
complete -C /usr/bin/vault vault

sudo useradd --system --home $VAULT_DIR --shell /bin/false vault
sudo mkdir -p $VAULT_DATA
sudo chown -R vault:vault $VAULT_DATA




