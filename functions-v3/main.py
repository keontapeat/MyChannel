# MyChannel — Platform Functions v3
# Deep feature parity: creator tools, moderation, stream management,
# analytics signals, collab system, geographic restrictions, and more.

from firebase_functions import firestore_fn, https_fn, scheduler_fn, options
from firebase_admin import initialize_app, firestore, auth as admin_auth, messaging
import logging
import os
import re as _re
import hashlib as _hashlib
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
    """
    h = {"Access-Control-Allow-Origin": "*"}
    try:
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
