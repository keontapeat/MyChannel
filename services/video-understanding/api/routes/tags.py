from fastapi import APIRouter
from ..schemas import TagsResponse, TagScore


router = APIRouter(tags=["tags"]) 


@router.get("/tags/{video_id}", response_model=TagsResponse)
def get_tags(video_id: str):
    return TagsResponse(tags=[])


