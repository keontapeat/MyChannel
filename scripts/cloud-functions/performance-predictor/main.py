import functions_framework
from flask import jsonify
from google.cloud import firestore
import math

db = firestore.Client()

@functions_framework.http
def performance_predictor(request):
    """Predict player performance and win probability."""
    data = request.get_json(silent=True) or {}
    
    action = data.get('action', 'analyzeSkill')
    
    if action == 'analyzeSkill':
        player_id = data.get('playerId', '')
        
        # Fetch player stats from Firestore
        try:
            stats_ref = db.collection('player_stats').document(player_id)
            stats_doc = stats_ref.get()
            
            if stats_doc.exists:
                stats = stats_doc.to_dict()
                wins = stats.get('wins', 0)
                losses = stats.get('losses', 0)
            else:
                wins = 0
                losses = 0
        except Exception:
            wins = 0
            losses = 0
        
        total_matches = wins + losses
        win_rate = wins / total_matches if total_matches > 0 else 0.5
        
        # Calculate ELO
        base_elo = 1000.0
        elo_adjustment = (win_rate - 0.5) * 400 * min(total_matches / 20.0, 1.0)
        elo_rating = base_elo + elo_adjustment
        
        # Data confidence based on match count
        data_confidence = min(1.0, total_matches / 30.0)
        
        return jsonify({
            'playerId': player_id,
            'eloRating': elo_rating,
            'winRate': win_rate,
            'totalMatches': total_matches,
            'recentForm': win_rate,
            'dataConfidence': data_confidence
        })
    
    elif action == 'predictWin':
        player1_elo = data.get('player1Elo', 1000)
        player2_elo = data.get('player2Elo', 1000)
        
        # ELO-based win probability
        elo_diff = player1_elo - player2_elo
        expected_p1 = 1.0 / (1.0 + math.pow(10, -elo_diff / 400.0))
        expected_p2 = 1.0 - expected_p1
        
        return jsonify({
            'player1WinProbability': expected_p1,
            'player2WinProbability': expected_p2,
            'confidence': 0.85
        })
    
    return jsonify({'error': 'Unknown action'}), 400




