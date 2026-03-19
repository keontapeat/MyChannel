#!/usr/bin/env python3
"""
3 Strike Review ML Service - MyChannel
Auto-reviews violations, predicts strike severity, recommends appeals outcomes
"""
import os
import logging
from flask import Flask, request, jsonify
from google.cloud import aiplatform

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

PROJECT_ID = os.environ.get("PROJECT_ID", "mychannel-ca26d")
REGION = os.environ.get("REGION", "us-central1")
ENDPOINT_ID = os.environ.get("VERTEX_AI_ENDPOINT_ID", "")

aiplatform.init(project=PROJECT_ID, location=REGION)

VIOLATION_WEIGHTS = {
    "hate_speech": 1.0,
    "csam": 1.0,
    "doxxing": 0.9,
    "harassment_severe": 0.85,
    "spam_coordinated": 0.8,
    "misinformation_dangerous": 0.8,
    "graphic_violence": 0.75,
    "copyright_repeat": 0.7,
    "nudity": 0.65,
    "harassment_mild": 0.5,
    "spam_mild": 0.4,
    "copyright_first": 0.35,
    "community_guideline_minor": 0.2,
}

STRIKE_THRESHOLDS = {"warning": 0.3, "strike_1": 0.5, "strike_2": 0.65, "strike_3_ban": 0.80}


def compute_violation_severity(violation: dict, account_history: dict) -> dict:
    violation_type = violation.get("type", "community_guideline_minor")
    base_weight = VIOLATION_WEIGHTS.get(violation_type, 0.3)

    # Account history multipliers
    prior_strikes = account_history.get("prior_strikes", 0)
    prior_warnings = account_history.get("prior_warnings", 0)
    account_age_days = account_history.get("account_age_days", 30)
    is_verified = account_history.get("is_verified", False)
    is_creator_partner = account_history.get("is_creator_partner", False)

    severity = base_weight
    severity += prior_strikes * 0.12
    severity += prior_warnings * 0.05
    if account_age_days < 7:
        severity += 0.15  # new accounts get less benefit of the doubt
    if is_verified:
        severity -= 0.05
    if is_creator_partner:
        severity -= 0.03

    severity = min(max(round(severity, 4), 0.0), 1.0)

    # Determine action
    if severity >= STRIKE_THRESHOLDS["strike_3_ban"]:
        action = "permanent_ban"
        strike_level = 3
    elif severity >= STRIKE_THRESHOLDS["strike_2"]:
        action = "strike_2_30day_restriction"
        strike_level = 2
    elif severity >= STRIKE_THRESHOLDS["strike_1"]:
        action = "strike_1_7day_restriction"
        strike_level = 1
    elif severity >= STRIKE_THRESHOLDS["warning"]:
        action = "warning_no_strike"
        strike_level = 0
    else:
        action = "no_action_educational_notice"
        strike_level = 0

    # Appeal likelihood
    appeal_success_probability = max(0.0, min(1.0 - severity + 0.2, 0.85))
    if prior_strikes >= 2:
        appeal_success_probability *= 0.5
    if violation_type in ["hate_speech", "csam", "doxxing"]:
        appeal_success_probability = 0.0

    return {
        "severity_score": severity,
        "recommended_action": action,
        "strike_level": strike_level,
        "violation_type": violation_type,
        "appeal_success_probability": round(appeal_success_probability, 4),
        "appeal_recommended": appeal_success_probability > 0.4,
        "needs_human_review": 0.35 <= severity <= 0.55,
        "auto_actioned": severity < 0.35 or severity > 0.75,
    }


def review_appeal(appeal: dict, original_violation: dict, account_history: dict) -> dict:
    appeal_reason = appeal.get("reason", "")
    has_evidence = appeal.get("has_evidence", False)
    is_first_offense = account_history.get("prior_strikes", 0) == 0
    violation_type = original_violation.get("type", "")
    severity = original_violation.get("severity_score", 0.5)

    # Auto-deny severe violations
    if violation_type in ["hate_speech", "csam", "doxxing"]:
        return {"appeal_outcome": "denied", "reason": "violation_type_not_appealable", "confidence": 0.99}

    overturn_score = 0.0
    if has_evidence:
        overturn_score += 0.30
    if is_first_offense:
        overturn_score += 0.20
    if len(appeal_reason) > 100:
        overturn_score += 0.10
    if severity < 0.5:
        overturn_score += 0.15
    if account_history.get("account_age_days", 0) > 365:
        overturn_score += 0.10

    if overturn_score >= 0.5:
        outcome = "overturned"
        new_action = "warning_only"
    elif overturn_score >= 0.3:
        outcome = "partially_overturned"
        new_action = "reduced_to_warning"
    else:
        outcome = "upheld"
        new_action = original_violation.get("recommended_action", "strike_1_7day_restriction")

    return {
        "appeal_outcome": outcome,
        "new_action": new_action,
        "overturn_score": round(overturn_score, 4),
        "confidence": 0.84
    }


@app.route("/predict/review", methods=["POST"])
def review_violation():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400
        violation = data.get("violation", {})
        account_history = data.get("account_history", {})
        result = compute_violation_severity(violation, account_history)
        result["user_id"] = data.get("user_id", "unknown")
        result["content_id"] = data.get("content_id", "unknown")
        logging.info(f"Strike review: action={result['recommended_action']} severity={result['severity_score']}")
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        logging.error(f"Strike review error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/predict/appeal", methods=["POST"])
def review_appeal_request():
    try:
        data = request.get_json()
        appeal = data.get("appeal", {})
        original_violation = data.get("original_violation", {})
        account_history = data.get("account_history", {})
        result = review_appeal(appeal, original_violation, account_history)
        result["user_id"] = data.get("user_id", "unknown")
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/batch", methods=["POST"])
def batch_review():
    try:
        data = request.get_json()
        cases = data.get("cases", [])
        results = []
        auto_actioned = 0
        needs_human = 0
        for case in cases:
            r = compute_violation_severity(case.get("violation", {}), case.get("account_history", {}))
            r["user_id"] = case.get("user_id", "")
            if r["auto_actioned"]:
                auto_actioned += 1
            if r["needs_human_review"]:
                needs_human += 1
            results.append(r)
        return jsonify({
            "predictions": results,
            "summary": {
                "total": len(results),
                "auto_actioned": auto_actioned,
                "needs_human_review": needs_human,
                "bans": sum(1 for r in results if r["recommended_action"] == "permanent_ban")
            }
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "three-strike-review", "version": "v1.0"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
