# This policy grants access to the finance admin partition and the team* namespaces

partition "finance" {
  # Write access to the finance admin partition
  policy = "write"
  
  # grants write permissions to the finance admin partition
  key_prefix "" {
    policy = "write"
  }

  # grants service:write to the finance admin partition
  service_prefix "" {
    policy = "write"
  }
  
  # grants node:read to the finance admin partition
  node_prefix "" {
    policy = "read"
  }
}
