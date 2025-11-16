import json

def main(request):
    """Ensures fair matchmaking for VS matches"""
    request_json = request.get_json()
    player1 = request_json.get('player1', {})
    player2 = request_json.get('player2', {})
    match_type = request_json.get('match_type', 'views')
    
    # Calculate skill ratings
    p1_rating = player1.get('avg_performance', 0)
    p2_rating = player2.get('avg_performance', 0)
    
    p1_wins = player1.get('total_wins', 0)
    p2_wins = player2.get('total_wins', 0)
    
    # Fairness score (closer to 1.0 = more fair)
    rating_diff = abs(p1_rating - p2_rating)
    fairness = max(0, 1.0 - (rating_diff / 100))
    
    # Predicted winner
    if p1_rating > p2_rating:
        predicted_winner = 'player1'
        win_probability = 0.5 + (rating_diff / 200)
    else:
        predicted_winner = 'player2'
        win_probability = 0.5 + (rating_diff / 200)
    
    return json.dumps({
        'fairness_score': fairness,
        'is_fair_match': fairness > 0.7,
        'predicted_winner': predicted_winner,
        'win_probability': min(win_probability, 0.95),
        'recommended_odds': {
            'player1': 1.0 / (p1_rating / (p1_rating + p2_rating)) if (p1_rating + p2_rating) > 0 else 2.0,
            'player2': 1.0 / (p2_rating / (p1_rating + p2_rating)) if (p1_rating + p2_rating) > 0 else 2.0
        },
        'platform_edge': 0.10
    })
