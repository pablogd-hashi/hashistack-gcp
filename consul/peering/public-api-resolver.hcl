Kind           = "service-resolver"
Name           = "public-api"
ConnectTimeout = "15s"
Failover = {
  "*" = {
    Targets = [
      {Peer = "gcp-dc2-default"}
    ]
  }
}
