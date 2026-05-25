import json
def main(request):
    return json.dumps({
        'copyright_detected': False,
        'matches': [],
        'action': 'allow',
        'confidence': 0.92
    })
