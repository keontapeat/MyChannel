"""
Dialect Detection AI Service
Detect language dialects for better localization
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

DIALECT_MAP = {
    'en': ['en-US', 'en-GB', 'en-AU', 'en-CA', 'en-IN', 'en-NG', 'en-ZA'],
    'es': ['es-MX', 'es-ES', 'es-AR', 'es-CO', 'es-CL', 'es-PE'],
    'pt': ['pt-BR', 'pt-PT'],
    'zh': ['zh-CN', 'zh-TW', 'zh-HK'],
    'ar': ['ar-SA', 'ar-EG', 'ar-MA', 'ar-AE'],
    'fr': ['fr-FR', 'fr-CA', 'fr-BE', 'fr-CH'],
}

def detect_dialect(transcript: str, base_language: str = None) -> dict:
    if not transcript:
        return {'dialect': 'en-US', 'confidence': 0.5, 'baseLanguage': 'en'}

    prompt = f"""Analyze this text and identify the specific dialect/regional variant.

TEXT: {transcript[:500]}

Determine:
1. "baseLanguage" - ISO 639-1 code (en, es, pt, fr, zh, ar, etc.)
2. "dialect" - specific regional variant (en-US, en-GB, es-MX, pt-BR, etc.)
3. "confidence" - 0-1 confidence score
4. "dialectFeatures" - array of specific features that indicate this dialect
5. "region" - geographic region
6. "localizationNotes" - array of tips for localizing content for this dialect

Return ONLY valid JSON."""

    try:
        response = model.generate_content(prompt)
        import re
        m = re.search(r'\{.*\}', response.text, re.DOTALL)
        if m:
            return json.loads(m.group())
    except Exception as e:
        print(f"Dialect detection error: {e}")

    # Fallback
    return {
        'baseLanguage': base_language or 'en',
        'dialect': f'{base_language or "en"}-US',
        'confidence': 0.5,
        'dialectFeatures': [],
        'region': 'Unknown',
        'localizationNotes': []
    }

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    transcript = data.get('transcript', '')
    base_language = data.get('baseLanguage')
    result = detect_dialect(transcript, base_language)
    return jsonify({'videoId': data.get('videoId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'dialect-detection-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
