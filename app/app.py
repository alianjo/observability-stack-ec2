#!/usr/bin/env python3
"""
Flask Application with Prometheus Metrics and Logging
This application exposes metrics for Prometheus and writes logs to a file.
"""

import logging
import time
import random
from flask import Flask, Response, jsonify
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from logging.handlers import RotatingFileHandler
import os

# Create Flask application
app = Flask(__name__)

# Configure logging
log_dir = '/var/log'
log_file = os.path.join(log_dir, 'app.log')

# Ensure log directory exists
os.makedirs(log_dir, exist_ok=True)

# Set up logging with rotation
handler = RotatingFileHandler(log_file, maxBytes=10485760, backupCount=5)
handler.setLevel(logging.INFO)
formatter = logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
handler.setFormatter(formatter)

# Configure root logger
logging.basicConfig(
    level=logging.INFO,
    handlers=[handler, logging.StreamHandler()]
)

logger = logging.getLogger(__name__)

# Prometheus Metrics
request_count = Counter(
    'flask_app_request_count',
    'Total number of requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'flask_app_request_duration_seconds',
    'Request duration in seconds',
    ['method', 'endpoint']
)

active_requests = Gauge(
    'flask_app_active_requests',
    'Number of active requests'
)

error_count = Counter(
    'flask_app_error_count',
    'Total number of errors',
    ['endpoint']
)

app_info = Gauge(
    'flask_app_info',
    'Application information',
    ['version', 'environment']
)

# Set application info
app_info.labels(version='1.0.0', environment='production').set(1)


@app.before_request
def before_request():
    """Track request start time and increment active requests"""
    from flask import request, g
    g.start_time = time.time()
    active_requests.inc()
    logger.info(f"Incoming request: {request.method} {request.path} from {request.remote_addr}")


@app.after_request
def after_request(response):
    """Track request completion and metrics"""
    from flask import request, g
    
    # Calculate request duration
    if hasattr(g, 'start_time'):
        duration = time.time() - g.start_time
        request_duration.labels(
            method=request.method,
            endpoint=request.endpoint or 'unknown'
        ).observe(duration)
    
    # Increment request counter
    request_count.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    
    # Decrement active requests
    active_requests.dec()
    
    logger.info(f"Request completed: {request.method} {request.path} - Status: {response.status_code}")
    
    return response


@app.route('/')
def index():
    """Home endpoint"""
    logger.info("Home endpoint accessed")
    return jsonify({
        'message': 'Welcome to Flask Observability Demo',
        'endpoints': {
            '/': 'Home page',
            '/health': 'Health check',
            '/metrics': 'Prometheus metrics',
            '/api/data': 'Sample data endpoint',
            '/api/random': 'Random number generator',
            '/api/error': 'Trigger an error (for testing)'
        }
    })


@app.route('/health')
def health():
    """Health check endpoint"""
    logger.info("Health check performed")
    return jsonify({'status': 'healthy', 'timestamp': time.time()})


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    logger.debug("Metrics endpoint accessed")
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


@app.route('/api/data')
def get_data():
    """Sample data endpoint"""
    logger.info("Data endpoint accessed")
    
    # Simulate some processing time
    time.sleep(random.uniform(0.01, 0.1))
    
    data = {
        'timestamp': time.time(),
        'data': [
            {'id': 1, 'name': 'Item 1', 'value': random.randint(1, 100)},
            {'id': 2, 'name': 'Item 2', 'value': random.randint(1, 100)},
            {'id': 3, 'name': 'Item 3', 'value': random.randint(1, 100)},
        ]
    }
    
    logger.info(f"Returning data with {len(data['data'])} items")
    return jsonify(data)


@app.route('/api/random')
def get_random():
    """Random number generator endpoint"""
    random_num = random.randint(1, 1000)
    logger.info(f"Generated random number: {random_num}")
    
    return jsonify({
        'random_number': random_num,
        'timestamp': time.time()
    })


@app.route('/api/error')
def trigger_error():
    """Endpoint to trigger an error for testing"""
    logger.error("Error endpoint triggered - simulating application error")
    error_count.labels(endpoint='/api/error').inc()
    
    # Randomly decide error type
    error_type = random.choice(['500', '404', '400'])
    
    if error_type == '500':
        logger.error("Simulating 500 Internal Server Error")
        return jsonify({'error': 'Internal Server Error'}), 500
    elif error_type == '404':
        logger.warning("Simulating 404 Not Found")
        return jsonify({'error': 'Resource Not Found'}), 404
    else:
        logger.warning("Simulating 400 Bad Request")
        return jsonify({'error': 'Bad Request'}), 400


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    logger.warning(f"404 error: {error}")
    return jsonify({'error': 'Not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"500 error: {error}")
    error_count.labels(endpoint='internal').inc()
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    logger.info("Starting Flask application on port 5000")
    logger.info(f"Logging to: {log_file}")
    app.run(host='0.0.0.0', port=5000, debug=False)
