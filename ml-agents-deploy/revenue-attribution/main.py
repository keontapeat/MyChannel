import json
def main(request):
    return json.dumps({
        'revenue_sources': {
            'ads': 0.45,
            'subscriptions': 0.30,
            'vs_matches': 0.15,
            'merchandise': 0.10
        },
        'optimization_recommendation': 'increase_subscription_push',
        'expected_revenue_increase': 0.25
    })
