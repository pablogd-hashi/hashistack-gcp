Kind = "exported-services"
Name = "default"

Services = [
  {
    Name      = "public-api"
    Consumers = [
        {
            Peer  = "gcp-dc1-default"
        },
    ]
  },
  {
    Name      = "private-api"
    Consumers = [
        {
            Peer = "gcp-dc1-default"
        }
    ]
  }
]
