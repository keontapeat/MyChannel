import json
def main(request):
    return json.dumps({
        'is_spam': False,
        'spam_probability': 0.05,
        'action': 'allow',
        'confidence': 0.95
    })
