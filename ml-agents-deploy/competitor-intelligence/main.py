import json
def main(request):
    return json.dumps({
        'trending_on_competitors': [
            {'platform': 'youtube', 'trend': 'Gaming reactions', 'growth': 0.85},
            {'platform': 'tiktok', 'trend': 'Dance challenges', 'growth': 1.2}
        ],
        'recommended_content_strategy': 'Create gaming reaction videos',
        'expected_views': 500000,
        'market_gap_opportunity': 0.75
    })
