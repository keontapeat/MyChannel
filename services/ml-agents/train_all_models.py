#!/usr/bin/env python3
"""
🔥 TRAIN ALL ML MODELS
Run this script to train all ML models with synthetic data.
In production, replace synthetic data with real BigQuery data.
"""

import os
import sys
import logging
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

MODEL_DIR = os.environ.get("MODEL_DIR", "./trained_models")


# ============================================================================
# Core Model Training Functions
# ============================================================================

def train_viral_predictor():
    """Train viral prediction model"""
    from models.viral_predictor import ViralPredictor, generate_training_data
    
    logger.info("🔥 Training Viral Predictor...")
    start = time.time()
    
    videos, labels, v24h, v7d, v30d = generate_training_data(10000)
    predictor = ViralPredictor()
    metrics = predictor.train(videos, labels, v24h, v7d, v30d)
    predictor.save(os.path.join(MODEL_DIR, "viral_predictor.joblib"))
    
    logger.info(f"✅ Viral Predictor trained in {time.time() - start:.1f}s")
    logger.info(f"   AUC: {metrics['auc']:.4f}")
    return metrics


def train_churn_predictor():
    """Train churn prediction model"""
    from models.churn_predictor import ChurnPredictor, generate_training_data
    
    logger.info("🔥 Training Churn Predictor...")
    start = time.time()
    
    users, churned, days = generate_training_data(10000)
    predictor = ChurnPredictor()
    metrics = predictor.train(users, churned, days)
    predictor.save(os.path.join(MODEL_DIR, "churn_predictor.joblib"))
    
    logger.info(f"✅ Churn Predictor trained in {time.time() - start:.1f}s")
    logger.info(f"   Ensemble AUC: {metrics['ensemble_auc']:.4f}")
    return metrics


def train_fraud_detector():
    """Train fraud detection model"""
    from models.fraud_detector import FraudDetector, generate_training_data
    
    logger.info("🔥 Training Fraud Detector...")
    start = time.time()
    
    clicks, labels = generate_training_data(50000)
    detector = FraudDetector()
    metrics = detector.train(clicks, labels)
    detector.save(os.path.join(MODEL_DIR, "fraud_detector.joblib"))
    
    logger.info(f"✅ Fraud Detector trained in {time.time() - start:.1f}s")
    logger.info(f"   AUC: {metrics['auc']:.4f}, Precision: {metrics['precision']:.4f}")
    return metrics


def train_recommendation_engine():
    """Train recommendation engine"""
    from models.recommendation_engine import RecommendationEngine, generate_training_data
    
    logger.info("🔥 Training Recommendation Engine...")
    start = time.time()
    
    interactions, videos = generate_training_data(1000, 5000, 50000)
    engine = RecommendationEngine()
    metrics = engine.train(interactions, videos, epochs=10)
    engine.save(os.path.join(MODEL_DIR, "recommendation_engine.joblib"))
    
    logger.info(f"✅ Recommendation Engine trained in {time.time() - start:.1f}s")
    return metrics


def train_thumbnail_predictor():
    """Train thumbnail CTR predictor"""
    from models.thumbnail_ctr_predictor import ThumbnailCTRPredictor, generate_training_data
    
    logger.info("🔥 Training Thumbnail CTR Predictor...")
    start = time.time()
    
    thumbnails, ctrs, categories = generate_training_data(500)
    predictor = ThumbnailCTRPredictor()
    metrics = predictor.train(thumbnails, ctrs, categories)
    predictor.save(os.path.join(MODEL_DIR, "thumbnail_ctr_predictor.joblib"))
    
    logger.info(f"✅ Thumbnail CTR Predictor trained in {time.time() - start:.1f}s")
    logger.info(f"   R²: {metrics['r2']:.4f}")
    return metrics


def train_watch_time_predictor():
    """Train watch time predictor"""
    from models.watch_time_predictor import WatchTimePredictor, generate_training_data
    
    logger.info("🔥 Training Watch Time Predictor...")
    start = time.time()
    
    videos, watch_times, retention_rates = generate_training_data(5000)
    predictor = WatchTimePredictor()
    metrics = predictor.train(videos, watch_times, retention_rates)
    predictor.save(os.path.join(MODEL_DIR, "watch_time_predictor.joblib"))
    
    logger.info(f"✅ Watch Time Predictor trained in {time.time() - start:.1f}s")
    logger.info(f"   Watch Time R²: {metrics['watch_time_r2']:.4f}")
    return metrics


# ============================================================================
# Real Agent Training Functions
# ============================================================================

def train_content_moderation():
    """Train content moderation agent"""
    from models.real_agents.content_moderation_agent import ContentModerationAgent
    
    logger.info("🔥 Training Content Moderation Agent...")
    start = time.time()
    
    agent = ContentModerationAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Content Moderation trained in {time.time() - start:.1f}s")
    logger.info(f"   AUC: {metrics.get('auc', 'N/A')}")
    return metrics


def train_sentiment_analysis():
    """Train sentiment analysis agent"""
    from models.real_agents.sentiment_analysis_agent import SentimentAnalysisAgent
    
    logger.info("🔥 Training Sentiment Analysis Agent...")
    start = time.time()
    
    agent = SentimentAnalysisAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Sentiment Analysis trained in {time.time() - start:.1f}s")
    logger.info(f"   R²: {metrics.get('r2', 'N/A')}")
    return metrics


def train_dynamic_pricing():
    """Train dynamic pricing agent"""
    from models.real_agents.dynamic_pricing_agent import DynamicPricingAgent
    
    logger.info("🔥 Training Dynamic Pricing Agent...")
    start = time.time()
    
    agent = DynamicPricingAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Dynamic Pricing trained in {time.time() - start:.1f}s")
    logger.info(f"   R²: {metrics.get('r2', 'N/A')}")
    return metrics


def train_lifetime_value():
    """Train lifetime value agent"""
    from models.real_agents.lifetime_value_agent import LifetimeValueAgent
    
    logger.info("🔥 Training Lifetime Value Agent...")
    start = time.time()
    
    agent = LifetimeValueAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Lifetime Value trained in {time.time() - start:.1f}s")
    logger.info(f"   R²: {metrics.get('r2', 'N/A')}")
    return metrics


def train_retention_predictor():
    """Train retention predictor agent"""
    from models.real_agents.retention_predictor_agent import RetentionPredictorAgent
    
    logger.info("🔥 Training Retention Predictor Agent...")
    start = time.time()
    
    agent = RetentionPredictorAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Retention Predictor trained in {time.time() - start:.1f}s")
    logger.info(f"   AUC: {metrics.get('auc', 'N/A')}")
    return metrics


def train_engagement_predictor():
    """Train engagement predictor agent"""
    from models.real_agents.engagement_predictor_agent import EngagementPredictorAgent
    
    logger.info("🔥 Training Engagement Predictor Agent...")
    start = time.time()
    
    agent = EngagementPredictorAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Engagement Predictor trained in {time.time() - start:.1f}s")
    logger.info(f"   R²: {metrics.get('r2', 'N/A')}")
    return metrics


def train_ad_revenue_optimizer():
    """Train ad revenue optimizer agent"""
    from models.real_agents.ad_revenue_optimizer_agent import AdRevenueOptimizerAgent
    
    logger.info("🔥 Training Ad Revenue Optimizer Agent...")
    start = time.time()
    
    agent = AdRevenueOptimizerAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Ad Revenue Optimizer trained in {time.time() - start:.1f}s")
    logger.info(f"   R²: {metrics.get('r2', 'N/A')}")
    return metrics


def train_creator_success():
    """Train creator success agent"""
    from models.real_agents.creator_success_agent import CreatorSuccessAgent
    
    logger.info("🔥 Training Creator Success Agent...")
    start = time.time()
    
    agent = CreatorSuccessAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Creator Success trained in {time.time() - start:.1f}s")
    logger.info(f"   R²: {metrics.get('r2', 'N/A')}")
    return metrics


def train_trend_forecaster():
    """Train trend forecaster agent"""
    from models.real_agents.trend_forecaster_agent import TrendForecasterAgent
    
    logger.info("🔥 Training Trend Forecaster Agent...")
    start = time.time()
    
    agent = TrendForecasterAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Trend Forecaster trained in {time.time() - start:.1f}s")
    logger.info(f"   R²: {metrics.get('r2', 'N/A')}")
    return metrics


def train_notification_optimizer():
    """Train notification optimizer agent"""
    from models.real_agents.notification_optimizer_agent import NotificationOptimizerAgent
    
    logger.info("🔥 Training Notification Optimizer Agent...")
    start = time.time()
    
    agent = NotificationOptimizerAgent()
    metrics = agent.train_and_save(10000)
    
    logger.info(f"✅ Notification Optimizer trained in {time.time() - start:.1f}s")
    logger.info(f"   AUC: {metrics.get('auc', 'N/A')}")
    return metrics


# ============================================================================
# Main Training Orchestration
# ============================================================================

def train_model_safe(name: str, train_func):
    """Safely train a model with error handling"""
    try:
        metrics = train_func()
        return name, metrics, None
    except Exception as e:
        logger.error(f"❌ Failed to train {name}: {e}")
        import traceback
        traceback.print_exc()
        return name, None, str(e)


def main(parallel: bool = False):
    """Train all models"""
    os.makedirs(MODEL_DIR, exist_ok=True)
    
    print("=" * 70)
    print("🔥🔥🔥 TRAINING ALL REAL ML MODELS 🔥🔥🔥")
    print("=" * 70)
    print(f"Model directory: {MODEL_DIR}")
    print(f"Parallel mode: {parallel}")
    print("=" * 70)
    
    total_start = time.time()
    all_metrics = {}
    errors = {}
    
    # Define all training functions
    training_tasks = [
        # Core models
        ("viral", train_viral_predictor),
        ("churn", train_churn_predictor),
        ("fraud", train_fraud_detector),
        ("recommendations", train_recommendation_engine),
        ("thumbnail", train_thumbnail_predictor),
        ("watch_time", train_watch_time_predictor),
        # Real agents
        ("content_moderation", train_content_moderation),
        ("sentiment", train_sentiment_analysis),
        ("dynamic_pricing", train_dynamic_pricing),
        ("lifetime_value", train_lifetime_value),
        ("retention", train_retention_predictor),
        ("engagement", train_engagement_predictor),
        ("ad_revenue", train_ad_revenue_optimizer),
        ("creator_success", train_creator_success),
        ("trend", train_trend_forecaster),
        ("notification", train_notification_optimizer),
    ]
    
    if parallel:
        # Train in parallel (faster but uses more memory)
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = {
                executor.submit(train_model_safe, name, func): name 
                for name, func in training_tasks
            }
            
            for future in as_completed(futures):
                name, metrics, error = future.result()
                if metrics:
                    all_metrics[name] = metrics
                if error:
                    errors[name] = error
    else:
        # Train sequentially
        for name, train_func in training_tasks:
            name, metrics, error = train_model_safe(name, train_func)
            if metrics:
                all_metrics[name] = metrics
            if error:
                errors[name] = error
    
    total_time = time.time() - total_start
    
    # Print summary
    print("\n" + "=" * 70)
    print("📊 TRAINING SUMMARY")
    print("=" * 70)
    print(f"Total training time: {total_time:.1f}s ({total_time/60:.1f} minutes)")
    print(f"Models trained: {len(all_metrics)}/{len(training_tasks)}")
    print(f"Errors: {len(errors)}")
    print(f"Model directory: {MODEL_DIR}")
    
    # List trained models
    print("\n🎯 Trained Models:")
    for name, metrics in all_metrics.items():
        print(f"\n  {name.upper()}:")
        for k, v in metrics.items():
            if isinstance(v, float):
                print(f"    {k}: {v:.4f}")
            elif isinstance(v, (int, str)):
                print(f"    {k}: {v}")
    
    # List errors
    if errors:
        print("\n❌ Failed Models:")
        for name, error in errors.items():
            print(f"  {name}: {error}")
    
    # List model files
    print("\n📁 Model Files:")
    if os.path.exists(MODEL_DIR):
        for f in sorted(os.listdir(MODEL_DIR)):
            if f.endswith('.joblib'):
                size = os.path.getsize(os.path.join(MODEL_DIR, f)) / 1024 / 1024
                print(f"  {f}: {size:.2f} MB")
    
    print("\n" + "=" * 70)
    if len(errors) == 0:
        print("✅ ALL MODELS TRAINED SUCCESSFULLY!")
    else:
        print(f"⚠️ {len(all_metrics)} models trained, {len(errors)} failed")
    print("=" * 70)
    
    return all_metrics, errors


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Train all ML models")
    parser.add_argument("--parallel", "-p", action="store_true", 
                        help="Train models in parallel (faster but uses more memory)")
    parser.add_argument("--model", "-m", type=str, 
                        help="Train only a specific model")
    args = parser.parse_args()
    
    if args.model:
        # Train specific model
        training_funcs = {
            "viral": train_viral_predictor,
            "churn": train_churn_predictor,
            "fraud": train_fraud_detector,
            "recommendations": train_recommendation_engine,
            "thumbnail": train_thumbnail_predictor,
            "watch_time": train_watch_time_predictor,
            "content_moderation": train_content_moderation,
            "sentiment": train_sentiment_analysis,
            "dynamic_pricing": train_dynamic_pricing,
            "lifetime_value": train_lifetime_value,
            "retention": train_retention_predictor,
            "engagement": train_engagement_predictor,
            "ad_revenue": train_ad_revenue_optimizer,
            "creator_success": train_creator_success,
            "trend": train_trend_forecaster,
            "notification": train_notification_optimizer,
        }
        
        if args.model in training_funcs:
            os.makedirs(MODEL_DIR, exist_ok=True)
            training_funcs[args.model]()
        else:
            print(f"Unknown model: {args.model}")
            print(f"Available: {list(training_funcs.keys())}")
            sys.exit(1)
    else:
        main(parallel=args.parallel)
