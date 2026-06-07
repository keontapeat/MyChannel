# MyChannel — Platform Functions v2
# Escrow, compliance, moderation, milestones, captions, chapters,
# fraud detection, super chat, weekly digest, age verification.

from firebase_functions import firestore_fn, https_fn, scheduler_fn, options
from firebase_admin import initialize_app, firestore, auth as admin_auth, messaging
import logging
import os
import re as _re
import hashlib as _hashlib
import requests
from datetime import datetime, timezone, timedelta
from typing import Optional

options.set_global_options(cpu="gcf_gen1", max_instances=3, region="us-east1")

initialize_app()

# ─── CONSTANTS ────────────────────────────────────────────────────────────────

PLATFORM_FEE_PCT     = 0.10
KYC_THRESHOLD_CENTS  = 500_00
DAILY_LIMIT_CENTS    = 10_000_00

_DIVISIONS = [
    (1,        100_00,  "Lightweight"),
    (100_01,   500_00,  "Welterweight"),
    (500_01,   1000_00, "Middleweight"),
    (1000_01,  5000_00, "Heavyweight"),
    (5000_01, 10000_00, "Super Heavyweight"),
    (10000_01, None,    "Ultra Heavyweight"),
]

_MILESTONES = [100, 1_000, 10_000, 100_000, 1_000_000]
_MILESTONE_LABELS = {
    100:       ("🎉 100 subscribers!", "You hit 100 subscribers. Keep going!"),
    1_000:     ("🚀 1,000 subscribers!", "You crossed 1K subscribers. You're growing fast."),
    10_000:    ("🔥 10K subscribers!", "10,000 people subscribed to your channel!"),
    100_000:   ("💎 100K subscribers!", "You've reached 100K subscribers. Silver Play level."),
    1_000_000: ("👑 1 Million subscribers!", "You're a MyChannel Legend. 1 MILLION subscribers!"),
}

_TIMESTAMP_PATTERN = _re.compile(
    r"(?:^|\n)\s*(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–—:]\s*(.+?)(?=\n|$)",
    _re.MULTILINE,
)

SENDGRID_API_KEY = os.environ.get("SENDGRID_API_KEY", "")
FROM_EMAIL = "noreply@mychannel.live"
FROM_NAME  = "MyChannel"

# ─── HELPERS ──────────────────────────────────────────────────────────────────

def _db():
    return firestore.client()


def _get_division(amount_cents: int) -> str:
    for lo, hi, label in _DIVISIONS:
        if hi is None or lo <= amount_cents <= hi:
            return label
    return "Lightweight"


def _compliance_check(user_data: dict, amount_cents: int) -> Optional[str]:
    if not user_data.get("isAgeVerified") and not user_data.get("ageVerified"):
        return "age_not_verified"
    dob = user_data.get("dateOfBirth")
    if dob:
        try:
            from datetime import date
            birth = date.fromisoformat(str(dob)[:10])
            if (date.today() - birth).days // 365 < 18:
                return "under_18"
        except Exception:
            pass
    if not user_data.get("termsAccepted") and not user_data.get("hasAcceptedTerms"):
        return "terms_not_accepted"
    blocked = {"KP", "IR", "SY", "CU", "SD"}
    if (user_data.get("region") or user_data.get("country") or "").upper() in blocked:
        return "region_blocked"
    daily_total = int(user_data.get("dailyWagerTotal") or 0)
    daily_limit = int(user_data.get("dailyWagerLimit") or DAILY_LIMIT_CENTS)
    if daily_total + amount_cents > daily_limit:
        return "daily_limit_exceeded"
    if amount_cents >= KYC_THRESHOLD_CENTS:
        kyc = user_data.get("kycStatus") or user_data.get("kycVerified")
        if kyc not in ("verified", "approved", True):
            return "kyc_required"
    return None


def _send_email(to: str, subject: str, html: str) -> bool:
    if not SENDGRID_API_KEY:
        logging.info(f"[email] no key — would send to {to}: {subject}")
        return False
    try:
        r = requests.post(
            "https://api.sendgrid.com/v3/mail/send",
            headers={"Authorization": f"Bearer {SENDGRID_API_KEY}",
                     "Content-Type": "application/json"},
            json={"personalizations": [{"to": [{"email": to}]}],
                  "from": {"email": FROM_EMAIL, "name": FROM_NAME},
                  "subject": subject,
                  "content": [{"type": "text/html", "value": html}]},
            timeout=10,
        )
        return r.status_code in (200, 202)
    except Exception:
        return False


def _parse_ts(ts: str) -> int:
    parts = [int(p) for p in ts.strip().split(":")]
    if len(parts) == 2: return parts[0]*60 + parts[1]
    if len(parts) == 3: return parts[0]*3600 + parts[1]*60 + parts[2]
    return 0


# =============================================================================
# 1. ESCROW CREATE — lock funds when VS Match accepted
# MONEY NOTE: transactional · integer-cents · idempotent
# =============================================================================

@firestore_fn.on_document_updated(
    document="versus_matches/{matchId}",
    region="us-east1",
)
def escrow_create_on_match_accepted(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        match_id = event.params["matchId"]
        if before.get("status") == after.get("status"): return
        if after.get("status") != "active": return
        if after.get("escrowStatus") == "locked": return

        challenger_id = after.get("challengerId") or ""
        opponent_id   = after.get("opponentId")   or ""
        wager_cents   = int(after.get("wagerAmount") or after.get("wagerAmountCents") or 0)
        if not challenger_id or not opponent_id or wager_cents <= 0: return

        db = _db()

        @firestore.transactional
        def _lock(tx):
            c_ref = db.collection("vs_match_wallets").document(challenger_id)
            o_ref = db.collection("vs_match_wallets").document(opponent_id)
            m_ref = db.collection("versus_matches").document(match_id)
            c_bal = int((c_ref.get(transaction=tx).to_dict() or {}).get("availableBalance") or 0)
            o_bal = int((o_ref.get(transaction=tx).to_dict() or {}).get("availableBalance") or 0)
            if c_bal < wager_cents: raise ValueError(f"challenger_insufficient:{c_bal}<{wager_cents}")
            if o_bal < wager_cents: raise ValueError(f"opponent_insufficient:{o_bal}<{wager_cents}")
            now = firestore.SERVER_TIMESTAMP
            for ref in [c_ref, o_ref]:
                tx.update(ref, {"availableBalance": firestore.Increment(-wager_cents),
                                "pendingBalance":   firestore.Increment(wager_cents),
                                "updatedAt": now})
            tx.set(db.collection("escrow").document(match_id), {
                "matchId": match_id, "challengerId": challenger_id,
                "opponentId": opponent_id, "wagerCents": wager_cents,
                "totalCents": wager_cents * 2, "status": "locked",
                "division": _get_division(wager_cents),
                "createdAt": now, "updatedAt": now,
            })
            for uid, role in [(challenger_id,"challenger"),(opponent_id,"opponent")]:
                tx.set(db.collection("vs_match_transactions").document(), {
                    "userId": uid, "matchId": match_id, "type": "wager",
                    "amount": -wager_cents, "status": "completed", "role": role,
                    "description": f"Wager locked ({_get_division(wager_cents)})",
                    "createdAt": now,
                })
            tx.update(m_ref, {"escrowStatus": "locked", "updatedAt": now})

        _lock(db.transaction())
        logging.info(f"[escrow_create] locked {wager_cents*2}¢ match {match_id}")

    except ValueError as ve:
        logging.error(f"[escrow_create] {ve}")
        try:
            db2 = _db()
            for uid in [event.data.after.to_dict().get("challengerId"),
                        event.data.after.to_dict().get("opponentId")]:
                if uid:
                    db2.collection("notifications").add({
                        "userId": uid, "type": "match_failed",
                        "title": "VS Match cancelled",
                        "message": "Insufficient funds to lock wager.",
                        "read": False, "createdAt": firestore.SERVER_TIMESTAMP,
                    })
            db2.collection("versus_matches").document(match_id).update({
                "status": "cancelled", "cancelReason": str(ve),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })
        except Exception: pass
    except Exception:
        logging.exception("escrow_create_on_match_accepted")


# =============================================================================
# 2. ESCROW SETTLE — release winner payout when match completes
# MONEY NOTE: transactional · 10% platform fee · idempotent
# =============================================================================

@firestore_fn.on_document_updated(
    document="versus_matches/{matchId}",
    region="us-east1",
)
def escrow_settle_on_match_completed(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        match_id = event.params["matchId"]
        if before.get("status") == after.get("status"): return
        if after.get("status") != "completed": return

        winner_id = after.get("winnerId") or ""
        if not winner_id: return

        db = _db()
        escrow_ref  = db.collection("escrow").document(match_id)
        escrow_snap = escrow_ref.get()
        if not escrow_snap.exists: return
        escrow_data = escrow_snap.to_dict() or {}
        if escrow_data.get("status") == "released": return  # idempotency

        total_cents   = int(escrow_data.get("totalCents") or 0)
        wager_cents   = int(escrow_data.get("wagerCents") or 0)
        challenger_id = escrow_data.get("challengerId") or ""
        opponent_id   = escrow_data.get("opponentId")   or ""
        loser_id = opponent_id if winner_id == challenger_id else challenger_id
        fee_cents    = int(total_cents * PLATFORM_FEE_PCT)
        payout_cents = total_cents - fee_cents

        @firestore.transactional
        def _settle(tx):
            now = firestore.SERVER_TIMESTAMP
            w_ref = db.collection("vs_match_wallets").document(winner_id)
            l_ref = db.collection("vs_match_wallets").document(loser_id)
            tx.update(w_ref, {"availableBalance": firestore.Increment(payout_cents),
                               "pendingBalance":   firestore.Increment(-wager_cents),
                               "totalWinnings":    firestore.Increment(payout_cents),
                               "updatedAt": now})
            tx.update(l_ref, {"pendingBalance": firestore.Increment(-wager_cents),
                               "totalLosses":   firestore.Increment(wager_cents),
                               "updatedAt": now})
            tx.update(escrow_ref, {"status": "released", "winnerId": winner_id,
                                   "feeCents": fee_cents, "payoutCents": payout_cents,
                                   "settledAt": now, "updatedAt": now})
            for uid, amt, t in [(winner_id,payout_cents,"win"),(loser_id,-wager_cents,"loss")]:
                tx.set(db.collection("vs_match_transactions").document(), {
                    "userId": uid, "matchId": match_id, "type": t, "amount": amt,
                    "status": "completed", "feeCents": fee_cents if t=="win" else 0,
                    "description": f"VS Match {'win' if t=='win' else 'loss'} — {_get_division(wager_cents)}",
                    "createdAt": now,
                })
            tx.set(db.collection("platform_revenue").document(), {
                "source": "vs_match", "matchId": match_id,
                "feeCents": fee_cents, "createdAt": now,
            })

        _settle(db.transaction())
        for uid, title, msg in [
            (winner_id, "🏆 You won!", f"You won ${payout_cents/100:.2f} after the 10% fee."),
            (loser_id,  "VS Match result", "You lost this match. Better luck next time."),
        ]:
            db.collection("notifications").add({
                "userId": uid, "type": "match_completed", "title": title,
                "message": msg, "matchId": match_id, "read": False,
                "createdAt": firestore.SERVER_TIMESTAMP,
            })
        logging.info(f"[escrow_settle] {match_id} winner {winner_id} paid {payout_cents}¢")
    except Exception:
        logging.exception("escrow_settle_on_match_completed")


# =============================================================================
# 3. ESCROW REFUND — refund both sides on cancel/expiry
# MONEY NOTE: transactional · idempotent
# =============================================================================

@firestore_fn.on_document_updated(
    document="versus_matches/{matchId}",
    region="us-east1",
)
def escrow_refund_on_match_cancelled(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        match_id = event.params["matchId"]
        if before.get("status") == after.get("status"): return
        if after.get("status") not in ("cancelled","expired"): return

        db = _db()
        escrow_ref  = db.collection("escrow").document(match_id)
        escrow_snap = escrow_ref.get()
        if not escrow_snap.exists: return
        escrow_data = escrow_snap.to_dict() or {}
        if escrow_data.get("status") in ("refunded","released"): return

        wager_cents   = int(escrow_data.get("wagerCents") or 0)
        challenger_id = escrow_data.get("challengerId") or ""
        opponent_id   = escrow_data.get("opponentId")   or ""
        if wager_cents <= 0: return

        @firestore.transactional
        def _refund(tx):
            now = firestore.SERVER_TIMESTAMP
            for uid in [challenger_id, opponent_id]:
                if not uid: continue
                ref = db.collection("vs_match_wallets").document(uid)
                tx.update(ref, {"availableBalance": firestore.Increment(wager_cents),
                                "pendingBalance":   firestore.Increment(-wager_cents),
                                "updatedAt": now})
                tx.set(db.collection("vs_match_transactions").document(), {
                    "userId": uid, "matchId": match_id, "type": "refund",
                    "amount": wager_cents, "status": "completed",
                    "description": f"Wager refunded — match {after.get('status')}",
                    "createdAt": now,
                })
            tx.update(escrow_ref, {"status": "refunded",
                                   "refundedAt": now, "updatedAt": now})

        _refund(db.transaction())
        for uid in [challenger_id, opponent_id]:
            if uid:
                db.collection("notifications").add({
                    "userId": uid, "type": "match_refunded",
                    "title": "VS Match refunded",
                    "message": f"Your ${wager_cents/100:.2f} wager has been returned.",
                    "matchId": match_id, "read": False,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                })
        logging.info(f"[escrow_refund] {match_id} refunded {wager_cents*2}¢")
    except Exception:
        logging.exception("escrow_refund_on_match_cancelled")


# =============================================================================
# 4. SERVER-SIDE COMPLIANCE GATE
# =============================================================================

@https_fn.on_request(region="us-east1")
def check_wager_compliance(req: https_fn.Request) -> https_fn.Response:
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"allowed": False, "reason": "unauthenticated"}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ",1)[1].strip())["uid"]
        body = req.get_json(silent=True) or {}
        user_id      = body.get("userId") or uid
        amount_cents = int(body.get("amountCents") or 0)
        if user_id != uid:
            return https_fn.Response({"allowed": False, "reason": "forbidden"}, 403, headers=h)
        if amount_cents <= 0:
            return https_fn.Response({"allowed": False, "reason": "invalid_amount"}, 400, headers=h)
        snap = _db().collection("users").document(uid).get()
        if not snap.exists:
            return https_fn.Response({"allowed": False, "reason": "user_not_found"}, 404, headers=h)
        err = _compliance_check(snap.to_dict() or {}, amount_cents)
        if err:
            return https_fn.Response({"allowed": False, "reason": err}, 200,
                                     headers={"Access-Control-Allow-Origin": "*"})
        return https_fn.Response({"allowed": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("check_wager_compliance")
        return https_fn.Response({"allowed": False, "reason": "server_error"}, 500,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# 5. VIDEO READY → NOTIFY CREATOR
# =============================================================================

@firestore_fn.on_document_updated(
    document="videos/{videoId}",
    region="us-east1",
)
def notify_creator_video_ready(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        if before.get("status") == after.get("status"): return
        if after.get("status") != "ready": return
        video_id   = event.params["videoId"]
        creator_id = after.get("creatorId") or ""
        if not creator_id: return
        _db().collection("notifications").add({
            "userId": creator_id, "type": "video_ready",
            "title": "Your video is live 🎬",
            "message": f'"{after.get("title","Your video")}" finished processing and is now live.',
            "videoId": video_id, "thumbnailURL": after.get("thumbnailURL",""),
            "deepLink": f"mychannel://watch/{video_id}",
            "read": False, "createdAt": firestore.SERVER_TIMESTAMP,
        })
    except Exception:
        logging.exception("notify_creator_video_ready")


# =============================================================================
# 6. LIVE CHAT MODERATION
# =============================================================================

@https_fn.on_request(region="us-east1")
def moderate_live_chat_message(req: https_fn.Request) -> https_fn.Response:
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        uid = ""
        if auth.lower().startswith("bearer "):
            try: uid = admin_auth.verify_id_token(auth.split(" ",1)[1].strip())["uid"]
            except Exception: pass

        body      = req.get_json(silent=True) or {}
        message   = (body.get("message") or "").strip()
        stream_id = (body.get("streamId") or "").strip()
        if not message or not stream_id:
            return https_fn.Response({"allowed": False, "reason": "missing_fields"}, 400, headers=h)
        if len(message) > 500:
            return https_fn.Response({"allowed": False, "reason": "too_long"}, 200, headers=h)

        if uid:
            ban = _db().collection("chat_bans").document(f"{stream_id}_{uid}").get()
            if ban.exists:
                return https_fn.Response({"allowed": False, "reason": "banned"}, 200, headers=h)

        key = os.environ.get("PERSPECTIVE_API_KEY","")
        if key:
            try:
                r = requests.post(
                    "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze",
                    params={"key": key},
                    json={"comment":{"text":message[:3000]},
                          "requestedAttributes":{"TOXICITY":{},"SEVERE_TOXICITY":{},
                                                 "IDENTITY_ATTACK":{},"THREAT":{}},
                          "doNotStore":True},
                    timeout=3,
                )
                if r.ok:
                    sc = r.json().get("attributeScores", {})
                    score = max(
                        sc.get("TOXICITY",{}).get("summaryScore",{}).get("value",0),
                        sc.get("SEVERE_TOXICITY",{}).get("summaryScore",{}).get("value",0),
                        sc.get("IDENTITY_ATTACK",{}).get("summaryScore",{}).get("value",0),
                        sc.get("THREAT",{}).get("summaryScore",{}).get("value",0),
                    )
                    if score >= 0.85:
                        _db().collection("live_chat_flags").add({
                            "streamId": stream_id, "userId": uid,
                            "message": message[:500], "score": score,
                            "flaggedAt": firestore.SERVER_TIMESTAMP,
                        })
                        return https_fn.Response({"allowed": False, "reason": "toxic", "score": score},
                                                 200, headers=h)
            except Exception: pass

        return https_fn.Response({"allowed": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("moderate_live_chat_message")
        return https_fn.Response({"allowed": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# 7. MILESTONE NOTIFICATIONS
# =============================================================================

@firestore_fn.on_document_updated(
    document="users/{userId}",
    region="us-east1",
)
def milestone_notification_on_subscriber_change(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        uid    = event.params["userId"]
        before_count = int(before.get("subscriberCount") or 0)
        after_count  = int(after.get("subscriberCount")  or 0)
        if after_count <= before_count: return

        db = _db()
        for milestone in _MILESTONES:
            if before_count < milestone <= after_count:
                if db.collection("milestones").document(f"{uid}_{milestone}").get().exists:
                    continue
                title, msg = _MILESTONE_LABELS.get(
                    milestone, (f"🎉 {milestone:,} subscribers!", f"You hit {milestone:,}!"))
                db.collection("notifications").add({
                    "userId": uid, "type": "milestone", "title": title, "message": msg,
                    "milestone": milestone, "deepLink": "mychannel://studio/analytics",
                    "read": False, "createdAt": firestore.SERVER_TIMESTAMP,
                })
                db.collection("milestones").document(f"{uid}_{milestone}").set({
                    "userId": uid, "milestone": milestone,
                    "achievedAt": firestore.SERVER_TIMESTAMP,
                })
    except Exception:
        logging.exception("milestone_notification_on_subscriber_change")


# =============================================================================
# 8. AGE VERIFICATION ENFORCE
# =============================================================================

@https_fn.on_request(region="us-east1")
def verify_age(req: https_fn.Request) -> https_fn.Response:
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"verified": False, "reason": "unauthenticated"}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ",1)[1].strip())["uid"]
        body = req.get_json(silent=True) or {}
        dob_str = (body.get("dateOfBirth") or "").strip()
        if not dob_str:
            return https_fn.Response({"verified": False, "reason": "missing_dob"}, 400, headers=h)
        from datetime import date
        try: dob = date.fromisoformat(dob_str[:10])
        except ValueError:
            return https_fn.Response({"verified": False, "reason": "invalid_date"}, 400, headers=h)
        age = (date.today() - dob).days // 365
        if age < 18:
            return https_fn.Response({"verified": False, "reason": "under_18", "age": age},
                                     200, headers=h)
        now = firestore.SERVER_TIMESTAMP
        _db().collection("age_verifications").document(uid).set({
            "userId": uid, "dateOfBirth": dob_str, "age": age,
            "verifiedAt": now, "method": "self_declared",
        })
        _db().collection("users").document(uid).update({
            "isAgeVerified": True, "dateOfBirth": dob_str, "ageVerifiedAt": now,
        })
        return https_fn.Response({"verified": True, "age": age}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("verify_age")
        return https_fn.Response({"verified": False, "reason": "server_error"}, 500,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# 9. DUPLICATE UPLOAD DETECTOR
# =============================================================================

@firestore_fn.on_document_created(
    document="video_transcode_jobs/{jobId}",
    region="us-east1",
)
def detect_duplicate_upload(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    try:
        snap = event.data
        if not snap: return
        data = snap.to_dict() or {}
        job_id     = event.params["jobId"]
        video_id   = data.get("videoId") or ""
        creator_id = data.get("creatorId") or ""
        if not video_id or not creator_id: return

        file_size = int(data.get("fileSizeBytes") or 0)
        title     = (data.get("title") or "").strip().lower()
        raw       = f"{title}:{file_size}:{creator_id}"
        content_hash = _hashlib.sha256(raw.encode()).hexdigest()[:32]

        db  = _db()
        cutoff = datetime.now(timezone.utc) - timedelta(days=30)
        existing = (
            db.collection("video_fingerprints")
            .where("hash", "==", content_hash)
            .where("creatorId", "==", creator_id)
            .where("createdAt", ">=", cutoff)
            .limit(1).get()
        )
        if existing:
            orig = (existing[0].to_dict() or {}).get("videoId", "unknown")
            now  = firestore.SERVER_TIMESTAMP
            db.collection("video_transcode_jobs").document(job_id).update(
                {"status": "duplicate", "duplicateOf": orig, "updatedAt": now})
            db.collection("videos").document(video_id).update(
                {"status": "duplicate", "duplicateOf": orig, "updatedAt": now})
            db.collection("notifications").add({
                "userId": creator_id, "type": "duplicate_upload",
                "title": "Duplicate video detected",
                "message": "This upload appears identical to a video you already have.",
                "videoId": video_id, "read": False,
                "createdAt": now,
            })
            return

        db.collection("video_fingerprints").document(f"{creator_id}_{video_id}").set({
            "hash": content_hash, "videoId": video_id, "creatorId": creator_id,
            "fileSizeBytes": file_size, "title": title,
            "createdAt": firestore.SERVER_TIMESTAMP,
        })
    except Exception:
        logging.exception("detect_duplicate_upload")


# =============================================================================
# 10. WEEKLY CREATOR DIGEST EMAIL
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every monday 09:00",
    region="us-east1",
    memory=options.MemoryOption.MB_512,
    max_instances=1,
)
def weekly_creator_digest(event: scheduler_fn.ScheduledEvent) -> None:
    try:
        db     = _db()
        cutoff = datetime.now(timezone.utc) - timedelta(days=7)
        snaps  = (db.collection("creator_analytics")
                    .where("updatedAt", ">=", cutoff).limit(1000).stream())
        sent = 0
        for doc in snaps:
            try:
                data = doc.to_dict() or {}
                uid  = doc.id
                user = (db.collection("users").document(uid).get().to_dict() or {})
                email = user.get("email") or ""
                name  = user.get("displayName") or "Creator"
                if not email or "@" not in email: continue

                prefs = (db.collection("users").document(uid)
                           .collection("notification_settings").document("global").get())
                if prefs.exists and not (prefs.to_dict() or {}).get("weeklyDigest", True):
                    continue

                views   = int(data.get("totalViews") or 0)
                subs    = int(data.get("totalSubscribers") or user.get("subscriberCount") or 0)
                revenue = float(data.get("revenueEstimate") or 0)
                videos  = int(data.get("totalVideos") or 0)
                html = f"""
                <div style="font-family:sans-serif;max-width:600px;margin:0 auto;
                            background:#000;color:#fff;padding:32px;border-radius:12px">
                  <h2 style="margin:0 0 16px">Weekly recap, {name} 📊</h2>
                  <p style="color:#aaa;margin:0 0 20px;font-size:14px">Here's how your channel performed this week.</p>
                  <table style="width:100%;border-collapse:collapse">
                    {"".join([f'<tr><td style="padding:8px;color:#aaa;font-size:13px">{l}</td>'
                               f'<td style="padding:8px;font-weight:700;font-size:18px">{v}</td></tr>'
                               for l, v in [("Views",f"{views:,}"),("Subscribers",f"{subs:,}"),
                                            ("Est. Revenue",f"${revenue:,.2f}"),("Videos",f"{videos:,}")]])}
                  </table>
                  <a href="https://mychannel.live/studio/analytics"
                     style="display:inline-block;background:#FF0000;color:#fff;
                            text-decoration:none;font-weight:700;padding:12px 24px;
                            border-radius:8px;margin-top:20px">View Analytics →</a>
                </div>"""
                if _send_email(email, f"Your weekly recap 📊 — {name}", html):
                    sent += 1
            except Exception: pass
        logging.info(f"[weekly_digest] sent {sent}")
    except Exception:
        logging.exception("weekly_creator_digest")


# =============================================================================
# 11. AUTO CAPTIONS
# =============================================================================

@firestore_fn.on_document_updated(
    document="videos/{videoId}",
    region="us-east1",
)
def auto_generate_captions(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        if before.get("status") == after.get("status"): return
        if after.get("status") != "ready": return

        video_id = event.params["videoId"]
        hls_url  = after.get("hlsURL") or after.get("videoURL") or ""
        duration = int(after.get("duration") or 0)
        if not hls_url or duration > 7200: return

        project = os.environ.get("GOOGLE_CLOUD_PROJECT","")
        if not project: return

        output_bucket = after.get("outputBucket","")
        if not output_bucket:
            m = _re.search(r"storage\.googleapis\.com/([^/]+)/", hls_url)
            if m: output_bucket = m.group(1)
        if not output_bucket: return

        audio_uri = f"gs://{output_bucket}/videos/{video_id}/hls/audio-aac.m3u8"
        try:
            import google.auth
            import google.auth.transport.requests as _gr
            creds, _ = google.auth.default(
                scopes=["https://www.googleapis.com/auth/cloud-platform"])
            creds.refresh(_gr.Request())
            r = requests.post(
                "https://speech.googleapis.com/v1p1beta1/speech:longrunningrecognize",
                headers={"Authorization": f"Bearer {creds.token}",
                         "Content-Type": "application/json"},
                json={"config": {"encoding":"MP3","sampleRateHertz":44100,
                                  "languageCode":"en-US","enableWordTimeOffsets":True,
                                  "enableAutomaticPunctuation":True,"model":"video"},
                      "audio": {"uri": audio_uri}},
                timeout=15,
            )
            if r.ok:
                op = r.json().get("name","")
                _db().collection("videos").document(video_id)\
                    .collection("captions").document("en").set({
                        "languageCode":"en","languageName":"English",
                        "status":"processing","sttOperationName":op,
                        "isAutoGenerated":True,"createdAt":firestore.SERVER_TIMESTAMP,
                    }, merge=True)
        except Exception as e:
            logging.warning(f"[captions] STT failed {video_id}: {e}")
    except Exception:
        logging.exception("auto_generate_captions")


# =============================================================================
# 12. CHAPTER EXTRACTOR
# =============================================================================

@firestore_fn.on_document_updated(
    document="videos/{videoId}",
    region="us-east1",
)
def extract_chapters_from_description(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        if before.get("description") == after.get("description"): return

        video_id = event.params["videoId"]
        desc     = after.get("description") or ""
        matches  = _TIMESTAMP_PATTERN.findall(desc)
        if len(matches) < 3: return

        db  = _db()
        col = db.collection("videos").document(video_id).collection("chapters")
        batch = db.batch()
        for old in col.stream():
            batch.delete(old.reference)

        for ts_str, title in matches:
            ref = col.document()
            batch.set(ref, {"title": title.strip()[:100],
                            "startTime": _parse_ts(ts_str),
                            "timestamp": ts_str,
                            "createdAt": firestore.SERVER_TIMESTAMP})

        batch.update(db.collection("videos").document(video_id), {
            "hasChapters": True, "chapterCount": len(matches),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })
        batch.commit()
        logging.info(f"[chapters] {len(matches)} chapters for {video_id}")
    except Exception:
        logging.exception("extract_chapters_from_description")


# =============================================================================
# 13. SUSPICIOUS VIEW PATTERN DETECTOR
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 30 minutes",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def detect_suspicious_view_patterns(event: scheduler_fn.ScheduledEvent) -> None:
    try:
        db     = _db()
        now    = datetime.now(timezone.utc)
        window = now - timedelta(minutes=30)
        snaps  = (db.collection("view_dedup")
                    .where("lastViewAt", ">=", window).limit(5000).stream())

        counts: dict = {}
        for doc in snaps:
            parts = doc.id.split("_", 1)
            if len(parts) != 2: continue
            uid, vid = parts
            if uid.startswith("anon:"): continue
            counts.setdefault(vid, set()).add(uid)

        flagged = 0
        for vid, viewers in counts.items():
            if len(viewers) < 50: continue
            existing = (db.collection("view_fraud_flags")
                          .where("videoId","==",vid)
                          .where("createdAt",">=",window).limit(1).get())
            if existing: continue
            try:
                cid = (_db().collection("videos").document(vid).get().to_dict() or {}).get("creatorId","")
            except Exception: cid = ""
            db.collection("view_fraud_flags").add({
                "videoId": vid, "creatorId": cid,
                "uniqueViewers": len(viewers), "windowMinutes": 30,
                "threshold": 50, "status": "pending_review",
                "createdAt": firestore.SERVER_TIMESTAMP,
            })
            flagged += 1
        if flagged:
            logging.warning(f"[view_fraud] flagged {flagged} videos")
    except Exception:
        logging.exception("detect_suspicious_view_patterns")


# =============================================================================
# 14. SUPER CHAT PAYMENT VERIFY
# MONEY NOTE: transactional · idempotent via idempotency key
# =============================================================================

@https_fn.on_request(region="us-east1")
def verify_super_chat_payment(req: https_fn.Request) -> https_fn.Response:
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"verified": False, "reason": "unauthenticated"}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ",1)[1].strip())["uid"]

        body          = req.get_json(silent=True) or {}
        stream_id     = (body.get("streamId") or "").strip()
        amount_cents  = int(body.get("amountCents") or 0)
        message       = (body.get("message") or "").strip()
        idem_key      = (body.get("idempotencyKey") or "").strip()

        if not stream_id or amount_cents < 100 or not message:
            return https_fn.Response({"verified": False, "reason": "invalid_input"}, 400, headers=h)

        db = _db()
        if idem_key:
            snap = db.collection("super_chat_idempotency").document(idem_key).get()
            if snap.exists:
                return https_fn.Response(
                    {"verified": True, "token": (snap.to_dict() or {}).get("token","")},
                    200, headers={"Access-Control-Allow-Origin":"*"})

        user_snap = db.collection("users").document(uid).get()
        err = _compliance_check(user_snap.to_dict() or {}, amount_cents)
        if err:
            return https_fn.Response({"verified": False, "reason": err}, 200, headers=h)

        token = _hashlib.sha256(
            f"{uid}:{stream_id}:{amount_cents}:{message[:50]}".encode()
        ).hexdigest()[:24]

        @firestore.transactional
        def _charge(tx):
            w_ref  = db.collection("vs_match_wallets").document(uid)
            w_data = w_ref.get(transaction=tx).to_dict() or {}
            bal    = int(w_data.get("availableBalance") or 0)
            if bal < amount_cents: raise ValueError("insufficient_funds")
            now = firestore.SERVER_TIMESTAMP
            tx.update(w_ref, {"availableBalance": firestore.Increment(-amount_cents),
                               "updatedAt": now})
            tx.set(db.collection("vs_match_transactions").document(), {
                "userId": uid, "streamId": stream_id, "type": "super_chat",
                "amount": -amount_cents, "message": message[:200],
                "token": token, "status": "completed", "createdAt": now,
            })
            # 90% to stream creator
            payout = int(amount_cents * 0.90)
            stream = db.collection("live_streams").document(stream_id).get(transaction=tx)
            cid    = (stream.to_dict() or {}).get("creatorId","")
            if cid and cid != uid:
                tx.update(db.collection("vs_match_wallets").document(cid), {
                    "availableBalance": firestore.Increment(payout), "updatedAt": now})

        _charge(db.transaction())

        if idem_key:
            db.collection("super_chat_idempotency").document(idem_key).set({
                "token": token, "uid": uid, "streamId": stream_id,
                "amountCents": amount_cents, "createdAt": firestore.SERVER_TIMESTAMP,
            })

        return https_fn.Response({"verified": True, "token": token}, 200,
                                 headers={"Access-Control-Allow-Origin":"*"})
    except ValueError as ve:
        return https_fn.Response({"verified": False, "reason": str(ve)}, 200,
                                 headers={"Access-Control-Allow-Origin":"*"})
    except Exception:
        logging.exception("verify_super_chat_payment")
        return https_fn.Response({"verified": False, "reason": "server_error"}, 500,
                                 headers={"Access-Control-Allow-Origin":"*"})


# =============================================================================
# ██████████████████████████████████████████████████████████████████████████████
#
#   YOUTUBE PARITY — ROUND 2
#
#   1.  Captions STT Polling  (complete pending caption jobs)
#   2.  Premiere Scheduler    (countdown notifications + auto-publish)
#   3.  Email Verification Flow  (verify → update Firestore)
#   4.  Playlist Management   (add video, reorder, thumbnail)
#   5.  Creator Ad Revenue Payout  (Stripe transfer to bank)
#   6.  VS Match Leaderboard  (1st/2nd/3rd place ranking by category)
#   7.  VS Match Matchmaking  (auto-match challengers by wager range)
#   8.  Live Betting          (wager placement during live streams)
#   9.  Flicks Recommendation Engine  (Shorts-style ML feed)
#
# =============================================================================


# =============================================================================
# 1. CAPTIONS STT POLLING
# Runs every 10 minutes. Finds all captions docs with status='processing',
# calls the Speech-to-Text Operations API to check if the job is done,
# and writes the VTT transcript to Storage + updates the captions doc.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 10 minutes",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def poll_caption_jobs(event: scheduler_fn.ScheduledEvent) -> None:
    """Poll pending Speech-to-Text operations and write completed captions."""
    try:
        db = _db()
        # collectionGroup query across all videos' captions subcollections
        pending = (
            db.collection_group("captions")
            .where("status", "==", "processing")
            .where("isAutoGenerated", "==", True)
            .limit(50)
            .stream()
        )

        import google.auth
        import google.auth.transport.requests as _gr

        try:
            creds, _ = google.auth.default(
                scopes=["https://www.googleapis.com/auth/cloud-platform"]
            )
            creds.refresh(_gr.Request())
            token = creds.token
        except Exception as e:
            logging.warning(f"[captions_poll] no GCP creds: {e}")
            return

        for doc in pending:
            data = doc.to_dict() or {}
            op_name = data.get("sttOperationName") or ""
            if not op_name:
                continue

            # Check operation status
            try:
                r = requests.get(
                    f"https://speech.googleapis.com/v1/operations/{op_name}",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=10,
                )
                if not r.ok:
                    continue

                op = r.json()
                if not op.get("done"):
                    continue  # still processing

                if op.get("error"):
                    doc.reference.update({
                        "status": "failed",
                        "error": str(op["error"]),
                        "updatedAt": firestore.SERVER_TIMESTAMP,
                    })
                    continue

                # Build WebVTT from word-time-offset results
                results = op.get("response", {}).get("results", [])
                vtt_lines = ["WEBVTT\n"]
                seq = 1
                for result in results:
                    alts = result.get("alternatives", [])
                    if not alts:
                        continue
                    words = alts[0].get("words", [])
                    if not words:
                        # No word-level timing — write as a single cue
                        transcript = alts[0].get("transcript", "").strip()
                        if transcript:
                            vtt_lines.append(f"\n{seq}\n00:00:00.000 --> 00:00:05.000\n{transcript}\n")
                            seq += 1
                        continue

                    # Group words into ~5s cues
                    chunk: list = []
                    chunk_start: float = 0.0

                    def _secs(t_str: str) -> float:
                        return float(t_str.replace("s", ""))

                    def _fmt(s: float) -> str:
                        h = int(s // 3600)
                        m = int((s % 3600) // 60)
                        sec = s % 60
                        return f"{h:02d}:{m:02d}:{sec:06.3f}"

                    for word in words:
                        start = _secs(word.get("startTime", "0s"))
                        if not chunk:
                            chunk_start = start
                        chunk.append(word.get("word", ""))
                        end = _secs(word.get("endTime", "0s"))
                        if end - chunk_start >= 5.0 or len(chunk) >= 12:
                            vtt_lines.append(
                                f"\n{seq}\n{_fmt(chunk_start)} --> {_fmt(end)}\n{' '.join(chunk)}\n"
                            )
                            seq += 1
                            chunk = []

                    if chunk:
                        end = _secs(words[-1].get("endTime", "0s"))
                        vtt_lines.append(
                            f"\n{seq}\n{_fmt(chunk_start)} --> {_fmt(end)}\n{' '.join(chunk)}\n"
                        )

                vtt_content = "".join(vtt_lines)

                # Extract videoId from document path: videos/{videoId}/captions/{lang}
                path_parts = doc.reference.path.split("/")
                video_id = path_parts[1] if len(path_parts) >= 4 else ""

                # Upload VTT to Storage
                caption_url = ""
                if video_id:
                    try:
                        from firebase_admin import storage as fb_storage
                        bucket = fb_storage.bucket()
                        blob = bucket.blob(f"captions/{video_id}/en.vtt")
                        blob.upload_from_string(vtt_content, content_type="text/vtt")
                        blob.make_public()
                        caption_url = blob.public_url
                    except Exception as se:
                        logging.warning(f"[captions_poll] storage upload failed: {se}")

                doc.reference.update({
                    "status": "completed",
                    "url": caption_url,
                    "completedAt": firestore.SERVER_TIMESTAMP,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                })

                # Update video doc so player knows captions are available
                if video_id:
                    db.collection("videos").document(video_id).update({
                        "hasCaptions": True,
                        "captionLanguages": firestore.ArrayUnion(["en"]),
                        "updatedAt": firestore.SERVER_TIMESTAMP,
                    })

                logging.info(f"[captions_poll] completed captions for {video_id}")

            except Exception as e:
                logging.warning(f"[captions_poll] operation check failed: {e}")

    except Exception:
        logging.exception("poll_caption_jobs")


# =============================================================================
# 2. PREMIERE SCHEDULER
# Runs every minute. Checks scheduled_premieres for upcoming events and:
#   - T-60min: sends "Premiering in 1 hour" notification to subscribers
#   - T-5min:  sends "Premiering in 5 minutes" notification
#   - T-0:     makes video public, sends "Premiering now!" notification
# Also cleans up expired premiere docs.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 1 minutes",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
    concurrency=1,
)
def premiere_scheduler(event: scheduler_fn.ScheduledEvent) -> None:
    """Drive scheduled video premieres — countdown notifications + auto-publish."""
    try:
        db  = _db()
        now = datetime.now(timezone.utc)

        # Window: premieres in the next 61 minutes that haven't fired yet
        window_end = now + timedelta(minutes=61)
        snaps = (
            db.collection("scheduled_premieres")
            .where("status", "in", ["scheduled", "notified_60", "notified_5"])
            .where("scheduledAt", "<=", window_end)
            .limit(100)
            .stream()
        )

        for doc in snaps:
            data     = doc.to_dict() or {}
            video_id  = data.get("videoId") or ""
            creator_id = data.get("creatorId") or ""
            title     = data.get("title") or data.get("videoTitle") or "A video"
            thumb     = data.get("thumbnailURL") or ""
            status    = data.get("status") or "scheduled"

            sched_ts = data.get("scheduledAt")
            if not sched_ts:
                continue

            try:
                sched_dt = datetime.fromtimestamp(
                    sched_ts.timestamp(), tz=timezone.utc
                )
            except Exception:
                continue

            mins_until = (sched_dt - now).total_seconds() / 60

            # T-0: publish the video
            if mins_until <= 0 and status != "published":
                # Make video public
                if video_id:
                    db.collection("videos").document(video_id).update({
                        "isPublic": True,
                        "status": "ready",
                        "visibility": "public",
                        "publishedAt": firestore.SERVER_TIMESTAMP,
                        "updatedAt": firestore.SERVER_TIMESTAMP,
                    })

                # Notify all subscribers
                _fanout_premiere_notification(
                    db, creator_id, video_id, title, thumb,
                    "is premiering now 🎬", "premiere_live",
                    f"mychannel://watch/{video_id}"
                )
                doc.reference.update({
                    "status": "published",
                    "publishedAt": firestore.SERVER_TIMESTAMP,
                })
                logging.info(f"[premiere] published {video_id}")

            # T-5min
            elif 3 <= mins_until <= 7 and status == "notified_60":
                _fanout_premiere_notification(
                    db, creator_id, video_id, title, thumb,
                    "premieres in 5 minutes ⏰", "premiere_soon",
                    f"mychannel://watch/{video_id}"
                )
                doc.reference.update({"status": "notified_5"})

            # T-60min
            elif 55 <= mins_until <= 65 and status == "scheduled":
                _fanout_premiere_notification(
                    db, creator_id, video_id, title, thumb,
                    "premieres in 1 hour 📅", "premiere_reminder",
                    f"mychannel://watch/{video_id}"
                )
                doc.reference.update({"status": "notified_60"})

    except Exception:
        logging.exception("premiere_scheduler")


def _fanout_premiere_notification(
    db, creator_id: str, video_id: str, title: str,
    thumb: str, verb: str, notif_type: str, deep_link: str
) -> None:
    """Send a premiere notification to all of the creator's subscribers."""
    try:
        if not creator_id:
            return
        subs = (
            db.collection("users").document(creator_id)
            .collection("subscribers").limit(500).stream()
        )
        creator_snap = db.collection("users").document(creator_id).get()
        creator_name = (creator_snap.to_dict() or {}).get("displayName") or "A creator"

        batch = db.batch()
        n = 0
        for sub in subs:
            if sub.id == creator_id:
                continue
            batch.set(db.collection("notifications").document(), {
                "userId": sub.id,
                "type": notif_type,
                "title": f"{creator_name} {verb}",
                "message": title,
                "videoId": video_id,
                "thumbnailURL": thumb,
                "deepLink": deep_link,
                "read": False,
                "createdAt": firestore.SERVER_TIMESTAMP,
            })
            n += 1
            if n % 499 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()
        logging.info(f"[premiere] sent {n} '{verb}' notifications")
    except Exception:
        logging.exception("_fanout_premiere_notification")


# =============================================================================
# 3. EMAIL VERIFICATION FLOW
# Triggered when users/{uid}.emailVerified transitions false → true
# (Firebase Auth sets this field when the user clicks the verification link).
# Updates Firestore and sends a "you're verified" confirmation.
# =============================================================================

@firestore_fn.on_document_updated(
    document="users/{userId}",
    region="us-east1",
)
def on_email_verified_update(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """Handle email verification — update Firestore, send confirmation."""
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        uid    = event.params["userId"]

        # Only fire on false → true transition
        if before.get("emailVerified") or not after.get("emailVerified"):
            return

        email = after.get("email") or ""
        name  = after.get("displayName") or after.get("username") or "Creator"

        # Update profile flags
        _db().collection("users").document(uid).update({
            "isEmailVerified":        True,
            "emailVerifiedAt":        firestore.SERVER_TIMESTAMP,
            "canReceivePayouts":      True,  # unlock payout eligibility
            "profileCompletionScore": firestore.Increment(10),
            "updatedAt":              firestore.SERVER_TIMESTAMP,
        })

        # Send confirmation email
        if email and "@" in email:
            html = f"""
            <div style="font-family:sans-serif;max-width:600px;margin:0 auto;
                        background:#000;color:#fff;padding:32px;border-radius:12px">
              <h2 style="margin:0 0 12px">✅ Email verified, {name}!</h2>
              <p style="color:#aaa;margin:0 0 20px;font-size:14px">
                Your email is confirmed. Your account is fully active — 
                you can now receive payouts and access all creator features.
              </p>
              <a href="https://mychannel.live/upload"
                 style="display:inline-block;background:#FF0000;color:#fff;
                        text-decoration:none;font-weight:700;padding:12px 24px;
                        border-radius:8px">Upload Your First Video →</a>
            </div>"""
            _send_email(email, f"Email verified ✅ — Welcome to MyChannel, {name}!", html)

        # In-app notification
        _db().collection("notifications").add({
            "userId": uid, "type": "email_verified",
            "title": "Email verified ✅",
            "message": "Your account is fully active. You can now receive payouts.",
            "read": False, "createdAt": firestore.SERVER_TIMESTAMP,
        })
        logging.info(f"[email_verified] user {uid}")

    except Exception:
        logging.exception("on_email_verified_update")


# =============================================================================
# 4. PLAYLIST MANAGEMENT
# add_to_playlist  — adds a video to a playlist, reorders by position
# reorder_playlist — updates videoIds array with new order
# Both callable from iOS/Android/Web.
# =============================================================================

@https_fn.on_request(region="us-east1")
def playlist_add_video(req: https_fn.Request) -> https_fn.Response:
    """
    Add a video to a playlist. Creates playlist if it doesn't exist.
    POST { playlistId?, title?, videoId, isPublic? }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False, "error": "unauthenticated"}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body        = req.get_json(silent=True) or {}
        video_id    = (body.get("videoId") or "").strip()
        playlist_id = (body.get("playlistId") or "").strip()
        title       = (body.get("title") or "My Playlist").strip()[:100]
        is_public   = bool(body.get("isPublic", True))

        if not video_id:
            return https_fn.Response({"ok": False, "error": "missing videoId"}, 400, headers=h)

        db  = _db()
        now = firestore.SERVER_TIMESTAMP

        # Verify video exists
        v_snap = db.collection("videos").document(video_id).get()
        if not v_snap.exists:
            return https_fn.Response({"ok": False, "error": "video_not_found"}, 404, headers=h)
        v_data = v_snap.to_dict() or {}

        if playlist_id:
            # Add to existing playlist
            pl_ref  = db.collection("playlists").document(playlist_id)
            pl_snap = pl_ref.get()
            if not pl_snap.exists:
                return https_fn.Response({"ok": False, "error": "playlist_not_found"}, 404, headers=h)
            pl_data = pl_snap.to_dict() or {}
            if pl_data.get("creatorId") != uid:
                return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)
            if video_id in (pl_data.get("videoIds") or []):
                return https_fn.Response({"ok": True, "playlistId": playlist_id, "alreadyAdded": True},
                                         200, headers={"Access-Control-Allow-Origin": "*"})
            pl_ref.update({
                "videoIds":   firestore.ArrayUnion([video_id]),
                "videoCount": firestore.Increment(1),
                # Use first video thumbnail if playlist has none
                "thumbnailURL": pl_data.get("thumbnailURL") or v_data.get("thumbnailURL") or "",
                "updatedAt":  now,
            })
        else:
            # Create new playlist
            pl_ref = db.collection("playlists").document()
            playlist_id = pl_ref.id
            pl_ref.set({
                "id":          playlist_id,
                "title":       title,
                "creatorId":   uid,
                "videoIds":    [video_id],
                "videoCount":  1,
                "isPublic":    is_public,
                "thumbnailURL": v_data.get("thumbnailURL") or "",
                "viewCount":   0,
                "createdAt":   now,
                "updatedAt":   now,
            })

        return https_fn.Response({"ok": True, "playlistId": playlist_id}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("playlist_add_video")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500,
                                 headers={"Access-Control-Allow-Origin": "*"})


@https_fn.on_request(region="us-east1")
def playlist_reorder(req: https_fn.Request) -> https_fn.Response:
    """
    Reorder videos in a playlist. Regenerates thumbnail from first video.
    POST { playlistId, videoIds: string[] }
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False, "error": "unauthenticated"}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body        = req.get_json(silent=True) or {}
        playlist_id = (body.get("playlistId") or "").strip()
        video_ids   = body.get("videoIds") or []

        if not playlist_id or not isinstance(video_ids, list):
            return https_fn.Response({"ok": False, "error": "missing fields"}, 400, headers=h)

        db  = _db()
        ref = db.collection("playlists").document(playlist_id)
        snap = ref.get()
        if not snap.exists:
            return https_fn.Response({"ok": False, "error": "not_found"}, 404, headers=h)
        if (snap.to_dict() or {}).get("creatorId") != uid:
            return https_fn.Response({"ok": False, "error": "forbidden"}, 403, headers=h)

        # Get thumbnail from first video
        thumb = ""
        if video_ids:
            try:
                v = db.collection("videos").document(video_ids[0]).get()
                thumb = (v.to_dict() or {}).get("thumbnailURL") or ""
            except Exception:
                pass

        ref.update({
            "videoIds":    video_ids,
            "videoCount":  len(video_ids),
            "thumbnailURL": thumb,
            "updatedAt":   firestore.SERVER_TIMESTAMP,
        })
        return https_fn.Response({"ok": True}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("playlist_reorder")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# 5. CREATOR AD REVENUE PAYOUT
# Scheduled monthly (1st of each month). Calculates each creator's earned
# ad revenue from their video view counts × RPM, then transfers to their
# Stripe Connect account. Same pattern as musicPayouts.
# MONEY NOTE: transactional per creator · idempotent · integer-cents.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="0 0 1 * *",  # cron: 1st of every month at midnight UTC
    region="us-east1",
    memory=options.MemoryOption.MB_512,
    max_instances=1,
    timeout_sec=540,
)
def monthly_ad_revenue_payout(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Pay out monthly ad revenue to all eligible creators via Stripe Connect.
    Eligibility: emailVerified=true, Stripe account connected, earned >= $10.
    """
    try:
        import stripe as _stripe_module

        stripe_key = os.environ.get("STRIPE_SECRET_KEY", "")
        if not stripe_key:
            logging.warning("[ad_payout] STRIPE_SECRET_KEY not set — skipping")
            return

        _stripe_module.api_key = stripe_key

        db    = _db()
        now   = datetime.now(timezone.utc)
        month = now.strftime("%Y%m")

        # Get all creators with analytics
        analytics_snap = (
            db.collection("creator_analytics")
            .where("revenueEstimate", ">=", 10.0)
            .limit(1000)
            .stream()
        )

        paid = 0
        for doc in analytics_snap:
            try:
                data       = doc.to_dict() or {}
                creator_id = doc.id
                revenue    = float(data.get("revenueEstimate") or 0)
                if revenue < 10.0:
                    continue

                # Idempotency: skip if already paid this month
                payout_ref = (
                    db.collection("creator_payouts")
                    .document(f"{creator_id}_{month}")
                )
                if payout_ref.get().exists:
                    continue

                # Check user eligibility
                user_snap = db.collection("users").document(creator_id).get()
                user_data = user_snap.to_dict() or {}
                if not user_data.get("isEmailVerified") and not user_data.get("emailVerified"):
                    continue

                # Get Stripe Connect account
                stripe_snap = db.collection("artist_stripe").document(creator_id).get()
                stripe_data = stripe_snap.to_dict() or {}
                stripe_acct = stripe_data.get("stripeAccountId") or ""
                if not stripe_acct:
                    # Creator not connected — accrue as owed
                    payout_ref.set({
                        "creatorId":    creator_id,
                        "month":        month,
                        "amountUSD":    revenue,
                        "amountCents":  int(revenue * 100),
                        "status":       "owed",
                        "reason":       "no_stripe_account",
                        "createdAt":    firestore.SERVER_TIMESTAMP,
                    })
                    continue

                amount_cents = int(revenue * 100)
                platform_cut = int(amount_cents * 0.30)  # MyChannel 30% rev share
                creator_cut  = amount_cents - platform_cut

                transfer = _stripe_module.Transfer.create(
                    amount=creator_cut,
                    currency="usd",
                    destination=stripe_acct,
                    transfer_group=f"ad_revenue_{month}",
                    description=f"MyChannel ad revenue — {now.strftime('%B %Y')}",
                    metadata={
                        "creatorId": creator_id,
                        "month": month,
                        "grossRevenue": str(revenue),
                        "platformFee": str(platform_cut / 100),
                    },
                )

                payout_ref.set({
                    "creatorId":       creator_id,
                    "month":           month,
                    "grossUSD":        revenue,
                    "platformCutUSD":  platform_cut / 100,
                    "creatorCutUSD":   creator_cut / 100,
                    "stripeTransferId": transfer.id,
                    "stripeAccountId": stripe_acct,
                    "status":          "paid",
                    "paidAt":          firestore.SERVER_TIMESTAMP,
                    "createdAt":       firestore.SERVER_TIMESTAMP,
                })

                # Notify creator
                db.collection("notifications").add({
                    "userId":  creator_id,
                    "type":    "payout_sent",
                    "title":   f"💰 ${creator_cut/100:.2f} payout sent!",
                    "message": f"Your {now.strftime('%B')} ad revenue has been transferred to your bank.",
                    "deepLink": "mychannel://studio/monetization",
                    "read":    False,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                })

                # Reset revenue estimate for next month
                db.collection("creator_analytics").document(creator_id).update({
                    "revenueEstimate": 0.0,
                    "lastPayoutAt":    firestore.SERVER_TIMESTAMP,
                    "updatedAt":       firestore.SERVER_TIMESTAMP,
                })

                paid += 1
                logging.info(f"[ad_payout] paid {creator_id}: ${creator_cut/100:.2f}")

            except Exception as e:
                logging.error(f"[ad_payout] failed for {doc.id}: {e}")

        logging.info(f"[ad_payout] monthly run complete — paid {paid} creators")

    except Exception:
        logging.exception("monthly_ad_revenue_payout")


# =============================================================================
# 6. VS MATCH LEADERBOARD (1st / 2nd / 3rd place ranking)
# Recalculates every hour. Ranks players by wins, win rate, and total wagered.
# Writes to leaderboards/{category} with top-100 ranked players.
# Also writes users/{uid}.vsMatchRank and vsMatchPosition for display.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 1 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_512,
    max_instances=1,
    timeout_sec=300,
)
def recalculate_vs_match_rankings(event: scheduler_fn.ScheduledEvent) -> None:
    """Recalculate VS Match leaderboard rankings — 1st, 2nd, 3rd place."""
    try:
        db  = _db()
        now = datetime.now(timezone.utc)

        # Get all completed matches in last 90 days
        cutoff = now - timedelta(days=90)
        matches_snap = (
            db.collection("versus_matches")
            .where("status", "==", "completed")
            .where("updatedAt", ">=", cutoff)
            .limit(10000)
            .stream()
        )

        # Aggregate stats per player
        player_stats: dict = {}

        for doc in matches_snap:
            d          = doc.to_dict() or {}
            winner_id  = d.get("winnerId") or ""
            c_id       = d.get("challengerId") or ""
            o_id       = d.get("opponentId")   or ""
            wager_cents = int(d.get("wagerAmount") or d.get("wagerAmountCents") or 0)
            category   = d.get("category") or "general"

            for uid in [c_id, o_id]:
                if not uid:
                    continue
                if uid not in player_stats:
                    player_stats[uid] = {
                        "wins": 0, "losses": 0, "totalWagered": 0,
                        "totalWon": 0, "categories": {}
                    }
                player_stats[uid]["totalWagered"] += wager_cents
                if category not in player_stats[uid]["categories"]:
                    player_stats[uid]["categories"][category] = {"wins": 0, "losses": 0}

                if uid == winner_id:
                    player_stats[uid]["wins"]  += 1
                    player_stats[uid]["totalWon"] += wager_cents
                    player_stats[uid]["categories"][category]["wins"] += 1
                else:
                    player_stats[uid]["losses"] += 1
                    player_stats[uid]["categories"][category]["losses"] += 1

        # Score formula: wins * 100 + win_rate * 50 + log(totalWagered+1) * 10
        import math

        def _score(stats: dict) -> float:
            total = stats["wins"] + stats["losses"]
            rate  = stats["wins"] / total if total > 0 else 0
            return (stats["wins"] * 100 +
                    rate * 50 +
                    math.log1p(stats["totalWagered"] / 100) * 10)

        # Build ranked list
        ranked = sorted(
            [{"uid": uid, "score": _score(s), **s}
             for uid, s in player_stats.items()],
            key=lambda x: x["score"], reverse=True
        )

        # Fetch display names for top 100
        top100 = ranked[:100]
        batch  = db.batch()

        leaderboard_entries = []
        for position, entry in enumerate(top100, start=1):
            uid      = entry["uid"]
            wins     = entry["wins"]
            losses   = entry["losses"]
            total    = wins + losses
            win_rate = round(wins / total * 100, 1) if total > 0 else 0

            try:
                u_snap = db.collection("users").document(uid).get()
                u_data = u_snap.to_dict() or {}
                display_name = u_data.get("displayName") or u_data.get("username") or "Player"
                avatar       = u_data.get("profileImageURL") or ""
            except Exception:
                display_name, avatar = "Player", ""

            medal = "🥇" if position == 1 else "🥈" if position == 2 else "🥉" if position == 3 else ""

            entry_data = {
                "position":    position,
                "userId":      uid,
                "displayName": display_name,
                "avatarURL":   avatar,
                "wins":        wins,
                "losses":      losses,
                "winRate":     win_rate,
                "totalWageredCents": entry["totalWagered"],
                "score":       round(entry["score"], 2),
                "medal":       medal,
                "updatedAt":   firestore.SERVER_TIMESTAMP,
            }
            leaderboard_entries.append(entry_data)

            # Update user's rank on their profile
            batch.update(db.collection("users").document(uid), {
                "vsMatchRank":     position,
                "vsMatchWins":     wins,
                "vsMatchLosses":   losses,
                "vsMatchWinRate":  win_rate,
                "vsMatchScore":    round(entry["score"], 2),
                "vsMatchMedal":    medal,
                "updatedAt":       firestore.SERVER_TIMESTAMP,
            })

        # Write leaderboard doc (paginated by 100)
        batch.set(db.collection("leaderboards").document("vs_match_overall"), {
            "category":    "overall",
            "entries":     leaderboard_entries,
            "totalPlayers": len(player_stats),
            "updatedAt":   firestore.SERVER_TIMESTAMP,
        })

        batch.commit()
        logging.info(f"[rankings] recalculated {len(player_stats)} players, top {len(top100)} ranked")

    except Exception:
        logging.exception("recalculate_vs_match_rankings")


# =============================================================================
# 7. VS MATCH MATCHMAKING
# Called by iOS/Android/Web to find or create a match.
# POST { wagerCents, category, userId }
# Looks for an open challenge in the same wager range, or creates one.
# Returns { matched: true, matchId } or { matched: false, challengeId }
# =============================================================================

@https_fn.on_request(region="us-east1")
def vs_match_find_opponent(req: https_fn.Request) -> https_fn.Response:
    """
    Matchmaking: find an existing open challenge or create a new one.
    Matches by wager range (±20%) and optional category.
    MONEY NOTE: no money moves here — escrow_create fires when match goes active.
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"matched": False, "error": "unauthenticated"}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body         = req.get_json(silent=True) or {}
        wager_cents  = int(body.get("wagerCents") or 0)
        category     = (body.get("category") or "general").strip()

        if wager_cents <= 0:
            return https_fn.Response({"matched": False, "error": "invalid_wager"}, 400, headers=h)

        # Compliance check before matchmaking
        user_snap = _db().collection("users").document(uid).get()
        err = _compliance_check(user_snap.to_dict() or {}, wager_cents)
        if err:
            return https_fn.Response({"matched": False, "error": err}, 200, headers=h)

        db  = _db()
        now = firestore.SERVER_TIMESTAMP

        # Look for open challenges: same category, wager within ±20%, not by self
        low  = int(wager_cents * 0.80)
        high = int(wager_cents * 1.20)

        open_challenges = (
            db.collection("versus_matches")
            .where("status", "==", "pending")
            .where("category", "==", category)
            .where("wagerAmount", ">=", low)
            .where("wagerAmount", "<=", high)
            .limit(20)
            .stream()
        )

        for challenge_doc in open_challenges:
            c_data = challenge_doc.to_dict() or {}
            if c_data.get("challengerId") == uid:
                continue  # can't match yourself
            if c_data.get("opponentId"):
                continue  # already has opponent

            # Found a match — accept it
            challenge_doc.reference.update({
                "opponentId": uid,
                "status":     "active",
                "acceptedAt": now,
                "updatedAt":  now,
            })

            return https_fn.Response({
                "matched":   True,
                "matchId":   challenge_doc.id,
                "wagerCents": c_data.get("wagerAmount") or wager_cents,
                "role":      "opponent",
            }, 200, headers={"Access-Control-Allow-Origin": "*"})

        # No match found — create open challenge
        match_ref = db.collection("versus_matches").document()
        match_ref.set({
            "id":           match_ref.id,
            "challengerId": uid,
            "opponentId":   None,
            "wagerAmount":  wager_cents,
            "category":     category,
            "division":     _get_division(wager_cents),
            "status":       "pending",
            "escrowStatus": "none",
            "createdAt":    now,
            "updatedAt":    now,
            "expiresAt":    firestore.SERVER_TIMESTAMP,  # TTL set by cleanup job
        })

        return https_fn.Response({
            "matched":    False,
            "challengeId": match_ref.id,
            "role":       "challenger",
            "message":    "Challenge posted. Waiting for an opponent.",
        }, 200, headers={"Access-Control-Allow-Origin": "*"})

    except Exception:
        logging.exception("vs_match_find_opponent")
        return https_fn.Response({"matched": False, "error": "server_error"}, 500,
                                 headers={"Access-Control-Allow-Origin": "*"})


# =============================================================================
# 8. LIVE BETTING
# Allows viewers to place wagers on the outcome of a live VS Match stream.
# POST { streamId, matchId, prediction (challengerWins|opponentWins), wagerCents }
# Deducts from wallet, records bet, settles automatically when match completes.
# MONEY NOTE: transactional · compliance-checked · idempotent via betId.
# =============================================================================

@https_fn.on_request(region="us-east1")
def place_live_bet(req: https_fn.Request) -> https_fn.Response:
    """
    Place a real-money bet on a live VS Match outcome.
    Wager is locked immediately; settled when the match completes.
    MONEY NOTE: compliance-gated · transactional · idempotent.
    """
    h = {"Access-Control-Allow-Origin": "*",
         "Access-Control-Allow-Headers": "Content-Type,Authorization"}
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=h)
    try:
        auth = (req.headers.get("Authorization") or "").strip()
        if not auth.lower().startswith("bearer "):
            return https_fn.Response({"ok": False, "error": "unauthenticated"}, 401, headers=h)
        uid = admin_auth.verify_id_token(auth.split(" ", 1)[1].strip())["uid"]

        body        = req.get_json(silent=True) or {}
        match_id    = (body.get("matchId") or "").strip()
        prediction  = (body.get("prediction") or "").strip()
        wager_cents = int(body.get("wagerCents") or 0)
        idem_key    = (body.get("idempotencyKey") or "").strip()

        if not match_id or prediction not in ("challengerWins", "opponentWins") or wager_cents <= 0:
            return https_fn.Response({"ok": False, "error": "invalid_input"}, 400, headers=h)

        # Min $1 bet
        if wager_cents < 100:
            return https_fn.Response({"ok": False, "error": "minimum_100_cents"}, 200, headers=h)

        db = _db()

        # Idempotency
        if idem_key:
            snap = db.collection("live_bet_idempotency").document(idem_key).get()
            if snap.exists:
                return https_fn.Response(
                    {"ok": True, "betId": (snap.to_dict() or {}).get("betId","")},
                    200, headers={"Access-Control-Allow-Origin": "*"})

        # Compliance check
        user_snap = db.collection("users").document(uid).get()
        err = _compliance_check(user_snap.to_dict() or {}, wager_cents)
        if err:
            return https_fn.Response({"ok": False, "error": err}, 200, headers=h)

        # Verify match is active and in-progress (live betting window)
        match_snap = db.collection("versus_matches").document(match_id).get()
        if not match_snap.exists:
            return https_fn.Response({"ok": False, "error": "match_not_found"}, 404, headers=h)
        match_data = match_snap.to_dict() or {}
        if match_data.get("status") not in ("active", "in_progress"):
            return https_fn.Response({"ok": False, "error": "betting_closed"}, 200, headers=h)
        if match_data.get("liveBettingClosed"):
            return https_fn.Response({"ok": False, "error": "betting_closed"}, 200, headers=h)
        # Can't bet on yourself
        if uid in (match_data.get("challengerId"), match_data.get("opponentId")):
            return https_fn.Response({"ok": False, "error": "cannot_bet_on_own_match"}, 200, headers=h)

        bet_ref = db.collection("live_bets").document()
        bet_id  = bet_ref.id

        @firestore.transactional
        def _place_bet(tx):
            w_ref  = db.collection("vs_match_wallets").document(uid)
            w_data = w_ref.get(transaction=tx).to_dict() or {}
            bal    = int(w_data.get("availableBalance") or 0)
            if bal < wager_cents:
                raise ValueError("insufficient_funds")
            now = firestore.SERVER_TIMESTAMP
            tx.update(w_ref, {
                "availableBalance": firestore.Increment(-wager_cents),
                "pendingBalance":   firestore.Increment(wager_cents),
                "updatedAt": now,
            })
            tx.set(bet_ref, {
                "id":          bet_id,
                "userId":      uid,
                "matchId":     match_id,
                "prediction":  prediction,
                "wagerCents":  wager_cents,
                "status":      "pending",
                "createdAt":   now,
                "updatedAt":   now,
            })
            tx.set(db.collection("vs_match_transactions").document(), {
                "userId":      uid,
                "matchId":     match_id,
                "type":        "live_bet",
                "amount":      -wager_cents,
                "status":      "completed",
                "description": f"Live bet — {prediction}",
                "createdAt":   now,
            })

        _place_bet(db.transaction())

        if idem_key:
            db.collection("live_bet_idempotency").document(idem_key).set({
                "betId": bet_id, "uid": uid, "matchId": match_id,
                "createdAt": firestore.SERVER_TIMESTAMP,
            })

        return https_fn.Response({"ok": True, "betId": bet_id}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except ValueError as ve:
        return https_fn.Response({"ok": False, "error": str(ve)}, 200,
                                 headers={"Access-Control-Allow-Origin": "*"})
    except Exception:
        logging.exception("place_live_bet")
        return https_fn.Response({"ok": False, "error": "server_error"}, 500,
                                 headers={"Access-Control-Allow-Origin": "*"})


@firestore_fn.on_document_updated(
    document="versus_matches/{matchId}",
    region="us-east1",
)
def settle_live_bets_on_match_complete(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """
    Settle all live bets when a VS Match completes.
    Winners get 1.8× their wager (house edge 10%). Losers forfeit.
    MONEY NOTE: transactional per bet · idempotent (status check).
    """
    try:
        before = event.data.before.to_dict() or {}
        after  = event.data.after.to_dict()  or {}
        if before.get("status") == after.get("status"): return
        if after.get("status") != "completed": return

        match_id  = event.params["matchId"]
        winner_id = after.get("winnerId") or ""
        if not winner_id: return

        challenger_id = after.get("challengerId") or ""
        opponent_id   = after.get("opponentId")   or ""
        winning_prediction = "challengerWins" if winner_id == challenger_id else "opponentWins"

        db = _db()

        # Get all pending bets on this match
        bets_snap = (
            db.collection("live_bets")
            .where("matchId", "==", match_id)
            .where("status", "==", "pending")
            .stream()
        )

        PAYOUT_MULTIPLIER = 1.8  # 1.8× for winners (10% house edge)

        for bet_doc in bets_snap:
            bet   = bet_doc.to_dict() or {}
            uid   = bet.get("userId") or ""
            wager = int(bet.get("wagerCents") or 0)
            pred  = bet.get("prediction") or ""

            if not uid or wager <= 0:
                continue

            is_winner  = pred == winning_prediction
            payout     = int(wager * PAYOUT_MULTIPLIER) if is_winner else 0
            net_change = payout - wager  # positive for winners, -wager for losers

            try:
                wallet_ref = db.collection("vs_match_wallets").document(uid)
                now = firestore.SERVER_TIMESTAMP

                @firestore.transactional
                def _settle_bet(tx, _wager=wager, _payout=payout, _net=net_change):
                    tx.update(wallet_ref, {
                        "availableBalance": firestore.Increment(_payout),
                        "pendingBalance":   firestore.Increment(-_wager),
                        "updatedAt": now,
                    })

                _settle_bet(db.transaction())

                bet_doc.reference.update({
                    "status":    "won" if is_winner else "lost",
                    "payout":    payout,
                    "settledAt": now,
                    "updatedAt": now,
                })

                # Notify bettor
                db.collection("notifications").add({
                    "userId": uid,
                    "type":   "live_bet_settled",
                    "title":  f"You {'won' if is_winner else 'lost'} your live bet!",
                    "message": (f"You won ${payout/100:.2f}!" if is_winner
                                else f"You lost ${wager/100:.2f}."),
                    "matchId": match_id,
                    "read":    False,
                    "createdAt": now,
                })

            except Exception as e:
                logging.error(f"[live_bet_settle] failed for bet {bet_doc.id}: {e}")

        logging.info(f"[live_bet_settle] settled bets for match {match_id}")

    except Exception:
        logging.exception("settle_live_bets_on_match_complete")


# =============================================================================
# 9. FLICKS / SHORTS RECOMMENDATION ENGINE
# Separate from the long-form recommendation engine.
# Runs every 30 minutes. Builds a personalized Flicks feed per active user
# based on: watch-through rate, likes, follows, category affinity.
# Writes to user_flicks_feed/{uid} — read directly by the Flicks tab.
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 30 minutes",
    region="us-east1",
    memory=options.MemoryOption.GB_1,
    max_instances=1,
    timeout_sec=540,
)
def compute_flicks_recommendations(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Build personalized Flicks (Shorts) feeds for active users.
    Uses: watch history, likes, creator subscriptions, trending scores.
    """
    try:
        db  = _db()
        now = datetime.now(timezone.utc)
        active_cutoff = now - timedelta(hours=24)

        # Get users active in last 24h via Flick events
        recent_events = (
            db.collection_group("events")
            .where("type", "in", ["view", "like"])
            .where("createdAt", ">=", active_cutoff)
            .limit(3000)
            .stream()
        )

        active_uids: set = set()
        user_affinity: dict = {}  # uid → { category: score }

        for ev in recent_events:
            ed  = ev.to_dict() or {}
            uid = ed.get("userId") or ""
            if not uid or uid.startswith("anon:"):
                continue
            active_uids.add(uid)
            # Build category affinity from flick events
            path_parts = ev.reference.path.split("/")
            flick_id = path_parts[1] if len(path_parts) >= 4 else ""
            if flick_id:
                try:
                    f = db.collection("flicks").document(flick_id).get()
                    cat = (f.to_dict() or {}).get("category") or "entertainment"
                    if uid not in user_affinity:
                        user_affinity[uid] = {}
                    w = 2.0 if ed.get("type") == "like" else 1.0
                    user_affinity[uid][cat] = user_affinity[uid].get(cat, 0) + w
                except Exception:
                    pass

        import math as _math

        logging.info(f"[flicks_recs] computing for {len(active_uids)} active users")

        for uid in list(active_uids)[:500]:
            try:
                affinities = user_affinity.get(uid, {})
                top_category = max(affinities, key=affinities.get) if affinities else "entertainment"

                # Get already-seen flick IDs (last 200)
                seen_snap = (
                    db.collection("users").document(uid)
                    .collection("watchHistory")
                    .order_by("watchedAt",
                               direction=firestore.Query.DESCENDING)
                    .limit(200)
                    .stream()
                )
                seen_ids = {s.id for s in seen_snap}

                # Candidate flicks: top category trending, then global trending
                candidates: list = []
                for cat_filter in [top_category, None]:
                    q = db.collection("flicks").where("isPublic", "==", True)
                    if cat_filter:
                        q = q.where("category", "==", cat_filter)
                    q = q.order_by("trendingScore",
                                    direction=firestore.Query.DESCENDING).limit(60)
                    for f_doc in q.stream():
                        if f_doc.id not in seen_ids:
                            fd = f_doc.to_dict() or {}
                            score = float(fd.get("trendingScore") or 0)
                            # Boost for category affinity
                            cat   = fd.get("category") or "entertainment"
                            boost = affinities.get(cat, 0) * 5
                            candidates.append({
                                "flickId":      f_doc.id,
                                "score":        score + boost,
                                "category":     cat,
                                "thumbnailURL": fd.get("thumbnailURL") or "",
                                "videoURL":     fd.get("videoURL") or "",
                                "creatorId":    fd.get("creatorId") or "",
                                "likeCount":    fd.get("likeCount") or 0,
                                "viewCount":    fd.get("viewCount") or 0,
                            })
                        if len(candidates) >= 100:
                            break
                    if len(candidates) >= 100:
                        break

                # Deduplicate and rank
                seen_fids: set = set()
                ranked: list = []
                for c in sorted(candidates, key=lambda x: x["score"], reverse=True):
                    if c["flickId"] not in seen_fids:
                        seen_fids.add(c["flickId"])
                        ranked.append(c)
                    if len(ranked) >= 50:
                        break

                # Write feed
                db.collection("user_flicks_feed").document(uid).set({
                    "userId":          uid,
                    "feed":            ranked,
                    "topCategory":     top_category,
                    "generatedAt":     firestore.SERVER_TIMESTAMP,
                    "candidateCount":  len(candidates),
                })

            except Exception as e:
                logging.exception(f"[flicks_recs] uid {uid}: {e}")

        logging.info(f"[flicks_recs] done for {len(active_uids)} users")

    except Exception:
        logging.exception("compute_flicks_recommendations")


# =============================================================================
# BONUS: EXPIRED CHALLENGE CLEANUP
# Removes VS Match challenges that haven't been accepted in 24 hours
# and cancels the escrow (trigger fires escrow_refund automatically).
# =============================================================================

@scheduler_fn.on_schedule(
    schedule="every 1 hours",
    region="us-east1",
    memory=options.MemoryOption.MB_256,
    max_instances=1,
)
def cleanup_expired_challenges(event: scheduler_fn.ScheduledEvent) -> None:
    """Cancel VS Match challenges open > 24 hours with no opponent."""
    try:
        db     = _db()
        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        snaps  = (
            db.collection("versus_matches")
            .where("status", "==", "pending")
            .where("createdAt", "<=", cutoff)
            .limit(200)
            .stream()
        )
        batch = db.batch()
        n = 0
        for doc in snaps:
            batch.update(doc.reference, {
                "status":       "expired",
                "cancelReason": "no_opponent_24h",
                "updatedAt":    firestore.SERVER_TIMESTAMP,
            })
            n += 1
            if n % 499 == 0:
                batch.commit()
                batch = db.batch()
        batch.commit()
        if n:
            logging.info(f"[challenge_cleanup] expired {n} challenges")
    except Exception:
        logging.exception("cleanup_expired_challenges")


# =============================================================================
# BONUS: LIVE BET POOL STATS (real-time odds display)
# Called by clients to get current bet pool for a match.
# GET ?matchId=xxx  →  { total, challengerPool, opponentPool, challengerOdds }
# =============================================================================

@https_fn.on_request(region="us-east1")
def get_live_bet_pool(req: https_fn.Request) -> https_fn.Response:
    """Return current betting pool stats for a live match."""
    h = {"Access-Control-Allow-Origin": "*",
         "Cache-Control": "no-store"}
    try:
        match_id = req.args.get("matchId") or ""
        if not match_id:
            return https_fn.Response({"error": "missing matchId"}, 400, headers=h)

        db    = _db()
        bets  = (
            db.collection("live_bets")
            .where("matchId", "==", match_id)
            .where("status", "==", "pending")
            .stream()
        )

        challenger_pool = 0
        opponent_pool   = 0
        total_bets      = 0

        for bet in bets:
            bd = bet.to_dict() or {}
            w  = int(bd.get("wagerCents") or 0)
            if bd.get("prediction") == "challengerWins":
                challenger_pool += w
            else:
                opponent_pool += w
            total_bets += 1

        total = challenger_pool + opponent_pool
        c_odds = round(total / challenger_pool, 2) if challenger_pool > 0 else 0
        o_odds = round(total / opponent_pool,   2) if opponent_pool   > 0 else 0

        return https_fn.Response({
            "matchId":        match_id,
            "totalCents":     total,
            "challengerPoolCents": challenger_pool,
            "opponentPoolCents":   opponent_pool,
            "challengerOdds": c_odds,
            "opponentOdds":   o_odds,
            "totalBets":      total_bets,
        }, 200, headers={"Access-Control-Allow-Origin": "*",
                         "Cache-Control": "no-store"})
    except Exception:
        logging.exception("get_live_bet_pool")
        return https_fn.Response({"error": "server_error"}, 500, headers=h)
