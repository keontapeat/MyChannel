"""
App Crash Predictor AI Service
Predict iOS/Android crashes before they happen
"""
import os
import json
from flask import Flask, request, jsonify

app = Flask(__name__)

CRASH_RISK_FACTORS = {
    'memory_pressure': 0.35,
    'battery_low': 0.15,
    'network_instability': 0.10,
    'background_tasks': 0.15,
    'cpu_spike': 0.20,
    'storage_low': 0.05,
}

def predict_crash_risk(device_metrics: dict, session_metrics: dict) -> dict:
    risk_score = 0.0
    risk_factors = []

    # Memory pressure
    memory_usage_mb = device_metrics.get('memoryUsageMB', 0)
    memory_limit_mb = device_metrics.get('memoryLimitMB', 2048)
    memory_ratio = memory_usage_mb / max(memory_limit_mb, 1)
    if memory_ratio > 0.85:
        risk_score += CRASH_RISK_FACTORS['memory_pressure']
        risk_factors.append(f'Critical memory: {memory_ratio:.0%} used')
    elif memory_ratio > 0.70:
        risk_score += CRASH_RISK_FACTORS['memory_pressure'] * 0.5
        risk_factors.append(f'High memory: {memory_ratio:.0%} used')

    # Battery
    battery_level = device_metrics.get('batteryLevel', 1.0)
    is_low_power = device_metrics.get('isLowPowerMode', False)
    if battery_level < 0.1 or is_low_power:
        risk_score += CRASH_RISK_FACTORS['battery_low']
        risk_factors.append('Low battery / low power mode active')

    # CPU spike
    cpu_usage = device_metrics.get('cpuUsage', 0)
    if cpu_usage > 0.90:
        risk_score += CRASH_RISK_FACTORS['cpu_spike']
        risk_factors.append(f'CPU spike: {cpu_usage:.0%}')

    # Network instability
    packet_loss = session_metrics.get('networkPacketLoss', 0)
    if packet_loss > 0.1:
        risk_score += CRASH_RISK_FACTORS['network_instability']
        risk_factors.append(f'Network packet loss: {packet_loss:.0%}')

    # Storage
    storage_free_mb = device_metrics.get('storageFreeGB', 10) * 1024
    if storage_free_mb < 500:
        risk_score += CRASH_RISK_FACTORS['storage_low']
        risk_factors.append('Low storage space')

    # Background tasks
    bg_tasks = session_metrics.get('activeBackgroundTasks', 0)
    if bg_tasks > 5:
        risk_score += CRASH_RISK_FACTORS['background_tasks']
        risk_factors.append(f'{bg_tasks} background tasks running')

    # Recent crash history
    recent_crashes = session_metrics.get('recentCrashCount24h', 0)
    if recent_crashes > 0:
        risk_score += recent_crashes * 0.1
        risk_factors.append(f'{recent_crashes} crashes in last 24h')

    risk_score = min(round(risk_score, 3), 1.0)

    level = 'critical' if risk_score >= 0.7 else 'high' if risk_score >= 0.5 else 'medium' if risk_score >= 0.3 else 'low'

    actions = []
    if memory_ratio > 0.8:
        actions.append('clear_image_cache')
    if memory_ratio > 0.85:
        actions.append('pause_video_preloading')
    if cpu_usage > 0.9:
        actions.append('reduce_background_processing')
    if risk_score >= 0.7:
        actions.append('save_state_checkpoint')

    return {
        'crashRisk': risk_score,
        'riskLevel': level,
        'riskFactors': risk_factors,
        'recommendedActions': actions,
        'shouldWarnUser': risk_score >= 0.8,
        'shouldReduceQuality': risk_score >= 0.6
    }

@app.route('/predict', methods=['POST'])
def predict():
    data = request.json
    result = predict_crash_risk(
        data.get('deviceMetrics', {}),
        data.get('sessionMetrics', {})
    )
    return jsonify({'deviceId': data.get('deviceId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'app-crash-predictor'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
