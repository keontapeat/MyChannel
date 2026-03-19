"""
Account Takeover AI Service
Detect account takeovers in real-time before damage is done
"""
import os
import json
import math
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

def calculate_takeover_risk(signals: dict) -> dict:
    """Real-time account takeover risk scoring"""
    
    risk_factors = {}
    risk_score = 0.0
    alerts = []
    
    # 1. Location anomaly
    usual_country = signals.get('usualCountry', '')
    current_country = signals.get('currentCountry', '')
    usual_city = signals.get('usualCity', '')
    current_city = signals.get('currentCity', '')
    
    if usual_country and current_country and usual_country != current_country:
        risk_factors['location_anomaly'] = 0.4
        risk_score += 0.4
        alerts.append(f'Login from new country: {current_country} (usual: {usual_country})')
    elif usual_city and current_city and usual_city != current_city:
        risk_factors['location_anomaly'] = 0.2
        risk_score += 0.2
        alerts.append(f'Login from new city: {current_city}')
    else:
        risk_factors['location_anomaly'] = 0.0
    
    # 2. Device anomaly
    known_devices = signals.get('knownDeviceIds', [])
    current_device = signals.get('currentDeviceId', '')
    
    if current_device and current_device not in known_devices:
        risk_factors['new_device'] = 0.3
        risk_score += 0.3
        alerts.append('Login from unrecognized device')
    else:
        risk_factors['new_device'] = 0.0
    
    # 3. Time anomaly
    usual_login_hours = signals.get('usualLoginHours', list(range(8, 23)))
    current_hour = datetime.utcnow().hour
    
    if current_hour not in usual_login_hours:
        risk_factors['time_anomaly'] = 0.15
        risk_score += 0.15
        alerts.append(f'Login at unusual time: {current_hour}:00 UTC')
    else:
        risk_factors['time_anomaly'] = 0.0
    
    # 4. Rapid action anomaly (many actions in short time)
    actions_per_minute = signals.get('actionsPerMinute', 1.0)
    if actions_per_minute > 20:
        risk_factors['rapid_actions'] = 0.35
        risk_score += 0.35
        alerts.append(f'Unusually rapid actions: {actions_per_minute:.0f}/min (possible bot)')
    elif actions_per_minute > 10:
        risk_factors['rapid_actions'] = 0.15
        risk_score += 0.15
    else:
        risk_factors['rapid_actions'] = 0.0
    
    # 5. Suspicious actions
    suspicious_actions = signals.get('suspiciousActions', [])
    suspicious_weights = {
        'password_change': 0.3,
        'email_change': 0.4,
        'payment_method_change': 0.35,
        'mass_unfollow': 0.2,
        'mass_delete': 0.4,
        'withdrawal_attempt': 0.45,
        'api_key_access': 0.25
    }
    
    for action in suspicious_actions:
        weight = suspicious_weights.get(action, 0.1)
        risk_factors[f'action_{action}'] = weight
        risk_score += weight
        alerts.append(f'Suspicious action detected: {action}')
    
    # 6. Failed login attempts
    failed_attempts = signals.get('recentFailedAttempts', 0)
    if failed_attempts >= 5:
        risk_factors['brute_force'] = 0.5
        risk_score += 0.5
        alerts.append(f'{failed_attempts} failed login attempts before success')
    elif failed_attempts >= 3:
        risk_factors['brute_force'] = 0.2
        risk_score += 0.2
    else:
        risk_factors['brute_force'] = 0.0
    
    # 7. VPN/Proxy/Tor detection
    is_vpn = signals.get('isVPN', False)
    is_tor = signals.get('isTor', False)
    
    if is_tor:
        risk_factors['anonymizer'] = 0.4
        risk_score += 0.4
        alerts.append('Login via Tor network')
    elif is_vpn:
        risk_factors['anonymizer'] = 0.1
        risk_score += 0.1
    else:
        risk_factors['anonymizer'] = 0.0
    
    # Cap at 1.0
    risk_score = min(round(risk_score, 3), 1.0)
    
    # Determine action
    if risk_score >= 0.8:
        action_required = 'block_and_notify'
        severity = 'critical'
    elif risk_score >= 0.6:
        action_required = 'require_2fa'
        severity = 'high'
    elif risk_score >= 0.4:
        action_required = 'send_alert_email'
        severity = 'medium'
    elif risk_score >= 0.2:
        action_required = 'monitor'
        severity = 'low'
    else:
        action_required = 'allow'
        severity = 'none'
    
    return {
        'riskScore': risk_score,
        'severity': severity,
        'actionRequired': action_required,
        'riskFactors': risk_factors,
        'alerts': alerts,
        'isTakeover': risk_score >= 0.7,
        'requiresMFA': risk_score >= 0.5,
        'sessionId': signals.get('sessionId', ''),
        'timestamp': datetime.utcnow().isoformat()
    }

@app.route('/assess', methods=['POST'])
def assess():
    data = request.json
    user_id = data.get('userId', '')
    signals = data.get('signals', {})
    
    result = calculate_takeover_risk(signals)
    
    # Log high-risk events
    if result['severity'] in ['high', 'critical']:
        print(f"🚨 HIGH RISK LOGIN: user={user_id}, score={result['riskScore']}, action={result['actionRequired']}")
    
    return jsonify({
        'userId': user_id,
        **result
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'account-takeover-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
