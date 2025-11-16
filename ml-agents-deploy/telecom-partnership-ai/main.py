import json
def main(request):
    return json.dumps({
        'recommended_partners': [
            {'name': 'T-Mobile', 'value': '100M users', 'deal_type': 'Zero-rating'},
            {'name': 'Vodafone', 'value': '300M users', 'deal_type': 'Preload'},
            {'name': 'China Mobile', 'value': '950M users', 'deal_type': 'Exclusive'}
        ],
        'total_addressable_users': '1.35B',
        'expected_conversion': 0.25
    })
