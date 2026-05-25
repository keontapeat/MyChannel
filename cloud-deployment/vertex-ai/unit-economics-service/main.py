"""
Unit Economics AI Service - CAC, LTV, Payback Period
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

def calculate_unit_economics(metrics: dict) -> dict:
    marketing_spend = metrics.get('marketingSpend', 0)
    sales_spend = metrics.get('salesSpend', 0)
    new_customers = max(metrics.get('newCustomers', 1), 1)
    arpu = metrics.get('arpu', 0)
    gross_margin = metrics.get('grossMargin', 0.7)
    churn_rate = max(metrics.get('monthlyChurnRate', 0.05), 0.001)
    dau = max(metrics.get('dau', 1), 1)
    mau = max(metrics.get('mau', 1), 1)
    monthly_revenue = metrics.get('monthlyRevenue', 0)

    cac = (marketing_spend + sales_spend) / new_customers
    ltv = (arpu * gross_margin) / churn_rate
    ltv_cac = ltv / max(cac, 0.01)
    payback_months = cac / max(arpu * gross_margin, 0.01)
    arpd = monthly_revenue / (dau * 30)
    dau_mau = dau / mau

    status = 'excellent' if ltv_cac >= 3 and payback_months <= 12 else \
             'good' if ltv_cac >= 2 else 'needs_improvement'

    return {
        'cac': round(cac, 2),
        'ltv': round(ltv, 2),
        'ltvCacRatio': round(ltv_cac, 2),
        'paybackPeriodMonths': round(payback_months, 1),
        'arpu': round(arpu, 2),
        'arpd': round(arpd, 4),
        'dauMauRatio': round(dau_mau, 3),
        'grossMargin': gross_margin,
        'status': status,
        'benchmark': {'ltvCac': {'good': 3.0, 'current': round(ltv_cac, 2)}},
        'recommendations': _get_recs(ltv_cac, payback_months, churn_rate)
    }

def _get_recs(ltv_cac, payback, churn):
    recs = []
    if ltv_cac < 3: recs.append('Improve LTV:CAC ratio to 3x+ (currently {:.1f}x)'.format(ltv_cac))
    if payback > 12: recs.append('Reduce payback period below 12 months')
    if churn > 0.08: recs.append('Reduce monthly churn - focus on retention')
    if not recs: recs.append('Unit economics are healthy - focus on scaling')
    return recs

@app.route('/calculate', methods=['POST'])
def calculate():
    data = request.json
    result = calculate_unit_economics(data.get('metrics', {}))
    return jsonify(result)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'unit-economics-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
