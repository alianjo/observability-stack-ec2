#!/bin/bash
# User data script for Loki EC2 instance

set -e

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y wget unzip

# Create Loki user
useradd --no-create-home --shell /bin/false loki || true

# Create directories
mkdir -p /etc/loki
mkdir -p /var/lib/loki

# Download and install Loki
cd /tmp
LOKI_VERSION="2.9.3"
wget https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
chmod +x loki-linux-amd64
mv loki-linux-amd64 /usr/local/bin/loki

# Set ownership
chown loki:loki /usr/local/bin/loki
chown -R loki:loki /etc/loki
chown -R loki:loki /var/lib/loki

# Create Loki configuration
cat > /etc/loki/config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

common:
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /var/lib/loki/boltdb-shipper-active
    cache_location: /var/lib/loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /var/lib/loki/chunks

compactor:
  working_directory: /var/lib/loki/boltdb-shipper-compactor
  shared_store: filesystem

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s

ruler:
  storage:
    type: local
    local:
      directory: /var/lib/loki/rules
  rule_path: /var/lib/loki/rules-temp
  alertmanager_url: http://localhost:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
EOF

# Set ownership for config file
chown loki:loki /etc/loki/config.yml

# Create systemd service
cat > /etc/systemd/system/loki.service << 'EOF'
[Unit]
Description=Loki service
After=network.target

[Service]
Type=simple
User=loki
Group=loki
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/config.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Loki
systemctl daemon-reload
systemctl enable loki
systemctl start loki

echo "Loki setup completed!"
