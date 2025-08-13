# Multi-stage build for smaller image
FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY MyChannel/Backend/requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && pip install -r /app/requirements.txt

COPY MyChannel/Backend /app

# Create non-root user
RUN useradd -m -u 10001 appuser
USER appuser

# Cloud Run sets PORT; default to 8080 locally
ENV PORT=8080
EXPOSE 8080

# Use multiple workers if CPU>1, otherwise 1 worker is fine with Cloud Run concurrency
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT} --workers 1 --loop uvloop --http httptools