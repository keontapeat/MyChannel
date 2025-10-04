import os
import requests
import json
from flask import Request

def tmdb_free_ads_proxy(request: Request):
    """Simple proxy for TMDB free/ads movies that works with Gen1 functions."""
    # Set CORS headers
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET',
        'Access-Control-Allow-Headers': 'Content-Type'
    }
    
    if request.method == 'OPTIONS':
        return ('', 204, headers)
    
    try:
        api_key = os.environ.get("TMDB_API_KEY", "")
        if not api_key:
            return (json.dumps({"error": "Missing TMDB API key"}), 500, headers)

        page = request.args.get("page", "1")
        region = request.args.get("region", "US")

        url = "https://api.themoviedb.org/3/discover/movie"
        params = {
            "api_key": api_key,
            "language": "en-US",
            "sort_by": "popularity.desc",
            "include_adult": "false",
            "include_video": "false",
            "page": page,
            "region": region,
            "with_watch_monetization_types": "free|ads"
        }

        r = requests.get(url, params=params, timeout=10)
        r.raise_for_status()
        data = r.json()

        base_w780 = "https://image.tmdb.org/t/p/w780"
        items = []
        for m in data.get("results", [])[:24]:
            items.append({
                "id": m.get("id"),
                "title": m.get("title") or m.get("name") or "Untitled",
                "overview": m.get("overview", ""),
                "poster": (base_w780 + (m.get("backdrop_path") or m.get("poster_path") or "")),
                "thumb": (base_w780 + (m.get("poster_path") or "")),
                "popularity": m.get("popularity", 0),
                "release_date": m.get("release_date", "")
            })

        return (json.dumps({"items": items}), 200, headers)
    except Exception as e:
        return (json.dumps({"error": str(e)}), 500, headers)
