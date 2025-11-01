from fastapi import APIRouter
from ..schemas import ModerateResponse


router = APIRouter(tags=["moderate"]) 


@router.get("/moderate/{video_id}", response_model=ModerateResponse)
def moderate(video_id: str):
    # Placeholder; actual moderation populated by pipeline
    return ModerateResponse(max_nsfw=0.0, flagged_segments=[])



