# AWS EC2 Observability Stack with Terraform

A complete observability stack deployed on AWS EC2 using Terraform, featuring Prometheus for metrics, Loki for logs, Grafana for visualization, and a sample Flask application.

## 🏗️ Architecture

This stack consists of four EC2 instances:

1. **Flask Application Server**: Python Flask app exposing Prometheus metrics and writing logs
2. **Prometheus Server**: Scrapes metrics from the Flask application
3. **Loki Server**: Collects and stores logs from the Flask application
4. **Grafana Server**: Visualizes metrics from Prometheus and logs from Loki

### Architecture Diagram

```
┌─────────────────┐
│  Flask App      │
│  - Port 5000    │◄──────┐
│  - Metrics      │       │
│  - Logs         │       │
└────────┬────────┘       │
         │                │
         │ Promtail       │ Scrape
         │                │
         ▼                │
┌─────────────────┐  ┌────┴──────────┐
│  Loki           │  │  Prometheus   │
│  - Port 3100    │  │  - Port 9090  │
│  - Log Storage  │  │  - Metrics DB │
└────────┬────────┘  └────┬──────────┘
         │                │
         │                │
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │  Grafana       │
         │  - Port 3000   │
         │  - Dashboards  │
         └────────────────┘
```

## 📋 Prerequisites

- **Terraform**: >= 1.0
- **AWS Account**: With appropriate permissions to create VPC, EC2, Security Groups
- **AWS CLI**: Configured with credentials
- **SSH Key Pair**: (Optional) For EC2 instance access

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd observability-stack-ec2
```

### 2. Configure AWS Credentials

```bash
aws configure
```

### 3. Create SSH Key Pair (Optional)

```bash
aws ec2 create-key-pair --key-name observability-key --query 'KeyMaterial' --output text > observability-key.pem
chmod 400 observability-key.pem
```

### 4. Initialize Terraform

```bash
cd terraform
terraform init
```

### 5. Review and Customize Variables

Edit `terraform.tfvars` (create if it doesn't exist):

```hcl
aws_region              = "us-east-1"
project_name            = "observability-stack"
instance_type           = "t3.small"
key_name                = "observability-key"  # Your SSH key name
allowed_ssh_cidr        = "YOUR_IP/32"         # Your IP for SSH access
allowed_web_cidr        = "YOUR_IP/32"         # Your IP for web access
grafana_admin_password  = "your-secure-password"
```

### 6. Deploy the Stack

```bash
terraform plan
terraform apply
```

This will take approximately 5-10 minutes to provision all resources and install software.

### 7. Access the Services

After deployment completes, Terraform will output the URLs:

```bash
terraform output
```

You'll see:
- **Flask App**: `http://<flask-ip>:5000`
- **Prometheus**: `http://<prometheus-ip>:9090`
- **Grafana**: `http://<grafana-ip>:3000`
- **Loki**: `http://<loki-ip>:3100`

## 🔐 Default Credentials

### Grafana
- **Username**: `admin`
- **Password**: Value of `grafana_admin_password` variable (default: `admin123`)

## 📊 Using the Stack

### Access Grafana Dashboard

1. Navigate to Grafana URL: `http://<grafana-ip>:3000`
2. Login with admin credentials
3. The dashboard "Flask Application Observability" is pre-configured
4. You'll see:
   - Request rate metrics
   - Active requests gauge
   - Request duration percentiles
   - Status code distribution
   - Application logs

### Test the Flask Application

Generate some traffic to see metrics:

```bash
# Get Flask app IP
FLASK_IP=$(terraform output -raw flask_app_public_ip)

# Test endpoints
curl http://$FLASK_IP:5000/
curl http://$FLASK_IP:5000/health
curl http://$FLASK_IP:5000/api/data
curl http://$FLASK_IP:5000/api/random
curl http://$FLASK_IP:5000/api/error  # Generates errors for testing
```

### Generate Load for Testing

```bash
# Install Apache Bench (if not installed)
sudo apt-get install apache2-utils  # Ubuntu/Debian
# or
brew install httpd  # macOS

# Generate load
ab -n 1000 -c 10 http://$FLASK_IP:5000/api/data
```

### View Prometheus Metrics

Navigate to `http://<prometheus-ip>:9090` and query:

```promql
# Request rate
rate(flask_app_request_count[5m])

# Active requests
flask_app_active_requests

# Request duration (95th percentile)
histogram_quantile(0.95, rate(flask_app_request_duration_seconds_bucket[5m]))

# Error rate
rate(flask_app_error_count[5m])
```

### Query Logs in Grafana

In Grafana's Explore view with Loki datasource:

```logql
# All logs
{job="flask-app"}

# Error logs only
{job="flask-app"} |~ "ERROR|error"

# Logs for specific endpoint
{job="flask-app"} |~ "/api/data"
```

## 📁 Project Structure

```
observability-stack-ec2/
├── terraform/
│   ├── main.tf           # Main Terraform configuration
│   ├── variables.tf      # Variable definitions
│   └── outputs.tf        # Output definitions
├── scripts/
│   ├── flask_app_userdata.sh    # Flask app setup script
│   ├── prometheus_userdata.sh   # Prometheus setup script
│   ├── loki_userdata.sh         # Loki setup script
│   └── grafana_userdata.sh      # Grafana setup script
├── app/
│   ├── app.py            # Flask application
│   └── requirements.txt  # Python dependencies
├── configs/
│   ├── prometheus.yml    # Prometheus configuration template
│   ├── loki.yml          # Loki configuration template
│   └── promtail.yml      # Promtail configuration template
├── dashboards/
│   └── flask-observability-dashboard.json  # Grafana dashboard
└── README.md
```

## 🔧 Configuration Details

### Flask Application

The Flask application (`app/app.py`) includes:

- **Endpoints**:
  - `/` - Home page with endpoint list
  - `/health` - Health check endpoint
  - `/metrics` - Prometheus metrics endpoint
  - `/api/data` - Sample data endpoint
  - `/api/random` - Random number generator
  - `/api/error` - Error simulation endpoint

- **Metrics Exposed**:
  - `flask_app_request_count` - Total request count by method, endpoint, and status
  - `flask_app_request_duration_seconds` - Request duration histogram
  - `flask_app_active_requests` - Current active requests
  - `flask_app_error_count` - Error count by endpoint
  - `flask_app_info` - Application information

- **Logging**:
  - Logs written to `/var/log/app.log`
  - Rotating file handler (10MB max, 5 backups)
  - Shipped to Loki via Promtail

### Prometheus Configuration

- **Scrape Interval**: 15 seconds
- **Targets**:
  - Self-monitoring (localhost:9090)
  - Flask application (flask-app-ip:5000)
- **Metrics Path**: `/metrics`

### Loki Configuration

- **Storage**: Local filesystem (BoltDB + filesystem)
- **Retention**: 168 hours (7 days)
- **Ingestion Rate**: 10MB/s
- **Port**: 3100

### Grafana Configuration

- **Datasources**:
  - Prometheus (default)
  - Loki
- **Pre-configured Dashboard**: Flask Application Observability
- **Auto-provisioning**: Enabled for datasources and dashboards

## 🔒 Security Considerations

### Current Setup (Development/Testing)

The default configuration is designed for testing and includes:
- Public IP addresses on all instances
- Security groups allowing access from `0.0.0.0/0` (configurable)

### Production Recommendations

For production deployments, consider:

1. **Network Security**:
   - Place Flask app, Prometheus, and Loki in private subnets
   - Use a load balancer or bastion host for access
   - Restrict security group rules to specific IP ranges
   - Use VPC endpoints for AWS services

2. **Authentication & Authorization**:
   - Enable authentication on Prometheus
   - Use strong passwords for Grafana
   - Implement OAuth/SAML for Grafana
   - Use AWS IAM roles for EC2 instances

3. **Encryption**:
   - Enable TLS/SSL for all services
   - Encrypt data at rest
   - Use AWS KMS for secret management

4. **Monitoring & Alerting**:
   - Set up Alertmanager with Prometheus
   - Configure alert rules for critical metrics
   - Integrate with PagerDuty/Slack/etc.

5. **Backup & Recovery**:
   - Regular backups of Prometheus data
   - Loki data backup strategy
   - Grafana dashboard exports

## 🛠️ Troubleshooting

### Services Not Starting

Check service status on each instance:

```bash
# SSH into instance
ssh -i observability-key.pem ubuntu@<instance-ip>

# Check service status
sudo systemctl status flask-app      # Flask app instance
sudo systemctl status prometheus     # Prometheus instance
sudo systemctl status loki          # Loki instance
sudo systemctl status grafana-server # Grafana instance
sudo systemctl status promtail      # Flask app instance

# View logs
sudo journalctl -u flask-app -f
sudo journalctl -u prometheus -f
sudo journalctl -u loki -f
sudo journalctl -u grafana-server -f
```

### Cannot Access Services

1. **Check Security Groups**: Ensure your IP is allowed in security group rules
2. **Check Instance Status**: Verify instances are running in AWS console
3. **Check User Data Execution**: View `/var/log/cloud-init-output.log` on instances
4. **Verify Network**: Ensure internet gateway and route tables are configured

### Prometheus Not Scraping Metrics

1. Check Prometheus targets: `http://<prometheus-ip>:9090/targets`
2. Verify Flask app is accessible from Prometheus instance
3. Check security group rules between instances
4. Verify Flask app is running and exposing metrics

### Loki Not Receiving Logs

1. Check Promtail status on Flask app instance
2. Verify Loki is accessible from Flask app instance
3. Check Promtail configuration: `/etc/promtail/config.yml`
4. View Promtail logs: `sudo journalctl -u promtail -f`

### Grafana Dashboard Not Showing Data

1. Verify datasources are configured correctly in Grafana
2. Test datasource connections in Grafana settings
3. Check if Prometheus and Loki are accessible from Grafana instance
4. Verify time range in dashboard matches data availability

## 📈 Scaling Considerations

### Vertical Scaling

Increase instance size for better performance:

```hcl
instance_type = "t3.medium"  # or t3.large, t3.xlarge
```

### Horizontal Scaling

For production workloads:

1. **Flask Application**: Use Auto Scaling Group with ALB
2. **Prometheus**: Implement federation or use Thanos
3. **Loki**: Deploy in microservices mode with object storage (S3)
4. **Grafana**: Use RDS for backend database, deploy multiple instances

## 🧹 Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

**Warning**: This will permanently delete all resources including data stored in Prometheus and Loki.

## 💰 Cost Estimation

Approximate monthly costs (us-east-1 region):

- **4 x t3.small EC2 instances**: ~$60/month (24/7 operation)
- **EBS volumes**: ~$4/month (30GB total)
- **Data transfer**: Varies based on usage
- **Total**: ~$64-70/month

**Cost Optimization Tips**:
- Use t3.micro for testing (~$30/month for 4 instances)
- Stop instances when not in use
- Use spot instances for non-production
- Set up billing alerts

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

This project is provided as-is for educational and demonstration purposes.

## ⚠️ Disclaimer

This stack is designed for learning and testing purposes. For production use, additional security hardening, high availability, and monitoring configurations are recommended.
