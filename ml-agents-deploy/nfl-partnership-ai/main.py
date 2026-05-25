import json
def main(request):
    return json.dumps({
        'deal_structure': 'Exclusive streaming rights',
        'content': ['Live games', 'RedZone', 'NFL Network', 'GamePass'],
        'deal_value': '2B/year (10 year deal)',
        'expected_subscribers': '50M',
        'revenue': '5B-15B/year'
    })
