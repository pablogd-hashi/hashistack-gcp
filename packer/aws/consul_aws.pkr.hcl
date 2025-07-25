variable "ssh_user" {
  default = "ubuntu"
}
variable "aws_region" {
  default = "eu-west-1"
}
variable "sshuser" {
  description = "Username for SSH"
}
variable "image" {
  default = "consul-nomad"
}
variable "consul_version" {
  default = "1.12.0"
}
variable "nomad_version" {
  default = "1.3.1"
}

locals {
  consul_version = regex_replace(var.consul_version,"\\.+|\\+","-")
  nomad_version = regex_replace(var.nomad_version,"\\.+|\\+","-")
}


packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "hashi-image" {
  # access_key = "AKIAIOSFODNN7EXAMPLE"
  # secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  region        = var.aws_region
  ami_name      = "${var.image}-${local.consul_version}-${local.nomad_version}"
  instance_type = "t2.small"
  # source_ami = "ubuntu-2104"
  # ssh_username = var.ssh_user
  ssh_username = "admin"
  # Debian 11 image as the source AMI
  source_ami = "ami-0f98479f8cd5b63f6"
  # source_ami_filter {
  #   filters = {
  #     name                = "debian-11-amd64-*"
  #     root-device-type    = "ebs"
  #     virtualization-type = "hvm"
  #   }
  #   most_recent = true
  #   owners      = ["136693071363"]
  # }
}

build {
#   hcp_packer_registry {
#     bucket_name = "vault-ubuntu"
#     description = <<EOT
# This is an image for a Vault node.
#     EOT
#     bucket_labels = {
#       "hashicorp"    = "consul-nomad",
#       "distribution" = "enterprise",
#     }
#   }
  sources = ["sources.amazon-ebs.hashi-image"]
  provisioner "shell" {
    scripts = ["../consul_prep.sh","../nomad_prep.sh"]
    # execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo '{{ .Path }}'"
    environment_vars = [
      "CONSUL_VERSION=${var.consul_version}",
      "NOMAD_VERSION=${var.nomad_version}"
    ]
  }
}

