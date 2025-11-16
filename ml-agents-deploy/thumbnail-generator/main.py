import json
import random

def main(request):
    """Generates AI thumbnail recommendations"""
    request_json = request.get_json()
    video_data = request_json.get('video_data', {})
    
    title = video_data.get('title', '')
    category = video_data.get('category', 'general')
    
    # Generate thumbnail styles
    styles = []
    
    # Face close-up style
    styles.append({
        'style': 'face_closeup',
        'description': 'Extreme close-up of face with shocked expression',
        'elements': ['face', 'arrows', 'text_overlay'],
        'colors': ['red', 'yellow', 'white'],
        'expected_ctr': 0.12,
        'viral_score': 0.85
    })
    
    # Split screen style
    styles.append({
        'style': 'split_screen',
        'description': 'Before/After or comparison split',
        'elements': ['split_line', 'vs_text', 'contrasting_images'],
        'colors': ['blue', 'red', 'white'],
        'expected_ctr': 0.10,
        'viral_score': 0.75
    })
    
    # Text-heavy style
    styles.append({
        'style': 'text_heavy',
        'description': 'Large bold text with emoji',
        'elements': ['large_text', 'emoji', 'minimal_background'],
        'colors': ['black', 'yellow', 'white'],
        'expected_ctr': 0.09,
        'viral_score': 0.70
    })
    
    # Best style based on category
    if category == 'gaming':
        best_style = styles[0]
    elif category == 'how_to':
        best_style = styles[1]
    else:
        best_style = max(styles, key=lambda x: x['expected_ctr'])
    
    return json.dumps({
        'recommended_style': best_style,
        'alternative_styles': [s for s in styles if s != best_style],
        'ai_generated_prompt': f'Create {best_style["style"]} thumbnail for: {title}',
        'expected_ctr_increase': 0.08,
        'estimated_additional_views': 15000
    })
