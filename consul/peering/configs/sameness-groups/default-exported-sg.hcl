Kind = "exported-services"
Name = "default"

Services = [
  {
    Name      = "public-api"
    Consumers = [
        {
            SamenessGroup  = "api-services"
        },
    ]
  },
  {
    Name      = "private-api"
    Consumers = [
        {
            SamenessGroup = "api-services"
        }
    ]
  }
]
