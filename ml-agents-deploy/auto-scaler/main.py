import json
def main(request):
    request_json = request.get_json()
    current_load = request_json.get('current_load', 0.5)
    if current_load > 0.8:
        action = 'scale_up'
        instances = 10
    elif current_load < 0.3:
        action = 'scale_down'
        instances = 3
    else:
        action = 'maintain'
        instances = 5
    return json.dumps({
        'action': action,
        'recommended_instances': instances,
        'expected_cost_change': -0.15 if action == 'scale_down' else 0.25
    })
