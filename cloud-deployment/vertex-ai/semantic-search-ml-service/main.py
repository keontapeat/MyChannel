#!/usr/bin/env python3
"""
Semantic Search ML Service - MyChannel
Powers the search bar: semantic understanding, intent detection,
auto-complete, typo correction, personalized re-ranking
"""
import os
import logging
import re
from flask import Flask, request, jsonify
from google.cloud import aiplatform

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

PROJECT_ID = os.environ.get("PROJECT_ID", "mychannel-ca26d")
REGION = os.environ.get("REGION", "us-central1")
ENDPOINT_ID = os.environ.get("VERTEX_AI_ENDPOINT_ID", "")

aiplatform.init(project=PROJECT_ID, location=REGION)

# Intent patterns
INTENT_PATTERNS = {
    "live_stream": [r"\blive\b", r"\bstreaming\b", r"\blive now\b"],
    "tutorial": [r"\bhow to\b", r"\btutorial\b", r"\blearn\b", r"\bguide\b"],
    "music": [r"\bsong\b", r"\bmusic\b", r"\balbum\b", r"\blyrics\b", r"\bcover\b"],
    "gaming": [r"\bgame\b", r"\bgaming\b", r"\bplaythrough\b", r"\bclips\b", r"\besports\b"],
    "news": [r"\bnews\b", r"\bbreaking\b", r"\btoday\b", r"\bupdate\b"],
    "creator": [r"\b@\w+\b", r"\bchannel\b", r"\bcreator\b"],
    "trending": [r"\btrending\b", r"\bviral\b", r"\bpopular\b"],
    "shorts": [r"\bshorts?\b", r"\bclip\b", r"\bquick\b"],
}

COMMON_TYPOS = {
    "gameing": "gaming", "musci": "music", "viedo": "video", "toturial": "tutorial",
    "sream": "stream", "steaming": "streaming", "epsorts": "esports", "twich": "twitch",
    "funnny": "funny", "hightlights": "highlights", "highlites": "highlights",
}

TRENDING_SEARCHES = [
    "gaming highlights", "music videos", "live streams", "trending now",
    "funny moments", "esports tournament", "cooking recipes", "fitness workout"
]


def detect_intent(query: str) -> str:
    q = query.lower()
    for intent, patterns in INTENT_PATTERNS.items():
        if any(re.search(p, q) for p in patterns):
            return intent
    return "general"


def correct_typos(query: str) -> tuple:
    words = query.lower().split()
    corrected = [COMMON_TYPOS.get(w, w) for w in words]
    corrected_query = " ".join(corrected)
    was_corrected = corrected_query != query.lower()
    return corrected_query, was_corrected


def generate_autocomplete(query: str, user_history: list) -> list:
    q = query.lower().strip()
    suggestions = []

    # From user search history
    for h in user_history:
        if h.lower().startswith(q) and h.lower() != q:
            suggestions.append({"text": h, "source": "history", "score": 1.0})

    # From trending
    for t in TRENDING_SEARCHES:
        if t.startswith(q) and t != q:
            suggestions.append({"text": t, "source": "trending", "score": 0.8})

    # Query expansions
    expansions = {
        "gam": ["gaming highlights", "gaming news", "gaming setup"],
        "mus": ["music videos", "music live", "music covers"],
        "spo": ["sports highlights", "sports news", "sports live"],
        "com": ["comedy shorts", "comedy skits", "comedy clips"],
        "fit": ["fitness workout", "fitness tips", "fitness transformation"],
    }
    for prefix, exps in expansions.items():
        if q.startswith(prefix):
            for e in exps:
                if e not in [s["text"] for s in suggestions]:
                    suggestions.append({"text": e, "source": "suggestion", "score": 0.6})

    suggestions.sort(key=lambda x: x["score"], reverse=True)
    return suggestions[:8]


def semantic_rank(query: str, results: list, user_context: dict) -> list:
    intent = detect_intent(query)
    query_words = set(query.lower().split())
    user_cats = user_context.get("top_categories", [])

    scored = []
    for r in results:
        score = 0.0
        title = r.get("title", "").lower()
        tags = [t.lower() for t in r.get("tags", [])]
        description = r.get("description", "").lower()

        # Exact title match
        if query.lower() in title:
            score += 0.35
        else:
            word_hits = sum(1 for w in query_words if w in title)
            score += (word_hits / max(len(query_words), 1)) * 0.25

        # Tag match
        tag_hits = sum(1 for w in query_words if w in tags)
        score += min(tag_hits * 0.05, 0.15)

        # Description match
        if query.lower() in description:
            score += 0.08

        # Intent match
        cat = r.get("category", "")
        intent_cat_map = {
            "gaming": "gaming", "music": "music", "tutorial": "education",
            "live_stream": "sports", "news": "news"
        }
        if intent_cat_map.get(intent) == cat:
            score += 0.10

        # Personalization
        if cat in user_cats[:3]:
            score += 0.08

        # Quality signals
        score += r.get("like_ratio", 0) * 0.07
        score += min(r.get("view_count", 0) / 1_000_000.0, 1.0) * 0.05
        if r.get("is_trending"):
            score += 0.05

        scored.append({**r, "relevance_score": round(min(score, 1.0), 4)})

    scored.sort(key=lambda x: x["relevance_score"], reverse=True)
    return scored


@app.route("/predict/search", methods=["POST"])
def search():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        query = data.get("query", "").strip()
        if not query:
            return jsonify({"error": "No query provided"}), 400

        results = data.get("results", [])
        user_context = data.get("user_context", {})
        user_id = data.get("user_id", "anonymous")

        # Typo correction
        corrected_query, was_corrected = correct_typos(query)
        active_query = corrected_query if was_corrected else query

        # Intent detection
        intent = detect_intent(active_query)

        # Semantic ranking
        ranked = semantic_rank(active_query, results, user_context) if results else []

        logging.info(f"Search: query='{query}' intent={intent} results={len(ranked)}")
        return jsonify({"predictions": [{
            "query": query,
            "corrected_query": corrected_query if was_corrected else None,
            "was_corrected": was_corrected,
            "detected_intent": intent,
            "ranked_results": ranked,
            "total": len(ranked),
            "user_id": user_id,
            "confidence": 0.90
        }]}), 200
    except Exception as e:
        logging.error(f"Search error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/predict/autocomplete", methods=["POST"])
def autocomplete():
    try:
        data = request.get_json()
        query = data.get("query", "").strip()
        user_history = data.get("user_search_history", [])
        if len(query) < 2:
            return jsonify({"predictions": [{"suggestions": TRENDING_SEARCHES[:5]}]}), 200
        suggestions = generate_autocomplete(query, user_history)
        return jsonify({"predictions": [{"query": query, "suggestions": suggestions}]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/trending-searches", methods=["GET"])
def trending_searches():
    return jsonify({"predictions": [{"trending": TRENDING_SEARCHES}]}), 200


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "semantic-search-ml", "version": "v1.0"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
