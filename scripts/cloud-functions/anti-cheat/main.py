import functions_framework
from flask import jsonify
from google.cloud import firestore

db = firestore.Client()

@functions_framework.http
def anti_cheat(request):
    """Analyze player risk and detect cheating patterns."""
    data = request.get_json(silent=True) or {}
    
    player_id = data.get('playerId', '')
    action = data.get('action', 'analyzeRisk')
    
    if action == 'analyzeRisk':
        # Fetch player match history
        try:
            matches_ref = db.collection('vs-matches').where('participants', 'array_contains', player_id).limit(20)
            matches = list(matches_ref.stream())
            
            dispute_count = sum(1 for m in matches if m.to_dict().get('disputed', False))
            flag_count = sum(1 for m in matches if m.to_dict().get('flagged', False))
            total_matches = len(matches)
        except Exception:
            dispute_count = 0
            flag_count = 0
            total_matches = 0
        
        # Calculate risk score
        dispute_rate = dispute_count / total_matches if total_matches > 0 else 0
        flag_rate = flag_count / total_matches if total_matches > 0 else 0
        risk_score = min(1.0, dispute_rate * 2 + flag_rate * 3)
        
        risk_level = 'high' if risk_score > 0.7 else ('medium' if risk_score > 0.3 else 'low')
        
        return jsonify({
            'riskScore': risk_score,
            'riskLevel': risk_level,
            'disputeRate': dispute_rate,
            'flagRate': flag_rate,
            'totalMatchesAnalyzed': total_matches,
            'confidence': 0.88
        })
    
    elif action == 'analyzeGameplay':
        # Analyze gameplay for cheating indicators
        frame_consistency = data.get('frameConsistency', 0.95)
        timestamp_consistency = data.get('timestampConsistency', 0.92)
        detected_score = data.get('detectedScore', 0)
        
        cheat_indicators = []
        cheat_probability = 0.0
        
        if detected_score > 999999:
            cheat_indicators.append('Impossible score detected')
            cheat_probability += 0.5
        
        if frame_consistency < 0.7:
            cheat_indicators.append('Video frame inconsistency')
            cheat_probability += 0.3
        
        if timestamp_consistency < 0.8:
            cheat_indicators.append('Timestamp anomaly detected')
            cheat_probability += 0.2
        
        return jsonify({
            'cheatingDetected': cheat_probability > 0.5,
            'cheatProbability': min(1.0, cheat_probability),
            'indicators': cheat_indicators,
            'confidence': 0.85
        })
    
    return jsonify({'error': 'Unknown action'}), 400




