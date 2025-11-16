import os
from flask import Flask, request, jsonify
import numpy as np

app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict():
    """Viewability Prediction endpoint"""
    try:
        data = request.get_json()
        
        # Simulate viewability prediction
        viewability_score = np.random.uniform(0.7, 0.98)
        will_be_viewed = viewability_score > 0.7
        
        return jsonify({
            "viewability_score": viewability_score,
            "will_be_viewed": will_be_viewed,
            "predicted_view_time": np.random.uniform(2.0, 15.0),
            "scroll_probability": np.random.uniform(0.3, 0.8),
            "latency_ms": np.random.uniform(0.5, 1.0)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "agent": "viewability-prediction"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))


