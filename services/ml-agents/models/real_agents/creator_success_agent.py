"""
🔥 REAL CREATOR SUCCESS PREDICTION AGENT
Predicts creator growth and success metrics with actual ML

Features:
- Growth trajectory prediction
- Success probability scoring
- Milestone forecasting
- Strategy recommendations
"""

import numpy as np
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_agent import BaseMLAgent


@dataclass
class CreatorSuccessResult:
    success_score: float  # 0-100
    growth_trajectory: str  # 'explosive', 'steady', 'stagnant', 'declining'
    predicted_subscribers_30d: int
    predicted_subscribers_90d: int
    predicted_subscribers_365d: int
    monetization_readiness: float
    viral_potential: float
    consistency_score: float
    next_milestone: Dict[str, Any]
    strengths: List[str]
    areas_to_improve: List[str]
    recommended_actions: List[str]
    confidence: float


class CreatorSuccessAgent(BaseMLAgent):
    """
    🔥 REAL Creator Success Prediction using Gradient Boosting
    
    Predicts:
    - Creator growth trajectory
    - Success probability
    - Milestone timing
    - Strategic recommendations
    """
    
    def __init__(self):
        super().__init__("creator_success", "regressor")
    
    def get_feature_names(self) -> List[str]:
        return [
            'channel_age_days', 'total_videos', 'total_subscribers',
            'subscribers_gained_30d', 'subscribers_gained_90d',
            'total_views', 'views_last_30d', 'views_last_90d',
            'avg_views_per_video', 'avg_watch_time',
            'upload_frequency', 'upload_consistency',
            'engagement_rate', 'like_ratio', 'comment_ratio',
            'subscriber_conversion_rate', 'returning_viewers_rate',
            'niche_competition_score', 'content_quality_score',
            'thumbnail_ctr_avg', 'title_optimization_score',
            'cross_promotion_score', 'community_engagement_score'
        ]
    
    def extract_features(self, data: Dict[str, Any]) -> np.ndarray:
        total_subs = data.get('total_subscribers', 100)
        subs_30d = data.get('subscribers_gained_30d', 10)
        subs_90d = data.get('subscribers_gained_90d', 30)
        
        return np.array([
            data.get('channel_age_days', 90),
            data.get('total_videos', 10),
            total_subs,
            subs_30d,
            subs_90d,
            data.get('total_views', 1000),
            data.get('views_last_30d', 500),
            data.get('views_last_90d', 1500),
            data.get('avg_views_per_video', 100),
            data.get('avg_watch_time', 120),
            data.get('upload_frequency', 1.0),
            data.get('upload_consistency', 0.5),
            data.get('engagement_rate', 0.05),
            data.get('like_ratio', 0.04),
            data.get('comment_ratio', 0.01),
            data.get('subscriber_conversion_rate', 0.02),
            data.get('returning_viewers_rate', 0.3),
            data.get('niche_competition_score', 0.5),
            data.get('content_quality_score', 0.7),
            data.get('thumbnail_ctr_avg', 0.05),
            data.get('title_optimization_score', 0.6),
            data.get('cross_promotion_score', 0.3),
            data.get('community_engagement_score', 0.4),
        ])
    
    def generate_training_data(self, n_samples: int = 10000) -> Tuple[List[Dict], List[float]]:
        np.random.seed(42)
        
        X_data = []
        y_data = []
        
        for i in range(n_samples):
            channel_age = np.random.randint(30, 1500)
            total_videos = max(1, int(channel_age / 7 * np.random.uniform(0.1, 2)))
            
            # Base subscriber count based on age and activity
            base_subs = total_videos * np.random.uniform(10, 500)
            total_subs = int(base_subs * np.random.lognormal(0, 1))
            
            # Growth rates
            growth_multiplier = np.random.uniform(0.5, 3)
            subs_30d = int(total_subs * 0.05 * growth_multiplier)
            subs_90d = int(subs_30d * 2.5)
            
            engagement = np.random.uniform(0.01, 0.15)
            consistency = np.random.uniform(0.2, 1.0)
            quality = np.random.uniform(0.3, 1.0)
            
            data = {
                'channel_age_days': channel_age,
                'total_videos': total_videos,
                'total_subscribers': total_subs,
                'subscribers_gained_30d': subs_30d,
                'subscribers_gained_90d': subs_90d,
                'total_views': total_subs * np.random.uniform(5, 50),
                'views_last_30d': total_subs * np.random.uniform(0.1, 2),
                'views_last_90d': total_subs * np.random.uniform(0.3, 5),
                'avg_views_per_video': total_subs * np.random.uniform(0.05, 0.5),
                'avg_watch_time': np.random.uniform(60, 600),
                'upload_frequency': np.random.uniform(0.1, 7),
                'upload_consistency': consistency,
                'engagement_rate': engagement,
                'like_ratio': engagement * 0.8,
                'comment_ratio': engagement * 0.2,
                'subscriber_conversion_rate': np.random.uniform(0.005, 0.1),
                'returning_viewers_rate': np.random.uniform(0.1, 0.6),
                'niche_competition_score': np.random.uniform(0.2, 0.9),
                'content_quality_score': quality,
                'thumbnail_ctr_avg': np.random.uniform(0.02, 0.12),
                'title_optimization_score': np.random.uniform(0.3, 0.9),
                'cross_promotion_score': np.random.uniform(0.1, 0.8),
                'community_engagement_score': np.random.uniform(0.1, 0.8),
            }
            
            # Calculate success score (0-100)
            success_score = (
                20 * min(engagement / 0.1, 1) +
                15 * min(growth_multiplier / 2, 1) +
                15 * consistency +
                15 * quality +
                10 * min(data['upload_frequency'] / 3, 1) +
                10 * data['thumbnail_ctr_avg'] / 0.1 +
                10 * data['subscriber_conversion_rate'] / 0.05 +
                5 * data['returning_viewers_rate']
            )
            
            success_score = min(100, max(0, success_score * np.random.uniform(0.9, 1.1)))
            
            X_data.append(data)
            y_data.append(success_score)
        
        return X_data, y_data
    
    def predict_success(self, data: Dict[str, Any]) -> CreatorSuccessResult:
        """Predict creator success metrics"""
        result = self.predict(data)
        success_score = max(0, min(100, result['prediction']))
        
        total_subs = data.get('total_subscribers', 100)
        subs_30d = data.get('subscribers_gained_30d', 10)
        
        # Growth trajectory
        growth_rate = subs_30d / max(total_subs, 1)
        if growth_rate > 0.3:
            trajectory = 'explosive'
        elif growth_rate > 0.1:
            trajectory = 'steady'
        elif growth_rate > 0.02:
            trajectory = 'stagnant'
        else:
            trajectory = 'declining'
        
        # Predict future subscribers
        monthly_growth = 1 + growth_rate
        pred_30d = int(total_subs * monthly_growth)
        pred_90d = int(total_subs * (monthly_growth ** 3))
        pred_365d = int(total_subs * (monthly_growth ** 12))
        
        # Monetization readiness (1000 subs, 4000 watch hours)
        sub_progress = min(total_subs / 1000, 1)
        watch_hours = data.get('total_views', 0) * data.get('avg_watch_time', 120) / 3600
        watch_progress = min(watch_hours / 4000, 1)
        monetization_readiness = (sub_progress + watch_progress) / 2
        
        # Viral potential
        engagement = data.get('engagement_rate', 0.05)
        ctr = data.get('thumbnail_ctr_avg', 0.05)
        viral_potential = min(1, (engagement / 0.1 + ctr / 0.08) / 2)
        
        # Consistency score
        consistency_score = data.get('upload_consistency', 0.5)
        
        # Next milestone
        milestones = [100, 1000, 10000, 100000, 1000000]
        next_milestone_value = next((m for m in milestones if m > total_subs), 10000000)
        subs_needed = next_milestone_value - total_subs
        days_to_milestone = int(subs_needed / max(subs_30d / 30, 1))
        
        next_milestone = {
            'target': next_milestone_value,
            'subscribers_needed': subs_needed,
            'estimated_days': min(days_to_milestone, 365 * 5),
        }
        
        # Strengths and improvements
        strengths = []
        improvements = []
        
        if engagement > 0.08:
            strengths.append("High engagement rate")
        else:
            improvements.append("Increase viewer engagement")
        
        if consistency_score > 0.7:
            strengths.append("Consistent upload schedule")
        else:
            improvements.append("Improve upload consistency")
        
        if ctr > 0.06:
            strengths.append("Strong thumbnail performance")
        else:
            improvements.append("Optimize thumbnails for higher CTR")
        
        if data.get('returning_viewers_rate', 0.3) > 0.4:
            strengths.append("Loyal returning audience")
        else:
            improvements.append("Build stronger viewer loyalty")
        
        if data.get('content_quality_score', 0.7) > 0.8:
            strengths.append("High content quality")
        else:
            improvements.append("Invest in content quality")
        
        # Recommended actions
        actions = []
        if growth_rate < 0.05:
            actions.append("Analyze top-performing videos and create similar content")
        if data.get('upload_frequency', 1) < 2:
            actions.append("Increase upload frequency to 2-3 videos per week")
        if data.get('cross_promotion_score', 0.3) < 0.5:
            actions.append("Collaborate with other creators in your niche")
        if data.get('community_engagement_score', 0.4) < 0.5:
            actions.append("Engage more with comments and community posts")
        if ctr < 0.05:
            actions.append("A/B test different thumbnail styles")
        
        return CreatorSuccessResult(
            success_score=round(success_score, 1),
            growth_trajectory=trajectory,
            predicted_subscribers_30d=pred_30d,
            predicted_subscribers_90d=pred_90d,
            predicted_subscribers_365d=pred_365d,
            monetization_readiness=round(monetization_readiness, 2),
            viral_potential=round(viral_potential, 2),
            consistency_score=round(consistency_score, 2),
            next_milestone=next_milestone,
            strengths=strengths[:3],
            areas_to_improve=improvements[:3],
            recommended_actions=actions[:3],
            confidence=result['confidence']
        )


if __name__ == "__main__":
    import logging
    logging.basicConfig(level=logging.INFO)
    
    agent = CreatorSuccessAgent()
    metrics = agent.train_and_save(10000)
    
    print(f"\n📊 Training Metrics: {metrics}")
    
    # Test
    test_data = {
        'channel_age_days': 180,
        'total_videos': 50,
        'total_subscribers': 5000,
        'subscribers_gained_30d': 800,
        'subscribers_gained_90d': 2000,
        'total_views': 100000,
        'views_last_30d': 20000,
        'avg_views_per_video': 2000,
        'avg_watch_time': 180,
        'upload_frequency': 3,
        'upload_consistency': 0.8,
        'engagement_rate': 0.08,
        'thumbnail_ctr_avg': 0.07,
        'content_quality_score': 0.85,
    }
    
    result = agent.predict_success(test_data)
    print(f"\nSuccess Score: {result.success_score}/100")
    print(f"Growth Trajectory: {result.growth_trajectory}")
    print(f"Predicted Subs (90d): {result.predicted_subscribers_90d:,}")
    print(f"Next Milestone: {result.next_milestone}")
    print(f"Strengths: {result.strengths}")
    print(f"Actions: {result.recommended_actions}")







