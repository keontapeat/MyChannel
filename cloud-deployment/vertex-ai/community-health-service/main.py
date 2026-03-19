"""
Community Health AI Service
Score overall community health - proactive platform safety
"""
import os
import json
from flask import Flask, request, jsonify
from datetime import datetime, timedelta

app = Flask(__name__)

def calculate_community_health(metrics: dict) -> dict:
    """Calculate a comprehensive community health score 0-100"""
    
    scores = {}
    issues = []
    recommendations = []
    
    # 1. Toxicity Rate (lower = better)
    toxicity_rate = metrics.get('toxicityRate', 0.05)
    if toxicity_rate < 0.02:
        scores['toxicity'] = 100
    elif toxicity_rate < 0.05:
        scores['toxicity'] = 80
    elif toxicity_rate < 0.10:
        scores['toxicity'] = 60
        issues.append(f'Elevated toxicity rate: {toxicity_rate:.1%}')
        recommendations.append('Increase moderation sensitivity')
    else:
        scores['toxicity'] = max(0, int(40 - toxicity_rate * 200))
        issues.append(f'High toxicity rate: {toxicity_rate:.1%} - urgent action needed')
        recommendations.append('Enable emergency moderation mode')
    
    # 2. Spam Rate (lower = better)
    spam_rate = metrics.get('spamRate', 0.03)
    if spam_rate < 0.02:
        scores['spam'] = 100
    elif spam_rate < 0.05:
        scores['spam'] = 80
    else:
        scores['spam'] = max(0, int(60 - spam_rate * 400))
        issues.append(f'Spam rate elevated: {spam_rate:.1%}')
        recommendations.append('Increase spam filtering threshold')
    
    # 3. Engagement Quality (higher = better)
    positive_comment_ratio = metrics.get('positiveCommentRatio', 0.7)
    scores['engagement_quality'] = int(positive_comment_ratio * 100)
    if positive_comment_ratio < 0.5:
        issues.append('Low positive engagement ratio')
        recommendations.append('Promote positive community interactions')
    
    # 4. Creator Satisfaction (higher = better)
    creator_satisfaction = metrics.get('creatorSatisfaction', 0.75)
    scores['creator_satisfaction'] = int(creator_satisfaction * 100)
    if creator_satisfaction < 0.6:
        issues.append('Creator satisfaction below threshold')
        recommendations.append('Review creator support and monetization policies')
    
    # 5. New User Retention (higher = better)
    new_user_retention = metrics.get('newUserRetention7d', 0.4)
    if new_user_retention > 0.5:
        scores['new_user_retention'] = 100
    elif new_user_retention > 0.3:
        scores['new_user_retention'] = 70
    else:
        scores['new_user_retention'] = int(new_user_retention * 200)
        issues.append(f'Low new user retention: {new_user_retention:.1%}')
        recommendations.append('Improve onboarding experience')
    
    # 6. Report Resolution Rate (higher = better)
    report_resolution_rate = metrics.get('reportResolutionRate', 0.8)
    scores['report_resolution'] = int(report_resolution_rate * 100)
    if report_resolution_rate < 0.7:
        issues.append('Report resolution rate too low')
        recommendations.append('Increase trust & safety team capacity')
    
    # 7. Active Creator Ratio (higher = better)
    active_creator_ratio = metrics.get('activeCreatorRatio', 0.3)
    scores['creator_activity'] = min(100, int(active_creator_ratio * 300))
    
    # 8. Harassment Report Rate (lower = better)
    harassment_rate = metrics.get('harassmentReportRate', 0.02)
    if harassment_rate < 0.01:
        scores['harassment'] = 100
    elif harassment_rate < 0.03:
        scores['harassment'] = 70
    else:
        scores['harassment'] = max(0, int(50 - harassment_rate * 1000))
        issues.append(f'Harassment reports elevated: {harassment_rate:.1%}')
        recommendations.append('Review anti-harassment policies')
    
    # Weighted overall score
    weights = {
        'toxicity': 0.25,
        'spam': 0.10,
        'engagement_quality': 0.15,
        'creator_satisfaction': 0.15,
        'new_user_retention': 0.10,
        'report_resolution': 0.10,
        'creator_activity': 0.10,
        'harassment': 0.05
    }
    
    overall = sum(scores[k] * weights[k] for k in scores)
    overall = round(overall)
    
    # Grade
    if overall >= 90: grade = 'A'
    elif overall >= 80: grade = 'B'
    elif overall >= 70: grade = 'C'
    elif overall >= 60: grade = 'D'
    else: grade = 'F'
    
    # Alert level
    if overall >= 80: alert_level = 'healthy'
    elif overall >= 60: alert_level = 'warning'
    else: alert_level = 'critical'
    
    return {
        'overallScore': overall,
        'grade': grade,
        'alertLevel': alert_level,
        'categoryScores': scores,
        'issues': issues,
        'recommendations': recommendations,
        'trending': _calculate_trend(metrics),
        'benchmarkComparison': _compare_to_benchmark(overall)
    }

def _calculate_trend(metrics: dict) -> str:
    prev_score = metrics.get('previousScore', 75)
    current = metrics.get('currentScore', 75)
    delta = current - prev_score
    if delta > 3: return 'improving'
    if delta < -3: return 'declining'
    return 'stable'

def _compare_to_benchmark(score: int) -> dict:
    return {
        'youtubeEstimate': 72,
        'tiktokEstimate': 68,
        'twitchEstimate': 65,
        'myChannelScore': score,
        'isAboveBenchmark': score > 72
    }

@app.route('/score', methods=['POST'])
def score():
    data = request.json
    platform_metrics = data.get('metrics', {})
    
    result = calculate_community_health(platform_metrics)
    
    return jsonify({
        'timestamp': datetime.utcnow().isoformat(),
        **result
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'community-health-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
