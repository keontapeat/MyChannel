from fastapi import APIRouter, Depends
from ..deps import require_bearer_token


router = APIRouter(tags=["admin"]) 


@router.post("/admin/reindex", dependencies=[Depends(require_bearer_token)])
def reindex():
    # Placeholder; actual implementation rebuilds FAISS from DB
    return {"ok": True}



