"""
Market Sizing AI Service
Size addressable market per region for strategic decisions
"""
import os
import json
from flask import Flask, request, jsonify

app = Flask(__name__)

# Internet users and video consumption data by region
MARKET_DATA = {
    'US': {'internetUsers': 311_000_000, 'videoConsumers': 0.85, 'avgSpendUsd': 180, 'youtubeShare': 0.28},
    'IN': {'internetUsers': 820_000_000, 'videoConsumers': 0.75, 'avgSpendUsd': 18, 'youtubeShare': 0.35},
    'BR': {'internetUsers': 165_000_000, 'videoConsumers': 0.80, 'avgSpendUsd': 45, 'youtubeShare': 0.30},
    'ID': {'internetUsers': 210_000_000, 'videoConsumers': 0.78, 'avgSpendUsd': 22, 'youtubeShare': 0.32},
    'NG': {'internetUsers': 122_000_000, 'videoConsumers': 0.70, 'avgSpendUsd': 12, 'youtubeShare': 0.25},
    'MX': {'internetUsers': 96_000_000, 'videoConsumers': 0.82, 'avgSpendUsd': 38, 'youtubeShare': 0.31},
    'PH': {'internetUsers': 85_000_000, 'videoConsumers': 0.80, 'avgSpendUsd': 20, 'youtubeShare': 0.33},
    'DE': {'internetUsers': 75_000_000, 'videoConsumers': 0.88, 'avgSpendUsd': 165, 'youtubeShare': 0.22},
    'GB': {'internetUsers': 67_000_000, 'videoConsumers': 0.90, 'avgSpendUsd': 175, 'youtubeShare': 0.24},
    'FR': {'internetUsers': 60_000_000, 'videoConsumers': 0.87, 'avgSpendUsd': 155, 'youtubeShare': 0.23},
    'JP': {'internetUsers': 118_000_000, 'videoConsumers': 0.88, 'avgSpendUsd': 145, 'youtubeShare': 0.20},
    'KR': {'internetUsers': 50_000_000, 'videoConsumers': 0.95, 'avgSpendUsd': 160, 'youtubeShare': 0.18},
    'GLOBAL': {'internetUsers': 5_400_000_000, 'videoConsumers': 0.72, 'avgSpendUsd': 55, 'youtubeShare': 0.28},
}

def calculate_market_size(regions: list, market_share_target: float = 0.05) -> dict:
    results = {}
    total_tam = 0
    total_sam = 0
    total_som = 0

    for region in regions:
        data = MARKET_DATA.get(region, MARKET_DATA['GLOBAL'])

        # TAM - Total Addressable Market
        video_consumers = int(data['internetUsers'] * data['videoConsumers'])
        tam_usd = video_consumers * data['avgSpendUsd']

        # SAM - Serviceable Addressable Market (realistic reach)
        # We can compete where YouTube is weak or has gaps
        sam_usd = tam_usd * (1 - data['youtubeShare'] * 0.5)

        # SOM - Serviceable Obtainable Market (our realistic capture)
        som_usd = sam_usd * market_share_target

        results[region] = {
            'videoConsumers': video_consumers,
            'tam': {'usd': round(tam_usd), 'formatted': _format_usd(tam_usd)},
            'sam': {'usd': round(sam_usd), 'formatted': _format_usd(sam_usd)},
            'som': {'usd': round(som_usd), 'formatted': _format_usd(som_usd)},
            'avgSpendPerUser': data['avgSpendUsd'],
            'youtubeMarketShare': data['youtubeShare'],
            'opportunityScore': round((1 - data['youtubeShare']) * (data['avgSpendUsd'] / 180), 3),
            'priority': 'high' if som_usd > 100_000_000 else 'medium' if som_usd > 10_000_000 else 'low'
        }

        total_tam += tam_usd
        total_sam += sam_usd
        total_som += som_usd

    # Sort regions by opportunity
    sorted_regions = sorted(results.items(), key=lambda x: x[1]['som']['usd'], reverse=True)

    return {
        'regions': dict(sorted_regions),
        'totals': {
            'tam': {'usd': round(total_tam), 'formatted': _format_usd(total_tam)},
            'sam': {'usd': round(total_sam), 'formatted': _format_usd(total_sam)},
            'som': {'usd': round(total_som), 'formatted': _format_usd(total_som)},
        },
        'targetMarketShare': market_share_target,
        'topOpportunities': [r[0] for r in sorted_regions[:3]],
        'totalVideoConsumers': sum(r[1]['videoConsumers'] for r in sorted_regions)
    }

def _format_usd(amount: float) -> str:
    if amount >= 1_000_000_000:
        return f'${amount/1_000_000_000:.1f}B'
    if amount >= 1_000_000:
        return f'${amount/1_000_000:.1f}M'
    return f'${amount:,.0f}'

@app.route('/size', methods=['POST'])
def size():
    data = request.json
    regions = data.get('regions', list(MARKET_DATA.keys()))
    target_share = data.get('targetMarketShare', 0.05)
    result = calculate_market_size(regions, target_share)
    return jsonify(result)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'market-sizing-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
