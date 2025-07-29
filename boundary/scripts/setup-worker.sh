#!/bin/bash

# Boundary Worker Setup Script for HashiStack Infrastructure
# This script installs and configures a Boundary worker on Ubuntu instances

set -e

# Variables
WORKER_PUBLIC_ADDR="${1:-}"
ENVIRONMENT="${2:-development}"
REGION="${3:-us-central1}"
HCP_BOUNDARY_CLUSTER_ID="${4:-}"
WORKER_CONFIG_PATH="/opt/boundary/worker"
WORKER_CONFIG_FILE="${WORKER_CONFIG_PATH}/pki-worker.hcl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    exit 1
fi

# Validate required parameters
if [[ -z "$WORKER_PUBLIC_ADDR" ]]; then
    log_error "Worker public address is required"
    echo "Usage: $0 <worker_public_addr> [environment] [region] [hcp_boundary_cluster_id]"
    exit 1
fi

if [[ -z "$HCP_BOUNDARY_CLUSTER_ID" ]]; then
    log_error "HCP Boundary cluster ID is required"
    echo "Usage: $0 <worker_public_addr> [environment] [region] [hcp_boundary_cluster_id]"
    exit 1
fi

log_info "Setting up Boundary worker..."
log_info "Public Address: $WORKER_PUBLIC_ADDR"
log_info "Environment: $ENVIRONMENT"
log_info "Region: $REGION"
log_info "HCP Cluster ID: $HCP_BOUNDARY_CLUSTER_ID"

# Update system packages
log_info "Updating system packages..."
sudo apt-get update -y

# Install required packages
log_info "Installing required packages..."
sudo apt-get install -y curl jq unzip

# Install HashiCorp GPG key and repository
log_info "Installing HashiCorp repository..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update package list and install Boundary Enterprise
log_info "Installing Boundary Enterprise..."
sudo apt-get update -y
sudo apt-get install -y boundary-enterprise

# Create boundary user and directories
log_info "Creating boundary user and directories..."
sudo useradd --system --home /opt/boundary --shell /bin/false boundary || true
sudo mkdir -p "$WORKER_CONFIG_PATH"
sudo chown -R boundary:boundary /opt/boundary

# Generate worker configuration
log_info "Generating worker configuration..."
sudo tee "$WORKER_CONFIG_FILE" > /dev/null <<EOF
# Boundary Worker Configuration
# This configuration is for a self-managed Boundary worker

# Disable memory lock for worker
disable_mlock = true

# Worker configuration
worker {
  # Name of the worker - will be displayed in Boundary UI
  name = "hashistack-worker-\$(hostname)"
  
  # Description of the worker
  description = "Self-managed worker for HashiStack infrastructure on \$(hostname)"
  
  # Public address where the worker will be accessible
  public_addr = "${WORKER_PUBLIC_ADDR}:9202"
  
  # Auth storage directory
  auth_storage_path = "/opt/boundary/worker"
  
  # Worker tags for filtering and organization
  tags {
    env = ["${ENVIRONMENT}"]
    region = ["${REGION}"]
    type = ["hashistack"]
    hostname = ["\$(hostname)"]
  }
}

# Listener configuration for proxy connections
listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
}

# HCP Configuration
hcp_boundary_cluster_id = "${HCP_BOUNDARY_CLUSTER_ID}"

# Logging configuration
log_level = "info"
log_format = "standard"
EOF

# Set proper permissions
sudo chown boundary:boundary "$WORKER_CONFIG_FILE"
sudo chmod 640 "$WORKER_CONFIG_FILE"

# Create systemd service file
log_info "Creating systemd service..."
sudo tee /etc/systemd/system/boundary-worker.service > /dev/null <<EOF
[Unit]
Description=Boundary Worker
Documentation=https://www.boundaryproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$WORKER_CONFIG_FILE

[Service]
Type=notify
ExecStart=/usr/bin/boundary server -config=$WORKER_CONFIG_FILE
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536
User=boundary
Group=boundary

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
log_info "Enabling Boundary worker service..."
sudo systemctl daemon-reload
sudo systemctl enable boundary-worker

# Configure firewall (if ufw is installed)
if command -v ufw &> /dev/null; then
    log_info "Configuring firewall..."
    sudo ufw allow 9202/tcp comment "Boundary worker proxy"
fi

log_info "Boundary worker setup completed!"
log_info "Configuration file: $WORKER_CONFIG_FILE"
log_info ""
log_info "To start the worker:"
log_info "  sudo systemctl start boundary-worker"
log_info ""
log_info "To check worker status:"
log_info "  sudo systemctl status boundary-worker"
log_info ""
log_info "To view worker logs:"
log_info "  sudo journalctl -u boundary-worker -f"
log_info ""
log_warn "IMPORTANT: After starting the worker, you need to register it in the Boundary UI"
log_warn "1. Start the worker: sudo systemctl start boundary-worker"
log_warn "2. Check logs for the Worker Auth Registration Request"
log_warn "3. Copy the registration request and paste it in the Boundary UI"
log_warn "4. Complete the worker registration process"