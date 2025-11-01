from __future__ import annotations
import os
import uuid
from typing import Dict, Any


def run_pipeline(video_id: uuid.UUID, gcs_uri: str) -> Dict[str, Any]:
    # Skeleton pipeline; TODO: implement full steps
    return {"video_id": str(video_id), "gcs_uri": gcs_uri, "status": "queued"}



