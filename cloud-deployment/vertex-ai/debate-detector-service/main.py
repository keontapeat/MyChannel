"""
Debate Detector AI Service
Detect viral debates in comments - surface hot content
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

def detect_debate(comments: list, video_id: str) -> dict:
    if not comments:
        return {'hasDebate': False, 'debateScore': 0, 'topics': [], 'sides': []}

    # Signals for debate detection
    total = len(comments)
    reply_heavy = sum(1 for c in comments if c.get('replyCount', 0) > 3)
    reply_ratio = reply_heavy / max(total, 1)

    # Sentiment polarity - high variance = debate
    sentiments = [c.get('sentimentScore', 0) for c in comments if 'sentimentScore' in c]
    sentiment_variance = 0.0
    if sentiments:
        avg = sum(sentiments) / len(sentiments)
        sentiment_variance = sum((s - avg) ** 2 for s in sentiments) / len(sentiments)

    # Opposing keywords
    debate_keywords = ['wrong', 'actually', 'disagree', 'no way', 'but', 'however', 'vs', 'better', 'worse']
    debate_comment_count = sum(
        1 for c in comments
        if any(kw in c.get('text', '').lower() for kw in debate_keywords)
    )
    debate_ratio = debate_comment_count / max(total, 1)

    # Composite debate score
    debate_score = round(
        reply_ratio * 0.4 +
        min(sentiment_variance * 2, 1.0) * 0.3 +
        debate_ratio * 0.3,
        3
    )

    has_debate = debate_score > 0.35

    # Use AI to identify debate topics if significant
    topics = []
    sides = []
    if has_debate and total >= 5:
        sample_texts = [c.get('text', '')[:100] for c in comments[:20]]
        prompt = f"""These video comments have a debate. Identify:
1. "topics" - array of 1-3 debate topics
2. "sides" - array of 2 opposing viewpoints

COMMENTS: {json.dumps(sample_texts)}

Return ONLY valid JSON: {{"topics": [], "sides": []}}"""
        try:
            resp = model.generate_content(prompt)
            import re
            m = re.search(r'\{.*\}', resp.text, re.DOTALL)
            if m:
                ai = json.loads(m.group())
                topics = ai.get('topics', [])
                sides = ai.get('sides', [])
        except:
            pass

    return {
        'hasDebate': has_debate,
        'debateScore': debate_score,
        'topics': topics,
        'sides': sides,
        'metrics': {
            'replyRatio': round(reply_ratio, 3),
            'sentimentVariance': round(sentiment_variance, 3),
            'debateKeywordRatio': round(debate_ratio, 3)
        },
        'action': 'boost_visibility' if debate_score > 0.6 else 'monitor' if has_debate else 'normal'
    }

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    result = detect_debate(data.get('comments', []), data.get('videoId', ''))
    return jsonify({'videoId': data.get('videoId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'debate-detector-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
