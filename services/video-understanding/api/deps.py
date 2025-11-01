import os
import json
import logging
from typing import Optional

import psycopg
from google.cloud import storage
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials


def init_logging():
    class JsonFormatter(logging.Formatter):
        def format(self, record: logging.LogRecord) -> str:
            data = {
                "level": record.levelname,
                "message": record.getMessage(),
                "logger": record.name,
            }
            return json.dumps(data)

    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.setLevel(os.getenv("LOG_LEVEL", "INFO").upper())
    # clear existing handlers if any
    root.handlers = [handler]


def get_db():
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        raise RuntimeError("DATABASE_URL not set")
    with psycopg.connect(dsn, autocommit=True) as conn:
        yield conn


def get_gcs():
    client = storage.Client(project=os.getenv("GCP_PROJECT"))
    bucket_name = os.getenv("GCS_BUCKET")
    if not bucket_name:
        raise RuntimeError("GCS_BUCKET not set")
    bucket = client.bucket(bucket_name)
    return client, bucket


bearer = HTTPBearer(auto_error=False)


def require_bearer_token(creds: Optional[HTTPAuthorizationCredentials] = Depends(bearer)):
    token = os.getenv("API_AUTH_TOKEN")
    if not token:
        raise HTTPException(status_code=500, detail="Server auth not configured")
    if creds is None or creds.scheme.lower() != "bearer" or creds.credentials != token:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return True


