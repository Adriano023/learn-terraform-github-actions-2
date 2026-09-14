# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.52.0"
    }
  }
  required_version = ">= 1.1.0"

  cloud {
    organization = "test_02332" 

    workspaces {
      name = "gh-actions-demo" 
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_instance" "web" {
  ami           = "ami-0aba19e56f3eaec05"
  
  # Istanza piu potente (8GB RAM) dal nuovo piano gratuito per reggere il modello
  instance_type = "m7i-flex.large" 

  # Rende l'infrastruttura immutabile
  user_data_replace_on_change = true

  # Allarghiamo il disco a 30 GB (inclusi nel piano gratuito) per l'immagine da 11.3 GB
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              # 1. Aggiorna i repository e installa Docker
              apt-get update
              apt-get install -y docker.io
              systemctl enable docker
              systemctl start docker
              

              docker run -d -p 8080:5000 quay.io/codait/max-object-detector
              EOF
}

output "web-address" {
  value = "${aws_instance.web.public_dns}:8080"
}