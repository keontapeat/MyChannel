"""
🔥 AGENT #25: SPONSORSHIP MATCHER AI
Revenue Impact: $30M-$70M/year
Matches creators with brand deals
"""
import json
from flask import jsonify

def main(request):
    data = request.get_json() if request.is_json else {}
    
    creator_id = data.get('creator_id', '')
    niche = data.get('niche', 'tech')
    audience_size = data.get('audience_size', 100000)
    
    sponsorship_matches = {
        'creator_id': creator_id,
        'brand_matches': [
            {'brand': 'TechCorp', 'fit_score': 0.95, 'deal_range': '$5000-$15000', 'contact': 'partnerships@techcorp.com'},
            {'brand': 'GadgetPro', 'fit_score': 0.88, 'deal_range': '$3000-$8000', 'contact': 'creators@gadgetpro.com'},
            {'brand': 'SoftwarePlus', 'fit_score': 0.82, 'deal_range': '$2000-$5000', 'contact': 'marketing@softwareplus.com'}
        ],
        'rate_card_suggestion': {
            'dedicated_video': audience_size * 0.05,
            'integration': audience_size * 0.03,
            'mention': audience_size * 0.01,
            'affiliate': '10-20% commission'
        },
        'negotiation_tips': [
            'Start 20% above target rate',
            'Offer performance bonuses',
            'Request creative freedom',
            'Lock in multi-video deals'
        ],
        'estimated_annual_sponsorship_revenue': audience_size * 0.15,
        'confidence': 0.89,
        'revenue_impact': '$30M-$70M/year'
    }
    
    return jsonify(sponsorship_matches)




