import json

def main(request):
    """Optimizes creator revenue strategies"""
    request_json = request.get_json()
    creator_data = request_json.get('creator_data', {})
    
    subscribers = creator_data.get('subscribers', 0)
    avg_views = creator_data.get('avg_views_per_video', 0)
    engagement_rate = creator_data.get('engagement_rate', 0)
    current_revenue = creator_data.get('monthly_revenue', 0)
    
    # Calculate potential revenue streams
    revenue_streams = []
    
    # Ad revenue
    if avg_views > 1000:
        ad_revenue = avg_views * 0.005 * 30
        revenue_streams.append({
            'type': 'ad_revenue',
            'current': current_revenue * 0.4,
            'potential': ad_revenue,
            'increase': ad_revenue - (current_revenue * 0.4)
        })
    
    # Sponsorships
    if subscribers > 10000:
        sponsor_revenue = subscribers * 0.1
        revenue_streams.append({
            'type': 'sponsorships',
            'current': current_revenue * 0.2,
            'potential': sponsor_revenue,
            'increase': sponsor_revenue - (current_revenue * 0.2)
        })
    
    # Memberships
    if subscribers > 1000:
        member_revenue = subscribers * 0.05 * 4.99
        revenue_streams.append({
            'type': 'memberships',
            'current': current_revenue * 0.15,
            'potential': member_revenue,
            'increase': member_revenue - (current_revenue * 0.15)
        })
    
    # VS Matches
    if engagement_rate > 0.10:
        vs_revenue = avg_views * 0.02
        revenue_streams.append({
            'type': 'vs_matches',
            'current': current_revenue * 0.1,
            'potential': vs_revenue,
            'increase': vs_revenue - (current_revenue * 0.1)
        })
    
    # Merchandise
    if subscribers > 5000:
        merch_revenue = subscribers * 0.03 * 20
        revenue_streams.append({
            'type': 'merchandise',
            'current': current_revenue * 0.15,
            'potential': merch_revenue,
            'increase': merch_revenue - (current_revenue * 0.15)
        })
    
    total_potential = sum(s['potential'] for s in revenue_streams)
    
    return json.dumps({
        'current_monthly_revenue': current_revenue,
        'potential_monthly_revenue': total_potential,
        'revenue_increase': total_potential - current_revenue,
        'revenue_streams': revenue_streams,
        'top_recommendation': max(revenue_streams, key=lambda x: x['increase'])['type'] if revenue_streams else 'increase_content_output'
    })
