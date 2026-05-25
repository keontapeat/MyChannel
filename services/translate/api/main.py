from fastapi import FastAPI

app = FastAPI()

@app.get('/health')
def health():
    return {"status": "ok"}

@app.post('/translate/captions')
def captions(payload: dict):
    # stub: return URIs
    return {"job": "captions", "targets": payload.get('targetLocales', []), "uris": []}



