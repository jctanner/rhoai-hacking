#!/usr/bin/env python3

import os
import logging
import jwt
import json
from flask import Flask, render_template, request, jsonify
from datetime import datetime
from kubernetes import client, config
from kubernetes.client.rest import ApiException
import base64

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-prod')
app.config['DEBUG'] = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'

'''
def get_k8s_client_from_jwt(jwt_token):
    """Create a Kubernetes client using the JWT token for authentication"""
    try:
        # Create a fresh configuration without loading incluster config
        configuration = client.Configuration()
        
        if os.path.exists("/var/run/secrets/kubernetes.io/serviceaccount"):
            # We're running in-cluster, manually set up the configuration
            k8s_host = os.environ.get('KUBERNETES_SERVICE_HOST', 'kubernetes.default.svc')
            k8s_port = os.environ.get('KUBERNETES_SERVICE_PORT', '443')
            configuration.host = f"https://{k8s_host}:{k8s_port}"
            
            # Use cluster CA certificate
            ca_cert_path = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
            if os.path.exists(ca_cert_path):
                configuration.ssl_ca_cert = ca_cert_path
                configuration.verify_ssl = True
            else:
                configuration.verify_ssl = False
        else:
            # We're running outside cluster (development)  
            k8s_host = os.environ.get('KUBERNETES_SERVICE_HOST', 'kubernetes.default.svc')
            k8s_port = os.environ.get('KUBERNETES_SERVICE_PORT', '443')
            configuration.host = f"https://{k8s_host}:{k8s_port}"
            configuration.verify_ssl = False
            
        # Set the user's JWT token for authentication
        configuration.api_key = {"authorization": f"Bearer {jwt_token}"}
        configuration.api_key_prefix = {"authorization": ""}
        
        logger.info(f"Kubernetes client configured with host: {configuration.host}")
        logger.info(f"SSL verification: {configuration.verify_ssl}")
        
        return client.ApiClient(configuration)
    except Exception as e:
        logger.error(f"Failed to create Kubernetes client: {e}")
        return None
'''

def get_k8s_client_from_jwt(jwt_token):
    """Create a Kubernetes client using only the provided JWT token"""
    try:
        configuration = client.Configuration()

        # Always use host from env (fallback to default service name)
        k8s_host = os.environ.get('KUBERNETES_SERVICE_HOST', 'kubernetes.default.svc')
        k8s_port = os.environ.get('KUBERNETES_SERVICE_PORT', '443')
        configuration.host = f"https://{k8s_host}:{k8s_port}"

        # Try to use cluster CA, but never use service account token
        ca_cert_path = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        if os.path.exists(ca_cert_path):
            configuration.ssl_ca_cert = ca_cert_path
            configuration.verify_ssl = True
        else:
            configuration.verify_ssl = False

        # Only use the provided JWT for auth
        configuration.api_key = {"authorization": f"Bearer {jwt_token}"}
        configuration.api_key_prefix = {"authorization": ""}

        logger.info(f"Kubernetes client configured with host: {configuration.host}")
        logger.info(f"SSL verification: {configuration.verify_ssl}")
        
        return client.ApiClient(configuration)
    except Exception as e:
        logger.error(f"Failed to create Kubernetes client: {e}")
        return None


def get_jwt_token_from_request():
    """Extract JWT token from request headers or cookies"""
    # Try Authorization header first
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        return auth_header[7:]  # Remove 'Bearer ' prefix
    
    # Try cookie
    auth_cookie = request.cookies.get('auth_token')
    if auth_cookie:
        return auth_cookie
        
    # Try other common headers
    jwt_header = request.headers.get('X-Forwarded-Access-Token')
    if jwt_header:
        return jwt_header
        
    return None

def get_namespaces(k8s_client):
    """Get list of namespaces from Kubernetes API"""
    try:
        v1 = client.CoreV1Api(k8s_client)
        namespaces = v1.list_namespace()
        
        namespace_list = []
        for ns in namespaces.items:
            namespace_info = {
                'name': ns.metadata.name,
                'status': ns.status.phase,
                'creation_timestamp': ns.metadata.creation_timestamp.isoformat() if ns.metadata.creation_timestamp else None,
                'labels': ns.metadata.labels or {}
            }
            namespace_list.append(namespace_info)
            
        return namespace_list
    except ApiException as e:
        logger.error(f"Failed to get namespaces: {e}")
        return []
    except Exception as e:
        logger.error(f"Unexpected error getting namespaces: {e}")
        return []

def get_notebooks(k8s_client, namespace=None):
    """Get list of Jupyter notebooks from Kubernetes API"""
    try:
        # Use CustomObjectsApi to get notebooks (assuming they're custom resources)
        custom_api = client.CustomObjectsApi(k8s_client)
        
        notebooks = []
        
        # Try to get notebooks from the kubeflow notebooks CRD
        try:
            if namespace:
                notebook_list = custom_api.list_namespaced_custom_object(
                    group="kubeflow.org",
                    version="v1",
                    namespace=namespace,
                    plural="notebooks"
                )
            else:
                notebook_list = custom_api.list_cluster_custom_object(
                    group="kubeflow.org",
                    version="v1",
                    plural="notebooks"
                )
                
            for notebook in notebook_list.get('items', []):
                notebook_info = {
                    'name': notebook['metadata']['name'],
                    'namespace': notebook['metadata']['namespace'],
                    'status': notebook.get('status', {}).get('containerState', {}).get('state', 'Unknown'),
                    'creation_timestamp': notebook['metadata'].get('creationTimestamp'),
                    'spec': notebook.get('spec', {}),
                    'ready': notebook.get('status', {}).get('readyReplicas', 0) > 0
                }
                notebooks.append(notebook_info)
                
        except ApiException as e:
            if e.status == 404:
                logger.info("Kubeflow notebooks CRD not found, trying alternative approaches")
                # Try to get StatefulSets that might be notebooks
                notebooks = get_notebook_statefulsets(k8s_client, namespace)
            else:
                logger.error(f"Failed to get notebooks: {e}")
                
        return notebooks
    except Exception as e:
        logger.error(f"Unexpected error getting notebooks: {e}")
        return []

def get_notebook_statefulsets(k8s_client, namespace=None):
    """Get notebook-like StatefulSets as fallback"""
    try:
        apps_v1 = client.AppsV1Api(k8s_client)
        notebooks = []
        
        if namespace:
            statefulsets = apps_v1.list_namespaced_stateful_set(namespace=namespace)
        else:
            statefulsets = apps_v1.list_stateful_set_for_all_namespaces()
            
        for sts in statefulsets.items:
            # Check if this looks like a notebook (has jupyter in name or labels)
            name = sts.metadata.name.lower()
            labels = sts.metadata.labels or {}
            
            if ('jupyter' in name or 'notebook' in name or 
                'jupyter' in str(labels).lower() or 'notebook' in str(labels).lower()):
                
                notebook_info = {
                    'name': sts.metadata.name,
                    'namespace': sts.metadata.namespace,
                    'status': 'Running' if sts.status.ready_replicas and sts.status.ready_replicas > 0 else 'Pending',
                    'creation_timestamp': sts.metadata.creation_timestamp.isoformat() if sts.metadata.creation_timestamp else None,
                    'ready': sts.status.ready_replicas and sts.status.ready_replicas > 0,
                    'replicas': sts.status.replicas or 0,
                    'ready_replicas': sts.status.ready_replicas or 0
                }
                notebooks.append(notebook_info)
                
        return notebooks
    except Exception as e:
        logger.error(f"Failed to get notebook StatefulSets: {e}")
        return []

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

@app.route('/')
def dashboard():
    """Main dashboard page showing namespaces and notebooks"""
    user_info = extract_user_info()
    
    # Get JWT token for K8s API calls
    jwt_token = get_jwt_token_from_request()
    
    # Debug logging
    logger.info(f"JWT token found: {'Yes' if jwt_token else 'No'}")
    if jwt_token:
        logger.info(f"JWT token length: {len(jwt_token)}")
        logger.info(f"JWT token starts with: {jwt_token[:20]}...")
    
    # Log all headers for debugging
    logger.info(f"Request headers: {dict(request.headers)}")
    
    namespaces = []
    notebooks = []
    k8s_error = None
    
    if jwt_token:
        k8s_client = get_k8s_client_from_jwt(jwt_token)
        if k8s_client:
            try:
                namespaces = get_namespaces(k8s_client)
                notebooks = get_notebooks(k8s_client)
                logger.info(f"Retrieved {len(namespaces)} namespaces and {len(notebooks)} notebooks")
            except Exception as e:
                k8s_error = f"Failed to query Kubernetes API: {str(e)}"
                logger.error(k8s_error)
        else:
            k8s_error = "Failed to create Kubernetes client"
    else:
        k8s_error = "No JWT token found in request"
    
    return render_template('dashboard.html', 
                         namespaces=namespaces,
                         notebooks=notebooks,
                         current_time=datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                         user_info=user_info,
                         k8s_error=k8s_error)

@app.route('/api/namespaces')
def api_namespaces():
    """API endpoint to get namespaces"""
    jwt_token = get_jwt_token_from_request()
    
    if not jwt_token:
        return jsonify({'error': 'No JWT token found'}), 401
    
    k8s_client = get_k8s_client_from_jwt(jwt_token)
    if not k8s_client:
        return jsonify({'error': 'Failed to create Kubernetes client'}), 500
    
    namespaces = get_namespaces(k8s_client)
    return jsonify({
        'namespaces': namespaces,
        'count': len(namespaces),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/notebooks')
@app.route('/api/notebooks/<namespace>')
def api_notebooks(namespace=None):
    """API endpoint to get notebooks"""
    jwt_token = get_jwt_token_from_request()
    
    if not jwt_token:
        return jsonify({'error': 'No JWT token found'}), 401
    
    k8s_client = get_k8s_client_from_jwt(jwt_token)
    if not k8s_client:
        return jsonify({'error': 'Failed to create Kubernetes client'}), 500
    
    notebooks = get_notebooks(k8s_client, namespace)
    return jsonify({
        'notebooks': notebooks,
        'namespace': namespace,
        'count': len(notebooks),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/health')
def health_check():
    """Health check endpoint for Kubernetes probes"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'service': 'odh-dashboard'
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