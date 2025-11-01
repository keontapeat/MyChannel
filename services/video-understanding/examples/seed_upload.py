import os
import sys
import time
import json
import requests
from google.cloud import storage


API = os.getenv('API_URL', 'http://localhost:8080')
TOKEN = os.getenv('API_AUTH_TOKEN', 'supersecrettoken')
BUCKET = os.getenv('GCS_BUCKET', 'mc-videos')
PROJECT = os.getenv('GCP_PROJECT')


def upload_to_gcs(local_path: str) -> str:
    client = storage.Client(project=PROJECT)
    bucket = client.bucket(BUCKET)
    name = f"uploads/{int(time.time())}_{os.path.basename(local_path)}"
    blob = bucket.blob(name)
    blob.upload_from_filename(local_path)
    return f"gs://{BUCKET}/{name}"


def main():
    if len(sys.argv) < 2:
        print("Usage: python examples/seed_upload.py /path/to/video.mp4")
        sys.exit(1)
    local = sys.argv[1]
    gcs_uri = upload_to_gcs(local)
    print("Uploaded to:", gcs_uri)
    r = requests.post(
        f"{API}/ingest",
        headers={'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'},
        data=json.dumps({'video_gcs_uri': gcs_uri})
    )
    print(r.status_code, r.text)


if __name__ == '__main__':
    main()

