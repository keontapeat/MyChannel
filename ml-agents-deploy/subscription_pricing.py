import json

def main(request):
    """Predicts optimal subscription price"""
    request_json = request.get_json()
    user_data = request_json.get('user_data', {})
    
    watch_time = user_data.get('watch_time_minutes', 0)
    engagement_score = user_data.get('engagement_score', 0)
    has_wagered = user_data.get('has_wagered', False)
    avg_wager = user_data.get('avg_wager_amount', 0)
    
    # Calculate optimal price
    if watch_time > 500 and engagement_score > 0.7:
        price = 19.99
        conversion = 0.65
    elif has_wagered and avg_wager > 100:
        price = 29.99
        conversion = 0.45
    elif watch_time > 100:
        price = 14.99
        conversion = 0.70
    else:
        price = 9.99
        conversion = 0.80
    
    return json.dumps({
        'recommended_price': price,
        'conversion_probability': conversion,
        'expected_revenue': price * conversion,
        'offer_type': 'annual' if watch_time > 300 else 'monthly'
    })
