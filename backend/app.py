from flask import Flask
from flask_cors import CORS
from config import Config
from models import db
from routes import demo_bp


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # Allow requests from your frontend origin
    CORS(app, resources={r"/api/*": {"origins": Config.ALLOWED_ORIGIN}})

    # Initialise S
    # QLAlchemy with this app
    db.init_app(app)

    # Register blueprints
    app.register_blueprint(demo_bp, url_prefix="/api")

    # Create tables if they don't exist yet
    with app.app_context():
        db.create_all()

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(debug=True,host="0.0.0.0", port=5000)
