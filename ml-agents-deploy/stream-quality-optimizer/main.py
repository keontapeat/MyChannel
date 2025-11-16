import json

def main(request):
    """Optimizes live stream quality dynamically"""
    request_json = request.get_json()
    stream_data = request_json.get('stream_data', {})
    
    current_bitrate = stream_data.get('bitrate', 5000)
    viewer_count = stream_data.get('viewer_count', 0)
    buffer_events = stream_data.get('buffer_events_per_minute', 0)
    avg_bandwidth = stream_data.get('avg_viewer_bandwidth', 10000)
    
    # Optimize bitrate
    if buffer_events > 2:
        recommended_bitrate = current_bitrate * 0.8
        quality_adjustment = 'decrease'
    elif buffer_events == 0 and avg_bandwidth > current_bitrate * 1.5:
        recommended_bitrate = current_bitrate * 1.2
        quality_adjustment = 'increase'
    else:
        recommended_bitrate = current_bitrate
        quality_adjustment = 'maintain'
    
    # Adaptive quality ladder
    quality_options = [
        {'bitrate': 6000, 'resolution': '1080p', 'viewers_percent': 0.4},
        {'bitrate': 4000, 'resolution': '720p', 'viewers_percent': 0.35},
        {'bitrate': 2500, 'resolution': '480p', 'viewers_percent': 0.15},
        {'bitrate': 1000, 'resolution': '360p', 'viewers_percent': 0.10}
    ]
    
    return json.dumps({
        'current_bitrate': current_bitrate,
        'recommended_bitrate': int(recommended_bitrate),
        'quality_adjustment': quality_adjustment,
        'quality_options': quality_options,
        'expected_buffer_reduction': 0.40,
        'expected_viewer_retention_increase': 0.12,
        'server_cost_per_hour': viewer_count * 0.02
    })
