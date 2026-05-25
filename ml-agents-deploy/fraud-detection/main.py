import json
def main(request):
    request_json = request.get_json()
    transaction = request_json.get('transaction_data', {})
    amount = transaction.get('amount', 0)
    if amount > 5000:
        risk = 0.85
    elif amount > 1000:
        risk = 0.55
    else:
        risk = 0.15
    return json.dumps({
        'fraud_probability': risk,
        'risk_level': 'high' if risk > 0.7 else 'medium' if risk > 0.4 else 'low',
        'should_block': risk > 0.8,
        'recommended_action': 'manual_review' if risk > 0.5 else 'approve'
    })
