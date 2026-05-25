import json

def main(request):
    """Generates viral title suggestions"""
    request_json = request.get_json()
    video_data = request_json.get('video_data', {})
    
    original_title = video_data.get('title', '')
    category = video_data.get('category', 'general')
    
    # Viral title patterns
    patterns = [
        {'prefix': 'INSANE', 'expected_ctr': 0.15},
        {'prefix': 'UNBELIEVABLE', 'expected_ctr': 0.13},
        {'prefix': 'SHOCKING', 'expected_ctr': 0.12},
        {'prefix': 'SECRET', 'expected_ctr': 0.14},
        {'prefix': 'EXPOSED', 'expected_ctr': 0.16},
        {'prefix': 'I Tried', 'expected_ctr': 0.11},
        {'prefix': 'How I', 'expected_ctr': 0.10},
        {'prefix': '$1M', 'expected_ctr': 0.17}
    ]
    
    # Generate alternatives
    alternatives = []
    for pattern in patterns[:5]:
        alternatives.append({
            'title': f"{pattern['prefix']} {original_title}",
            'expected_ctr': pattern['expected_ctr'],
            'viral_score': pattern['expected_ctr'] * 5
        })
    
    # Add number-based titles
    alternatives.append({
        'title': f"7 SECRETS About {original_title}",
        'expected_ctr': 0.14,
        'viral_score': 0.70
    })
    
    best_title = max(alternatives, key=lambda x: x['expected_ctr'])
    
    return json.dumps({
        'original_title': original_title,
        'recommended_title': best_title,
        'alternative_titles': [a for a in alternatives if a != best_title],
        'expected_views_increase': 25000,
        'optimization_confidence': 0.88
    })
