"""
Data Exfiltration Detection AI Service
Detect data theft attempts in real-time
"""
import os
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

def detect_exfiltration(activity: dict) -> dict:
    risk_score = 0.0
    indicators = []

    # Bulk data access
    records_accessed = activity.get('recordsAccessedInWindow', 0)
    if records_accessed > 10000:
        risk_score += 0.5
        indicators.append(f'Bulk data access: {records_accessed:,} records')
    elif records_accessed > 1000:
        risk_score += 0.3
        indicators.append(f'High data access: {records_accessed:,} records')

    # Unusual API endpoint patterns
    api_calls = activity.get('apiCallsPerMinute', 0)
    normal_api_rate = activity.get('normalApiRate', 10)
    if api_calls > normal_api_rate * 10:
        risk_score += 0.35
        indicators.append(f'API call spike: {api_calls}/min (normal: {normal_api_rate}/min)')

    # Data export attempts
    export_attempts = activity.get('dataExportAttempts', 0)
    if export_attempts > 3:
        risk_score += 0.4
        indicators.append(f'{export_attempts} data export attempts')

    # Accessing sensitive endpoints
    sensitive_endpoints_hit = activity.get('sensitiveEndpointsAccessed', [])
    if len(sensitive_endpoints_hit) >= 3:
        risk_score += 0.3
        indicators.append(f'Sensitive endpoints accessed: {sensitive_endpoints_hit}')

    # Large outbound data transfer
    outbound_mb = activity.get('outboundDataMB', 0)
    if outbound_mb > 500:
        risk_score += 0.4
        indicators.append(f'Large outbound transfer: {outbound_mb:.0f}MB')
    elif outbound_mb > 100:
        risk_score += 0.2

    # Off-hours access
    hour = datetime.utcnow().hour
    is_off_hours = hour < 6 or hour > 22
    if is_off_hours and records_accessed > 100:
        risk_score += 0.15
        indicators.append('Off-hours bulk access')

    # Scraping patterns (sequential ID access)
    sequential_access = activity.get('sequentialIdAccess', False)
    if sequential_access:
        risk_score += 0.3
        indicators.append('Sequential ID scraping detected')

    risk_score = min(round(risk_score, 3), 1.0)
    severity = 'critical' if risk_score >= 0.8 else 'high' if risk_score >= 0.6 else 'medium' if risk_score >= 0.3 else 'low'

    actions = []
    if risk_score >= 0.7:
        actions.extend(['terminate_session', 'block_ip', 'alert_security_team'])
    elif risk_score >= 0.5:
        actions.extend(['rate_limit_aggressive', 'require_reauth', 'log_for_review'])
    elif risk_score >= 0.3:
        actions.append('increase_monitoring')

    return {
        'riskScore': risk_score,
        'severity': severity,
        'indicators': indicators,
        'actions': actions,
        'isExfiltration': risk_score >= 0.6,
        'timestamp': datetime.utcnow().isoformat()
    }

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    result = detect_exfiltration(data.get('activity', {}))
    return jsonify({'userId': data.get('userId', ''), 'ipAddress': data.get('ipAddress', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'data-exfiltration-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
