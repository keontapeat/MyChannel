import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from google.cloud import aiplatform, logging as gclogging
from google.cloud import pubsub_v1

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get("PROJECT_ID")
LOCATION = os.environ.get("LOCATION", "us-central1")

if not PROJECT_ID:
    raise RuntimeError("PROJECT_ID or GOOGLE_CLOUD_PROJECT must be set")

gclogging.Client().setup_logging()
aiplatform.init(project=PROJECT_ID, location=LOCATION)

app = FastAPI(title="MyChannel AI")
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, "events")


class SummarizeRequest(BaseModel):
    text: str
    lang: str | None = "en"


@app.get("/")
def root():
    return {"status": "ok"}


@app.post("/ai/summarize")
def summarize(req: SummarizeRequest):
    try:
        from vertexai.generative_models import GenerativeModel
        model = GenerativeModel("gemini-1.5-flash")
        prompt = f"Summarize for video description in {req.lang}: {req.text}"
        resp = model.generate_content(prompt)
        summary = resp.text
        publisher.publish(topic_path, b'{"type":"summarize","ok":true}')
        return {"summary": summary}
    except Exception as e:
        publisher.publish(topic_path, b'{"type":"summarize","ok":false}')
        raise HTTPException(status_code=500, detail=str(e))


