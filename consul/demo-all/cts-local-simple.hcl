log_level = "DEBUG"
port = 8558

# Reduce buffer for faster response
buffer_period {
  enabled = true
  min = "2s"
  max = "10s"
}

consul {
  address = "http://34.88.51.53:8500"
  token = "ConsulR0cks"
}

driver "terraform" {
  log = true
  persist_log = true
}

task {
  name = "production-boutique-automation"
  description = "Monitor production boutique services and generate automation"
  enabled = true
  module = "./simple-module"

  # Use deprecated but working services block
  services = ["frontend", "cartservice", "currencyservice", "productcatalogservice", "redis-cart", "test-service"]
}