# Acceptance environment policy for k8s-west1 partition

partition "k8s-west1" {
  # Read access to the partition
  policy = "read"
  
  # KV access for acceptance/staging keys
  key_prefix "acceptance/" {
    policy = "write"
  }
  
  key_prefix "staging/" {
    policy = "write"
  }
  
  key_prefix "testing/" {
    policy = "read"
  }
  
  key_prefix "" {
    policy = "read"
  }

  # Service management permissions for acceptance services
  service_prefix "staging-" {
    policy = "write"
  }
  
  service_prefix "accept-" {
    policy = "write"
  }
  
  service_prefix "" {
    policy = "read"
  }
  
  # Node read permissions
  node_prefix "" {
    policy = "read"
  }

  # Acceptance namespace access
  namespace "acceptance" {
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
  
  # Staging namespace access
  namespace "staging" {
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