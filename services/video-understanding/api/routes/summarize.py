from fastapi import APIRouter, Depends
from ..schemas import SummarizeRequest, SummarizeResponse
from ..deps import require_bearer_token


router = APIRouter(tags=["summarize"]) 


@router.post("/summarize", response_model=SummarizeResponse, dependencies=[Depends(require_bearer_token)])
def summarize(req: SummarizeRequest):
    return SummarizeResponse(title="", one_liner="", bullets=[])


