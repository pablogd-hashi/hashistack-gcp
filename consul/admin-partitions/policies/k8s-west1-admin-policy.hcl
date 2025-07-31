# Admin policy for k8s-west1 partition - provides full administrative access

partition "k8s-west1" {
  # Full write access to the k8s-west1 admin partition
  policy = "write"
  
  # Full write permissions to KV store in k8s-west1 partition
  key_prefix "" {
    policy = "write"
  }

  # Full service management permissions in k8s-west1 partition
  service_prefix "" {
    policy = "write"
  }
  
  # Node management permissions in k8s-west1 partition
  node_prefix "" {
    policy = "write"
  }

  # ACL management permissions within the partition
  acl = "write"

  # Full access to all namespaces within the partition
  namespace_prefix "" {
    policy = "write"
    
    key_prefix "" {
      policy = "write"
    }
    
    service_prefix "" {
      policy = "write"
    }
    
    # Note: node_prefix with write policy not allowed at namespace level
    node_prefix "" {
      policy = "read"
    }
    
    acl = "write"
  }
}