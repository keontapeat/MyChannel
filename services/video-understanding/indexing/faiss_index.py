import os
from typing import List, Dict, Optional


class GlobalFaissIndex:
    def __init__(self):
        self.index_path = os.getenv("INDEX_PATH", "/app/data/indexes/main.faiss")
        # Lazy load; real FAISS would be initialized here

    def search_text(self, q: str, k: int = 10, video_id: Optional[str] = None) -> List[Dict]:
        # Placeholder; returns empty list
        return []



