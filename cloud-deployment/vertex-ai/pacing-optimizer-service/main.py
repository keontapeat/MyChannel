"""
Pacing Optimizer AI Service
Detect slow/fast pacing to improve viewer retention
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

def analyze_pacing(transcript: str, retention_data: list, duration: int) -> dict:
    """Analyze video pacing using transcript density and retention correlation"""
    
    words = transcript.split() if transcript else []
    words_per_second = len(words) / max(duration, 1)
    
    # Segment the video into 30-second chunks
    segments = []
    chunk_duration = 30
    
    for i in range(0, duration, chunk_duration):
        start = i
        end = min(i + chunk_duration, duration)
        
        # Words in this segment
        seg_start_word = int((start / duration) * len(words))
        seg_end_word = int((end / duration) * len(words))
        seg_words = words[seg_start_word:seg_end_word]
        
        # Words per second in segment
        seg_wps = len(seg_words) / (end - start)
        
        # Retention at this segment
        retention = _get_avg_retention(retention_data, start, end)
        
        # Classify pacing
        if seg_wps < words_per_second * 0.7:
            pacing = 'slow'
        elif seg_wps > words_per_second * 1.3:
            pacing = 'fast'
        else:
            pacing = 'optimal'
        
        segments.append({
            'start': start,
            'end': end,
            'wordsPerSecond': round(seg_wps, 2),
            'pacing': pacing,
            'retention': round(retention, 3),
            'needsEdit': pacing == 'slow' and retention < 0.6
        })
    
    # Overall pacing analysis
    slow_segments = [s for s in segments if s['pacing'] == 'slow']
    fast_segments = [s for s in segments if s['pacing'] == 'fast']
    
    overall_pacing = 'optimal'
    if len(slow_segments) > len(segments) * 0.4:
        overall_pacing = 'too_slow'
    elif len(fast_segments) > len(segments) * 0.4:
        overall_pacing = 'too_fast'
    
    # Get AI suggestions
    suggestions = _get_pacing_suggestions(segments, overall_pacing)
    
    # Estimated time savings if slow sections cut
    cuttable_duration = sum(
        s['end'] - s['start']
        for s in segments
        if s.get('needsEdit', False)
    )
    
    return {
        'overallPacing': overall_pacing,
        'avgWordsPerSecond': round(words_per_second, 2),
        'segments': segments,
        'slowSegmentCount': len(slow_segments),
        'fastSegmentCount': len(fast_segments),
        'cuttableDuration': round(cuttable_duration, 1),
        'estimatedRetentionGain': round(len(slow_segments) * 0.02, 3),
        'suggestions': suggestions,
        'pacingScore': _calculate_pacing_score(segments)
    }

def _get_avg_retention(retention_data: list, start: float, end: float) -> float:
    if not retention_data:
        return 0.7
    
    relevant = [p for p in retention_data if start <= p.get('time', 0) <= end]
    if not relevant:
        return 0.7
    
    return sum(p.get('value', 0.7) for p in relevant) / len(relevant)

def _calculate_pacing_score(segments: list) -> int:
    if not segments:
        return 50
    
    optimal = sum(1 for s in segments if s['pacing'] == 'optimal')
    return int((optimal / len(segments)) * 100)

def _get_pacing_suggestions(segments: list, overall: str) -> list:
    suggestions = []
    
    if overall == 'too_slow':
        suggestions.append('Speed up delivery - aim for 130-160 words per minute')
        suggestions.append('Cut dead air and long pauses in editing')
        
        slow_times = [f"{s['start']}s-{s['end']}s" for s in segments if s['pacing'] == 'slow'][:3]
        if slow_times:
            suggestions.append(f"Slowest sections: {', '.join(slow_times)} - consider cutting or speeding up')
    
    elif overall == 'too_fast':
        suggestions.append('Slow down delivery - viewers may be struggling to follow')
        suggestions.append('Add more pauses for emphasis on key points')
    
    else:
        suggestions.append('Pacing is well-optimized')
        suggestions.append('Continue maintaining consistent energy throughout')
    
    return suggestions

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    video_id = data.get('videoId', '')
    transcript = data.get('transcript', '')
    retention_data = data.get('retentionData', [])
    duration = data.get('duration', 600)
    
    analysis = analyze_pacing(transcript, retention_data, duration)
    
    return jsonify({
        'videoId': video_id,
        **analysis
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'pacing-optimizer-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
