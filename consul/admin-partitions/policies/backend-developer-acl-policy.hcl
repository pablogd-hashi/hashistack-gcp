# This policy grants access to the web partition and the backend* namespaces

partition "web" {
  # Write access to the web admin partition
  policy = "write"
  
  # grants write permissions to the web admin partition
  key_prefix "" {
    policy = "write"
  }

  # grants service:write to the web admin partition
  service_prefix "" {
    policy = "write"
  }
  
  # grants node:write to the web admin partition
  node_prefix "" {
    policy = "read"
  }
  
  namespace_prefix "backend" {
    # grants permission to manage ACLs only for the backend* namespaces
    acl = "write"

    # grants permission to create and edit the backend* namespaces
    policy = "write"

    # grants write permissions to the KV for the backend* namespaces
    key_prefix "" {
      policy = "write"
    }

    # grants service:write for all services in the backend* namespaces
    service_prefix "" {
      policy = "write"
    }

    # grants node:read in the backend* namespaces
    node_prefix "" {
      policy = "read"
    }

  }
}
