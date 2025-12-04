import functions_framework
from flask import jsonify
import math

@functions_framework.http
def match_fairness(request):
    """Evaluate match fairness based on player ELO ratings."""
    data = request.get_json(silent=True) or {}
    
    player1_elo = data.get('player1Elo', 1000)
    player2_elo = data.get('player2Elo', 1000)
    wager_amount = data.get('wagerAmount', 0)
    
    # Calculate ELO difference
    elo_diff = abs(player1_elo - player2_elo)
    
    # Fairness score (1.0 = perfect, decreases with ELO gap)
    fairness_score = max(0.5, 1.0 - (elo_diff / 800.0))
    
    # Win probability using ELO formula
    expected_p1 = 1.0 / (1.0 + math.pow(10, (player2_elo - player1_elo) / 400.0))
    expected_p2 = 1.0 - expected_p1
    
    # Recommended duration based on wager
    base_duration = 3600  # 1 hour
    duration_multiplier = 1.0 + (wager_amount / 1000.0) * 0.5
    recommended_duration = min(base_duration * duration_multiplier, 14400)  # Max 4 hours
    
    return jsonify({
        'fairnessScore': fairness_score,
        'eloDifference': elo_diff,
        'player1WinProbability': expected_p1,
        'player2WinProbability': expected_p2,
        'recommendedDuration': recommended_duration,
        'warnings': ['Large skill gap detected'] if elo_diff > 300 else [],
        'confidence': 0.95
    })




