import os
from flask import Flask, request, jsonify
import numpy as np

app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict():
    """Chat Moderation AI - Clean chat experience"""
    try:
        data = request.get_json()
        message = data.get('message', '')
        
        # Simulate chat analysis
        is_spam = np.random.choice([True, False], p=[0.05, 0.95])
        is_toxic = np.random.choice([True, False], p=[0.03, 0.97])
        is_emoji_spam = message.count('😂') > 5 if message else False
        
        should_block = is_spam or is_toxic or is_emoji_spam
        
        return jsonify({
            "should_block": should_block,
            "is_spam": is_spam,
            "is_toxic": is_toxic,
            "is_emoji_spam": is_emoji_spam,
            "toxicity_score": np.random.uniform(0.0, 0.2),
            "action": "block" if should_block else "allow",
            "latency_ms": np.random.uniform(0.2, 0.6)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "agent": "chat-moderation"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))


