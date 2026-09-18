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
  
  # aggiornamento istazna da 8 gb per ML
  instance_type = "m7i-flex.large" 

  # Rende l'infrastruttura immutabile
  user_data_replace_on_change = true

  # Allarghiamo il disco a 30 GB in caso di eventuale aggiunta di modello piu pesante
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
              
              #restart always serve per riavviare il container ad ogni accensione dell istanza
              docker run -d --restart always -p 8080:5000 quay.io/codait/max-object-detector
              EOF
}

output "web-address" {
  value = "${aws_instance.web.public_dns}:8080"
}