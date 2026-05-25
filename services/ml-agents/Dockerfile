# 🔥 REAL ML AGENTS - Production Docker Image
# Multi-stage build for optimized image size

# ============================================================================
# Stage 1: Builder - Install dependencies and train models
# ============================================================================
FROM python:3.11-slim as builder

WORKDIR /app

# Install system dependencies for building
RUN apt-get update && apt-get install -y \
    build-essential \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for caching
COPY requirements.txt .

# Create virtual environment and install dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create model directory
RUN mkdir -p /app/trained_models

# Pre-train all models during build (optional - can also train at runtime)
# This makes container startup faster but increases build time
ARG PRETRAIN_MODELS=false
RUN if [ "$PRETRAIN_MODELS" = "true" ]; then \
        echo "🔥 Pre-training models during build..." && \
        python train_all_models.py; \
    fi

# ============================================================================
# Stage 2: Production - Minimal runtime image
# ============================================================================
FROM python:3.11-slim as production

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
COPY --from=builder /app /app

# Create non-root user for security
RUN useradd -m -u 1000 mluser && \
    chown -R mluser:mluser /app
USER mluser

# Set environment variables
ENV PORT=8000
ENV MODEL_DIR=/app/trained_models
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application - Cloud Run sets PORT env var
CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}
