#!/bin/bash
# User data script for Prometheus EC2 instance

set -e

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y wget tar

# Create Prometheus user
useradd --no-create-home --shell /bin/false prometheus || true

# Create directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# Download and install Prometheus
cd /tmp
PROMETHEUS_VERSION="2.48.0"
wget https://github.com/prometheus/prometheus/releases/download/v$${PROMETHEUS_VERSION}/prometheus-$${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar -xzf prometheus-$${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-$${PROMETHEUS_VERSION}.linux-amd64

# Copy binaries
cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/

# Copy console files
cp -r consoles /etc/prometheus
cp -r console_libraries /etc/prometheus

# Set ownership
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

# Create Prometheus configuration
cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'observability-stack'
    environment: 'production'

# Alertmanager configuration (optional)
# alerting:
#   alertmanagers:
#     - static_configs:
#         - targets:
#           - localhost:9093

# Load rules once and periodically evaluate them
rule_files:
  # - "rules/*.yml"

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'prometheus-server'

  # Flask application monitoring
  - job_name: 'flask-app'
    scrape_interval: 10s
    static_configs:
      - targets: ['${flask_app_ip}:5000']
        labels:
          instance: 'flask-app-server'
          application: 'flask-demo'
    metrics_path: '/metrics'
EOF

# Set ownership for config file
chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Create systemd service
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Prometheus
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

echo "Prometheus setup completed!"
