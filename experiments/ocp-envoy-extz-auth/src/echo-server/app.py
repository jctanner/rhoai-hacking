import jwt
import json
import requests
import os
from flask import Flask, request, jsonify, Response

app = Flask(__name__)

# --- In-cluster K8s API configuration ---
K8S_API_HOST = "https://kubernetes.default.svc"

def decode_token(token):
    """Decodes a JWT token without verifying the signature."""
    try:
        return jwt.decode(token, options={"verify_signature": False})
    except Exception as e:
        return {"error": f"Failed to decode token: {str(e)}"}

def get_namespaces_with_token(token):
    """Tries to list namespaces using the provided bearer token via a direct REST call."""
    try:
        headers = {"Authorization": f"Bearer {token}"}
        # For this demo, we are disabling TLS verification for the internal API call.
        # In a production environment, you would want to properly verify the certificate.
        response = requests.get(f"{K8S_API_HOST}/api/v1/namespaces", headers=headers, verify=False)
        
        # Raise an exception if the request was not successful
        response.raise_for_status()
        
        data = response.json()
        return {
            "status": "Success",
            "namespaces": [ns["metadata"]["name"] for ns in data.get("items", [])]
        }
    except requests.exceptions.HTTPError as http_err:
        return {
            "status": "Error",
            "message": f"HTTP Error: {http_err}",
            "response_body": http_err.response.text
        }
    except Exception as e:
        return {
            "status": "Error",
            "message": f"Failed to list namespaces: {str(e)}"
        }

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def echo(path):
    headers = {key: value for key, value in sorted(request.headers)}
    response_data = {"headers": headers}

    access_token = headers.get("X-Auth-Request-Access-Token")
    if access_token:
        decoded_token = decode_token(access_token)
        response_data["headers"]["X-Auth-Request-Access-Token-Decoded"] = decoded_token

    if 'text/html' in request.headers.get('Accept', '') and access_token:
        k8s_api_result = get_namespaces_with_token(access_token)
        response_data["kubernetes_api_result"] = k8s_api_result
        
        pretty_json = json.dumps(response_data, indent=2)
        html_output = f"<pre>{pretty_json}</pre>"
        return Response(html_output, mimetype='text/html')
    else:
        return jsonify(response_data["headers"])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
