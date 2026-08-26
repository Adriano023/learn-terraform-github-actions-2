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
    organization = "test_02332" # <-- INSERISCI QUI LA TUA ORGANIZZAZIONE HCP

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

  # Il blocco user_data ora automatizza l'installazione di Docker
  user_data = <<-EOF
              #!/bin/bash
              # 1. Aggiorna i repository di sistema
              apt-get update
              
              # 2. Installa il motore Docker
              apt-get install -y docker.io
              
              # 3. Abilita e avvia il demone Docker
              systemctl enable docker
              systemctl start docker
              
              # 4. Scarica e avvia il container del microservizio
              # Mappiamo la porta 8080 della macchina virtuale sulla porta 80 del container
              docker run -d -p 8080:80 --name microservizio-web nginx:latest
              EOF
}

output "web-address" {
  value = "${aws_instance.web.public_dns}:8080"
}