from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def echo(path):
    headers = {key: value for key, value in sorted(request.headers)}
    return jsonify(headers)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
