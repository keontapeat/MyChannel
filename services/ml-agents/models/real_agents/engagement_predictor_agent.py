"""
🔥 REAL ENGAGEMENT PREDICTOR AGENT
Predicts video engagement metrics with actual ML

Features:
- Like probability prediction
- Comment probability prediction
- Share probability prediction
- Engagement rate forecasting
"""

import numpy as np
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_agent import BaseMLAgent


@dataclass
class EngagementResult:
    engagement_rate: float
    like_probability: float
    comment_probability: float
    share_probability: float
    save_probability: float
    predicted_likes: int
    predicted_comments: int
    predicted_shares: int
    engagement_tier: str  # 'viral', 'high', 'medium', 'low'
    optimization_tips: List[str]
    confidence: float


class EngagementPredictorAgent(BaseMLAgent):
    """
    🔥 REAL Engagement Prediction using Gradient Boosting
    
    Predicts engagement metrics based on:
    - Video content features
    - Creator history
    - Audience characteristics
    - Timing factors
    """
    
    def __init__(self):
        super().__init__("engagement_predictor", "regressor")
    
    def get_feature_names(self) -> List[str]:
        return [
            'video_duration_seconds', 'title_length', 'description_length',
            'tag_count', 'thumbnail_ctr', 'is_shorts',
            'creator_subscriber_count', 'creator_avg_engagement',
            'creator_upload_frequency', 'creator_avg_views',
            'category_avg_engagement', 'hour_of_upload', 'day_of_week',
            'is_trending_topic', 'has_call_to_action', 'has_question_in_title',
            'video_quality_score', 'audio_quality_score',
            'has_captions', 'has_chapters',
            'first_24h_views', 'avg_watch_percentage'
        ]
    
    def extract_features(self, data: Dict[str, Any]) -> np.ndarray:
        return np.array([
            data.get('video_duration_seconds', 300),
            data.get('title_length', 50),
            data.get('description_length', 200),
            data.get('tag_count', 5),
            data.get('thumbnail_ctr', 0.05),
            float(data.get('is_shorts', False)),
            data.get('creator_subscriber_count', 1000),
            data.get('creator_avg_engagement', 0.05),
            data.get('creator_upload_frequency', 1.0),
            data.get('creator_avg_views', 1000),
            data.get('category_avg_engagement', 0.05),
            data.get('hour_of_upload', 12),
            data.get('day_of_week', 3),
            float(data.get('is_trending_topic', False)),
            float(data.get('has_call_to_action', False)),
            float(data.get('has_question_in_title', False)),
            data.get('video_quality_score', 0.8),
            data.get('audio_quality_score', 0.8),
            float(data.get('has_captions', False)),
            float(data.get('has_chapters', False)),
            data.get('first_24h_views', 100),
            data.get('avg_watch_percentage', 0.5),
        ])
    
    def generate_training_data(self, n_samples: int = 10000) -> Tuple[List[Dict], List[float]]:
        np.random.seed(42)
        
        X_data = []
        y_data = []
        
        for i in range(n_samples):
            # Generate video features
            is_shorts = np.random.random() < 0.3
            duration = np.random.randint(15, 60) if is_shorts else np.random.randint(120, 1200)
            
            creator_subs = int(np.random.lognormal(8, 2))  # Log-normal for realistic sub counts
            creator_avg_engagement = np.random.uniform(0.01, 0.15)
            
            thumbnail_ctr = np.random.uniform(0.02, 0.12)
            has_cta = np.random.random() < 0.4
            has_question = np.random.random() < 0.3
            
            data = {
                'video_duration_seconds': duration,
                'title_length': np.random.randint(20, 100),
                'description_length': np.random.randint(50, 500),
                'tag_count': np.random.randint(1, 15),
                'thumbnail_ctr': thumbnail_ctr,
                'is_shorts': is_shorts,
                'creator_subscriber_count': creator_subs,
                'creator_avg_engagement': creator_avg_engagement,
                'creator_upload_frequency': np.random.uniform(0.1, 7),
                'creator_avg_views': creator_subs * np.random.uniform(0.01, 0.3),
                'category_avg_engagement': np.random.uniform(0.02, 0.08),
                'hour_of_upload': np.random.randint(0, 24),
                'day_of_week': np.random.randint(0, 7),
                'is_trending_topic': np.random.random() < 0.1,
                'has_call_to_action': has_cta,
                'has_question_in_title': has_question,
                'video_quality_score': np.random.uniform(0.5, 1.0),
                'audio_quality_score': np.random.uniform(0.5, 1.0),
                'has_captions': np.random.random() < 0.6,
                'has_chapters': np.random.random() < 0.3,
                'first_24h_views': int(creator_subs * np.random.uniform(0.01, 0.2)),
                'avg_watch_percentage': np.random.uniform(0.2, 0.8),
            }
            
            # Calculate engagement rate
            base_engagement = creator_avg_engagement
            
            # Shorts boost
            if is_shorts:
                base_engagement *= 1.5
            
            # Thumbnail CTR impact
            base_engagement *= (1 + (thumbnail_ctr - 0.05) * 5)
            
            # CTA and question boost
            if has_cta:
                base_engagement *= 1.2
            if has_question:
                base_engagement *= 1.15
            
            # Watch time impact
            base_engagement *= (1 + data['avg_watch_percentage'] * 0.5)
            
            # Add noise
            engagement_rate = base_engagement * np.random.uniform(0.8, 1.2)
            engagement_rate = min(0.3, max(0.001, engagement_rate))
            
            X_data.append(data)
            y_data.append(engagement_rate)
        
        return X_data, y_data
    
    def predict_engagement(self, data: Dict[str, Any]) -> EngagementResult:
        """Predict engagement metrics for a video"""
        result = self.predict(data)
        engagement_rate = max(0.001, min(0.3, result['prediction']))
        
        views = data.get('first_24h_views', 1000)
        
        # Calculate individual probabilities
        like_prob = engagement_rate * 0.8
        comment_prob = engagement_rate * 0.15
        share_prob = engagement_rate * 0.05
        save_prob = engagement_rate * 0.1
        
        # Predicted counts
        predicted_likes = int(views * like_prob)
        predicted_comments = int(views * comment_prob)
        predicted_shares = int(views * share_prob)
        
        # Engagement tier
        if engagement_rate > 0.15:
            tier = 'viral'
        elif engagement_rate > 0.08:
            tier = 'high'
        elif engagement_rate > 0.03:
            tier = 'medium'
        else:
            tier = 'low'
        
        # Optimization tips
        tips = []
        if not data.get('has_call_to_action', False):
            tips.append("Add a call-to-action to boost engagement")
        if not data.get('has_question_in_title', False):
            tips.append("Consider adding a question to your title")
        if data.get('thumbnail_ctr', 0.05) < 0.05:
            tips.append("Improve thumbnail to increase CTR")
        if not data.get('has_captions', False):
            tips.append("Add captions to reach wider audience")
        if data.get('avg_watch_percentage', 0.5) < 0.4:
            tips.append("Work on retention - hook viewers in first 30 seconds")
        
        return EngagementResult(
            engagement_rate=round(engagement_rate, 4),
            like_probability=round(like_prob, 4),
            comment_probability=round(comment_prob, 4),
            share_probability=round(share_prob, 4),
            save_probability=round(save_prob, 4),
            predicted_likes=predicted_likes,
            predicted_comments=predicted_comments,
            predicted_shares=predicted_shares,
            engagement_tier=tier,
            optimization_tips=tips[:3],
            confidence=result['confidence']
        )


if __name__ == "__main__":
    import logging
    logging.basicConfig(level=logging.INFO)
    
    agent = EngagementPredictorAgent()
    metrics = agent.train_and_save(10000)
    
    print(f"\n📊 Training Metrics: {metrics}")
    
    # Test
    test_data = {
        'video_duration_seconds': 600,
        'title_length': 60,
        'thumbnail_ctr': 0.08,
        'is_shorts': False,
        'creator_subscriber_count': 50000,
        'creator_avg_engagement': 0.06,
        'has_call_to_action': True,
        'has_question_in_title': True,
        'first_24h_views': 5000,
        'avg_watch_percentage': 0.55,
    }
    
    result = agent.predict_engagement(test_data)
    print(f"\nEngagement Rate: {result.engagement_rate:.2%}")
    print(f"Tier: {result.engagement_tier}")
    print(f"Predicted Likes: {result.predicted_likes}")
    print(f"Tips: {result.optimization_tips}")




