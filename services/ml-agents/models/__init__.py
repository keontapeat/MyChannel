# 🔥 REAL ML MODELS - Production Grade
"""
Real trained ML models for MyChannel platform.
No mocks, no hardcoded values - actual machine learning.
"""

from .viral_predictor import ViralPredictor
from .churn_predictor import ChurnPredictor
from .fraud_detector import FraudDetector
from .recommendation_engine import RecommendationEngine
from .thumbnail_ctr_predictor import ThumbnailCTRPredictor
from .watch_time_predictor import WatchTimePredictor

__all__ = [
    "ViralPredictor",
    "ChurnPredictor", 
    "FraudDetector",
    "RecommendationEngine",
    "ThumbnailCTRPredictor",
    "WatchTimePredictor",
]




