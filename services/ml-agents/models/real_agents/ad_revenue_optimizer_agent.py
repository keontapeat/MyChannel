"""
🔥 REAL AD REVENUE OPTIMIZER AGENT
Optimizes ad placement and revenue with actual ML

Features:
- Optimal ad placement timing
- CPM prediction
- Fill rate optimization
- Revenue forecasting
"""

import numpy as np
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_agent import BaseMLAgent


@dataclass
class AdRevenueResult:
    predicted_cpm: float
    predicted_rpm: float
    predicted_fill_rate: float
    optimal_ad_placements: List[int]  # Seconds into video
    predicted_revenue_per_1k_views: float
    predicted_total_revenue: float
    ad_format_recommendations: Dict[str, float]
    revenue_tier: str
    optimization_suggestions: List[str]
    confidence: float


class AdRevenueOptimizerAgent(BaseMLAgent):
    """
    🔥 REAL Ad Revenue Optimization using Gradient Boosting
    
    Optimizes:
    - Ad placement timing
    - CPM/RPM prediction
    - Fill rate estimation
    - Revenue forecasting
    """
    
    def __init__(self):
        super().__init__("ad_revenue_optimizer", "regressor")
    
    def get_feature_names(self) -> List[str]:
        return [
            'video_duration_seconds', 'video_category', 'is_monetizable',
            'creator_channel_age_days', 'creator_subscriber_count',
            'creator_avg_cpm', 'creator_avg_rpm',
            'audience_age_18_24', 'audience_age_25_34', 'audience_age_35_plus',
            'audience_tier1_percentage', 'audience_tier2_percentage',
            'avg_watch_time_seconds', 'avg_watch_percentage',
            'current_ad_count', 'has_mid_roll_enabled',
            'is_advertiser_friendly', 'content_rating',
            'hour_of_day', 'day_of_week', 'is_holiday_season',
            'competitor_cpm', 'market_demand_index'
        ]
    
    def extract_features(self, data: Dict[str, Any]) -> np.ndarray:
        return np.array([
            data.get('video_duration_seconds', 600),
            data.get('video_category', 0),  # Encoded category
            float(data.get('is_monetizable', True)),
            data.get('creator_channel_age_days', 365),
            data.get('creator_subscriber_count', 10000),
            data.get('creator_avg_cpm', 3.0),
            data.get('creator_avg_rpm', 2.0),
            data.get('audience_age_18_24', 0.3),
            data.get('audience_age_25_34', 0.35),
            data.get('audience_age_35_plus', 0.35),
            data.get('audience_tier1_percentage', 0.5),  # US, UK, etc.
            data.get('audience_tier2_percentage', 0.3),
            data.get('avg_watch_time_seconds', 300),
            data.get('avg_watch_percentage', 0.5),
            data.get('current_ad_count', 2),
            float(data.get('has_mid_roll_enabled', True)),
            float(data.get('is_advertiser_friendly', True)),
            data.get('content_rating', 0),  # 0=all, 1=teen, 2=mature
            data.get('hour_of_day', 12),
            data.get('day_of_week', 3),
            float(data.get('is_holiday_season', False)),
            data.get('competitor_cpm', 3.0),
            data.get('market_demand_index', 1.0),
        ])
    
    def generate_training_data(self, n_samples: int = 10000) -> Tuple[List[Dict], List[float]]:
        np.random.seed(42)
        
        X_data = []
        y_data = []
        
        # Category CPM multipliers
        category_cpm = {
            0: 2.5,   # Entertainment
            1: 4.0,   # Finance
            2: 3.5,   # Tech
            3: 2.0,   # Gaming
            4: 3.0,   # Education
            5: 2.8,   # Lifestyle
            6: 5.0,   # Business
            7: 1.5,   # Music
        }
        
        for i in range(n_samples):
            duration = np.random.randint(60, 3600)
            category = np.random.randint(0, 8)
            is_monetizable = np.random.random() < 0.9
            
            tier1_pct = np.random.uniform(0.1, 0.8)
            tier2_pct = np.random.uniform(0.1, 0.5)
            
            is_advertiser_friendly = np.random.random() < 0.85
            is_holiday = np.random.random() < 0.15
            
            data = {
                'video_duration_seconds': duration,
                'video_category': category,
                'is_monetizable': is_monetizable,
                'creator_channel_age_days': np.random.randint(90, 2000),
                'creator_subscriber_count': int(np.random.lognormal(9, 2)),
                'creator_avg_cpm': np.random.uniform(1, 10),
                'creator_avg_rpm': np.random.uniform(0.5, 8),
                'audience_age_18_24': np.random.uniform(0.1, 0.5),
                'audience_age_25_34': np.random.uniform(0.2, 0.5),
                'audience_age_35_plus': np.random.uniform(0.1, 0.4),
                'audience_tier1_percentage': tier1_pct,
                'audience_tier2_percentage': tier2_pct,
                'avg_watch_time_seconds': duration * np.random.uniform(0.3, 0.8),
                'avg_watch_percentage': np.random.uniform(0.3, 0.8),
                'current_ad_count': np.random.randint(0, 5),
                'has_mid_roll_enabled': duration > 480,
                'is_advertiser_friendly': is_advertiser_friendly,
                'content_rating': np.random.choice([0, 1, 2], p=[0.7, 0.2, 0.1]),
                'hour_of_day': np.random.randint(0, 24),
                'day_of_week': np.random.randint(0, 7),
                'is_holiday_season': is_holiday,
                'competitor_cpm': np.random.uniform(2, 6),
                'market_demand_index': np.random.uniform(0.5, 1.5),
            }
            
            # Calculate CPM
            base_cpm = category_cpm.get(category, 2.5)
            
            # Tier 1 audience boost
            base_cpm *= (1 + tier1_pct * 0.8)
            
            # Advertiser friendly
            if not is_advertiser_friendly:
                base_cpm *= 0.3
            
            # Monetizable
            if not is_monetizable:
                base_cpm = 0
            
            # Holiday boost
            if is_holiday:
                base_cpm *= 1.3
            
            # Market demand
            base_cpm *= data['market_demand_index']
            
            # Add noise
            cpm = base_cpm * np.random.uniform(0.8, 1.2)
            cpm = max(0, min(15, cpm))
            
            X_data.append(data)
            y_data.append(cpm)
        
        return X_data, y_data
    
    def optimize_revenue(self, data: Dict[str, Any], expected_views: int = 10000) -> AdRevenueResult:
        """Optimize ad revenue for a video"""
        result = self.predict(data)
        predicted_cpm = max(0, result['prediction'])
        
        # Calculate RPM (revenue per 1000 views after YouTube's cut)
        youtube_cut = 0.45
        predicted_rpm = predicted_cpm * (1 - youtube_cut)
        
        # Fill rate based on advertiser friendliness
        base_fill_rate = 0.85
        if not data.get('is_advertiser_friendly', True):
            base_fill_rate = 0.4
        if not data.get('is_monetizable', True):
            base_fill_rate = 0
        
        # Optimal ad placements
        duration = data.get('video_duration_seconds', 600)
        placements = [0]  # Pre-roll always
        
        if duration >= 480:  # 8+ minutes = mid-rolls
            # Place mid-rolls at natural break points
            mid_roll_interval = 180  # Every 3 minutes
            current = 120  # First mid-roll at 2 minutes
            while current < duration - 60:
                placements.append(current)
                current += mid_roll_interval
        
        placements.append(duration)  # Post-roll
        
        # Revenue calculations
        revenue_per_1k = predicted_rpm * base_fill_rate
        total_revenue = (expected_views / 1000) * revenue_per_1k
        
        # Ad format recommendations
        ad_formats = {
            'skippable_in_stream': 0.6,
            'non_skippable': 0.2 if data.get('is_advertiser_friendly', True) else 0.05,
            'bumper': 0.15,
            'overlay': 0.05,
        }
        
        # Revenue tier
        if predicted_cpm > 8:
            tier = 'premium'
        elif predicted_cpm > 4:
            tier = 'high'
        elif predicted_cpm > 2:
            tier = 'medium'
        else:
            tier = 'low'
        
        # Optimization suggestions
        suggestions = []
        if data.get('audience_tier1_percentage', 0.5) < 0.4:
            suggestions.append("Target more Tier 1 countries (US, UK, CA) for higher CPMs")
        if not data.get('is_advertiser_friendly', True):
            suggestions.append("Review content for advertiser-friendliness")
        if duration < 480:
            suggestions.append("Make videos 8+ minutes to enable mid-roll ads")
        if data.get('avg_watch_percentage', 0.5) < 0.5:
            suggestions.append("Improve retention to increase ad impressions")
        if data.get('video_category', 0) in [3, 7]:  # Gaming, Music
            suggestions.append("Consider cross-promoting to higher CPM categories")
        
        return AdRevenueResult(
            predicted_cpm=round(predicted_cpm, 2),
            predicted_rpm=round(predicted_rpm, 2),
            predicted_fill_rate=round(base_fill_rate, 2),
            optimal_ad_placements=placements,
            predicted_revenue_per_1k_views=round(revenue_per_1k, 2),
            predicted_total_revenue=round(total_revenue, 2),
            ad_format_recommendations=ad_formats,
            revenue_tier=tier,
            optimization_suggestions=suggestions[:3],
            confidence=result['confidence']
        )


if __name__ == "__main__":
    import logging
    logging.basicConfig(level=logging.INFO)
    
    agent = AdRevenueOptimizerAgent()
    metrics = agent.train_and_save(10000)
    
    print(f"\n📊 Training Metrics: {metrics}")
    
    # Test
    test_data = {
        'video_duration_seconds': 900,
        'video_category': 1,  # Finance
        'is_monetizable': True,
        'creator_subscriber_count': 100000,
        'audience_tier1_percentage': 0.6,
        'is_advertiser_friendly': True,
        'is_holiday_season': True,
        'market_demand_index': 1.2,
    }
    
    result = agent.optimize_revenue(test_data, expected_views=50000)
    print(f"\nPredicted CPM: ${result.predicted_cpm}")
    print(f"Predicted RPM: ${result.predicted_rpm}")
    print(f"Total Revenue (50k views): ${result.predicted_total_revenue}")
    print(f"Optimal Ad Placements: {result.optimal_ad_placements}")
    print(f"Suggestions: {result.optimization_suggestions}")




