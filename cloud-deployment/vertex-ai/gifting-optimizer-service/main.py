"""
Gifting Optimizer AI Service
Optimize virtual gift timing and suggestions for maximum revenue
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

GIFT_CATALOG = [
    {'id': 'rose', 'name': 'Rose', 'credits': 1, 'usdValue': 0.01, 'animation': 'float'},
    {'id': 'heart', 'name': 'Heart', 'credits': 5, 'usdValue': 0.05, 'animation': 'pulse'},
    {'id': 'fire', 'name': 'Fire', 'credits': 20, 'usdValue': 0.20, 'animation': 'burst'},
    {'id': 'crown', 'name': 'Crown', 'credits': 100, 'usdValue': 1.00, 'animation': 'sparkle'},
    {'id': 'rocket', 'name': 'Rocket', 'credits': 500, 'usdValue': 5.00, 'animation': 'launch'},
    {'id': 'diamond', 'name': 'Diamond', 'credits': 1000, 'usdValue': 10.00, 'animation': 'shatter'},
    {'id': 'galaxy', 'name': 'Galaxy', 'credits': 5000, 'usdValue': 50.00, 'animation': 'explode'},
]

def optimize_gift_moment(stream_data: dict, user_data: dict) -> dict:
    viewer_count = stream_data.get('viewerCount', 0)
    stream_duration_min = stream_data.get('durationMinutes', 0)
    creator_milestone_near = stream_data.get('milestoneNear', False)
    peak_moment = stream_data.get('isPeakEngagement', False)
    last_gift_seconds = stream_data.get('secondsSinceLastGift', 999)

    user_credits = user_data.get('credits', 0)
    past_gifting_avg = user_data.get('avgGiftValue', 0)
    is_top_gifter = user_data.get('isTopGifter', False)
    gifting_streak = user_data.get('giftingStreakDays', 0)

    prompt_score = 0.0
    reasons = []

    # Peak engagement = best time to prompt
    if peak_moment:
        prompt_score += 0.35
        reasons.append('Stream at peak engagement moment')

    # Milestone approaching
    if creator_milestone_near:
        prompt_score += 0.30
        reasons.append('Creator close to milestone')

    # Good time gap since last gift
    if last_gift_seconds > 300:
        prompt_score += 0.15
        reasons.append('Good time gap since last gift')

    # Early in stream (gifting more common)
    if 5 <= stream_duration_min <= 30:
        prompt_score += 0.10
        reasons.append('Early stream prime gifting window')

    # Top gifter = higher suggestion
    if is_top_gifter:
        prompt_score += 0.10
        reasons.append('Top gifter status')

    prompt_score = min(round(prompt_score, 3), 1.0)
    should_prompt = prompt_score >= 0.4

    # Suggest appropriate gift based on user history
    suggested_gift = _suggest_gift(user_credits, past_gifting_avg, is_top_gifter)

    return {
        'shouldPromptGift': should_prompt,
        'promptScore': prompt_score,
        'reasons': reasons,
        'suggestedGift': suggested_gift,
        'giftCatalog': GIFT_CATALOG,
        'urgencyMessage': _get_urgency(creator_milestone_near, peak_moment),
        'streakBonus': f'+{gifting_streak * 5}% creator support bonus' if gifting_streak > 0 else None
    }

def _suggest_gift(credits: int, avg_value: float, is_top: bool) -> dict:
    # Find affordable gift close to user's average
    affordable = [g for g in GIFT_CATALOG if g['credits'] <= credits]
    if not affordable:
        return GIFT_CATALOG[0]

    if is_top:
        return affordable[-1]  # Most expensive affordable

    # Find gift closest to average
    target = avg_value or 1.0
    return min(affordable, key=lambda g: abs(g['usdValue'] - target))

def _get_urgency(milestone: bool, peak: bool) -> str:
    if milestone:
        return 'Help the creator reach their milestone!'
    if peak:
        return 'The stream is on fire! Show your support!'
    return None

@app.route('/optimize', methods=['POST'])
def optimize():
    data = request.json
    result = optimize_gift_moment(
        data.get('streamData', {}),
        data.get('userData', {})
    )
    return jsonify({'userId': data.get('userId', ''), 'creatorId': data.get('creatorId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'gifting-optimizer-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
