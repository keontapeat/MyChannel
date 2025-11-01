from fastapi import APIRouter


router = APIRouter(tags=["videos"]) 


@router.get("/videos/{video_id}")
def get_video(video_id: str):
    # Placeholder; actual implementation returns metadata and transcript
    return {"id": video_id, "status": "processing"}



