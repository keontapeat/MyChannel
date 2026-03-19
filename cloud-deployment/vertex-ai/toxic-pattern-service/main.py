"""
Toxic Pattern AI Service
Detect coordinated harassment campaigns before they escalate
"""
import os
from flask import Flask, request, jsonify
from datetime import datetime, timedelta
from collections import defaultdict

app = Flask(__name__)

def detect_coordinated_harassment(reports: list, target_user_id: str, window_minutes: int = 60) -> dict:
    if not reports:
        return {'isCoordinated': False, 'riskLevel': 'low', 'actions': []}

    now = datetime.utcnow()
    window_start = now - timedelta(minutes=window_minutes)

    # Filter to recent reports
    recent = [r for r in reports if _parse_time(r.get('timestamp', '')) >= window_start]

    if not recent:
        return {'isCoordinated': False, 'riskLevel': 'low', 'actions': []}

    # Analyze patterns
    unique_reporters = set(r.get('reporterId', '') for r in recent)
    report_types = defaultdict(int)
    account_ages = []

    for r in recent:
        report_types[r.get('type', 'unknown')] += 1
        age_days = r.get('reporterAccountAgeDays', 365)
        account_ages.append(age_days)

    # Signals of coordinated attack
    signals = {}

    # Many reporters in short window
    signals['volume_spike'] = len(recent) >= 5
    signals['many_unique_reporters'] = len(unique_reporters) >= 4

    # New accounts (common in coordinated attacks)
    avg_account_age = sum(account_ages) / max(len(account_ages), 1)
    signals['new_accounts'] = avg_account_age < 30  # Less than 30 days old

    # Same report type (coordinated narrative)
    max_type_count = max(report_types.values()) if report_types else 0
    signals['same_report_type'] = max_type_count >= len(recent) * 0.7

    # Rapid succession (within minutes of each other)
    timestamps = sorted([_parse_time(r.get('timestamp', '')) for r in recent])
    if len(timestamps) >= 3:
        diffs = [(timestamps[i+1] - timestamps[i]).total_seconds() for i in range(len(timestamps)-1)]
        avg_diff = sum(diffs) / len(diffs)
        signals['rapid_succession'] = avg_diff < 120  # Less than 2 minutes apart

    # Calculate coordination score
    score = sum(1 for v in signals.values() if v) / len(signals)
    is_coordinated = score >= 0.5

    risk_level = 'critical' if score >= 0.8 else 'high' if score >= 0.6 else 'medium' if score >= 0.4 else 'low'

    actions = []
    if is_coordinated:
        actions.append('flag_for_trust_safety_review')
        actions.append('temporarily_restrict_mass_reporting')
        actions.append('notify_target_user')
    if risk_level == 'critical':
        actions.append('escalate_to_human_reviewer')
        actions.append('protect_target_account')

    return {
        'isCoordinated': is_coordinated,
        'coordinationScore': round(score, 3),
        'riskLevel': risk_level,
        'signals': signals,
        'reportCount': len(recent),
        'uniqueReporters': len(unique_reporters),
        'avgReporterAccountAgeDays': round(avg_account_age, 1),
        'dominantReportType': max(report_types, key=report_types.get) if report_types else 'none',
        'actions': actions,
        'windowMinutes': window_minutes
    }

def _parse_time(ts: str) -> datetime:
    try:
        return datetime.fromisoformat(ts.replace('Z', '+00:00').replace('+00:00', ''))
    except:
        return datetime.utcnow() - timedelta(hours=1)

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    result = detect_coordinated_harassment(
        data.get('reports', []),
        data.get('targetUserId', ''),
        data.get('windowMinutes', 60)
    )
    return jsonify({'targetUserId': data.get('targetUserId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'toxic-pattern-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
