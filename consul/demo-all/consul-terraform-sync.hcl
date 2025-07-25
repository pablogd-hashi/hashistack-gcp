log_level = "INFO"
port = 8558

consul {
  address = "http://consul.hc-6e62239184664d288bfcec8c6f8.gcp.sbx.hashicorpdemo.com:8500"  # Direct connection to GCP Consul server
  token = "ConsulR0cks"       # Your bootstrap token
}
driver "terraform" {
  log = true
  path = "/tmp/cts-terraform"
  
  # For local execution - CTS doesn't support remote backend directly
  required_providers {
    consul = {
      source = "hashicorp/consul"
    }
    google = {
      source = "hashicorp/google"
    }
    local = {
      source = "hashicorp/local" 
    }
  }
}

task {
  name = "boutique-load-balancer-sync"
  description = "Update load balancer when production intentions change for minimal boutique"
  enabled = true
  
  # Updated syntax for CTS v0.8.0
  condition "services" {
    names = [
      "frontend",
      "productcatalogservice", 
      "cartservice",
      "currencyservice",
      "redis-cart"
    ]
  }
  
  # Use local module that integrates with existing GKE infrastructure
  module = "./gke-integration-module"
}
