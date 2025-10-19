#!/bin/bash
# Load generation script for testing observability stack

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Check if we're in the terraform directory
if [ ! -f "terraform.tfstate" ]; then
    echo "Error: terraform.tfstate not found. Please run this script from the terraform directory."
    exit 1
fi

# Get Flask app IP
FLASK_IP=$(terraform output -raw flask_app_public_ip 2>/dev/null)

if [ -z "$FLASK_IP" ]; then
    echo "Error: Could not retrieve Flask app IP"
    exit 1
fi

echo "=========================================="
echo "Load Generation Script"
echo "=========================================="
echo ""
print_info "Target: http://$FLASK_IP:5000"
echo ""

# Parse command line arguments
DURATION=${1:-60}  # Default 60 seconds
RPS=${2:-10}       # Default 10 requests per second

print_info "Duration: ${DURATION} seconds"
print_info "Rate: ${RPS} requests per second"
echo ""

# Calculate total requests
TOTAL_REQUESTS=$((DURATION * RPS))
SLEEP_TIME=$(echo "scale=3; 1/$RPS" | bc)

print_info "Will send approximately $TOTAL_REQUESTS requests"
echo ""

# Endpoints to test
ENDPOINTS=(
    "/api/data"
    "/api/random"
    "/health"
    "/"
)

# Start time
START_TIME=$(date +%s)
REQUEST_COUNT=0
ERROR_COUNT=0

print_info "Starting load generation..."
echo ""

# Generate load
while [ $(($(date +%s) - START_TIME)) -lt $DURATION ]; do
    # Select random endpoint
    ENDPOINT=${ENDPOINTS[$RANDOM % ${#ENDPOINTS[@]}]}
    
    # Send request in background
    if curl -s -f "http://$FLASK_IP:5000$ENDPOINT" > /dev/null 2>&1; then
        REQUEST_COUNT=$((REQUEST_COUNT + 1))
    else
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
    
    # Occasionally trigger an error endpoint
    if [ $((RANDOM % 20)) -eq 0 ]; then
        curl -s "http://$FLASK_IP:5000/api/error" > /dev/null 2>&1 &
    fi
    
    # Print progress every 10 requests
    if [ $((REQUEST_COUNT % 10)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        echo -ne "\rElapsed: ${ELAPSED}s | Requests: $REQUEST_COUNT | Errors: $ERROR_COUNT"
    fi
    
    # Sleep to maintain rate
    sleep $SLEEP_TIME
done

# Final statistics
echo ""
echo ""
echo "=========================================="
echo "Load Generation Complete"
echo "=========================================="
echo ""
print_success "Total requests sent: $REQUEST_COUNT"
print_info "Failed requests: $ERROR_COUNT"
print_info "Success rate: $(echo "scale=2; ($REQUEST_COUNT - $ERROR_COUNT) * 100 / $REQUEST_COUNT" | bc)%"
echo ""
print_info "View metrics at: http://$(terraform output -raw prometheus_public_ip):9090"
print_info "View dashboard at: http://$(terraform output -raw grafana_public_ip):3000"
echo ""
