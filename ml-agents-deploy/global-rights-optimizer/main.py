import json
def main(request):
    return json.dumps({
        'sports_packages': {
            'NFL': '2B/year',
            'NBA': '1.5B/year',
            'UFC': '800M/year',
            'Premier League': '1.2B/year',
            'La Liga': '600M/year',
            'Champions League': '1B/year'
        },
        'total_annual_cost': '7.1B/year',
        'expected_revenue': '25B-75B/year',
        'roi': '3.5x-10.5x'
    })
