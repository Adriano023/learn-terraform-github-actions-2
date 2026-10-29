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
  
  # aggiornamento istanza da 8 gb per ML
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
              curl -sfL https://get.k3s.io | sh -

              # 2. Aspettiamo qualche secondo che il nodo Kubernetes sia pronto
              sleep 15

              # 3. Creiamo il file Manifest per il nostro modello ML
              cat << 'ML_EOF' > /tmp/max-object-detector.yaml
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
              ML_EOF

              # 4. Creiamo il file Manifest per il Monitoring (cAdvisor + Prometheus)
              cat << 'MONITORING_EOF' > /tmp/monitoring.yaml
              # --- cAdvisor ---
              apiVersion: apps/v1
              kind: DaemonSet
              metadata:
                name: cadvisor
              spec:
                selector:
                  matchLabels:
                    app: cadvisor
                template:
                  metadata:
                    labels:
                      app: cadvisor
                  spec:
                    containers:
                    - name: cadvisor
                      image: gcr.io/cadvisor/cadvisor:latest
                      ports:
                      - containerPort: 8080
                      volumeMounts:
                      - name: rootfs
                        mountPath: /rootfs
                        readOnly: true
                      - name: var-run
                        mountPath: /var/run
                        readOnly: true
                      - name: sys
                        mountPath: /sys
                        readOnly: true
                    volumes:
                    - name: rootfs
                      hostPath: { path: / }
                    - name: var-run
                      hostPath: { path: /var/run }
                    - name: sys
                      hostPath: { path: /sys }
              ---
              apiVersion: v1
              kind: Service
              metadata:
                name: cadvisor
              spec:
                selector:
                  app: cadvisor
                ports:
                - port: 8080
                  targetPort: 8080
              # --- Prometheus ConfigMap (il file prometheus.yml) ---
              ---
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: prometheus-config
              data:
                prometheus.yml: |
                  global:
                    scrape_interval: 5s
                  scrape_configs:
                    - job_name: 'cadvisor'
                      static_configs:
                        - targets: ['cadvisor:8080']
              # --- Prometheus Deployment & Service ---
              ---
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: prometheus
              spec:
                replicas: 1
                selector:
                  matchLabels:
                    app: prometheus
                template:
                  metadata:
                    labels:
                      app: prometheus
                  spec:
                    containers:
                    - name: prometheus
                      image: prom/prometheus:latest
                      ports:
                      - containerPort: 9090
                      volumeMounts:
                      - name: config-volume
                        mountPath: /etc/prometheus/prometheus.yml
                        subPath: prometheus.yml
                    volumes:
                    - name: config-volume
                      configMap:
                        name: prometheus-config
              ---
              apiVersion: v1
              kind: Service
              metadata:
                name: prometheus-svc
              spec:
                type: LoadBalancer
                selector:
                  app: prometheus
                ports:
                - port: 9090
                  targetPort: 9090
              MONITORING_EOF

              # 5. Applichiamo tutti i manifest in K3s
              k3s kubectl apply -f /tmp/max-object-detector.yaml
              k3s kubectl apply -f /tmp/monitoring.yaml
              EOF
}

output "web-address" {
  value = "${aws_instance.web.public_dns}:8080"
}
output "prometheus-address" {
  value = "${aws_instance.web.public_dns}:9090"
}