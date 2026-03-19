"""
Cultural Sensitivity AI Service
Flag culturally inappropriate content for safe global expansion
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

# Country-specific sensitivity rules
REGIONAL_RULES = {
    'SA': {'restrictions': ['alcohol', 'pork', 'dating', 'lgbtq', 'political_criticism'], 'severity': 'strict'},
    'CN': {'restrictions': ['political_dissent', 'taiwan_independence', 'tiananmen', 'dalai_lama', 'vpn'], 'severity': 'strict'},
    'IN': {'restrictions': ['beef', 'religious_mockery', 'intercaste_romance'], 'severity': 'moderate'},
    'DE': {'restrictions': ['nazi_symbols', 'hate_speech'], 'severity': 'strict'},
    'TR': {'restrictions': ['armenian_genocide_acknowledgment', 'kurdish_independence'], 'severity': 'moderate'},
    'RU': {'restrictions': ['ukraine_war_criticism', 'lgbtq_promotion'], 'severity': 'strict'},
    'PK': {'restrictions': ['blasphemy', 'ahmadiyya', 'india_positive'], 'severity': 'strict'},
    'IL': {'restrictions': ['antisemitism', 'holocaust_denial'], 'severity': 'strict'},
}

def analyze_cultural_sensitivity(content: dict, target_regions: list) -> dict:
    """Analyze content for cultural sensitivity across target regions"""
    
    title = content.get('title', '')
    description = content.get('description', '')
    transcript = content.get('transcript', '')
    tags = content.get('tags', [])
    
    combined_text = f"{title} {description} {transcript[:2000]} {' '.join(tags)}"
    
    region_results = {}
    global_issues = []
    
    for region in target_regions:
        rules = REGIONAL_RULES.get(region, {})
        restrictions = rules.get('restrictions', [])
        severity = rules.get('severity', 'low')
        
        region_issues = []
        for restriction in restrictions:
            if restriction.replace('_', ' ').lower() in combined_text.lower():
                region_issues.append(restriction)
        
        region_results[region] = {
            'safe': len(region_issues) == 0,
            'issues': region_issues,
            'severity': severity if region_issues else 'none',
            'action': 'block' if (region_issues and severity == 'strict') else ('review' if region_issues else 'allow')
        }
    
    # AI-powered deeper analysis
    ai_analysis = _ai_sensitivity_check(combined_text, target_regions)
    
    # Compile safe regions
    safe_regions = [r for r, v in region_results.items() if v['safe']]
    blocked_regions = [r for r, v in region_results.items() if v['action'] == 'block']
    review_regions = [r for r, v in region_results.items() if v['action'] == 'review']
    
    overall_safe = len(blocked_regions) == 0
    
    return {
        'overallSafe': overall_safe,
        'safeRegions': safe_regions,
        'blockedRegions': blocked_regions,
        'reviewRegions': review_regions,
        'regionAnalysis': region_results,
        'aiAnalysis': ai_analysis,
        'recommendations': _get_recommendations(blocked_regions, review_regions)
    }

def _ai_sensitivity_check(text: str, regions: list) -> dict:
    """Use Gemini for nuanced cultural analysis"""
    prompt = f"""Analyze this content for cultural sensitivity issues in these regions: {', '.join(regions)}.

CONTENT: {text[:1500]}

Return JSON with:
1. "overallRisk" - low/medium/high
2. "culturalIssues" - array of specific issues found
3. "suggestedEdits" - array of suggested text changes
4. "confidence" - 0-1

Return ONLY valid JSON."""
    
    try:
        response = model.generate_content(prompt)
        import re
        json_match = re.search(r'\{.*\}', response.text, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
    except:
        pass
    
    return {'overallRisk': 'low', 'culturalIssues': [], 'suggestedEdits': [], 'confidence': 0.5}

def _get_recommendations(blocked: list, review: list) -> list:
    recs = []
    if blocked:
        recs.append(f'Content blocked in {len(blocked)} regions: {", ".join(blocked)}')
        recs.append('Consider creating region-specific versions of this content')
    if review:
        recs.append(f'Content needs manual review for regions: {", ".join(review)}')
    if not blocked and not review:
        recs.append('Content is globally safe for all analyzed regions')
    return recs

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    video_id = data.get('videoId', '')
    content = data.get('content', {})
    target_regions = data.get('targetRegions', list(REGIONAL_RULES.keys()))
    
    result = analyze_cultural_sensitivity(content, target_regions)
    
    return jsonify({
        'videoId': video_id,
        **result
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'cultural-sensitivity-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
