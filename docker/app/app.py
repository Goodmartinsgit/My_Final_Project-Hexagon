from flask import Flask, jsonify
import os

app = Flask(__name__)

# SERVICE_NAME is injected at runtime by the launch template user_data.
# This avoids hardcoding the project name in the container image.
SERVICE_NAME = os.environ.get("SERVICE_NAME", "app-tier")


@app.route("/health")
def health():
    return jsonify({"status": "ok", "tier": "app"})


@app.route("/")
def index():
    return jsonify({"service": SERVICE_NAME, "message": "Hello from the app tier"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
