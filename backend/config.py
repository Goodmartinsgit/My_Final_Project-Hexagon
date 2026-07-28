import os
from dotenv import load_dotenv

load_dotenv()  # reads .env in the backend directory

env = os.getenv("ENV_MODE", "development")

if env == "production":
    load_dotenv(".env.prod")
if env == "test":
    load_dotenv(".env.test")
else:
    load_dotenv(".env.dev")

class Config:
    # ── Database
    DB_HOST = os.getenv("DB_HOST")

    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        f"postgresql://postgres:postgres@{DB_HOST}:5432/demo_db",
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # ── Security
    SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")

    # ── CORS
    # Set ALLOWED_ORIGIN in .env to match your frontend URL,
    # e.g. http://localhost:3000
    ALLOWED_ORIGIN = os.getenv("ALLOWED_ORIGIN", "*")
