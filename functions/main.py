# Simple Firebase Functions for MyChannel
from firebase_functions import firestore_fn, https_fn
from firebase_admin import initialize_app, firestore
import logging
import os
import requests
import json
from typing import List, Dict, Any

try:
    # Vertex AI optional import; functions can still run without this configured
    from google.cloud import aiplatform
except Exception:
    aiplatform = None
# --- HTTPS Proxies ---
@https_fn.on_request()
def ai_rank(req: https_fn.Request) -> https_fn.Response:
    """Rank a list of items using Vertex AI (optional). Expects JSON: {items:[{id, title, tags, views, createdAt}], user:{id}}.
    If Vertex isn't configured, returns items unchanged with uniform scores.
    """
    try:
        body = req.get_json(silent=True) or {}
        items: List[Dict[str, Any]] = body.get("items", [])
        user: Dict[str, Any] = body.get("user", {})

        # Default: passthrough
        if not items:
            return https_fn.Response({"items": []}, status=200, headers={"Access-Control-Allow-Origin": "*"})

        project = os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get("GCP_PROJECT")
        location = os.environ.get("VERTEX_LOCATION", "us-central1")
        model_name = os.environ.get("VERTEX_RANKING_MODEL")  # optional custom model

        if aiplatform is None or not project:
            scored = [{**it, "score": 1.0} for it in items]
            return https_fn.Response({"items": scored}, status=200, headers={"Access-Control-Allow-Origin": "*"})

        aiplatform.init(project=project, location=location)

        # Simple feature mapping; replace with your model endpoint if available
        # For demo, we compute a lightweight heuristic score and return
        def heuristic(it: Dict[str, Any]) -> float:
            views = float(it.get("views", 0) or 0)
            recency = 0.0
            try:
                # Expect ISO date or epoch
                created = it.get("createdAt")
                if isinstance(created, (int, float)):
                    recency = max(0.0, 1.0 - ( ( ( ( ( ( ( ( ( (0) ) ) ) ) ) ) ) ) ))
            except Exception:
                pass
            title_boost = 1.0 + (0.2 if str(it.get("title",""))[:1].isupper() else 0.0)
            return title_boost + (views ** 0.5) * 0.01

        scored = sorted(([{**it, "score": heuristic(it)} for it in items]), key=lambda x: x["score"], reverse=True)
        return https_fn.Response({"items": scored}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        logging.exception("ai_rank error")
        return https_fn.Response({"error": str(e)}, status=500, headers={"Access-Control-Allow-Origin": "*"})

# Initialize Firebase Admin
initialize_app()

# Toggle triggers to avoid first‑time Eventarc/Run propagation delays
ENABLE_EMAIL_TRIGGERS = False

# Free streaming provider mapping
FREE_PROVIDERS = {
    "tubi": {"id": "73", "name": "Tubi", "logo": "https://image.tmdb.org/t/p/original/fJ9U8jWNpGNgARAKbO6mhcWTnTG.jpg"},
    "pluto": {"id": "300", "name": "Pluto TV", "logo": "https://image.tmdb.org/t/p/original/peURlLlr8jggOwK53fJ5wdQl05y.jpg"},
    "roku": {"id": "207", "name": "Roku Channel", "logo": "https://image.tmdb.org/t/p/original/avANUOaTNOHdLQhKSWz3qclxcZw.jpg"},
    "freevee": {"id": "613", "name": "Amazon Freevee", "logo": "https://image.tmdb.org/t/p/original/emthp39XA2YScoYL1p0sdbAH2WA.jpg"},
    "plex": {"id": "538", "name": "Plex", "logo": "https://image.tmdb.org/t/p/original/tbEdqQDwx5LEVr8WpSeXQSIirVq.jpg"},
    "crackle": {"id": "12", "name": "Crackle", "logo": "https://image.tmdb.org/t/p/original/8Gt1iClBlzTeQs8WQm8UrCoIxnQ.jpg"}
}

if ENABLE_EMAIL_TRIGGERS:
    @firestore_fn.on_document_created(document="users/{userId}")
    def send_welcome_email(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
        """Trigger when a new user is created"""
        try:
            # Get user data
            user_data = event.data.to_dict()
            email = user_data.get('email')
            username = user_data.get('displayName', 'Creator')
            user_id = event.params['userId']
            language = user_data.get('preferredLanguage', 'en')

            if not email:
                logging.error("No email found for user")
                return

            # For now, just log the beautiful email that would be sent
            logging.info(f"🎬 Beautiful welcome email for {username} ({email}) in {language}")
            logging.info("Subject: 🎬 Welcome to MyChannel - Verify Your Account!")
            logging.info("Template: Multi-language HTML with MyChannel branding")

            # Update user document to track email
            db = firestore.client()
            db.collection('users').document(user_id).update({
                'welcome_email_sent': True,
                'welcome_email_sent_at': firestore.SERVER_TIMESTAMP,
                'email_language': language
            })

            print(f"✅ Welcome email processed for {username} in {language}")
        except Exception as e:
            logging.error(f"❌ Error processing welcome email: {str(e)}")

if ENABLE_EMAIL_TRIGGERS:
    @firestore_fn.on_document_updated(document="users/{userId}")
    def on_email_verified(event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]]) -> None:
        """Send thank you email when user verifies their email"""
        try:
            before_data = event.data.before.to_dict() or {}
            after_data = event.data.after.to_dict() or {}

            # Check if email was just verified
            if before_data.get('emailVerified') or not after_data.get('emailVerified'):
                return

            user_id = event.params['userId']
            email = after_data.get('email')
            username = after_data.get('displayName', 'Creator')
            language = after_data.get('preferredLanguage', 'en')

            if not email:
                return

            # Log the thank you email that would be sent
            logging.info(f"🎉 Thank you email for verified user {username} ({email}) in {language}")
            logging.info("Subject: 🎉 You're verified - Welcome to MyChannel!")
            logging.info("Template: Celebration email with creator benefits")

            # Update user document
            db = firestore.client()
            db.collection('users').document(user_id).update({
                'thank_you_email_sent': True,
                'thank_you_email_sent_at': firestore.SERVER_TIMESTAMP
            })

            print(f"✅ Thank you email processed for verified user {username}")
        except Exception as e:
            logging.error(f"❌ Error processing thank you email: {str(e)}")


# --- HTTPS Proxies ---
@https_fn.on_request()
def tmdb_popular(req: https_fn.Request) -> https_fn.Response:
    """Proxy to fetch popular movies from TMDB without exposing API key to clients."""
    try:
        api_key = os.environ.get("TMDB_API_KEY", "")
        if not api_key:
            return https_fn.Response("Missing TMDB API key", status=500)

        page = req.args.get("page", "1")
        region = req.args.get("region", "US")
        url = "https://api.themoviedb.org/3/movie/popular"
        r = requests.get(url, params={
            "api_key": api_key,
            "page": page,
            "region": region,
            "language": "en-US"
        }, timeout=10)
        r.raise_for_status()
        data = r.json()

        # Normalize minimal fields for the client
        items = []
        base = "https://image.tmdb.org/t/p/w780"
        for m in data.get("results", [])[:24]:
            items.append({
                "id": m.get("id"),
                "title": m.get("title") or m.get("name") or "Untitled",
                "overview": m.get("overview", ""),
                "poster": (base + m["backdrop_path"]) if m.get("backdrop_path") else (base + (m.get("poster_path") or "")),
                "thumb": (base + (m.get("poster_path") or "")),
                "popularity": m.get("popularity", 0),
                "release_date": m.get("release_date", "")
            })

        return https_fn.Response({"items": items}, status=200)
    except Exception as e:
        logging.exception("TMDB proxy error")
        return https_fn.Response({"error": str(e)}, status=500)


# --- HTTPS: Free/Ads-supported movies (US) ---
@https_fn.on_request()
def tmdb_free_ads(req: https_fn.Request) -> https_fn.Response:
    """Discover movies available free/ad-supported in a given region (default US)."""
    try:
        api_key = os.environ.get("TMDB_API_KEY", "")
        if not api_key:
            return https_fn.Response({"error": "Missing TMDB API key"}, status=500, headers={"Access-Control-Allow-Origin": "*"})

        page = req.args.get("page", "1")
        region = req.args.get("region", "US")
        provider = req.args.get("provider", "all")  # all, tubi, pluto, roku, etc.

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

        # Add provider-specific filtering
        provider_ids = {
            "tubi": "73",      # Tubi
            "pluto": "300",    # Pluto TV
            "roku": "207",     # Roku Channel
            "freevee": "613",  # Amazon Freevee
            "plex": "538",     # Plex
            "crackle": "12",   # Crackle
            "imdb": "613"       # IMDb TV (now Freevee)
        }
        
        if provider != "all" and provider in provider_ids:
            params["with_watch_providers"] = provider_ids[provider]

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
                "release_date": m.get("release_date", ""),
                "vote_average": m.get("vote_average", 0),
                "genre_ids": m.get("genre_ids", [])
            })

        return https_fn.Response({"items": items, "provider": provider}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        logging.exception("TMDB free/ads proxy error")
        return https_fn.Response({"error": str(e)}, status=500, headers={"Access-Control-Allow-Origin": "*"})


@https_fn.on_request()
def tmdb_trending(req: https_fn.Request) -> https_fn.Response:
    """Get trending movies and TV shows from TMDB."""
    try:
        api_key = os.environ.get("TMDB_API_KEY", "")
        if not api_key:
            return https_fn.Response({"error": "Missing TMDB API key"}, status=500, headers={"Access-Control-Allow-Origin": "*"})

        media_type = req.args.get("media_type", "movie")  # movie, tv, all
        time_window = req.args.get("time_window", "week")  # day, week
        
        url = f"https://api.themoviedb.org/3/trending/{media_type}/{time_window}"
        params = {
            "api_key": api_key,
            "language": "en-US"
        }

        r = requests.get(url, params=params, timeout=10)
        r.raise_for_status()
        data = r.json()

        base_w780 = "https://image.tmdb.org/t/p/w780"
        items = []
        for m in data.get("results", [])[:20]:
            items.append({
                "id": m.get("id"),
                "title": m.get("title") or m.get("name") or "Untitled",
                "overview": m.get("overview", ""),
                "poster": (base_w780 + (m.get("backdrop_path") or m.get("poster_path") or "")),
                "thumb": (base_w780 + (m.get("poster_path") or "")),
                "popularity": m.get("popularity", 0),
                "release_date": m.get("release_date") or m.get("first_air_date", ""),
                "vote_average": m.get("vote_average", 0),
                "media_type": m.get("media_type", media_type)
            })

        return https_fn.Response({"items": items, "media_type": media_type}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        logging.exception("TMDB trending proxy error")
        return https_fn.Response({"error": str(e)}, status=500, headers={"Access-Control-Allow-Origin": "*"})


@https_fn.on_request()
def tmdb_details(req: https_fn.Request) -> https_fn.Response:
    """Get detailed movie/TV show information including watch providers."""
    try:
        api_key = os.environ.get("TMDB_API_KEY", "")
        if not api_key:
            return https_fn.Response({"error": "Missing TMDB API key"}, status=500, headers={"Access-Control-Allow-Origin": "*"})

        media_type = req.args.get("media_type", "movie")  # movie or tv
        media_id = req.args.get("id")
        
        if not media_id:
            return https_fn.Response({"error": "Missing media ID"}, status=400, headers={"Access-Control-Allow-Origin": "*"})

        # Get basic details
        details_url = f"https://api.themoviedb.org/3/{media_type}/{media_id}"
        providers_url = f"https://api.themoviedb.org/3/{media_type}/{media_id}/watch/providers"
        
        params = {
            "api_key": api_key,
            "language": "en-US"
        }

        # Fetch details and providers
        details_r = requests.get(details_url, params=params, timeout=10)
        providers_r = requests.get(providers_url, params=params, timeout=10)
        
        details_r.raise_for_status()
        providers_r.raise_for_status()
        
        details_data = details_r.json()
        providers_data = providers_r.json()

        base_w780 = "https://image.tmdb.org/t/p/w780"
        
        # Extract watch providers for US
        us_providers = providers_data.get("results", {}).get("US", {})
        free_providers = us_providers.get("free", [])
        
        result = {
            "id": details_data.get("id"),
            "title": details_data.get("title") or details_data.get("name") or "Untitled",
            "overview": details_data.get("overview", ""),
            "poster": (base_w780 + (details_data.get("backdrop_path") or details_data.get("poster_path") or "")),
            "thumb": (base_w780 + (details_data.get("poster_path") or "")),
            "release_date": details_data.get("release_date") or details_data.get("first_air_date", ""),
            "vote_average": details_data.get("vote_average", 0),
            "runtime": details_data.get("runtime") or details_data.get("episode_run_time", [0])[0] if details_data.get("episode_run_time") else 0,
            "genres": [g.get("name", "") for g in details_data.get("genres", [])],
            "watch_providers": {
                "free": [{
                    "provider_name": p.get("provider_name", ""),
                    "logo_path": "https://image.tmdb.org/t/p/w92" + (p.get("logo_path") or ""),
                    "provider_id": p.get("provider_id")
                } for p in free_providers]
            },
            "media_type": media_type
        }

        return https_fn.Response(result, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        logging.exception("TMDB details proxy error")
        return https_fn.Response({"error": str(e)}, status=500, headers={"Access-Control-Allow-Origin": "*"})