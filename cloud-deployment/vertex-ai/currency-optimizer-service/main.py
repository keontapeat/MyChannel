"""
Currency Optimizer AI Service
Optimize pricing per currency for international revenue
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

# PPP-adjusted pricing multipliers (relative to USD)
PPP_MULTIPLIERS = {
    'USD': 1.00, 'EUR': 0.92, 'GBP': 0.79, 'CAD': 1.35, 'AUD': 1.53,
    'JPY': 148.0, 'KRW': 1320.0, 'CNY': 7.10, 'INR': 83.0, 'BRL': 4.97,
    'MXN': 17.5, 'NGN': 1480.0, 'ZAR': 18.6, 'IDR': 15500.0, 'PHP': 56.0,
    'THB': 35.0, 'VND': 24000.0, 'PKR': 279.0, 'EGP': 31.0, 'TRY': 32.0,
    'AED': 3.67, 'SAR': 3.75, 'SEK': 10.5, 'NOK': 10.7, 'DKK': 6.89,
    'PLN': 4.00, 'CZK': 23.5, 'HUF': 360.0, 'RUB': 92.0, 'ILS': 3.70,
    'CHF': 0.90, 'SGD': 1.34, 'HKD': 7.82, 'TWD': 31.5, 'MYR': 4.72,
}

# Purchasing power parity adjustments (local affordability)
LOCAL_AFFORDABILITY = {
    'IN': 0.25, 'PK': 0.15, 'NG': 0.20, 'ID': 0.30, 'VN': 0.25,
    'PH': 0.30, 'EG': 0.20, 'TH': 0.40, 'MX': 0.50, 'BR': 0.55,
    'ZA': 0.45, 'TR': 0.40, 'RU': 0.50, 'PL': 0.65, 'HU': 0.60,
    'CN': 0.45, 'KR': 0.80, 'JP': 0.90, 'AU': 0.95, 'CA': 0.95,
    'GB': 0.95, 'DE': 0.95, 'FR': 0.90, 'US': 1.00, 'SG': 1.00,
    'AE': 0.90, 'SA': 0.85, 'IL': 0.90, 'SE': 0.95, 'CH': 1.00,
}

def calculate_local_price(base_usd_price: float, country: str, currency: str) -> dict:
    """Calculate optimal local price with PPP adjustment"""
    exchange_rate = PPP_MULTIPLIERS.get(currency, 1.0)
    affordability = LOCAL_AFFORDABILITY.get(country, 0.7)

    # Raw conversion
    raw_price = base_usd_price * exchange_rate

    # PPP-adjusted price (accounts for local purchasing power)
    ppp_price = base_usd_price * affordability * exchange_rate

    # Round to psychologically appealing price
    final_price = _round_to_appealing(ppp_price, currency)

    # Effective USD equivalent
    effective_usd = final_price / exchange_rate

    return {
        'currency': currency,
        'country': country,
        'baseUsdPrice': base_usd_price,
        'rawConvertedPrice': round(raw_price, 2),
        'pppAdjustedPrice': round(ppp_price, 2),
        'recommendedLocalPrice': final_price,
        'effectiveUsdEquivalent': round(effective_usd, 2),
        'affordabilityFactor': affordability,
        'exchangeRate': exchange_rate,
        'discountFromUsd': round((1 - effective_usd / base_usd_price) * 100, 1)
    }

def _round_to_appealing(price: float, currency: str) -> float:
    """Round to psychologically appealing price points"""
    # High value currencies (JPY, KRW, IDR, etc.)
    if currency in ['JPY', 'KRW', 'IDR', 'VND', 'NGN', 'PKR', 'HUF']:
        rounded = round(price / 100) * 100
        return rounded - 1 if rounded > 100 else rounded

    if price < 1:
        return round(price, 2)
    elif price < 5:
        return round(price * 2) / 2 - 0.01  # e.g., 1.99, 2.49
    elif price < 20:
        return float(int(price)) + 0.99
    else:
        return float(round(price / 5) * 5) - 0.01

def optimize_subscription_tiers(base_tiers: list, country: str, currency: str) -> list:
    """Optimize all subscription tiers for a market"""
    return [
        {
            **tier,
            'localPricing': calculate_local_price(tier.get('priceUsd', 0), country, currency)
        }
        for tier in base_tiers
    ]

@app.route('/price', methods=['POST'])
def get_price():
    data = request.json
    result = calculate_local_price(
        data.get('basePriceUsd', 9.99),
        data.get('country', 'US'),
        data.get('currency', 'USD')
    )
    return jsonify(result)

@app.route('/tiers', methods=['POST'])
def get_tiers():
    data = request.json
    result = optimize_subscription_tiers(
        data.get('tiers', []),
        data.get('country', 'US'),
        data.get('currency', 'USD')
    )
    return jsonify({'tiers': result})

@app.route('/supported-currencies', methods=['GET'])
def get_currencies():
    return jsonify({'currencies': list(PPP_MULTIPLIERS.keys()), 'count': len(PPP_MULTIPLIERS)})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'currency-optimizer-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
