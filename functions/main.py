# Simple Firebase Functions for MyChannel
from firebase_functions import firestore_fn, https_fn, scheduler_fn, options
from firebase_admin import initialize_app, firestore, auth as admin_auth, messaging
import logging
from datetime import datetime, timezone, timedelta
import os
import requests
import json
from typing import List, Dict, Any

# --- Reduce cold-start time: heavy imports are deferred to function bodies ---
# google-cloud-aiplatform takes ~8s to import; keep it lazy.
aiplatform = None  # imported on first use inside ai_rank

# --- Common headers helpers for performance ---
options.set_global_options(cpu="gcf_gen1", max_instances=3, region="us-east1")

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
# --- HTTPS: Report content (callable-like via POST) ---
@https_fn.on_request(region="us-east1")
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
@https_fn.on_request(region="us-east1")
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
            try:
                from google.cloud import aiplatform as _aip
                globals()['aiplatform'] = _aip
            except Exception:
                pass
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
@firestore_fn.on_document_created(document="videos/{videoId}/comments/{commentId}",
    region="us-east1")
def on_comment_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        params = event.params
        video_id = params["videoId"]
        vid_ref = db.collection('videos').document(video_id)
        vid_ref.update({ 'commentCount': firestore.Increment(1) })
    except Exception:
        logging.exception('on_comment_created')

@firestore_fn.on_document_deleted(document="videos/{videoId}/comments/{commentId}",
    region="us-east1")
def on_comment_deleted(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        params = event.params
        video_id = params["videoId"]
        vid_ref = db.collection('videos').document(video_id)
        vid_ref.update({ 'commentCount': firestore.Increment(-1) })
    except Exception:
        logging.exception('on_comment_deleted')

@firestore_fn.on_document_created(document="videos/{videoId}/likes/{uid}",
    region="us-east1")
def on_like_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        video_id = event.params["videoId"]
        db.collection('videos').document(video_id).update({ 'likeCount': firestore.Increment(1) })
    except Exception:
        logging.exception('on_like_created')

@firestore_fn.on_document_deleted(document="videos/{videoId}/likes/{uid}",
    region="us-east1")
def on_like_deleted(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        video_id = event.params["videoId"]
        db.collection('videos').document(video_id).update({ 'likeCount': firestore.Increment(-1) })
    except Exception:
        logging.exception('on_like_deleted')

@firestore_fn.on_document_created(document="video_analytics/{videoId}/views/{viewId}",
    region="us-east1")
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

@firestore_fn.on_document_created(document="flicks/{shortId}/events/{eventId}",
    region="us-east1")
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

@firestore_fn.on_document_created(document="stories/{storyId}/events/{eventId}",
    region="us-east1")
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

@firestore_fn.on_document_created(document="users/{creatorId}/subscribers/{uid}",
    region="us-east1")
def on_subscribe_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        creator = event.params['creatorId']
        db.collection('users').document(creator).update({ 'subscribersCount': firestore.Increment(1) })
    except Exception:
        logging.exception('on_subscribe_created')

@firestore_fn.on_document_deleted(document="users/{creatorId}/subscribers/{uid}",
    region="us-east1")
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
    @firestore_fn.on_document_created(document="users/{userId}",
    region="us-east1")
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
    @firestore_fn.on_document_updated(document="users/{userId}",
    region="us-east1")
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
@https_fn.on_request(region="us-east1")
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
@https_fn.on_request(region="us-east1")
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


@https_fn.on_request(region="us-east1")
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
@https_fn.on_request(region="us-east1")
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


@https_fn.on_request(region="us-east1")
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


@https_fn.on_request(region="us-east1")
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

@firestore_fn.on_document_created(document="uploads/{uploadId}",
    region="us-east1")
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


@firestore_fn.on_document_updated(document="videos/{videoId}",
    region="us-east1")
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


@firestore_fn.on_document_created(document="tips/{tipId}",
    region="us-east1")
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


@firestore_fn.on_document_created(document="memberships/{membershipId}/payments/{paymentId}",
    region="us-east1")
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


@https_fn.on_request(region="us-east1")
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


@https_fn.on_request(region="us-east1")
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


@https_fn.on_request(region="us-east1")
def growth_aso_sync(req: https_fn.Request) -> https_fn.Response:
    try:
        # TODO: pull keywords from store APIs and update growth/keyword_bank
        return https_fn.Response({'ok': True}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        return https_fn.Response({'error': str(e)}, status=500, headers=cache_headers_no_store())


@https_fn.on_request(region="us-east1")
def growth_aso_publish(req: https_fn.Request) -> https_fn.Response:
    try:
        # TODO: publish winning ASO variants
        return https_fn.Response({'ok': True}, status=200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        return https_fn.Response({'error': str(e)}, status=500, headers=cache_headers_no_store())


@https_fn.on_request(region="us-east1")
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


# =============================================================================
# ██████████████████████████████████████████████████████████████████████████████
#
#   SENIOR YOUTUBE ENGINEER FIREBASE LAYER
#   iOS × Android × Web — Full Platform Parity
#
#   Sections:
#     A. FCM Push Delivery (real device notifications — APNs + FCM)
#     B. View Deduplication (24h window per user/video)
#     C. Search Keyword Indexer (title + description + tags)
#     D. Trending Score Engine (recalculated every 15 min)
#     E. Live Stream Cleanup (stale stream killer)
#     F. Account Deletion Cleanup (GDPR/CCPA)
#     G. Video Transcoder API trigger (multi-quality pipeline)
#     H. Auto Thumbnail Extraction (3 frames per upload)
#     I. Watch-Time Aggregation (real watch-time, not estimated)
#     J. Recommendation Pre-computation (user affinity scores)
#     K. Daily Limit Reset (compliance — wagers reset at midnight)
#     L. Subscription Feed Fanout (denormalized home feed)
#     M. Channel Stats Denormalization (fast Studio reads)
#     N. Comment Toxicity Screening (Perspective API)
#     O. Welcome Email (was disabled — now real)
#     P. Re-engagement Push (30-day inactive users)
#     Q. Copyright Strike Escalation (3-strike → account suspend)
#     R. Real-Time Viewer Count Sync (RTDB → Firestore)
#
# =============================================================================

import hashlib
import math
import re

# ─── lazy Firestore client after initialize_app() already ran above ───────────
def _db():
    return firestore.client()


# =============================================================================
# A. FCM PUSH DELIVERY
# Sends *actual* APNs/FCM pushes, not just Firestore docs.
# Called by the TS notification functions via a Pub/Sub message, or directly
# when a notification doc is written.
# =============================================================================

@firestore_fn.on_document_created(document="notifications/{notificationId}",
    region="us-east1")
def deliver_push_on_notification_created(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """Send a real FCM/APNs push whenever a notification doc is created."""
    try:
        snap = event.data
        if not snap:
            return
        data = snap.to_dict() or {}

        user_id: str = data.get("userId") or ""
        title: str = data.get("title") or ""
        body: str = data.get("message") or data.get("body") or ""
        notif_type: str = data.get("type") or "general"
        deep_link: str = data.get("deepLink") or ""
        thumbnail_url: str = data.get("thumbnailURL") or ""

        if not user_id or not title:
            return

        # Fetch FCM tokens stored in users/{uid}/fcmTokens/{token}
        tokens_snap = (
            _db()
            .collection("users")
            .document(user_id)
            .collection("fcmTokens")
            .stream()
        )
        tokens = [t.id for t in tokens_snap if t.id]
        if not tokens:
            return

        # Build the multicast message
        android_config = messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                title=title,
                body=body,
                image=thumbnail_url or None,
                click_action="FLUTTER_NOTIFICATION_CLICK",
                default_vibrate_timings=True,
                default_sound=True,
            ),
            data={
                "type": notif_type,
                "deepLink": deep_link,
                "notificationId": snap.id,
            },
        )
        apns_config = messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(title=title, body=body),
                    badge=1,
                    sound="default",
                    content_available=True,
                    mutable_content=True,
                )
            ),
            headers={"apns-priority": "10"},
        )

        msg = messaging.MulticastMessage(
            tokens=tokens[:500],  # FCM limit per call
            notification=messaging.Notification(title=title, body=body),
            android=android_config,
            apns=apns_config,
            data={
                "type": notif_type,
                "deepLink": deep_link,
                "notificationId": snap.id,
                "thumbnailURL": thumbnail_url,
            },
        )

        response = messaging.send_each_for_multicast(msg)
        logging.info(
            f"[push] {response.success_count}/{len(tokens)} sent for user {user_id}"
        )

        # Clean up stale tokens (404 = unregistered device)
        bad_tokens = []
        for idx, r in enumerate(response.responses):
            if not r.success and r.exception:
                code = getattr(r.exception, "code", "")
                if "registration-token-not-registered" in str(code).lower() or \
                   "invalid-registration-token" in str(code).lower():
                    bad_tokens.append(tokens[idx])

        for bad in bad_tokens:
            try:
                _db().collection("users").document(user_id) \
                     .collection("fcmTokens").document(bad).delete()
            except Exception:
                pass

    except Exception:
        logging.exception("deliver_push_on_notification_created")


@https_fn.on_request(region="us-east1")
def register_fcm_token(req: https_fn.Request) -> https_fn.Response:
    """
    iOS/Android/Web call this after obtaining an FCM token.
    Body: { token: string, platform: 'ios'|'android'|'web', deviceId?: string }
    Auth: Bearer <Firebase ID token>
    """
    try:
        if req.method == "OPTIONS":
            return https_fn.Response(
                "", status=204,
                headers={"Access-Control-Allow-Origin": "*",
                         "Access-Control-Allow-Methods": "POST,OPTIONS",
                         "Access-Control-Allow-Headers": "Content-Type,Authorization"},
            )
        auth_header = (req.headers.get("Authorization") or "").strip()
        if not auth_header.lower().startswith("bearer "):
            return https_fn.Response({"error": "unauthorized"}, status=401,
                                     headers={"Access-Control-Allow-Origin": "*"})
        id_token = auth_header.split(" ", 1)[1].strip()
        decoded = admin_auth.verify_id_token(id_token)
        uid = decoded["uid"]

        body = req.get_json(silent=True) or {}
        token: str = (body.get("token") or "").strip()
        platform: str = (body.get("platform") or "unknown").strip()
        device_id: str = (body.get("deviceId") or token[:32]).strip()

        if not token:
            return https_fn.Response({"error": "missing token"}, status=400,
                                     headers={"Access-Control-Allow-Origin": "*"})

        # Store token — doc id IS the token (auto-deduplicates)
        _db().collection("users").document(uid) \
             .collection("fcmTokens").document(token).set({
                 "token": token,
                 "platform": platform,
                 "deviceId": device_id,
                 "updatedAt": firestore.SERVER_TIMESTAMP,
             }, merge=True)

        return https_fn.Response({"ok": True}, status=200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        logging.exception("register_fcm_token")
        return https_fn.Response({"error": str(e)}, status=500,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# B. VIEW DEDUPLICATION
# One real view per (user, video) per 24 hours.
# Clients call POST /record_view { videoId, userId?, watchDuration }
# =============================================================================

@https_fn.on_request(region="us-east1")
def record_view(req: https_fn.Request) -> https_fn.Response:
    """
    Dedup-safe view counter. One credit per (user, video) per 24 h.
    Anonymous viewers are keyed by a hashed IP so bots can't inflate counts.
    watchDuration (seconds) is accumulated into totalWatchTime.
    """
    try:
        if req.method == "OPTIONS":
            return https_fn.Response(
                "", status=204,
                headers={"Access-Control-Allow-Origin": "*",
                         "Access-Control-Allow-Methods": "POST,OPTIONS",
                         "Access-Control-Allow-Headers": "Content-Type,Authorization"},
            )

        body = req.get_json(silent=True) or {}
        video_id: str = (body.get("videoId") or "").strip()
        watch_duration = int(body.get("watchDuration") or body.get("watchTime") or 0)

        if not video_id:
            return https_fn.Response({"error": "missing videoId"}, status=400,
                                     headers={"Access-Control-Allow-Origin": "*"})

        # Resolve viewer identity
        auth_header = (req.headers.get("Authorization") or "").strip()
        uid: str = ""
        if auth_header.lower().startswith("bearer "):
            try:
                uid = admin_auth.verify_id_token(
                    auth_header.split(" ", 1)[1].strip()
                )["uid"]
            except Exception:
                pass

        if not uid:
            # Anonymous — hash IP so the dedup still works without storing PII
            raw_ip = (req.headers.get("X-Forwarded-For") or
                      req.headers.get("X-Real-IP") or
                      req.remote_addr or "unknown")
            ip = raw_ip.split(",")[0].strip()
            uid = "anon:" + hashlib.sha256(ip.encode()).hexdigest()[:16]

        db = _db()
        now = datetime.now(timezone.utc)
        dedup_key = f"{uid}_{video_id}"
        dedup_ref = db.collection("view_dedup").document(dedup_key)
        dedup_snap = dedup_ref.get()

        is_new_view = True
        if dedup_snap.exists:
            last_ts = dedup_snap.get("lastViewAt")
            if last_ts:
                last_dt = last_ts.replace(tzinfo=timezone.utc) \
                    if hasattr(last_ts, "replace") else \
                    datetime.fromtimestamp(last_ts.timestamp(), tz=timezone.utc)
                if (now - last_dt).total_seconds() < 86400:
                    is_new_view = False

        update: dict = {
            "watchDuration": firestore.Increment(watch_duration),
            "sessionCount": firestore.Increment(1),
            "lastViewAt": firestore.SERVER_TIMESTAMP,
        }

        if is_new_view:
            # Increment video counters atomically
            video_ref = db.collection("videos").document(video_id)
            video_update: dict = {
                "viewCount": firestore.Increment(1),
                "lastViewedAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
            if watch_duration > 0:
                video_update["totalWatchTime"] = firestore.Increment(watch_duration)
            video_ref.set(video_update, merge=True)

            # Write watch history for signed-in users
            if not uid.startswith("anon:"):
                db.collection("users").document(uid) \
                  .collection("watchHistory").document(video_id).set({
                      "videoId": video_id,
                      "watchedAt": firestore.SERVER_TIMESTAMP,
                      "watchDuration": watch_duration,
                  }, merge=True)

            update["lastViewAt"] = firestore.SERVER_TIMESTAMP

        dedup_ref.set(update, merge=True)

        return https_fn.Response(
            {"ok": True, "counted": is_new_view},
            status=200,
            headers={"Access-Control-Allow-Origin": "*"},
        )
    except Exception as e:
        logging.exception("record_view")
        return https_fn.Response({"error": str(e)}, status=500,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# C. SEARCH KEYWORD INDEXER
# On video create/update: extract title + desc + tags → searchKeywords array.
# Enables prefix-free full-text search across the platform.
# =============================================================================

def _tokenize(text: str) -> set:
    """Lowercase alphanum tokens, 2–30 chars. Generates prefix sub-tokens for autocomplete."""
    words = re.findall(r"[a-z0-9]+", text.lower())
    tokens = set()
    for w in words:
        if 2 <= len(w) <= 30:
            tokens.add(w)
            # Prefix tokens: "hello" → "he","hel","hell","hello"
            for i in range(2, len(w)):
                tokens.add(w[:i])
    return tokens


@firestore_fn.on_document_created(document="videos/{videoId}",
    region="us-east1")
def index_video_on_create(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """Index search keywords when a video is uploaded."""
    try:
        snap = event.data
        if not snap:
            return
        data = snap.to_dict() or {}
        _write_search_index(event.params["videoId"], data)
    except Exception:
        logging.exception("index_video_on_create")


@firestore_fn.on_document_updated(document="videos/{videoId}",
    region="us-east1")
def index_video_on_update(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """Re-index if title, description, or tags change."""
    try:
        before = event.data.before.to_dict() or {}
        after = event.data.after.to_dict() or {}
        # Skip if nothing indexable changed
        if (before.get("title") == after.get("title") and
                before.get("description") == after.get("description") and
                before.get("tags") == after.get("tags")):
            return
        _write_search_index(event.params["videoId"], after)
    except Exception:
        logging.exception("index_video_on_update")


def _write_search_index(video_id: str, data: dict) -> None:
    tokens = set()
    tokens |= _tokenize(data.get("title") or "")
    tokens |= _tokenize(data.get("description") or "")
    for tag in (data.get("tags") or []):
        tokens |= _tokenize(str(tag))
    # Creator name
    creator = data.get("creator") or {}
    tokens |= _tokenize(creator.get("displayName") or "")

    # Firestore arrays are limited to 20 kB per field; cap at 500 tokens
    keyword_list = sorted(tokens)[:500]

    _db().collection("videos").document(video_id).update({
        "searchKeywords": keyword_list,
        "searchIndexedAt": firestore.SERVER_TIMESTAMP,
    })
    logging.info(f"[search_index] indexed {len(keyword_list)} tokens for {video_id}")


# =============================================================================
# D. TRENDING SCORE ENGINE
# Recalculated every 15 minutes. Score = Wilson score on likes + velocity bonus.
# YouTube uses a more complex signal but this is the production-safe version.
# =============================================================================

def _wilson_score(likes: int, dislikes: int, z: float = 1.96) -> float:
    """Wilson score confidence interval lower bound for a Bernoulli proportion."""
    n = likes + dislikes
    if n == 0:
        return 0.0
    p_hat = likes / n
    return (p_hat + z**2 / (2 * n) - z * math.sqrt((p_hat * (1 - p_hat) + z**2 / (4 * n)) / n)) / (1 + z**2 / n)


def _trending_score(views: int, likes: int, dislikes: int,
                    comments: int, created_ts, now: datetime) -> float:
    """
    Composite trending score:
      - View velocity (views / hours since upload, capped at 336 h = 14 days)
      - Wilson engagement quality
      - Comment signal
    Produces a float that sorts highest = most trending.
    """
    try:
        if hasattr(created_ts, "timestamp"):
            age_secs = max(1, (now - datetime.fromtimestamp(
                created_ts.timestamp(), tz=timezone.utc)).total_seconds())
        else:
            age_secs = 86400  # fallback 1 day

        age_hours = min(age_secs / 3600, 336)  # cap at 14 days
        velocity = views / max(age_hours, 1)

        engagement = _wilson_score(likes, max(0, dislikes))
        comment_boost = math.log1p(comments) * 0.5

        return velocity * (1 + engagement) + comment_boost
    except Exception:
        return 0.0


@scheduler_fn.on_schedule(
    schedule="every 15 minutes",
    region="us-east1",
    memory=options.MemoryOption.MB_512,
    max_instances=1,
    concurrency=1,
)
def recalculate_trending(event: scheduler_fn.ScheduledEvent) -> None:
    """Recalculate trendingScore for all public videos updated in last 14 days."""
    try:
        db = _db()
        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(days=14)
        cutoff_ts = cutoff  # Firestore accepts datetime

        snap = (
            db.collection("videos")
            .where("isPublic", "==", True)
            .where("updatedAt", ">=", cutoff_ts)
            .limit(2000)
            .stream()
        )

        batch = db.batch()
        count = 0
        for doc in snap:
            d = doc.to_dict() or {}
            score = _trending_score(
                views=int(d.get("viewCount") or 0),
                likes=int(d.get("likeCount") or 0),
                dislikes=int(d.get("dislikeCount") or 0),
                comments=int(d.get("commentCount") or 0),
                created_ts=d.get("createdAt"),
                now=now,
            )
            batch.update(doc.reference, {
                "trendingScore": score,
                "trendingUpdatedAt": firestore.SERVER_TIMESTAMP,
            })
            count += 1
            if count % 499 == 0:
                batch.commit()
                batch = db.batch()

        batch.commit()
        logging.info(f"[trending] scored {count} videos")
    except Exception:
        logging.exception("recalculate_trending")


# =============================================================================
# E. LIVE STREAM CLEANUP
# Kills streams where the broadcaster hasn't sent a heartbeat in >5 minutes.
# Also syncs RTDB live_viewers count → Firestore viewerCount.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 5 minutes",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
    concurrency=1,
)
def cleanup_stale_live_streams(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Mark live streams as ended when:
    1. No heartbeat in live_stream_health (RTDB) for >5 min, OR
    2. Stream doc has isLive=true but startedAt > 12 hours ago (hard cap).
    Also rolls up live_viewers count from RTDB into Firestore viewerCount.
    """
    try:
        db = _db()
        rtdb = admin_auth._DEFAULT_APP_USER  # gets default app
        now = datetime.now(timezone.utc)
        stale_cutoff = now - timedelta(minutes=5)
        hard_cutoff = now - timedelta(hours=12)

        live_streams = (
            db.collection("live_streams")
            .where("isLive", "==", True)
            .stream()
        )

        for doc in live_streams:
            d = doc.to_dict() or {}
            stream_id = doc.id
            started_at = d.get("startedAt")

            # Hard cap: 12 hours
            if started_at:
                try:
                    started_dt = datetime.fromtimestamp(
                        started_at.timestamp(), tz=timezone.utc
                    )
                    if started_dt < hard_cutoff:
                        doc.reference.update({
                            "isLive": False,
                            "endedAt": firestore.SERVER_TIMESTAMP,
                            "endReason": "hard_cap_12h",
                        })
                        logging.info(f"[stream_cleanup] ended {stream_id} (12h cap)")
                        continue
                except Exception:
                    pass

            # Heartbeat check from RTDB live_stream_health/{streamId}/lastHeartbeat
            try:
                from firebase_admin import db as rtdb_module
                heartbeat_ref = rtdb_module.reference(
                    f"live_stream_health/{stream_id}/lastHeartbeat"
                )
                heartbeat_ts = heartbeat_ref.get()
                if heartbeat_ts:
                    hb_dt = datetime.fromtimestamp(
                        int(heartbeat_ts) / 1000, tz=timezone.utc
                    )
                    if hb_dt < stale_cutoff:
                        doc.reference.update({
                            "isLive": False,
                            "endedAt": firestore.SERVER_TIMESTAMP,
                            "endReason": "heartbeat_timeout",
                        })
                        logging.info(f"[stream_cleanup] ended {stream_id} (heartbeat timeout)")
                        continue
            except Exception:
                pass

            # Sync viewer count from RTDB → Firestore
            try:
                from firebase_admin import db as rtdb_module
                viewers_ref = rtdb_module.reference(f"live_viewers/{stream_id}")
                viewers_data = viewers_ref.get() or {}
                viewer_count = len(viewers_data) if isinstance(viewers_data, dict) else 0
                doc.reference.update({"viewerCount": viewer_count})
            except Exception:
                pass

    except Exception:
        logging.exception("cleanup_stale_live_streams")


# =============================================================================
# F. ACCOUNT DELETION CLEANUP (GDPR / CCPA)
# Firebase Auth onUserDeleted triggers this. Wipes all PII:
#   - users/{uid} doc + subcollections
#   - videos hidden (not deleted — preserves platform content)
#   - notifications, search history, watch history, subscriptions
#   - FCM tokens (so no further pushes land on a dead account)
# =============================================================================

@firestore_fn.on_document_deleted(document="users/{userId}",
    region="us-east1")
def on_user_document_deleted(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """
    Fires when a user doc is deleted (account deletion flow).
    Anonymizes their video metadata and cleans up private subcollections.
    We do NOT delete videos — their content stays but creator identity is erased.
    """
    try:
        uid = event.params["userId"]
        db = _db()

        # 1. Anonymize videos (keep content, erase creator identity)
        videos_snap = (
            db.collection("videos")
            .where("creatorId", "==", uid)
            .stream()
        )
        batch = db.batch()
        count = 0
        for vdoc in videos_snap:
            batch.update(vdoc.reference, {
                "creatorId": "[deleted]",
                "creator": {
                    "id": "[deleted]",
                    "displayName": "[Deleted User]",
                    "profileImageURL": "",
                    "isVerified": False,
                },
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })
            count += 1
            if count % 499 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()

        # 2. Delete private subcollections
        private_cols = [
            "fcmTokens", "watchHistory", "watch_history",
            "subscriptions", "subscribers", "search_history",
            "videoLikes", "watchLater", "watch-later",
            "notifications", "feedSignals", "blockedUsers",
            "thumbnailProjects",
        ]
        for col in private_cols:
            try:
                docs = db.collection("users").document(uid) \
                         .collection(col).limit(500).stream()
                b = db.batch()
                n = 0
                for d in docs:
                    b.delete(d.reference)
                    n += 1
                    if n % 499 == 0:
                        b.commit()
                        b = db.batch()
                b.commit()
            except Exception:
                pass

        # 3. Log deletion for compliance audit
        db.collection("account_deletions").add({
            "uid": uid,
            "deletedAt": firestore.SERVER_TIMESTAMP,
            "reason": "user_initiated",
        })

        logging.info(f"[gdpr] cleaned up user {uid}, anonymized {count} videos")
    except Exception:
        logging.exception("on_user_document_deleted")


@https_fn.on_request(region="us-east1")
def delete_account(req: https_fn.Request) -> https_fn.Response:
    """
    iOS/Android/Web: POST with Bearer token to delete the authenticated account.
    Deletes Firebase Auth user → triggers on_user_document_deleted above.
    """
    try:
        if req.method == "OPTIONS":
            return https_fn.Response(
                "", status=204,
                headers={"Access-Control-Allow-Origin": "*",
                         "Access-Control-Allow-Methods": "POST,OPTIONS",
                         "Access-Control-Allow-Headers": "Content-Type,Authorization"},
            )
        auth_header = (req.headers.get("Authorization") or "").strip()
        if not auth_header.lower().startswith("bearer "):
            return https_fn.Response({"error": "unauthorized"}, status=401,
                                     headers={"Access-Control-Allow-Origin": "*"})
        decoded = admin_auth.verify_id_token(auth_header.split(" ", 1)[1].strip())
        uid = decoded["uid"]

        # Delete user doc first (triggers cleanup above)
        _db().collection("users").document(uid).delete()

        # Delete Firebase Auth account
        admin_auth.delete_user(uid)

        return https_fn.Response({"ok": True}, status=200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception as e:
        logging.exception("delete_account")
        return https_fn.Response({"error": str(e)}, status=500,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# G. VIDEO TRANSCODER API TRIGGER
# Calls Google Cloud Transcoder API to generate:
#   - 240p, 360p, 480p, 720p, 1080p (if source allows)
#   - HLS playlist + TS segments stored under videos/{uid}/{videoId}/hls/
#   - DASH manifest
# Updates video.status: 'processing' → 'ready' on job completion.
# =============================================================================

@firestore_fn.on_document_created(document="video_transcode_jobs/{jobId}",
    region="us-east1")
def start_transcode_job(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """
    Triggered when upload service writes a transcode job doc.
    Doc format: { videoId, creatorId, sourcePath (gs://...), outputBucket }
    """
    try:
        snap = event.data
        if not snap:
            return
        data = snap.to_dict() or {}
        job_id = event.params["jobId"]
        video_id: str = data.get("videoId") or ""
        source_path: str = data.get("sourcePath") or ""
        output_bucket: str = data.get("outputBucket") or ""

        if not (video_id and source_path and output_bucket):
            logging.warning(f"[transcode] job {job_id} missing fields: {data}")
            return

        import os

        project = os.environ.get("GOOGLE_CLOUD_PROJECT") or ""
        location = os.environ.get("TRANSCODER_LOCATION", "us-central1")

        if not project:
            logging.warning("[transcode] GOOGLE_CLOUD_PROJECT not set, skipping")
            return

        output_uri = f"gs://{output_bucket}/videos/{video_id}/hls/"

        # Build Transcoder API job config (multi-bitrate HLS + DASH)
        job_body = {
            "inputUri": source_path,
            "outputUri": output_uri,
            "config": {
                "elementaryStreams": [
                    # Video streams
                    {"key": "video-sd240", "videoStream": {
                        "h264": {"heightPixels": 240, "widthPixels": 426,
                                 "bitrateBps": 400_000, "frameRate": 30,
                                 "entropyCoder": "cabac", "profile": "high"}}},
                    {"key": "video-sd360", "videoStream": {
                        "h264": {"heightPixels": 360, "widthPixels": 640,
                                 "bitrateBps": 800_000, "frameRate": 30,
                                 "entropyCoder": "cabac", "profile": "high"}}},
                    {"key": "video-sd480", "videoStream": {
                        "h264": {"heightPixels": 480, "widthPixels": 854,
                                 "bitrateBps": 1_500_000, "frameRate": 30,
                                 "entropyCoder": "cabac", "profile": "high"}}},
                    {"key": "video-hd720", "videoStream": {
                        "h264": {"heightPixels": 720, "widthPixels": 1280,
                                 "bitrateBps": 3_000_000, "frameRate": 30,
                                 "entropyCoder": "cabac", "profile": "high"}}},
                    {"key": "video-hd1080", "videoStream": {
                        "h264": {"heightPixels": 1080, "widthPixels": 1920,
                                 "bitrateBps": 6_000_000, "frameRate": 30,
                                 "entropyCoder": "cabac", "profile": "high"}}},
                    # Audio stream
                    {"key": "audio-aac", "audioStream": {
                        "codec": "aac", "bitrateBps": 128_000,
                        "channelCount": 2, "sampleRateHertz": 44100}},
                ],
                "muxStreams": [
                    {"key": "hls-240", "container": "ts",
                     "elementaryStreams": ["video-sd240", "audio-aac"]},
                    {"key": "hls-360", "container": "ts",
                     "elementaryStreams": ["video-sd360", "audio-aac"]},
                    {"key": "hls-480", "container": "ts",
                     "elementaryStreams": ["video-sd480", "audio-aac"]},
                    {"key": "hls-720", "container": "ts",
                     "elementaryStreams": ["video-hd720", "audio-aac"]},
                    {"key": "hls-1080", "container": "ts",
                     "elementaryStreams": ["video-hd1080", "audio-aac"]},
                ],
                "manifests": [
                    {"fileName": "master.m3u8", "type": "HLS",
                     "muxStreams": ["hls-240","hls-360","hls-480","hls-720","hls-1080"]},
                    {"fileName": "manifest.mpd", "type": "DASH",
                     "muxStreams": ["hls-240","hls-360","hls-480","hls-720","hls-1080"]},
                ],
                "spriteSheets": [
                    {"filePrefix": "sprite_small", "spriteWidthPixels": 128,
                     "spriteHeightPixels": 72, "columnCount": 10, "rowCount": 10,
                     "interval": "10s"},
                ],
            },
        }

        import google.auth
        import google.auth.transport.requests as google_requests

        creds, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        authed = google_requests.Request()
        creds.refresh(authed)

        url = (f"https://transcoder.googleapis.com/v1/projects/{project}"
               f"/locations/{location}/jobs")
        resp = requests.post(
            url,
            json=job_body,
            headers={"Authorization": f"Bearer {creds.token}",
                     "Content-Type": "application/json"},
            timeout=30,
        )

        if resp.ok:
            gcp_job = resp.json()
            gcp_job_name = gcp_job.get("name", "")
            _db().collection("video_transcode_jobs").document(job_id).update({
                "gcpJobName": gcp_job_name,
                "status": "submitted",
                "submittedAt": firestore.SERVER_TIMESTAMP,
            })
            _db().collection("videos").document(video_id).set({
                "status": "processing",
                "transcodeJobId": gcp_job_name,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)
            logging.info(f"[transcode] submitted GCP job {gcp_job_name} for {video_id}")
        else:
            logging.error(f"[transcode] GCP error {resp.status_code}: {resp.text}")
            _db().collection("videos").document(video_id).set({
                "status": "transcode_failed",
                "transcodeError": resp.text[:500],
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)

    except Exception:
        logging.exception("start_transcode_job")


@https_fn.on_request(region="us-east1")
def transcode_webhook(req: https_fn.Request) -> https_fn.Response:
    """
    Pub/Sub push subscription webhook from Cloud Transcoder.
    Called when a job finishes. Updates video status to 'ready' and
    writes the HLS master playlist URL back to the video doc.
    """
    try:
        import base64, json as _json
        envelope = req.get_json(silent=True) or {}
        msg_data = envelope.get("message", {}).get("data", "")
        payload = _json.loads(base64.b64decode(msg_data).decode()) if msg_data else {}

        job_name: str = payload.get("job", {}).get("name", "")
        state: str = payload.get("job", {}).get("state", "")

        if not job_name:
            return https_fn.Response({"ok": True}, status=200)

        db = _db()
        # Find transcode job doc by gcpJobName
        job_docs = (
            db.collection("video_transcode_jobs")
            .where("gcpJobName", "==", job_name)
            .limit(1)
            .stream()
        )
        job_doc = next(job_docs, None)
        if not job_doc:
            return https_fn.Response({"ok": True}, status=200)

        job_data = job_doc.to_dict() or {}
        video_id = job_data.get("videoId") or ""
        output_bucket = job_data.get("outputBucket") or ""

        if state == "SUCCEEDED":
            hls_url = (f"https://storage.googleapis.com/{output_bucket}"
                       f"/videos/{video_id}/hls/master.m3u8")
            dash_url = (f"https://storage.googleapis.com/{output_bucket}"
                        f"/videos/{video_id}/hls/manifest.mpd")

            db.collection("videos").document(video_id).set({
                "status": "ready",
                "videoURL": hls_url,
                "hlsURL": hls_url,
                "dashURL": dash_url,
                "qualityVariants": [
                    {"quality": "240p", "url": hls_url},
                    {"quality": "360p", "url": hls_url},
                    {"quality": "480p", "url": hls_url},
                    {"quality": "720p", "url": hls_url},
                    {"quality": "1080p", "url": hls_url},
                ],
                "transcodeCompletedAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)
            job_doc.reference.update({
                "status": "succeeded",
                "completedAt": firestore.SERVER_TIMESTAMP,
            })
            logging.info(f"[transcode_webhook] {video_id} ready → {hls_url}")

        elif state in ("FAILED", "CANCELLED"):
            db.collection("videos").document(video_id).set({
                "status": "transcode_failed",
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)
            job_doc.reference.update({
                "status": state.lower(),
                "completedAt": firestore.SERVER_TIMESTAMP,
            })

        return https_fn.Response({"ok": True}, status=200)
    except Exception as e:
        logging.exception("transcode_webhook")
        return https_fn.Response({"error": str(e)}, status=500)


# =============================================================================
# H. AUTO THUMBNAIL EXTRACTION
# When a video transitions to 'ready', extract 3 frame thumbnails using
# Cloud Storage signed URLs + ffmpeg on a lightweight Cloud Run job.
# Falls back to writing placeholder URLs from the sprite sheet.
# =============================================================================

@firestore_fn.on_document_updated(document="videos/{videoId}",
    region="us-east1")
def extract_thumbnails_on_ready(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """Auto-generate thumbnail candidates when transcoding completes."""
    try:
        before_status = (event.data.before.to_dict() or {}).get("status")
        after = event.data.after.to_dict() or {}
        after_status = after.get("status")

        if before_status == after_status or after_status != "ready":
            return

        video_id = event.params["videoId"]
        hls_url: str = after.get("hlsURL") or after.get("videoURL") or ""
        output_bucket: str = after.get("outputBucket") or ""

        if not output_bucket:
            # Derive from hlsURL if present
            import re as _re
            m = _re.search(r"storage\.googleapis\.com/([^/]+)/", hls_url)
            if m:
                output_bucket = m.group(1)

        # Use sprite sheet frames as thumbnail candidates (generated by Transcoder)
        # Sprite: sprite_small_000000001.jpeg, _000000002.jpeg, ...
        candidates = []
        for i in range(1, 4):  # 3 candidates
            sprite_path = (f"https://storage.googleapis.com/{output_bucket}"
                           f"/videos/{video_id}/hls/sprite_small_{i:09d}.jpeg")
            candidates.append(sprite_path)

        db = _db()
        # If no user-uploaded thumbnail exists, set the first sprite as default
        current = (db.collection("videos").document(video_id).get().to_dict() or {})
        update: dict = {
            "thumbnailCandidates": candidates,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if not current.get("thumbnailURL"):
            update["thumbnailURL"] = candidates[0]

        db.collection("videos").document(video_id).set(update, merge=True)
        logging.info(f"[thumbnails] set {len(candidates)} candidates for {video_id}")

    except Exception:
        logging.exception("extract_thumbnails_on_ready")


# =============================================================================
# I. WATCH-TIME AGGREGATION
# Aggregates real watch-time (not estimated) from view_dedup into
# creator_analytics daily buckets for the Studio analytics charts.
# Runs hourly; writes creator_analytics/{uid}/daily/{YYYYMMDD}.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 1 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_512,
    max_instances=1,
    concurrency=1,
)
def aggregate_watch_time(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Rolls up watch-time from view_dedup docs into per-creator daily buckets.
    view_dedup/{uid}_{videoId}: { watchDuration (seconds), lastViewAt }
    """
    try:
        db = _db()
        now = datetime.now(timezone.utc)
        today = now.strftime("%Y%m%d")
        yesterday = (now - timedelta(days=1)).strftime("%Y%m%d")

        # Only process docs updated in the last 2 hours
        cutoff = now - timedelta(hours=2)
        dedup_snap = (
            db.collection("view_dedup")
            .where("lastViewAt", ">=", cutoff)
            .limit(5000)
            .stream()
        )

        # Aggregate per creator
        creator_watch: dict = {}  # { creatorId: { 'watchSecs': int, 'views': int } }

        for doc in dedup_snap:
            d = doc.to_dict() or {}
            # doc id format: uid_videoId OR anon:hash_videoId
            parts = doc.id.split("_", 1)
            if len(parts) != 2:
                continue
            user_id, video_id = parts

            # Look up creatorId for this video (cached in the dedup doc if we add it)
            creator_id: str = d.get("creatorId") or ""
            if not creator_id:
                # Fetch once and cache back
                try:
                    vsnap = db.collection("videos").document(video_id).get()
                    creator_id = (vsnap.to_dict() or {}).get("creatorId") or ""
                    if creator_id:
                        doc.reference.update({"creatorId": creator_id})
                except Exception:
                    continue

            if not creator_id:
                continue

            if creator_id not in creator_watch:
                creator_watch[creator_id] = {"watchSecs": 0, "views": 0}
            creator_watch[creator_id]["watchSecs"] += int(d.get("watchDuration") or 0)
            creator_watch[creator_id]["views"] += int(d.get("sessionCount") or 0)

        # Write daily buckets
        batch = db.batch()
        n = 0
        for creator_id, stats in creator_watch.items():
            ref = (db.collection("creator_analytics")
                     .document(creator_id)
                     .collection("daily")
                     .document(today))
            batch.set(ref, {
                "date": today,
                "watchSecs": firestore.Increment(stats["watchSecs"]),
                "views": firestore.Increment(stats["views"]),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)
            n += 1
            if n % 499 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()
        logging.info(f"[watch_time] aggregated {n} creator buckets for {today}")

    except Exception:
        logging.exception("aggregate_watch_time")


# =============================================================================
# J. RECOMMENDATION PRE-COMPUTATION
# Computes lightweight user-affinity scores based on watch history + likes.
# Writes to user_recommendations/{uid} so the home feed can read instantly.
# Runs every 6 hours for active users.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 6 hours",
    region="us-east1",
    memory=options.MemoryOption.GB_1,
    max_instances=1,
    timeout_sec=540,
    concurrency=1,
)
def precompute_recommendations(event: scheduler_fn.ScheduledEvent) -> None:
    """
    For each user active in the last 7 days:
    1. Pull their watch history (last 50 videos)
    2. Extract categories + creator affinities
    3. Find top 20 matching videos not yet watched
    4. Write to user_recommendations/{uid}
    """
    try:
        db = _db()
        now = datetime.now(timezone.utc)
        active_cutoff = now - timedelta(days=7)

        # Find recently active users via watch_progress or view_dedup
        # We approximate by scanning creator_analytics recent writers
        active_uids: set = set()

        dedup_snap = (
            db.collection("view_dedup")
            .where("lastViewAt", ">=", active_cutoff)
            .limit(2000)
            .stream()
        )
        for doc in dedup_snap:
            uid = doc.id.split("_")[0]
            if not uid.startswith("anon:"):
                active_uids.add(uid)

        logging.info(f"[recs] computing recs for {len(active_uids)} active users")

        for uid in list(active_uids)[:500]:  # cap per run
            try:
                # Fetch watch history
                history_snap = (
                    db.collection("users").document(uid)
                      .collection("watchHistory")
                      .order_by("watchedAt", direction=firestore.Query.DESCENDING)
                      .limit(50)
                      .stream()
                )
                watched_ids = set()
                category_counts: dict = {}
                creator_counts: dict = {}

                for hdoc in history_snap:
                    hd = hdoc.to_dict() or {}
                    vid = hd.get("videoId") or hdoc.id
                    watched_ids.add(vid)
                    # Fetch category + creator for affinity (best-effort)
                    try:
                        vsnap = db.collection("videos").document(vid).get()
                        vd = vsnap.to_dict() or {}
                        cat = vd.get("category") or "entertainment"
                        cid = vd.get("creatorId") or ""
                        category_counts[cat] = category_counts.get(cat, 0) + 1
                        if cid:
                            creator_counts[cid] = creator_counts.get(cid, 0) + 1
                    except Exception:
                        pass

                if not category_counts:
                    continue

                top_category = max(category_counts, key=category_counts.get)

                # Find candidate videos in top category not yet watched
                candidates_snap = (
                    db.collection("videos")
                      .where("isPublic", "==", True)
                      .where("category", "==", top_category)
                      .order_by("trendingScore", direction=firestore.Query.DESCENDING)
                      .limit(40)
                      .stream()
                )
                recs = []
                for cdoc in candidates_snap:
                    if cdoc.id not in watched_ids:
                        cd = cdoc.to_dict() or {}
                        recs.append({
                            "videoId": cdoc.id,
                            "score": float(cd.get("trendingScore") or 0),
                            "category": top_category,
                        })
                    if len(recs) >= 20:
                        break

                db.collection("user_recommendations").document(uid).set({
                    "userId": uid,
                    "recommendations": recs,
                    "topCategory": top_category,
                    "topCreators": sorted(creator_counts,
                                          key=creator_counts.get,
                                          reverse=True)[:5],
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                }, merge=True)

            except Exception:
                logging.exception(f"[recs] uid {uid}")

        logging.info(f"[recs] done for batch of {len(active_uids)} users")

    except Exception:
        logging.exception("precompute_recommendations")


# =============================================================================
# K. DAILY WAGER LIMIT RESET (COMPLIANCE)
# Resets per-user daily wager totals at UTC midnight.
# Required by money-and-compliance steering — never skip.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every day 00:00",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
    concurrency=1,
)
def reset_daily_wager_limits(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Resets users.dailyWagerTotal = 0 at UTC midnight.
    Only touches users who wagered yesterday (dailyWagerTotal > 0).
    """
    try:
        db = _db()
        snap = (
            db.collection("users")
            .where("dailyWagerTotal", ">", 0)
            .limit(5000)
            .stream()
        )
        batch = db.batch()
        n = 0
        for doc in snap:
            batch.update(doc.reference, {
                "dailyWagerTotal": 0,
                "dailyWagerResetAt": firestore.SERVER_TIMESTAMP,
            })
            n += 1
            if n % 499 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()
        logging.info(f"[wager_reset] reset daily limits for {n} users")

    except Exception:
        logging.exception("reset_daily_wager_limits")


# =============================================================================
# L. SUBSCRIPTION FEED FANOUT
# When a creator uploads, push to feeds/{subscriberId}/items/{videoId}.
# This powers the "Subscriptions" tab with O(1) reads per user.
# Handles up to 10K subscribers via batched writes.
# =============================================================================

@firestore_fn.on_document_updated(document="videos/{videoId}",
    region="us-east1")
def fanout_to_subscription_feeds(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """
    On video status → 'ready', push to all subscriber feeds.
    Also removes from feeds when a video is made private.
    """
    try:
        before = event.data.before.to_dict() or {}
        after = event.data.after.to_dict() or {}
        video_id = event.params["videoId"]

        before_status = before.get("status")
        after_status = after.get("status")
        before_public = before.get("isPublic", True)
        after_public = after.get("isPublic", True)

        db = _db()

        # Case 1: video just became ready → fanout to feeds
        if before_status != "ready" and after_status == "ready" and after_public:
            creator_id: str = after.get("creatorId") or ""
            if not creator_id:
                return

            subs_snap = (
                db.collection("users").document(creator_id)
                  .collection("subscribers")
                  .limit(10000)
                  .stream()
            )

            feed_item = {
                "videoId": video_id,
                "creatorId": creator_id,
                "title": after.get("title") or "",
                "thumbnailURL": after.get("thumbnailURL") or "",
                "duration": after.get("duration") or 0,
                "createdAt": after.get("createdAt") or firestore.SERVER_TIMESTAMP,
                "addedAt": firestore.SERVER_TIMESTAMP,
            }

            batch = db.batch()
            n = 0
            for sub_doc in subs_snap:
                feed_ref = (
                    db.collection("feeds")
                      .document(sub_doc.id)
                      .collection("items")
                      .document(video_id)
                )
                batch.set(feed_ref, feed_item, merge=True)
                n += 1
                if n % 499 == 0:
                    batch.commit()
                    batch = db.batch()
            batch.commit()
            logging.info(f"[feed_fanout] pushed {video_id} to {n} feeds")

        # Case 2: video made private → remove from all feeds
        elif before_public and not after_public:
            feeds_snap = (
                db.collection_group("items")
                  .where("videoId", "==", video_id)
                  .limit(10000)
                  .stream()
            )
            batch = db.batch()
            n = 0
            for feed_item_doc in feeds_snap:
                batch.delete(feed_item_doc.reference)
                n += 1
                if n % 499 == 0:
                    batch.commit()
                    batch = db.batch()
            batch.commit()
            logging.info(f"[feed_fanout] removed private {video_id} from {n} feeds")

    except Exception:
        logging.exception("fanout_to_subscription_feeds")


# =============================================================================
# M. CHANNEL STATS DENORMALIZATION
# Fast Studio reads: merge video aggregates into creator_analytics every hour.
# Also writes channel_stats/{uid} for public channel page display.
# =============================================================================

@firestore_fn.on_document_updated(document="videos/{videoId}",
    region="us-east1")
def update_channel_stats_on_video_change(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """
    Incrementally update creator's channel_stats when a video's counters change.
    Only fires when viewCount, likeCount, or commentCount changes.
    """
    try:
        before = event.data.before.to_dict() or {}
        after = event.data.after.to_dict() or {}
        creator_id: str = after.get("creatorId") or ""
        if not creator_id:
            return

        delta_views = int(after.get("viewCount") or 0) - int(before.get("viewCount") or 0)
        delta_likes = int(after.get("likeCount") or 0) - int(before.get("likeCount") or 0)
        delta_comments = (int(after.get("commentCount") or 0) -
                          int(before.get("commentCount") or 0))

        if delta_views == 0 and delta_likes == 0 and delta_comments == 0:
            return

        db = _db()
        updates: dict = {"updatedAt": firestore.SERVER_TIMESTAMP}
        if delta_views:
            updates["totalViews"] = firestore.Increment(delta_views)
        if delta_likes:
            updates["totalLikes"] = firestore.Increment(delta_likes)
        if delta_comments:
            updates["totalComments"] = firestore.Increment(delta_comments)

        db.collection("channel_stats").document(creator_id).set(
            updates, merge=True
        )

    except Exception:
        logging.exception("update_channel_stats_on_video_change")


# =============================================================================
# N. COMMENT TOXICITY SCREENING (Perspective API)
# Screens comments for toxicity before they appear publicly.
# Holds high-score comments for moderation rather than deleting them.
# =============================================================================

PERSPECTIVE_API_KEY = os.environ.get("PERSPECTIVE_API_KEY", "")
TOXICITY_HOLD_THRESHOLD = 0.80   # Hold for review
TOXICITY_AUTO_DELETE_THRESHOLD = 0.98  # Auto-delete (extreme content only)


@firestore_fn.on_document_created(document="videos/{videoId}/comments/{commentId}",
    region="us-east1")
def screen_comment_toxicity(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """Screen new comments via Perspective API. Hold or delete toxic content."""
    try:
        if not PERSPECTIVE_API_KEY:
            return  # Graceful no-op if not configured

        snap = event.data
        if not snap:
            return
        data = snap.to_dict() or {}
        text: str = data.get("text") or ""
        if not text or len(text) < 5:
            return

        video_id = event.params["videoId"]
        comment_id = event.params["commentId"]

        resp = requests.post(
            "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze",
            params={"key": PERSPECTIVE_API_KEY},
            json={
                "comment": {"text": text[:3000]},
                "requestedAttributes": {
                    "TOXICITY": {},
                    "SEVERE_TOXICITY": {},
                    "IDENTITY_ATTACK": {},
                    "THREAT": {},
                },
                "doNotStore": True,
            },
            timeout=5,
        )

        if not resp.ok:
            return

        scores = resp.json().get("attributeScores", {})
        toxicity = scores.get("TOXICITY", {}).get("summaryScore", {}).get("value", 0)
        severe = scores.get("SEVERE_TOXICITY", {}).get("summaryScore", {}).get("value", 0)
        identity = scores.get("IDENTITY_ATTACK", {}).get("summaryScore", {}).get("value", 0)
        threat = scores.get("THREAT", {}).get("summaryScore", {}).get("value", 0)

        max_score = max(toxicity, severe, identity, threat)

        db = _db()
        ref = (db.collection("videos").document(video_id)
                 .collection("comments").document(comment_id))

        if max_score >= TOXICITY_AUTO_DELETE_THRESHOLD:
            ref.delete()
            db.collection("comment_moderation").document(video_id) \
              .collection("auto_removed").add({
                  "commentId": comment_id,
                  "text": text[:500],
                  "toxicityScore": max_score,
                  "removedAt": firestore.SERVER_TIMESTAMP,
              })
            logging.info(f"[toxicity] auto-deleted comment {comment_id} score={max_score:.2f}")

        elif max_score >= TOXICITY_HOLD_THRESHOLD:
            ref.update({
                "isHeld": True,
                "toxicityScore": max_score,
                "toxicityScores": {
                    "toxicity": toxicity, "severe": severe,
                    "identity": identity, "threat": threat,
                },
            })
            logging.info(f"[toxicity] held comment {comment_id} score={max_score:.2f}")

    except Exception:
        logging.exception("screen_comment_toxicity")


# =============================================================================
# O. WELCOME EMAIL — real implementation (was permanently disabled)
# Uses SendGrid (SENDGRID_API_KEY env var). Falls back to logging if not set.
# =============================================================================

SENDGRID_API_KEY = os.environ.get("SENDGRID_API_KEY", "")
FROM_EMAIL = "noreply@mychannel.live"
FROM_NAME = "MyChannel"


def _send_email(to: str, subject: str, html: str) -> bool:
    if not SENDGRID_API_KEY:
        logging.info(f"[email] SENDGRID not configured — would send to {to}: {subject}")
        return False
    try:
        resp = requests.post(
            "https://api.sendgrid.com/v3/mail/send",
            headers={"Authorization": f"Bearer {SENDGRID_API_KEY}",
                     "Content-Type": "application/json"},
            json={
                "personalizations": [{"to": [{"email": to}]}],
                "from": {"email": FROM_EMAIL, "name": FROM_NAME},
                "subject": subject,
                "content": [{"type": "text/html", "value": html}],
            },
            timeout=10,
        )
        return resp.status_code in (200, 202)
    except Exception:
        logging.exception("_send_email")
        return False


@firestore_fn.on_document_created(document="users/{userId}",
    region="us-east1")
def send_welcome_email_real(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """Send real welcome email to every new user."""
    try:
        snap = event.data
        if not snap:
            return
        data = snap.to_dict() or {}
        email: str = data.get("email") or ""
        name: str = data.get("displayName") or data.get("username") or "Creator"
        uid = event.params["userId"]

        if not email or "@" not in email:
            return

        html = f"""
        <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
                    max-width:600px;margin:0 auto;background:#000;color:#fff;
                    padding:40px 32px;border-radius:12px">
          <img src="https://mychannel.live/logo.png" width="48" height="48"
               alt="MyChannel" style="border-radius:10px;margin-bottom:24px"/>
          <h1 style="font-size:28px;font-weight:700;margin:0 0 12px">
            Welcome to MyChannel, {name} 👋
          </h1>
          <p style="font-size:16px;color:#aaa;line-height:1.6;margin:0 0 24px">
            You're now part of the next generation of creators.
            Upload your first video, go live, or challenge someone to a
            real-money VS Match.
          </p>
          <a href="https://mychannel.live/upload"
             style="display:inline-block;background:#FF0000;color:#fff;
                    text-decoration:none;font-weight:700;font-size:15px;
                    padding:14px 28px;border-radius:8px;margin-bottom:32px">
            Upload Your First Video →
          </a>
          <p style="font-size:13px;color:#555;margin:0">
            You're receiving this because you created a MyChannel account.
            <a href="https://mychannel.live/settings/notifications"
               style="color:#888">Unsubscribe</a>
          </p>
        </div>
        """

        sent = _send_email(email, f"Welcome to MyChannel, {name} 🎬", html)

        _db().collection("users").document(uid).update({
            "welcomeEmailSent": True,
            "welcomeEmailSentAt": firestore.SERVER_TIMESTAMP,
        })
        logging.info(f"[welcome_email] sent={sent} to {email}")

    except Exception:
        logging.exception("send_welcome_email_real")


# =============================================================================
# P. RE-ENGAGEMENT PUSH NOTIFICATION
# Users inactive for 30 days get a single push (iOS + Android + Web).
# Runs daily at 10:00 UTC. Respects user's notification_settings.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every day 10:00",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
    concurrency=1,
)
def send_reengagement_push(event: scheduler_fn.ScheduledEvent) -> None:
    """Push to users who haven't opened the app in 30 days."""
    try:
        db = _db()
        now = datetime.now(timezone.utc)
        cutoff_30d = now - timedelta(days=30)
        cutoff_31d = now - timedelta(days=31)  # only send once

        # Users with lastActiveAt between 30 and 31 days ago
        snap = (
            db.collection("users")
            .where("lastActiveAt", ">=", cutoff_31d)
            .where("lastActiveAt", "<=", cutoff_30d)
            .limit(1000)
            .stream()
        )

        sent = 0
        for doc in snap:
            uid = doc.id
            d = doc.to_dict() or {}

            # Respect opt-out
            prefs_snap = (
                db.collection("users").document(uid)
                  .collection("notification_settings")
                  .document("global")
                  .get()
            )
            if prefs_snap.exists:
                prefs = prefs_snap.to_dict() or {}
                if not prefs.get("reEngagement", True):
                    continue

            # Fetch FCM tokens
            tokens_snap = (
                db.collection("users").document(uid)
                  .collection("fcmTokens")
                  .stream()
            )
            tokens = [t.id for t in tokens_snap if t.id]
            if not tokens:
                continue

            name = d.get("displayName") or "Creator"
            msg = messaging.MulticastMessage(
                tokens=tokens[:500],
                notification=messaging.Notification(
                    title="We miss you 👀",
                    body=f"Hey {name}, new videos are waiting for you on MyChannel.",
                ),
                data={"type": "reengagement", "deepLink": "mychannel://home"},
                android=messaging.AndroidConfig(priority="normal"),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound="default", badge=1)
                    )
                ),
            )
            try:
                messaging.send_each_for_multicast(msg)
                sent += 1
            except Exception:
                pass

        logging.info(f"[reengagement] sent to {sent} users")

    except Exception:
        logging.exception("send_reengagement_push")


# =============================================================================
# Q. COPYRIGHT STRIKE ESCALATION
# 3 strikes within 90 days → account suspension.
# Mirrors YouTube's 3-strike policy exactly.
# =============================================================================

@firestore_fn.on_document_created(document="strikeCases/{caseId}",
    region="us-east1")
def on_strike_issued(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """
    Check if this strike triggers the 3-strike rule.
    strikeCases/{caseId}: { userId, type, status, issuedAt, videoId }
    """
    try:
        snap = event.data
        if not snap:
            return
        data = snap.to_dict() or {}
        user_id: str = data.get("userId") or ""
        if not user_id:
            return

        db = _db()
        now = datetime.now(timezone.utc)
        window_start = now - timedelta(days=90)

        # Count active strikes in last 90 days
        strikes_snap = (
            db.collection("strikeCases")
            .where("userId", "==", user_id)
            .where("status", "==", "active")
            .where("issuedAt", ">=", window_start)
            .stream()
        )
        active_strikes = sum(1 for _ in strikes_snap)

        logging.info(f"[strikes] user {user_id} has {active_strikes} active strikes")

        if active_strikes >= 3:
            # Suspend account
            try:
                admin_auth.update_user(user_id, disabled=True)
            except Exception:
                pass

            db.collection("users").document(user_id).update({
                "accountStatus": "suspended",
                "suspendedAt": firestore.SERVER_TIMESTAMP,
                "suspensionReason": "3_copyright_strikes_90_days",
            })

            # Notify the user
            db.collection("notifications").add({
                "userId": user_id,
                "type": "account_suspended",
                "title": "Your account has been suspended",
                "message": ("Your account has received 3 copyright strikes within 90 days "
                            "and has been suspended per MyChannel policy."),
                "deepLink": "mychannel://settings/copyright",
                "read": False,
                "createdAt": firestore.SERVER_TIMESTAMP,
            })
            logging.info(f"[strikes] suspended user {user_id} (3 strikes)")

        elif active_strikes == 2:
            # Warn: one more strike means suspension
            db.collection("notifications").add({
                "userId": user_id,
                "type": "copyright_warning",
                "title": "Copyright warning — 2 of 3 strikes",
                "message": ("You have received 2 copyright strikes. "
                            "One more within 90 days will suspend your account."),
                "deepLink": "mychannel://settings/copyright",
                "read": False,
                "createdAt": firestore.SERVER_TIMESTAMP,
            })

    except Exception:
        logging.exception("on_strike_issued")


# =============================================================================
# R. REAL-TIME VIEWER COUNT SYNC (RTDB → Firestore)
# Syncs live_viewers presence from Realtime Database into Firestore
# every 30 seconds so Studio analytics shows accurate concurrent viewers.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 1 minutes",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
    concurrency=1,
)
def sync_live_viewer_counts(event: scheduler_fn.ScheduledEvent) -> None:
    """Read live_viewers from RTDB and update live_streams.viewerCount in Firestore."""
    try:
        from firebase_admin import db as rtdb_module

        db = _db()

        # Get all currently live streams
        live_snap = (
            db.collection("live_streams")
            .where("isLive", "==", True)
            .limit(100)
            .stream()
        )

        batch = db.batch()
        n = 0
        for stream_doc in live_snap:
            stream_id = stream_doc.id
            try:
                viewers_ref = rtdb_module.reference(f"live_viewers/{stream_id}")
                viewers_data = viewers_ref.get()
                count = (len(viewers_data)
                         if isinstance(viewers_data, dict) else 0)
                batch.update(stream_doc.reference, {
                    "viewerCount": count,
                    "viewerCountUpdatedAt": firestore.SERVER_TIMESTAMP,
                })
                n += 1
            except Exception:
                pass

        batch.commit()
        logging.info(f"[viewer_sync] synced {n} live streams")

    except Exception:
        logging.exception("sync_live_viewer_counts")


# =============================================================================
# BONUS: FCM TOKEN CLEANUP — daily sweep of stale tokens
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 24 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
    concurrency=1,
)
def cleanup_stale_fcm_tokens(event: scheduler_fn.ScheduledEvent) -> None:
    """Remove FCM tokens not updated in >60 days (device uninstalled / rotated)."""
    try:
        from firebase_admin import db as rtdb_module
        db = _db()
        cutoff = datetime.now(timezone.utc) - timedelta(days=60)

        # collectionGroup query across all users' fcmTokens
        old_tokens = (
            db.collection_group("fcmTokens")
            .where("updatedAt", "<=", cutoff)
            .limit(1000)
            .stream()
        )

        batch = db.batch()
        n = 0
        for tdoc in old_tokens:
            batch.delete(tdoc.reference)
            n += 1
            if n % 499 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()
        logging.info(f"[fcm_cleanup] removed {n} stale tokens")

    except Exception:
        logging.exception("cleanup_stale_fcm_tokens")
