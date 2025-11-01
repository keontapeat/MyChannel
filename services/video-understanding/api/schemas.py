from typing import List, Optional
from uuid import UUID
from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = "ok"
    versions: dict = Field(default_factory=dict)


class IngestRequest(BaseModel):
    video_gcs_uri: str
    video_id: Optional[UUID] = None


class IngestResponse(BaseModel):
    job_id: str
    video_id: UUID


class SegmentHit(BaseModel):
    video_id: str
    t_start: float
    t_end: float
    score: float
    keyframe_url: Optional[str]
    text_snippet: Optional[str]


class SearchResponse(BaseModel):
    hits: List[SegmentHit]


class Chapter(BaseModel):
    title: str
    t_start: float
    t_end: float
    summary: Optional[str]


class ChaptersResponse(BaseModel):
    chapters: List[Chapter]


class TagScore(BaseModel):
    tag: str
    score: float


class TagsResponse(BaseModel):
    tags: List[TagScore]


class ModerateResponse(BaseModel):
    max_nsfw: float
    flagged_segments: List[str]


class SummarizeRequest(BaseModel):
    video_id: str


class SummarizeResponse(BaseModel):
    title: str
    one_liner: str
    bullets: List[str]


