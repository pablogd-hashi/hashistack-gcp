# Development environment policy for k8s-southwest1 partition

partition "k8s-southwest1" {
  # Read access to the partition
  policy = "read"
  
  # Limited KV access - read/write for development keys only
  key_prefix "development/" {
    policy = "write"
  }
  
  key_prefix "" {
    policy = "read"
  }

  # Service management permissions for development services
  service_prefix "dev-" {
    policy = "write"
  }
  
  service_prefix "" {
    policy = "read"
  }
  
  # Node read permissions
  node_prefix "" {
    policy = "read"
  }

  # Development namespace access
  namespace "development" {
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