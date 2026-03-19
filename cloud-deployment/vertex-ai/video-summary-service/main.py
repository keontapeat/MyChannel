"""
Video Summary AI Service
Auto-generate video summaries and descriptions
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

def generate_summary(transcript: str, title: str = '', duration: int = 0) -> dict:
    """Generate comprehensive video summary using Gemini"""
    
    prompt = f"""Analyze this video transcript and generate comprehensive metadata.

VIDEO TITLE: {title or 'Untitled'}
DURATION: {duration} seconds
TRANSCRIPT:
{transcript[:5000]}

Generate a JSON response with:
1. "summary" - 2-3 sentence summary of the video
2. "shortSummary" - 1 sentence (for cards/thumbnails)  
3. "keyPoints" - array of 3-5 main takeaways
4. "topics" - array of 3-7 topic tags
5. "sentiment" - overall sentiment: positive/neutral/negative
6. "contentType" - tutorial/review/entertainment/news/vlog/other
7. "targetAudience" - who this video is for
8. "description" - YouTube-optimized description (300 words)
9. "hashtags" - array of 5-10 relevant hashtags

Return ONLY valid JSON."""

    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        
        # Extract JSON
        import re
        json_match = re.search(r'\{.*\}', text, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
    except Exception as e:
        print(f"Error generating summary: {e}")
    
    return {
        'summary': 'Video content analysis unavailable.',
        'shortSummary': 'Video content.',
        'keyPoints': [],
        'topics': [],
        'sentiment': 'neutral',
        'contentType': 'other',
        'targetAudience': 'general',
        'description': '',
        'hashtags': []
    }

def extract_quotes(transcript: str, max_quotes: int = 5) -> list:
    """Extract memorable quotes from transcript"""
    if not transcript:
        return []
    
    prompt = f"""Extract {max_quotes} most memorable/quotable sentences from this transcript.
    
TRANSCRIPT: {transcript[:3000]}

Return as JSON array of strings. Return ONLY valid JSON array."""
    
    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        import re
        json_match = re.search(r'\[.*?\]', text, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
    except:
        pass
    
    return []

@app.route('/summarize', methods=['POST'])
def summarize():
    data = request.json
    video_id = data.get('videoId', '')
    transcript = data.get('transcript', '')
    title = data.get('title', '')
    duration = data.get('duration', 0)
    
    if not transcript:
        return jsonify({'error': 'transcript required'}), 400
    
    summary_data = generate_summary(transcript, title, duration)
    quotes = extract_quotes(transcript)
    
    return jsonify({
        'videoId': video_id,
        **summary_data,
        'memorableQuotes': quotes,
        'transcriptLength': len(transcript.split()),
        'readingTime': f"{len(transcript.split()) // 200} min read"
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'video-summary-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
