import json
def main(request):
    request_json = request.get_json()
    user_data = request_json.get('user_data', {})
    avg_watch = user_data.get('avg_watch_percentage', 0.5)
    return json.dumps({
        'optimization_strategy': 'front_load_hook' if avg_watch < 0.3 else 'mid_point_retention',
        'estimated_watch_time_increase': 0.25,
        'current_retention': avg_watch,
        'target_retention': min(avg_watch + 0.25, 0.95)
    })
