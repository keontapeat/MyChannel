"""
Sleep Mode AI Service
Detect when user fell asleep - auto-pause video
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

def detect_sleep(interaction_signals: dict) -> dict:
    last_interaction_seconds = interaction_signals.get('secondsSinceLastInteraction', 0)
    time_of_day = interaction_signals.get('timeOfDay', 12)
    session_duration = interaction_signals.get('sessionDurationSeconds', 0)
    screen_brightness = interaction_signals.get('screenBrightness', 1.0)
    device_orientation_stable = interaction_signals.get('orientationStableSeconds', 0)
    volume_level = interaction_signals.get('volumeLevel', 0.5)
    touch_pressure_history = interaction_signals.get('recentTouchPressures', [])

    sleep_score = 0.0
    signals = {}

    # No interaction for extended period
    if last_interaction_seconds > 1800:  # 30 min
        sleep_score += 0.5
        signals['long_inactivity'] = True
    elif last_interaction_seconds > 900:  # 15 min
        sleep_score += 0.3
        signals['moderate_inactivity'] = True
    elif last_interaction_seconds > 300:  # 5 min
        sleep_score += 0.1

    # Late night + long session = high sleep probability
    is_late_night = time_of_day >= 22 or time_of_day <= 4
    if is_late_night:
        sleep_score += 0.2
        signals['late_night'] = True

    # Long session without interaction
    if session_duration > 3600 and last_interaction_seconds > 600:
        sleep_score += 0.15
        signals['long_session'] = True

    # Very low brightness (often set before sleep)
    if screen_brightness < 0.1:
        sleep_score += 0.1
        signals['low_brightness'] = True

    # Device hasn't moved (lying flat, stable)
    if device_orientation_stable > 600:
        sleep_score += 0.1
        signals['device_stationary'] = True

    # Decreasing touch pressure (finger relaxing)
    if len(touch_pressure_history) >= 3:
        recent = touch_pressure_history[-3:]
        if all(recent[i] > recent[i+1] for i in range(len(recent)-1)):
            sleep_score += 0.1
            signals['decreasing_pressure'] = True

    sleep_score = min(round(sleep_score, 3), 1.0)
    is_asleep = sleep_score >= 0.5

    # Recommended action
    if sleep_score >= 0.7:
        action = 'pause_and_show_sleep_prompt'
        message = "You fell asleep. Resume where you left off?"
    elif sleep_score >= 0.5:
        action = 'show_subtle_prompt'
        message = "Still watching?"
    elif sleep_score >= 0.3:
        action = 'monitor'
        message = None
    else:
        action = 'continue'
        message = None

    return {
        'isSleeping': is_asleep,
        'sleepScore': sleep_score,
        'signals': signals,
        'action': action,
        'promptMessage': message,
        'sleepTimerSuggestion': _suggest_sleep_timer(time_of_day, session_duration)
    }

def _suggest_sleep_timer(hour: int, session_seconds: int) -> dict:
    if hour >= 22 or hour <= 2:
        return {'suggest': True, 'minutes': 30, 'message': 'Set a sleep timer?'}
    elif session_seconds > 5400:  # 90+ min
        return {'suggest': True, 'minutes': 60, 'message': 'Taking a break soon?'}
    return {'suggest': False, 'minutes': 0, 'message': None}

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    result = detect_sleep(data.get('interactionSignals', {}))
    return jsonify({'userId': data.get('userId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'sleep-mode-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
