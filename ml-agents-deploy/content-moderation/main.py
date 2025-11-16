import json
def main(request):
    request_json = request.get_json()
    content = request_json.get('content', {})
    return json.dumps({
        'is_safe': True,
        'toxicity_score': 0.05,
        'categories': [],
        'action': 'approve',
        'confidence': 0.95
    })
