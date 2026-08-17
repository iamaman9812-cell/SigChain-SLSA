import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/", methods=["GET"])
def index():
    """
    Homepage endpoint.
    Returns a simple JSON response indicating that the application is running.
    """
    return jsonify({
        "message": "Welcome to SigChain-SLSA Platform!",
        "status": "running",
        "version": "1.0.0"
    }), 200

@app.route("/health", methods=["GET"])
def health():
    """
    Health check endpoint.
    Used by orchestrators, container runtime, and monitoring systems to verify application health.
    """
    return jsonify({
        "status": "healthy",
        "service": "sigchain-slsa"
    }), 200

if __name__ == "__main__":
    # For local development only. Production deployment uses Gunicorn WSGI server.
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
