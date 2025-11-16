import json
def main(request):
    return json.dumps({
        'deal_structure': 'Exclusive global streaming',
        'content': ['PPV events', 'Fight Nights', 'UFC Fight Pass', 'Behind scenes'],
        'deal_value': '800M/year (7 year deal)',
        'expected_subscribers': '25M',
        'revenue': '3B-8B/year'
    })
