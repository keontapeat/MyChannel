#!/usr/bin/env python3
"""
Gaming & Esports ML Service - MyChannel
Powers GamingEsportsViewModel: match predictions, skill ranking,
tournament seeding, odds, highlight detection, player analytics
"""
import os
import logging
import math
from flask import Flask, request, jsonify
from google.cloud import aiplatform

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

PROJECT_ID = os.environ.get("PROJECT_ID", "mychannel-ca26d")
REGION = os.environ.get("REGION", "us-central1")
ENDPOINT_ID = os.environ.get("VERTEX_AI_ENDPOINT_ID", "")

aiplatform.init(project=PROJECT_ID, location=REGION)


# ── Glicko-2 style skill rating ───────────────────────────────────────────

def compute_skill_rating(player: dict) -> dict:
    wins = player.get("wins", 0)
    losses = player.get("losses", 0)
    total = wins + losses
    if total == 0:
        return {"skill_rating": 1500, "tier": "Unranked", "confidence": 0.5}

    win_rate = wins / total
    avg_opponent_rating = player.get("avg_opponent_rating", 1500)
    streak = player.get("current_win_streak", 0)
    avg_kda = player.get("avg_kda", 1.0)

    # Base rating from win rate vs opponent quality
    expected_win_rate = 1 / (1 + 10 ** ((avg_opponent_rating - 1500) / 400))
    rating_delta = 32 * (win_rate - expected_win_rate)
    rating = 1500 + rating_delta * total * 0.5

    # KDA bonus
    rating += (avg_kda - 1.0) * 50
    # Win streak bonus
    rating += min(streak * 15, 100)

    rating = max(min(round(rating), 3000), 500)

    if rating >= 2500:
        tier = "Grandmaster"
    elif rating >= 2200:
        tier = "Master"
    elif rating >= 1900:
        tier = "Diamond"
    elif rating >= 1700:
        tier = "Platinum"
    elif rating >= 1500:
        tier = "Gold"
    elif rating >= 1300:
        tier = "Silver"
    else:
        tier = "Bronze"

    confidence = min(total / 50.0, 1.0)
    return {"skill_rating": rating, "tier": tier, "confidence": round(confidence, 4)}


# ── Match outcome prediction ───────────────────────────────────────────────

def predict_match_outcome(player_a: dict, player_b: dict) -> dict:
    rating_a = player_a.get("skill_rating", 1500)
    rating_b = player_b.get("skill_rating", 1500)

    # Elo win probability
    prob_a = 1 / (1 + 10 ** ((rating_b - rating_a) / 400))
    prob_b = 1 - prob_a

    # Head-to-head history adjustment
    h2h_wins_a = player_a.get("h2h_wins_vs_opponent", 0)
    h2h_wins_b = player_b.get("h2h_wins_vs_opponent", 0)
    h2h_total = h2h_wins_a + h2h_wins_b
    if h2h_total > 0:
        h2h_factor = (h2h_wins_a / h2h_total - 0.5) * 0.1
        prob_a = min(max(prob_a + h2h_factor, 0.05), 0.95)
        prob_b = 1 - prob_a

    # Recent form adjustment
    form_a = player_a.get("recent_form_5games", 0.5)
    form_b = player_b.get("recent_form_5games", 0.5)
    form_factor = (form_a - form_b) * 0.05
    prob_a = min(max(prob_a + form_factor, 0.05), 0.95)
    prob_b = 1 - prob_a

    # Odds (American format)
    if prob_a >= 0.5:
        odds_a = round(-prob_a / (1 - prob_a) * 100)
        odds_b = round((1 - prob_a) / prob_a * 100)
    else:
        odds_a = round(prob_a / (1 - prob_a) * 100)
        odds_b = round(-prob_b / (1 - prob_b) * 100)

    return {
        "player_a_win_probability": round(prob_a, 4),
        "player_b_win_probability": round(prob_b, 4),
        "predicted_winner": player_a.get("player_id") if prob_a > prob_b else player_b.get("player_id"),
        "confidence": round(abs(prob_a - 0.5) * 2, 4),
        "odds_a_american": odds_a,
        "odds_b_american": odds_b,
        "is_close_match": abs(prob_a - prob_b) < 0.15,
    }


# ── Tournament seeding ─────────────────────────────────────────────────────

def seed_tournament(players: list) -> list:
    rated = []
    for p in players:
        sr = compute_skill_rating(p)
        rated.append({**p, **sr})
    rated.sort(key=lambda x: x["skill_rating"], reverse=True)
    seeded = []
    for i, p in enumerate(rated):
        seeded.append({
            "seed": i + 1,
            "player_id": p.get("player_id"),
            "display_name": p.get("display_name"),
            "skill_rating": p["skill_rating"],
            "tier": p["tier"],
        })
    return seeded


# ── Highlight moment detection ─────────────────────────────────────────────

def detect_highlights(game_events: list) -> list:
    highlights = []
    for event in game_events:
        excitement = 0.0
        etype = event.get("type", "")
        if etype == "clutch_play":
            excitement += 0.9
        elif etype == "multi_kill":
            excitement += 0.7 + event.get("kill_count", 1) * 0.05
        elif etype == "comeback":
            excitement += 0.85
        elif etype == "record_broken":
            excitement += 0.95
        elif etype == "final_kill":
            excitement += 0.6

        # Crowd reaction signal
        excitement += event.get("chat_spike_ratio", 0) * 0.2
        excitement = min(round(excitement, 4), 1.0)

        if excitement >= 0.5:
            highlights.append({
                "timestamp": event.get("timestamp"),
                "event_type": etype,
                "excitement_score": excitement,
                "clip_start_offset_seconds": -5,
                "clip_duration_seconds": 15,
                "is_top_highlight": excitement >= 0.8,
            })

    highlights.sort(key=lambda x: x["excitement_score"], reverse=True)
    return highlights


# ── Routes ─────────────────────────────────────────────────────────────────

@app.route("/predict/skill-rating", methods=["POST"])
def skill_rating():
    try:
        data = request.get_json()
        player = data.get("player", data)
        result = compute_skill_rating(player)
        result["player_id"] = data.get("player_id", "unknown")
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/match-outcome", methods=["POST"])
def match_outcome():
    try:
        data = request.get_json()
        result = predict_match_outcome(
            data.get("player_a", {}),
            data.get("player_b", {})
        )
        result["match_id"] = data.get("match_id", "unknown")
        logging.info(f"Match prediction: winner={result['predicted_winner']} conf={result['confidence']}")
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/tournament-seed", methods=["POST"])
def tournament_seed():
    try:
        data = request.get_json()
        players = data.get("players", [])
        if not players:
            return jsonify({"error": "No players provided"}), 400
        seeded = seed_tournament(players)
        return jsonify({
            "predictions": [{
                "tournament_id": data.get("tournament_id"),
                "seeded_players": seeded,
                "total_players": len(seeded)
            }]
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/highlights", methods=["POST"])
def highlights():
    try:
        data = request.get_json()
        events = data.get("game_events", [])
        result = detect_highlights(events)
        return jsonify({
            "predictions": [{
                "match_id": data.get("match_id"),
                "highlights": result,
                "top_highlight_count": sum(1 for h in result if h["is_top_highlight"]),
                "total_highlights": len(result)
            }]
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/leaderboard", methods=["POST"])
def leaderboard():
    try:
        data = request.get_json()
        players = data.get("players", [])
        period = data.get("period", "weekly")
        scored = []
        for p in players:
            sr = compute_skill_rating(p)
            scored.append({
                "player_id": p.get("player_id"),
                "display_name": p.get("display_name"),
                "skill_rating": sr["skill_rating"],
                "tier": sr["tier"],
                "earnings": p.get("earnings", 0),
                "wins": p.get("wins", 0),
                "win_rate": round(p.get("wins", 0) / max(p.get("wins", 0) + p.get("losses", 0), 1), 4),
            })
        scored.sort(key=lambda x: x["skill_rating"], reverse=True)
        for i, p in enumerate(scored):
            p["rank"] = i + 1
        return jsonify({"predictions": [{"leaderboard": scored, "period": period}]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "gaming-esports-ml", "version": "v1.0"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
