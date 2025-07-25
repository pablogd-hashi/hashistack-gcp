terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.28.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "2.20.0"
    }
  }
}


provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

provider "consul" {
  address = var.dns_zone != "" ? "${trimsuffix(google_dns_record_set.consul[0].name, ".")}:8501" : "${google_compute_forwarding_rule.global-lb.ip_address}:8501"
  scheme         = "https"
  insecure_https = true
  token          = var.consul_bootstrap_token
}
# provider "azure" {
#   version = ">=2.0.0"
#   features {}
# }
# provider "aws" {
#   region = "eu-west"
# } 
