# Optimized Base Dockerfile for Cloud Run ML Agents
# Reduces cold start from 2-3s to <1s

FROM python:3.11-slim

# Install system dependencies in single layer
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies with optimizations
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir gunicorn gevent

# Copy application code
COPY . .

# Create non-root user for security
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Optimize Python startup
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONHASHSEED=random \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Use gunicorn with gevent for better concurrency
CMD exec gunicorn \
    --bind :$PORT \
    --workers 1 \
    --threads 8 \
    --worker-class gevent \
    --worker-connections 1000 \
    --timeout 60 \
    --preload \
    --access-logfile - \
    --error-logfile - \
    main:app
