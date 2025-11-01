import os
import logging
from fastapi import FastAPI
from .deps import init_logging
from .routes import health, ingest, search, chapters, tags, summarize, moderate, admin, videos


init_logging()

app = FastAPI(
    title="ChannelMind",
    description="Search any scene. Jump to any moment. AI video intelligence that feels human.",
    version="1.0.0",
)

app.include_router(health.router, prefix="")
app.include_router(ingest.router, prefix="")
app.include_router(search.router, prefix="")
app.include_router(chapters.router, prefix="")
app.include_router(tags.router, prefix="")
app.include_router(summarize.router, prefix="")
app.include_router(moderate.router, prefix="")
app.include_router(admin.router, prefix="")
app.include_router(videos.router, prefix="")


@app.get("/")
def root():
    return {
        "service": "ChannelMind",
        "powered_by": "MyChannel — Powered by ChannelMind",
        "tagline": "Search any scene. Jump to any moment. AI video intelligence that feels human.",
        "status": "ok",
    }


