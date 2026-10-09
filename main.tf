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
              apt-get update
              apt-get install -y docker.io
              systemctl enable docker
              systemctl start docker

              # 1. Creiamo una rete interna per far parlare i container tra loro
              docker network create monitoring-net

              # 2. Avviamo cAdvisor per estrarre le metriche hardware da Docker
              docker run -d --name=cadvisor --net=monitoring-net -p 8081:8080 \
                -v /:/rootfs:ro -v /var/run:/var/run:rw -v /sys:/sys:ro -v /var/lib/docker/:/var/lib/docker:ro \
                --restart always gcr.io/cadvisor/cadvisor:latest

              # 3. Creiamo la configurazione per Prometheus
              mkdir -p /etc/prometheus
              cat << 'PROM_EOF' > /etc/prometheus/prometheus.yml
              global:
                scrape_interval: 5s
              scrape_configs:
                - job_name: 'cadvisor'
                  static_configs:
                    - targets: ['cadvisor:8080']
              PROM_EOF

              # 4. Avviamo Prometheus per raccogliere i dati
              docker run -d --name=prometheus --net=monitoring-net -p 9090:9090 \
                -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
                --restart always prom/prometheus:latest

              # 5. Avviamo il nostro modello di Machine Learning
              docker run -d --name=max-object-detector -p 8080:5000 \
                --restart always quay.io/codait/max-object-detector
              EOF
}

output "web-address" {
  value = "${aws_instance.web.public_dns}:8080"
}