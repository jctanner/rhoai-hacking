#!/usr/bin/env python3

import os
import logging
from flask import Flask, render_template, request, jsonify
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-prod')
app.config['DEBUG'] = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'

# Sample data - in a real implementation, this could come from the gateway config or K8s API
SAMPLE_SERVICES = [
    {
        'name': 'Jupyter Notebooks',
        'description': 'Interactive notebook environment for data science',
        'path': '/notebooks',
        'icon': '📓',
        'status': 'healthy'
    },
    {
        'name': 'MLflow',
        'description': 'Machine learning lifecycle management',
        'path': '/mlflow',
        'icon': '🔬',
        'status': 'healthy'
    },
    {
        'name': 'TensorBoard',
        'description': 'Visualization toolkit for machine learning',
        'path': '/tensorboard',
        'icon': '📊',
        'status': 'healthy'
    }
]

@app.route('/')
def dashboard():
    """Main dashboard page showing available services"""
    return render_template('dashboard.html', 
                         services=SAMPLE_SERVICES,
                         current_time=datetime.now().strftime('%Y-%m-%d %H:%M:%S'))

@app.route('/health')
def health_check():
    """Health check endpoint for Kubernetes probes"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'service': 'odh-dashboard'
    })

@app.route('/api/services')
def api_services():
    """API endpoint to get available services (for future AJAX updates)"""
    return jsonify({
        'services': SAMPLE_SERVICES,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/about')
def about():
    """About page explaining the ODH Gateway system"""
    return render_template('about.html')

@app.errorhandler(404)
def not_found_error(error):
    """Custom 404 page"""
    return render_template('404.html'), 404

@app.errorhandler(500)
def internal_error(error):
    """Custom 500 page"""
    logger.error(f"Internal server error: {error}")
    return render_template('500.html'), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    host = os.environ.get('HOST', '0.0.0.0')
    
    logger.info(f"Starting ODH Dashboard on {host}:{port}")
    app.run(host=host, port=port, debug=app.config['DEBUG']) 