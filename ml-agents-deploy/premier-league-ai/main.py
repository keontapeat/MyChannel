import json
def main(request):
    return json.dumps({
        'deal_structure': 'Exclusive streaming (select regions)',
        'regions': ['Asia', 'MENA', 'Africa'],
        'deal_value': '1.2B/year (6 year deal)',
        'expected_subscribers': '60M',
        'revenue': '6B-18B/year'
    })
