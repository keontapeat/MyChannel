import functions_framework
from flask import jsonify

@functions_framework.http
def dispute_resolution(request):
    """AI-powered dispute resolution."""
    data = request.get_json(silent=True) or {}
    
    match_id = data.get('matchId', '')
    player1_claim = data.get('player1Claim', '')
    player2_claim = data.get('player2Claim', '')
    evidence = data.get('evidence', [])
    
    # Simple sentiment analysis (in production, use Google NLP API)
    def simple_sentiment(text):
        if not text:
            return 0.0
        negative_words = ['cheat', 'lie', 'unfair', 'hack', 'fake', 'fraud']
        positive_words = ['fair', 'honest', 'good', 'real', 'true']
        
        text_lower = text.lower()
        neg_count = sum(1 for word in negative_words if word in text_lower)
        pos_count = sum(1 for word in positive_words if word in text_lower)
        
        if neg_count + pos_count == 0:
            return 0.0
        return (pos_count - neg_count) / (pos_count + neg_count)
    
    p1_sentiment = simple_sentiment(player1_claim)
    p2_sentiment = simple_sentiment(player2_claim)
    
    # Check evidence strength
    has_video = any('video' in str(e).lower() or 'mp4' in str(e).lower() for e in evidence)
    has_screenshot = any('screenshot' in str(e).lower() or 'png' in str(e).lower() or 'jpg' in str(e).lower() for e in evidence)
    
    evidence_strength = (0.5 if has_video else 0.0) + (0.3 if has_screenshot else 0.0)
    
    # Determine decision
    if evidence_strength > 0.6:
        decision = 'requires_manual_review'
        confidence = 0.7
        reasoning = f'Strong evidence provided ({len(evidence)} pieces). Requires human review.'
    elif evidence_strength > 0.3:
        decision = 'insufficient_evidence'
        confidence = 0.6
        reasoning = 'Some evidence provided but not conclusive.'
    else:
        decision = 'requires_manual_review'
        confidence = 0.4
        reasoning = 'Insufficient evidence. Escalating to human referee.'
    
    recommended_action = 'Escalate to human referee' if decision == 'requires_manual_review' else 'Close dispute'
    
    return jsonify({
        'matchId': match_id,
        'decision': decision,
        'confidence': confidence,
        'reasoning': reasoning,
        'recommendedAction': recommended_action,
        'player1Sentiment': p1_sentiment,
        'player2Sentiment': p2_sentiment,
        'evidenceStrength': evidence_strength
    })




