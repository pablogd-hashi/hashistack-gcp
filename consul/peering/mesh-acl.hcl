mesh = "write"
partition_prefix "" {
  mesh = "write"
  peering = "read"
  service_prefix "" {
    policy = "read"
  }
}