# Boundary Worker Configuration
# This configuration is for a self-managed Boundary worker

# Disable memory lock for worker
disable_mlock = true

# Worker configuration
worker {
  # Name of the worker - will be displayed in Boundary UI
  name = "hashistack-worker"
  
  # Description of the worker
  description = "Self-managed worker for HashiStack infrastructure"
  
  # Public address where the worker will be accessible
  # This should be the public IP or hostname of the worker instance
  public_addr = "${WORKER_PUBLIC_ADDR}"
  
  # Auth storage directory
  auth_storage_path = "/opt/boundary/worker"
  
  # Worker tags for filtering and organization
  tags {
    env = ["${ENVIRONMENT}"]
    region = ["${REGION}"]
    type = ["hashistack"]
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