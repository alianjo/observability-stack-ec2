# Outputs for the Observability Stack

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "flask_app_public_ip" {
  description = "Public IP of Flask application instance"
  value       = aws_instance.flask_app.public_ip
}

output "flask_app_private_ip" {
  description = "Private IP of Flask application instance"
  value       = aws_instance.flask_app.private_ip
}

output "prometheus_public_ip" {
  description = "Public IP of Prometheus instance"
  value       = aws_instance.prometheus.public_ip
}

output "prometheus_private_ip" {
  description = "Private IP of Prometheus instance"
  value       = aws_instance.prometheus.private_ip
}

output "grafana_public_ip" {
  description = "Public IP of Grafana instance"
  value       = aws_instance.grafana.public_ip
}

output "grafana_private_ip" {
  description = "Private IP of Grafana instance"
  value       = aws_instance.grafana.private_ip
}

output "loki_public_ip" {
  description = "Public IP of Loki instance"
  value       = aws_instance.loki.public_ip
}

output "loki_private_ip" {
  description = "Private IP of Loki instance"
  value       = aws_instance.loki.private_ip
}

output "flask_app_url" {
  description = "URL to access Flask application"
  value       = "http://${aws_instance.flask_app.public_ip}:5000"
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${aws_instance.prometheus.public_ip}:9090"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://${aws_instance.grafana.public_ip}:3000"
}

output "loki_url" {
  description = "URL to access Loki"
  value       = "http://${aws_instance.loki.public_ip}:3100"
}

output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = {
    flask_app  = "ssh -i <your-key.pem> ubuntu@${aws_instance.flask_app.public_ip}"
    prometheus = "ssh -i <your-key.pem> ubuntu@${aws_instance.prometheus.public_ip}"
    grafana    = "ssh -i <your-key.pem> ubuntu@${aws_instance.grafana.public_ip}"
    loki       = "ssh -i <your-key.pem> ubuntu@${aws_instance.loki.public_ip}"
  }
}
