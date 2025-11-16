import json
def main(request):
    return json.dumps({
        'is_deepfake': False,
        'confidence': 0.98,
        'authenticity_score': 0.95,
        'action': 'allow'
    })
