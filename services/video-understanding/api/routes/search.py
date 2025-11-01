from fastapi import APIRouter, Query
from typing import Optional
from ..schemas import SearchResponse, SegmentHit
from indexing.faiss_index import GlobalFaissIndex


router = APIRouter(tags=["search"]) 
index = GlobalFaissIndex()


@router.get("/search", response_model=SearchResponse)
def search(q: str = Query(...), k: int = Query(10, ge=1, le=200), video_id: Optional[str] = None):
    hits = index.search_text(q, k=k, video_id=video_id)
    return SearchResponse(hits=[SegmentHit(**h) for h in hits])


