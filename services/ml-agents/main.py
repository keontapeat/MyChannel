"""
🔥 REAL ML AGENTS API - Production FastAPI Server
Serves all ML models via REST API

Endpoints:
- POST /predict/viral - Viral prediction
- POST /predict/churn - Churn prediction
- POST /predict/fraud - Fraud detection
- POST /predict/recommendations - Content recommendations
- POST /predict/thumbnail-ctr - Thumbnail CTR prediction
- POST /predict/watch-time - Watch time prediction
- POST /predict/content-moderation - Content moderation
- POST /predict/sentiment - Sentiment analysis
- POST /predict/dynamic-pricing - Dynamic pricing optimization
- POST /predict/lifetime-value - Customer LTV prediction
- POST /predict/retention - User retention prediction
- POST /predict/engagement - Engagement prediction
- POST /predict/ad-revenue - Ad revenue optimization
- POST /predict/creator-success - Creator success prediction
- POST /predict/trend - Trend forecasting
- POST /predict/notification - Notification optimization
- GET /health - Health check
- GET /models - List loaded models
"""

import os
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

# Import core ML models
from models.viral_predictor import ViralPredictor, VideoFeatures
from models.churn_predictor import ChurnPredictor, UserEngagementFeatures
from models.fraud_detector import FraudDetector, ClickEvent
from models.recommendation_engine import RecommendationEngine, UserProfile, VideoMetadata
from models.thumbnail_ctr_predictor import ThumbnailCTRPredictor, ThumbnailAnalysis
from models.watch_time_predictor import WatchTimePredictor, VideoData

# Import real agents
from models.real_agents.content_moderation_agent import ContentModerationAgent
from models.real_agents.sentiment_analysis_agent import SentimentAnalysisAgent
from models.real_agents.dynamic_pricing_agent import DynamicPricingAgent
from models.real_agents.lifetime_value_agent import LifetimeValueAgent
from models.real_agents.retention_predictor_agent import RetentionPredictorAgent
from models.real_agents.engagement_predictor_agent import EngagementPredictorAgent
from models.real_agents.ad_revenue_optimizer_agent import AdRevenueOptimizerAgent
from models.real_agents.creator_success_agent import CreatorSuccessAgent
from models.real_agents.trend_forecaster_agent import TrendForecasterAgent
from models.real_agents.notification_optimizer_agent import NotificationOptimizerAgent

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Model paths
MODEL_DIR = os.environ.get("MODEL_DIR", "./trained_models")


# Global model instances
models: Dict[str, Any] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load models on startup"""
    logger.info("🔥 Loading ML models...")
    
    # Create model directory if it doesn't exist
    os.makedirs(MODEL_DIR, exist_ok=True)
    
    # Load or train models
    try:
        # Core models
        models['viral'] = load_or_train_viral()
        models['churn'] = load_or_train_churn()
        models['fraud'] = load_or_train_fraud()
        models['recommendations'] = load_or_train_recommendations()
        models['thumbnail'] = load_or_train_thumbnail()
        models['watch_time'] = load_or_train_watch_time()
        
        # Real agents
        models['content_moderation'] = load_or_train_agent(ContentModerationAgent, "content_moderation")
        models['sentiment'] = load_or_train_agent(SentimentAnalysisAgent, "sentiment_analysis")
        models['pricing'] = load_or_train_agent(DynamicPricingAgent, "dynamic_pricing")
        models['ltv'] = load_or_train_agent(LifetimeValueAgent, "lifetime_value")
        models['retention'] = load_or_train_agent(RetentionPredictorAgent, "retention_predictor")
        models['engagement'] = load_or_train_agent(EngagementPredictorAgent, "engagement_predictor")
        models['ad_revenue'] = load_or_train_agent(AdRevenueOptimizerAgent, "ad_revenue_optimizer")
        models['creator_success'] = load_or_train_agent(CreatorSuccessAgent, "creator_success")
        models['trend'] = load_or_train_agent(TrendForecasterAgent, "trend_forecaster")
        models['notification'] = load_or_train_agent(NotificationOptimizerAgent, "notification_optimizer")
        
        logger.info(f"✅ Loaded {len(models)} ML models")
    except Exception as e:
        logger.error(f"❌ Failed to load models: {e}")
        import traceback
        traceback.print_exc()
    
    yield
    
    logger.info("👋 Shutting down ML agents...")


# Initialize FastAPI
app = FastAPI(
    title="🔥 MyChannel ML Agents API",
    description="Production-grade ML models for video platform intelligence",
    version="2.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================================
# Model Loading Functions
# ============================================================================

def load_or_train_agent(agent_class, name: str):
    """Generic loader for BaseMLAgent subclasses"""
    model_path = os.path.join(MODEL_DIR, f"{name}.joblib")
    agent = agent_class()
    
    if os.path.exists(model_path):
        agent.load(model_path)
        logger.info(f"📂 Loaded {name} from disk")
    else:
        logger.info(f"🔧 Training {name}...")
        agent.train_and_save(10000)
    
    return agent


def load_or_train_viral() -> ViralPredictor:
    """Load or train viral predictor"""
    model_path = os.path.join(MODEL_DIR, "viral_predictor.joblib")
    predictor = ViralPredictor()
    
    if os.path.exists(model_path):
        predictor.load(model_path)
        logger.info("📂 Loaded viral predictor from disk")
    else:
        logger.info("🔧 Training viral predictor...")
        from models.viral_predictor import generate_training_data
        videos, labels, v24h, v7d, v30d = generate_training_data(10000)
        predictor.train(videos, labels, v24h, v7d, v30d)
        predictor.save(model_path)
    
    return predictor


def load_or_train_churn() -> ChurnPredictor:
    """Load or train churn predictor"""
    model_path = os.path.join(MODEL_DIR, "churn_predictor.joblib")
    predictor = ChurnPredictor()
    
    if os.path.exists(model_path):
        predictor.load(model_path)
        logger.info("📂 Loaded churn predictor from disk")
    else:
        logger.info("🔧 Training churn predictor...")
        from models.churn_predictor import generate_training_data
        users, churned, days = generate_training_data(10000)
        predictor.train(users, churned, days)
        predictor.save(model_path)
    
    return predictor


def load_or_train_fraud() -> FraudDetector:
    """Load or train fraud detector"""
    model_path = os.path.join(MODEL_DIR, "fraud_detector.joblib")
    detector = FraudDetector()
    
    if os.path.exists(model_path):
        detector.load(model_path)
        logger.info("📂 Loaded fraud detector from disk")
    else:
        logger.info("🔧 Training fraud detector...")
        from models.fraud_detector import generate_training_data
        clicks, labels = generate_training_data(50000)
        detector.train(clicks, labels)
        detector.save(model_path)
    
    return detector


def load_or_train_recommendations() -> RecommendationEngine:
    """Load or train recommendation engine"""
    model_path = os.path.join(MODEL_DIR, "recommendation_engine.joblib")
    engine = RecommendationEngine()
    
    if os.path.exists(model_path):
        engine.load(model_path)
        logger.info("📂 Loaded recommendation engine from disk")
    else:
        logger.info("🔧 Training recommendation engine...")
        from models.recommendation_engine import generate_training_data
        interactions, videos = generate_training_data(1000, 5000, 50000)
        engine.train(interactions, videos, epochs=10)
        engine.save(model_path)
    
    return engine


def load_or_train_thumbnail() -> ThumbnailCTRPredictor:
    """Load or train thumbnail CTR predictor"""
    model_path = os.path.join(MODEL_DIR, "thumbnail_ctr_predictor.joblib")
    predictor = ThumbnailCTRPredictor()
    
    if os.path.exists(model_path):
        predictor.load(model_path)
        logger.info("📂 Loaded thumbnail CTR predictor from disk")
    else:
        logger.info("🔧 Training thumbnail CTR predictor...")
        from models.thumbnail_ctr_predictor import generate_training_data
        thumbnails, ctrs, categories = generate_training_data(500)
        predictor.train(thumbnails, ctrs, categories)
        predictor.save(model_path)
    
    return predictor


def load_or_train_watch_time() -> WatchTimePredictor:
    """Load or train watch time predictor"""
    model_path = os.path.join(MODEL_DIR, "watch_time_predictor.joblib")
    predictor = WatchTimePredictor()
    
    if os.path.exists(model_path):
        predictor.load(model_path)
        logger.info("📂 Loaded watch time predictor from disk")
    else:
        logger.info("🔧 Training watch time predictor...")
        from models.watch_time_predictor import generate_training_data
        videos, watch_times, retention_rates = generate_training_data(5000)
        predictor.train(videos, watch_times, retention_rates)
        predictor.save(model_path)
    
    return predictor


# ============================================================================
# Request/Response Models
# ============================================================================

class ViralPredictionRequest(BaseModel):
    title: str
    description: str = ""
    duration_seconds: int
    thumbnail_score: float = Field(ge=0, le=1)
    creator_subscriber_count: int
    creator_avg_views: float
    creator_upload_frequency: float = 1.0
    category: str = "Entertainment"
    tags: List[str] = []
    hour_of_day: int = Field(ge=0, le=23, default=12)
    day_of_week: int = Field(ge=0, le=6, default=3)
    is_shorts: bool = False


class ChurnPredictionRequest(BaseModel):
    user_id: str
    days_since_signup: int
    days_since_last_visit: int
    total_watch_time_hours: float
    avg_session_duration_minutes: float
    sessions_last_7_days: int
    sessions_last_30_days: int
    videos_watched_last_7_days: int
    videos_watched_last_30_days: int
    likes_given: int = 0
    comments_made: int = 0
    shares_made: int = 0
    subscriptions_count: int = 0
    notifications_enabled: bool = True
    is_premium: bool = False
    premium_days_remaining: int = 0
    content_categories_watched: List[str] = []
    device_types_used: List[str] = ["mobile"]
    avg_video_completion_rate: float = 0.5
    creator_subscriptions: int = 0


class FraudDetectionRequest(BaseModel):
    click_id: str
    timestamp: float
    ip_address: str
    user_agent: str
    device_type: str = "desktop"
    os: str = "Windows"
    browser: str = "Chrome"
    screen_resolution: str = "1920x1080"
    timezone: str = "America/New_York"
    language: str = "en-US"
    time_on_page_before_click: float
    mouse_movement_entropy: float = Field(ge=0, le=1)
    scroll_depth_before_click: float = Field(ge=0, le=1)
    click_position_x: float
    click_position_y: float
    session_id: str
    clicks_in_session: int
    time_since_session_start: float
    pages_visited_in_session: int
    clicks_from_ip_last_hour: int
    clicks_from_ip_last_day: int
    unique_ads_clicked_by_ip: int
    conversion_rate_from_ip: float
    is_vpn: bool = False
    is_datacenter: bool = False
    is_proxy: bool = False
    ip_reputation_score: float = Field(ge=0, le=1, default=0)


class RecommendationRequest(BaseModel):
    user_id: str
    watched_video_ids: List[str] = []
    liked_video_ids: List[str] = []
    watch_time_per_video: Dict[str, float] = {}
    subscribed_channels: List[str] = []
    preferred_categories: List[str] = []
    preferred_duration: str = "medium"
    n_recommendations: int = 20
    diversity_weight: float = Field(ge=0, le=1, default=0.2)


class WatchTimeRequest(BaseModel):
    video_id: str
    title: str
    description: str = ""
    duration_seconds: int
    category: str
    tags: List[str] = []
    channel_subscriber_count: int
    channel_avg_watch_time: float
    channel_avg_retention: float
    has_intro: bool = False
    has_outro: bool = False
    has_chapters: bool = False
    thumbnail_ctr: float = 0.05
    is_tutorial: bool = False
    is_entertainment: bool = True
    is_news: bool = False
    is_shorts: bool = False
    hour_of_upload: int = 12
    day_of_week: int = 3


# New Request Models for Real Agents

class ContentModerationRequest(BaseModel):
    text: str
    content_type: str = "comment"  # comment, title, description


class SentimentRequest(BaseModel):
    text: str


class DynamicPricingRequest(BaseModel):
    base_price: float
    demand_score: float = Field(ge=0, le=1, default=0.5)
    inventory_level: int = 100
    competitor_price: float = 0
    hour_of_day: int = Field(ge=0, le=23, default=12)
    day_of_week: int = Field(ge=0, le=6, default=3)
    is_weekend: bool = False
    is_holiday: bool = False
    is_peak_season: bool = False
    user_segment: int = Field(ge=0, le=2, default=1)  # 0=budget, 1=standard, 2=premium
    user_ltv: float = 100.0
    user_purchase_history: int = 0
    product_popularity: float = Field(ge=0, le=1, default=0.5)
    product_age_days: int = 30
    category_demand: float = Field(ge=0, le=1, default=0.5)
    margin_target: float = 0.3
    conversion_rate_history: float = 0.05
    cart_abandonment_rate: float = 0.7
    time_since_last_purchase: int = 30
    competitor_count: int = 5


class LifetimeValueRequest(BaseModel):
    user_id: str
    days_since_signup: int
    total_spend: float = 0
    avg_order_value: float = 0
    order_count: int = 0
    days_since_last_order: int = 30
    order_frequency: float = 0
    is_premium: bool = False
    premium_months: int = 0
    referral_count: int = 0
    support_tickets: int = 0
    engagement_score: float = Field(ge=0, le=1, default=0.5)
    session_count: int = 0
    avg_session_duration: float = 0
    feature_adoption_rate: float = 0
    email_open_rate: float = 0
    notification_click_rate: float = 0
    social_shares: int = 0
    content_created: int = 0
    comments_made: int = 0
    acquisition_channel: int = 0


class RetentionRequest(BaseModel):
    user_id: str
    days_active: int
    sessions_last_7d: int
    sessions_last_30d: int
    avg_session_duration: float = 15
    pages_per_session: float = 5
    features_used: int = 3
    content_consumed: int = 10
    content_created: int = 0
    social_connections: int = 0
    notifications_enabled: bool = True
    email_engaged: bool = False
    support_contacts: int = 0
    bugs_reported: int = 0
    feedback_given: int = 0
    is_premium: bool = False
    days_since_last_session: int = 1
    login_streak: int = 0
    completion_rate: float = 0.5
    satisfaction_score: float = Field(ge=0, le=1, default=0.5)


class EngagementRequest(BaseModel):
    video_id: str
    video_duration_seconds: int
    title_length: int = 50
    description_length: int = 200
    tag_count: int = 5
    thumbnail_ctr: float = 0.05
    is_shorts: bool = False
    creator_subscriber_count: int
    creator_avg_engagement: float = 0.05
    creator_upload_frequency: float = 1.0
    creator_avg_views: float = 1000
    category_avg_engagement: float = 0.05
    hour_of_upload: int = 12
    day_of_week: int = 3
    is_trending_topic: bool = False
    has_call_to_action: bool = False
    has_question_in_title: bool = False
    video_quality_score: float = 0.8
    audio_quality_score: float = 0.8
    has_captions: bool = False
    has_chapters: bool = False
    first_24h_views: int = 100
    avg_watch_percentage: float = 0.5


class AdRevenueRequest(BaseModel):
    video_id: str
    video_duration_seconds: int
    video_category: int = 0
    is_monetizable: bool = True
    creator_channel_age_days: int = 365
    creator_subscriber_count: int
    creator_avg_cpm: float = 3.0
    creator_avg_rpm: float = 2.0
    audience_age_18_24: float = 0.3
    audience_age_25_34: float = 0.35
    audience_age_35_plus: float = 0.35
    audience_tier1_percentage: float = 0.5
    audience_tier2_percentage: float = 0.3
    avg_watch_time_seconds: float = 300
    avg_watch_percentage: float = 0.5
    current_ad_count: int = 2
    has_mid_roll_enabled: bool = True
    is_advertiser_friendly: bool = True
    content_rating: int = 0
    hour_of_day: int = 12
    day_of_week: int = 3
    is_holiday_season: bool = False
    competitor_cpm: float = 3.0
    market_demand_index: float = 1.0
    expected_views: int = 10000


class CreatorSuccessRequest(BaseModel):
    channel_id: str
    channel_age_days: int
    total_videos: int
    total_subscribers: int
    subscribers_gained_30d: int = 0
    subscribers_gained_90d: int = 0
    total_views: int = 0
    views_last_30d: int = 0
    views_last_90d: int = 0
    avg_views_per_video: float = 100
    avg_watch_time: float = 120
    upload_frequency: float = 1.0
    upload_consistency: float = 0.5
    engagement_rate: float = 0.05
    like_ratio: float = 0.04
    comment_ratio: float = 0.01
    subscriber_conversion_rate: float = 0.02
    returning_viewers_rate: float = 0.3
    niche_competition_score: float = 0.5
    content_quality_score: float = 0.7
    thumbnail_ctr_avg: float = 0.05
    title_optimization_score: float = 0.6
    cross_promotion_score: float = 0.3
    community_engagement_score: float = 0.4


class TrendForecastRequest(BaseModel):
    topic: str
    search_volume_current: int
    search_volume_7d_ago: int = 0
    search_volume_30d_ago: int = 0
    social_mentions_current: int = 0
    social_mentions_7d_ago: int = 0
    social_sentiment_score: float = 0.6
    influencer_adoption_rate: float = 0.1
    news_coverage_count: int = 0
    wikipedia_pageviews: int = 0
    youtube_video_count: int = 100
    youtube_video_growth_rate: float = 0.1
    avg_video_views_on_topic: int = 5000
    avg_video_engagement: float = 0.05
    topic_age_days: int = 30
    is_seasonal: bool = False
    is_evergreen: bool = False
    category_trend_score: float = 0.5
    related_topics_trending: int = 0
    geographic_spread: float = 0.5
    demographic_breadth: float = 0.5


class NotificationOptimizationRequest(BaseModel):
    user_id: str
    user_timezone_offset: int = 0
    user_avg_active_hour: int = 12
    user_notifications_received_7d: int = 5
    user_notifications_opened_7d: int = 3
    user_notifications_clicked_7d: int = 1
    user_last_notification_hours_ago: float = 24
    user_session_count_7d: int = 5
    user_avg_session_duration: float = 15
    user_preferred_content_type: int = 0
    user_subscription_tier: int = 0
    notification_type: int = 0
    notification_priority: int = 1
    content_relevance_score: float = 0.5
    content_freshness_hours: float = 12
    is_personalized: bool = False
    has_media: bool = False
    has_action_button: bool = False
    current_hour: int = 12
    current_day_of_week: int = 3
    is_weekend: bool = False
    is_holiday: bool = False


# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "models_loaded": list(models.keys()),
        "version": "2.0.0"
    }


@app.get("/models")
async def list_models():
    """List all loaded models and their status"""
    model_info = {}
    for name, model in models.items():
        model_info[name] = {
            "loaded": model is not None,
            "trained": getattr(model, 'is_trained', False) if model else False,
        }
    return {"models": model_info, "total": len(models)}


@app.post("/predict/viral")
async def predict_viral(request: ViralPredictionRequest):
    """Predict viral probability for a video"""
    if 'viral' not in models or not models['viral'].is_trained:
        raise HTTPException(status_code=503, detail="Viral predictor not available")
    
    video = VideoFeatures(
        title=request.title,
        description=request.description,
        duration_seconds=request.duration_seconds,
        thumbnail_score=request.thumbnail_score,
        creator_subscriber_count=request.creator_subscriber_count,
        creator_avg_views=request.creator_avg_views,
        creator_upload_frequency=request.creator_upload_frequency,
        category=request.category,
        tags=request.tags,
        hour_of_day=request.hour_of_day,
        day_of_week=request.day_of_week,
        is_shorts=request.is_shorts,
    )
    
    prediction = models['viral'].predict(video)
    
    return {
        "viral_probability": prediction.viral_probability,
        "expected_views_24h": prediction.expected_views_24h,
        "expected_views_7d": prediction.expected_views_7d,
        "expected_views_30d": prediction.expected_views_30d,
        "confidence": prediction.confidence,
        "top_factors": prediction.top_factors,
        "recommendations": prediction.recommendations,
    }


@app.post("/predict/churn")
async def predict_churn(request: ChurnPredictionRequest):
    """Predict churn probability for a user"""
    if 'churn' not in models or not models['churn'].is_trained:
        raise HTTPException(status_code=503, detail="Churn predictor not available")
    
    user = UserEngagementFeatures(
        user_id=request.user_id,
        days_since_signup=request.days_since_signup,
        days_since_last_visit=request.days_since_last_visit,
        total_watch_time_hours=request.total_watch_time_hours,
        avg_session_duration_minutes=request.avg_session_duration_minutes,
        sessions_last_7_days=request.sessions_last_7_days,
        sessions_last_30_days=request.sessions_last_30_days,
        videos_watched_last_7_days=request.videos_watched_last_7_days,
        videos_watched_last_30_days=request.videos_watched_last_30_days,
        likes_given=request.likes_given,
        comments_made=request.comments_made,
        shares_made=request.shares_made,
        subscriptions_count=request.subscriptions_count,
        notifications_enabled=request.notifications_enabled,
        is_premium=request.is_premium,
        premium_days_remaining=request.premium_days_remaining,
        content_categories_watched=request.content_categories_watched,
        device_types_used=request.device_types_used,
        avg_video_completion_rate=request.avg_video_completion_rate,
        creator_subscriptions=request.creator_subscriptions,
    )
    
    prediction = models['churn'].predict(user)
    
    return {
        "churn_probability": prediction.churn_probability,
        "risk_level": prediction.risk_level,
        "days_until_likely_churn": prediction.days_until_likely_churn,
        "confidence": prediction.confidence,
        "risk_factors": prediction.risk_factors,
        "retention_actions": prediction.retention_actions,
        "predicted_ltv_if_retained": prediction.predicted_ltv_if_retained,
    }


@app.post("/predict/fraud")
async def detect_fraud(request: FraudDetectionRequest):
    """Detect ad fraud for a click event"""
    if 'fraud' not in models or not models['fraud'].is_trained:
        raise HTTPException(status_code=503, detail="Fraud detector not available")
    
    click = ClickEvent(
        click_id=request.click_id,
        timestamp=request.timestamp,
        ip_address=request.ip_address,
        user_agent=request.user_agent,
        device_type=request.device_type,
        os=request.os,
        browser=request.browser,
        screen_resolution=request.screen_resolution,
        timezone=request.timezone,
        language=request.language,
        time_on_page_before_click=request.time_on_page_before_click,
        mouse_movement_entropy=request.mouse_movement_entropy,
        scroll_depth_before_click=request.scroll_depth_before_click,
        click_position_x=request.click_position_x,
        click_position_y=request.click_position_y,
        session_id=request.session_id,
        clicks_in_session=request.clicks_in_session,
        time_since_session_start=request.time_since_session_start,
        pages_visited_in_session=request.pages_visited_in_session,
        clicks_from_ip_last_hour=request.clicks_from_ip_last_hour,
        clicks_from_ip_last_day=request.clicks_from_ip_last_day,
        unique_ads_clicked_by_ip=request.unique_ads_clicked_by_ip,
        conversion_rate_from_ip=request.conversion_rate_from_ip,
        is_vpn=request.is_vpn,
        is_datacenter=request.is_datacenter,
        is_proxy=request.is_proxy,
        ip_reputation_score=request.ip_reputation_score,
    )
    
    prediction = models['fraud'].predict(click)
    
    return {
        "fraud_probability": prediction.fraud_probability,
        "is_fraud": prediction.is_fraud,
        "fraud_type": prediction.fraud_type,
        "confidence": prediction.confidence,
        "risk_score": prediction.risk_score,
        "anomaly_score": prediction.anomaly_score,
        "should_block": prediction.should_block,
        "should_review": prediction.should_review,
        "fraud_signals": prediction.fraud_signals,
        "recommended_action": prediction.recommended_action,
    }


@app.post("/predict/recommendations")
async def get_recommendations(request: RecommendationRequest):
    """Get personalized video recommendations"""
    if 'recommendations' not in models or not models['recommendations'].is_trained:
        raise HTTPException(status_code=503, detail="Recommendation engine not available")
    
    user = UserProfile(
        user_id=request.user_id,
        watched_video_ids=request.watched_video_ids,
        liked_video_ids=request.liked_video_ids,
        watch_time_per_video=request.watch_time_per_video,
        subscribed_channels=request.subscribed_channels,
        preferred_categories=request.preferred_categories,
        preferred_duration=request.preferred_duration,
    )
    
    result = models['recommendations'].recommend(
        user,
        n_recommendations=request.n_recommendations,
        diversity_weight=request.diversity_weight
    )
    
    return {
        "recommendations": [
            {
                "video_id": rec.video_id,
                "score": rec.score,
                "reason": rec.reason,
                "predicted_watch_time": rec.predicted_watch_time,
            }
            for rec in result.recommendations
        ],
        "diversity_score": result.diversity_score,
        "personalization_score": result.personalization_score,
        "cold_start_mode": result.cold_start_mode,
    }


@app.post("/predict/watch-time")
async def predict_watch_time(request: WatchTimeRequest):
    """Predict watch time and retention for a video"""
    if 'watch_time' not in models or not models['watch_time'].is_trained:
        raise HTTPException(status_code=503, detail="Watch time predictor not available")
    
    video = VideoData(
        video_id=request.video_id,
        title=request.title,
        description=request.description,
        duration_seconds=request.duration_seconds,
        category=request.category,
        tags=request.tags,
        channel_subscriber_count=request.channel_subscriber_count,
        channel_avg_watch_time=request.channel_avg_watch_time,
        channel_avg_retention=request.channel_avg_retention,
        has_intro=request.has_intro,
        has_outro=request.has_outro,
        has_chapters=request.has_chapters,
        thumbnail_ctr=request.thumbnail_ctr,
        is_tutorial=request.is_tutorial,
        is_entertainment=request.is_entertainment,
        is_news=request.is_news,
        is_shorts=request.is_shorts,
        hour_of_upload=request.hour_of_upload,
        day_of_week=request.day_of_week,
    )
    
    prediction = models['watch_time'].predict(video)
    
    return {
        "predicted_watch_time_seconds": prediction.predicted_watch_time_seconds,
        "predicted_retention_rate": prediction.predicted_retention_rate,
        "predicted_avg_view_duration": prediction.predicted_avg_view_duration,
        "confidence": prediction.confidence,
        "retention_curve": prediction.retention_curve,
        "drop_off_points": prediction.drop_off_points,
        "optimization_tips": prediction.optimization_tips,
    }


# ============================================================================
# NEW REAL AGENT ENDPOINTS
# ============================================================================

@app.post("/predict/content-moderation")
async def moderate_content(request: ContentModerationRequest):
    """Moderate content for toxicity, spam, and policy violations"""
    if 'content_moderation' not in models or not models['content_moderation'].is_trained:
        raise HTTPException(status_code=503, detail="Content moderation not available")
    
    result = models['content_moderation'].moderate(request.text)
    
    return {
        "is_safe": result.is_safe,
        "toxicity_score": result.toxicity_score,
        "spam_score": result.spam_score,
        "hate_speech_score": result.hate_speech_score,
        "nsfw_score": result.nsfw_score,
        "confidence": result.confidence,
        "action": result.action,
        "flags": result.flags,
    }


@app.post("/predict/sentiment")
async def analyze_sentiment(request: SentimentRequest):
    """Analyze sentiment of text"""
    if 'sentiment' not in models or not models['sentiment'].is_trained:
        raise HTTPException(status_code=503, detail="Sentiment analysis not available")
    
    result = models['sentiment'].analyze(request.text)
    
    return {
        "sentiment": result.sentiment,
        "positive_score": result.positive_score,
        "negative_score": result.negative_score,
        "neutral_score": result.neutral_score,
        "intensity": result.intensity,
        "emotions": result.emotions,
        "confidence": result.confidence,
    }


@app.post("/predict/dynamic-pricing")
async def optimize_pricing(request: DynamicPricingRequest):
    """Get optimal pricing recommendation"""
    if 'pricing' not in models or not models['pricing'].is_trained:
        raise HTTPException(status_code=503, detail="Dynamic pricing not available")
    
    data = request.model_dump()
    result = models['pricing'].optimize_price(data)
    
    return {
        "optimal_price": result.optimal_price,
        "min_price": result.min_price,
        "max_price": result.max_price,
        "expected_revenue": result.expected_revenue,
        "expected_conversions": result.expected_conversions,
        "price_elasticity": result.price_elasticity,
        "confidence": result.confidence,
        "factors": result.factors,
    }


@app.post("/predict/lifetime-value")
async def predict_ltv(request: LifetimeValueRequest):
    """Predict customer lifetime value"""
    if 'ltv' not in models or not models['ltv'].is_trained:
        raise HTTPException(status_code=503, detail="LTV prediction not available")
    
    data = request.model_dump()
    result = models['ltv'].predict_ltv(data)
    
    return {
        "predicted_ltv": result.predicted_ltv,
        "ltv_30_days": result.ltv_30_days,
        "ltv_90_days": result.ltv_90_days,
        "ltv_365_days": result.ltv_365_days,
        "segment": result.segment,
        "churn_risk": result.churn_risk,
        "upsell_potential": result.upsell_potential,
        "confidence": result.confidence,
    }


@app.post("/predict/retention")
async def predict_retention(request: RetentionRequest):
    """Predict user retention probability"""
    if 'retention' not in models or not models['retention'].is_trained:
        raise HTTPException(status_code=503, detail="Retention prediction not available")
    
    data = request.model_dump()
    result = models['retention'].predict_retention(data)
    
    return {
        "retention_probability": result.retention_probability,
        "days_until_churn": result.days_until_churn,
        "risk_level": result.risk_level,
        "key_factors": result.key_factors,
        "recommended_actions": result.recommended_actions,
        "confidence": result.confidence,
    }


@app.post("/predict/engagement")
async def predict_engagement(request: EngagementRequest):
    """Predict video engagement metrics"""
    if 'engagement' not in models or not models['engagement'].is_trained:
        raise HTTPException(status_code=503, detail="Engagement prediction not available")
    
    data = request.model_dump()
    result = models['engagement'].predict_engagement(data)
    
    return {
        "engagement_rate": result.engagement_rate,
        "like_probability": result.like_probability,
        "comment_probability": result.comment_probability,
        "share_probability": result.share_probability,
        "save_probability": result.save_probability,
        "predicted_likes": result.predicted_likes,
        "predicted_comments": result.predicted_comments,
        "predicted_shares": result.predicted_shares,
        "engagement_tier": result.engagement_tier,
        "optimization_tips": result.optimization_tips,
        "confidence": result.confidence,
    }


@app.post("/predict/ad-revenue")
async def optimize_ad_revenue(request: AdRevenueRequest):
    """Optimize ad revenue for a video"""
    if 'ad_revenue' not in models or not models['ad_revenue'].is_trained:
        raise HTTPException(status_code=503, detail="Ad revenue optimization not available")
    
    data = request.model_dump()
    expected_views = data.pop('expected_views', 10000)
    result = models['ad_revenue'].optimize_revenue(data, expected_views)
    
    return {
        "predicted_cpm": result.predicted_cpm,
        "predicted_rpm": result.predicted_rpm,
        "predicted_fill_rate": result.predicted_fill_rate,
        "optimal_ad_placements": result.optimal_ad_placements,
        "predicted_revenue_per_1k_views": result.predicted_revenue_per_1k_views,
        "predicted_total_revenue": result.predicted_total_revenue,
        "ad_format_recommendations": result.ad_format_recommendations,
        "revenue_tier": result.revenue_tier,
        "optimization_suggestions": result.optimization_suggestions,
        "confidence": result.confidence,
    }


@app.post("/predict/creator-success")
async def predict_creator_success(request: CreatorSuccessRequest):
    """Predict creator success and growth trajectory"""
    if 'creator_success' not in models or not models['creator_success'].is_trained:
        raise HTTPException(status_code=503, detail="Creator success prediction not available")
    
    data = request.model_dump()
    result = models['creator_success'].predict_success(data)
    
    return {
        "success_score": result.success_score,
        "growth_trajectory": result.growth_trajectory,
        "predicted_subscribers_30d": result.predicted_subscribers_30d,
        "predicted_subscribers_90d": result.predicted_subscribers_90d,
        "predicted_subscribers_365d": result.predicted_subscribers_365d,
        "monetization_readiness": result.monetization_readiness,
        "viral_potential": result.viral_potential,
        "consistency_score": result.consistency_score,
        "next_milestone": result.next_milestone,
        "strengths": result.strengths,
        "areas_to_improve": result.areas_to_improve,
        "recommended_actions": result.recommended_actions,
        "confidence": result.confidence,
    }


@app.post("/predict/trend")
async def forecast_trend(request: TrendForecastRequest):
    """Forecast trend for a topic"""
    if 'trend' not in models or not models['trend'].is_trained:
        raise HTTPException(status_code=503, detail="Trend forecasting not available")
    
    data = request.model_dump()
    topic = data.pop('topic', '')
    result = models['trend'].forecast_trend(data, topic)
    
    return {
        "trend_score": result.trend_score,
        "trend_phase": result.trend_phase,
        "days_until_peak": result.days_until_peak,
        "days_of_relevance": result.days_of_relevance,
        "opportunity_score": result.opportunity_score,
        "competition_level": result.competition_level,
        "predicted_search_volume": result.predicted_search_volume,
        "related_topics": result.related_topics,
        "optimal_content_timing": result.optimal_content_timing,
        "content_recommendations": result.content_recommendations,
        "confidence": result.confidence,
    }


@app.post("/predict/notification")
async def optimize_notification(request: NotificationOptimizationRequest):
    """Optimize notification timing and content"""
    if 'notification' not in models or not models['notification'].is_trained:
        raise HTTPException(status_code=503, detail="Notification optimization not available")
    
    data = request.model_dump()
    result = models['notification'].optimize_notification(data)
    
    return {
        "optimal_send_hour": result.optimal_send_hour,
        "optimal_send_day": result.optimal_send_day,
        "click_probability": result.click_probability,
        "open_probability": result.open_probability,
        "fatigue_risk": result.fatigue_risk,
        "should_send": result.should_send,
        "recommended_frequency": result.recommended_frequency,
        "personalization_score": result.personalization_score,
        "content_recommendations": result.content_recommendations,
        "best_notification_type": result.best_notification_type,
        "confidence": result.confidence,
    }


# ============================================================================
# Training Endpoints
# ============================================================================

@app.post("/train/{model_name}")
async def trigger_training(model_name: str, background_tasks: BackgroundTasks):
    """Trigger model retraining (background task)"""
    valid_models = [
        'viral', 'churn', 'fraud', 'recommendations', 'thumbnail', 'watch_time',
        'content_moderation', 'sentiment', 'pricing', 'ltv', 'retention',
        'engagement', 'ad_revenue', 'creator_success', 'trend', 'notification'
    ]
    
    if model_name not in valid_models:
        raise HTTPException(status_code=400, detail=f"Invalid model. Choose from: {valid_models}")
    
    # Add training to background tasks
    background_tasks.add_task(retrain_model, model_name)
    
    return {"message": f"Training {model_name} model in background", "status": "started"}


async def retrain_model(model_name: str):
    """Retrain a specific model"""
    logger.info(f"🔄 Retraining {model_name} model...")
    
    try:
        if model_name == 'viral':
            models['viral'] = load_or_train_viral()
        elif model_name == 'churn':
            models['churn'] = load_or_train_churn()
        elif model_name == 'fraud':
            models['fraud'] = load_or_train_fraud()
        elif model_name == 'recommendations':
            models['recommendations'] = load_or_train_recommendations()
        elif model_name == 'thumbnail':
            models['thumbnail'] = load_or_train_thumbnail()
        elif model_name == 'watch_time':
            models['watch_time'] = load_or_train_watch_time()
        elif model_name == 'content_moderation':
            models['content_moderation'] = load_or_train_agent(ContentModerationAgent, "content_moderation")
        elif model_name == 'sentiment':
            models['sentiment'] = load_or_train_agent(SentimentAnalysisAgent, "sentiment_analysis")
        elif model_name == 'pricing':
            models['pricing'] = load_or_train_agent(DynamicPricingAgent, "dynamic_pricing")
        elif model_name == 'ltv':
            models['ltv'] = load_or_train_agent(LifetimeValueAgent, "lifetime_value")
        elif model_name == 'retention':
            models['retention'] = load_or_train_agent(RetentionPredictorAgent, "retention_predictor")
        elif model_name == 'engagement':
            models['engagement'] = load_or_train_agent(EngagementPredictorAgent, "engagement_predictor")
        elif model_name == 'ad_revenue':
            models['ad_revenue'] = load_or_train_agent(AdRevenueOptimizerAgent, "ad_revenue_optimizer")
        elif model_name == 'creator_success':
            models['creator_success'] = load_or_train_agent(CreatorSuccessAgent, "creator_success")
        elif model_name == 'trend':
            models['trend'] = load_or_train_agent(TrendForecasterAgent, "trend_forecaster")
        elif model_name == 'notification':
            models['notification'] = load_or_train_agent(NotificationOptimizerAgent, "notification_optimizer")
        
        logger.info(f"✅ Finished retraining {model_name}")
    except Exception as e:
        logger.error(f"❌ Failed to retrain {model_name}: {e}")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=os.environ.get("ENV", "development") == "development"
    )
