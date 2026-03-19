"""
Investor Narrative AI Service
Auto-generate investor updates, pitch decks, and board reports
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

def generate_investor_update(metrics: dict, period: str) -> dict:
    dau = metrics.get('dau', 0)
    mau = metrics.get('mau', 0)
    revenue = metrics.get('revenue', 0)
    revenue_growth = metrics.get('revenueGrowthRate', 0)
    creator_count = metrics.get('creatorCount', 0)
    video_count = metrics.get('videoCount', 0)
    user_growth = metrics.get('userGrowthRate', 0)
    burn_rate = metrics.get('monthlyBurnRate', 0)
    runway_months = metrics.get('runwayMonths', 0)

    prompt = f"""Generate a professional investor update email for MyChannel, a YouTube competitor.

METRICS FOR {period}:
- DAU: {dau:,}
- MAU: {mau:,}
- Revenue: ${revenue:,.0f}
- Revenue Growth: {revenue_growth:.1%}
- Creators: {creator_count:,}
- Videos: {video_count:,}
- User Growth: {user_growth:.1%}
- Monthly Burn: ${burn_rate:,.0f}
- Runway: {runway_months} months

Write a professional, confident update with:
1. "subject" - email subject line
2. "headline" - one-sentence highlight
3. "keyMetrics" - 3 bullet points of top metrics
4. "wins" - 2-3 major achievements
5. "challenges" - 1-2 honest challenges
6. "outlook" - forward-looking statement
7. "ask" - what we need from investors (if applicable)

Return ONLY valid JSON."""

    try:
        response = model.generate_content(prompt)
        import re
        m = re.search(r'\{.*\}', response.text, re.DOTALL)
        if m:
            return json.loads(m.group())
    except Exception as e:
        print(f"Investor narrative error: {e}")

    return {
        'subject': f'MyChannel {period} Update',
        'headline': f'Growing {user_growth:.0%} with {dau:,} daily active users',
        'keyMetrics': [
            f'DAU: {dau:,} ({user_growth:.0%} growth)',
            f'Revenue: ${revenue:,.0f} ({revenue_growth:.0%} growth)',
            f'Creators: {creator_count:,}'
        ],
        'wins': ['Platform scaling well', 'Revenue growing'],
        'challenges': ['Competitive market', 'Scaling costs'],
        'outlook': 'On track for targets',
        'ask': None
    }

@app.route('/update', methods=['POST'])
def generate_update():
    data = request.json
    result = generate_investor_update(
        data.get('metrics', {}),
        data.get('period', 'Q1 2026')
    )
    return jsonify(result)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'investor-narrative-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
