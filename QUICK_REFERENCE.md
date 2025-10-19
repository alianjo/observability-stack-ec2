# Quick Reference Guide

Essential commands and information for the observability stack.

## Deployment Commands

```bash
# Initialize Terraform
cd terraform
terraform init

# Preview changes
terraform plan

# Deploy stack
terraform apply

# Destroy stack
terraform destroy

# View outputs
terraform output

# Get specific output
terraform output flask_app_public_ip
```

## Service URLs

```bash
# Get all URLs
terraform output flask_app_url
terraform output prometheus_url
terraform output grafana_url
terraform output loki_url

# Or construct manually
FLASK_IP=$(terraform output -raw flask_app_public_ip)
echo "Flask: http://$FLASK_IP:5000"
```

## Testing Commands

```bash
# Run comprehensive tests
cd terraform
bash ../scripts/test_stack.sh

# Generate load (duration in seconds, requests per second)
bash ../scripts/generate_load.sh 60 10

# Quick health checks
curl http://<flask-ip>:5000/health
curl http://<prometheus-ip>:9090/-/healthy
curl http://<loki-ip>:3100/ready
curl http://<grafana-ip>:3000/api/health
```

## SSH Access

```bash
# SSH into instances
ssh -i your-key.pem ubuntu@<instance-ip>

# Using Terraform output
ssh -i your-key.pem ubuntu@$(terraform output -raw flask_app_public_ip)
ssh -i your-key.pem ubuntu@$(terraform output -raw prometheus_public_ip)
ssh -i your-key.pem ubuntu@$(terraform output -raw grafana_public_ip)
ssh -i your-key.pem ubuntu@$(terraform output -raw loki_public_ip)
```

## Service Management

```bash
# Check service status
sudo systemctl status flask-app
sudo systemctl status prometheus
sudo systemctl status loki
sudo systemctl status grafana-server
sudo systemctl status promtail

# Restart services
sudo systemctl restart flask-app
sudo systemctl restart prometheus
sudo systemctl restart loki
sudo systemctl restart grafana-server
sudo systemctl restart promtail

# View logs
sudo journalctl -u flask-app -f
sudo journalctl -u prometheus -f
sudo journalctl -u loki -f
sudo journalctl -u grafana-server -f
sudo journalctl -u promtail -f
```

## Configuration Files

```bash
# Flask app
/opt/flask-app/app.py
/opt/flask-app/requirements.txt

# Prometheus
/etc/prometheus/prometheus.yml
/var/lib/prometheus/

# Loki
/etc/loki/config.yml
/var/lib/loki/

# Grafana
/etc/grafana/grafana.ini
/etc/grafana/provisioning/
/var/lib/grafana/

# Promtail
/etc/promtail/config.yml

# Application logs
/var/log/app.log
```

## Prometheus Queries

```promql
# Request rate
rate(flask_app_request_count[5m])

# Total requests
sum(flask_app_request_count)

# Request duration (p95)
histogram_quantile(0.95, rate(flask_app_request_duration_seconds_bucket[5m]))

# Active requests
flask_app_active_requests

# Error rate
rate(flask_app_error_count[5m])

# Requests by status code
sum by (status) (rate(flask_app_request_count[5m]))

# Requests by endpoint
sum by (endpoint) (rate(flask_app_request_count[5m]))

# Error percentage
(sum(rate(flask_app_error_count[5m])) / sum(rate(flask_app_request_count[5m]))) * 100
```

## LogQL Queries (Loki)

```logql
# All logs
{job="flask-app"}

# Error logs
{job="flask-app"} |~ "ERROR|error"

# Logs with specific text
{job="flask-app"} |= "api/data"

# Logs without specific text
{job="flask-app"} != "health"

# Rate of log lines
rate({job="flask-app"}[5m])

# Count by level
sum by (level) (rate({job="flask-app"} | json | __error__="" [5m]))

# Filter by time range
{job="flask-app"} |~ "ERROR" | line_format "{{.timestamp}} {{.message}}"
```

## Flask API Endpoints

```bash
# Home
curl http://<flask-ip>:5000/

# Health check
curl http://<flask-ip>:5000/health

# Metrics
curl http://<flask-ip>:5000/metrics

# Sample data
curl http://<flask-ip>:5000/api/data

# Random number
curl http://<flask-ip>:5000/api/random

# Trigger error (for testing)
curl http://<flask-ip>:5000/api/error
```

## AWS CLI Commands

```bash
# List instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=observability-stack-*" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress]' \
  --output table

# Stop instances
aws ec2 stop-instances --instance-ids <instance-id>

# Start instances
aws ec2 start-instances --instance-ids <instance-id>

# Describe security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=observability-stack-*"

# Get VPC info
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=observability-stack-vpc"
```

## Grafana Access

```bash
# Default credentials
Username: admin
Password: (from terraform.tfvars grafana_admin_password)

# Reset admin password (on Grafana instance)
ssh -i key.pem ubuntu@<grafana-ip>
sudo grafana-cli admin reset-admin-password newpassword
```

## Backup Commands

```bash
# Backup Prometheus data
ssh -i key.pem ubuntu@<prometheus-ip>
sudo tar -czf prometheus-backup-$(date +%Y%m%d).tar.gz /var/lib/prometheus/

# Backup Loki data
ssh -i key.pem ubuntu@<loki-ip>
sudo tar -czf loki-backup-$(date +%Y%m%d).tar.gz /var/lib/loki/

# Backup Grafana
ssh -i key.pem ubuntu@<grafana-ip>
sudo tar -czf grafana-backup-$(date +%Y%m%d).tar.gz /var/lib/grafana/

# Download backup
scp -i key.pem ubuntu@<instance-ip>:~/backup.tar.gz ./
```

## Monitoring Commands

```bash
# Check resource usage
ssh -i key.pem ubuntu@<instance-ip>
top
htop
df -h
free -h
iostat

# Check network connections
netstat -tulpn
ss -tulpn

# Check disk I/O
iostat -x 1

# Check logs size
du -sh /var/log/
du -sh /var/lib/prometheus/
du -sh /var/lib/loki/
```

## Troubleshooting Quick Checks

```bash
# 1. Check if services are running
for service in flask-app prometheus loki grafana-server; do
  ssh -i key.pem ubuntu@<ip> "sudo systemctl is-active $service"
done

# 2. Check connectivity
nc -zv <flask-ip> 5000
nc -zv <prometheus-ip> 9090
nc -zv <loki-ip> 3100
nc -zv <grafana-ip> 3000

# 3. Check Prometheus targets
curl -s http://<prometheus-ip>:9090/api/v1/targets | jq '.data.activeTargets[].health'

# 4. Check if logs are being shipped
curl -s "http://<loki-ip>:3100/loki/api/v1/query?query={job=\"flask-app\"}" | jq

# 5. Verify security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=observability-stack-*" \
  --query 'SecurityGroups[].IpPermissions[]'
```

## Performance Tuning

```bash
# Increase Prometheus retention
ssh -i key.pem ubuntu@<prometheus-ip>
sudo nano /etc/systemd/system/prometheus.service
# Add: --storage.tsdb.retention.time=30d
sudo systemctl daemon-reload
sudo systemctl restart prometheus

# Adjust Loki retention
ssh -i key.pem ubuntu@<loki-ip>
sudo nano /etc/loki/config.yml
# Update: retention_period: 336h  # 14 days
sudo systemctl restart loki

# Optimize Promtail
ssh -i key.pem ubuntu@<flask-ip>
sudo nano /etc/promtail/config.yml
# Adjust batch_size and batch_wait
sudo systemctl restart promtail
```

## Cost Management

```bash
# Check instance costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Stop all instances (keep data)
terraform apply -var="instance_type=t3.micro" -target=aws_instance.flask_app
# Or stop via AWS CLI
aws ec2 stop-instances --instance-ids $(terraform output -json | jq -r '.*.value.id')

# Destroy everything
terraform destroy
```

## Common Variables

```hcl
# terraform.tfvars
aws_region              = "us-east-1"
project_name            = "observability-stack"
instance_type           = "t3.small"
key_name                = "your-key-name"
allowed_ssh_cidr        = "YOUR_IP/32"
allowed_web_cidr        = "YOUR_IP/32"
grafana_admin_password  = "secure-password"
```

## Port Reference

| Service    | Port | Protocol | Purpose                |
|------------|------|----------|------------------------|
| Flask      | 5000 | HTTP     | Application & Metrics  |
| Prometheus | 9090 | HTTP     | Metrics & Web UI       |
| Loki       | 3100 | HTTP     | Log Ingestion & Query  |
| Grafana    | 3000 | HTTP     | Visualization & UI     |
| Promtail   | 9080 | HTTP     | Promtail Metrics       |
| SSH        | 22   | SSH      | Remote Access          |

## File Locations Reference

| Component  | Config Location              | Data Location           |
|------------|------------------------------|-------------------------|
| Flask      | /opt/flask-app/              | /var/log/app.log        |
| Prometheus | /etc/prometheus/             | /var/lib/prometheus/    |
| Loki       | /etc/loki/                   | /var/lib/loki/          |
| Grafana    | /etc/grafana/                | /var/lib/grafana/       |
| Promtail   | /etc/promtail/               | /tmp/positions.yaml     |

## Useful One-Liners

```bash
# Get all IPs at once
terraform output -json | jq -r 'to_entries[] | select(.key | endswith("_public_ip")) | "\(.key): \(.value.value)"'

# Test all services health
for ip in $(terraform output -json | jq -r '.*.value' | grep -E '^[0-9]'); do
  echo "Testing $ip..."
  curl -s -o /dev/null -w "%{http_code}\n" http://$ip:5000/health 2>/dev/null || echo "N/A"
done

# Generate continuous load
while true; do curl -s http://<flask-ip>:5000/api/data > /dev/null; sleep 0.1; done

# Watch Prometheus metrics
watch -n 1 'curl -s http://<prometheus-ip>:9090/api/v1/query?query=flask_app_request_count | jq'

# Tail all logs from all instances
for ip in $(terraform output -json | jq -r '.*.value' | grep -E '^[0-9]'); do
  ssh -i key.pem ubuntu@$ip "sudo journalctl -f" &
done
```

## Emergency Procedures

```bash
# Service crashed - restart
ssh -i key.pem ubuntu@<instance-ip>
sudo systemctl restart <service-name>

# Out of disk space - clean up
ssh -i key.pem ubuntu@<instance-ip>
sudo journalctl --vacuum-time=1d
sudo find /var/log -name "*.gz" -delete
sudo find /tmp -type f -atime +7 -delete

# High CPU - investigate
ssh -i key.pem ubuntu@<instance-ip>
top -c
ps aux --sort=-%cpu | head -10

# Network issues - check connectivity
ssh -i key.pem ubuntu@<instance-ip>
ping -c 3 8.8.8.8
curl -I https://google.com
netstat -tulpn

# Complete reset
terraform destroy
terraform apply
```

## Documentation Links

- **Main README**: [README.md](README.md)
- **Deployment Guide**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Project Summary**: [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)

## Support

For issues or questions:
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review service logs
3. Verify security groups and network
4. Create GitHub issue with details

---

**Tip**: Bookmark this page for quick access to common commands!
