# Testing environment policy for k8s-west1 partition

partition "k8s-west1" {
  # Read access to the partition
  policy = "read"
  
  # KV access for testing keys
  key_prefix "testing/" {
    policy = "write"
  }
  
  key_prefix "development/" {
    policy = "read"
  }
  
  key_prefix "" {
    policy = "read"
  }

  # Service management permissions for testing services
  service_prefix "test-" {
    policy = "write"
  }
  
  service_prefix "dev-" {
    policy = "read"
  }
  
  service_prefix "" {
    policy = "read"
  }
  
  # Node read permissions
  node_prefix "" {
    policy = "read"
  }

  # Testing namespace access
  namespace "testing" {
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
  
  # Read access to development namespace
  namespace "development" {
    policy = "read"
  }
  
  # Read-only access to other namespaces
  namespace_prefix "" {
    policy = "read"
  }
}