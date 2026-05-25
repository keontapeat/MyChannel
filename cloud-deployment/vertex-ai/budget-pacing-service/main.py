import os
from flask import Flask, request, jsonify
import numpy as np

app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict():
    """Budget Pacing prediction endpoint"""
    try:
        data = request.get_json()
        
        # Simulate pacing calculation
        pacing_multiplier = np.random.uniform(0.8, 1.2)
        optimal_spend = data.get('current_spend', 100) * pacing_multiplier
        
        return jsonify({
            "pacing_multiplier": pacing_multiplier,
            "optimal_spend": optimal_spend,
            "budget_health": "healthy",
            "latency_ms": np.random.uniform(0.4, 0.9)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "agent": "budget-pacing"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))

