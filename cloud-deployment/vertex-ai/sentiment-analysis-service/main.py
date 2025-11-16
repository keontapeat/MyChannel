import os
from flask import Flask, request, jsonify
import numpy as np

app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict():
    """Sentiment Analysis prediction endpoint"""
    try:
        data = request.get_json()
        
        # Simulate sentiment analysis
        sentiment_scores = {
            "positive": np.random.uniform(0.3, 0.7),
            "neutral": np.random.uniform(0.2, 0.4),
            "negative": np.random.uniform(0.0, 0.2)
        }
        
        # Normalize scores
        total = sum(sentiment_scores.values())
        sentiment_scores = {k: v/total for k, v in sentiment_scores.items()}
        
        dominant_sentiment = max(sentiment_scores, key=sentiment_scores.get)
        
        return jsonify({
            "sentiment_scores": sentiment_scores,
            "dominant_sentiment": dominant_sentiment,
            "emotional_state": np.random.choice(['happy', 'excited', 'calm', 'curious']),
            "ad_receptiveness": np.random.uniform(0.6, 0.9),
            "recommended_tone": np.random.choice(['cheerful', 'professional', 'urgent']),
            "latency_ms": np.random.uniform(0.7, 1.5)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "agent": "sentiment-analysis"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))


