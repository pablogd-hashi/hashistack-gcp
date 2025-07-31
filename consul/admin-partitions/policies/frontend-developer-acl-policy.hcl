# Frontend Developer policy - access to web partition frontend services

partition "web" {
  # Read access to the web partition
  policy = "read"
  
  # Limited KV access for frontend configuration
  key_prefix "frontend/" {
    policy = "write"
  }
  
  key_prefix "config/frontend/" {
    policy = "write"
  }
  
  key_prefix "" {
    policy = "read"
  }

  # Service management permissions for frontend services
  service_prefix "frontend-" {
    policy = "write"
  }
  
  service_prefix "ui-" {
    policy = "write"
  }
  
  service_prefix "web-" {
    policy = "read"
  }
  
  service_prefix "" {
    policy = "read"
  }
  
  # Node read permissions only
  node_prefix "" {
    policy = "read"
  }

  # Frontend namespace access
  namespace "frontend" {
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
  
  # Default namespace read access
  namespace "default" {
    policy = "read"
    
    # Can read services to understand dependencies
    service_prefix "" {
      policy = "read"
    }
  }
  
  # Read-only access to other namespaces
  namespace_prefix "" {
    policy = "read"
  }
}