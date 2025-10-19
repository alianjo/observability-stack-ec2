#!/bin/bash
# Test script for observability stack
# This script tests all components and generates sample traffic

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if we're in the terraform directory
if [ ! -f "terraform.tfstate" ]; then
    echo "Error: terraform.tfstate not found. Please run this script from the terraform directory."
    exit 1
fi

echo "=========================================="
echo "Observability Stack Test Suite"
echo "=========================================="
echo ""

# Get IPs from Terraform output
print_info "Retrieving instance IPs from Terraform..."
FLASK_IP=$(terraform output -raw flask_app_public_ip 2>/dev/null)
PROMETHEUS_IP=$(terraform output -raw prometheus_public_ip 2>/dev/null)
GRAFANA_IP=$(terraform output -raw grafana_public_ip 2>/dev/null)
LOKI_IP=$(terraform output -raw loki_public_ip 2>/dev/null)

if [ -z "$FLASK_IP" ] || [ -z "$PROMETHEUS_IP" ] || [ -z "$GRAFANA_IP" ] || [ -z "$LOKI_IP" ]; then
    print_error "Failed to retrieve IPs from Terraform output"
    exit 1
fi

print_success "Retrieved all instance IPs"
echo ""

# Test Flask Application
echo "Testing Flask Application..."
echo "----------------------------"

# Test home endpoint
if curl -s -f "http://$FLASK_IP:5000/" > /dev/null; then
    print_success "Flask home endpoint is accessible"
else
    print_error "Flask home endpoint is not accessible"
fi

# Test health endpoint
if curl -s -f "http://$FLASK_IP:5000/health" > /dev/null; then
    print_success "Flask health endpoint is accessible"
else
    print_error "Flask health endpoint is not accessible"
fi

# Test metrics endpoint
if curl -s -f "http://$FLASK_IP:5000/metrics" | grep -q "flask_app_request_count"; then
    print_success "Flask metrics endpoint is working"
else
    print_error "Flask metrics endpoint is not working"
fi

echo ""

# Test Prometheus
echo "Testing Prometheus..."
echo "---------------------"

# Test Prometheus health
if curl -s -f "http://$PROMETHEUS_IP:9090/-/healthy" > /dev/null; then
    print_success "Prometheus is healthy"
else
    print_error "Prometheus is not healthy"
fi

# Test Prometheus API
if curl -s -f "http://$PROMETHEUS_IP:9090/api/v1/status/config" > /dev/null; then
    print_success "Prometheus API is accessible"
else
    print_error "Prometheus API is not accessible"
fi

# Check if Prometheus is scraping Flask app
if curl -s "http://$PROMETHEUS_IP:9090/api/v1/targets" | grep -q "flask-app"; then
    print_success "Prometheus is configured to scrape Flask app"
else
    print_error "Prometheus is not configured to scrape Flask app"
fi

echo ""

# Test Loki
echo "Testing Loki..."
echo "---------------"

# Test Loki health
if curl -s -f "http://$LOKI_IP:3100/ready" > /dev/null; then
    print_success "Loki is ready"
else
    print_error "Loki is not ready"
fi

# Test Loki API
if curl -s -f "http://$LOKI_IP:3100/loki/api/v1/labels" > /dev/null; then
    print_success "Loki API is accessible"
else
    print_error "Loki API is not accessible"
fi

echo ""

# Test Grafana
echo "Testing Grafana..."
echo "------------------"

# Test Grafana health
if curl -s -f "http://$GRAFANA_IP:3000/api/health" > /dev/null; then
    print_success "Grafana is healthy"
else
    print_error "Grafana is not healthy"
fi

# Test Grafana API
if curl -s -f "http://$GRAFANA_IP:3000/api/datasources" > /dev/null; then
    print_success "Grafana API is accessible"
else
    print_error "Grafana API is not accessible"
fi

echo ""

# Generate test traffic
echo "Generating Test Traffic..."
echo "--------------------------"

print_info "Sending 100 requests to Flask app..."

for i in {1..100}; do
    curl -s "http://$FLASK_IP:5000/api/data" > /dev/null &
    curl -s "http://$FLASK_IP:5000/api/random" > /dev/null &
    
    if [ $((i % 10)) -eq 0 ]; then
        echo -n "."
    fi
done

wait
echo ""
print_success "Sent 200 requests successfully"

# Generate some errors
print_info "Generating error traffic for testing..."
for i in {1..10}; do
    curl -s "http://$FLASK_IP:5000/api/error" > /dev/null &
done
wait
print_success "Generated 10 error requests"

echo ""

# Wait for metrics to be scraped
print_info "Waiting 15 seconds for metrics to be scraped..."
sleep 15

# Verify metrics in Prometheus
echo ""
echo "Verifying Metrics in Prometheus..."
echo "-----------------------------------"

# Check if metrics are available
METRIC_CHECK=$(curl -s "http://$PROMETHEUS_IP:9090/api/v1/query?query=flask_app_request_count" | grep -o '"status":"success"')

if [ ! -z "$METRIC_CHECK" ]; then
    print_success "Metrics are available in Prometheus"
    
    # Get total request count
    TOTAL_REQUESTS=$(curl -s "http://$PROMETHEUS_IP:9090/api/v1/query?query=sum(flask_app_request_count)" | grep -oP '"value":\[\d+,"\K[^"]+')
    if [ ! -z "$TOTAL_REQUESTS" ]; then
        print_info "Total requests recorded: $TOTAL_REQUESTS"
    fi
else
    print_error "Metrics are not available in Prometheus"
fi

echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "Access URLs:"
echo "  Flask App:  http://$FLASK_IP:5000"
echo "  Prometheus: http://$PROMETHEUS_IP:9090"
echo "  Grafana:    http://$GRAFANA_IP:3000"
echo "  Loki:       http://$LOKI_IP:3100"
echo ""
echo "Next Steps:"
echo "  1. Open Grafana at http://$GRAFANA_IP:3000"
echo "  2. Login with admin credentials"
echo "  3. View the 'Flask Application Observability' dashboard"
echo "  4. Explore metrics and logs"
echo ""
print_success "All tests completed!"
