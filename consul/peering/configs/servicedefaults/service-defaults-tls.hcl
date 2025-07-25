Kind = "service-defaults"
Name = "tls-destination"
Protocol = "tcp"
Destination {
  Addresses = [
    "developer.hashicorp.com",
    "www.google.com",
    "10.2.0.4",
    "10.2.0.18",
    "hashicorp.com"
  ]
  Port = 443
}