"""
Beat Sync AI Service
Auto-sync video cuts to music beats for viral Shorts/Flicks
"""
import os
import json
import numpy as np
from flask import Flask, request, jsonify

app = Flask(__name__)

def detect_beats(audio_data: dict) -> list:
    """Detect beat timestamps from audio analysis data"""
    
    bpm = audio_data.get('bpm', 120)
    duration = audio_data.get('duration', 60)
    beat_strength = audio_data.get('beatStrength', [])  # Array of {time, strength}
    
    # If no beat data provided, generate from BPM
    if not beat_strength:
        beat_interval = 60.0 / bpm
        beats = []
        t = 0.0
        while t < duration:
            beats.append({
                'time': round(t, 3),
                'strength': 0.8,
                'isMajorBeat': (len(beats) % 4) == 0  # Every 4th beat is major
            })
            t += beat_interval
        return beats
    
    # Filter to significant beats
    avg_strength = sum(b['strength'] for b in beat_strength) / max(len(beat_strength), 1)
    significant_beats = [
        b for b in beat_strength
        if b['strength'] >= avg_strength * 0.7
    ]
    
    return significant_beats

def generate_cut_points(beats: list, scene_count: int, video_duration: float) -> list:
    """Generate optimal cut points aligned to beats"""
    
    if not beats:
        return []
    
    # Target cuts per scene
    major_beats = [b for b in beats if b.get('isMajorBeat', False)]
    
    if not major_beats:
        major_beats = beats[::4]  # Take every 4th beat
    
    # Distribute cuts evenly across scenes
    cuts_needed = scene_count - 1
    
    if cuts_needed <= 0:
        return []
    
    # Pick evenly spaced beats
    step = max(1, len(major_beats) // cuts_needed)
    cut_beats = major_beats[::step][:cuts_needed]
    
    cut_points = []
    for beat in cut_beats:
        cut_points.append({
            'time': beat['time'],
            'strength': beat.get('strength', 0.8),
            'isMajorBeat': beat.get('isMajorBeat', True),
            'description': f"Cut at {beat['time']:.2f}s"
        })
    
    return sorted(cut_points, key=lambda x: x['time'])

def generate_sync_instructions(scenes: list, beats: list, bpm: float) -> list:
    """Generate editing instructions for beat-synced video"""
    
    cut_points = generate_cut_points(beats, len(scenes), 0)
    instructions = []
    
    for i, scene in enumerate(scenes):
        if i < len(cut_points):
            beat = cut_points[i]
            instructions.append({
                'sceneIndex': i,
                'startTime': scene.get('start', 0),
                'cutAt': beat['time'],
                'beatStrength': beat['strength'],
                'instruction': f"Cut scene {i+1} at {beat['time']:.2f}s on {('major' if beat['isMajorBeat'] else 'minor')} beat"
            })
    
    return instructions

def calculate_sync_score(current_cuts: list, beats: list) -> dict:
    """Score how well current cuts align with beats"""
    
    if not current_cuts or not beats:
        return {'score': 0, 'grade': 'F', 'alignedCuts': 0, 'totalCuts': len(current_cuts)}
    
    beat_times = [b['time'] for b in beats]
    aligned = 0
    tolerance = 0.1  # 100ms tolerance
    
    for cut in current_cuts:
        cut_time = cut.get('time', 0)
        # Check if cut is near a beat
        nearest_beat = min(beat_times, key=lambda b: abs(b - cut_time))
        if abs(nearest_beat - cut_time) <= tolerance:
            aligned += 1
    
    score = int((aligned / len(current_cuts)) * 100)
    grade = 'A' if score >= 90 else 'B' if score >= 80 else 'C' if score >= 70 else 'D' if score >= 60 else 'F'
    
    return {
        'score': score,
        'grade': grade,
        'alignedCuts': aligned,
        'totalCuts': len(current_cuts)
    }

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    video_id = data.get('videoId', '')
    audio_data = data.get('audioData', {})
    scenes = data.get('scenes', [])
    current_cuts = data.get('currentCuts', [])
    
    beats = detect_beats(audio_data)
    cut_points = generate_cut_points(beats, max(len(scenes), 10), audio_data.get('duration', 60))
    instructions = generate_sync_instructions(scenes, beats, audio_data.get('bpm', 120))
    sync_score = calculate_sync_score(current_cuts, beats)
    
    return jsonify({
        'videoId': video_id,
        'bpm': audio_data.get('bpm', 120),
        'totalBeats': len(beats),
        'majorBeats': len([b for b in beats if b.get('isMajorBeat')]),
        'recommendedCutPoints': cut_points[:20],
        'editingInstructions': instructions,
        'currentSyncScore': sync_score,
        'isViralReady': sync_score['score'] >= 80
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'beat-sync-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
