import uuid
from fastapi import APIRouter, Depends, HTTPException
from ..schemas import IngestRequest, IngestResponse
from ..deps import require_bearer_token
from workers.celery_app import app as celery


router = APIRouter(tags=["ingest"]) 


@router.post("/ingest", response_model=IngestResponse, dependencies=[Depends(require_bearer_token)])
def ingest(req: IngestRequest):
    video_id = req.video_id or uuid.uuid4()
    task = celery.send_task("tasks.ingest_video", args=[str(video_id), req.video_gcs_uri])
    return IngestResponse(job_id=task.id, video_id=video_id)


