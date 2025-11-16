import json
def main(request):
    request_json = request.get_json()
    video_data = request_json.get('video_data', {})
    duration = video_data.get('duration_seconds', 600)
    num_ads = max(1, duration // 300)
    positions = [i * (duration // num_ads) for i in range(1, num_ads + 1)]
    return json.dumps({
        'num_ads': num_ads,
        'ad_positions': positions,
        'predicted_cpm': 8.0,
        'expected_revenue': num_ads * 0.008
    })
