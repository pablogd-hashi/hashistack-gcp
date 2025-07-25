Kind = "service-intentions"
Name = "test-destination"
Sources = [
  {
    Name   = "front-service"
    Action = "allow"
  },
  {
    Name   = "public-api"
    Action = "allow"
  }
]
