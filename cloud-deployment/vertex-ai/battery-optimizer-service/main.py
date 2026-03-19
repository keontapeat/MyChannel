"""
Battery Optimizer AI Service
Optimize app behavior for battery life
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

def get_battery_optimizations(device_state: dict) -> dict:
    battery_level = device_state.get('batteryLevel', 1.0)
    is_charging = device_state.get('isCharging', False)
    is_low_power = device_state.get('isLowPowerMode', False)
    thermal_state = device_state.get('thermalState', 'nominal')  # nominal/fair/serious/critical
    cpu_usage = device_state.get('cpuUsage', 0.3)

    optimizations = []
    video_quality = 'auto'
    preload_count = 3
    background_refresh = True
    analytics_frequency = 'normal'
    animation_level = 'full'

    # Critical battery
    if battery_level < 0.10 and not is_charging:
        optimizations.append('reduce_video_quality_to_360p')
        optimizations.append('disable_video_preloading')
        optimizations.append('pause_background_sync')
        optimizations.append('reduce_animation_complexity')
        optimizations.append('disable_autoplay')
        video_quality = '360p'
        preload_count = 0
        background_refresh = False
        animation_level = 'minimal'

    # Low battery
    elif battery_level < 0.20 and not is_charging:
        optimizations.append('reduce_video_quality_to_480p')
        optimizations.append('reduce_preload_to_1_video')
        optimizations.append('reduce_analytics_frequency')
        video_quality = '480p'
        preload_count = 1
        analytics_frequency = 'reduced'

    # Low power mode
    elif is_low_power:
        optimizations.append('cap_video_quality_720p')
        optimizations.append('reduce_preload_to_2_videos')
        optimizations.append('reduce_background_refresh')
        video_quality = '720p'
        preload_count = 2
        animation_level = 'reduced'

    # Thermal throttling
    if thermal_state in ['serious', 'critical']:
        optimizations.append('reduce_cpu_intensive_processing')
        optimizations.append('pause_ml_inference')
        optimizations.append('reduce_video_quality')
        if video_quality == 'auto':
            video_quality = '720p'

    # High CPU
    if cpu_usage > 0.85:
        optimizations.append('defer_non_critical_work')
        optimizations.append('reduce_concurrent_operations')

    battery_drain_estimate = _estimate_drain_rate(device_state, video_quality)

    return {
        'optimizations': optimizations,
        'videoQuality': video_quality,
        'preloadCount': preload_count,
        'backgroundRefreshEnabled': background_refresh,
        'analyticsFrequency': analytics_frequency,
        'animationLevel': animation_level,
        'estimatedDrainPerHour': battery_drain_estimate,
        'thermalState': thermal_state,
        'recommendation': _get_recommendation(battery_level, is_charging, thermal_state)
    }

def _estimate_drain_rate(state: dict, quality: str) -> str:
    base = 0.08  # 8% per hour baseline
    quality_drain = {'360p': 0.05, '480p': 0.07, '720p': 0.10, '1080p': 0.14, 'auto': 0.10}
    total = base + quality_drain.get(quality, 0.10)
    if state.get('isLowPowerMode'): total *= 0.6
    return f"{total:.0%}/hour"

def _get_recommendation(level: float, charging: bool, thermal: str) -> str:
    if thermal in ['serious', 'critical']:
        return 'Device overheating - reduce usage to cool down'
    if level < 0.10 and not charging:
        return 'Plug in charger immediately for best experience'
    if level < 0.20 and not charging:
        return 'Low battery - connect charger soon'
    return 'Battery optimal'

@app.route('/optimize', methods=['POST'])
def optimize():
    data = request.json
    result = get_battery_optimizations(data.get('deviceState', {}))
    return jsonify({'deviceId': data.get('deviceId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'battery-optimizer-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
