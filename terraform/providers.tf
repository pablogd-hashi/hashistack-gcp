terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.28.0"
    }
    consul = {
      source = "hashicorp/consul"
      version = "2.20.0"
    }
  }
}


provider "google" {
  project = var.gcp_project
  region = var.gcp_region
}

provider "consul" {
  address = "${local.fqdn}:8500"
  # address = "${trimsuffix(google_dns_record_set.dns.name,".")}:8500"
  scheme = "http"
  token = var.consul_bootstrap_token
}
# provider "azure" {
#   version = ">=2.0.0"
#   features {}
# }
# provider "aws" {
#   region = "eu-west"
# } 
