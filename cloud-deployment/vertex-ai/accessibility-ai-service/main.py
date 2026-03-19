"""
Accessibility AI Service
Auto-generate accessibility content: audio descriptions, alt text, sign language cues
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

def generate_audio_description(video_metadata: dict) -> str:
    """Generate audio description for visually impaired users"""
    title = video_metadata.get('title', '')
    description = video_metadata.get('description', '')
    transcript = video_metadata.get('transcript', '')[:1000]
    category = video_metadata.get('category', '')

    prompt = f"""Write a brief audio description for a visually impaired person watching this video.
Describe the visual content, setting, and key actions in 2-3 sentences.

TITLE: {title}
CATEGORY: {category}
DESCRIPTION: {description[:200]}
TRANSCRIPT: {transcript}

Return ONLY the audio description text (2-3 sentences, natural spoken language)."""

    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except:
        return f"Video titled '{title}' in the {category} category."

def generate_alt_text(thumbnail_description: dict) -> str:
    """Generate alt text for thumbnails"""
    prompt = f"""Write concise alt text for this video thumbnail for screen readers.
Under 125 characters, descriptive and informative.

THUMBNAIL INFO: {json.dumps(thumbnail_description)}

Return ONLY the alt text."""
    try:
        response = model.generate_content(prompt)
        return response.text.strip()[:125]
    except:
        return thumbnail_description.get('title', 'Video thumbnail')

def check_accessibility_compliance(video_data: dict) -> dict:
    """Check WCAG 2.1 AA compliance for video content"""
    issues = []
    score = 100

    # Caption check
    has_captions = video_data.get('hasCaptions', False)
    caption_accuracy = video_data.get('captionAccuracy', 0)
    if not has_captions:
        issues.append({'criterion': 'WCAG 1.2.2', 'issue': 'No captions provided', 'severity': 'critical'})
        score -= 30
    elif caption_accuracy < 0.95:
        issues.append({'criterion': 'WCAG 1.2.2', 'issue': f'Caption accuracy below 95% ({caption_accuracy:.0%})', 'severity': 'high'})
        score -= 15

    # Audio description
    has_audio_desc = video_data.get('hasAudioDescription', False)
    if not has_audio_desc:
        issues.append({'criterion': 'WCAG 1.2.5', 'issue': 'No audio description for visual content', 'severity': 'medium'})
        score -= 15

    # Flashing content
    has_flashing = video_data.get('hasFlashingContent', False)
    if has_flashing:
        issues.append({'criterion': 'WCAG 2.3.1', 'issue': 'Flashing content detected - may trigger seizures', 'severity': 'critical'})
        score -= 25

    # Transcript
    has_transcript = video_data.get('hasTranscript', False)
    if not has_transcript:
        issues.append({'criterion': 'WCAG 1.2.3', 'issue': 'No text transcript available', 'severity': 'medium'})
        score -= 10

    score = max(0, score)
    return {
        'score': score,
        'grade': 'A' if score >= 90 else 'B' if score >= 80 else 'C' if score >= 70 else 'F',
        'wcagLevel': 'AA' if score >= 80 else 'A' if score >= 60 else 'Non-compliant',
        'issues': issues,
        'compliant': score >= 80,
        'recommendations': [i['issue'] for i in issues]
    }

@app.route('/describe', methods=['POST'])
def describe():
    data = request.json
    video_metadata = data.get('videoMetadata', {})
    audio_desc = generate_audio_description(video_metadata)
    compliance = check_accessibility_compliance(data.get('videoData', {}))
    alt_text = generate_alt_text(data.get('thumbnailData', {'title': video_metadata.get('title', '')}))

    return jsonify({
        'videoId': data.get('videoId', ''),
        'audioDescription': audio_desc,
        'thumbnailAltText': alt_text,
        'wcagCompliance': compliance
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'accessibility-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
