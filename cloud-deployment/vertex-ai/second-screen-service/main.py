"""
Second Screen AI Service
Detect multi-device usage and optimize cross-device experience
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

def detect_second_screen(device_sessions: list) -> dict:
    if len(device_sessions) < 2:
        return {'isMultiDevice': False, 'devices': device_sessions, 'strategy': 'single_device'}

    # Sort by last active
    active = sorted(device_sessions, key=lambda x: x.get('lastActiveSec', 999))

    primary = active[0]
    secondary = active[1] if len(active) > 1 else None

    primary_type = primary.get('deviceType', 'mobile')
    secondary_type = secondary.get('deviceType', 'mobile') if secondary else None

    # Determine strategy
    strategy = _get_strategy(primary_type, secondary_type)

    # Cross-device continuity
    watching_video = primary.get('currentVideoId')
    continuation = {
        'videoId': watching_video,
        'position': primary.get('playbackPosition', 0),
        'canHandoff': watching_video is not None
    } if watching_video else None

    return {
        'isMultiDevice': True,
        'deviceCount': len(device_sessions),
        'primaryDevice': primary_type,
        'secondaryDevice': secondary_type,
        'strategy': strategy,
        'crossDeviceContinuity': continuation,
        'notifications': _get_cross_device_notifications(strategy),
        'syncEnabled': True
    }

def _get_strategy(primary: str, secondary: str) -> str:
    combos = {
        ('tv', 'mobile'): 'companion_app',         # Mobile as remote/companion
        ('mobile', 'tv'): 'cast_suggestion',        # Suggest casting to TV
        ('mobile', 'tablet'): 'handoff',            # Seamless handoff
        ('tablet', 'mobile'): 'handoff',
        ('desktop', 'mobile'): 'notification_sync', # Sync notifications
        ('mobile', 'desktop'): 'notification_sync',
        ('tv', 'tablet'): 'companion_app',
    }
    return combos.get((primary, secondary), 'sync_state')

def _get_cross_device_notifications(strategy: str) -> list:
    notifs = {
        'companion_app': ['Use phone as remote control', 'View video info on phone while watching on TV'],
        'cast_suggestion': ['Cast to TV for better experience', 'Tap to cast current video'],
        'handoff': ['Continue watching on this device', 'Pick up where you left off'],
        'notification_sync': ['Notifications synced across devices'],
        'sync_state': ['Watch history synced across all devices']
    }
    return notifs.get(strategy, [])

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    result = detect_second_screen(data.get('deviceSessions', []))
    return jsonify({'userId': data.get('userId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'second-screen-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
