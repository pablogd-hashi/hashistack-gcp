#! /bin/bash

export NOMAD_VERSION="$NOMAD_VERSION"
# export NOMAD_VERSION="$1"
export NOMAD_URL="https://releases.hashicorp.com/nomad"
export DC_NAME="dc1"
export NOMAD_DIR="/etc/nomad.d"
export NOMAD_DATA="/opt/nomad"
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

sudo apt-get install unzip -y

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo groupadd docker
sudo usermod -aG docker $USER

# Downloading Nomad Enterprise binary according to the version specified in the variables
curl -s -O ${NOMAD_URL}/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_${OS_SUFFIX}.zip
curl -s -O ${NOMAD_URL}/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_SHA256SUMS
curl -s -O ${NOMAD_URL}/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_SHA256SUMS.sig

# Installing Nomad Enterprise binary and configuring 
unzip -o nomad_${NOMAD_VERSION}_${OS_SUFFIX}.zip
sudo chown root:root nomad
sudo mv nomad /usr/bin/
nomad --version

nomad -autocomplete-install
complete -C /usr/bin/nomad nomad

sudo mkdir -p $NOMAD_DIR
sudo useradd --system --home $NOMAD_DIR --shell /bin/false nomad
sudo mkdir -p $NOMAD_DATA
sudo chown -R nomad:nomad $NOMAD_DATA

# Need to add nomad user to Docker group to make the Docker driver available.
sudo usermod -G docker -a nomad



