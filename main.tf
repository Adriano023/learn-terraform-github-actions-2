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
              
              # 1. Installiamo K3s (la versione leggera di Kubernetes)
              # Questo comando scarica K3s, lo installa, avvia il servizio e configura kubectl
              curl -sfL https://get.k3s.io | sh -

              # 2. Aspettiamo qualche secondo che il nodo Kubernetes sia pronto
              sleep 15

              # 3. Creiamo il file Manifest di Kubernetes per il nostro modello ML
              # Definiamo un "Deployment" (il container) e un "Service" (l'esposizione della porta)
              cat << 'K8S_EOF' > /tmp/max-object-detector.yaml
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: max-object-detector
              spec:
                replicas: 1
                selector:
                  matchLabels:
                    app: object-detector
                template:
                  metadata:
                    labels:
                      app: object-detector
                  spec:
                    containers:
                    - name: detector
                      image: quay.io/codait/max-object-detector
                      ports:
                      - containerPort: 5000
              ---
              apiVersion: v1
              kind: Service
              metadata:
                name: max-object-detector-svc
              spec:
                type: LoadBalancer
                selector:
                  app: object-detector
                ports:
                - port: 8080
                  targetPort: 5000
              K8S_EOF

              # 4. Diciamo a Kubernetes di applicare il file e avviare l'infrastruttura
              k3s kubectl apply -f /tmp/max-object-detector.yaml
              EOF
}

output "web-address" {
  value = "${aws_instance.web.public_dns}:8080"
}