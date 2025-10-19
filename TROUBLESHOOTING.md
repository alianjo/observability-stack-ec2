# Troubleshooting Guide

This guide helps you diagnose and fix common issues with the observability stack.

## Quick Diagnostics

### Run the Test Script

```bash
cd terraform
bash ../scripts/test_stack.sh
```

This will test all components and report any issues.

## Common Issues

### 1. Cannot Access Services

#### Symptoms
- Connection timeout when accessing URLs
- "Connection refused" errors
- Services not responding

#### Diagnosis

```bash
# Check if instances are running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=observability-stack-*" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress]' \
  --output table

# Test connectivity
FLASK_IP=$(terraform output -raw flask_app_public_ip)
nc -zv $FLASK_IP 5000
```

#### Solutions

**A. Check Security Groups**

```bash
# Get your current IP
MY_IP=$(curl -s ifconfig.me)
echo "Your IP: $MY_IP"

# Update terraform.tfvars
allowed_ssh_cidr = "$MY_IP/32"
allowed_web_cidr = "$MY_IP/32"

# Apply changes
terraform apply
```

**B. Verify Instance State**

```bash
# If instances are stopped, start them
aws ec2 start-instances --instance-ids <instance-id>

# Wait for running state
aws ec2 wait instance-running --instance-ids <instance-id>
```

**C. Check Service Status**

```bash
# SSH into instance
ssh -i your-key.pem ubuntu@<instance-ip>

# Check service
sudo systemctl status flask-app  # or prometheus, loki, grafana-server

# Restart if needed
sudo systemctl restart flask-app
```

---

### 2. Services Not Starting

#### Symptoms
- Service status shows "failed" or "inactive"
- Services crash immediately after starting
- Error messages in logs

#### Diagnosis

```bash
# SSH into the instance
ssh -i your-key.pem ubuntu@<instance-ip>

# Check service status
sudo systemctl status <service-name>

# View service logs
sudo journalctl -u <service-name> -n 50 --no-pager

# Check user data execution
sudo cat /var/log/cloud-init-output.log
```

#### Solutions

**A. Flask App Not Starting**

```bash
# Check if Python dependencies are installed
pip3 list | grep -E "Flask|prometheus"

# Reinstall dependencies
cd /opt/flask-app
sudo pip3 install -r requirements.txt

# Check log file permissions
sudo ls -la /var/log/app.log
sudo chmod 666 /var/log/app.log

# Restart service
sudo systemctl restart flask-app
```

**B. Prometheus Not Starting**

```bash
# Check configuration syntax
/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml

# Check file permissions
sudo ls -la /etc/prometheus/
sudo ls -la /var/lib/prometheus/

# Fix permissions if needed
sudo chown -R prometheus:prometheus /etc/prometheus/
sudo chown -R prometheus:prometheus /var/lib/prometheus/

# Restart service
sudo systemctl restart prometheus
```

**C. Loki Not Starting**

```bash
# Check configuration syntax
/usr/local/bin/loki -config.file=/etc/loki/config.yml -verify-config

# Check file permissions
sudo ls -la /etc/loki/
sudo ls -la /var/lib/loki/

# Fix permissions if needed
sudo chown -R loki:loki /etc/loki/
sudo chown -R loki:loki /var/lib/loki/

# Restart service
sudo systemctl restart loki
```

**D. Grafana Not Starting**

```bash
# Check Grafana logs
sudo journalctl -u grafana-server -n 100

# Check configuration
sudo grafana-cli admin reset-admin-password newpassword

# Restart service
sudo systemctl restart grafana-server
```

---

### 3. Prometheus Not Scraping Metrics

#### Symptoms
- Targets show as "DOWN" in Prometheus UI
- No metrics data in Grafana
- Empty graphs in dashboard

#### Diagnosis

```bash
# Check Prometheus targets
# Open: http://<prometheus-ip>:9090/targets

# SSH into Prometheus instance
ssh -i your-key.pem ubuntu@<prometheus-ip>

# Test connectivity to Flask app
FLASK_PRIVATE_IP=$(terraform output -raw flask_app_private_ip)
curl http://$FLASK_PRIVATE_IP:5000/metrics
```

#### Solutions

**A. Flask App Not Accessible**

```bash
# Check Flask app is running
ssh -i your-key.pem ubuntu@<flask-app-ip>
sudo systemctl status flask-app

# Check Flask app is listening
sudo netstat -tlnp | grep 5000

# Test from Prometheus instance
curl http://<flask-private-ip>:5000/metrics
```

**B. Wrong IP in Configuration**

```bash
# SSH into Prometheus instance
ssh -i your-key.pem ubuntu@<prometheus-ip>

# Check configuration
sudo cat /etc/prometheus/prometheus.yml

# Verify Flask app IP is correct
# Should match: terraform output flask_app_private_ip

# If wrong, update and restart
sudo systemctl restart prometheus
```

**C. Security Group Issue**

```bash
# Verify security group allows Prometheus to Flask app
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=observability-stack-flask-app-sg" \
  --query 'SecurityGroups[].IpPermissions[]'

# Should show ingress from Prometheus security group on port 5000
```

---

### 4. No Logs in Grafana/Loki

#### Symptoms
- Loki datasource works but no logs appear
- Empty log panels in Grafana
- LogQL queries return no results

#### Diagnosis

```bash
# SSH into Flask app instance
ssh -i your-key.pem ubuntu@<flask-app-ip>

# Check Promtail status
sudo systemctl status promtail

# Check if log file exists and has content
ls -la /var/log/app.log
tail -f /var/log/app.log

# Check Promtail logs
sudo journalctl -u promtail -n 50
```

#### Solutions

**A. Promtail Not Running**

```bash
# Start Promtail
sudo systemctl start promtail

# Enable on boot
sudo systemctl enable promtail

# Check status
sudo systemctl status promtail
```

**B. Promtail Cannot Reach Loki**

```bash
# Test connectivity from Flask app to Loki
LOKI_PRIVATE_IP=$(terraform output -raw loki_private_ip)
curl http://$LOKI_PRIVATE_IP:3100/ready

# Check Promtail configuration
sudo cat /etc/promtail/config.yml

# Verify Loki URL is correct
# Should match: http://<loki-private-ip>:3100
```

**C. Log File Permissions**

```bash
# Check log file permissions
ls -la /var/log/app.log

# Fix if needed
sudo chmod 644 /var/log/app.log

# Restart Promtail
sudo systemctl restart promtail
```

**D. No Logs Being Generated**

```bash
# Generate some traffic to Flask app
FLASK_IP=$(terraform output -raw flask_app_public_ip)
for i in {1..10}; do curl http://$FLASK_IP:5000/api/data; done

# Check if logs are being written
tail -f /var/log/app.log

# Should see new log entries
```

---

### 5. Grafana Dashboard Shows No Data

#### Symptoms
- Dashboard loads but panels are empty
- "No data" messages in panels
- Datasource connection fails

#### Diagnosis

```bash
# SSH into Grafana instance
ssh -i your-key.pem ubuntu@<grafana-ip>

# Test Prometheus connectivity
PROMETHEUS_PRIVATE_IP=$(terraform output -raw prometheus_private_ip)
curl http://$PROMETHEUS_PRIVATE_IP:9090/api/v1/query?query=up

# Test Loki connectivity
LOKI_PRIVATE_IP=$(terraform output -raw loki_private_ip)
curl http://$LOKI_PRIVATE_IP:3100/ready
```

#### Solutions

**A. Datasource Not Configured**

1. Open Grafana: `http://<grafana-ip>:3000`
2. Go to Configuration > Data Sources
3. Check if Prometheus and Loki are listed
4. Test each datasource connection
5. If failed, update URL and save

**B. Wrong Time Range**

1. In dashboard, check time range (top right)
2. Set to "Last 15 minutes" or "Last 1 hour"
3. Ensure there's data in that time range

**C. No Metrics/Logs Available**

```bash
# Generate traffic to create metrics and logs
cd terraform
bash ../scripts/generate_load.sh 60 5

# Wait 30 seconds for data to be scraped
sleep 30

# Refresh Grafana dashboard
```

**D. Query Errors**

1. Open Grafana Explore view
2. Select Prometheus datasource
3. Try simple query: `up`
4. Should return results
5. Try Flask metric: `flask_app_request_count`

---

### 6. High AWS Costs

#### Symptoms
- Unexpected AWS charges
- Bill higher than expected

#### Diagnosis

```bash
# Check running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check instance hours
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

#### Solutions

**A. Stop Instances When Not in Use**

```bash
# Stop all instances
cd terraform
terraform destroy

# Or stop individual instances
aws ec2 stop-instances --instance-ids <instance-id>
```

**B. Use Smaller Instance Types**

```bash
# Edit terraform.tfvars
instance_type = "t3.micro"  # Instead of t3.small

# Apply changes
terraform apply
```

**C. Set Up Billing Alerts**

```bash
# Create billing alarm (requires AWS CLI and SNS topic)
aws cloudwatch put-metric-alarm \
  --alarm-name observability-stack-billing \
  --alarm-description "Alert when costs exceed $50" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold
```

---

### 7. Terraform Apply Fails

#### Symptoms
- Terraform apply returns errors
- Resources fail to create
- State conflicts

#### Common Errors and Solutions

**A. "Error: creating EC2 Instance: InvalidKeyPair.NotFound"**

```bash
# Key pair doesn't exist
# Create it first:
aws ec2 create-key-pair --key-name observability-key \
  --query 'KeyMaterial' --output text > observability-key.pem
chmod 400 observability-key.pem

# Or remove key_name from terraform.tfvars
key_name = ""
```

**B. "Error: creating VPC: VpcLimitExceeded"**

```bash
# Too many VPCs in region
# Delete unused VPCs or use different region

# List VPCs
aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,Tags[?Key==`Name`].Value|[0]]'

# Delete unused VPC
aws ec2 delete-vpc --vpc-id vpc-xxxxx
```

**C. "Error: creating Security Group: InvalidGroup.Duplicate"**

```bash
# Security group already exists
# Import existing or destroy and recreate

# Destroy existing resources
terraform destroy

# Then apply again
terraform apply
```

**D. "Error: insufficient capacity"**

```bash
# AWS doesn't have capacity for instance type
# Try different availability zone or instance type

# Edit terraform.tfvars
instance_type = "t3.medium"  # Try different type

# Or change region
aws_region = "us-west-2"
```

---

### 8. Performance Issues

#### Symptoms
- Slow dashboard loading
- High latency in queries
- Services consuming too much CPU/memory

#### Diagnosis

```bash
# SSH into instance
ssh -i your-key.pem ubuntu@<instance-ip>

# Check resource usage
top
htop  # If installed

# Check disk usage
df -h

# Check memory
free -h

# Check network
netstat -s
```

#### Solutions

**A. Increase Instance Size**

```bash
# Edit terraform.tfvars
instance_type = "t3.medium"  # Or t3.large

# Apply changes
terraform apply
```

**B. Optimize Prometheus Retention**

```bash
# SSH into Prometheus instance
ssh -i your-key.pem ubuntu@<prometheus-ip>

# Edit systemd service
sudo nano /etc/systemd/system/prometheus.service

# Add retention flags:
# --storage.tsdb.retention.time=7d
# --storage.tsdb.retention.size=5GB

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart prometheus
```

**C. Optimize Loki Retention**

```bash
# SSH into Loki instance
ssh -i your-key.pem ubuntu@<loki-ip>

# Edit configuration
sudo nano /etc/loki/config.yml

# Update retention:
# table_manager:
#   retention_deletes_enabled: true
#   retention_period: 168h  # 7 days

# Restart Loki
sudo systemctl restart loki
```

---

## Debugging Commands

### Check All Services

```bash
# Create a script to check all services
cat > check_services.sh << 'EOF'
#!/bin/bash
echo "Flask App:"
curl -s http://$(terraform output -raw flask_app_public_ip):5000/health | jq
echo ""
echo "Prometheus:"
curl -s http://$(terraform output -raw prometheus_public_ip):9090/-/healthy
echo ""
echo "Loki:"
curl -s http://$(terraform output -raw loki_public_ip):3100/ready
echo ""
echo "Grafana:"
curl -s http://$(terraform output -raw grafana_public_ip):3000/api/health | jq
EOF

chmod +x check_services.sh
./check_services.sh
```

### View All Logs

```bash
# Flask App
ssh -i key.pem ubuntu@<flask-ip> 'sudo journalctl -u flask-app -f'

# Prometheus
ssh -i key.pem ubuntu@<prometheus-ip> 'sudo journalctl -u prometheus -f'

# Loki
ssh -i key.pem ubuntu@<loki-ip> 'sudo journalctl -u loki -f'

# Grafana
ssh -i key.pem ubuntu@<grafana-ip> 'sudo journalctl -u grafana-server -f'
```

### Test Connectivity Between Instances

```bash
# From Prometheus to Flask App
ssh -i key.pem ubuntu@<prometheus-ip>
curl http://<flask-private-ip>:5000/metrics

# From Grafana to Prometheus
ssh -i key.pem ubuntu@<grafana-ip>
curl http://<prometheus-private-ip>:9090/api/v1/query?query=up

# From Grafana to Loki
ssh -i key.pem ubuntu@<grafana-ip>
curl http://<loki-private-ip>:3100/ready

# From Flask App to Loki (Promtail)
ssh -i key.pem ubuntu@<flask-ip>
curl http://<loki-private-ip>:3100/ready
```

---

## Getting Help

### Collect Diagnostic Information

```bash
# Create diagnostic report
cat > diagnostic_report.sh << 'EOF'
#!/bin/bash
echo "=== Terraform State ==="
terraform output

echo ""
echo "=== AWS Instances ==="
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=observability-stack-*" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress,PrivateIpAddress]' \
  --output table

echo ""
echo "=== Security Groups ==="
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=observability-stack-*" \
  --query 'SecurityGroups[].[GroupName,GroupId]' \
  --output table

echo ""
echo "=== Service Health ==="
./check_services.sh
EOF

chmod +x diagnostic_report.sh
./diagnostic_report.sh > diagnostic_report.txt
```

### Useful Resources

- [Prometheus Troubleshooting](https://prometheus.io/docs/prometheus/latest/troubleshooting/)
- [Grafana Troubleshooting](https://grafana.com/docs/grafana/latest/troubleshooting/)
- [Loki Troubleshooting](https://grafana.com/docs/loki/latest/operations/troubleshooting/)
- [AWS EC2 Troubleshooting](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-troubleshoot.html)
- [Terraform Troubleshooting](https://www.terraform.io/docs/cli/commands/index.html)

### Community Support

- GitHub Issues: [Create an issue](https://github.com/your-repo/issues)
- Stack Overflow: Tag with `prometheus`, `grafana`, `loki`, `terraform`
- AWS Support: For AWS-specific issues

---

## Prevention Tips

1. **Always test in dev first**: Don't deploy directly to production
2. **Use version control**: Commit all configuration changes
3. **Monitor costs**: Set up billing alerts
4. **Regular backups**: Backup Prometheus and Loki data
5. **Keep updated**: Regularly update software versions
6. **Document changes**: Keep notes of any modifications
7. **Test after changes**: Run test script after any updates
8. **Use proper security**: Don't use 0.0.0.0/0 in production
9. **Set up alerting**: Get notified of issues automatically
10. **Review logs regularly**: Check for warnings and errors
