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
    organization = "REPLACE_ME" # <-- INSERISCI QUI SOLO IL NOME DELLA TUA ORGANIZZAZIONE

    workspaces {
      name = "gh-actions-demo" 
    }
  }
}

provider "aws" {
  region = "eu-north-1" # <-- REGIONE DI STOCCOLMA
}

resource "aws_instance" "web" {
  ami           = "ami-0aba19e56f3eaec05" # <-- AMI DI STOCCOLMA
  instance_type = "t3.micro" 

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              sed -i -e 's/80/8080/' /etc/apache2/ports.conf
              echo "Hello World" > /var/www/html/index.html
              systemctl restart apache2
              EOF
}

output "web-address" {
  value = "${aws_instance.web.public_dns}:8080"
}