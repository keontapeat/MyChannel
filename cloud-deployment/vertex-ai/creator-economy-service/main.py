"""
Creator Economy AI Service
Model and optimize the creator economy health
"""
import os
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

def analyze_creator_economy(metrics: dict) -> dict:
    total_creators = metrics.get('totalCreators', 0)
    active_creators = metrics.get('activeCreators30d', 0)
    monetized_creators = metrics.get('monetizedCreators', 0)
    avg_creator_revenue = metrics.get('avgCreatorRevenueMonthly', 0)
    top_creator_revenue = metrics.get('topCreatorRevenueMonthly', 0)
    creator_churn_rate = metrics.get('creatorMonthlyChurnRate', 0.05)
    new_creators_monthly = metrics.get('newCreatorsMonthly', 0)
    creator_satisfaction = metrics.get('creatorSatisfactionScore', 0.7)
    platform_take_rate = metrics.get('platformTakeRate', 0.30)

    # Activity rate
    activity_rate = active_creators / max(total_creators, 1)

    # Monetization rate
    monetization_rate = monetized_creators / max(total_creators, 1)

    # Creator LTV
    creator_ltv = avg_creator_revenue * (1 / max(creator_churn_rate, 0.001)) * (1 - platform_take_rate)

    # Revenue concentration (Gini-like)
    revenue_concentration = top_creator_revenue / max(avg_creator_revenue * 100, 1)

    # Economy health score
    health_score = 0
    health_score += min(activity_rate * 100, 25)
    health_score += min(monetization_rate * 100, 25)
    health_score += min(creator_satisfaction * 25, 25)
    health_score += 25 if creator_churn_rate < 0.05 else 15 if creator_churn_rate < 0.10 else 5

    health_score = min(round(health_score), 100)

    # Growth trajectory
    net_creator_growth = new_creators_monthly - (total_creators * creator_churn_rate)
    growth_trajectory = 'growing' if net_creator_growth > 0 else 'declining'

    recommendations = []
    if monetization_rate < 0.1:
        recommendations.append('Lower monetization bar - allow more creators to earn')
    if creator_satisfaction < 0.7:
        recommendations.append('Improve creator tools and support')
    if creator_churn_rate > 0.08:
        recommendations.append('Launch creator retention program')
    if platform_take_rate > 0.35:
        recommendations.append('Reduce platform take rate to attract top creators')
    if revenue_concentration > 0.5:
        recommendations.append('Invest in mid-tier creator growth programs')

    return {
        'economyHealthScore': health_score,
        'grade': 'A' if health_score >= 85 else 'B' if health_score >= 70 else 'C' if health_score >= 55 else 'D',
        'metrics': {
            'activityRate': round(activity_rate, 3),
            'monetizationRate': round(monetization_rate, 3),
            'creatorLtv': round(creator_ltv, 2),
            'revenueConcentration': round(revenue_concentration, 3),
            'netGrowthMonthly': round(net_creator_growth),
        },
        'growthTrajectory': growth_trajectory,
        'totalPlatformCreatorRevenue': round(avg_creator_revenue * monetized_creators),
        'recommendations': recommendations,
        'benchmarks': {
            'youtube': {'monetizationRate': 0.05, 'takeRate': 0.45},
            'tiktok': {'monetizationRate': 0.08, 'takeRate': 0.50},
            'myChannel': {'monetizationRate': round(monetization_rate, 3), 'takeRate': platform_take_rate}
        },
        'generatedAt': datetime.utcnow().isoformat()
    }

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    result = analyze_creator_economy(data.get('metrics', {}))
    return jsonify(result)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'creator-economy-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
