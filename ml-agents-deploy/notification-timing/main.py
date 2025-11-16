import json
def main(request):
    request_json = request.get_json()
    user_data = request_json.get('user_data', {})
    pattern = user_data.get('engagement_pattern', 'evening')
    best_hour = 19 if pattern == 'evening' else 8
    return json.dumps({
        'optimal_send_time_hour': best_hour,
        'expected_click_through_rate': 0.35,
        'send_immediately': False
    })
