import os
import time
import json
import uuid
import logging
from typing import Optional, List, Dict, Any

from fastapi import FastAPI, HTTPException, Request, Header, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, constr
from google.cloud import aiplatform, logging as gclogging
from google.cloud import pubsub_v1
from google.cloud import bigquery
from tenacity import retry, wait_exponential_jitter, stop_after_attempt, retry_if_exception_type
from google.cloud import storage
from google.cloud import videointelligence_v1 as vi
try:
    import firebase_admin
    from firebase_admin import auth as fb_auth
except Exception:  # pragma: no cover - optional
    firebase_admin = None
    fb_auth = None

# Env
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get("PROJECT_ID")
LOCATION = os.environ.get("LOCATION", "us-central1")
API_KEY = os.environ.get("API_KEY")  # Optional simple API key
MEDIA_BUCKET = os.environ.get("MEDIA_BUCKET")
MODEL_NAME = os.environ.get("GEN_MODEL", "gemini-1.5-flash")
MAX_TEXT_CHARS = int(os.environ.get("MAX_TEXT_CHARS", "4000"))

if not PROJECT_ID:
    raise RuntimeError("PROJECT_ID or GOOGLE_CLOUD_PROJECT must be set")

# Logging and AI init
gclogging.Client().setup_logging()
aiplatform.init(project=PROJECT_ID, location=LOCATION)
logger = logging.getLogger("mychannel")
logger.setLevel(logging.INFO)

# Initialize Firebase Admin if available
if firebase_admin and not getattr(firebase_admin, "_apps", {}):  # type: ignore[attr-defined]
    try:
        firebase_admin.initialize_app()
    except Exception:
        pass

# Pub/Sub
publisher: Optional[pubsub_v1.PublisherClient] = None
topic_path: Optional[str] = None
topic_features_path: Optional[str] = None
try:
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(PROJECT_ID, "events")
    topic_features_path = publisher.topic_path(PROJECT_ID, "video-features")
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


def verify_firebase_token(authorization_header: Optional[str]) -> Optional[str]:
    if not authorization_header or not authorization_header.startswith("Bearer "):
        return None
    if not fb_auth:
        return None
    token = authorization_header.split(" ", 1)[1]
    try:
        decoded = fb_auth.verify_id_token(token)
        return decoded.get("uid")
    except Exception:
        return None


def require_auth(x_api_key: Optional[str], authorization: Optional[str]) -> Optional[str]:
    """Return uid if Firebase token valid; otherwise require API key if configured."""
    uid = verify_firebase_token(authorization)
    if uid:
        return uid
    require_api_key(x_api_key)
    return None


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


def publish_video_features(event: Dict[str, Any]) -> None:
    if not publisher or not topic_features_path:
        return
    try:
        publisher.publish(
            topic_features_path,
            json.dumps(event, ensure_ascii=False).encode("utf-8"),
            eventType=event.get("type", "video_features"),
        )
    except Exception as e:
        logger.warning("Pub/Sub video-features publish failed: %s", e)


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


# Video Intelligence API request/response
class AnalyzeVideoRequest(BaseModel):
    gcs_uri: constr(strip_whitespace=True, min_length=10)
    features: Optional[List[str]] = Field(default_factory=lambda: ["LABEL_DETECTION", "SHOT_CHANGE_DETECTION"])
    video_id: Optional[str] = Field(default=None, description="Client-assigned video id")
    duration_seconds: Optional[float] = Field(default=None, description="Video duration in seconds")


class AnalyzeVideoResponse(BaseModel):
    labels: List[str] = []
    shots: int = 0
    explicit_content: Optional[bool] = None
    text_annotations: List[str] = []
    object_annotations: List[str] = []
    uri: str


@app.post("/ai/analyzeVideo", response_model=AnalyzeVideoResponse)
def analyze_video(req: AnalyzeVideoRequest, x_api_key: Optional[str] = Header(default=None), authorization: Optional[str] = Header(default=None)):
    _ = require_auth(x_api_key, authorization)
    client = vi.VideoIntelligenceServiceClient()
    feature_map = {
        "LABEL_DETECTION": vi.Feature.LABEL_DETECTION,
        "SHOT_CHANGE_DETECTION": vi.Feature.SHOT_CHANGE_DETECTION,
        "EXPLICIT_CONTENT_DETECTION": vi.Feature.EXPLICIT_CONTENT_DETECTION,
        "TEXT_DETECTION": vi.Feature.TEXT_DETECTION,
        "OBJECT_TRACKING": vi.Feature.OBJECT_TRACKING,
    }
    selected = [feature_map[f] for f in (req.features or []) if f in feature_map]
    if not selected:
        selected = [vi.Feature.LABEL_DETECTION]

    operation = client.annotate_video(
        request={
            "features": selected,
            "input_uri": req.gcs_uri,
        }
    )
    result = operation.result(timeout=300)

    label_set: set[str] = set()
    shots = 0
    explicit = None
    text_set: set[str] = set()
    object_set: set[str] = set()

    for annotation_result in result.annotation_results:
        shots += len(annotation_result.shot_annotations or [])
        for l in (annotation_result.segment_label_annotations or []):
            if l.entity and l.entity.description:
                label_set.add(l.entity.description)
        for t in (annotation_result.text_annotations or []):
            if t.text:
                text_set.add(t.text)
        for o in (annotation_result.object_annotations or []):
            if o.entity and o.entity.description:
                object_set.add(o.entity.description)
        if annotation_result.explicit_annotation and annotation_result.explicit_annotation.frames:
            for f in annotation_result.explicit_annotation.frames:
                # Flag explicit if likelihood > VERY_UNLIKELY (1)
                if getattr(f, "pornography_likelihood", 0) and f.pornography_likelihood > 1:
                    explicit = True
                    break

    response = AnalyzeVideoResponse(
        labels=sorted(label_set),
        shots=shots,
        explicit_content=explicit,
        text_annotations=sorted(text_set),
        object_annotations=sorted(object_set),
        uri=req.gcs_uri,
    )

    # Publish features for learning pipeline
    features_event: Dict[str, Any] = {
        "type": "video_features",
        "video_id": req.video_id or "",
        "uri": req.gcs_uri,
        "labels": list(sorted(label_set)),
        "shots": shots,
        "explicit_content": bool(explicit) if explicit is not None else None,
        "text_annotations": list(sorted(text_set)),
        "object_annotations": list(sorted(object_set)),
        "duration_seconds": req.duration_seconds,
        "ingested_at": int(time.time()),
    }
    publish_video_features(features_event)

    return response


class ScoreViralityRequest(BaseModel):
    labels: List[str] = []
    shots: int = 0
    explicit_content: Optional[bool] = None
    duration_seconds: Optional[float] = None
    text_annotations: List[str] = []
    object_annotations: List[str] = []


class ScoreViralityResponse(BaseModel):
    score: float
    factors: Dict[str, Any]


@app.post("/ai/scoreVirality", response_model=ScoreViralityResponse)
def score_virality(req: ScoreViralityRequest, x_api_key: Optional[str] = Header(default=None), authorization: Optional[str] = Header(default=None)):
    _ = require_auth(x_api_key, authorization)

    # Simple heuristic baseline; can be replaced with BQML model scoring
    score = 0.0
    factors: Dict[str, Any] = {}

    # Penalize explicit content
    if req.explicit_content:
        score -= 0.2
        factors["explicit_penalty"] = -0.2

    # More unique labels and objects suggest richer content
    richness = min(1.0, (len(set(req.labels)) + len(set(req.object_annotations))) / 50.0)
    score += 0.3 * richness
    factors["richness"] = 0.3 * richness

    # Shots can capture editing pace
    pace = min(1.0, req.shots / 200.0)
    score += 0.2 * pace
    factors["pace"] = 0.2 * pace

    # Duration sweet spot around 15-90 seconds
    dur = req.duration_seconds or 0
    if dur > 0:
        if dur < 10:
            score += 0.05
            factors["duration_short_boost"] = 0.05
        elif 15 <= dur <= 90:
            score += 0.25
            factors["duration_sweet_spot"] = 0.25
        elif dur <= 300:
            score += 0.1
            factors["duration_medium"] = 0.1
        else:
            score -= 0.05
            factors["duration_long_penalty"] = -0.05

    score = max(0.0, min(1.0, score))
    return ScoreViralityResponse(score=score, factors=factors)


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
def summarize(req: SummarizeRequest, request: Request, x_api_key: Optional[str] = Header(default=None), authorization: Optional[str] = Header(default=None)):
    _ = require_auth(x_api_key, authorization)

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


# Live HLS proxy endpoints (serve GCS HLS via Cloud Run/API Gateway)
def _gcs_read_bytes(path: str) -> bytes:
    if not MEDIA_BUCKET:
        raise HTTPException(status_code=500, detail="MEDIA_BUCKET not configured")
    client = storage.Client(project=PROJECT_ID)
    bucket = client.bucket(MEDIA_BUCKET)
    blob = bucket.blob(path)
    if not blob.exists():
        raise HTTPException(status_code=404, detail="Not found")
    return blob.download_as_bytes()


@app.get("/live/playlist")
def live_playlist():
    # Default location used by Live Stream channel config
    manifest_path = "livestream/outputs/manifest.m3u8"
    try:
        data = _gcs_read_bytes(manifest_path)
    except HTTPException as e:
        raise e
    # Optionally rewrite URIs to route segment requests through /live/segment
    text = data.decode("utf-8", errors="ignore")
    rewritten_lines = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            rewritten_lines.append(raw)
            continue
        # Rewrite any URI line to route through proxy
        rewritten_lines.append(f"/live/file?path={line}")
    out = "\n".join(rewritten_lines) if rewritten_lines else text
    return Response(content=out, media_type="application/vnd.apple.mpegurl")


@app.get("/live/file")
def live_file(path: str):
    if ".." in path or path.startswith("/"):
        raise HTTPException(status_code=400, detail="invalid path")
    # Serve any file (segments, sub-playlists, init mp4) under output prefix
    path = f"livestream/outputs/{path}"
    try:
        data = _gcs_read_bytes(path)
    except HTTPException as e:
        raise e
    content_type = "application/octet-stream"
    lower = path.lower()
    if lower.endswith(".m3u8"):
        content_type = "application/vnd.apple.mpegurl"
    elif lower.endswith(".m4s") or lower.endswith(".mp4"):
        content_type = "video/mp4"
    return Response(content=data, media_type=content_type)


class LiveStatusResponse(BaseModel):
    ok: bool
    has_recent_segments: bool
    latest_object: Optional[str] = None
    latest_updated: Optional[str] = None


@app.get("/live/status", response_model=LiveStatusResponse)
def live_status():
    if not MEDIA_BUCKET:
        raise HTTPException(status_code=500, detail="MEDIA_BUCKET not configured")
    client = storage.Client(project=PROJECT_ID)
    bucket = client.bucket(MEDIA_BUCKET)
    prefix = "livestream/outputs/"
    # List a small set of blobs under the HLS output prefix
    blobs = list(client.list_blobs(bucket, prefix=prefix, max_results=50))
    if not blobs:
        return LiveStatusResponse(ok=True, has_recent_segments=False)
    # Find latest by updated time
    latest = max(blobs, key=lambda b: b.updated or b.time_created)
    latest_time = latest.updated or latest.time_created
    has_recent = False
    try:
        # Recent within last 2 minutes implies channel active
        has_recent = (latest_time is not None) and ((time.time() - latest_time.timestamp()) < 120)
    except Exception:
        has_recent = False
    return LiveStatusResponse(
        ok=True,
        has_recent_segments=has_recent,
        latest_object=latest.name,
        latest_updated=latest_time.isoformat() if latest_time else None,
    )