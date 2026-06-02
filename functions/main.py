# Simple Firebase Functions for MyChannel
from firebase_functions import firestore_fn, https_fn, scheduler_fn, options
from firebase_admin import initialize_app, firestore, auth as admin_auth, messaging
import logging
from datetime import datetime, timezone, timedelta
import os
import requests
import json
from typing import List, Dict, Any

# --- Common headers helpers for performance ---
options.set_global_options(cpu="gcf_gen1", max_instances=3)

def cache_headers_public(seconds: int = 300) -> Dict[str, str]:
    return {
        "Cache-Control": f"public, max-age={seconds}, s-maxage={seconds * 4}, stale-while-revalidate=60",
        "Vary": "Accept-Encoding",
        "Access-Control-Allow-Origin": "*",
    }

def cache_headers_no_store() -> Dict[str, str]:
    return {
        "Cache-Control": "no-store",
        "Vary": "Accept-Encoding",
        "Access-Control-Allow-Origin": "*",
    }

try:
    # Vertex AI optional import; functions can still run without this configured
    from google.cloud import aiplatform
except Exception:
    aiplatform = None
# --- HTTPS: Report content (callable-like via POST) ---
@https_fn.on_request()
def report_content(req: https_fn.Request) -> https_fn.Response:
    """Report a video or user. Body: {type: 'video'|'user', id: string, reason: string}."""
    try:
        if req.method == 'OPTIONS':
            return https_fn.Response('', status=204, headers={"Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type, Authorization"})
        # Verify Firebase Auth ID token from Authorization: Bearer <token>
        auth_header = req.headers.get('Authorization') or req.headers.get('authorization') or ''
        if not auth_header.lower().startswith('bearer '):
            return https_fn.Response({'error': 'unauthorized'}, status=401, headers=cache_headers_no_store())
        id_token = auth_header.split(' ', 1)[1].strip()
        try:
            decoded = admin_auth.verify_id_token(id_token)
            reporter_uid = decoded.get('uid')
            if not reporter_uid:
                return https_fn.Response({'error': 'unauthorized'}, status=401, headers=cache_headers_no_store())
        except Exception:
            return https_fn.Response({'error': 'unauthorized'}, status=401, headers=cache_headers_no_store())
        data = req.get_json(silent=True) or {}
        item_type = (data.get('type') or '').strip()
        item_id = (data.get('id') or '').strip()
        reason = (data.get('reason') or '').strip()
        if not item_type or not item_id or not reason:
            return https_fn.Response({'error': 'missing_fields'}, status=400, headers=cache_headers_no_store())
        # Write to Firestore collection for moderation triage
        doc = firestore.client().collection('reports').document()
        doc.set({
            'type': item_type,
            'itemId': item_id,
            'reason': reason,
            'reporterUid': reporter_uid,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
        return https_fn.Response({'ok': True}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        logging.exception('report_content error')
        return https_fn.Response({'error': str(e)}, status=500, headers=cache_headers_no_store())

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
            return https_fn.Response({"items": []}, status=200, headers=cache_headers_no_store())

        project = os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get("GCP_PROJECT")
        location = os.environ.get("VERTEX_LOCATION", "us-central1")
        model_name = os.environ.get("VERTEX_RANKING_MODEL")  # optional custom model

        if aiplatform is None or not project:
            scored = [{**it, "score": 1.0} for it in items]
            return https_fn.Response({"items": scored}, status=200, headers=cache_headers_no_store())

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
        return https_fn.Response({"items": scored}, status=200, headers=cache_headers_no_store())
    except Exception as e:
        logging.exception("ai_rank error")
        return https_fn.Response({"error": str(e)}, status=500, headers=cache_headers_no_store())

# Initialize Firebase Admin
initialize_app()

def _safe_firestore_client():
    """Return a Firestore client, tolerating the absence of Application Default
    Credentials during local deploy-time code analysis. In production (and in the
    running function) ADC is always present, so this returns a real client. During
    `firebase deploy` the CLI imports this module on a dev machine that may lack
    ADC; function bodies never run at analysis time, so a deferred client is safe.
    Callers at module scope must tolerate `None` (they only execute in prod).
    """
    try:
        return firestore.client()
    except Exception:
        logging.warning("firestore.client() unavailable at import (no ADC?); deferring.")
        return None

db = _safe_firestore_client()
# --- Firestore Triggers: counters ---
@firestore_fn.on_document_created(document="videos/{videoId}/comments/{commentId}")
def on_comment_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        params = event.params
        video_id = params["videoId"]
        vid_ref = db.collection('videos').document(video_id)
        vid_ref.update({ 'commentCount': firestore.Increment(1) })
    except Exception:
        logging.exception('on_comment_created')

@firestore_fn.on_document_deleted(document="videos/{videoId}/comments/{commentId}")
def on_comment_deleted(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        params = event.params
        video_id = params["videoId"]
        vid_ref = db.collection('videos').document(video_id)
        vid_ref.update({ 'commentCount': firestore.Increment(-1) })
    except Exception:
        logging.exception('on_comment_deleted')

@firestore_fn.on_document_created(document="videos/{videoId}/likes/{uid}")
def on_like_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        video_id = event.params["videoId"]
        db.collection('videos').document(video_id).update({ 'likeCount': firestore.Increment(1) })
    except Exception:
        logging.exception('on_like_created')

@firestore_fn.on_document_deleted(document="videos/{videoId}/likes/{uid}")
def on_like_deleted(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        video_id = event.params["videoId"]
        db.collection('videos').document(video_id).update({ 'likeCount': firestore.Increment(-1) })
    except Exception:
        logging.exception('on_like_deleted')

@firestore_fn.on_document_created(document="video_analytics/{videoId}/views/{viewId}")
def on_video_view_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        video_id = event.params["videoId"]
        snap = event.data
        data = snap.to_dict() if snap else {}
        watch_duration = int(data.get("watchDuration") or 0)
        update_data = {
            "viewCount": firestore.Increment(1),
            "lastViewedAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if watch_duration > 0:
            update_data["totalWatchTime"] = firestore.Increment(watch_duration)
            update_data["lastWatched"] = firestore.SERVER_TIMESTAMP
        db.collection('videos').document(video_id).set(update_data, merge=True)
    except Exception:
        logging.exception('on_video_view_created')

@firestore_fn.on_document_created(document="flicks/{shortId}/events/{eventId}")
def on_short_event_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        short_id = event.params["shortId"]
        snap = event.data
        data = snap.to_dict() if snap else {}
        event_type = data.get("type") or data.get("eventType")
        update_data = {"updatedAt": firestore.SERVER_TIMESTAMP}
        if event_type == "view":
            update_data["viewCount"] = firestore.Increment(1)
            update_data["lastViewed"] = firestore.SERVER_TIMESTAMP
            watch_time = int(data.get("watchTime") or data.get("watchDuration") or 0)
            if watch_time > 0:
                update_data["totalWatchTime"] = firestore.Increment(watch_time)
        elif event_type == "like":
            update_data["likeCount"] = firestore.Increment(1)
        elif event_type == "unlike":
            update_data["likeCount"] = firestore.Increment(-1)
        elif event_type == "comment":
            update_data["commentCount"] = firestore.Increment(1)
        elif event_type == "share":
            update_data["shareCount"] = firestore.Increment(1)
        else:
            return
        db.collection('flicks').document(short_id).set(update_data, merge=True)
    except Exception:
        logging.exception('on_short_event_created')

@firestore_fn.on_document_created(document="stories/{storyId}/events/{eventId}")
def on_story_event_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        story_id = event.params["storyId"]
        snap = event.data
        data = snap.to_dict() if snap else {}
        event_type = data.get("type") or data.get("eventType")
        update_data = {"updatedAt": firestore.SERVER_TIMESTAMP}
        if event_type == "view":
            update_data["viewCount"] = firestore.Increment(1)
            update_data["lastViewed"] = firestore.SERVER_TIMESTAMP
            view_duration = int(data.get("viewDuration") or data.get("watchDuration") or 0)
            if view_duration > 0:
                update_data["totalViewTime"] = firestore.Increment(view_duration)
        elif event_type == "like":
            update_data["likeCount"] = firestore.Increment(1)
        elif event_type == "unlike":
            update_data["likeCount"] = firestore.Increment(-1)
        elif event_type == "comment":
            update_data["commentCount"] = firestore.Increment(1)
        elif event_type == "share":
            update_data["shareCount"] = firestore.Increment(1)
        else:
            return
        db.collection('stories').document(story_id).set(update_data, merge=True)
    except Exception:
        logging.exception('on_story_event_created')

@firestore_fn.on_document_created(document="users/{creatorId}/subscribers/{uid}")
def on_subscribe_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        creator = event.params['creatorId']
        db.collection('users').document(creator).update({ 'subscribersCount': firestore.Increment(1) })
    except Exception:
        logging.exception('on_subscribe_created')

@firestore_fn.on_document_deleted(document="users/{creatorId}/subscribers/{uid}")
def on_subscribe_deleted(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        creator = event.params['creatorId']
        db.collection('users').document(creator).update({ 'subscribersCount': firestore.Increment(-1) })
    except Exception:
        logging.exception('on_subscribe_deleted')


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
            return https_fn.Response({"error": "Missing TMDB API key"}, status=500, headers=cache_headers_no_store())

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

        return https_fn.Response({"items": items}, status=200, headers=cache_headers_public(300))
    except Exception as e:
        logging.exception("TMDB proxy error")
        return https_fn.Response({"error": str(e)}, status=500, headers=cache_headers_no_store())


# --- HTTPS: Free/Ads-supported movies (US) ---
@https_fn.on_request()
def tmdb_free_ads(req: https_fn.Request) -> https_fn.Response:
    """Discover movies available free/ad-supported in a given region (default US)."""
    try:
        api_key = os.environ.get("TMDB_API_KEY", "")
        if not api_key:
            return https_fn.Response({"error": "Missing TMDB API key"}, status=500, headers=cache_headers_no_store())

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

        return https_fn.Response({"items": items, "provider": provider}, status=200, headers=cache_headers_public(300))
    except Exception as e:
        logging.exception("TMDB free/ads proxy error")
        return https_fn.Response({"error": str(e)}, status=500, headers=cache_headers_no_store())


@https_fn.on_request()
def tmdb_trending(req: https_fn.Request) -> https_fn.Response:
    """Get trending movies and TV shows from TMDB."""
    try:
        api_key = os.environ.get("TMDB_API_KEY", "")
        if not api_key:
            return https_fn.Response({"error": "Missing TMDB API key"}, status=500, headers=cache_headers_no_store())

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


# --- HTTPS: reCAPTCHA v3 verification ---
@https_fn.on_request()
def recaptcha_verify(req: https_fn.Request) -> https_fn.Response:
    """Verify reCAPTCHA v3 token server-side. Expects JSON {token, action}.
    Reads secret from env RECAPTCHA_SECRET.
    """
    try:
        # CORS preflight
        if req.method == 'OPTIONS':
            return https_fn.Response('', status=204, headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type"
            })

        body = req.get_json(silent=True) or {}
        token = body.get('token', '')
        action = body.get('action', '')
        secret = os.environ.get('RECAPTCHA_SECRET', '')

        # If not configured, do not block the flow but report
        if not secret or not token:
            return https_fn.Response({
                'success': False,
                'error': 'not_configured' if not secret else 'missing_token',
                'score': None,
                'action': action
            }, status=200, headers={"Access-Control-Allow-Origin": "*"})

        resp = requests.post(
            'https://www.google.com/recaptcha/api/siteverify',
            data={
                'secret': secret,
                'response': token
            },
            timeout=5
        )
        data = resp.json()
        result = {
            'success': bool(data.get('success')),
            'score': data.get('score'),
            'action': data.get('action') or action,
            'hostname': data.get('hostname')
        }
        return https_fn.Response(result, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        return https_fn.Response({'success': False, 'error': str(e)}, status=200, headers={"Access-Control-Allow-Origin": "*"})


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
            return https_fn.Response({"error": "Missing media ID"}, status=400, headers=cache_headers_no_store())

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

        return https_fn.Response(result, status=200, headers=cache_headers_public(600))
    except Exception as e:
        logging.exception("TMDB details proxy error")
        return https_fn.Response({"error": str(e)}, status=500, headers=cache_headers_no_store())


@https_fn.on_request()
def events_view(req: https_fn.Request) -> https_fn.Response:
    """Increment sharded view counter for a video. Expects JSON {videoId}."""
    try:
        body = req.get_json(silent=True) or {}
        video_id = body.get("videoId")
        if not video_id:
            return https_fn.Response({"error": "missing videoId"}, status=400, headers=cache_headers_no_store())
        import random
        shard = random.randint(0, 49)
        shard_ref = db.collection('videos').document(video_id).collection('view_shards').document(str(shard))
        shard_ref.set({"count": firestore.Increment(1), "updatedAt": firestore.SERVER_TIMESTAMP}, merge=True)
        return https_fn.Response({"ok": True}, status=200, headers=cache_headers_no_store())
    except Exception as e:
        logging.exception("events_view error")
        return https_fn.Response({"error": str(e)}, status=500, headers=cache_headers_no_store())


# =============================
# New Stubs for Parity Features
# =============================

@firestore_fn.on_document_created(document="uploads/{uploadId}")
def on_upload_created_trigger(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    """Start a transcode job when an upload record is created.
    Expects uploads/{uploadId}: { videoId, ownerUid, sourcePath }
    """
    try:
        snap = event.data
        data = snap.to_dict() or {}
        video_id = data.get("videoId")
        owner_uid = data.get("ownerUid")
        source_path = data.get("sourcePath")
        if not (video_id and owner_uid and source_path):
            logging.warning("on_upload_created missing required fields")
            return
        # Mark video processing status
        firestore.client().collection('videos').document(video_id).set({
            'status': 'processing',
            'updatedAt': firestore.SERVER_TIMESTAMP
        }, merge=True)
        # TODO: Integrate Transcoder API job creation here
        logging.info(f"[transcode] queued for {video_id} from {source_path}")
    except Exception:
        logging.exception('on_upload_created')


@firestore_fn.on_document_updated(document="videos/{videoId}")
def on_video_ready(event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]]) -> None:
    """When a video's status transitions to ready, notify subscribers and enqueue follow-ups."""
    try:
        before = (event.data.before.to_dict() or {}).get('status')
        after = (event.data.after.to_dict() or {}).get('status')
        if before == 'ready' or after != 'ready':
            return
        vid = event.params['videoId']
        video_after = event.data.after.to_dict() or {}
        owner_uid = video_after.get('ownerUid')
        if not owner_uid:
            return
        # Minimal: insert a notification stub
        firestore.client().collection('notifications').add({
            'type': 'video_ready',
            'videoId': vid,
            'ownerUid': owner_uid,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
        # Fanout to FCM topic for the creator (clients subscribe to topic: creator_{owner_uid})
        try:
            topic = f"creator_{owner_uid}"
            title = video_after.get('title') or 'New upload'
            message = messaging.Message(
                notification=messaging.Notification(
                    title=f"{title}",
                    body="Tap to watch now"
                ),
                topic=topic,
                data={
                    'type': 'video_ready',
                    'videoId': vid,
                    'ownerUid': owner_uid
                }
            )
            messaging.send(message)
        except Exception:
            logging.exception('[video_ready] fcm fanout')
        # Fanout to subscribers' feeds collection: feeds/{uid}/items
        try:
            subs_ref = db.collection('users').document(owner_uid).collection('subscribers')
            subs = subs_ref.limit(500).stream()
            batch = db.batch()
            count = 0
            for sub in subs:
                sub_uid = sub.id
                feed_item = {
                    'videoId': vid,
                    'ownerUid': owner_uid,
                    'title': video_after.get('title') or '',
                    'thumb': (video_after.get('thumbnails', {}) or {}).get('default') or video_after.get('thumbnailURL', ''),
                    'createdAt': firestore.SERVER_TIMESTAMP
                }
                feed_doc = db.collection('feeds').document(sub_uid).collection('items').document(vid)
                batch.set(feed_doc, feed_item, merge=True)
                count += 1
                if count % 400 == 0:
                    batch.commit(); batch = db.batch()
            batch.commit()
            logging.info(f"[video_ready] feed fanout items: {count}")
        except Exception:
            logging.exception('[video_ready] feed fanout')
        # TODO: enqueue captions AI, update explore
        logging.info(f"[video_ready] fanout queued for {vid}")
    except Exception:
        logging.exception('on_video_ready')


@firestore_fn.on_document_created(document="tips/{tipId}")
def on_tip_received(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    """Accrue tip into earnings for the creator's channel."""
    try:
        tip = event.data.to_dict() or {}
        channel_id = tip.get('channelId')
        amount_cents = int(tip.get('amountCents') or 0)
        if not channel_id or amount_cents <= 0:
            return
        now = datetime.now(timezone.utc)
        ym = now.strftime('%Y%m')
        doc = firestore.client().collection('earnings').document(channel_id).collection('months').document(ym)
        doc.set({
            'totals': firestore.ArrayUnion([]),  # ensures doc exists
            'updatedAt': firestore.SERVER_TIMESTAMP
        }, merge=True)
        doc.update({
            'totals.ads': firestore.Increment(0),
            'totals.tips': firestore.Increment(amount_cents / 100.0),
            'totals.subs': firestore.Increment(0),
            'totals.ppv': firestore.Increment(0)
        })
        logging.info(f"[tips] accrued {amount_cents}c to {channel_id}:{ym}")
    except Exception:
        logging.exception('on_tip_received')


@firestore_fn.on_document_created(document="memberships/{membershipId}/payments/{paymentId}")
def on_membership_renew(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    """Update entitlements on membership renewal."""
    try:
        pay = event.data.to_dict() or {}
        user_id = pay.get('userId')
        channel_id = pay.get('channelId')
        if not (user_id and channel_id):
            return
        firestore.client().collection('users').document(user_id).set({
            'entitlements': { f"channel:{channel_id}": True },
            'entitlementsUpdatedAt': firestore.SERVER_TIMESTAMP
        }, merge=True)
        logging.info(f"[membership] renewed {user_id} -> {channel_id}")
    except Exception:
        logging.exception('on_membership_renew')


@https_fn.on_request()
def referral_create(req: https_fn.Request) -> https_fn.Response:
    """Create a referral code for the authenticated user."""
    try:
        # Optional auth
        auth_header = req.headers.get('Authorization') or ''
        uid_decoded = None
        if auth_header.lower().startswith('bearer '):
            try:
                decoded = admin_auth.verify_id_token(auth_header.split(' ',1)[1].strip())
                uid_decoded = decoded.get('uid')
            except Exception:
                pass
        data = req.get_json(silent=True) or {}
        owner_uid = data.get('ownerUid') or uid_decoded
        if not owner_uid:
            return https_fn.Response({'error': 'unauthorized'}, status=401, headers=cache_headers_no_store())
        import random, string
        code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))
        firestore.client().collection('referrals').document(code).set({
            'ownerUid': owner_uid,
            'createdAt': firestore.SERVER_TIMESTAMP,
            'clicks': 0,
            'installs': 0,
            'activations': 0
        })
        return https_fn.Response({'code': code}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        logging.exception('referral_create')
        return https_fn.Response({'error': str(e)}, status=500, headers=cache_headers_no_store())


@https_fn.on_request()
def reviews_eligibility(req: https_fn.Request) -> https_fn.Response:
    """Return whether the user is eligible for in-app review prompt.
    Placeholder: wire to analytics thresholds (watch time + sessions).
    """
    try:
        body = req.get_json(silent=True) or {}
        user_id = body.get('userId')
        if not user_id:
            return https_fn.Response({'eligible': False, 'reason': 'missing_user'}, status=200, headers={"Access-Control-Allow-Origin": "*"})
        # TODO: compute from GA4/BigQuery exports
        return https_fn.Response({'eligible': False, 'reason': 'not_implemented'}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        return https_fn.Response({'eligible': False, 'error': str(e)}, status=200, headers={"Access-Control-Allow-Origin": "*"})


@https_fn.on_request()
def growth_aso_sync(req: https_fn.Request) -> https_fn.Response:
    try:
        # TODO: pull keywords from store APIs and update growth/keyword_bank
        return https_fn.Response({'ok': True}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        return https_fn.Response({'error': str(e)}, status=500, headers=cache_headers_no_store())


@https_fn.on_request()
def growth_aso_publish(req: https_fn.Request) -> https_fn.Response:
    try:
        # TODO: publish winning ASO variants
        return https_fn.Response({'ok': True}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        return https_fn.Response({'error': str(e)}, status=500, headers=cache_headers_no_store())


@https_fn.on_request()
def ads_serve(req: https_fn.Request) -> https_fn.Response:
    """Proxy to Ads service /ads/serve if configured by ADS_BASE_URL env.
    Body passthrough.
    """
    try:
        base = os.environ.get('ADS_BASE_URL')
        if not base:
            return https_fn.Response({'error': 'ADS_BASE_URL not configured'}, status=500, headers=cache_headers_no_store())
        body = req.get_json(silent=True) or {}
        r = requests.post(f"{base.rstrip('/')}/ads/serve", json=body, timeout=5)
        return https_fn.Response(r.json(), status=r.status_code, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        logging.exception('ads_serve proxy')
        return https_fn.Response({'error': str(e)}, status=500, headers=cache_headers_no_store())


# ============================================================
# 🎯 FEATURE CARD (#1–#10) — server-side activation & expiry
# ============================================================
#
# The iOS client previously activated/expired paid Feature Card bookings only
# while an ADMIN device had the app open (the sync was gated on `isAdmin`). That
# meant a creator's paid slot could go live late, or stay live past its end date,
# if the admin wasn't around. This scheduled function makes activation/expiry
# authoritative and admin-independent.
#
# Collections (must match FeatureSlotService.swift):
#   feature_slot_bookings/{id}: {
#       videoId, creatorId, videoTitle, videoThumbnail, creatorName,
#       rank (1-10), duration, pricePaid, startDate (ts), endDate (ts),
#       paymentStatus, status, payByDate (ts?), ...
#   }
#   featured_videos/{videoId}: the live Home carousel (priority = rank).
#
# Money safety: this function NEVER moves money. It only flips booking status and
# mirrors live PAID bookings into featured_videos. Charges happen client-side via
# StoreKit IAP (review-before-pay), so there is nothing to refund here.

FEATURE_BOOKINGS = "feature_slot_bookings"
FEATURED_VIDEOS = "featured_videos"
FEATURE_TOTAL_SLOTS = 10


def _ts_to_dt(value):
    """Best-effort convert a Firestore timestamp/datetime to aware datetime (UTC)."""
    if value is None:
        return None
    try:
        # Firestore python returns datetime for timestamp fields.
        if isinstance(value, datetime):
            return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
        # google.cloud Timestamp-like
        if hasattr(value, "ToDatetime"):
            dt = value.ToDatetime()
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        if hasattr(value, "timestamp"):
            return datetime.fromtimestamp(value.timestamp(), tz=timezone.utc)
    except Exception:
        logging.exception("_ts_to_dt conversion failed")
    return None


def _sync_live_bookings_to_featured_card(client) -> None:
    """Mirror currently-live PAID bookings into featured_videos (priority = rank),
    and remove paid-slot featured docs that are no longer live. Mirrors the iOS
    FeatureSlotService.syncLiveBookingsToFeaturedCard() so the two never diverge.
    """
    try:
        now = datetime.now(timezone.utc)
        live_snap = client.collection(FEATURE_BOOKINGS).where("status", "==", "active").stream()
        live_video_ids = set()
        for doc in live_snap:
            b = doc.to_dict() or {}
            start = _ts_to_dt(b.get("startDate"))
            end = _ts_to_dt(b.get("endDate"))
            # Only mirror PAID bookings whose window actually contains "now".
            if b.get("paymentStatus") != "completed":
                continue
            if start and now < start:
                continue
            if end and now > end:
                continue
            video_id = b.get("videoId")
            if not video_id:
                continue
            rank = int(b.get("rank") or FEATURE_TOTAL_SLOTS)
            live_video_ids.add(video_id)

            # Ensure the underlying video doc exists for the client to hydrate.
            client.collection("videos").document(video_id).set({
                "id": video_id,
                "title": b.get("videoTitle") or "",
                "thumbnailURL": b.get("videoThumbnail") or "",
                "thumbnailUrl": b.get("videoThumbnail") or "",
                "creatorId": b.get("creatorId") or "",
                "userId": b.get("creatorId") or "",
                "creatorName": b.get("creatorName") or "",
                "creatorDisplayName": b.get("creatorName") or "",
                "isPublic": True,
                "visibility": "public",
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)

            client.collection(FEATURED_VIDEOS).document(video_id).set({
                "videoId": video_id,
                "priority": rank,            # #1 → priority 1 → shown first (ascending)
                "source": "paid_slot",
                "bookingId": doc.id,
                "expiresAt": b.get("endDate"),
                "addedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)

        # Remove paid-slot featured docs that are no longer live.
        paid_docs = client.collection(FEATURED_VIDEOS).where("source", "==", "paid_slot").stream()
        for doc in paid_docs:
            vid = (doc.to_dict() or {}).get("videoId") or doc.id
            if vid not in live_video_ids:
                doc.reference.delete()
    except Exception:
        logging.exception("_sync_live_bookings_to_featured_card")


@scheduler_fn.on_schedule(
    schedule="every 15 minutes",
    region="us-east1",            # us-central1 CPU quota is exhausted; us-east1 has headroom
    memory=options.MemoryOption.MB_256,
    max_instances=1,              # low-frequency job — keep CPU reservation minimal
    concurrency=1,
)
def feature_slot_lifecycle(event: scheduler_fn.ScheduledEvent) -> None:
    """Activate scheduled bookings, complete finished ones, release unpaid holds,
    then re-sync the live Feature Card. Runs independently of any admin device.
    """
    try:
        client = firestore.client()
        now = datetime.now(timezone.utc)
        changed = False

        # Only bookings in a transitional state matter.
        statuses = ["approvedAwaitingPayment", "scheduled", "active"]
        snap = client.collection(FEATURE_BOOKINGS).where("status", "in", statuses).stream()

        for doc in snap:
            b = doc.to_dict() or {}
            status = b.get("status")
            start = _ts_to_dt(b.get("startDate"))
            end = _ts_to_dt(b.get("endDate"))
            pay_by = _ts_to_dt(b.get("payByDate"))

            if status == "scheduled" and start and end and start <= now <= end:
                doc.reference.update({"status": "active", "updatedAt": firestore.SERVER_TIMESTAMP})
                changed = True
            elif status in ("active", "scheduled") and end and now > end:
                doc.reference.update({"status": "completed", "updatedAt": firestore.SERVER_TIMESTAMP})
                changed = True
                _notify_waitlist_for_freed_slot(client, int(b.get("rank") or 0))
            elif status == "approvedAwaitingPayment" and pay_by and now > pay_by:
                # Creator didn't pay in time — release the hold (no charge happened).
                doc.reference.update({"status": "paymentExpired", "updatedAt": firestore.SERVER_TIMESTAMP})
                changed = True
                _notify_waitlist_for_freed_slot(client, int(b.get("rank") or 0))

        # Always re-sync so the card reflects exactly what's live right now.
        _sync_live_bookings_to_featured_card(client)
        logging.info(f"[feature_slot_lifecycle] ran at {now.isoformat()} changed={changed}")
    except Exception:
        logging.exception("feature_slot_lifecycle")


def _notify_waitlist_for_freed_slot(client, rank: int) -> None:
    """Notify waitlisted creators (any-rank or matching rank) that a slot freed up."""
    if rank <= 0:
        return
    try:
        entries = client.collection("feature_slot_waitlist").where("notified", "==", False).stream()
        for doc in entries:
            e = doc.to_dict() or {}
            desired = e.get("desiredRank")
            if desired is not None and int(desired) != rank:
                continue
            client.collection("notifications").add({
                "userId": e.get("creatorId"),
                "type": "system",
                "title": "A feature slot just opened 🎉",
                "body": f"Slot #{rank} is now available. Tap to grab it before someone else does.",
                "deepLink": f"mychannel://feature-slots?rank={rank}",
                "isRead": False,
                "groupedCount": 1,
                "createdAt": firestore.SERVER_TIMESTAMP,
            })
            doc.reference.update({"notified": True})
    except Exception:
        logging.exception("_notify_waitlist_for_freed_slot")
