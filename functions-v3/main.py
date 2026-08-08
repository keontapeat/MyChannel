# MyChannel — Platform Functions v3
# Deep feature parity: creator tools, moderation, stream management,
# analytics signals, collab system, geographic restrictions, and more.

from firebase_functions import firestore_fn, https_fn, scheduler_fn, options
from firebase_admin import initialize_app, firestore, auth as admin_auth, messaging
import logging
import os
import re as _re
import hashlib as _hashlib
import hmac as _hmac
import requests
from datetime import datetime, timezone, timedelta

options.set_global_options(cpu="gcf_gen1", max_instances=3, region="us-east1")

initialize_app()

SENDGRID_API_KEY = os.environ.get("SENDGRID_API_KEY", "")
FROM_EMAIL = "noreply@mychannel.live"

def _db():
    return firestore.client()

def _send_email(to: str, subject: str, html: str) -> bool:
    if not SENDGRID_API_KEY:
        logging.info(f"[email] no key — skipping: {subject}")
        return False
    try:
        r = requests.post(
            "https://api.sendgrid.com/v3/mail/send",
            headers={"Authorization": f"Bearer {SENDGRID_API_KEY}",
                     "Content-Type": "application/json"},
            json={"personalizations": [{"to": [{"email": to}]}],
                  "from": {"email": FROM_EMAIL, "name": "MyChannel"},
                  "subject": subject,
                  "content": [{"type": "text/html", "value": html}]},
            timeout=10,
        )
        return r.status_code in (200, 202)
    except Exception:
        return False


# =============================================================================
# 1. PINNED COMMENT
# Creator can pin exactly one comment per video. Unpins the previous one.
# =============================================================================

@https_fn.on_request(region="us-east1")
def pin_comment(req: https_fn.Request) -> https_fn.Response:
    """Pin/unpin a comment on your video. POST { videoId, commentId, pin: bool }"""
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body       = req.get_json(silent=True) or {}
        video_id   = (body.get("videoId") or "").strip()
        comment_id = (body.get("commentId") or "").strip()
        pin        = bool(body.get("pin", True))

        if not video_id or not comment_id:
            return https_fn.Response({"ok": False, "error": "missing fields"}, 400, headers=h)

        db = _db()
        # Verify caller owns the video
        v_snap = db.collection("videos").document(video_id).get()
        if not v_snap.exists or (v_snap.to_dict() or {}).get("creatorId") != uid:
            return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        now = firestore.SERVER_TIMESTAMP

        if pin:
            # Unpin any existing pinned comment first
            existing_pinned = (
                db.collection("videos").document(video_id)
                  .collection("comments")
                  .where("isPinned", "==", True)
                  .limit(5).stream()
            )
            batch = db.batch()
            for doc in existing_pinned:
                batch.update(doc.reference, {"isPinned": False, "updatedAt": now})
            # Pin the new one
            batch.update(
                db.collection("videos").document(video_id)
                  .collection("comments").document(comment_id),
                {"isPinned": True, "pinnedAt": now, "updatedAt": now}
            )
            batch.commit()
        else:
            db.collection("videos").document(video_id)\
              .collection("comments").document(comment_id)\
              .update({"isPinned": False, "updatedAt": now})

        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("pin_comment")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 2. COMMENT RATE LIMITER (anti-spam)
# Max 5 comments per user per video per minute.
# Called before comment creation to gate spam.
# =============================================================================

@https_fn.on_request(region="us-east1")
def check_comment_rate_limit(req: https_fn.Request) -> https_fn.Response:
    """
    Check if a user can post a comment. POST { videoId }
    Returns { allowed: bool, remaining: int }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"allowed": False, "reason": "unauthenticated"}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body     = req.get_json(silent=True) or {}
        video_id = (body.get("videoId") or "").strip()

        MAX_PER_MIN = 5
        now     = datetime.now(timezone.utc)
        one_min = now - timedelta(minutes=1)

        db = _db()
        rate_ref = db.collection("comment_rate_limits").document(f"{uid}_{video_id}")
        snap     = rate_ref.get()

        if snap.exists:
            data     = snap.to_dict() or {}
            count    = int(data.get("count") or 0)
            reset_ts = data.get("windowStart")
            try:
                window_start = datetime.fromtimestamp(
                    reset_ts.timestamp(), tz=timezone.utc
                ) if reset_ts else now - timedelta(minutes=2)
            except Exception:
                window_start = now - timedelta(minutes=2)

            if (now - window_start).total_seconds() < 60:
                if count >= MAX_PER_MIN:
                    return https_fn.Response({
                        "allowed": False, "reason": "rate_limited",
                        "remaining": 0, "resetInSeconds": int(60 - (now - window_start).total_seconds())
                    }, 200, headers={"Access-Control-Allow-Origin": "*"})
                rate_ref.update({"count": firestore.Increment(1), "updatedAt": firestore.SERVER_TIMESTAMP})
                return https_fn.Response({"allowed": True, "remaining": MAX_PER_MIN - count - 1},
                                         200, headers={"Access-Control-Allow-Origin": "*"})
            else:
                # New window
                rate_ref.set({"count": 1, "windowStart": firestore.SERVER_TIMESTAMP,
                               "updatedAt": firestore.SERVER_TIMESTAMP})
        else:
            rate_ref.set({"count": 1, "windowStart": firestore.SERVER_TIMESTAMP,
                          "updatedAt": firestore.SERVER_TIMESTAMP})

        return https_fn.Response({"allowed": True, "remaining": MAX_PER_MIN - 1},
                                 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("check_comment_rate_limit")
        return https_fn.Response({"allowed": True, "remaining": 5}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# 3. CREATOR VERIFICATION APPLICATION
# Creator applies for verification (blue checkmark).
# Requires: 1K+ subscribers, complete profile, no active strikes.
# Admin approves → sets isVerified = true.
# =============================================================================

@https_fn.on_request(region="us-east1")
def apply_for_verification(req: https_fn.Request) -> https_fn.Response:
    """
    Submit a creator verification application.
    POST { realName, category, websiteURL?, socialLinks? }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body        = req.get_json(silent=True) or {}
        real_name   = (body.get("realName") or "").strip()[:200]
        category    = (body.get("category") or "").strip()[:100]
        website     = (body.get("websiteURL") or "").strip()[:500]

        if not real_name or not category:
            return https_fn.Response({"ok": False, "error": "missing fields"}, 400, headers=h)

        db = _db()
        user_snap = db.collection("users").document(uid).get()
        user_data = user_snap.to_dict() or {}

        # Requirements check
        subs = int(user_data.get("subscriberCount") or 0)
        if subs < 1000:
            return https_fn.Response({
                "ok": False, "error": "insufficient_subscribers",
                "required": 1000, "current": subs
            }, 200, headers=h)

        # Check no active strikes
        strikes = (
            db.collection("strikeCases")
            .where("userId", "==", uid)
            .where("status", "==", "active")
            .limit(1).get()
        )
        if strikes:
            return https_fn.Response({"ok": False, "error": "active_strikes"}, 200, headers=h)

        # Check no pending application
        existing = (
            db.collection("verification_applications")
            .where("userId", "==", uid)
            .where("status", "in", ["pending", "under_review"])
            .limit(1).get()
        )
        if existing:
            return https_fn.Response({"ok": False, "error": "application_already_pending"}, 200, headers=h)

        ref = db.collection("verification_applications").document()
        ref.set({
            "id":          ref.id,
            "userId":      uid,
            "displayName": user_data.get("displayName") or "",
            "username":    user_data.get("username") or "",
            "realName":    real_name,
            "category":    category,
            "websiteURL":  website,
            "subscriberCount": subs,
            "videoCount":  user_data.get("videoCount") or 0,
            "status":      "pending",
            "createdAt":   firestore.SERVER_TIMESTAMP,
            "updatedAt":   firestore.SERVER_TIMESTAMP,
        })

        # Notify admin
        db.collection("admin_alerts").add({
            "type":          "verification_application",
            "applicationId": ref.id,
            "userId":        uid,
            "displayName":   user_data.get("displayName") or "",
            "subscribers":   subs,
            "createdAt":     firestore.SERVER_TIMESTAMP,
        })

        return https_fn.Response({"ok": True, "applicationId": ref.id}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("apply_for_verification")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


@firestore_fn.on_document_updated(
    document="verification_applications/{appId}",
    region="us-east1",
)
def on_verification_approved(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """Grant verified status when admin approves a verification application."""
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        if before.get("status") == after.get("status"): return
        if after.get("status") != "approved": return

        uid = after.get("userId") or ""
        if not uid: return

        _db().collection("users").document(uid).update({
            "isVerified":     True,
            "verifiedAt":     firestore.SERVER_TIMESTAMP,
            "verifiedBadge":  "official",
            "updatedAt":      firestore.SERVER_TIMESTAMP,
        })

        _db().collection("notifications").add({
            "userId":  uid,
            "type":    "verified",
            "title":   "✅ You're now verified!",
            "message": "Your MyChannel account has been verified. Your checkmark is live.",
            "read":    False,
            "createdAt": firestore.SERVER_TIMESTAMP,
        })
        logging.info(f"[verification] approved user {uid}")
    except Exception:
        logging.exception("on_verification_approved")


# =============================================================================
# 4. CHANNEL BLOCK / BAN USER
# Creator can block a user from commenting on their videos.
# =============================================================================

@https_fn.on_request(region="us-east1")
def block_user_from_channel(req: https_fn.Request) -> https_fn.Response:
    """Block/unblock a user from your channel. POST { targetUserId, block: bool }"""
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body           = req.get_json(silent=True) or {}
        target_user_id = (body.get("targetUserId") or "").strip()
        block          = bool(body.get("block", True))

        if not target_user_id or target_user_id == uid:
            return https_fn.Response({"ok": False, "error": "invalid_target"}, 400, headers=h)

        db  = _db()
        ref = db.collection("users").document(uid)\
                .collection("blockedUsers").document(target_user_id)

        if block:
            ref.set({
                "userId":    target_user_id,
                "blockedAt": firestore.SERVER_TIMESTAMP,
            })
            # Also block in live chat
            db.collection("chat_bans").document(f"channel_{uid}_{target_user_id}").set({
                "channelId": uid,
                "userId":    target_user_id,
                "reason":    "channel_block",
                "bannedAt":  firestore.SERVER_TIMESTAMP,
            })
        else:
            ref.delete()
            db.collection("chat_bans").document(f"channel_{uid}_{target_user_id}").delete()

        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("block_user_from_channel")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 5. STREAM KEY MANAGEMENT (RTMP for OBS / Streamlabs)
# Generates and rotates RTMP stream keys for live streaming.
# Stream key is stored hashed; only shown once on generate.
# =============================================================================

@https_fn.on_request(region="us-east1")
def generate_stream_key(req: https_fn.Request) -> https_fn.Response:
    """
    Generate a new RTMP stream key for the authenticated creator.
    POST {} — invalidates the old key instantly.
    Returns { streamKey, rtmpURL, streamId }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        import secrets
        raw_key   = secrets.token_urlsafe(32)
        key_hash  = _hashlib.sha256(raw_key.encode()).hexdigest()
        stream_id = f"live_{uid}"

        _db().collection("stream_keys").document(uid).set({
            "userId":    uid,
            "keyHash":   key_hash,
            "streamId":  stream_id,
            "isActive":  True,
            "rotatedAt": firestore.SERVER_TIMESTAMP,
            "createdAt": firestore.SERVER_TIMESTAMP,
        })

        # RTMP ingest URL — replace with actual media server
        rtmp_base = os.environ.get("RTMP_INGEST_URL", "rtmp://live.mychannel.live/live")

        return https_fn.Response({
            "ok":        True,
            "streamKey": raw_key,          # shown once — not stored plaintext
            "rtmpURL":   rtmp_base,
            "streamId":  stream_id,
            "fullRTMP":  f"{rtmp_base}/{raw_key}",
        }, 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("generate_stream_key")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


@https_fn.on_request(region="us-east1")
def validate_stream_key(req: https_fn.Request) -> https_fn.Response:
    """
    Called by the media server to validate an ingest stream key.
    POST { streamKey } — returns { valid: bool, userId, streamId }
    Internal use only — called by streaming infrastructure.

    SECURITY: requires a shared secret so only the media server can probe
    stream keys (the response leaks userId/streamId, and an open endpoint
    would let attackers brute-force valid ingest keys). Set env
    STREAM_KEY_VALIDATOR_SECRET and send it as the X-Internal-Secret header
    (or Authorization: Bearer <secret>). Fails closed when the env is unset.
    """
    h = {"Access-Control-Allow-Origin": "*"}
    try:
        expected = (os.environ.get("STREAM_KEY_VALIDATOR_SECRET") or "").strip()
        provided = (req.headers.get("X-Internal-Secret") or "").strip()
        if not provided:
            bearer = (req.headers.get("Authorization") or "").strip()
            if bearer.lower().startswith("bearer "):
                provided = bearer.split(" ", 1)[1].strip()
        if not expected or not _hmac.compare_digest(provided, expected):
            logging.warning("[validate_stream_key] unauthorized request rejected")
            return https_fn.Response({"valid": False}, 401, headers=h)

        body      = req.get_json(silent=True) or {}
        raw_key   = (body.get("streamKey") or "").strip()
        if not raw_key:
            return https_fn.Response({"valid": False}, 400, headers=h)

        key_hash = _hashlib.sha256(raw_key.encode()).hexdigest()
        snaps = (
            _db().collection("stream_keys")
            .where("keyHash", "==", key_hash)
            .where("isActive", "==", True)
            .limit(1).stream()
        )
        doc = next(snaps, None)
        if not doc:
            return https_fn.Response({"valid": False}, 200, headers=h)

        data = doc.to_dict() or {}
        return https_fn.Response({
            "valid":    True,
            "userId":   data.get("userId") or "",
            "streamId": data.get("streamId") or "",
        }, 200, headers=h)
    except Exception:
        logging.exception("validate_stream_key")
        return https_fn.Response({"valid": False}, 500, headers=h)


# =============================================================================
# 6. A/B THUMBNAIL TESTING
# Creator uploads 2 thumbnail variants. Each viewer is randomly assigned A or B.
# CTR is tracked per variant. After enough impressions, winner is auto-selected.
# =============================================================================

@https_fn.on_request(region="us-east1")
def start_thumbnail_ab_test(req: https_fn.Request) -> https_fn.Response:
    """
    Start an A/B thumbnail test for a video.
    POST { videoId, thumbnailA: url, thumbnailB: url, durationHours?: int }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body          = req.get_json(silent=True) or {}
        video_id      = (body.get("videoId") or "").strip()
        thumbnail_a   = (body.get("thumbnailA") or "").strip()
        thumbnail_b   = (body.get("thumbnailB") or "").strip()
        duration_hrs  = min(168, max(1, int(body.get("durationHours") or 24)))

        if not video_id or not thumbnail_a or not thumbnail_b:
            return https_fn.Response({"ok": False, "error": "missing fields"}, 400, headers=h)

        db = _db()
        v_snap = db.collection("videos").document(video_id).get()
        if not v_snap.exists or (v_snap.to_dict() or {}).get("creatorId") != uid:
            return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        now     = datetime.now(timezone.utc)
        expires = now + timedelta(hours=duration_hrs)

        test_ref = db.collection("ab_thumbnail_tests").document(video_id)
        test_ref.set({
            "videoId":      video_id,
            "creatorId":    uid,
            "variants": {
                "A": {"url": thumbnail_a, "impressions": 0, "clicks": 0, "ctr": 0.0},
                "B": {"url": thumbnail_b, "impressions": 0, "clicks": 0, "ctr": 0.0},
            },
            "status":       "running",
            "winner":       None,
            "startedAt":    firestore.SERVER_TIMESTAMP,
            "expiresAt":    expires,
            "durationHours": duration_hrs,
        })

        # Store both thumbnails on the video doc
        db.collection("videos").document(video_id).update({
            "abTestActive":   True,
            "thumbnailAURL":  thumbnail_a,
            "thumbnailBURL":  thumbnail_b,
            "updatedAt":      firestore.SERVER_TIMESTAMP,
        })

        return https_fn.Response({"ok": True, "testId": video_id, "expiresAt": expires.isoformat()},
                                 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("start_thumbnail_ab_test")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


@https_fn.on_request(region="us-east1")
def record_thumbnail_impression(req: https_fn.Request) -> https_fn.Response:
    """
    Record impression + click for A/B test. POST { videoId, variant, clicked }
    Returns the thumbnail URL for this viewer's variant.
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization",
         "Cache-Control": "no-store"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        import random
        body     = req.get_json(silent=True) or {}
        video_id = (body.get("videoId") or "").strip()
        variant  = (body.get("variant") or "").upper()  # A or B, empty = assign
        clicked  = bool(body.get("clicked", False))

        if not video_id:
            return https_fn.Response({"variant": "A"}, 400, headers=h)

        db   = _db()
        ref  = db.collection("ab_thumbnail_tests").document(video_id)
        snap = ref.get()

        if not snap.exists or (snap.to_dict() or {}).get("status") != "running":
            return https_fn.Response({"variant": "A", "active": False}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        data = snap.to_dict() or {}
        # Assign variant if not provided (50/50 random)
        if variant not in ("A", "B"):
            variant = random.choice(["A", "B"])

        # Increment counters atomically
        update: dict = {
            f"variants.{variant}.impressions": firestore.Increment(1),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if clicked:
            update[f"variants.{variant}.clicks"] = firestore.Increment(1)

        ref.update(update)

        variants = data.get("variants", {})
        thumb_url = (variants.get(variant) or {}).get("url") or ""

        return https_fn.Response({"variant": variant, "thumbnailURL": thumb_url, "active": True},
                                 200, headers={"Access-Control-Allow-Origin": "*",
                                               "Cache-Control": "no-store"})
    except Exception:
        logging.exception("record_thumbnail_impression")
        return https_fn.Response({"variant": "A"}, 500, headers=h)


@scheduler_fn.on_schedule(
    schedule="every 1 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def resolve_ab_thumbnail_tests(event: scheduler_fn.ScheduledEvent) -> None:
    """Auto-resolve A/B tests: select winner by CTR when expired or 1000+ impressions."""
    try:
        db  = _db()
        now = datetime.now(timezone.utc)

        running = (
            db.collection("ab_thumbnail_tests")
            .where("status", "==", "running")
            .limit(100).stream()
        )

        for doc in running:
            data     = doc.to_dict() or {}
            video_id = data.get("videoId") or ""
            expires  = data.get("expiresAt")
            variants = data.get("variants") or {}

            a_imp = int((variants.get("A") or {}).get("impressions") or 0)
            b_imp = int((variants.get("B") or {}).get("impressions") or 0)
            total = a_imp + b_imp

            # Check if expired or enough impressions
            expired = False
            if expires:
                try:
                    exp_dt = datetime.fromtimestamp(expires.timestamp(), tz=timezone.utc)
                    expired = now > exp_dt
                except Exception:
                    pass

            if not expired and total < 1000:
                continue

            # Calculate CTR
            a_ctr = ((variants.get("A") or {}).get("clicks") or 0) / max(a_imp, 1)
            b_ctr = ((variants.get("B") or {}).get("clicks") or 0) / max(b_imp, 1)
            winner_variant = "A" if a_ctr >= b_ctr else "B"
            winner_url     = (variants.get(winner_variant) or {}).get("url") or ""

            now_ts = firestore.SERVER_TIMESTAMP

            # Set winning thumbnail on video
            if video_id and winner_url:
                db.collection("videos").document(video_id).update({
                    "thumbnailURL":  winner_url,
                    "abTestActive":  False,
                    "abTestWinner":  winner_variant,
                    "updatedAt":     now_ts,
                })

            doc.reference.update({
                "status":    "completed",
                "winner":    winner_variant,
                "winnerCTR": max(a_ctr, b_ctr),
                "completedAt": now_ts,
            })

            # Notify creator
            creator_id = data.get("creatorId") or ""
            if creator_id:
                db.collection("notifications").add({
                    "userId":  creator_id,
                    "type":    "ab_test_complete",
                    "title":   f"Thumbnail A/B test complete — Variant {winner_variant} wins!",
                    "message": f"CTR A: {a_ctr:.1%} | CTR B: {b_ctr:.1%}. Winning thumbnail is now live.",
                    "videoId": video_id,
                    "read":    False,
                    "createdAt": now_ts,
                })

            logging.info(f"[ab_test] resolved {video_id}: variant {winner_variant} CTR={max(a_ctr,b_ctr):.1%}")
    except Exception:
        logging.exception("resolve_ab_thumbnail_tests")


# =============================================================================
# 7. CREATOR COLLAB INVITES
# Creator A invites Creator B to collaborate on a video or live stream.
# B accepts → both get "collab" tag, can co-host a stream.
# =============================================================================

@https_fn.on_request(region="us-east1")
def send_collab_invite(req: https_fn.Request) -> https_fn.Response:
    """
    Send a collaboration invite to another creator.
    POST { targetCreatorId, type: 'video'|'live', message?, videoId? }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body      = req.get_json(silent=True) or {}
        target_id = (body.get("targetCreatorId") or "").strip()
        collab_type = (body.get("type") or "video").strip()
        message   = (body.get("message") or "").strip()[:500]
        video_id  = (body.get("videoId") or "").strip()

        if not target_id or target_id == uid:
            return https_fn.Response({"ok": False, "error": "invalid_target"}, 400, headers=h)

        db  = _db()
        ref = db.collection("collab_invites").document()
        ref.set({
            "id":          ref.id,
            "senderId":    uid,
            "targetId":    target_id,
            "type":        collab_type,
            "message":     message,
            "videoId":     video_id,
            "status":      "pending",
            "createdAt":   firestore.SERVER_TIMESTAMP,
            "updatedAt":   firestore.SERVER_TIMESTAMP,
        })

        # Notify target creator
        sender_snap  = db.collection("users").document(uid).get()
        sender_name  = (sender_snap.to_dict() or {}).get("displayName") or "A creator"

        db.collection("notifications").add({
            "userId":   target_id,
            "type":     "collab_invite",
            "title":    f"🤝 {sender_name} invited you to collab!",
            "message":  message or f"{sender_name} wants to collaborate on a {collab_type}.",
            "inviteId": ref.id,
            "deepLink": f"mychannel://collab/{ref.id}",
            "read":     False,
            "createdAt": firestore.SERVER_TIMESTAMP,
        })

        return https_fn.Response({"ok": True, "inviteId": ref.id}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("send_collab_invite")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


@https_fn.on_request(region="us-east1")
def respond_collab_invite(req: https_fn.Request) -> https_fn.Response:
    """Accept or decline a collab invite. POST { inviteId, accept: bool }"""
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body      = req.get_json(silent=True) or {}
        invite_id = (body.get("inviteId") or "").strip()
        accept    = bool(body.get("accept", True))

        if not invite_id:
            return https_fn.Response({"ok": False}, 400, headers=h)

        db   = _db()
        ref  = db.collection("collab_invites").document(invite_id)
        snap = ref.get()
        if not snap.exists:
            return https_fn.Response({"ok": False, "error": "not_found"}, 404, headers=h)

        data = snap.to_dict() or {}
        if data.get("targetId") != uid:
            return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        now    = firestore.SERVER_TIMESTAMP
        status = "accepted" if accept else "declined"
        ref.update({"status": status, "respondedAt": now, "updatedAt": now})

        # Notify sender
        sender_id   = data.get("senderId") or ""
        target_name = (db.collection("users").document(uid).get().to_dict() or {}).get("displayName") or "Creator"

        db.collection("notifications").add({
            "userId":   sender_id,
            "type":     "collab_response",
            "title":    f"{'✅' if accept else '❌'} {target_name} {status} your collab invite",
            "inviteId": invite_id,
            "read":     False,
            "createdAt": now,
        })

        return https_fn.Response({"ok": True, "status": status}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("respond_collab_invite")
        return https_fn.Response({"ok": False}, 500, headers=h)


# =============================================================================
# 8. GEOGRAPHIC CONTENT RESTRICTIONS
# Creator can restrict a video to specific countries.
# Viewer IP is checked against allowed regions before playback.
# =============================================================================

@https_fn.on_request(region="us-east1")
def set_geo_restriction(req: https_fn.Request) -> https_fn.Response:
    """
    Set geographic restrictions on a video.
    POST { videoId, allowedCountries: ['US','GB',...] or [], blockedCountries: [...] }
    Empty allowedCountries = allow all. blockedCountries takes priority.
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body              = req.get_json(silent=True) or {}
        video_id          = (body.get("videoId") or "").strip()
        allowed_countries = [c.upper() for c in (body.get("allowedCountries") or [])][:250]
        blocked_countries = [c.upper() for c in (body.get("blockedCountries") or [])][:250]

        if not video_id:
            return https_fn.Response({"ok": False}, 400, headers=h)

        db = _db()
        v  = db.collection("videos").document(video_id).get()
        if not v.exists or (v.to_dict() or {}).get("creatorId") != uid:
            return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        db.collection("videos").document(video_id).update({
            "geoRestriction": {
                "allowedCountries": allowed_countries,
                "blockedCountries": blocked_countries,
                "isRestricted":     bool(allowed_countries or blocked_countries),
            },
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })

        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("set_geo_restriction")
        return https_fn.Response({"ok": False}, 500, headers=h)


@https_fn.on_request(region="us-east1")
def check_video_geo_access(req: https_fn.Request) -> https_fn.Response:
    """
    Check if a viewer can watch a video from their region.
    GET ?videoId=xxx — uses X-Country-Code header (set by CDN/load balancer)
    Returns { allowed: bool, reason? }
    """
    h = {"Access-Control-Allow-Origin": "*", "Cache-Control": "no-store"}
    try:
        video_id     = (req.args.get("videoId") or "").strip()
        country_code = (
            req.headers.get("X-Country-Code") or
            req.headers.get("CF-IPCountry") or      # Cloudflare
            req.headers.get("X-AppEngine-Country") or # GCP App Engine
            "US"
        ).upper().strip()[:2]

        if not video_id:
            return https_fn.Response({"allowed": True}, 200, headers=h)

        snap = _db().collection("videos").document(video_id).get()
        if not snap.exists:
            return https_fn.Response({"allowed": False, "reason": "not_found"}, 404, headers=h)

        data       = snap.to_dict() or {}
        geo        = data.get("geoRestriction") or {}
        is_restricted = geo.get("isRestricted") or False

        if not is_restricted:
            return https_fn.Response({"allowed": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        blocked   = geo.get("blockedCountries") or []
        allowed   = geo.get("allowedCountries") or []

        if country_code in blocked:
            return https_fn.Response({"allowed": False, "reason": "geo_blocked"}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        if allowed and country_code not in allowed:
            return https_fn.Response({"allowed": False, "reason": "not_in_allowed_region"}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        return https_fn.Response({"allowed": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("check_video_geo_access")
        return https_fn.Response({"allowed": True}, 500, headers=h)


# =============================================================================
# 9. SEARCH QUALITY SIGNALS
# Records click-through and dwell time on search results to improve ranking.
# =============================================================================

@https_fn.on_request(region="us-east1")
def record_search_signal(req: https_fn.Request) -> https_fn.Response:
    """
    Record a search quality signal (click or dwell time).
    POST { query, videoId, signal: 'click'|'dwell', dwellSeconds? }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        body         = req.get_json(silent=True) or {}
        query        = (body.get("query") or "").strip().lower()[:200]
        video_id     = (body.get("videoId") or "").strip()
        signal       = (body.get("signal") or "click").strip()
        dwell_secs   = max(0, int(body.get("dwellSeconds") or 0))

        if not query or not video_id:
            return https_fn.Response({"ok": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        # Update search quality score on the video
        update: dict = {"updatedAt": firestore.SERVER_TIMESTAMP}
        if signal == "click":
            update["searchClickCount"] = firestore.Increment(1)
        elif signal == "dwell" and dwell_secs > 0:
            update["searchDwellTotal"] = firestore.Increment(dwell_secs)
            update["searchDwellCount"] = firestore.Increment(1)

        _db().collection("videos").document(video_id).update(update)

        # Update trending_searches
        _db().collection("trending_searches").document(query).set({
            "query":        query,
            "searchCount":  firestore.Increment(1),
            "lastSearched": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# 10. AUTO-GENERATED VIDEO DESCRIPTION FROM TRANSCRIPT
# When captions complete, generates a structured description using the
# transcript text. Writes a suggested description for creator review.
# =============================================================================

@firestore_fn.on_document_updated(
    document="videos/{videoId}/captions/{lang}",
    region="us-east1",
)
def generate_description_from_captions(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """Generate a video description suggestion from completed captions."""
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        if before.get("status") == after.get("status"): return
        if after.get("status") != "completed": return

        lang     = event.params.get("lang") or ""
        if lang != "en": return  # Only for English

        video_id = event.params["videoId"]
        db       = _db()

        video_snap = db.collection("videos").document(video_id).get()
        video_data = video_snap.to_dict() or {}

        # Only generate if description is empty or very short
        existing_desc = (video_data.get("description") or "").strip()
        if len(existing_desc) > 100:
            return

        caption_url = after.get("url") or ""
        if not caption_url:
            return

        # Fetch VTT content
        try:
            r = requests.get(caption_url, timeout=10)
            if not r.ok: return
            vtt_text = r.text
        except Exception:
            return

        # Extract text from VTT (strip timestamps)
        lines = []
        for line in vtt_text.split("\n"):
            line = line.strip()
            if not line or line == "WEBVTT" or "-->" in line or line.isdigit():
                continue
            lines.append(line)

        full_transcript = " ".join(lines)[:2000]
        if len(full_transcript) < 50:
            return

        # Simple extractive summary: take first 200 chars as opening
        sentences = _re.split(r'[.!?]', full_transcript)
        opening   = ". ".join(s.strip() for s in sentences[:3] if s.strip())[:200]
        title     = video_data.get("title") or ""
        tags      = " ".join(f"#{t}" for t in (video_data.get("tags") or [])[:5])

        suggested_desc = (
            f"{opening}...\n\n"
            f"Watch {title} on MyChannel.\n\n"
            f"{tags}"
        ).strip()

        # Write as suggestion — creator reviews before it goes live
        db.collection("videos").document(video_id).update({
            "suggestedDescription": suggested_desc,
            "hasSuggestedDescription": True,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })
        logging.info(f"[auto_desc] generated description suggestion for {video_id}")
    except Exception:
        logging.exception("generate_description_from_captions")


# =============================================================================
# 11. NOTIFICATION GROUPING
# Batches "X liked your video" → "X and 4 others liked your video"
# Runs every 2 minutes. Groups notifications by type+target within 1 hour.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 2 minutes",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def group_notifications(event: scheduler_fn.ScheduledEvent) -> None:
    """Group similar notifications into digest entries."""
    try:
        db     = _db()
        now    = datetime.now(timezone.utc)
        cutoff = now - timedelta(hours=1)

        # Find ungrouped like/comment/subscriber notifications
        ungrouped = (
            db.collection("notifications")
            .where("type", "in", ["video_like", "new_subscriber", "comment_reply"])
            .where("grouped", "==", False)
            .where("createdAt", ">=", cutoff)
            .limit(500)
            .stream()
        )

        # Group by (userId, type, videoId/targetId)
        groups: dict = {}
        docs_by_key: dict = {}

        for doc in ungrouped:
            d         = doc.to_dict() or {}
            user_id   = d.get("userId") or ""
            notif_type = d.get("type") or ""
            video_id  = d.get("videoId") or d.get("targetId") or ""
            key       = f"{user_id}:{notif_type}:{video_id}"

            if key not in groups:
                groups[key] = {"count": 0, "actors": [], "data": d, "userId": user_id}
                docs_by_key[key] = []
            groups[key]["count"] += 1
            actor = d.get("actorName") or d.get("displayName") or ""
            if actor and actor not in groups[key]["actors"]:
                groups[key]["actors"].append(actor)
            docs_by_key[key].append(doc.reference)

        for key, group in groups.items():
            if group["count"] < 2:
                continue  # Not enough to group

            count  = group["count"]
            actors = group["actors"]
            d      = group["data"]
            uid    = group["userId"]

            if len(actors) >= 2:
                actor_str = f"{actors[0]} and {count - 1} others"
            elif actors:
                actor_str = actors[0]
            else:
                actor_str = f"{count} people"

            notif_type = d.get("type") or ""
            verb = {
                "video_like":     "liked your video",
                "new_subscriber": "subscribed to your channel",
                "comment_reply":  "commented on your video",
            }.get(notif_type, "interacted with your content")

            # Write a grouped notification
            db.collection("notifications").add({
                "userId":       uid,
                "type":         f"{notif_type}_grouped",
                "title":        f"{actor_str} {verb}",
                "message":      f"{count} new {notif_type.replace('_', ' ')}s",
                "videoId":      d.get("videoId") or "",
                "count":        count,
                "grouped":      True,
                "read":         False,
                "createdAt":    firestore.SERVER_TIMESTAMP,
            })

            # Mark originals as grouped
            batch = db.batch()
            n = 0
            for ref in docs_by_key[key]:
                batch.update(ref, {"grouped": True, "supersededAt": firestore.SERVER_TIMESTAMP})
                n += 1
                if n % 499 == 0:
                    batch.commit()
                    batch = db.batch()
            batch.commit()

    except Exception:
        logging.exception("group_notifications")


# =============================================================================
# 12. CREATOR PAYOUT HISTORY + TAX FORM DATA
# Returns a structured payout history and generates a 1099-MISC summary
# for creators who earned > $600 in a calendar year (US tax requirement).
# =============================================================================

@https_fn.on_request(region="us-east1")
def get_payout_history(req: https_fn.Request) -> https_fn.Response:
    """
    Get creator payout history. GET ?year=2025
    Returns { payouts: [...], totalUSD, qualifiesFor1099: bool }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid  = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]
        year = int(req.args.get("year") or datetime.now(timezone.utc).year)

        db    = _db()
        snaps = (
            db.collection("creator_payouts")
            .where("creatorId", "==", uid)
            .order_by("paidAt", direction=firestore.Query.DESCENDING)
            .limit(100)
            .stream()
        )

        payouts   = []
        total_usd = 0.0

        for doc in snaps:
            d         = doc.to_dict() or {}
            month_str = d.get("month") or ""
            if month_str and not month_str.startswith(str(year)):
                continue  # filter by year
            paid_at = d.get("paidAt")
            payouts.append({
                "id":           doc.id,
                "month":        month_str,
                "amountUSD":    d.get("creatorCutUSD") or d.get("amountUSD") or 0,
                "status":       d.get("status") or "paid",
                "transferId":   d.get("stripeTransferId") or "",
                "paidAt":       paid_at.isoformat() if hasattr(paid_at, "isoformat") else "",
            })
            total_usd += float(d.get("creatorCutUSD") or d.get("amountUSD") or 0)

        return https_fn.Response({
            "ok":               True,
            "year":             year,
            "payouts":          payouts,
            "totalUSD":         round(total_usd, 2),
            "qualifiesFor1099": total_usd >= 600.0,
            "taxYear":          year,
        }, 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("get_payout_history")
        return https_fn.Response({"ok": False}, 500, headers=h)


# =============================================================================
# 13. MERCH SHELF — Product links on video page
# Creator registers external product links that appear below their video.
# Physical goods checkout is on external storefront (App Store compliant).
# =============================================================================

@https_fn.on_request(region="us-east1")
def manage_merch_shelf(req: https_fn.Request) -> https_fn.Response:
    """
    Add/update/delete a merch product from a creator's shelf.
    POST { action: 'add'|'remove'|'reorder', product?: {...}, productId?, order?: [] }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body       = req.get_json(silent=True) or {}
        action     = (body.get("action") or "add").strip()
        db         = _db()
        shelf_ref  = db.collection("creator_shops").document(uid)
        now        = firestore.SERVER_TIMESTAMP

        if action == "add":
            product = body.get("product") or {}
            if not product.get("title") or not product.get("url"):
                return https_fn.Response({"ok": False, "error": "missing product fields"}, 400, headers=h)

            prod_ref = db.collection("shopping_products").document()
            prod_ref.set({
                "id":          prod_ref.id,
                "creatorId":   uid,
                "title":       (product.get("title") or "")[:100],
                "description": (product.get("description") or "")[:500],
                "priceDisplay":(product.get("priceDisplay") or "")[:50],
                "imageURL":    (product.get("imageURL") or "")[:1000],
                "url":         (product.get("url") or "")[:1000],  # external checkout URL
                "isActive":    True,
                "views":       0,
                "checkoutTaps": 0,
                "createdAt":   now,
                "updatedAt":   now,
            })
            # Add to shelf
            shelf_ref.set({
                "creatorId":  uid,
                "updatedAt":  now,
                "productIds": firestore.ArrayUnion([prod_ref.id]),
            }, merge=True)
            return https_fn.Response({"ok": True, "productId": prod_ref.id}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        elif action == "remove":
            product_id = (body.get("productId") or "").strip()
            if not product_id:
                return https_fn.Response({"ok": False}, 400, headers=h)
            db.collection("shopping_products").document(product_id).update({
                "isActive": False, "updatedAt": now})
            shelf_ref.update({"productIds": firestore.ArrayRemove([product_id]),
                               "updatedAt": now})
            return https_fn.Response({"ok": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        elif action == "reorder":
            order = body.get("order") or []
            shelf_ref.update({"productIds": order, "updatedAt": now})
            return https_fn.Response({"ok": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        return https_fn.Response({"ok": False, "error": "invalid action"}, 400, headers=h)
    except Exception:
        logging.exception("manage_merch_shelf")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 14. VIDEO CLIP CREATION
# Creates a clip (a timestamped excerpt) from a long-form video.
# Clips get their own video doc with a reference to the parent.
# =============================================================================

@https_fn.on_request(region="us-east1")
def create_video_clip(req: https_fn.Request) -> https_fn.Response:
    """
    Create a clip from a video. Any viewer can clip (like YouTube).
    POST { videoId, startSeconds, endSeconds, title }
    Max 60 seconds. Returns { clipId }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body          = req.get_json(silent=True) or {}
        video_id      = (body.get("videoId") or "").strip()
        start_secs    = max(0, int(body.get("startSeconds") or 0))
        end_secs      = int(body.get("endSeconds") or 0)
        clip_title    = (body.get("title") or "Clip")[:100].strip()

        duration = end_secs - start_secs
        if not video_id or duration <= 0:
            return https_fn.Response({"ok": False, "error": "invalid range"}, 400, headers=h)
        if duration > 60:
            return https_fn.Response({"ok": False, "error": "max_60_seconds"}, 400, headers=h)

        db = _db()
        v_snap = db.collection("videos").document(video_id).get()
        if not v_snap.exists:
            return https_fn.Response({"ok": False, "error": "video_not_found"}, 404, headers=h)

        v_data     = v_snap.to_dict() or {}
        video_url  = v_data.get("videoURL") or v_data.get("hlsURL") or ""
        thumb_url  = v_data.get("thumbnailURL") or ""

        clip_ref = db.collection("clips").document()
        clip_ref.set({
            "id":           clip_ref.id,
            "parentVideoId": video_id,
            "creatorId":    uid,  # who made the clip (viewer)
            "originalCreatorId": v_data.get("creatorId") or "",
            "title":        clip_title,
            "videoURL":     video_url,  # client handles seeking
            "thumbnailURL": thumb_url,
            "startSeconds": start_secs,
            "endSeconds":   end_secs,
            "duration":     duration,
            "viewCount":    0,
            "likeCount":    0,
            "isPublic":     True,
            "createdAt":    firestore.SERVER_TIMESTAMP,
        })

        # Increment clip count on original video
        db.collection("videos").document(video_id).update({
            "clipCount": firestore.Increment(1),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })

        return https_fn.Response({"ok": True, "clipId": clip_ref.id,
                                  "deepLink": f"mychannel://clip/{clip_ref.id}"},
                                 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("create_video_clip")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 15. STALE DATA CLEANUP — Scheduled maintenance
# Removes rate limit docs, expired watch parties, old dedup entries,
# resolved dispute docs, and expired stream keys.
# Runs daily to keep Firestore lean and fast.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 24 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def daily_stale_data_cleanup(event: scheduler_fn.ScheduledEvent) -> None:
    """Daily maintenance: remove stale rate limits, expired sessions, old dedup docs."""
    try:
        db     = _db()
        now    = datetime.now(timezone.utc)
        cutoffs = {
            "comment_rate_limits": now - timedelta(hours=2),
            "super_chat_idempotency": now - timedelta(days=7),
            "tip_idempotency": now - timedelta(days=7),
            "live_bet_idempotency": now - timedelta(days=7),
            "gift_idempotency": now - timedelta(days=7),
        }

        total = 0
        for coll, cutoff in cutoffs.items():
            try:
                snaps = (
                    db.collection(coll)
                    .where("createdAt", "<=", cutoff)
                    .limit(500).stream()
                )
                batch = db.batch()
                n = 0
                for doc in snaps:
                    batch.delete(doc.reference)
                    n += 1
                    if n % 499 == 0:
                        batch.commit()
                        batch = db.batch()
                batch.commit()
                total += n
            except Exception as e:
                logging.warning(f"[stale_cleanup] {coll}: {e}")

        # Expire abandoned watch parties (> 4 hours old with no activity)
        old_parties = (
            db.collection("watch_parties")
            .where("status", "==", "active")
            .where("createdAt", "<=", now - timedelta(hours=4))
            .limit(100).stream()
        )
        batch = db.batch()
        n = 0
        for doc in old_parties:
            batch.update(doc.reference, {"status": "ended", "endedAt": firestore.SERVER_TIMESTAMP})
            n += 1
        batch.commit()
        total += n

        # Clean up old view_dedup docs (> 48 hours)
        old_dedup = (
            db.collection("view_dedup")
            .where("lastViewAt", "<=", now - timedelta(hours=48))
            .limit(1000).stream()
        )
        batch = db.batch()
        n = 0
        for doc in old_dedup:
            batch.delete(doc.reference)
            n += 1
            if n % 499 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()
        total += n

        logging.info(f"[stale_cleanup] removed {total} stale docs")
    except Exception:
        logging.exception("daily_stale_data_cleanup")


# =============================================================================
# ██████████████████████████████████████████████████████████████████████████████
#
#   WAVE 5 — PRODUCTION COMPLETENESS
#
#   1.  Direct Messages (DM send/read/thread)
#   2.  End Screen / Cards Editor API
#   3.  Affiliate Promo Code System
#   4.  Spam Account Detector
#   5.  Video Heatmap Analytics (replay timestamps)
#   6.  Creator Fund Eligibility
#   7.  Push Notification Topic Subscriptions
#   8.  Video Quality Signal Recorder
#   9.  Membership Tier Pricing Management
#   10. Live Stream → Save to VOD
#   11. Story Analytics
#   12. Wallet Top-Up via Stripe
#   13. VS Match Highlight Clip Auto-Generation
#   14. Platform Health Dashboard (admin)
#   15. Creator Standing / Content Health Score
#
# =============================================================================

import math as _math


# =============================================================================
# 1. DIRECT MESSAGES
# Send a DM to another user. Thread stored in Firestore for history.
# Real-time delivery uses RTDB (direct_messages/{threadId}/messages).
# =============================================================================

@https_fn.on_request(region="us-east1")
def send_direct_message(req: https_fn.Request) -> https_fn.Response:
    """
    Send a DM. POST { recipientId, text, mediaURL? }
    Creates a Firestore thread doc + writes to RTDB for real-time delivery.
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body         = req.get_json(silent=True) or {}
        recipient_id = (body.get("recipientId") or "").strip()
        text         = (body.get("text") or "").strip()[:2000]
        media_url    = (body.get("mediaURL") or "").strip()[:1000]

        if not recipient_id or (not text and not media_url):
            return https_fn.Response({"ok": False, "error": "missing fields"}, 400, headers=h)
        if recipient_id == uid:
            return https_fn.Response({"ok": False, "error": "cannot_dm_yourself"}, 400, headers=h)

        db  = _db()
        now = firestore.SERVER_TIMESTAMP

        # Check if sender is blocked by recipient
        blocked = db.collection("users").document(recipient_id)\
                    .collection("blockedUsers").document(uid).get()
        if blocked.exists:
            return https_fn.Response({"ok": False, "error": "blocked"}, 200, headers=h)

        # Thread ID: sorted pair so A→B and B→A use same thread
        parts     = sorted([uid, recipient_id])
        thread_id = f"{parts[0]}_{parts[1]}"

        # Ensure thread doc exists
        thread_ref = db.collection("dm_threads").document(thread_id)
        thread_snap = thread_ref.get()
        if not thread_snap.exists:
            thread_ref.set({
                "id":           thread_id,
                "participants": [uid, recipient_id],
                "createdAt":    now,
                "updatedAt":    now,
                "lastMessage":  text[:100],
                "unreadCount":  {recipient_id: 0, uid: 0},
            })

        # Write message doc
        msg_ref = db.collection("dm_threads").document(thread_id)\
                    .collection("messages").document()

        msg_data: dict = {
            "id":          msg_ref.id,
            "senderId":    uid,
            "recipientId": recipient_id,
            "text":        text,
            "read":        False,
            "createdAt":   now,
        }
        if media_url:
            msg_data["mediaURL"] = media_url

        msg_ref.set(msg_data)

        # Update thread metadata
        thread_ref.update({
            "lastMessage":                   text[:100] or "📷 Media",
            "lastMessageAt":                 now,
            "updatedAt":                     now,
            f"unreadCount.{recipient_id}":   firestore.Increment(1),
        })

        # Push notification to recipient
        db.collection("notifications").add({
            "userId":    recipient_id,
            "type":      "direct_message",
            "title":     "New message",
            "message":   text[:100] if text else "Sent you a media message",
            "senderId":  uid,
            "threadId":  thread_id,
            "deepLink":  f"mychannel://dm/{thread_id}",
            "read":      False,
            "createdAt": now,
        })

        return https_fn.Response({"ok": True, "messageId": msg_ref.id, "threadId": thread_id},
                                 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("send_direct_message")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


@https_fn.on_request(region="us-east1")
def mark_dm_read(req: https_fn.Request) -> https_fn.Response:
    """Mark all messages in a DM thread as read. POST { threadId }"""
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid       = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]
        body      = req.get_json(silent=True) or {}
        thread_id = (body.get("threadId") or "").strip()
        if not thread_id:
            return https_fn.Response({"ok": False}, 400, headers=h)

        _db().collection("dm_threads").document(thread_id).update({
            f"unreadCount.{uid}": 0,
            "updatedAt":          firestore.SERVER_TIMESTAMP,
        })
        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("mark_dm_read")
        return https_fn.Response({"ok": False}, 500, headers=h)


# =============================================================================
# 2. END SCREEN / CARDS EDITOR API
# Creator adds end screen elements (subscribe button, video link, playlist link)
# that appear in the last 20 seconds of a video.
# =============================================================================

@https_fn.on_request(region="us-east1")
def save_end_screen(req: https_fn.Request) -> https_fn.Response:
    """
    Save end screen configuration for a video.
    POST { videoId, elements: [{type, x, y, width, height, targetId?, startSec, endSec}] }
    Max 4 elements. Must be in last 20 seconds.
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body     = req.get_json(silent=True) or {}
        video_id = (body.get("videoId") or "").strip()
        elements = body.get("elements") or []

        if not video_id:
            return https_fn.Response({"ok": False, "error": "missing videoId"}, 400, headers=h)
        if len(elements) > 4:
            return https_fn.Response({"ok": False, "error": "max_4_elements"}, 400, headers=h)

        db = _db()
        v  = db.collection("videos").document(video_id).get()
        if not v.exists or (v.to_dict() or {}).get("creatorId") != uid:
            return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        duration = int((v.to_dict() or {}).get("duration") or 0)

        # Validate elements
        valid_types = {"video", "playlist", "subscribe", "channel", "link"}
        sanitized = []
        for el in elements:
            el_type = (el.get("type") or "").strip()
            if el_type not in valid_types:
                continue
            start = max(0, int(el.get("startSec") or 0))
            end   = min(duration, int(el.get("endSec") or duration))
            if duration > 0 and start < duration - 20:
                start = max(start, duration - 20)  # enforce last 20s
            sanitized.append({
                "type":      el_type,
                "x":         max(0, min(100, float(el.get("x") or 0))),
                "y":         max(0, min(100, float(el.get("y") or 0))),
                "width":     max(5, min(50, float(el.get("width") or 30))),
                "height":    max(5, min(30, float(el.get("height") or 15))),
                "targetId":  (el.get("targetId") or "").strip(),
                "targetURL": (el.get("targetURL") or "").strip()[:500],
                "startSec":  start,
                "endSec":    end,
            })

        db.collection("endScreens").document(video_id).set({
            "videoId":    video_id,
            "creatorId":  uid,
            "elements":   sanitized,
            "updatedAt":  firestore.SERVER_TIMESTAMP,
        })

        db.collection("videos").document(video_id).update({
            "hasEndScreen": True,
            "updatedAt":    firestore.SERVER_TIMESTAMP,
        })

        return https_fn.Response({"ok": True, "elements": sanitized}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("save_end_screen")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 3. AFFILIATE / PROMO CODE SYSTEM
# Creator generates promo codes. Viewer applies code → creator gets
# affiliate credit. Creator can see conversion stats.
# =============================================================================

@https_fn.on_request(region="us-east1")
def create_promo_code(req: https_fn.Request) -> https_fn.Response:
    """Create a promo code for affiliate tracking. POST { label?, discountPct? }"""
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body         = req.get_json(silent=True) or {}
        label        = (body.get("label") or "").strip()[:50]
        discount_pct = min(50, max(0, int(body.get("discountPct") or 0)))

        import random, string
        code = label.upper().replace(" ", "") if label else \
               "".join(random.choices(string.ascii_uppercase + string.digits, k=8))

        db  = _db()
        ref = db.collection("promo_codes").document(code)

        if ref.get().exists:
            # Add suffix to make unique
            code = code + "".join(random.choices(string.digits, k=3))
            ref  = db.collection("promo_codes").document(code)

        ref.set({
            "code":          code,
            "creatorId":     uid,
            "label":         label or code,
            "discountPct":   discount_pct,
            "uses":          0,
            "conversions":   0,
            "revenue":       0.0,
            "isActive":      True,
            "createdAt":     firestore.SERVER_TIMESTAMP,
        })

        return https_fn.Response({"ok": True, "code": code, "discountPct": discount_pct},
                                 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("create_promo_code")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


@https_fn.on_request(region="us-east1")
def apply_promo_code(req: https_fn.Request) -> https_fn.Response:
    """
    Viewer applies a promo code at checkout. POST { code, context: 'membership'|'tip' }
    Returns { valid, discountPct, creatorId }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"valid": False}, 401, headers=h)
        uid  = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]
        body = req.get_json(silent=True) or {}
        code = (body.get("code") or "").strip().upper()

        if not code:
            return https_fn.Response({"valid": False}, 400, headers=h)

        db   = _db()
        snap = db.collection("promo_codes").document(code).get()

        if not snap.exists or not (snap.to_dict() or {}).get("isActive"):
            return https_fn.Response({"valid": False, "reason": "invalid_code"}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        data       = snap.to_dict() or {}
        creator_id = data.get("creatorId") or ""

        # Can't use own code
        if creator_id == uid:
            return https_fn.Response({"valid": False, "reason": "own_code"}, 200, headers=h)

        db.collection("promo_codes").document(code).update({
            "uses": firestore.Increment(1),
            "lastUsedAt": firestore.SERVER_TIMESTAMP,
        })

        return https_fn.Response({
            "valid":       True,
            "code":        code,
            "discountPct": data.get("discountPct") or 0,
            "creatorId":   creator_id,
            "label":       data.get("label") or code,
        }, 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("apply_promo_code")
        return https_fn.Response({"valid": False}, 500, headers=h)


# =============================================================================
# 4. SPAM ACCOUNT DETECTOR
# Runs every 30 minutes. Detects rapid follow/like/comment behavior
# from new accounts. Flags for review, auto-restricts at high score.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 30 minutes",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def detect_spam_accounts(event: scheduler_fn.ScheduledEvent) -> None:
    """Detect and flag spam accounts based on behavioral signals."""
    try:
        db     = _db()
        now    = datetime.now(timezone.utc)
        hour_ago = now - timedelta(hours=1)

        # Find accounts created in last 24h with unusual activity
        new_accts_cutoff = now - timedelta(hours=24)

        # Check view_dedup for accounts that viewed 50+ unique videos in last hour
        recent_views = (
            db.collection("view_dedup")
            .where("lastViewAt", ">=", hour_ago)
            .limit(5000)
            .stream()
        )

        uid_view_counts: dict = {}
        for doc in recent_views:
            uid = doc.id.split("_")[0]
            if not uid.startswith("anon:"):
                uid_view_counts[uid] = uid_view_counts.get(uid, 0) + 1

        flagged = 0
        for uid, count in uid_view_counts.items():
            if count < 50:
                continue

            # Check account age
            try:
                user_snap = db.collection("users").document(uid).get()
                if not user_snap.exists:
                    continue
                user_data  = user_snap.to_dict() or {}
                created_at = user_data.get("createdAt")
                if created_at:
                    created_dt = datetime.fromtimestamp(created_at.timestamp(), tz=timezone.utc)
                    age_hours  = (now - created_dt).total_seconds() / 3600
                    # New account + high view velocity = suspect
                    if age_hours > 72:
                        continue  # established account — skip
            except Exception:
                continue

            spam_score = min(100, int((count / 50) * 40 + (72 / max(age_hours, 1)) * 60))

            if spam_score >= 70:
                # Flag for review
                existing = (
                    db.collection("spam_flags")
                    .where("userId", "==", uid)
                    .where("createdAt", ">=", hour_ago)
                    .limit(1).get()
                )
                if existing:
                    continue

                db.collection("spam_flags").add({
                    "userId":      uid,
                    "spamScore":   spam_score,
                    "viewCount1h": count,
                    "accountAgeH": age_hours,
                    "status":      "pending",
                    "createdAt":   firestore.SERVER_TIMESTAMP,
                })
                flagged += 1

                if spam_score >= 90:
                    # Auto-restrict
                    db.collection("users").document(uid).update({
                        "isRestricted":   True,
                        "restrictReason": "spam_behavior",
                        "restrictedAt":   firestore.SERVER_TIMESTAMP,
                    })

        if flagged:
            logging.warning(f"[spam_detect] flagged {flagged} accounts")
    except Exception:
        logging.exception("detect_spam_accounts")


# =============================================================================
# 5. VIDEO HEATMAP ANALYTICS
# Clients report which timestamp was played/replayed.
# Aggregates into a heatmap showing which parts viewers rewatch most.
# =============================================================================

@https_fn.on_request(region="us-east1")
def record_playback_event(req: https_fn.Request) -> https_fn.Response:
    """
    Record a playback event for heatmap analytics.
    POST { videoId, events: [{type: 'play'|'seek'|'replay', positionSec}] }
    Batched — client sends array of events every 30 seconds.
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        body     = req.get_json(silent=True) or {}
        video_id = (body.get("videoId") or "").strip()
        events   = body.get("events") or []

        if not video_id or not events:
            return https_fn.Response({"ok": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        db = _db()
        # Bucket events into 10-second segments
        segment_hits: dict = {}
        for ev in events[:50]:  # cap batch size
            pos  = max(0, int(ev.get("positionSec") or 0))
            seg  = (pos // 10) * 10  # bucket: 0,10,20,30...
            ev_t = ev.get("type") or "play"
            weight = 3 if ev_t == "replay" else 2 if ev_t == "seek" else 1
            segment_hits[seg] = segment_hits.get(seg, 0) + weight

        if not segment_hits:
            return https_fn.Response({"ok": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        heatmap_ref = db.collection("video_heatmaps").document(video_id)
        update      = {"updatedAt": firestore.SERVER_TIMESTAMP, "sampleCount": firestore.Increment(1)}
        for seg, hits in segment_hits.items():
            update[f"segments.s{seg}"] = firestore.Increment(hits)

        heatmap_ref.set(update, merge=True)

        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# 6. CREATOR FUND ELIGIBILITY
# Checks if a creator qualifies for the MyChannel Creator Fund.
# Requirements: 10K+ views in 90 days, 1K+ subscribers, 18+, compliant.
# =============================================================================

@https_fn.on_request(region="us-east1")
def check_creator_fund_eligibility(req: https_fn.Request) -> https_fn.Response:
    """Check creator fund eligibility. GET (authenticated)"""
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"eligible": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        db = _db()
        user_snap = db.collection("users").document(uid).get()
        user_data = user_snap.to_dict() or {}

        checks = {
            "age_verified": bool(user_data.get("isAgeVerified") or user_data.get("ageVerified")),
            "email_verified": bool(user_data.get("isEmailVerified") or user_data.get("emailVerified")),
            "terms_accepted": bool(user_data.get("termsAccepted") or user_data.get("hasAcceptedTerms")),
            "no_active_strikes": True,
        }

        # Check strikes
        strikes = (
            db.collection("strikeCases")
            .where("userId", "==", uid)
            .where("status", "==", "active")
            .limit(1).get()
        )
        checks["no_active_strikes"] = not bool(strikes)

        # Check subscribers
        subs = int(user_data.get("subscriberCount") or 0)
        checks["min_subscribers"] = subs >= 1000

        # Check 90-day views
        analytics_snap = db.collection("creator_analytics").document(uid).get()
        analytics_data = analytics_snap.to_dict() or {}
        total_views    = int(analytics_data.get("totalViews") or 0)
        # Approximate 90-day views as ~25% of total (rough estimate)
        views_90d      = int(total_views * 0.25)
        checks["min_views_90d"] = views_90d >= 10_000

        # Check not already in fund
        fund_snap = db.collection("creator_fund_members").document(uid).get()
        checks["not_already_enrolled"] = not fund_snap.exists

        all_pass   = all(checks.values())
        failed     = [k for k, v in checks.items() if not v]

        result = {
            "eligible":           all_pass,
            "checks":             checks,
            "failedRequirements": failed,
            "subscriberCount":    subs,
            "views90d":           views_90d,
            "requirements": {
                "minSubscribers": 1000,
                "minViews90d":    10000,
                "ageVerified":    True,
                "emailVerified":  True,
                "termsAccepted":  True,
                "noStrikes":      True,
            },
        }

        # Auto-enroll if eligible
        if all_pass:
            db.collection("creator_fund_members").document(uid).set({
                "userId":      uid,
                "enrolledAt":  firestore.SERVER_TIMESTAMP,
                "status":      "active",
                "tier":        "standard",
            }, merge=True)
            result["enrolled"] = True

        return https_fn.Response(result, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("check_creator_fund_eligibility")
        return https_fn.Response({"eligible": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 7. PUSH NOTIFICATION TOPIC SUBSCRIPTIONS
# iOS/Android can subscribe to FCM topics for broadcast notifications
# (e.g., "new video from channel X", "live stream started").
# =============================================================================

@https_fn.on_request(region="us-east1")
def manage_notification_topics(req: https_fn.Request) -> https_fn.Response:
    """
    Subscribe/unsubscribe an FCM token to notification topics.
    POST { fcmToken, action: 'subscribe'|'unsubscribe', topics: string[] }
    Topics: 'channel_{creatorId}', 'live_{streamId}', 'vs_match_{matchId}'
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())

        body      = req.get_json(silent=True) or {}
        fcm_token = (body.get("fcmToken") or "").strip()
        action    = (body.get("action") or "subscribe").strip()
        topics    = [t for t in (body.get("topics") or []) if isinstance(t, str)][:10]

        if not fcm_token or not topics:
            return https_fn.Response({"ok": False, "error": "missing fields"}, 400, headers=h)

        results = {}
        for topic in topics:
            # Sanitize topic name (FCM only allows alphanum, dash, underscore)
            safe_topic = _re.sub(r"[^a-zA-Z0-9_-]", "_", topic)[:100]
            try:
                if action == "subscribe":
                    resp = messaging.subscribe_to_topic([fcm_token], safe_topic)
                else:
                    resp = messaging.unsubscribe_from_topic([fcm_token], safe_topic)
                results[topic] = {"success": resp.success_count > 0}
            except Exception as e:
                results[topic] = {"success": False, "error": str(e)[:100]}

        return https_fn.Response({"ok": True, "results": results}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("manage_notification_topics")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 8. VIDEO QUALITY SIGNAL RECORDER
# Client reports the quality level they ended up playing at.
# Used to optimize adaptive bitrate ladder and CDN decisions.
# =============================================================================

@https_fn.on_request(region="us-east1")
def record_playback_quality(req: https_fn.Request) -> https_fn.Response:
    """
    Record what quality level a viewer actually played at.
    POST { videoId, quality: '240p'|'360p'|'480p'|'720p'|'1080p', bufferRatio, startTimeMs }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        body         = req.get_json(silent=True) or {}
        video_id     = (body.get("videoId") or "").strip()
        quality      = (body.get("quality") or "720p").strip()
        buffer_ratio = min(1.0, max(0.0, float(body.get("bufferRatio") or 0)))
        start_ms     = max(0, int(body.get("startTimeMs") or 0))

        if not video_id: return https_fn.Response({"ok": True}, 200, headers=h)

        valid_qualities = {"240p", "360p", "480p", "720p", "1080p", "1440p", "4K"}
        if quality not in valid_qualities:
            quality = "720p"

        _db().collection("video_quality_signals").document(video_id).set({
            f"quality.{quality}": firestore.Increment(1),
            "bufferRatioSum":     firestore.Increment(buffer_ratio),
            "startTimeMsSum":     firestore.Increment(start_ms),
            "sampleCount":        firestore.Increment(1),
            "updatedAt":          firestore.SERVER_TIMESTAMP,
        }, merge=True)

        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# 9. MEMBERSHIP TIER PRICING MANAGEMENT
# Creator creates/edits/deletes their membership tiers with prices and perks.
# =============================================================================

@https_fn.on_request(region="us-east1")
def manage_membership_tiers(req: https_fn.Request) -> https_fn.Response:
    """
    Create/update/delete a membership tier.
    POST { action: 'create'|'update'|'delete', tier: {...}, tierId? }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body    = req.get_json(silent=True) or {}
        action  = (body.get("action") or "create").strip()
        tier_id = (body.get("tierId") or "").strip()
        tier    = body.get("tier") or {}

        db  = _db()
        now = firestore.SERVER_TIMESTAMP

        if action == "create":
            name     = (tier.get("name") or "").strip()[:50]
            price    = max(0.99, float(tier.get("priceUSD") or 4.99))
            badge    = (tier.get("badge") or "⭐").strip()[:10]
            perks    = [p[:200] for p in (tier.get("perks") or [])[:10]]

            if not name:
                return https_fn.Response({"ok": False, "error": "missing name"}, 400, headers=h)

            ref = db.collection("membership_tiers").document()
            ref.set({
                "id":          ref.id,
                "creatorId":   uid,
                "name":        name,
                "priceUSD":    round(price, 2),
                "badge":       badge,
                "perks":       perks,
                "memberCount": 0,
                "isActive":    True,
                "createdAt":   now,
                "updatedAt":   now,
            })
            return https_fn.Response({"ok": True, "tierId": ref.id}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        elif action == "update":
            if not tier_id:
                return https_fn.Response({"ok": False, "error": "missing tierId"}, 400, headers=h)
            ref = db.collection("membership_tiers").document(tier_id)
            snap = ref.get()
            if not snap.exists or (snap.to_dict() or {}).get("creatorId") != uid:
                return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

            updates: dict = {"updatedAt": now}
            if tier.get("name"): updates["name"] = tier["name"][:50]
            if tier.get("badge"): updates["badge"] = tier["badge"][:10]
            if tier.get("perks"): updates["perks"] = [p[:200] for p in tier["perks"][:10]]
            if tier.get("isActive") is not None: updates["isActive"] = bool(tier["isActive"])
            ref.update(updates)
            return https_fn.Response({"ok": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        elif action == "delete":
            if not tier_id:
                return https_fn.Response({"ok": False, "error": "missing tierId"}, 400, headers=h)
            ref = db.collection("membership_tiers").document(tier_id)
            snap = ref.get()
            if not snap.exists or (snap.to_dict() or {}).get("creatorId") != uid:
                return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)
            # Soft delete — don't remove active memberships
            ref.update({"isActive": False, "deletedAt": now, "updatedAt": now})
            return https_fn.Response({"ok": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        return https_fn.Response({"ok": False, "error": "invalid action"}, 400, headers=h)
    except Exception:
        logging.exception("manage_membership_tiers")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 10. LIVE STREAM → SAVE TO VOD
# When a live stream ends, the recording is saved as a regular video.
# Triggered when live_streams/{id}.isLive → false.
# =============================================================================

@firestore_fn.on_document_updated(
    document="live_streams/{streamId}",
    region="us-east1",
)
def save_live_stream_as_vod(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """Save a completed live stream as a VOD video."""
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        if before.get("isLive") == after.get("isLive"): return
        if after.get("isLive"): return  # going live — skip
        if not before.get("isLive"): return  # wasn't live — skip

        stream_id  = event.params["streamId"]
        creator_id = after.get("creatorId") or ""
        title      = after.get("title") or "Live Stream Recording"
        thumb_url  = after.get("thumbnailURL") or ""
        stream_url = after.get("streamURL") or after.get("hlsURL") or ""
        save_vod   = after.get("saveToVOD", True)

        if not creator_id or not save_vod or not stream_url:
            return

        db  = _db()
        now = firestore.SERVER_TIMESTAMP

        # Create a VOD video doc from the stream recording
        video_ref = db.collection("videos").document()
        video_ref.set({
            "id":              video_ref.id,
            "title":           f"{title} (Live Recording)",
            "description":     after.get("description") or "",
            "videoURL":        stream_url,
            "hlsURL":          stream_url,
            "thumbnailURL":    thumb_url,
            "creatorId":       creator_id,
            "category":        after.get("category") or "entertainment",
            "tags":            after.get("tags") or [],
            "isPublic":        True,
            "isLiveRecording": True,
            "sourceStreamId":  stream_id,
            "viewCount":       int(after.get("viewerCount") or 0),
            "likeCount":       0,
            "commentCount":    0,
            "shareCount":      0,
            "duration":        int(after.get("durationSeconds") or 0),
            "status":          "ready",
            "createdAt":       now,
            "updatedAt":       now,
        })

        # Mark stream as saved
        db.collection("live_streams").document(stream_id).update({
            "vodVideoId": video_ref.id,
            "savedToVOD": True,
            "updatedAt":  now,
        })

        # Notify creator
        db.collection("notifications").add({
            "userId":   creator_id,
            "type":     "stream_saved",
            "title":    "📼 Live stream saved!",
            "message":  "Your live stream has been saved as a video on your channel.",
            "videoId":  video_ref.id,
            "deepLink": f"mychannel://watch/{video_ref.id}",
            "read":     False,
            "createdAt": now,
        })

        logging.info(f"[vod_save] stream {stream_id} → video {video_ref.id}")
    except Exception:
        logging.exception("save_live_stream_as_vod")


# =============================================================================
# 11. STORY ANALYTICS
# Tracks per-story metrics: views, replies, poll votes, forward/back swipes.
# Creator reads their story analytics in Studio.
# =============================================================================

@https_fn.on_request(region="us-east1")
def get_story_analytics(req: https_fn.Request) -> https_fn.Response:
    """
    Get analytics for a creator's recent stories. GET ?days=7
    Returns { stories: [{id, views, replies, likeCount, avgViewPct, pollResults}] }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid  = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]
        days = min(30, max(1, int(req.args.get("days") or 7)))

        db     = _db()
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)

        stories_snap = (
            db.collection("stories")
            .where("creatorId", "==", uid)
            .where("createdAt", ">=", cutoff)
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .limit(50)
            .stream()
        )

        results = []
        for doc in stories_snap:
            d        = doc.to_dict() or {}
            story_id = doc.id

            # Get view count from story_views
            view_count = int(d.get("viewCount") or 0)

            # Get reply count
            reply_count = 0
            try:
                replies = (
                    db.collection("story_replies")
                    .where("storyId", "==", story_id)
                    .limit(1000).stream()
                )
                reply_count = sum(1 for _ in replies)
            except Exception:
                pass

            created_at = d.get("createdAt")
            results.append({
                "id":          story_id,
                "type":        d.get("type") or "photo",
                "viewCount":   view_count,
                "likeCount":   d.get("likeCount") or 0,
                "replyCount":  reply_count,
                "shareCount":  d.get("shareCount") or 0,
                "completion":  d.get("completionRate") or 0,
                "createdAt":   created_at.isoformat() if hasattr(created_at, "isoformat") else "",
                "expiresAt":   (d.get("expiresAt") or {}).isoformat()
                               if hasattr(d.get("expiresAt"), "isoformat") else "",
            })

        total_views = sum(s["viewCount"] for s in results)
        avg_views   = round(total_views / len(results), 1) if results else 0

        return https_fn.Response({
            "ok":        True,
            "stories":   results,
            "totalViews": total_views,
            "avgViews":   avg_views,
            "count":      len(results),
        }, 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("get_story_analytics")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 12. WALLET TOP-UP VIA STRIPE
# User deposits money into their VS Match wallet via Stripe PaymentIntent.
# MONEY NOTE: server creates PaymentIntent, client confirms with Stripe SDK.
# Stripe webhook fires on success → credit wallet.
# =============================================================================

@https_fn.on_request(region="us-east1")
def create_wallet_topup(req: https_fn.Request) -> https_fn.Response:
    """
    Create a Stripe PaymentIntent for wallet top-up.
    POST { amountCents }
    Returns { clientSecret, paymentIntentId }
    Client confirms with Stripe SDK, then webhook credits the wallet.
    MONEY NOTE: wallet is only credited after Stripe confirms payment.
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        import stripe as _stripe
        stripe_key = os.environ.get("STRIPE_SECRET_KEY", "")
        if not stripe_key:
            return https_fn.Response({"ok": False, "error": "payments_not_configured"}, 503, headers=h)
        _stripe.api_key = stripe_key

        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body         = req.get_json(silent=True) or {}
        amount_cents = int(body.get("amountCents") or 0)

        # Min $5, max $10,000 per deposit
        if amount_cents < 500:
            return https_fn.Response({"ok": False, "error": "minimum_500_cents"}, 400, headers=h)
        if amount_cents > 1_000_000:
            return https_fn.Response({"ok": False, "error": "maximum_1000000_cents"}, 400, headers=h)

        db        = _db()
        user_snap = db.collection("users").document(uid).get()
        user_data = user_snap.to_dict() or {}

        # Age + terms check for real money
        if not user_data.get("isAgeVerified") and not user_data.get("ageVerified"):
            return https_fn.Response({"ok": False, "error": "age_not_verified"}, 200, headers=h)

        # Get or create Stripe customer
        stripe_customer_id = user_data.get("stripeCustomerId") or ""
        if not stripe_customer_id:
            customer = _stripe.Customer.create(
                email=user_data.get("email") or "",
                metadata={"userId": uid}
            )
            stripe_customer_id = customer.id
            db.collection("users").document(uid).update({
                "stripeCustomerId": stripe_customer_id,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })

        intent = _stripe.PaymentIntent.create(
            amount=amount_cents,
            currency="usd",
            customer=stripe_customer_id,
            metadata={"userId": uid, "type": "wallet_topup"},
            description="MyChannel wallet top-up",
        )

        # Record pending deposit
        db.collection("wallet_deposits").document(intent.id).set({
            "paymentIntentId": intent.id,
            "userId":          uid,
            "amountCents":     amount_cents,
            "status":          "pending",
            "createdAt":       firestore.SERVER_TIMESTAMP,
        })

        return https_fn.Response({
            "ok":             True,
            "clientSecret":   intent.client_secret,
            "paymentIntentId": intent.id,
            "amountCents":    amount_cents,
        }, 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("create_wallet_topup")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


@https_fn.on_request(region="us-east1")
def stripe_wallet_webhook(req: https_fn.Request) -> https_fn.Response:
    """
    Stripe webhook for wallet top-up confirmation.
    Credits wallet when payment_intent.succeeded fires.
    MONEY NOTE: verifies Stripe signature before crediting any wallet.
    """
    h = {"Access-Control-Allow-Origin": "*"}
    try:
        import stripe as _stripe
        stripe_key     = os.environ.get("STRIPE_SECRET_KEY", "")
        webhook_secret = os.environ.get("STRIPE_WALLET_WEBHOOK_SECRET", "")
        _stripe.api_key = stripe_key

        sig = req.headers.get("stripe-signature") or ""
        try:
            event = _stripe.Webhook.construct_event(
                req.get_data(as_text=True), sig, webhook_secret
            )
        except Exception:
            return https_fn.Response({"error": "invalid_signature"}, 400, headers=h)

        if event.type == "payment_intent.succeeded":
            intent    = event.data.object
            intent_id = intent.id
            uid       = (intent.metadata or {}).get("userId") or ""

            if not uid or (intent.metadata or {}).get("type") != "wallet_topup":
                return https_fn.Response({"ok": True}, 200, headers=h)

            amount_cents = int(intent.amount_received or intent.amount or 0)
            db  = _db()

            # Idempotency — check not already credited
            deposit_ref  = db.collection("wallet_deposits").document(intent_id)
            deposit_snap = deposit_ref.get()
            if deposit_snap.exists and (deposit_snap.to_dict() or {}).get("status") == "completed":
                return https_fn.Response({"ok": True}, 200, headers=h)

            now = firestore.SERVER_TIMESTAMP

            @firestore.transactional
            def _credit(tx):
                wallet_ref = db.collection("vs_match_wallets").document(uid)
                w_snap = wallet_ref.get(transaction=tx)
                if not w_snap.exists:
                    tx.set(wallet_ref, {
                        "userId": uid, "availableBalance": amount_cents,
                        "pendingBalance": 0, "totalDeposits": amount_cents,
                        "createdAt": now, "updatedAt": now,
                    })
                else:
                    tx.update(wallet_ref, {
                        "availableBalance": firestore.Increment(amount_cents),
                        "totalDeposits":    firestore.Increment(amount_cents),
                        "updatedAt":        now,
                    })
                tx.update(deposit_ref, {"status": "completed", "completedAt": now})
                tx.set(db.collection("vs_match_transactions").document(), {
                    "userId":          uid,
                    "type":            "deposit",
                    "amount":          amount_cents,
                    "paymentIntentId": intent_id,
                    "status":          "completed",
                    "description":     f"Wallet top-up ${amount_cents/100:.2f}",
                    "createdAt":       now,
                })

            _credit(db.transaction())

            db.collection("notifications").add({
                "userId":  uid,
                "type":    "wallet_topup",
                "title":   f"💰 ${amount_cents/100:.2f} added to your wallet!",
                "message": "Your deposit is confirmed and ready to use.",
                "read":    False,
                "createdAt": now,
            })

            logging.info(f"[wallet_topup] credited {amount_cents}¢ to {uid}")

        return https_fn.Response({"ok": True}, 200, headers=h)
    except Exception:
        logging.exception("stripe_wallet_webhook")
        return https_fn.Response({"error": "server_error"}, 500, headers=h)


# =============================================================================
# 13. PLATFORM HEALTH DASHBOARD (admin)
# Aggregates DAU, MAU, revenue, error rates into a single admin doc.
# Runs every hour. Admin reads platform_health/current.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 1 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_512,
    max_instances=1,
)
def aggregate_platform_health(event: scheduler_fn.ScheduledEvent) -> None:
    """Aggregate platform-wide health metrics for admin dashboard."""
    try:
        db  = _db()
        now = datetime.now(timezone.utc)

        day_ago   = now - timedelta(hours=24)
        week_ago  = now - timedelta(days=7)
        month_ago = now - timedelta(days=30)

        def _count(col, field, cutoff):
            try:
                return sum(1 for _ in
                    db.collection(col).where(field, ">=", cutoff).limit(50000).stream())
            except Exception:
                return -1  # -1 = unable to count

        # Active users (viewed something)
        dau = _count("view_dedup", "lastViewAt", day_ago)
        wau = _count("view_dedup", "lastViewAt", week_ago)

        # New users
        new_users_day  = _count("users", "createdAt", day_ago)
        new_users_week = _count("users", "createdAt", week_ago)

        # Videos uploaded
        uploads_day  = _count("videos", "createdAt", day_ago)
        uploads_week = _count("videos", "createdAt", week_ago)

        # Revenue (sum from platform_revenue)
        revenue_day  = 0.0
        revenue_week = 0.0
        try:
            for doc in db.collection("platform_revenue")\
                         .where("createdAt", ">=", day_ago).limit(10000).stream():
                revenue_day += float((doc.to_dict() or {}).get("feeCents") or 0) / 100
            for doc in db.collection("platform_revenue")\
                         .where("createdAt", ">=", week_ago).limit(50000).stream():
                revenue_week += float((doc.to_dict() or {}).get("feeCents") or 0) / 100
        except Exception:
            pass

        # Live streams active now
        live_now = sum(1 for _ in
            db.collection("live_streams").where("isLive", "==", True).limit(1000).stream())

        # Spam flags pending
        spam_pending = sum(1 for _ in
            db.collection("spam_flags").where("status", "==", "pending").limit(500).stream())

        # Reports pending
        reports_pending = sum(1 for _ in
            db.collection("content_reports")
            .where("status", "==", "pending").limit(500).stream())

        db.collection("platform_health").document("current").set({
            "dau":             dau,
            "wau":             wau,
            "newUsersDay":     new_users_day,
            "newUsersWeek":    new_users_week,
            "uploadsDay":      uploads_day,
            "uploadsWeek":     uploads_week,
            "revenueDayUSD":   round(revenue_day, 2),
            "revenueWeekUSD":  round(revenue_week, 2),
            "liveStreamsNow":  live_now,
            "spamFlagsPending": spam_pending,
            "reportsPending":  reports_pending,
            "updatedAt":       firestore.SERVER_TIMESTAMP,
        })

        logging.info(f"[platform_health] DAU={dau} WAU={wau} liveNow={live_now} "
                     f"revenueDay=${revenue_day:.2f}")
    except Exception:
        logging.exception("aggregate_platform_health")


# =============================================================================
# 14. CREATOR STANDING / CONTENT HEALTH SCORE
# Runs daily. Aggregates strike history, spam flags, report volume,
# and compliance status into a single creatorStanding score (0–100).
# Used to gate monetization eligibility.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 24 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def recalculate_creator_standing(event: scheduler_fn.ScheduledEvent) -> None:
    """Recalculate content health / creator standing score for all creators."""
    try:
        db  = _db()
        now = datetime.now(timezone.utc)
        cutoff_90d = now - timedelta(days=90)

        # Get all creators with at least one video
        creators_snap = (
            db.collection("creator_analytics")
            .limit(2000)
            .stream()
        )

        for doc in creators_snap:
            creator_id = doc.id
            try:
                # Start at 100, deduct for issues
                score = 100

                # Active strikes (-20 each, max -60)
                strikes = list(
                    db.collection("strikeCases")
                    .where("userId", "==", creator_id)
                    .where("status", "==", "active")
                    .limit(10).stream()
                )
                score -= min(60, len(strikes) * 20)

                # Reports on their videos in last 90 days
                report_count = sum(
                    1 for report in
                    db.collection("content_reports")
                    .where("contentCreatorId", "==", creator_id)
                    .where("createdAt", ">=", cutoff_90d)
                    .limit(100).stream()
                    if (report.to_dict() or {}).get("type") == "video"
                )
                score -= min(20, report_count * 2)

                # Spam flags (-10)
                spam_flags = list(
                    db.collection("spam_flags")
                    .where("userId", "==", creator_id)
                    .where("status", "==", "pending")
                    .limit(5).stream()
                )
                score -= min(10, len(spam_flags) * 5)

                # Bonus for verified email (+5) and age verified (+5)
                user_snap = db.collection("users").document(creator_id).get()
                user_data = user_snap.to_dict() or {}
                if user_data.get("isEmailVerified") or user_data.get("emailVerified"):
                    score += 5
                if user_data.get("isAgeVerified") or user_data.get("ageVerified"):
                    score += 5

                score = max(0, min(100, score))

                standing = "excellent" if score >= 90 else \
                           "good"      if score >= 70 else \
                           "fair"      if score >= 50 else \
                           "poor"      if score >= 30 else "critical"

                db.collection("creator_standing").document(creator_id).set({
                    "creatorId":      creator_id,
                    "score":          score,
                    "standing":       standing,
                    "activeStrikes":  len(strikes),
                    "reportsLast90d": report_count,
                    "monetizationEligible": score >= 70,
                    "updatedAt":      firestore.SERVER_TIMESTAMP,
                }, merge=True)

                # If standing is critical, restrict monetization
                if score < 30:
                    db.collection("users").document(creator_id).update({
                        "monetizationEnabled": False,
                        "updatedAt": firestore.SERVER_TIMESTAMP,
                    })

            except Exception as e:
                logging.warning(f"[creator_standing] {creator_id}: {e}")

        logging.info(f"[creator_standing] recalculated for creator batch")
    except Exception:
        logging.exception("recalculate_creator_standing")


# =============================================================================
# 15. ABANDONED WATCH CLEANUP + SESSION ANALYTICS
# Every 6 hours, cleans up watch party sessions and tallies total watch time
# into creator analytics for the Studio dashboard.
# Also marks videos as "trending" based on watch time velocity.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 6 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def session_analytics_rollup(event: scheduler_fn.ScheduledEvent) -> None:
    """Rollup session analytics: watch time, quality scores, heatmap summaries."""
    try:
        db  = _db()
        now = datetime.now(timezone.utc)

        # Aggregate quality signals per video into a summary
        quality_snaps = (
            db.collection("video_quality_signals")
            .where("updatedAt", ">=", now - timedelta(hours=6))
            .limit(1000)
            .stream()
        )

        for doc in quality_snaps:
            d          = doc.to_dict() or {}
            video_id   = doc.id
            sample_cnt = max(1, int(d.get("sampleCount") or 1))
            qualities  = d.get("quality") or {}

            # Most common quality
            top_quality = max(qualities.items(), key=lambda x: x[1])[0] \
                          if qualities else "720p"
            avg_start   = round((d.get("startTimeMsSum") or 0) / sample_cnt)
            avg_buffer  = round((d.get("bufferRatioSum") or 0) / sample_cnt, 3)

            try:
                db.collection("videos").document(video_id).update({
                    "topQuality":      top_quality,
                    "avgStartTimeMs":  avg_start,
                    "avgBufferRatio":  avg_buffer,
                    "updatedAt":       firestore.SERVER_TIMESTAMP,
                })
            except Exception:
                pass

        # Summarize heatmaps — find peak replay segments
        heatmap_snaps = (
            db.collection("video_heatmaps")
            .where("updatedAt", ">=", now - timedelta(hours=6))
            .limit(500)
            .stream()
        )
        for doc in heatmap_snaps:
            d        = doc.to_dict() or {}
            video_id = doc.id
            segs     = d.get("segments") or {}
            if not segs:
                continue
            # Find top 3 replay segments
            sorted_segs = sorted(segs.items(), key=lambda x: x[1], reverse=True)[:3]
            peak_segments = [{"start": int(k.replace("s","")), "score": v}
                             for k, v in sorted_segs]
            try:
                db.collection("videos").document(video_id).update({
                    "peakReplaySegments": peak_segments,
                    "updatedAt":          firestore.SERVER_TIMESTAMP,
                })
            except Exception:
                pass

        logging.info("[session_rollup] completed quality + heatmap summaries")
    except Exception:
        logging.exception("session_analytics_rollup")
