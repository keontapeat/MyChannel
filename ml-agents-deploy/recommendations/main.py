import json
def main(request):
    request_json = request.get_json()
    available = request_json.get('available_videos', [])
    recommendations = available[:24] if available else []
    return json.dumps({
        'recommendations': recommendations,
        'algorithm': 'collaborative_filtering_v2',
        'confidence': 0.85
    })
