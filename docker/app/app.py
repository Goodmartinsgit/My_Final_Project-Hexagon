from flask import Flask, jsonify
import os

app = Flask(__name__)

# SERVICE_NAME is injected at runtime by the launch template user_data.
# This avoids hardcoding the project name in the container image.
SERVICE_NAME = os.environ.get("SERVICE_NAME", "app-tier")


@app.route("/health")
def health():
    """Health check at bare /health path."""
    return jsonify({"status": "ok", "tier": "app"})


# The real backend registers this via the /api blueprint prefix.
# This stub exposes it directly so the internal ALB target group health check
# (configured as /api/health) succeeds even when using this placeholder image.
@app.route("/api/health")
def api_health():
    """Health check at /api/health — matches the internal ALB target group probe."""
    return jsonify({"status": "ok", "tier": "app"})


@app.route("/")
def index():
    return jsonify({"service": SERVICE_NAME, "message": "Hello from the app tier"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
