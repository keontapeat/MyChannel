# MyChannel — Platform Functions v4
# Final parity wave: Content ID matching, notification prefs, scheduled
# publish, bulk ops, demographics, members-only gating, impressions,
# account security.

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

def _db():
    return firestore.client()


# =============================================================================
# 1. CONTENT ID MATCHING
# On video upload (status → ready), scan against registered Content ID
# references. If a match is found, apply the rights holder's policy:
#   - block:    set video private + notify uploader
#   - monetize: route ad revenue to rights holder
#   - track:    log the match (no action)
# This is the metadata-match layer. Full acoustic fingerprinting runs in a
# dedicated Cloud Run service that writes match results to content_id_scans.
# =============================================================================

@firestore_fn.on_document_updated(
    document="videos/{videoId}",
    region="us-east1",
)
def content_id_scan_on_ready(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """Scan a newly-ready video against Content ID references and apply policy."""
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        if before.get("status") == after.get("status"): return
        if after.get("status") != "ready": return
        if after.get("contentIdScanned"): return  # idempotency

        video_id   = event.params["videoId"]
        creator_id = after.get("creatorId") or ""
        title      = (after.get("title") or "").lower()
        tags       = [t.lower() for t in (after.get("tags") or [])]
        isrc       = (after.get("isrc") or "").strip().upper()

        db = _db()

        # Metadata-level match: ISRC exact match, or title/tag overlap with reference
        matched_ref = None
        match_method = ""

        # 1) ISRC exact match (most reliable)
        if isrc:
            isrc_refs = (
                db.collection("content_id_references")
                .where("isrc", "==", isrc)
                .limit(1).get()
            )
            if isrc_refs:
                matched_ref = isrc_refs[0]
                match_method = "isrc"

        # 2) Title token match against reference titles
        if not matched_ref and title:
            title_tokens = set(_re.findall(r"[a-z0-9]+", title))
            # Scan active references (cap 200 for cost)
            refs = (
                db.collection("content_id_references")
                .where("status", "in", ["active", "pending_scan"])
                .limit(200).stream()
            )
            for ref_doc in refs:
                rd = ref_doc.to_dict() or {}
                ref_title  = (rd.get("title") or "").lower()
                ref_artist = (rd.get("artist") or "").lower()
                ref_tokens = set(_re.findall(r"[a-z0-9]+", f"{ref_title} {ref_artist}"))
                if not ref_tokens:
                    continue
                overlap = len(title_tokens & ref_tokens) / max(len(ref_tokens), 1)
                # Require strong overlap to avoid false positives
                if overlap >= 0.75 and len(ref_tokens) >= 2:
                    matched_ref = ref_doc
                    match_method = "title_match"
                    break

        now = firestore.SERVER_TIMESTAMP

        if not matched_ref:
            # No match — mark scanned, all clear
            db.collection("videos").document(video_id).update({
                "contentIdScanned": True,
                "contentIdStatus":  "clear",
                "updatedAt":        now,
            })
            return

        ref_data    = matched_ref.to_dict() or {}
        policy      = ref_data.get("policy") or "track"
        owner_id    = ref_data.get("ownerId") or ""
        ref_title   = ref_data.get("title") or ""

        # Record the match
        claim_ref = db.collection("content_id_claims").document()
        claim_ref.set({
            "id":            claim_ref.id,
            "videoId":       video_id,
            "videoCreatorId": creator_id,
            "referenceId":   matched_ref.id,
            "rightsHolderId": owner_id,
            "referenceTitle": ref_title,
            "policy":        policy,
            "matchMethod":   match_method,
            "status":        "active",
            "createdAt":     now,
        })

        # Apply policy
        video_update: dict = {
            "contentIdScanned": True,
            "contentIdStatus":  "claimed",
            "contentIdClaimId": claim_ref.id,
            "contentIdPolicy":  policy,
            "updatedAt":        now,
        }

        if policy == "block":
            video_update["isPublic"]      = False
            video_update["status"]        = "blocked_content_id"
            video_update["blockedReason"] = f"Content ID match: {ref_title}"
        elif policy == "monetize":
            # Route ad revenue to rights holder
            video_update["adRevenueBeneficiary"] = owner_id
            video_update["monetizedByClaim"]     = True

        db.collection("videos").document(video_id).update(video_update)

        # Increment reference match count
        matched_ref.reference.update({
            "matchCount": firestore.Increment(1),
            "lastMatchAt": now,
        })

        # Notify the uploader about the claim
        policy_msg = {
            "block":    "Your video has been blocked due to a copyright match.",
            "monetize": "A copyright claim was applied. Ad revenue goes to the rights holder. You can dispute this.",
            "track":    "A copyright match was detected on your video (tracking only, no action).",
        }.get(policy, "A Content ID match was detected.")

        db.collection("notifications").add({
            "userId":   creator_id,
            "type":     "content_id_claim",
            "title":    "Content ID claim on your video",
            "message":  policy_msg,
            "videoId":  video_id,
            "claimId":  claim_ref.id,
            "deepLink": f"mychannel://studio/copyright/{claim_ref.id}",
            "read":     False,
            "createdAt": now,
        })

        logging.info(f"[content_id] {video_id} matched {matched_ref.id} policy={policy}")
    except Exception:
        logging.exception("content_id_scan_on_ready")


@https_fn.on_request(region="us-east1")
def dispute_content_id_claim(req: https_fn.Request) -> https_fn.Response:
    """
    Dispute a Content ID claim on your video.
    POST { claimId, reason }
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
        claim_id = (body.get("claimId") or "").strip()
        reason   = (body.get("reason") or "").strip()[:1000]

        if not claim_id or not reason:
            return https_fn.Response({"ok": False, "error": "missing fields"}, 400, headers=h)

        db   = _db()
        ref  = db.collection("content_id_claims").document(claim_id)
        snap = ref.get()
        if not snap.exists:
            return https_fn.Response({"ok": False, "error": "claim_not_found"}, 404, headers=h)

        claim = snap.to_dict() or {}
        if claim.get("videoCreatorId") != uid:
            return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        now = firestore.SERVER_TIMESTAMP
        ref.update({
            "status":        "disputed",
            "disputeReason": reason,
            "disputedAt":    now,
        })

        # Notify rights holder + admin
        db.collection("admin_alerts").add({
            "type":     "content_id_dispute",
            "claimId":  claim_id,
            "videoId":  claim.get("videoId") or "",
            "disputedBy": uid,
            "reason":   reason[:200],
            "createdAt": now,
        })
        rights_holder = claim.get("rightsHolderId") or ""
        if rights_holder:
            db.collection("notifications").add({
                "userId":  rights_holder,
                "type":    "content_id_disputed",
                "title":   "Your Content ID claim was disputed",
                "message": "A creator disputed your copyright claim. Review required.",
                "claimId": claim_id,
                "read":    False,
                "createdAt": now,
            })

        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("dispute_content_id_claim")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 2. NOTIFICATION PREFERENCES API
# Per-type notification toggles. Checked by the push delivery function.
# =============================================================================

@https_fn.on_request(region="us-east1")
def update_notification_preferences(req: https_fn.Request) -> https_fn.Response:
    """
    Update per-type notification preferences.
    POST { preferences: { uploads: bool, comments: bool, likes: bool,
                          subscribers: bool, live: bool, reEngagement: bool,
                          weeklyDigest: bool, directMessages: bool } }
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

        body  = req.get_json(silent=True) or {}
        prefs = body.get("preferences") or {}

        allowed_keys = {
            "uploads", "comments", "likes", "subscribers", "live",
            "reEngagement", "weeklyDigest", "directMessages",
            "mentions", "milestones", "contentIdClaims", "payouts",
        }
        sanitized = {k: bool(v) for k, v in prefs.items() if k in allowed_keys}

        _db().collection("users").document(uid)\
             .collection("notification_settings").document("global").set({
                 **sanitized,
                 "updatedAt": firestore.SERVER_TIMESTAMP,
             }, merge=True)

        return https_fn.Response({"ok": True, "preferences": sanitized}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("update_notification_preferences")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 3. SCHEDULED VIDEO PUBLISH
# Creator schedules a private video to go public at a future time.
# A scheduler runs every minute to publish due videos.
# =============================================================================

@https_fn.on_request(region="us-east1")
def schedule_video_publish(req: https_fn.Request) -> https_fn.Response:
    """
    Schedule a private video to publish at a future time.
    POST { videoId, publishAt: ISO8601 string }
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
        video_id   = (body.get("videoId") or "").strip()
        publish_at = (body.get("publishAt") or "").strip()

        if not video_id or not publish_at:
            return https_fn.Response({"ok": False, "error": "missing fields"}, 400, headers=h)

        try:
            publish_dt = datetime.fromisoformat(publish_at.replace("Z", "+00:00"))
        except ValueError:
            return https_fn.Response({"ok": False, "error": "invalid_date"}, 400, headers=h)

        db = _db()
        v  = db.collection("videos").document(video_id).get()
        if not v.exists or (v.to_dict() or {}).get("creatorId") != uid:
            return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        now = firestore.SERVER_TIMESTAMP
        db.collection("videos").document(video_id).update({
            "isPublic":      False,
            "isScheduled":   True,
            "scheduledPublishAt": publish_dt,
            "updatedAt":     now,
        })
        db.collection("scheduled_publishes").document(video_id).set({
            "videoId":    video_id,
            "creatorId":  uid,
            "publishAt":  publish_dt,
            "status":     "scheduled",
            "createdAt":  now,
        })

        return https_fn.Response({"ok": True, "publishAt": publish_dt.isoformat()},
                                 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("schedule_video_publish")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


@scheduler_fn.on_schedule(
    schedule="every 1 minutes",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
    concurrency=1,
)
def publish_scheduled_videos(event: scheduler_fn.ScheduledEvent) -> None:
    """Publish videos whose scheduled time has arrived."""
    try:
        db  = _db()
        now = datetime.now(timezone.utc)

        due = (
            db.collection("scheduled_publishes")
            .where("status", "==", "scheduled")
            .where("publishAt", "<=", now)
            .limit(100).stream()
        )

        for doc in due:
            d        = doc.to_dict() or {}
            video_id = d.get("videoId") or ""
            creator_id = d.get("creatorId") or ""
            if not video_id:
                continue
            now_ts = firestore.SERVER_TIMESTAMP

            # Publish
            db.collection("videos").document(video_id).update({
                "isPublic":     True,
                "isScheduled":  False,
                "status":       "ready",
                "publishedAt":  now_ts,
                "updatedAt":    now_ts,
            })
            doc.reference.update({"status": "published", "publishedAt": now_ts})

            # Notify creator
            if creator_id:
                db.collection("notifications").add({
                    "userId":   creator_id,
                    "type":     "video_published",
                    "title":    "📅 Your scheduled video is live!",
                    "message":  "Your video has been published as scheduled.",
                    "videoId":  video_id,
                    "deepLink": f"mychannel://watch/{video_id}",
                    "read":     False,
                    "createdAt": now_ts,
                })
            logging.info(f"[scheduled_publish] published {video_id}")
    except Exception:
        logging.exception("publish_scheduled_videos")


# =============================================================================
# 4. BULK VIDEO OPERATIONS
# Edit visibility, monetization, or delete multiple videos at once.
# =============================================================================

@https_fn.on_request(region="us-east1")
def bulk_video_operation(req: https_fn.Request) -> https_fn.Response:
    """
    Perform a bulk operation on multiple videos.
    POST { videoIds: [], operation: 'visibility'|'delete'|'monetize'|'addTag',
           value? }
    Max 50 videos per call.
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
        video_ids = (body.get("videoIds") or [])[:50]
        operation = (body.get("operation") or "").strip()
        value     = body.get("value")

        if not video_ids or not operation:
            return https_fn.Response({"ok": False, "error": "missing fields"}, 400, headers=h)

        db    = _db()
        now   = firestore.SERVER_TIMESTAMP
        batch = db.batch()
        affected = 0

        for video_id in video_ids:
            v_ref  = db.collection("videos").document(video_id)
            v_snap = v_ref.get()
            if not v_snap.exists or (v_snap.to_dict() or {}).get("creatorId") != uid:
                continue  # skip videos the caller doesn't own

            if operation == "delete":
                batch.delete(v_ref)
            elif operation == "visibility":
                is_public = (value == "public")
                batch.update(v_ref, {
                    "isPublic":   is_public,
                    "visibility": value if value in ("public", "unlisted", "private") else "private",
                    "updatedAt":  now,
                })
            elif operation == "monetize":
                batch.update(v_ref, {"monetizationEnabled": bool(value), "updatedAt": now})
            elif operation == "addTag" and value:
                batch.update(v_ref, {"tags": firestore.ArrayUnion([str(value)[:50]]), "updatedAt": now})
            else:
                continue
            affected += 1
            if affected % 400 == 0:
                batch.commit()
                batch = db.batch()

        batch.commit()
        return https_fn.Response({"ok": True, "affected": affected}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("bulk_video_operation")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)


# =============================================================================
# 5. CHANNEL DEMOGRAPHICS ROLLUP
# Aggregates viewer age/gender/geo from view events into a demographics doc.
# Runs every 12 hours. Studio reads channel_demographics/{creatorId}.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 12 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_512,
    max_instances=1,
    timeout_sec=300,
)
def aggregate_channel_demographics(event: scheduler_fn.ScheduledEvent) -> None:
    """Roll up viewer demographics per creator from recent view events."""
    try:
        db  = _db()
        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(days=28)

        # Get recent views with viewer info
        views = (
            db.collection("view_dedup")
            .where("lastViewAt", ">=", cutoff)
            .limit(10000).stream()
        )

        # creator → demographics aggregation
        creator_demo: dict = {}

        for doc in views:
            d   = doc.to_dict() or {}
            cid = d.get("creatorId") or ""
            if not cid:
                continue
            parts = doc.id.split("_", 1)
            if len(parts) != 2 or parts[0].startswith("anon:"):
                continue
            viewer_id = parts[0]

            if cid not in creator_demo:
                creator_demo[cid] = {
                    "total": 0, "ageGroups": {}, "genders": {}, "countries": {},
                    "_viewers": set(),
                }
            if viewer_id in creator_demo[cid]["_viewers"]:
                continue
            creator_demo[cid]["_viewers"].add(viewer_id)
            creator_demo[cid]["total"] += 1

        # Enrich with viewer profile data (sample up to 500 per creator)
        for cid, demo in creator_demo.items():
            sampled = list(demo["_viewers"])[:500]
            for vid in sampled:
                try:
                    u = db.collection("users").document(vid).get()
                    if not u.exists:
                        continue
                    ud = u.to_dict() or {}
                    # Age group from dateOfBirth
                    dob = ud.get("dateOfBirth")
                    if dob:
                        try:
                            from datetime import date
                            birth = date.fromisoformat(str(dob)[:10])
                            age   = (date.today() - birth).days // 365
                            grp   = ("13-17" if age < 18 else "18-24" if age < 25 else
                                     "25-34" if age < 35 else "35-44" if age < 45 else
                                     "45-54" if age < 55 else "55+")
                            demo["ageGroups"][grp] = demo["ageGroups"].get(grp, 0) + 1
                        except Exception:
                            pass
                    gender = (ud.get("gender") or "unknown").lower()
                    demo["genders"][gender] = demo["genders"].get(gender, 0) + 1
                    country = (ud.get("country") or ud.get("region") or "unknown").upper()
                    demo["countries"][country] = demo["countries"].get(country, 0) + 1
                except Exception:
                    pass

            # Write demographics doc (strip the internal _viewers set)
            top_countries = sorted(demo["countries"].items(),
                                   key=lambda x: x[1], reverse=True)[:10]
            db.collection("channel_demographics").document(cid).set({
                "creatorId":     cid,
                "totalViewers":  len(demo["_viewers"]),
                "ageGroups":     demo["ageGroups"],
                "genders":       demo["genders"],
                "topCountries":  [{"country": c, "count": n} for c, n in top_countries],
                "updatedAt":     firestore.SERVER_TIMESTAMP,
            })

        logging.info(f"[demographics] rolled up {len(creator_demo)} channels")
    except Exception:
        logging.exception("aggregate_channel_demographics")


# =============================================================================
# 6. CREATOR HEART COMMENT
# Creator can "heart" a comment on their video (YouTube creator heart).
# =============================================================================

@https_fn.on_request(region="us-east1")
def heart_comment(req: https_fn.Request) -> https_fn.Response:
    """Creator hearts/unhearts a comment. POST { videoId, commentId, heart: bool }"""
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
        heart      = bool(body.get("heart", True))

        if not video_id or not comment_id:
            return https_fn.Response({"ok": False}, 400, headers=h)

        db = _db()
        v  = db.collection("videos").document(video_id).get()
        if not v.exists or (v.to_dict() or {}).get("creatorId") != uid:
            return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        now = firestore.SERVER_TIMESTAMP
        c_ref = db.collection("videos").document(video_id)\
                  .collection("comments").document(comment_id)
        c_ref.update({
            "creatorHearted":   heart,
            "creatorHeartedAt": now if heart else firestore.DELETE_FIELD,
            "updatedAt":        now,
        })

        # Notify the commenter when hearted
        if heart:
            c_snap = c_ref.get()
            commenter = (c_snap.to_dict() or {}).get("userId") or ""
            if commenter and commenter != uid:
                creator_name = (v.to_dict() or {}).get("creator", {}).get("displayName") or "The creator"
                db.collection("notifications").add({
                    "userId":   commenter,
                    "type":     "comment_hearted",
                    "title":    f"❤️ {creator_name} hearted your comment",
                    "videoId":  video_id,
                    "read":     False,
                    "createdAt": now,
                })

        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("heart_comment")
        return https_fn.Response({"ok": False}, 500, headers=h)


# =============================================================================
# 7. MEMBERS-ONLY CONTENT GATING
# Checks whether a viewer has an active membership entitlement for a
# members-only video before allowing playback.
# =============================================================================

@https_fn.on_request(region="us-east1")
def check_members_only_access(req: https_fn.Request) -> https_fn.Response:
    """
    Check if a viewer can access a members-only video.
    GET ?videoId=xxx — Returns { allowed: bool, requiresTier? }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization",
         "Cache-Control": "no-store"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        uid  = ""
        if auth.lower().startswith("bearer "):
            try: uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]
            except Exception: pass

        video_id = (req.args.get("videoId") or "").strip()
        if not video_id:
            return https_fn.Response({"allowed": False}, 400, headers=h)

        db   = _db()
        snap = db.collection("videos").document(video_id).get()
        if not snap.exists:
            return https_fn.Response({"allowed": False, "reason": "not_found"}, 404, headers=h)

        data = snap.to_dict() or {}
        if not data.get("membersOnly"):
            return https_fn.Response({"allowed": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        channel_id = data.get("creatorId") or ""
        # Creator always has access to own content
        if uid == channel_id:
            return https_fn.Response({"allowed": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        if not uid:
            return https_fn.Response({"allowed": False, "reason": "membership_required",
                                      "channelId": channel_id}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        # Check entitlement
        user_snap = db.collection("users").document(uid).get()
        entitlements = (user_snap.to_dict() or {}).get("entitlements") or {}
        has_access = entitlements.get(f"channel:{channel_id}", False)

        return https_fn.Response({
            "allowed":   bool(has_access),
            "reason":    None if has_access else "membership_required",
            "channelId": channel_id,
        }, 200, headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("check_members_only_access")
        return https_fn.Response({"allowed": False}, 500, headers=h)


# =============================================================================
# 8. VIDEO IMPRESSION TRACKING (real CTR)
# Client reports when a video thumbnail is shown in a feed (impression).
# Combined with clicks → real CTR for the trending/recommendation engine.
# =============================================================================

@https_fn.on_request(region="us-east1")
def record_impressions(req: https_fn.Request) -> https_fn.Response:
    """
    Record video thumbnail impressions (batched).
    POST { impressions: [videoId,...], clicked?: videoId }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        body        = req.get_json(silent=True) or {}
        impressions = (body.get("impressions") or [])[:50]
        clicked     = (body.get("clicked") or "").strip()

        if not impressions and not clicked:
            return https_fn.Response({"ok": True}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})

        db    = _db()
        batch = db.batch()
        n = 0
        now = firestore.SERVER_TIMESTAMP

        for video_id in impressions:
            if not video_id:
                continue
            batch.set(db.collection("video_impressions").document(video_id), {
                "impressions": firestore.Increment(1),
                "updatedAt":   now,
            }, merge=True)
            n += 1
            if n % 400 == 0:
                batch.commit()
                batch = db.batch()

        if clicked:
            batch.set(db.collection("video_impressions").document(clicked), {
                "clicks":    firestore.Increment(1),
                "updatedAt": now,
            }, merge=True)

        batch.commit()
        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})


@scheduler_fn.on_schedule(
    schedule="every 2 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def compute_real_ctr(event: scheduler_fn.ScheduledEvent) -> None:
    """Compute real CTR from impressions/clicks and write back to videos."""
    try:
        db  = _db()
        now = datetime.now(timezone.utc)
        snaps = (
            db.collection("video_impressions")
            .where("updatedAt", ">=", now - timedelta(hours=2))
            .limit(2000).stream()
        )
        for doc in snaps:
            d     = doc.to_dict() or {}
            imps  = int(d.get("impressions") or 0)
            clk   = int(d.get("clicks") or 0)
            if imps < 10:
                continue
            ctr = round(clk / imps * 100, 2)
            try:
                db.collection("videos").document(doc.id).update({
                    "impressionCTR": ctr,
                    "totalImpressions": imps,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                })
            except Exception:
                pass
        logging.info("[real_ctr] computed CTR for video batch")
    except Exception:
        logging.exception("compute_real_ctr")


# =============================================================================
# 9. SUSPICIOUS LOGIN DETECTION
# Triggered when a login event is recorded. Detects logins from new
# countries/devices and notifies the user + flags for review.
# =============================================================================

@firestore_fn.on_document_created(
    document="login_events/{eventId}",
    region="us-east1",
)
def detect_suspicious_login(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """Detect logins from new locations/devices and alert the user."""
    try:
        snap = event.data
        if not snap: return
        data    = snap.to_dict() or {}
        uid     = data.get("userId") or ""
        country = (data.get("country") or "").upper()
        device  = data.get("deviceId") or ""
        ip      = data.get("ipAddress") or ""

        if not uid:
            return

        db = _db()

        # Get user's known login locations
        known_ref  = db.collection("users").document(uid)\
                       .collection("knownLogins").document("summary")
        known_snap = known_ref.get()
        known      = known_snap.to_dict() or {} if known_snap.exists else {}

        known_countries = set(known.get("countries") or [])
        known_devices   = set(known.get("devices") or [])

        is_new_country = country and country not in known_countries
        is_new_device  = device and device not in known_devices

        now = firestore.SERVER_TIMESTAMP

        # Update known logins
        known_ref.set({
            "countries": firestore.ArrayUnion([country] if country else []),
            "devices":   firestore.ArrayUnion([device] if device else []),
            "lastLoginAt": now,
            "updatedAt": now,
        }, merge=True)

        # Alert on new country (most important signal) — only if user has prior history
        if is_new_country and known_countries:
            db.collection("notifications").add({
                "userId":  uid,
                "type":    "security_alert",
                "title":   "🔐 New login detected",
                "message": f"We noticed a sign-in from a new location ({country}). If this wasn't you, secure your account.",
                "deepLink": "mychannel://settings/security",
                "read":    False,
                "createdAt": now,
            })
            # Log security event
            db.collection("security_events").add({
                "uid":         uid,
                "type":        "new_country_login",
                "country":     country,
                "ip":          ip,
                "deviceId":    device,
                "createdAt":   now,
            })
            logging.info(f"[suspicious_login] new country {country} for {uid}")
    except Exception:
        logging.exception("detect_suspicious_login")


# =============================================================================
# 10. CHANNEL TRAILER + FEATURED VIDEO
# Set a channel trailer (for non-subscribers) and a featured video
# (for returning visitors) — YouTube channel customization parity.
# =============================================================================

@https_fn.on_request(region="us-east1")
def set_channel_featured(req: https_fn.Request) -> https_fn.Response:
    """
    Set channel trailer and/or featured video.
    POST { trailerVideoId?, featuredVideoId? }
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
        trailer_id   = (body.get("trailerVideoId") or "").strip()
        featured_id  = (body.get("featuredVideoId") or "").strip()

        db  = _db()
        now = firestore.SERVER_TIMESTAMP

        # Verify ownership of any provided videos
        for vid in [trailer_id, featured_id]:
            if vid:
                v = db.collection("videos").document(vid).get()
                if not v.exists or (v.to_dict() or {}).get("creatorId") != uid:
                    return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        updates: dict = {"updatedAt": now}
        if trailer_id:  updates["channelTrailerId"]  = trailer_id
        if featured_id: updates["channelFeaturedId"] = featured_id

        db.collection("users").document(uid).update(updates)

        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("set_channel_featured")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500, headers=h)
