"""
Phishing Detector AI Service
Detect phishing links in comments, descriptions, bios
"""
import os
import re
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

SUSPICIOUS_PATTERNS = [
    r'bit\.ly/', r'tinyurl\.com/', r'goo\.gl/',
    r'free.*gift', r'claim.*prize', r'winner.*selected',
    r'verify.*account', r'suspended.*account',
    r'click.*here.*now', r'limited.*time.*offer',
    r'send.*crypto', r'double.*bitcoin',
    r'onlyfans.*free', r'password.*reset.*link',
]

SAFE_DOMAINS = [
    'youtube.com', 'google.com', 'twitter.com', 'instagram.com',
    'tiktok.com', 'facebook.com', 'amazon.com', 'mychannel.live',
    'github.com', 'wikipedia.org', 'reddit.com'
]

def analyze_text_for_phishing(text: str) -> dict:
    risk_score = 0.0
    flags = []

    text_lower = text.lower()

    # Pattern matching
    for pattern in SUSPICIOUS_PATTERNS:
        if re.search(pattern, text_lower):
            risk_score += 0.2
            flags.append(f'Suspicious pattern: {pattern}')

    # URL extraction
    urls = re.findall(r'https?://[^\s<>"]+|www\.[^\s<>"]+', text)
    suspicious_urls = []

    for url in urls:
        domain = re.sub(r'https?://', '', url).split('/')[0].lower()
        is_safe = any(safe in domain for safe in SAFE_DOMAINS)
        if not is_safe:
            suspicious_urls.append(url)
            risk_score += 0.15

    # Homograph attacks (lookalike domains)
    lookalike_patterns = [
        r'g[o0]{2}gle', r'fac[e3]b[o0]{2}k', r'paypa[l1]',
        r'[a4]mazon', r'micr[o0]s[o0]ft', r'app[l1]e'
    ]
    for p in lookalike_patterns:
        if re.search(p, text_lower):
            risk_score += 0.4
            flags.append('Lookalike domain detected')

    risk_score = min(round(risk_score, 3), 1.0)

    return {
        'riskScore': risk_score,
        'isPhishing': risk_score >= 0.5,
        'flags': flags,
        'suspiciousUrls': suspicious_urls,
        'urlCount': len(urls),
        'action': 'remove' if risk_score >= 0.7 else 'warn' if risk_score >= 0.4 else 'allow'
    }

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    text = data.get('text', '')
    content_id = data.get('contentId', '')

    result = analyze_text_for_phishing(text)
    return jsonify({'contentId': content_id, **result})

@app.route('/batch', methods=['POST'])
def batch_analyze():
    data = request.json
    items = data.get('items', [])
    results = []
    for item in items:
        r = analyze_text_for_phishing(item.get('text', ''))
        results.append({'id': item.get('id', ''), **r})
    flagged = sum(1 for r in results if r['isPhishing'])
    return jsonify({'results': results, 'total': len(results), 'flagged': flagged})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'phishing-detector-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
