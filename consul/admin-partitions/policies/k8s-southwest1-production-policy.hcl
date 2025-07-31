# Production environment policy for k8s-southwest1 partition

partition "k8s-southwest1" {
  # Read access to the partition
  policy = "read"
  
  # KV access for production keys
  key_prefix "production/" {
    policy = "write"
  }
  
  key_prefix "prod/" {
    policy = "write"
  }
  
  key_prefix "acceptance/" {
    policy = "read"
  }
  
  key_prefix "" {
    policy = "read"
  }

  # Service management permissions for production services
  service_prefix "prod-" {
    policy = "write"
  }
  
  service_prefix "production-" {
    policy = "write"
  }
  
  service_prefix "" {
    policy = "read"
  }
  
  # Node read permissions (production should not modify nodes)
  node_prefix "" {
    policy = "read"
  }

  # Production namespace access
  namespace "production" {
    policy = "write"
    
    key_prefix "" {
      policy = "write"
    }
    
    service_prefix "" {
      policy = "write"
    }
    
    node_prefix "" {
      policy = "read"
    }
  }
  
  # Default namespace for production workloads
  namespace "default" {
    policy = "write"
    
    key_prefix "" {
      policy = "write"
    }
    
    service_prefix "" {
      policy = "write"
    }
    
    node_prefix "" {
      policy = "read"
    }
  }
  
  # Read-only access to other namespaces
  namespace_prefix "" {
    policy = "read"
  }
}