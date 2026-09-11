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
  instance_type = "t3.micro" 

  # rende l'infrastruttura immutabile
  user_data_replace_on_change = true

  # Il blocco user_data ora automatizza l'installazione di Docker e del modello ML
  user_data = <<-EOF
              #!/bin/bash
              # 1. Aggiorna i repository di sistema
              apt-get update
              
              # 2. Installa il motore Docker
              apt-get install -y docker.io
              
              # 3. Abilita e avvia il demone Docker
              systemctl enable docker
              systemctl start docker
              
              # 4. Scarica e avvia il container del microservizio di Machine Learning
              # Mappiamo la porta 8080 di AWS sulla porta 5000 del container Python
              docker run -d -p 8080:5000 --name ml-app vaishnavi8754/24mcr121-ml:latest
              EOF
}

output "web-address" {
  value = "${aws_instance.web.public_dns}:8080"
}