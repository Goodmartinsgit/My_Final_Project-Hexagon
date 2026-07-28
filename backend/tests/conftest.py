"""
conftest.py — shared pytest fixtures for the backend test suite.

Run tests from the backend/ directory:
    pytest tests/ -v --cov=. --cov-report=term-missing

The fixtures use an in-memory SQLite database so no external Postgres is required.
The DATABASE_URL environment variable is set before any application module is
imported so that Config reads the test value at startup.
"""

import os

import pytest

# Set test environment variables before importing application modules.
# Config reads from os.environ, so these must be set before the import below.
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("ENV_MODE", "test")
os.environ.setdefault("SECRET_KEY", "test-secret-key-not-for-production")
os.environ.setdefault("ALLOWED_ORIGIN", "*")

from app import create_app  # noqa: E402 — import after env setup
from models import db as _db  # noqa: E402


@pytest.fixture(scope="session")
def app():
    """
    Create a Flask application configured for testing.

    Session scope means the application is created once per pytest session,
    which is sufficient since we reset state at the database level between tests.
    """
    application = create_app()
    application.config.update(
        TESTING=True,
        SQLALCHEMY_DATABASE_URI="sqlite:///:memory:",
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
    )
    return application


@pytest.fixture(scope="session")
def _database(app):
    """Create all tables once per session and drop them when the session ends."""
    with app.app_context():
        _db.create_all()
        yield _db
        _db.drop_all()


@pytest.fixture(autouse=True)
def rollback_after_test(app, _database):
    """
    Wrap every test in a transaction that is rolled back at the end.

    This means each test starts with a clean, empty database without the
    overhead of dropping and recreating tables.
    """
    with app.app_context():
        connection = _database.engine.connect()
        transaction = connection.begin()
        _database.session.bind = connection
        yield
        transaction.rollback()
        connection.close()


@pytest.fixture(scope="session")
def client(app):
    """Flask test client for making HTTP requests in tests."""
    return app.test_client()
