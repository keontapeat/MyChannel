"""
Poll Optimizer AI Service
Predict best poll answers and optimize engagement timing
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

def optimize_poll(poll_data: dict, audience_data: dict) -> dict:
    question = poll_data.get('question', '')
    options = poll_data.get('options', [])
    video_context = poll_data.get('videoContext', '')
    duration_hours = poll_data.get('durationHours', 24)

    audience_size = audience_data.get('subscriberCount', 1000)
    avg_engagement_rate = audience_data.get('avgEngagementRate', 0.05)
    audience_age_range = audience_data.get('ageRange', '18-34')
    top_interests = audience_data.get('topInterests', [])

    # Predict participation
    predicted_votes = int(audience_size * avg_engagement_rate * 1.5)

    # Use AI to analyze poll options
    ai_analysis = {}
    if question and options:
        prompt = f"""Analyze this community poll and predict engagement.

QUESTION: {question}
OPTIONS: {json.dumps(options)}
AUDIENCE: Age {audience_age_range}, interests: {', '.join(top_interests[:3])}
VIDEO CONTEXT: {video_context[:200]}

Return JSON with:
1. "predictedWinner" - option most likely to win
2. "predictedDistribution" - dict of option: predicted_percentage
3. "engagementScore" - 0-100 how engaging this poll is
4. "improvementSuggestions" - array of how to improve the poll
5. "bestPostingTime" - when to post for max engagement
6. "followUpContentIdea" - video idea based on poll results

Return ONLY valid JSON."""

        try:
            response = model.generate_content(prompt)
            import re
            m = re.search(r'\{.*\}', response.text, re.DOTALL)
            if m:
                ai_analysis = json.loads(m.group())
        except Exception as e:
            print(f"Poll AI error: {e}")

    return {
        'question': question,
        'options': options,
        'predictedVotes': predicted_votes,
        'predictedParticipationRate': round(predicted_votes / max(audience_size, 1), 3),
        'aiAnalysis': ai_analysis,
        'optimalDurationHours': _get_optimal_duration(audience_size),
        'postingRecommendation': _get_posting_recommendation(audience_data),
        'engagementTips': _get_tips(question, options)
    }

def _get_optimal_duration(subscribers: int) -> int:
    if subscribers > 1000000: return 24
    if subscribers > 100000: return 48
    return 72

def _get_posting_recommendation(audience: dict) -> dict:
    return {
        'bestDay': 'Tuesday or Wednesday',
        'bestTime': '12pm-2pm or 6pm-8pm (audience timezone)',
        'avoidDays': ['Monday', 'Sunday']
    }

def _get_tips(question: str, options: list) -> list:
    tips = []
    if len(options) > 4:
        tips.append('Limit to 4 options for better engagement')
    if not question.endswith('?'):
        tips.append('End question with ? for natural tone')
    if len(options) == 2:
        tips.append('Consider adding a 3rd option to increase nuance')
    tips.append('Pin the poll to your community page for max visibility')
    return tips

@app.route('/optimize', methods=['POST'])
def optimize():
    data = request.json
    result = optimize_poll(
        data.get('pollData', {}),
        data.get('audienceData', {})
    )
    return jsonify({'creatorId': data.get('creatorId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'poll-optimizer-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
