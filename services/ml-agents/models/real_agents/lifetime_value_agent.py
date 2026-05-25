"""
🔥 REAL LIFETIME VALUE (LTV) PREDICTION AGENT
Predicts customer lifetime value with actual ML
"""

import numpy as np
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_agent import BaseMLAgent


@dataclass
class LTVResult:
    predicted_ltv: float
    ltv_30_days: float
    ltv_90_days: float
    ltv_365_days: float
    segment: str  # 'low', 'medium', 'high', 'whale'
    churn_risk: float
    upsell_potential: float
    confidence: float


class LifetimeValueAgent(BaseMLAgent):
    """🔥 REAL LTV Prediction using Gradient Boosting"""
    
    def __init__(self):
        super().__init__("lifetime_value", "regressor")
    
    def get_feature_names(self) -> List[str]:
        return [
            'days_since_signup', 'total_spend', 'avg_order_value',
            'order_count', 'days_since_last_order', 'order_frequency',
            'is_premium', 'premium_months', 'referral_count',
            'support_tickets', 'engagement_score', 'session_count',
            'avg_session_duration', 'feature_adoption_rate',
            'email_open_rate', 'notification_click_rate',
            'social_shares', 'content_created', 'comments_made',
            'acquisition_channel'
        ]
    
    def extract_features(self, data: Dict[str, Any]) -> np.ndarray:
        return np.array([
            data.get('days_since_signup', 30),
            data.get('total_spend', 0),
            data.get('avg_order_value', 0),
            data.get('order_count', 0),
            data.get('days_since_last_order', 30),
            data.get('order_frequency', 0),
            float(data.get('is_premium', False)),
            data.get('premium_months', 0),
            data.get('referral_count', 0),
            data.get('support_tickets', 0),
            data.get('engagement_score', 0.5),
            data.get('session_count', 0),
            data.get('avg_session_duration', 0),
            data.get('feature_adoption_rate', 0),
            data.get('email_open_rate', 0),
            data.get('notification_click_rate', 0),
            data.get('social_shares', 0),
            data.get('content_created', 0),
            data.get('comments_made', 0),
            data.get('acquisition_channel', 0),
        ])
    
    def generate_training_data(self, n_samples: int = 10000) -> Tuple[List[Dict], List[float]]:
        np.random.seed(42)
        
        X_data = []
        y_data = []
        
        for i in range(n_samples):
            days_since_signup = np.random.randint(1, 730)
            is_premium = np.random.random() < 0.3
            engagement = np.random.uniform(0.1, 1.0)
            
            # Base spend calculation
            if is_premium:
                monthly_spend = 12.99
                premium_months = min(days_since_signup // 30, np.random.randint(1, 24))
            else:
                monthly_spend = np.random.uniform(0, 5)  # Ad revenue equivalent
                premium_months = 0
            
            total_spend = monthly_spend * (days_since_signup / 30)
            order_count = int(total_spend / max(monthly_spend, 1))
            
            data = {
                'days_since_signup': days_since_signup,
                'total_spend': total_spend,
                'avg_order_value': monthly_spend,
                'order_count': order_count,
                'days_since_last_order': np.random.randint(1, max(min(days_since_signup, 60), 2)),
                'order_frequency': order_count / max(days_since_signup / 30, 1),
                'is_premium': is_premium,
                'premium_months': premium_months,
                'referral_count': np.random.randint(0, 10),
                'support_tickets': np.random.randint(0, 5),
                'engagement_score': engagement,
                'session_count': int(days_since_signup * engagement * 0.5),
                'avg_session_duration': np.random.uniform(5, 60),
                'feature_adoption_rate': engagement * np.random.uniform(0.5, 1),
                'email_open_rate': np.random.uniform(0.1, 0.6),
                'notification_click_rate': np.random.uniform(0.05, 0.3),
                'social_shares': np.random.randint(0, 50),
                'content_created': np.random.randint(0, 100),
                'comments_made': np.random.randint(0, 200),
                'acquisition_channel': np.random.choice([0, 1, 2, 3]),
            }
            
            # Calculate LTV
            retention_rate = 0.9 if is_premium else 0.7
            retention_rate *= engagement
            
            # Project 12 months
            ltv = 0
            for month in range(12):
                ltv += monthly_spend * (retention_rate ** month)
            
            # Referral value
            ltv += data['referral_count'] * 20
            
            X_data.append(data)
            y_data.append(ltv)
        
        return X_data, y_data
    
    def predict_ltv(self, data: Dict[str, Any]) -> LTVResult:
        """Predict lifetime value for a user"""
        result = self.predict(data)
        ltv = max(0, result['prediction'])
        
        # Time-based projections
        ltv_30 = ltv * 0.1
        ltv_90 = ltv * 0.25
        ltv_365 = ltv
        
        # Segment
        if ltv > 500:
            segment = 'whale'
        elif ltv > 200:
            segment = 'high'
        elif ltv > 50:
            segment = 'medium'
        else:
            segment = 'low'
        
        # Churn risk (inverse of engagement)
        engagement = data.get('engagement_score', 0.5)
        days_inactive = data.get('days_since_last_order', 30)
        churn_risk = min(1, (1 - engagement) * 0.5 + (days_inactive / 60) * 0.5)
        
        # Upsell potential
        is_premium = data.get('is_premium', False)
        upsell_potential = 0.8 if not is_premium and engagement > 0.6 else 0.2
        
        return LTVResult(
            predicted_ltv=round(ltv, 2),
            ltv_30_days=round(ltv_30, 2),
            ltv_90_days=round(ltv_90, 2),
            ltv_365_days=round(ltv_365, 2),
            segment=segment,
            churn_risk=round(churn_risk, 2),
            upsell_potential=round(upsell_potential, 2),
            confidence=result['confidence']
        )

