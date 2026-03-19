"""
Highlight Reel AI Service
Auto-cut the best moments from long videos
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

def score_segments(segments: list, transcript: str, engagement_data: dict) -> list:
    """Score video segments for highlight potential"""
    
    if not segments:
        return []
    
    # Build segment descriptions from transcript + timing
    words = transcript.split() if transcript else []
    
    scored = []
    for seg in segments:
        start = seg.get('start', 0)
        end = seg.get('end', 0)
        duration = end - start
        
        # Calculate scores
        scores = {
            'engagement': _score_engagement(start, end, engagement_data),
            'duration': _score_duration(duration),
            'position': _score_position(start, seg.get('videoDuration', 600)),
        }
        
        total_score = (
            scores['engagement'] * 0.5 +
            scores['duration'] * 0.3 +
            scores['position'] * 0.2
        )
        
        scored.append({
            **seg,
            'scores': scores,
            'highlightScore': round(total_score, 3),
            'isHighlight': total_score > 0.6
        })
    
    return sorted(scored, key=lambda x: x['highlightScore'], reverse=True)

def _score_engagement(start: float, end: float, engagement: dict) -> float:
    """Score based on engagement spikes"""
    if not engagement:
        return 0.5
    
    heatmap = engagement.get('viewerHeatmap', [])
    if not heatmap:
        return 0.5
    
    # Find engagement in this time range
    relevant = [p for p in heatmap if start <= p.get('time', 0) <= end]
    if not relevant:
        return 0.5
    
    avg_engagement = sum(p.get('value', 0) for p in relevant) / len(relevant)
    return min(1.0, avg_engagement)

def _score_duration(duration: float) -> float:
    """Prefer segments 15-60 seconds for highlights"""
    if 15 <= duration <= 60:
        return 1.0
    elif 10 <= duration < 15 or 60 < duration <= 90:
        return 0.7
    else:
        return 0.3

def _score_position(start: float, total_duration: float) -> float:
    """Score based on position (avoid very start/end)"""
    if total_duration == 0:
        return 0.5
    
    position = start / total_duration
    
    # Sweet spot: 10%-80% through video
    if 0.1 <= position <= 0.8:
        return 1.0
    else:
        return 0.5

def generate_highlight_reel(highlights: list, target_duration: int = 60) -> list:
    """Generate a highlight reel within target duration"""
    reel = []
    total_duration = 0
    
    for highlight in highlights:
        if not highlight.get('isHighlight'):
            continue
        
        seg_duration = highlight.get('end', 0) - highlight.get('start', 0)
        
        if total_duration + seg_duration <= target_duration:
            reel.append(highlight)
            total_duration += seg_duration
        
        if total_duration >= target_duration * 0.9:
            break
    
    return sorted(reel, key=lambda x: x.get('start', 0))

@app.route('/generate', methods=['POST'])
def generate_highlights():
    data = request.json
    video_id = data.get('videoId', '')
    segments = data.get('segments', [])
    transcript = data.get('transcript', '')
    engagement_data = data.get('engagementData', {})
    target_duration = data.get('targetDuration', 60)
    
    scored_segments = score_segments(segments, transcript, engagement_data)
    highlights = [s for s in scored_segments if s.get('isHighlight')]
    reel = generate_highlight_reel(highlights, target_duration)
    
    total_reel_duration = sum(
        s.get('end', 0) - s.get('start', 0) for s in reel
    )
    
    return jsonify({
        'videoId': video_id,
        'highlights': highlights[:10],  # Top 10
        'highlightReel': reel,
        'reelDuration': round(total_reel_duration, 1),
        'targetDuration': target_duration,
        'totalHighlights': len(highlights)
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'highlight-reel-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
