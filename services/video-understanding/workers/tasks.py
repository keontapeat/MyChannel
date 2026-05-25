import os
import uuid
from .celery_app import app
from .pipeline import run_pipeline


@app.task(name="tasks.ingest_video")
def ingest_video(video_id: str, gcs_uri: str):
    vid = uuid.UUID(video_id)
    return run_pipeline(vid, gcs_uri)



