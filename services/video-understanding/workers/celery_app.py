import os
from celery import Celery


CELERY_BROKER_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
CELERY_BACKEND_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

app = Celery(
    "channelmind",
    broker=CELERY_BROKER_URL,
    backend=CELERY_BACKEND_URL,
    include=["workers.tasks"],
)

app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    task_track_started=True,
    worker_max_tasks_per_child=50,
)


