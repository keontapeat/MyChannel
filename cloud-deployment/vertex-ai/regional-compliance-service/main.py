"""
Regional Compliance AI Service
Auto-comply with local laws: GDPR, CCPA, COPPA, etc.
"""
import os
import json
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

COMPLIANCE_RULES = {
    'GDPR': {
        'regions': ['EU', 'DE', 'FR', 'IT', 'ES', 'NL', 'SE', 'PL', 'BE', 'AT', 'DK', 'FI'],
        'requirements': ['consent_required', 'data_deletion_right', 'data_portability', 'privacy_notice', 'dpo_required'],
        'data_retention_days': 365,
        'cookie_consent': True,
        'age_verification': 16
    },
    'CCPA': {
        'regions': ['US-CA'],
        'requirements': ['opt_out_sale', 'data_disclosure', 'non_discrimination', 'privacy_notice'],
        'data_retention_days': 730,
        'cookie_consent': False,
        'age_verification': 16
    },
    'COPPA': {
        'regions': ['US'],
        'requirements': ['parental_consent_under_13', 'limited_data_collection', 'no_behavioral_ads_under_13'],
        'data_retention_days': None,
        'cookie_consent': True,
        'age_verification': 13
    },
    'PIPL': {
        'regions': ['CN'],
        'requirements': ['explicit_consent', 'data_localization', 'cross_border_transfer_approval'],
        'data_retention_days': 730,
        'cookie_consent': True,
        'age_verification': 14
    },
    'PDPA': {
        'regions': ['TH', 'SG', 'MY'],
        'requirements': ['consent_required', 'purpose_limitation', 'data_accuracy'],
        'data_retention_days': 365,
        'cookie_consent': True,
        'age_verification': 18
    },
    'LGPD': {
        'regions': ['BR'],
        'requirements': ['consent_required', 'data_deletion_right', 'privacy_notice'],
        'data_retention_days': 365,
        'cookie_consent': True,
        'age_verification': 18
    },
}

def get_compliance_requirements(country: str, user_age: int = None) -> dict:
    """Get all applicable compliance requirements for a country"""
    applicable_laws = []
    requirements = set()
    actions = []

    for law, rules in COMPLIANCE_RULES.items():
        regions = rules['regions']
        applies = country in regions or f'US-{country}' in regions
        if not applies and country.startswith('US'):
            applies = 'US' in regions
        if not applies:
            for r in regions:
                if country in r or r in country:
                    applies = True
                    break

        if applies:
            applicable_laws.append(law)
            requirements.update(rules['requirements'])

            if rules.get('cookie_consent'):
                actions.append('show_cookie_consent_banner')

            age_limit = rules.get('age_verification', 13)
            if user_age is not None and user_age < age_limit:
                actions.append(f'require_parental_consent_{law}')
                actions.append('restrict_data_collection')
                actions.append('disable_behavioral_ads')

    actions = list(set(actions))

    return {
        'country': country,
        'applicableLaws': applicable_laws,
        'requirements': list(requirements),
        'requiredActions': actions,
        'cookieConsentRequired': 'show_cookie_consent_banner' in actions,
        'dataRetentionDays': min(
            (COMPLIANCE_RULES[l].get('data_retention_days') or 9999 for l in applicable_laws),
            default=730
        ),
        'isCompliant': len(applicable_laws) > 0,
        'checkedAt': datetime.utcnow().isoformat()
    }

def validate_data_request(request_type: str, user_data: dict, country: str) -> dict:
    """Validate a data request against compliance rules"""
    requirements = get_compliance_requirements(country)
    applicable = requirements['applicableLaws']

    response = {'approved': True, 'conditions': [], 'requiredActions': []}

    if request_type == 'data_collection':
        if 'consent_required' in requirements['requirements']:
            has_consent = user_data.get('hasConsent', False)
            if not has_consent:
                response['approved'] = False
                response['requiredActions'].append('obtain_explicit_consent')

    elif request_type == 'data_deletion':
        if any(l in applicable for l in ['GDPR', 'CCPA', 'LGPD']):
            response['mustComply'] = True
            response['deadline'] = '30 days (GDPR) / 45 days (CCPA)'
            response['requiredActions'].append('process_deletion_request')

    elif request_type == 'data_export':
        if 'GDPR' in applicable:
            response['mustComply'] = True
            response['format'] = 'machine_readable_JSON_or_CSV'
            response['requiredActions'].append('generate_data_export')

    return response

@app.route('/requirements', methods=['POST'])
def get_requirements():
    data = request.json
    country = data.get('country', 'US')
    user_age = data.get('userAge')
    result = get_compliance_requirements(country, user_age)
    return jsonify(result)

@app.route('/validate', methods=['POST'])
def validate():
    data = request.json
    result = validate_data_request(
        data.get('requestType', ''),
        data.get('userData', {}),
        data.get('country', 'US')
    )
    return jsonify(result)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'regional-compliance-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
