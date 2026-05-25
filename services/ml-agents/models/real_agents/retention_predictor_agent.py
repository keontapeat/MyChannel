"""
🔥 REAL RETENTION PREDICTOR AGENT
Predicts user retention probability with actual ML
"""

import numpy as np
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_agent import BaseMLAgent


@dataclass
class RetentionResult:
    retention_probability: float
    days_until_churn: int
    risk_level: str
    key_factors: List[Tuple[str, float]]
    recommended_actions: List[str]
    confidence: float


class RetentionPredictorAgent(BaseMLAgent):
    """🔥 REAL Retention Prediction using Gradient Boosting"""
    
    def __init__(self):
        super().__init__("retention_predictor", "classifier")
    
    def get_feature_names(self) -> List[str]:
        return [
            'days_active', 'sessions_last_7d', 'sessions_last_30d',
            'session_trend', 'avg_session_duration', 'pages_per_session',
            'features_used', 'content_consumed', 'content_created',
            'social_connections', 'notifications_enabled', 'email_engaged',
            'support_contacts', 'bugs_reported', 'feedback_given',
            'is_premium', 'days_since_last_session', 'login_streak',
            'completion_rate', 'satisfaction_score'
        ]
    
    def extract_features(self, data: Dict[str, Any]) -> np.ndarray:
        sessions_7d = data.get('sessions_last_7d', 0)
        sessions_30d = data.get('sessions_last_30d', 0)
        session_trend = sessions_7d / max(sessions_30d / 4, 0.1)
        
        return np.array([
            data.get('days_active', 0),
            sessions_7d,
            sessions_30d,
            session_trend,
            data.get('avg_session_duration', 0),
            data.get('pages_per_session', 0),
            data.get('features_used', 0),
            data.get('content_consumed', 0),
            data.get('content_created', 0),
            data.get('social_connections', 0),
            float(data.get('notifications_enabled', True)),
            float(data.get('email_engaged', False)),
            data.get('support_contacts', 0),
            data.get('bugs_reported', 0),
            data.get('feedback_given', 0),
            float(data.get('is_premium', False)),
            data.get('days_since_last_session', 0),
            data.get('login_streak', 0),
            data.get('completion_rate', 0),
            data.get('satisfaction_score', 0.5),
        ])
    
    def generate_training_data(self, n_samples: int = 10000) -> Tuple[List[Dict], List[float]]:
        np.random.seed(42)
        
        X_data = []
        y_data = []
        
        for i in range(n_samples):
            engagement = np.random.uniform(0.1, 1.0)
            is_premium = np.random.random() < 0.3
            days_active = np.random.randint(1, 365)
            
            sessions_30d = int(engagement * 30)
            sessions_7d = int(sessions_30d * np.random.uniform(0.2, 0.35))
            
            data = {
                'days_active': days_active,
                'sessions_last_7d': sessions_7d,
                'sessions_last_30d': sessions_30d,
                'avg_session_duration': np.random.uniform(5, 60) * engagement,
                'pages_per_session': np.random.uniform(2, 20) * engagement,
                'features_used': int(np.random.uniform(1, 10) * engagement),
                'content_consumed': int(np.random.uniform(0, 100) * engagement),
                'content_created': int(np.random.uniform(0, 20) * engagement),
                'social_connections': int(np.random.uniform(0, 50) * engagement),
                'notifications_enabled': np.random.random() < 0.7,
                'email_engaged': np.random.random() < engagement,
                'support_contacts': np.random.randint(0, 5),
                'bugs_reported': np.random.randint(0, 3),
                'feedback_given': np.random.randint(0, 5),
                'is_premium': is_premium,
                'days_since_last_session': int(np.random.exponential(5)),
                'login_streak': int(engagement * np.random.randint(0, 30)),
                'completion_rate': engagement * np.random.uniform(0.5, 1),
                'satisfaction_score': engagement * np.random.uniform(0.6, 1),
            }
            
            # Calculate retention
            retention_score = (
                0.3 * engagement +
                0.2 * (1 if is_premium else 0) +
                0.15 * min(sessions_7d / 7, 1) +
                0.15 * (1 - min(data['days_since_last_session'] / 14, 1)) +
                0.1 * data['satisfaction_score'] +
                0.1 * (1 if data['notifications_enabled'] else 0)
            )
            
            retained = retention_score > 0.5
            
            X_data.append(data)
            y_data.append(int(retained))
        
        return X_data, y_data
    
    def predict_retention(self, data: Dict[str, Any]) -> RetentionResult:
        """Predict retention for a user"""
        result = self.predict(data)
        prob = result['probability']
        
        # Risk level
        if prob > 0.8:
            risk_level = 'low'
            days_until_churn = 180
        elif prob > 0.6:
            risk_level = 'medium'
            days_until_churn = 60
        elif prob > 0.4:
            risk_level = 'high'
            days_until_churn = 30
        else:
            risk_level = 'critical'
            days_until_churn = 7
        
        # Key factors
        importance = self.get_feature_importance()[:5]
        
        # Recommended actions
        actions = []
        if data.get('days_since_last_session', 0) > 7:
            actions.append("Send re-engagement notification")
        if not data.get('notifications_enabled', True):
            actions.append("Prompt to enable notifications")
        if data.get('sessions_last_7d', 0) < 3:
            actions.append("Offer personalized content recommendations")
        if not data.get('is_premium', False) and prob > 0.6:
            actions.append("Offer premium trial")
        if data.get('satisfaction_score', 0.5) < 0.5:
            actions.append("Proactive customer support outreach")
        
        return RetentionResult(
            retention_probability=round(prob, 3),
            days_until_churn=days_until_churn,
            risk_level=risk_level,
            key_factors=importance,
            recommended_actions=actions[:3],
            confidence=result['confidence']
        )

