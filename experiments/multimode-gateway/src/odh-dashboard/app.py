#!/usr/bin/env python3

import os
import logging
import jwt
import json
from flask import Flask, render_template, request, jsonify
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-prod')
app.config['DEBUG'] = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'

def extract_user_info():
    """Extract user information from headers and JWT tokens"""
    user_info = {
        'username': 'anonymous',
        'email': None,
        'groups': [],
        'raw_headers': dict(request.headers),
        'jwt_payload': None,
        'auth_method': 'none'
    }
    
    # Check for forwarded user header (set by ODH Gateway)
    forwarded_user = request.headers.get('X-Forwarded-User')
    if forwarded_user:
        user_info['username'] = forwarded_user
        user_info['auth_method'] = 'forwarded_header'
    
    # Check for forwarded groups
    forwarded_groups = request.headers.get('X-Forwarded-Groups')
    if forwarded_groups:
        user_info['groups'] = forwarded_groups.split(',')
    
    # Try to parse JWT from Authorization header
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        token = auth_header[7:]  # Remove 'Bearer ' prefix
        try:
            # Decode without verification (since we trust the gateway)
            payload = jwt.decode(token, options={"verify_signature": False})
            user_info['jwt_payload'] = payload
            user_info['auth_method'] = 'jwt_token'
            
            # Extract username from JWT claims
            if 'preferred_username' in payload:
                user_info['username'] = payload['preferred_username']
            elif 'sub' in payload:
                user_info['username'] = payload['sub']
            elif 'email' in payload:
                user_info['username'] = payload['email']
                
            # Extract email
            if 'email' in payload:
                user_info['email'] = payload['email']
                
            # Extract groups from JWT
            if 'groups' in payload:
                user_info['groups'] = payload['groups']
                
        except Exception as e:
            logger.warning(f"Failed to decode JWT: {e}")
    
    # Try to get JWT from cookie (set by ODH Gateway)
    auth_cookie = request.cookies.get('auth_token')
    if auth_cookie and not user_info['jwt_payload']:
        try:
            payload = jwt.decode(auth_cookie, options={"verify_signature": False})
            user_info['jwt_payload'] = payload
            user_info['auth_method'] = 'jwt_cookie'
            
            # Extract user info from cookie JWT
            if 'preferred_username' in payload:
                user_info['username'] = payload['preferred_username']
            elif 'sub' in payload:
                user_info['username'] = payload['sub']
            elif 'email' in payload:
                user_info['username'] = payload['email']
                
            if 'email' in payload:
                user_info['email'] = payload['email']
                
            if 'groups' in payload:
                user_info['groups'] = payload['groups']
                
        except Exception as e:
            logger.warning(f"Failed to decode JWT from cookie: {e}")
    
    return user_info

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
    user_info = extract_user_info()
    return render_template('dashboard.html', 
                         services=SAMPLE_SERVICES,
                         current_time=datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                         user_info=user_info)

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
    user_info = extract_user_info()
    return render_template('about.html', user_info=user_info)

@app.route('/debug')
def debug():
    """Debug page showing headers and JWT information"""
    user_info = extract_user_info()
    
    # Pretty-print JSON for display
    jwt_json = None
    if user_info['jwt_payload']:
        jwt_json = json.dumps(user_info['jwt_payload'], indent=2, default=str)
    
    headers_json = json.dumps(dict(request.headers), indent=2, default=str)
    
    return render_template('debug.html', 
                         user_info=user_info,
                         jwt_json=jwt_json,
                         headers_json=headers_json,
                         request_info={
                             'method': request.method,
                             'url': request.url,
                             'remote_addr': request.remote_addr,
                             'user_agent': request.headers.get('User-Agent', 'Unknown')
                         })

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