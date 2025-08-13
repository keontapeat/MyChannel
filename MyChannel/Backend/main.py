import os
import time
import json
import uuid
import logging
from typing import Optional

from fastapi import FastAPI, HTTPException, Request, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, constr
from google.cloud import aiplatform, logging as gclogging
from google.cloud import pubsub_v1
from tenacity import retry, wait_exponential_jitter, stop_after_attempt, retry_if_exception_type

# Env
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get("PROJECT_ID")
LOCATION = os.environ.get("LOCATION", "us-central1")
API_KEY = os.environ.get("API_KEY")  # Optional simple API key
MODEL_NAME = os.environ.get("GEN_MODEL", "gemini-1.5-flash")
MAX_TEXT_CHARS = int(os.environ.get("MAX_TEXT_CHARS", "4000"))

if not PROJECT_ID:
    raise RuntimeError("PROJECT_ID or GOOGLE_CLOUD_PROJECT must be set")

# Logging and AI init
gclogging.Client().setup_logging()
aiplatform.init(project=PROJECT_ID, location=LOCATION)
logger = logging.getLogger("mychannel")
logger.setLevel(logging.INFO)

# Pub/Sub
publisher: Optional[pubsub_v1.PublisherClient] = None
topic_path: Optional[str] = None
try:
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(PROJECT_ID, "events")
except Exception as e:
    logger.warning("Pub/Sub publisher init failed: %s", e)

# App
app = FastAPI(title="MyChannel AI", version="1.0.0")

# CORS (tighten origins in prod)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Replace with your allowed origins
    allow_credentials=False,
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)


# Models
class SummarizeRequest(BaseModel):
    text: constr(strip_whitespace=True, min_length=1) = Field(..., description="Text to summarize")
    lang: Optional[str] = Field(default="en", description="Language code")


class SummarizeResponse(BaseModel):
    summary: str
    id: str
    model: str
    latency_ms: int


class HealthResponse(BaseModel):
    status: str
    project: str
    location: str
    model: str


# Helpers
def client_id_from_request(request: Request) -> str:
    xff = request.headers.get("x-forwarded-for")
    if xff:
        return xff.split(",")[0].strip()
    if request.client:
        return request.client.host or "unknown"
    return "unknown"


def require_api_key(provided: Optional[str]) -> None:
    if not API_KEY:
        return
    if not provided or provided != API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")


def pubsub_event(event: dict) -> None:
    if not publisher or not topic_path:
        return
    try:
        publisher.publish(
            topic_path,
            json.dumps(event, ensure_ascii=False).encode("utf-8"),
            eventType=event.get("type", "unknown"),
        )
    except Exception as e:
        logger.warning("Pub/Sub publish failed: %s", e)


def get_model():
    from vertexai.generative_models import GenerativeModel
    return GenerativeModel(MODEL_NAME)


@retry(
    wait=wait_exponential_jitter(initial=0.2, max=2.0),
    stop=stop_after_attempt(3),
    retry=retry_if_exception_type(Exception),
    reraise=True,
)
def generate_summary_sync(prompt: str) -> str:
    model = get_model()
    resp = model.generate_content(prompt)
    # Vertex responses may contain safety blocks; guard for text
    text = getattr(resp, "text", None)
    if not text:
        # fallback if chunks-like
        candidates = getattr(resp, "candidates", None)
        text = candidates[0].content.parts[0].text if candidates else ""
    if not text:
        raise RuntimeError("Empty response from model")
    return text


# Routes
@app.get("/", response_model=HealthResponse)
def root():
    return HealthResponse(status="ok", project=PROJECT_ID, location=LOCATION, model=MODEL_NAME)


@app.get("/healthz", response_model=HealthResponse)
def healthz():
    return HealthResponse(status="ok", project=PROJECT_ID, location=LOCATION, model=MODEL_NAME)


@app.get("/readyz", response_model=HealthResponse)
def readyz():
    # Lightweight readiness: verify we can instantiate the model
    _ = get_model()
    return HealthResponse(status="ready", project=PROJECT_ID, location=LOCATION, model=MODEL_NAME)


@app.post("/ai/summarize", response_model=SummarizeResponse)
def summarize(req: SummarizeRequest, request: Request, x_api_key: Optional[str] = Header(default=None)):
    require_api_key(x_api_key)

    if len(req.text) > MAX_TEXT_CHARS:
        raise HTTPException(status_code=413, detail=f"text too long; max {MAX_TEXT_CHARS} chars")

    cid = client_id_from_request(request)
    req_id = str(uuid.uuid4())
    start = time.time()

    prompt = f"Summarize the following for a concise, engaging video description in {req.lang}:\n\n{req.text}"

    try:
        summary = generate_summary_sync(prompt)
        latency_ms = int((time.time() - start) * 1000)

        log = {
            "severity": "INFO",
            "message": "summarize_ok",
            "request_id": req_id,
            "client_id": cid,
            "model": MODEL_NAME,
            "lang": req.lang or "en",
            "text_len": len(req.text),
            "latency_ms": latency_ms,
        }
        logger.info(json.dumps(log))
        pubsub_event({"type": "summarize", "ok": True, **log})

        return SummarizeResponse(summary=summary, id=req_id, model=MODEL_NAME, latency_ms=latency_ms)
    except Exception as e:
        latency_ms = int((time.time() - start) * 1000)
        err = {
            "severity": "ERROR",
            "message": "summarize_fail",
            "request_id": req_id,
            "client_id": cid,
            "model": MODEL_NAME,
            "lang": req.lang or "en",
            "text_len": len(req.text),
            "latency_ms": latency_ms,
            "error": str(e),
        }
        logger.error(json.dumps(err))
        pubsub_event({"type": "summarize", "ok": False, **err})
        raise HTTPException(status_code=500, detail="Summarization failed")