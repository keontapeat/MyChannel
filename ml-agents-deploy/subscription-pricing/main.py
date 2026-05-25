import json
def main(request):
    request_json = request.get_json()
    user_data = request_json.get('user_data', {})
    watch_time = user_data.get('watch_time_minutes', 0)
    engagement = user_data.get('engagement_score', 0)
    has_wagered = user_data.get('has_wagered', False)
    if watch_time > 400 and engagement > 0.7:
        price = 29.99
        conv = 0.45
    elif watch_time > 200:
        price = 19.99
        conv = 0.35
    else:
        price = 14.99
        conv = 0.25
    if has_wagered:
        conv += 0.10
    return json.dumps({
        'recommended_price': price,
        'conversion_probability': conv,
        'expected_revenue': price * conv,
        'offer_type': 'annual' if price > 20 else 'monthly'
    })
