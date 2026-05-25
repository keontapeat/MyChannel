import json
def main(request):
    return json.dumps({
        'deal_structure': 'Co-exclusive streaming',
        'content': ['Regular season', 'Playoffs', 'Finals', 'League Pass'],
        'deal_value': '1.5B/year (8 year deal)',
        'expected_subscribers': '40M',
        'revenue': '4B-12B/year'
    })
