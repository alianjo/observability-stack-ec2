# Architecture Documentation

## Overview

This document provides detailed architecture information for the AWS EC2 Observability Stack.

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS VPC (10.0.0.0/16)                   │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │         Public Subnet (10.0.1.0/24)                    │   │
│  │                                                         │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │   │
│  │  │  Flask App   │  │  Prometheus  │  │   Grafana    │ │   │
│  │  │  EC2         │  │  EC2         │  │   EC2        │ │   │
│  │  │  :5000       │  │  :9090       │  │   :3000      │ │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │   │
│  │         │                 │                 │          │   │
│  │         │                 │                 │          │   │
│  │  ┌──────┴─────────────────┴─────────────────┴───────┐ │   │
│  │  │              Loki EC2 :3100                       │ │   │
│  │  └───────────────────────────────────────────────────┘ │   │
│  │                                                         │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │         Private Subnet (10.0.2.0/24)                   │   │
│  │         (Reserved for future use)                      │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Internet Gateway
                              │
                         ┌────┴────┐
                         │ Internet │
                         └─────────┘
```

## Component Details

### 1. Flask Application Server

**Purpose**: Sample application that generates metrics and logs

**Components**:
- **Flask Web Framework**: Python web application
- **Prometheus Client**: Exports metrics in Prometheus format
- **Promtail**: Ships logs to Loki
- **Application Logger**: Writes structured logs to file

**Exposed Ports**:
- `5000`: Flask application HTTP server
- `9080`: Promtail metrics (internal)

**Metrics Exported**:
```
flask_app_request_count{method, endpoint, status}
flask_app_request_duration_seconds{method, endpoint}
flask_app_active_requests
flask_app_error_count{endpoint}
flask_app_info{version, environment}
```

**Log Format**:
```
YYYY-MM-DD HH:MM:SS - logger_name - LEVEL - message
```

**Storage**:
- Application code: `/opt/flask-app/`
- Logs: `/var/log/app.log`
- Promtail config: `/etc/promtail/config.yml`

### 2. Prometheus Server

**Purpose**: Time-series database for metrics collection and storage

**Components**:
- **Prometheus Server**: Core metrics database
- **Prometheus Web UI**: Query interface and visualization
- **Service Discovery**: Static configuration for targets

**Exposed Ports**:
- `9090`: Prometheus HTTP server and UI

**Scrape Configuration**:
```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'flask-app'
    scrape_interval: 10s
    static_configs:
      - targets: ['<flask-app-private-ip>:5000']
    metrics_path: '/metrics'
```

**Storage**:
- Configuration: `/etc/prometheus/prometheus.yml`
- Data: `/var/lib/prometheus/`
- Retention: 15 days (default)

**Query Examples**:
```promql
# Request rate
rate(flask_app_request_count[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(flask_app_request_duration_seconds_bucket[5m]))

# Error rate
rate(flask_app_error_count[5m])
```

### 3. Loki Server

**Purpose**: Log aggregation system for centralized logging

**Components**:
- **Loki Server**: Log storage and query engine
- **BoltDB**: Index storage
- **Filesystem**: Chunk storage

**Exposed Ports**:
- `3100`: Loki HTTP API
- `9096`: Loki gRPC (internal)

**Storage Configuration**:
```yaml
storage_config:
  boltdb_shipper:
    active_index_directory: /var/lib/loki/boltdb-shipper-active
    cache_location: /var/lib/loki/boltdb-shipper-cache
  filesystem:
    directory: /var/lib/loki/chunks
```

**Storage**:
- Configuration: `/etc/loki/config.yml`
- Data: `/var/lib/loki/`
- Retention: 168 hours (7 days)

**Query Examples**:
```logql
# All logs from Flask app
{job="flask-app"}

# Error logs only
{job="flask-app"} |~ "ERROR|error"

# Logs with specific text
{job="flask-app"} |= "api/data"

# Rate of log lines
rate({job="flask-app"}[5m])
```

### 4. Grafana Server

**Purpose**: Visualization and dashboarding platform

**Components**:
- **Grafana Server**: Core application
- **Datasource Provisioning**: Auto-configured Prometheus and Loki
- **Dashboard Provisioning**: Pre-configured dashboards

**Exposed Ports**:
- `3000`: Grafana HTTP server and UI

**Datasources**:
1. **Prometheus** (default)
   - URL: `http://<prometheus-private-ip>:9090`
   - Type: Prometheus
   - Access: Proxy

2. **Loki**
   - URL: `http://<loki-private-ip>:3100`
   - Type: Loki
   - Access: Proxy

**Storage**:
- Configuration: `/etc/grafana/grafana.ini`
- Data: `/var/lib/grafana/`
- Dashboards: `/var/lib/grafana/dashboards/`
- Provisioning: `/etc/grafana/provisioning/`

## Network Architecture

### VPC Configuration

**CIDR Block**: `10.0.0.0/16`

**Subnets**:
1. **Public Subnet**: `10.0.1.0/24`
   - Internet-accessible via Internet Gateway
   - Hosts all EC2 instances
   - Auto-assigns public IPs

2. **Private Subnet**: `10.0.2.0/24`
   - Reserved for future use
   - No direct internet access

**Routing**:
- Public subnet routes `0.0.0.0/0` to Internet Gateway
- Private subnet would route through NAT Gateway (not implemented)

### Security Groups

#### Flask App Security Group

**Inbound Rules**:
```
Port 22   (SSH)        - From: allowed_ssh_cidr
Port 5000 (Flask)      - From: allowed_web_cidr
Port 5000 (Prometheus) - From: Prometheus SG
```

**Outbound Rules**:
```
Port 3100 (Loki)       - To: VPC CIDR
All traffic            - To: 0.0.0.0/0
```

#### Prometheus Security Group

**Inbound Rules**:
```
Port 22   (SSH)        - From: allowed_ssh_cidr
Port 9090 (Prometheus) - From: allowed_web_cidr
Port 9090 (Grafana)    - From: Grafana SG
```

**Outbound Rules**:
```
All traffic            - To: 0.0.0.0/0
```

#### Grafana Security Group

**Inbound Rules**:
```
Port 22   (SSH)        - From: allowed_ssh_cidr
Port 3000 (Grafana)    - From: allowed_web_cidr
```

**Outbound Rules**:
```
All traffic            - To: 0.0.0.0/0
```

#### Loki Security Group

**Inbound Rules**:
```
Port 22   (SSH)        - From: allowed_ssh_cidr
Port 3100 (Loki)       - From: VPC CIDR
Port 3100 (Grafana)    - From: Grafana SG
```

**Outbound Rules**:
```
All traffic            - To: 0.0.0.0/0
```

## Data Flow

### Metrics Flow

```
┌──────────────┐
│  Flask App   │
│  Exposes     │
│  /metrics    │
└──────┬───────┘
       │
       │ HTTP GET /metrics
       │ Every 10s
       │
       ▼
┌──────────────┐
│  Prometheus  │
│  Scrapes &   │
│  Stores      │
└──────┬───────┘
       │
       │ PromQL Queries
       │
       ▼
┌──────────────┐
│   Grafana    │
│  Visualizes  │
└──────────────┘
```

### Logs Flow

```
┌──────────────┐
│  Flask App   │
│  Writes to   │
│  app.log     │
└──────┬───────┘
       │
       │ File Tail
       │
       ▼
┌──────────────┐
│  Promtail    │
│  Reads &     │
│  Ships       │
└──────┬───────┘
       │
       │ HTTP POST
       │ /loki/api/v1/push
       │
       ▼
┌──────────────┐
│     Loki     │
│  Stores &    │
│  Indexes     │
└──────┬───────┘
       │
       │ LogQL Queries
       │
       ▼
┌──────────────┐
│   Grafana    │
│  Displays    │
└──────────────┘
```

## Deployment Flow

### Terraform Execution Order

1. **Network Resources**
   - VPC
   - Internet Gateway
   - Subnets
   - Route Tables

2. **Security Groups**
   - Flask App SG
   - Prometheus SG
   - Grafana SG
   - Loki SG

3. **EC2 Instances** (with dependencies)
   - Loki (first - no dependencies)
   - Flask App (depends on Loki)
   - Prometheus (depends on Flask App)
   - Grafana (depends on Prometheus and Loki)

### User Data Execution

Each EC2 instance runs a user data script on first boot:

1. **System Update**: `apt-get update && upgrade`
2. **Install Dependencies**: Required packages
3. **Download Software**: Prometheus, Loki, Promtail, Grafana
4. **Configure Service**: Write configuration files
5. **Create Systemd Service**: Service definition
6. **Start Service**: Enable and start

**Execution Time**: 3-5 minutes per instance

## Monitoring and Observability

### What We Monitor

**Application Metrics**:
- Request rate (requests per second)
- Request duration (latency percentiles)
- Active requests (concurrent connections)
- Error rate (errors per second)
- Status code distribution

**Application Logs**:
- Request logs (method, path, status)
- Error logs (exceptions, failures)
- Application events (startup, shutdown)

**System Metrics** (via Prometheus self-monitoring):
- Prometheus scrape duration
- Prometheus storage usage
- Prometheus query performance

### Observability Patterns

**RED Method** (Requests, Errors, Duration):
- ✅ Request Rate: `rate(flask_app_request_count[5m])`
- ✅ Error Rate: `rate(flask_app_error_count[5m])`
- ✅ Duration: `histogram_quantile(0.95, rate(flask_app_request_duration_seconds_bucket[5m]))`

**USE Method** (Utilization, Saturation, Errors):
- Utilization: Active requests gauge
- Saturation: Request queue (not implemented)
- Errors: Error counter

## Scalability Considerations

### Current Limitations

- **Single Instance**: Each component runs on one instance
- **Local Storage**: No distributed storage
- **No High Availability**: Single point of failure
- **Manual Scaling**: No auto-scaling

### Scaling Strategies

#### Horizontal Scaling

**Flask Application**:
```
┌─────────────┐
│     ALB     │
└──────┬──────┘
       │
   ┌───┴───┐
   │       │
   ▼       ▼
┌────┐  ┌────┐
│App1│  │App2│
└────┘  └────┘
```

**Prometheus** (Federation):
```
┌──────────────┐
│  Prometheus  │
│   (Global)   │
└──────┬───────┘
       │
   ┌───┴───┐
   │       │
   ▼       ▼
┌────┐  ┌────┐
│Prom│  │Prom│
│ 1  │  │ 2  │
└────┘  └────┘
```

**Loki** (Microservices Mode):
```
┌─────────┐  ┌─────────┐  ┌─────────┐
│Ingester │  │Querier  │  │Compactor│
└────┬────┘  └────┬────┘  └────┬────┘
     │            │            │
     └────────────┴────────────┘
                  │
            ┌─────┴─────┐
            │  S3/DynamoDB│
            └───────────┘
```

#### Vertical Scaling

Increase instance size:
- `t3.small` → `t3.medium` → `t3.large`
- Add more storage (EBS volumes)
- Increase IOPS for better performance

## Security Architecture

### Defense in Depth

**Layer 1: Network**
- VPC isolation
- Security groups (stateful firewall)
- NACL (optional, stateless firewall)

**Layer 2: Instance**
- SSH key authentication
- No password authentication
- Minimal software installation
- Regular security updates

**Layer 3: Application**
- Grafana authentication
- No public write access
- Rate limiting (application level)

**Layer 4: Data**
- Logs contain no sensitive data
- Metrics are aggregated
- No PII in telemetry

### Security Best Practices

**Implemented**:
- ✅ Security groups with minimal access
- ✅ SSH key authentication
- ✅ Grafana password authentication
- ✅ Separate security groups per service

**Not Implemented (Production Recommendations)**:
- ❌ TLS/SSL encryption
- ❌ Private subnets with NAT Gateway
- ❌ AWS Systems Manager Session Manager
- ❌ CloudWatch monitoring
- ❌ AWS Secrets Manager
- ❌ VPC Flow Logs
- ❌ AWS WAF
- ❌ IAM roles for EC2

## Cost Optimization

### Current Costs (Approximate)

**Monthly Costs (us-east-1)**:
- 4 × t3.small (730 hours): ~$60
- 4 × 30GB EBS (gp3): ~$4
- Data transfer: ~$1-5
- **Total**: ~$65-70/month

### Cost Optimization Strategies

1. **Use Smaller Instances**:
   - t3.micro for testing: ~$30/month

2. **Stop When Not in Use**:
   - Stop instances: $0 compute, ~$4 storage

3. **Use Spot Instances**:
   - 70-90% savings for non-production

4. **Reserved Instances**:
   - 1-year: 40% savings
   - 3-year: 60% savings

5. **Optimize Storage**:
   - Delete old logs/metrics
   - Use lifecycle policies
   - Compress data

## Performance Characteristics

### Expected Performance

**Flask Application**:
- Throughput: ~1000 req/s (single instance)
- Latency: <50ms (p95)
- Concurrent connections: ~100

**Prometheus**:
- Scrape targets: ~10-100
- Metrics: ~10,000 time series
- Query latency: <1s
- Storage: ~1GB per million samples

**Loki**:
- Ingestion: ~10MB/s
- Query latency: <5s
- Storage: ~100MB per million log lines

**Grafana**:
- Concurrent users: ~10-50
- Dashboard load time: <2s
- Query performance: Depends on datasource

## Disaster Recovery

### Backup Strategy

**What to Backup**:
- Prometheus data: `/var/lib/prometheus/`
- Loki data: `/var/lib/loki/`
- Grafana dashboards: `/var/lib/grafana/`
- Configuration files: `/etc/prometheus/`, `/etc/loki/`, `/etc/grafana/`

**Backup Methods**:
1. EBS Snapshots (automated)
2. Manual tar archives
3. Configuration in Git (IaC)

### Recovery Procedures

**Complete Stack Recovery**:
```bash
# 1. Deploy infrastructure
terraform apply

# 2. Restore data (if needed)
# SSH into instances and restore from backups

# 3. Verify services
# Check each service is running and accessible
```

**Individual Service Recovery**:
```bash
# Restart service
sudo systemctl restart <service-name>

# Restore from backup
sudo tar -xzf backup.tar.gz -C /

# Verify
sudo systemctl status <service-name>
```

## Future Enhancements

### Planned Improvements

1. **High Availability**:
   - Multi-AZ deployment
   - Load balancers
   - Auto-scaling groups

2. **Enhanced Security**:
   - Private subnets
   - TLS/SSL everywhere
   - AWS Secrets Manager
   - IAM roles

3. **Better Monitoring**:
   - CloudWatch integration
   - Alertmanager setup
   - PagerDuty integration

4. **Distributed Storage**:
   - S3 for Loki chunks
   - RDS for Grafana
   - Thanos for Prometheus

5. **CI/CD Integration**:
   - Automated deployments
   - Blue-green deployments
   - Canary releases

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
