# Admin policy for openshift-rosa partition - provides full administrative access

# Required for partition-init job to verify partition exists
operator = "read"

partition "openshift-rosa" {
  # Full write access to the openshift-rosa admin partition
  policy = "write"

  # Full write permissions to KV store in openshift-rosa partition
  key_prefix "" {
    policy = "write"
  }

  # Full service management permissions in openshift-rosa partition
  service_prefix "" {
    policy = "write"
  }

  # Node management permissions in openshift-rosa partition
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

    node_prefix "" {
      policy = "read"
    }

    acl = "write"
  }
}
