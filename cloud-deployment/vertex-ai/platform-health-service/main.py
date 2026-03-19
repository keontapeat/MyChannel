"""
Platform Health AI Service
Overall platform health score - CEO/leadership KPI dashboard
"""
import os
import json
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

def calculate_platform_health(metrics: dict) -> dict:
    """Calculate comprehensive platform health score"""
    
    categories = {}
    
    # 1. Growth Health (25%)
    dau = metrics.get('dau', 0)
    mau = metrics.get('mau', 1)
    dau_mau_ratio = dau / max(mau, 1)
    new_users_7d = metrics.get('newUsers7d', 0)
    user_growth_rate = metrics.get('userGrowthRate', 0)
    
    growth_score = 0
    if dau_mau_ratio > 0.5: growth_score += 30
    elif dau_mau_ratio > 0.3: growth_score += 20
    else: growth_score += 10
    
    if user_growth_rate > 0.1: growth_score += 40
    elif user_growth_rate > 0.05: growth_score += 25
    elif user_growth_rate > 0: growth_score += 10
    
    if new_users_7d > 10000: growth_score += 30
    elif new_users_7d > 1000: growth_score += 20
    else: growth_score += 5
    
    categories['growth'] = {'score': min(100, growth_score), 'weight': 0.25}
    
    # 2. Engagement Health (25%)
    avg_session_duration = metrics.get('avgSessionDuration', 0)
    videos_per_session = metrics.get('videosPerSession', 0)
    retention_7d = metrics.get('retention7d', 0)
    
    engagement_score = 0
    if avg_session_duration > 1800: engagement_score += 35
    elif avg_session_duration > 900: engagement_score += 25
    else: engagement_score += 10
    
    if videos_per_session > 5: engagement_score += 35
    elif videos_per_session > 3: engagement_score += 20
    else: engagement_score += 5
    
    if retention_7d > 0.4: engagement_score += 30
    elif retention_7d > 0.25: engagement_score += 20
    else: engagement_score += 5
    
    categories['engagement'] = {'score': min(100, engagement_score), 'weight': 0.25}
    
    # 3. Revenue Health (20%)
    arpu = metrics.get('arpu', 0)  # Average revenue per user
    revenue_growth = metrics.get('revenueGrowthRate', 0)
    creator_earnings_total = metrics.get('creatorEarningsTotal', 0)
    
    revenue_score = 0
    if arpu > 5: revenue_score += 40
    elif arpu > 2: revenue_score += 25
    else: revenue_score += 10
    
    if revenue_growth > 0.2: revenue_score += 40
    elif revenue_growth > 0.1: revenue_score += 25
    else: revenue_score += 5
    
    if creator_earnings_total > 100000: revenue_score += 20
    elif creator_earnings_total > 10000: revenue_score += 10
    else: revenue_score += 5
    
    categories['revenue'] = {'score': min(100, revenue_score), 'weight': 0.20}
    
    # 4. Content Health (15%)
    videos_uploaded_7d = metrics.get('videosUploaded7d', 0)
    avg_video_quality_score = metrics.get('avgVideoQualityScore', 0.7)
    content_diversity_score = metrics.get('contentDiversityScore', 0.5)
    
    content_score = int((
        min(videos_uploaded_7d / 1000, 1.0) * 0.4 +
        avg_video_quality_score * 0.3 +
        content_diversity_score * 0.3
    ) * 100)
    
    categories['content'] = {'score': content_score, 'weight': 0.15}
    
    # 5. Safety Health (15%)
    toxicity_rate = metrics.get('toxicityRate', 0.05)
    fraud_rate = metrics.get('fraudRate', 0.01)
    copyright_violation_rate = metrics.get('copyrightViolationRate', 0.02)
    
    safety_score = 100
    safety_score -= min(40, int(toxicity_rate * 400))
    safety_score -= min(30, int(fraud_rate * 1000))
    safety_score -= min(30, int(copyright_violation_rate * 500))
    
    categories['safety'] = {'score': max(0, safety_score), 'weight': 0.15}
    
    # Calculate weighted overall score
    overall = sum(
        cat['score'] * cat['weight']
        for cat in categories.values()
    )
    overall = round(overall)
    
    # Status
    if overall >= 85: status = 'excellent'
    elif overall >= 70: status = 'healthy'
    elif overall >= 55: status = 'needs_attention'
    else: status = 'critical'
    
    # Generate executive summary
    summary = _generate_executive_summary(overall, categories, metrics)
    
    return {
        'overallScore': overall,
        'status': status,
        'grade': 'A' if overall >= 90 else 'B' if overall >= 80 else 'C' if overall >= 70 else 'D' if overall >= 60 else 'F',
        'categories': {k: {'score': v['score'], 'weight': v['weight']} for k, v in categories.items()},
        'executiveSummary': summary,
        'topIssues': _get_top_issues(categories),
        'topWins': _get_top_wins(categories),
        'timestamp': datetime.utcnow().isoformat()
    }

def _generate_executive_summary(score: int, categories: dict, metrics: dict) -> str:
    lowest = min(categories.items(), key=lambda x: x[1]['score'])
    highest = max(categories.items(), key=lambda x: x[1]['score'])
    
    return (
        f"Platform health at {score}/100. "
        f"Strongest area: {highest[0]} ({highest[1]['score']}/100). "
        f"Focus area: {lowest[0]} ({lowest[1]['score']}/100)."
    )

def _get_top_issues(categories: dict) -> list:
    issues = []
    for name, data in categories.items():
        if data['score'] < 60:
            issues.append(f"{name.capitalize()} needs urgent attention (score: {data['score']})")
    return issues[:3]

def _get_top_wins(categories: dict) -> list:
    wins = []
    for name, data in categories.items():
        if data['score'] >= 80:
            wins.append(f"{name.capitalize()} performing well (score: {data['score']})")
    return wins[:3]

@app.route('/score', methods=['POST'])
def score():
    data = request.json
    metrics = data.get('metrics', {})
    
    result = calculate_platform_health(metrics)
    return jsonify(result)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'platform-health-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
