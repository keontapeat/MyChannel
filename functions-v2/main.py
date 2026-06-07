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
