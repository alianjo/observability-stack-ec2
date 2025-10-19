# Deployment Guide - AWS EC2 Observability Stack

This guide provides step-by-step instructions for deploying the observability stack.

## Prerequisites Checklist

- [ ] AWS Account with appropriate permissions
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] (Optional) SSH key pair for EC2 access

## Step-by-Step Deployment

### Step 1: Verify AWS Credentials

```bash
# Check if AWS CLI is configured
aws sts get-caller-identity

# Expected output should show your AWS account details
```

### Step 2: Create SSH Key Pair (Optional but Recommended)

```bash
# Create a new key pair
aws ec2 create-key-pair \
  --key-name observability-key \
  --query 'KeyMaterial' \
  --output text > observability-key.pem

# Set proper permissions
chmod 400 observability-key.pem

# Verify key was created
aws ec2 describe-key-pairs --key-names observability-key
```

### Step 3: Prepare Terraform Configuration

```bash
# Navigate to terraform directory
cd terraform

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file
nano terraform.tfvars  # or use your preferred editor
```

**Important Variables to Configure:**

```hcl
# Set your AWS region
aws_region = "us-east-1"

# Set your SSH key name (from Step 2)
key_name = "observability-key"

# Restrict access to your IP for security
# Get your IP: curl ifconfig.me
allowed_ssh_cidr = "YOUR_IP/32"
allowed_web_cidr = "YOUR_IP/32"

# Set a strong Grafana password
grafana_admin_password = "YourSecurePassword123!"

# Choose instance size (t3.micro for testing, t3.small for demo)
instance_type = "t3.small"
```

### Step 4: Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init

# Expected output: "Terraform has been successfully initialized!"
```

### Step 5: Review the Deployment Plan

```bash
# Generate and review the execution plan
terraform plan

# Review the output carefully
# You should see:
# - 1 VPC
# - 2 Subnets (public and private)
# - 1 Internet Gateway
# - 4 Security Groups
# - 4 EC2 Instances
# - Route tables and associations
```

### Step 6: Deploy the Stack

```bash
# Apply the configuration
terraform apply

# Type 'yes' when prompted to confirm
```

**Deployment Time**: Approximately 5-10 minutes

The deployment process will:
1. Create networking infrastructure (VPC, subnets, IGW)
2. Create security groups with appropriate rules
3. Launch 4 EC2 instances
4. Run user data scripts to install and configure services
5. Configure Prometheus, Loki, Grafana, and Flask app

### Step 7: Verify Deployment

```bash
# Get all outputs
terraform output

# Get specific outputs
terraform output flask_app_url
terraform output prometheus_url
terraform output grafana_url
terraform output loki_url
```

### Step 8: Wait for Services to Initialize

After Terraform completes, services need additional time to install and start:

```bash
# Wait 3-5 minutes for all services to fully initialize
# You can monitor progress by SSH'ing into instances

# Example: Check Flask app status
FLASK_IP=$(terraform output -raw flask_app_public_ip)
ssh -i ../observability-key.pem ubuntu@$FLASK_IP

# On the instance, check service status
sudo systemctl status flask-app
sudo systemctl status promtail

# Check user data execution log
sudo tail -f /var/log/cloud-init-output.log

# Exit the SSH session
exit
```

### Step 9: Verify Each Service

#### Test Flask Application

```bash
FLASK_IP=$(terraform output -raw flask_app_public_ip)

# Test home endpoint
curl http://$FLASK_IP:5000/

# Test health endpoint
curl http://$FLASK_IP:5000/health

# Test metrics endpoint
curl http://$FLASK_IP:5000/metrics

# Expected: JSON responses and Prometheus metrics
```

#### Test Prometheus

```bash
PROMETHEUS_IP=$(terraform output -raw prometheus_public_ip)

# Open in browser
echo "Prometheus UI: http://$PROMETHEUS_IP:9090"

# Or test with curl
curl http://$PROMETHEUS_IP:9090/-/healthy

# Expected: "Prometheus is Healthy."
```

**In Prometheus UI:**
1. Go to Status > Targets
2. Verify both targets (prometheus, flask-app) are UP
3. Go to Graph tab
4. Query: `flask_app_request_count`
5. Should see metrics data

#### Test Loki

```bash
LOKI_IP=$(terraform output -raw loki_public_ip)

# Test Loki health
curl http://$LOKI_IP:3100/ready

# Expected: "ready"

# Query logs (requires some time for logs to accumulate)
curl -G -s "http://$LOKI_IP:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="flask-app"}' | jq
```

#### Test Grafana

```bash
GRAFANA_IP=$(terraform output -raw grafana_public_ip)

# Open in browser
echo "Grafana UI: http://$GRAFANA_IP:3000"

# Test Grafana API
curl http://$GRAFANA_IP:3000/api/health

# Expected: {"commit":"...","database":"ok","version":"..."}
```

**In Grafana UI:**
1. Navigate to `http://<grafana-ip>:3000`
2. Login with:
   - Username: `admin`
   - Password: (value from terraform.tfvars)
3. Go to Dashboards
4. Open "Flask Application Observability"
5. Verify metrics and logs are displayed

### Step 10: Generate Test Traffic

```bash
FLASK_IP=$(terraform output -raw flask_app_public_ip)

# Simple requests
for i in {1..100}; do
  curl -s http://$FLASK_IP:5000/api/data > /dev/null
  curl -s http://$FLASK_IP:5000/api/random > /dev/null
  sleep 0.1
done

# Generate some errors
for i in {1..10}; do
  curl -s http://$FLASK_IP:5000/api/error > /dev/null
done

# Using Apache Bench (if installed)
ab -n 1000 -c 10 http://$FLASK_IP:5000/api/data
```

### Step 11: Explore the Dashboard

In Grafana, you should now see:

1. **Request Rate**: Increasing as you generate traffic
2. **Active Requests**: Showing concurrent requests
3. **Request Duration**: P50, P95, P99 percentiles
4. **Requests by Status Code**: 2xx, 4xx, 5xx breakdown
5. **Requests by Endpoint**: Traffic distribution
6. **Error Rate**: Errors per second
7. **Application Logs**: Real-time log stream
8. **Error Logs**: Filtered error messages

## Troubleshooting Deployment Issues

### Issue: Terraform Apply Fails

**Symptoms**: Error during `terraform apply`

**Solutions**:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify region availability
aws ec2 describe-availability-zones --region us-east-1

# Check for resource limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A

# Review detailed error in Terraform output
```

### Issue: Cannot Access Services

**Symptoms**: Connection timeout when accessing URLs

**Solutions**:
```bash
# 1. Verify instances are running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=observability-stack-*" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' \
  --output table

# 2. Check security groups
# Ensure your current IP is allowed
curl ifconfig.me  # Get your current IP

# 3. Verify security group rules
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=observability-stack-*" \
  --query 'SecurityGroups[].[GroupName,GroupId]'

# 4. Test connectivity
FLASK_IP=$(terraform output -raw flask_app_public_ip)
nc -zv $FLASK_IP 5000
```

### Issue: Services Not Starting

**Symptoms**: Services return connection refused

**Solutions**:
```bash
# SSH into the instance
ssh -i observability-key.pem ubuntu@<instance-ip>

# Check service status
sudo systemctl status flask-app      # or prometheus, loki, grafana-server

# View service logs
sudo journalctl -u flask-app -n 100 --no-pager

# Check user data execution
sudo cat /var/log/cloud-init-output.log

# Restart service if needed
sudo systemctl restart flask-app
```

### Issue: Prometheus Not Scraping

**Symptoms**: Targets show as DOWN in Prometheus

**Solutions**:
```bash
# 1. Check Prometheus targets
# Open: http://<prometheus-ip>:9090/targets

# 2. Verify Flask app is accessible from Prometheus instance
ssh -i observability-key.pem ubuntu@<prometheus-ip>
curl http://<flask-private-ip>:5000/metrics

# 3. Check Prometheus configuration
sudo cat /etc/prometheus/prometheus.yml

# 4. Restart Prometheus
sudo systemctl restart prometheus
```

### Issue: No Logs in Grafana

**Symptoms**: Loki datasource works but no logs appear

**Solutions**:
```bash
# 1. Check Promtail on Flask app instance
ssh -i observability-key.pem ubuntu@<flask-app-ip>
sudo systemctl status promtail

# 2. Verify Promtail can reach Loki
curl http://<loki-private-ip>:3100/ready

# 3. Check Promtail logs
sudo journalctl -u promtail -n 100

# 4. Verify log file exists
ls -la /var/log/app.log

# 5. Check Promtail configuration
sudo cat /etc/promtail/config.yml

# 6. Restart Promtail
sudo systemctl restart promtail
```

### Issue: High Costs

**Symptoms**: Unexpected AWS charges

**Solutions**:
```bash
# 1. Check running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime]' \
  --output table

# 2. Stop instances when not in use
terraform destroy  # Destroys all resources

# Or stop individual instances
aws ec2 stop-instances --instance-ids i-xxxxx

# 3. Use smaller instance types for testing
# Edit terraform.tfvars:
instance_type = "t3.micro"

# Apply changes
terraform apply
```

## Post-Deployment Configuration

### Configure Alerting (Optional)

1. **Install Alertmanager**:
```bash
ssh -i observability-key.pem ubuntu@<prometheus-ip>
# Follow Alertmanager installation guide
```

2. **Create Alert Rules**:
```yaml
# /etc/prometheus/rules/alerts.yml
groups:
  - name: flask_app
    rules:
      - alert: HighErrorRate
        expr: rate(flask_app_error_count[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
```

### Set Up Backup (Optional)

```bash
# Backup Prometheus data
ssh -i observability-key.pem ubuntu@<prometheus-ip>
sudo tar -czf prometheus-backup.tar.gz /var/lib/prometheus/

# Backup Grafana dashboards
ssh -i observability-key.pem ubuntu@<grafana-ip>
sudo tar -czf grafana-backup.tar.gz /var/lib/grafana/
```

### Configure Log Retention

```bash
# Edit Loki configuration for retention
ssh -i observability-key.pem ubuntu@<loki-ip>
sudo nano /etc/loki/config.yml

# Update retention settings:
# table_manager:
#   retention_deletes_enabled: true
#   retention_period: 168h  # 7 days

sudo systemctl restart loki
```

## Cleanup

### Destroy All Resources

```bash
cd terraform

# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Type 'yes' when prompted

# Verify all resources are deleted
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=observability-stack-*" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]'
```

### Delete SSH Key Pair

```bash
# Delete from AWS
aws ec2 delete-key-pair --key-name observability-key

# Delete local file
rm observability-key.pem
```

## Next Steps

1. **Customize the Flask Application**: Modify `app/app.py` to add your own endpoints and metrics
2. **Create Custom Dashboards**: Build dashboards specific to your use case
3. **Set Up Alerting**: Configure Alertmanager for critical alerts
4. **Implement High Availability**: Use Auto Scaling Groups and Load Balancers
5. **Add More Services**: Extend the stack with additional microservices
6. **Implement CI/CD**: Automate deployments with GitHub Actions or GitLab CI

## Support

For issues or questions:
1. Check the main README.md
2. Review Terraform output for error messages
3. Check service logs on EC2 instances
4. Consult official documentation for each component

## Security Reminders

- [ ] Change default Grafana password
- [ ] Restrict security group rules to your IP
- [ ] Use SSH keys for instance access
- [ ] Enable CloudWatch monitoring
- [ ] Set up billing alerts
- [ ] Regular security updates on instances
- [ ] Use AWS Secrets Manager for sensitive data
- [ ] Enable VPC Flow Logs
- [ ] Implement backup strategy
- [ ] Review IAM permissions regularly
