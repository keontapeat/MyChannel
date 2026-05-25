import json
def main(request):
    request_json = request.get_json()
    days_inactive = request_json.get('days_since_last_active', 0)
    if days_inactive > 14:
        churn_prob = 0.75
        risk = 'high'
    elif days_inactive > 7:
        churn_prob = 0.45
        risk = 'medium'
    else:
        churn_prob = 0.15
        risk = 'low'
    return json.dumps({
        'churn_probability': churn_prob,
        'risk_level': risk,
        'days_until_churn': max(1, 30 - days_inactive),
        'recommended_intervention': 'personalized_email' if risk == 'high' else 'none'
    })
