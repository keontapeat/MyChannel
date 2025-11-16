import os
from flask import Flask, request, jsonify
import numpy as np

app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict():
    """Fraud Detection prediction endpoint"""
    try:
        data = request.get_json()
        
        # Simulate fraud detection
        fraud_score = np.random.uniform(0.0, 0.05)  # Low fraud score = good
        is_fraudulent = fraud_score > 0.03
        
        return jsonify({
            "fraud_score": fraud_score,
            "is_fraudulent": is_fraudulent,
            "confidence": np.random.uniform(0.95, 0.9999),
            "latency_ms": np.random.uniform(0.3, 0.8)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "agent": "fraud-detection"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))

