FROM python:3.11-slim AS base

# Set working directory
WORKDIR /app

# Install production dependencies first (better Docker layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY . .

# Create a non-root user for security — never run production as root
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

# Application listens on port 5000
EXPOSE 5000

# Gunicorn is the production WSGI server — replaces the dev server (python app.py)
# 2 workers is sufficient for a t2.micro; scale up for larger instance types.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "60", "app:create_app()"]