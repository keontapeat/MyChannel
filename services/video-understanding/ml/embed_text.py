from __future__ import annotations
from typing import List
import numpy as np
from sentence_transformers import SentenceTransformer


_model: SentenceTransformer | None = None


def _get_model() -> SentenceTransformer:
    global _model
    if _model is None:
        _model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
    return _model


def embed_texts(texts: List[str]) -> np.ndarray:
    model = _get_model()
    embs = model.encode(texts, normalize_embeddings=True)
    return np.asarray(embs, dtype=np.float32)



