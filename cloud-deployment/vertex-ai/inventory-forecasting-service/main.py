import os
from flask import Flask, request, jsonify
import numpy as np

app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict():
    """Inventory Forecasting prediction endpoint"""
    try:
        data = request.get_json()
        
        # Simulate inventory forecasting
        current_hour = int(data.get('hour', 12))
        day_of_week = int(data.get('day_of_week', 3))
        
        # Base traffic with daily patterns
        base_traffic = 100000
        hour_multiplier = 1.0 + 0.3 * np.sin((current_hour - 6) * np.pi / 12)
        day_multiplier = 1.2 if day_of_week >= 5 else 1.0
        
        predicted_impressions = int(base_traffic * hour_multiplier * day_multiplier * np.random.uniform(0.9, 1.1))
        
        return jsonify({
            "predicted_impressions": predicted_impressions,
            "available_inventory": int(predicted_impressions * 0.7),
            "fill_rate_forecast": np.random.uniform(0.85, 0.98),
            "peak_hours": [18, 19, 20, 21],
            "confidence": np.random.uniform(0.85, 0.95),
            "latency_ms": np.random.uniform(0.8, 1.5)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "agent": "inventory-forecasting"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))




