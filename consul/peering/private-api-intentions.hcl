Kind = "service-intentions"
Name = "private-api"
Sources = [
  {
    Name   = "front-service"
    Action = "allow"
    Peer = "gcp-dc1-default"
  }
]
