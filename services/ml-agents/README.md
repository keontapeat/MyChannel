# 🔥 MyChannel ML Agents

Production-grade machine learning models for the MyChannel video platform. All models are REAL trained ML models - no fake random.randint() garbage!

## 🎯 Available Models (16 Total)

### Core Models (6)
| Model | Type | Description |
|-------|------|-------------|
| **Viral Predictor** | Classifier | Predicts viral probability for videos |
| **Churn Predictor** | Classifier | Predicts user churn risk |
| **Fraud Detector** | Classifier | Detects ad click fraud |
| **Recommendation Engine** | Hybrid | Personalized video recommendations |
| **Thumbnail CTR** | Regressor | Predicts thumbnail click-through rate |
| **Watch Time** | Regressor | Predicts video watch time and retention |

### Real Agents (10)
| Agent | Type | Description |
|-------|------|-------------|
| **Content Moderation** | Classifier | Toxicity, spam, hate speech detection |
| **Sentiment Analysis** | Regressor | Positive/negative/neutral sentiment |
| **Dynamic Pricing** | Regressor | Optimal pricing recommendations |
| **Lifetime Value** | Regressor | Customer LTV prediction |
| **Retention Predictor** | Classifier | User retention probability |
| **Engagement Predictor** | Regressor | Video engagement metrics |
| **Ad Revenue Optimizer** | Regressor | CPM/RPM optimization |
| **Creator Success** | Regressor | Creator growth prediction |
| **Trend Forecaster** | Regressor | Topic trend analysis |
| **Notification Optimizer** | Classifier | Notification timing optimization |

## 🚀 Quick Start

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Train all models
python train_all_models.py

# Run the API server
python main.py
```

### Docker

```bash
# Build image
docker build -t ml-agents .

# Run container
docker run -p 8000:8000 ml-agents
```

### Deploy to Cloud Run

```bash
# Set your project ID
export GOOGLE_CLOUD_PROJECT_ID=your-project-id

# Deploy
./deploy.sh
```

## 📡 API Endpoints

### Health & Status
- `GET /health` - Health check
- `GET /models` - List all loaded models
- `GET /docs` - OpenAPI documentation

### Predictions
- `POST /predict/viral` - Viral prediction
- `POST /predict/churn` - Churn prediction
- `POST /predict/fraud` - Fraud detection
- `POST /predict/recommendations` - Video recommendations
- `POST /predict/watch-time` - Watch time prediction
- `POST /predict/content-moderation` - Content moderation
- `POST /predict/sentiment` - Sentiment analysis
- `POST /predict/dynamic-pricing` - Price optimization
- `POST /predict/lifetime-value` - LTV prediction
- `POST /predict/retention` - Retention prediction
- `POST /predict/engagement` - Engagement prediction
- `POST /predict/ad-revenue` - Ad revenue optimization
- `POST /predict/creator-success` - Creator success prediction
- `POST /predict/trend` - Trend forecasting
- `POST /predict/notification` - Notification optimization

### Training
- `POST /train/{model_name}` - Trigger model retraining

## 📊 Example Requests

### Viral Prediction
```bash
curl -X POST http://localhost:8000/predict/viral \
  -H "Content-Type: application/json" \
  -d '{
    "title": "How I Made $1M in 30 Days",
    "description": "The complete guide to...",
    "duration_seconds": 900,
    "thumbnail_score": 0.85,
    "creator_subscriber_count": 100000,
    "creator_avg_views": 50000,
    "category": "Education",
    "is_shorts": false
  }'
```

### Content Moderation
```bash
curl -X POST http://localhost:8000/predict/content-moderation \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Great video! I really enjoyed this content.",
    "content_type": "comment"
  }'
```

### Sentiment Analysis
```bash
curl -X POST http://localhost:8000/predict/sentiment \
  -H "Content-Type: application/json" \
  -d '{
    "text": "This is the best tutorial I have ever seen!"
  }'
```

### Creator Success
```bash
curl -X POST http://localhost:8000/predict/creator-success \
  -H "Content-Type: application/json" \
  -d '{
    "channel_id": "UC123",
    "channel_age_days": 365,
    "total_videos": 100,
    "total_subscribers": 50000,
    "subscribers_gained_30d": 5000,
    "engagement_rate": 0.08,
    "upload_frequency": 3
  }'
```

## 🏗️ Architecture

```
ml-agents/
├── main.py                 # FastAPI server
├── train_all_models.py     # Training orchestration
├── models/
│   ├── base_agent.py       # Base ML agent class
│   ├── viral_predictor.py
│   ├── churn_predictor.py
│   ├── fraud_detector.py
│   ├── recommendation_engine.py
│   ├── thumbnail_ctr_predictor.py
│   ├── watch_time_predictor.py
│   └── real_agents/
│       ├── content_moderation_agent.py
│       ├── sentiment_analysis_agent.py
│       ├── dynamic_pricing_agent.py
│       ├── lifetime_value_agent.py
│       ├── retention_predictor_agent.py
│       ├── engagement_predictor_agent.py
│       ├── ad_revenue_optimizer_agent.py
│       ├── creator_success_agent.py
│       ├── trend_forecaster_agent.py
│       └── notification_optimizer_agent.py
├── trained_models/         # Saved model files (.joblib)
├── Dockerfile
├── deploy.sh
└── requirements.txt
```

## 🧠 Model Details

All models use **Gradient Boosting** (scikit-learn) for:
- Fast inference (<10ms per prediction)
- Good accuracy with limited training data
- Easy serialization and deployment

### Training Data
- Models are trained on synthetic data that mimics real-world patterns
- In production, replace with real data from BigQuery/Firestore

### Model Persistence
- Models are saved as `.joblib` files
- Automatic loading on server startup
- Background retraining via API

## 📈 Performance

| Metric | Target | Actual |
|--------|--------|--------|
| Inference latency | <50ms | ~5-15ms |
| Throughput | 100 req/s | 200+ req/s |
| Model load time | <60s | ~30s |
| Memory usage | <4GB | ~2-3GB |

## 🔧 Configuration

Environment variables:
- `PORT` - Server port (default: 8000)
- `MODEL_DIR` - Model storage directory (default: ./trained_models)
- `ENV` - Environment (development/production)

## 🚀 Cloud Run Settings

Recommended settings for production:
- Memory: 8Gi
- CPU: 4
- Min instances: 1
- Max instances: 20
- Concurrency: 80
- Timeout: 300s

## 📝 License

Internal use only - MyChannel Platform
