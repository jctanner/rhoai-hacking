from flask import Flask, request, jsonify, Response
import jwt
import json
import os
import requests
from functools import wraps


app = Flask(__name__)

# Default to "/" if ROUTE_PREFIX is unset
ROUTE_PREFIX = os.environ.get("ROUTE_PREFIX", "/").rstrip("/")

def route_with_prefix(route, **kwargs):
    """Custom route decorator that prepends the ROUTE_PREFIX"""
    full_route = ROUTE_PREFIX + route
    return app.route(full_route, **kwargs)


@route_with_prefix("/")
def echo_headers_html():

    app_name = os.environ.get('APP_NAME', "APP_NAME UNSET")

    headers = dict(request.headers)
    token = headers.get('X-Forwarded-Access-Token')
    decoded = {}

    if token:
        try:
            decoded = jwt.decode(token, options={"verify_signature": False})
        except Exception as e:
            decoded = {"error": str(e)}

    html = f"""
    <html>
        <head>
            <title>Request Info {app_name}</title>
            <style>
                body {{ font-family: monospace; background: #f5f5f5; padding: 1em; }}
                pre {{ background: #fff; border: 1px solid #ccc; padding: 1em; overflow-x: auto; }}
            </style>
        </head>
        <body>
            <h1>Request Headers</h1>
            <pre>{json.dumps(headers, indent=2)}</pre>
            <h1>Decoded Token</h1>
            <pre>{json.dumps(decoded, indent=2)}</pre>
        </body>
    </html>
    """
    return Response(html, mimetype='text/html')


@route_with_prefix("/projects")
def list_projects():
    token = request.headers.get('X-Forwarded-Access-Token')

    if not token:
        return jsonify({"error": "Missing X-Forwarded-Access-Token"}), 401

    try:
        response = requests.get(
            "https://kubernetes.default.svc/apis/project.openshift.io/v1/projects",
            headers={"Authorization": f"Bearer {token}"},
            #verify="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
            verify=False,
            timeout=5,
        )
        response.raise_for_status()
        return jsonify(response.json())
    except requests.RequestException as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("FLASK_PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
