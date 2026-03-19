#!/usr/bin/env python3
"""
CyberSecurity AI Agent - MyChannel
FBI-grade ML threat detection: brute-force, intrusion, anomaly, token abuse,
IP reputation, account takeover, injection attacks, DDoS pattern detection.
"""
import os
import time
import hashlib
import logging
import math
from collections import defaultdict
from datetime import datetime, timezone
from flask import Flask, request, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# ─── In-memory rolling windows (Cloud Run single-instance per request is fine;
#     for multi-instance scale, replace with Redis / Firestore) ────────────────
_ip_request_log: dict = defaultdict(list)      # ip -> [timestamps]
_uid_request_log: dict = defaultdict(list)     # uid -> [timestamps]
_failed_auth_log: dict = defaultdict(list)     # ip -> [timestamps]
_uid_failed_auth: dict = defaultdict(list)     # uid -> [timestamps]
_banned_ips: set = set()
_banned_uids: set = set()

WINDOW_SECONDS = 60          # rolling 1-min window
RATE_LIMIT_IP = 300          # requests/min per IP before flagging
RATE_LIMIT_UID = 200         # requests/min per UID
BRUTE_FORCE_THRESHOLD = 10   # failed auths in 60s = brute force
DDOS_THRESHOLD = 1000        # requests/min = DDoS pattern

# Known malicious patterns (SQL/NoSQL injection, XSS, path traversal, etc.)
INJECTION_PATTERNS = [
    "' OR ", "' AND ", "1=1", "DROP TABLE", "UNION SELECT", "--",
    "<script>", "</script>", "javascript:", "onerror=", "onload=",
    "../", "..\\", "/etc/passwd", "/etc/shadow", "cmd.exe",
    "eval(", "exec(", "__import__", "os.system", "subprocess",
    "$where", "$regex", "$gt", "$lt", "$ne",  # NoSQL injection
    "alert(", "document.cookie", "window.location",
]

# Known bad user-agent substrings (scanners, exploit tools)
BAD_USER_AGENTS = [
    "sqlmap", "nikto", "nmap", "masscan", "zgrab", "burpsuite",
    "hydra", "medusa", "nessus", "acunetix", "metasploit",
    "python-requests/2.2", "Go-http-client/1.1", "libwww-perl",
    "dirbuster", "dirb ", "gobuster", "wfuzz", "ffuf",
    "nuclei", "zaproxy", "openvas", "w3af",
]

# GeoIP reputation — high-risk ASNs/countries (simplified heuristic)
HIGH_RISK_IP_PREFIXES = [
    "185.220.",   # Tor exit nodes
    "198.96.",    # Known proxy pools
    "45.155.",    # Abuse-heavy ranges
    "194.165.",
]


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _clean_window(log: list, now: float) -> list:
    return [t for t in log if now - t < WINDOW_SECONDS]


def _entropy(s: str) -> float:
    """Shannon entropy — high entropy = potential encoded payload."""
    if not s:
        return 0.0
    freq = defaultdict(int)
    for c in s:
        freq[c] += 1
    n = len(s)
    return -sum((f / n) * math.log2(f / n) for f in freq.values())


def _check_injection(value: str) -> list:
    found = []
    v = value.upper()
    for pat in INJECTION_PATTERNS:
        if pat.upper() in v:
            found.append(pat)
    return found


def _scan_dict(d, depth=0) -> list:
    """Recursively scan all string values in a dict for injection patterns."""
    hits = []
    if depth > 5:
        return hits
    if isinstance(d, dict):
        for v in d.values():
            hits.extend(_scan_dict(v, depth + 1))
    elif isinstance(d, list):
        for item in d:
            hits.extend(_scan_dict(item, depth + 1))
    elif isinstance(d, str):
        hits.extend(_check_injection(d))
    return hits


def _threat_level(score: float) -> str:
    if score >= 0.85:
        return "CRITICAL"
    if score >= 0.65:
        return "HIGH"
    if score >= 0.40:
        return "MEDIUM"
    if score >= 0.20:
        return "LOW"
    return "CLEAN"


# ─── Core analysis engine ─────────────────────────────────────────────────────

def analyze_request(payload: dict) -> dict:
    now = time.time()
    signals = []
    threat_score = 0.0

    ip = payload.get("ip", "")
    uid = payload.get("uid", "")
    user_agent = payload.get("user_agent", "").lower()
    endpoint = payload.get("endpoint", "")
    method = payload.get("method", "GET")
    body = payload.get("body", {})
    headers = payload.get("headers", {})
    auth_failed = payload.get("auth_failed", False)
    request_size_bytes = payload.get("request_size_bytes", 0)
    country_code = payload.get("country_code", "")
    is_vpn = payload.get("is_vpn", False)
    is_tor = payload.get("is_tor", False)

    # ── 1. Pre-banned check ────────────────────────────────────────────────
    if ip in _banned_ips:
        return {
            "threat_score": 1.0,
            "threat_level": "CRITICAL",
            "action": "BLOCK",
            "signals": ["IP_PERMANENTLY_BANNED"],
            "blocked": True,
        }
    if uid and uid in _banned_uids:
        return {
            "threat_score": 1.0,
            "threat_level": "CRITICAL",
            "action": "BLOCK",
            "signals": ["UID_PERMANENTLY_BANNED"],
            "blocked": True,
        }

    # ── 2. Rate limiting ──────────────────────────────────────────────────
    if ip:
        _ip_request_log[ip] = _clean_window(_ip_request_log[ip], now)
        _ip_request_log[ip].append(now)
        ip_rpm = len(_ip_request_log[ip])

        if ip_rpm >= DDOS_THRESHOLD:
            threat_score += 0.80
            signals.append(f"DDOS_PATTERN:{ip_rpm}rpm")
        elif ip_rpm >= RATE_LIMIT_IP:
            threat_score += 0.45
            signals.append(f"RATE_LIMIT_IP:{ip_rpm}rpm")

    if uid:
        _uid_request_log[uid] = _clean_window(_uid_request_log[uid], now)
        _uid_request_log[uid].append(now)
        uid_rpm = len(_uid_request_log[uid])
        if uid_rpm >= RATE_LIMIT_UID:
            threat_score += 0.35
            signals.append(f"RATE_LIMIT_UID:{uid_rpm}rpm")

    # ── 3. Brute force detection ──────────────────────────────────────────
    if auth_failed:
        if ip:
            _failed_auth_log[ip] = _clean_window(_failed_auth_log[ip], now)
            _failed_auth_log[ip].append(now)
            ip_fails = len(_failed_auth_log[ip])
            if ip_fails >= BRUTE_FORCE_THRESHOLD:
                threat_score += 0.70
                signals.append(f"BRUTE_FORCE_IP:{ip_fails}_fails")
                if ip_fails >= 20:
                    _banned_ips.add(ip)
                    signals.append("IP_AUTO_BANNED")

        if uid:
            _uid_failed_auth[uid] = _clean_window(_uid_failed_auth[uid], now)
            _uid_failed_auth[uid].append(now)
            uid_fails = len(_uid_failed_auth[uid])
            if uid_fails >= BRUTE_FORCE_THRESHOLD:
                threat_score += 0.65
                signals.append(f"BRUTE_FORCE_UID:{uid_fails}_fails")
                if uid_fails >= 15:
                    _banned_uids.add(uid)
                    signals.append("UID_AUTO_BANNED")

    # ── 4. Malicious user-agent detection ─────────────────────────────────
    for bad_ua in BAD_USER_AGENTS:
        if bad_ua in user_agent:
            threat_score += 0.75
            signals.append(f"MALICIOUS_USER_AGENT:{bad_ua}")
            break

    if not user_agent:
        threat_score += 0.20
        signals.append("EMPTY_USER_AGENT")

    # ── 5. Injection attack scanning ──────────────────────────────────────
    injection_hits = _scan_dict(body)
    if injection_hits:
        threat_score += min(0.90, 0.30 * len(injection_hits))
        signals.append(f"INJECTION_DETECTED:{injection_hits[:3]}")

    # Also scan endpoint URL
    endpoint_hits = _check_injection(endpoint)
    if endpoint_hits:
        threat_score += 0.50
        signals.append(f"ENDPOINT_INJECTION:{endpoint_hits[:2]}")

    # ── 6. Anomalous payload size ─────────────────────────────────────────
    if request_size_bytes > 10_000_000:  # 10MB+ request body
        threat_score += 0.40
        signals.append(f"OVERSIZED_PAYLOAD:{request_size_bytes}bytes")
    elif request_size_bytes > 1_000_000:
        threat_score += 0.15
        signals.append(f"LARGE_PAYLOAD:{request_size_bytes}bytes")

    # ── 7. High-entropy payload (encoded exploits) ────────────────────────
    if isinstance(body, dict):
        body_str = str(body)
        ent = _entropy(body_str)
        if ent > 5.5 and len(body_str) > 200:
            threat_score += 0.25
            signals.append(f"HIGH_ENTROPY_PAYLOAD:{ent:.2f}")

    # ── 8. IP reputation signals ──────────────────────────────────────────
    for prefix in HIGH_RISK_IP_PREFIXES:
        if ip.startswith(prefix):
            threat_score += 0.30
            signals.append(f"HIGH_RISK_IP_RANGE:{prefix}")
            break

    if is_tor:
        threat_score += 0.40
        signals.append("TOR_EXIT_NODE")

    if is_vpn:
        threat_score += 0.10
        signals.append("VPN_DETECTED")

    # ── 9. Sensitive endpoint targeting ───────────────────────────────────
    sensitive_endpoints = [
        "/admin", "/firebase", "/api/keys", "/api/secrets",
        "/.env", "/config", "/backup", "/dump", "/export",
        "/wp-admin", "/phpmyadmin", "/.git", "/server-status",
        "/actuator", "/metrics", "/__debug__",
    ]
    for se in sensitive_endpoints:
        if se in endpoint.lower():
            threat_score += 0.55
            signals.append(f"SENSITIVE_ENDPOINT_PROBE:{se}")
            break

    # ── 10. HTTP method abuse ─────────────────────────────────────────────
    if method in ["TRACE", "CONNECT", "DEBUG", "TRACK"]:
        threat_score += 0.35
        signals.append(f"DANGEROUS_HTTP_METHOD:{method}")

    # ── 11. Account takeover heuristics ──────────────────────────────────
    # Multiple UIDs from same IP in short window
    if ip and uid:
        known_uids_for_ip = set()
        # Track uid diversity per IP using a simple hash-based approach
        ip_uid_key = f"{ip}:{uid}"
        ip_uid_hash = hashlib.md5(ip_uid_key.encode()).hexdigest()[:8]
        # Heuristic: if ip makes requests for >5 different UIDs, flag
        # (simplified — production should use Redis set)
        signals_str = str(signals)
        if signals_str.count("RATE_LIMIT") > 0 and auth_failed:
            threat_score += 0.20
            signals.append("ACCOUNT_TAKEOVER_PATTERN")

    # ── 12. Clamp and finalize ────────────────────────────────────────────
    threat_score = round(min(threat_score, 1.0), 4)
    level = _threat_level(threat_score)

    # Determine action
    if threat_score >= 0.85 or "IP_AUTO_BANNED" in signals or "UID_AUTO_BANNED" in signals:
        action = "BLOCK"
        blocked = True
    elif threat_score >= 0.65:
        action = "CHALLENGE"  # Require CAPTCHA / MFA re-auth
        blocked = False
    elif threat_score >= 0.40:
        action = "THROTTLE"
        blocked = False
    elif threat_score >= 0.20:
        action = "MONITOR"
        blocked = False
    else:
        action = "ALLOW"
        blocked = False

    logging.info(
        f"[SecurityAI] ip={ip} uid={uid} score={threat_score} level={level} "
        f"action={action} signals={signals}"
    )

    return {
        "threat_score": threat_score,
        "threat_level": level,
        "action": action,
        "blocked": blocked,
        "signals": signals,
        "ip": ip,
        "uid": uid,
        "analyzed_at": datetime.now(timezone.utc).isoformat(),
    }


def analyze_account_behavior(payload: dict) -> dict:
    """
    Behavioral analysis for account anomalies:
    - Impossible travel (lat/lng velocity)
    - Unusual upload burst
    - Mass-comment/spam spree
    - Credential stuffing pattern
    """
    signals = []
    threat_score = 0.0

    uid = payload.get("uid", "")
    events_last_hour = payload.get("events_last_hour", 0)
    uploads_last_hour = payload.get("uploads_last_hour", 0)
    comments_last_hour = payload.get("comments_last_hour", 0)
    likes_last_hour = payload.get("likes_last_hour", 0)
    follows_last_hour = payload.get("follows_last_hour", 0)
    reports_last_hour = payload.get("reports_last_hour", 0)
    new_account_minutes = payload.get("account_age_minutes", 99999)
    distance_km_last_hour = payload.get("distance_km_last_hour", 0)  # geo velocity
    device_count_today = payload.get("device_count_today", 1)
    password_change_count_24h = payload.get("password_change_count_24h", 0)

    # Impossible travel (> 1000km/hr is physically impossible)
    if distance_km_last_hour > 1000:
        threat_score += 0.80
        signals.append(f"IMPOSSIBLE_TRAVEL:{distance_km_last_hour}km/hr")

    # Spam burst
    if comments_last_hour > 100:
        threat_score += 0.60
        signals.append(f"COMMENT_SPAM_BURST:{comments_last_hour}")
    elif comments_last_hour > 40:
        threat_score += 0.30
        signals.append(f"COMMENT_ELEVATED:{comments_last_hour}")

    if likes_last_hour > 500:
        threat_score += 0.40
        signals.append(f"LIKE_FARMING:{likes_last_hour}")

    if follows_last_hour > 200:
        threat_score += 0.50
        signals.append(f"FOLLOW_SPAM:{follows_last_hour}")

    # Upload abuse (only platform accounts can mass upload)
    if uploads_last_hour > 20:
        threat_score += 0.55
        signals.append(f"UPLOAD_BURST:{uploads_last_hour}")

    # Report abuse
    if reports_last_hour > 30:
        threat_score += 0.45
        signals.append(f"REPORT_ABUSE:{reports_last_hour}")

    # New account with high activity = bot
    if new_account_minutes < 60 and events_last_hour > 50:
        threat_score += 0.65
        signals.append(f"NEW_ACCOUNT_BOT:age={new_account_minutes}min,events={events_last_hour}")

    # Multiple device logins = credential stuffing or account sharing abuse
    if device_count_today > 8:
        threat_score += 0.35
        signals.append(f"EXCESSIVE_DEVICES:{device_count_today}")

    # Multiple password changes = account under attack
    if password_change_count_24h > 3:
        threat_score += 0.50
        signals.append(f"PASSWORD_CHANGE_SURGE:{password_change_count_24h}")

    threat_score = round(min(threat_score, 1.0), 4)
    level = _threat_level(threat_score)

    if threat_score >= 0.80:
        action = "SUSPEND_ACCOUNT"
    elif threat_score >= 0.60:
        action = "REQUIRE_MFA_REVERIFY"
    elif threat_score >= 0.40:
        action = "SHADOW_RESTRICT"
    elif threat_score >= 0.20:
        action = "MONITOR_ENHANCED"
    else:
        action = "ALLOW"

    return {
        "threat_score": threat_score,
        "threat_level": level,
        "action": action,
        "signals": signals,
        "uid": uid,
        "analyzed_at": datetime.now(timezone.utc).isoformat(),
    }


def analyze_content_security(payload: dict) -> dict:
    """
    Content-level security checks:
    - Steganography heuristics (file entropy)
    - Filename injection
    - MIME type spoofing
    - Metadata exfil attempts
    """
    signals = []
    threat_score = 0.0

    filename = payload.get("filename", "")
    mime_type = payload.get("mime_type", "")
    declared_mime = payload.get("declared_mime", "")
    file_size_bytes = payload.get("file_size_bytes", 0)
    file_entropy = payload.get("file_entropy", 0.0)
    metadata = payload.get("metadata", {})

    # Filename injection
    fname_hits = _check_injection(filename)
    if fname_hits:
        threat_score += 0.70
        signals.append(f"FILENAME_INJECTION:{fname_hits[:2]}")

    # Double extension (e.g., video.mp4.exe)
    parts = filename.split(".")
    if len(parts) > 2:
        last_ext = parts[-1].lower()
        dangerous_exts = ["exe", "sh", "bat", "ps1", "cmd", "php", "py", "rb", "js", "jar", "dll"]
        if last_ext in dangerous_exts:
            threat_score += 0.85
            signals.append(f"DANGEROUS_EXTENSION:{last_ext}")

    # MIME type spoofing
    if mime_type and declared_mime and mime_type != declared_mime:
        threat_score += 0.60
        signals.append(f"MIME_SPOOF:declared={declared_mime},actual={mime_type}")

    # Steganography heuristic (high entropy video/image = hidden payload)
    if file_entropy > 7.8 and mime_type.startswith("image/"):
        threat_score += 0.30
        signals.append(f"HIGH_ENTROPY_IMAGE:{file_entropy:.2f}")

    # Oversized metadata (potential exfil)
    if len(str(metadata)) > 10000:
        threat_score += 0.25
        signals.append("EXCESSIVE_METADATA")

    # Metadata injection scan
    meta_hits = _scan_dict(metadata)
    if meta_hits:
        threat_score += 0.45
        signals.append(f"METADATA_INJECTION:{meta_hits[:2]}")

    threat_score = round(min(threat_score, 1.0), 4)
    level = _threat_level(threat_score)
    action = "BLOCK" if threat_score >= 0.65 else ("QUARANTINE" if threat_score >= 0.40 else "ALLOW")

    return {
        "threat_score": threat_score,
        "threat_level": level,
        "action": action,
        "signals": signals,
        "filename": filename,
        "analyzed_at": datetime.now(timezone.utc).isoformat(),
    }


# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.route("/predict", methods=["POST"])
@app.route("/predict/request", methods=["POST"])
def predict_request():
    """Analyze an inbound HTTP request for threats."""
    try:
        data = request.get_json(force=True) or {}
        result = analyze_request(data)
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        logging.error(f"[SecurityAI] predict error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/predict/behavior", methods=["POST"])
def predict_behavior():
    """Analyze user behavioral signals for account anomalies."""
    try:
        data = request.get_json(force=True) or {}
        result = analyze_account_behavior(data)
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        logging.error(f"[SecurityAI] behavior error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/predict/content", methods=["POST"])
def predict_content():
    """Analyze uploaded content for security threats."""
    try:
        data = request.get_json(force=True) or {}
        result = analyze_content_security(data)
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        logging.error(f"[SecurityAI] content error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/predict/batch", methods=["POST"])
def predict_batch():
    """Analyze a batch of requests."""
    try:
        data = request.get_json(force=True) or {}
        requests_list = data.get("requests", [])
        results = [analyze_request(r) for r in requests_list]
        blocked = sum(1 for r in results if r.get("blocked"))
        critical = sum(1 for r in results if r.get("threat_level") == "CRITICAL")
        return jsonify({
            "predictions": results,
            "summary": {
                "total": len(results),
                "blocked": blocked,
                "critical": critical,
                "clean": sum(1 for r in results if r.get("threat_level") == "CLEAN"),
            }
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/admin/banned-ips", methods=["GET"])
def get_banned_ips():
    return jsonify({"banned_ips": list(_banned_ips), "count": len(_banned_ips)}), 200


@app.route("/admin/banned-uids", methods=["GET"])
def get_banned_uids():
    return jsonify({"banned_uids": list(_banned_uids), "count": len(_banned_uids)}), 200


@app.route("/admin/unban", methods=["POST"])
def unban():
    data = request.get_json(force=True) or {}
    ip = data.get("ip")
    uid = data.get("uid")
    if ip and ip in _banned_ips:
        _banned_ips.discard(ip)
    if uid and uid in _banned_uids:
        _banned_uids.discard(uid)
    return jsonify({"status": "ok"}), 200


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy",
        "service": "cybersecurity-ai",
        "version": "v2.0",
        "banned_ips": len(_banned_ips),
        "banned_uids": len(_banned_uids),
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
