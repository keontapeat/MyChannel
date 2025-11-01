from fastapi import APIRouter
from ..schemas import HealthResponse


router = APIRouter(tags=["health"]) 


@router.get("/health", response_model=HealthResponse)
def health():
    return HealthResponse(versions={"api": "1.0.0", "python": "3.11"})


