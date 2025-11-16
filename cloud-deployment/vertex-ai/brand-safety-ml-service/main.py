import os
from flask import Flask, request, jsonify
import numpy as np

app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict():
    """Brand Safety ML prediction endpoint"""
    try:
        data = request.get_json()
        
        # Simulate brand safety analysis
        safety_score = np.random.uniform(0.85, 0.99)
        is_brand_safe = safety_score > 0.9
        
        risk_categories = {
            "violence": np.random.uniform(0.0, 0.1),
            "adult_content": np.random.uniform(0.0, 0.05),
            "hate_speech": np.random.uniform(0.0, 0.02),
            "controversial": np.random.uniform(0.0, 0.15)
        }
        
        return jsonify({
            "safety_score": safety_score,
            "is_brand_safe": is_brand_safe,
            "risk_categories": risk_categories,
            "recommendation": "safe" if is_brand_safe else "block",
            "latency_ms": np.random.uniform(0.6, 1.2)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "agent": "brand-safety-ml"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))


