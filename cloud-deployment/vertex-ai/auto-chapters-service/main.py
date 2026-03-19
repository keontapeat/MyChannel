"""
Auto Chapters AI Service
Auto-generate meaningful chapter titles from video content
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)

# Configure Gemini
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

def generate_chapter_titles(transcript: str, chapters: list) -> list:
    """Use Gemini to generate meaningful chapter titles"""
    if not transcript or not chapters:
        return chapters
    
    # Build prompt
    chapters_info = '\n'.join([
        f"Chapter {c['index']}: {c['start_formatted']} - {c['end_formatted'] if 'end_formatted' in c else ''} (duration: {c['duration']}s)"
        for c in chapters
    ])
    
    prompt = f"""You are a YouTube chapter title generator. Given a video transcript and chapter timestamps, generate concise, engaging chapter titles.

VIDEO TRANSCRIPT (excerpt):
{transcript[:3000]}

CHAPTERS:
{chapters_info}

Generate a JSON array of chapter titles. Each title should be:
- 2-5 words maximum
- Descriptive and engaging
- Relevant to what happens at that timestamp
- No clickbait

Return ONLY valid JSON array like: ["Intro", "Main Topic", "Key Point", "Conclusion"]"""

    try:
        response = model.generate_content(prompt)
        titles_text = response.text.strip()
        
        # Extract JSON
        import re
        json_match = re.search(r'\[.*?\]', titles_text, re.DOTALL)
        if json_match:
            titles = json.loads(json_match.group())
            
            # Apply titles to chapters
            for i, chapter in enumerate(chapters):
                if i < len(titles):
                    chapter['title'] = titles[i]
            
    except Exception as e:
        print(f"Error generating titles: {e}")
    
    return chapters

def extract_key_moments(chapters: list, transcript: str) -> list:
    """Extract key moments and highlights"""
    key_moments = []
    
    for chapter in chapters:
        key_moments.append({
            'timestamp': chapter['start_seconds'],
            'formatted': chapter['start_formatted'],
            'title': chapter.get('title', f"Chapter {chapter['index']}"),
            'isChapter': True
        })
    
    return key_moments

@app.route('/generate', methods=['POST'])
def generate_chapters():
    data = request.json
    video_id = data.get('videoId', '')
    transcript = data.get('transcript', '')
    scenes = data.get('scenes', [])
    duration = data.get('duration', 0)
    
    # Build base chapters from scenes
    chapters = []
    for i, scene in enumerate(scenes):
        start = scene.get('start', 0)
        end = scene.get('end', 0)
        
        from scene_utils import format_timestamp
        chapters.append({
            'index': i + 1,
            'start_seconds': round(start, 1),
            'end_seconds': round(end, 1),
            'start_formatted': _format_ts(start),
            'end_formatted': _format_ts(end),
            'duration': round(end - start, 1),
            'title': f'Chapter {i + 1}'
        })
    
    # Generate AI titles if transcript available
    if transcript and chapters:
        chapters = generate_chapter_titles(transcript, chapters)
    
    key_moments = extract_key_moments(chapters, transcript)
    
    # Generate YouTube-style description
    description_lines = [f"{c['start_formatted']} {c['title']}" for c in chapters]
    
    return jsonify({
        'videoId': video_id,
        'chapters': chapters,
        'keyMoments': key_moments,
        'youtubeDescription': '\n'.join(description_lines),
        'chapterCount': len(chapters)
    })

def _format_ts(seconds: float) -> str:
    s = int(seconds)
    h = s // 3600
    m = (s % 3600) // 60
    sec = s % 60
    if h > 0:
        return f"{h:02d}:{m:02d}:{sec:02d}"
    return f"{m:02d}:{sec:02d}"

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'auto-chapters-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
