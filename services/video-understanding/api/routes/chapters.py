from fastapi import APIRouter
from ..schemas import ChaptersResponse, Chapter


router = APIRouter(tags=["chapters"]) 


@router.get("/chapters/{video_id}", response_model=ChaptersResponse)
def get_chapters(video_id: str):
    # Placeholder; actual logic is in workers/pipeline
    return ChaptersResponse(chapters=[])


