Kind = "http-route"
Name = "my-http-route"

// Rules define how requests will be routed
Rules = [
  {
    Matches = [
      {
        Path = {
          Match = "prefix"
          Value = "/"
        }
      }
    ]
    Services = [
      {
        Name = "front-service"
      }
    ]
  }
]

Parents = [
  {
    Kind        = "api-gateway"
    Name        = "my-api-gateway"
    SectionName = "my-http-listener"
  }
]