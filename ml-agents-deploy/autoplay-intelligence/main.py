import json
def main(request):
    request_json = request.get_json()
    candidates = request_json.get('candidate_videos', [])
    next_video = candidates[0] if candidates else None
    return json.dumps({
        'next_video': next_video,
        'autoplay_confidence': 0.85,
        'expected_continuation_rate': 0.75
    })
