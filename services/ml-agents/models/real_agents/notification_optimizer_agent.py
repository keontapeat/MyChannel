"""
🔥 REAL NOTIFICATION OPTIMIZER AGENT
Optimizes notification timing and content with actual ML

Features:
- Optimal send time prediction
- Click probability prediction
- Notification fatigue detection
- Content personalization
"""

import numpy as np
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_agent import BaseMLAgent


@dataclass
class NotificationOptimizationResult:
    optimal_send_hour: int  # 0-23
    optimal_send_day: int  # 0-6 (Mon-Sun)
    click_probability: float
    open_probability: float
    fatigue_risk: float
    should_send: bool
    recommended_frequency: str  # 'daily', 'weekly', 'bi-weekly'
    personalization_score: float
    content_recommendations: List[str]
    best_notification_type: str
    confidence: float


class NotificationOptimizerAgent(BaseMLAgent):
    """
    🔥 REAL Notification Optimization using Gradient Boosting
    
    Optimizes:
    - Send timing
    - Click/open rates
    - Fatigue prevention
    - Content personalization
    """
    
    def __init__(self):
        super().__init__("notification_optimizer", "classifier")
    
    def get_feature_names(self) -> List[str]:
        return [
            'user_timezone_offset', 'user_avg_active_hour',
            'user_notifications_received_7d', 'user_notifications_opened_7d',
            'user_notifications_clicked_7d', 'user_last_notification_hours_ago',
            'user_session_count_7d', 'user_avg_session_duration',
            'user_preferred_content_type', 'user_subscription_tier',
            'notification_type', 'notification_priority',
            'content_relevance_score', 'content_freshness_hours',
            'is_personalized', 'has_media', 'has_action_button',
            'current_hour', 'current_day_of_week',
            'is_weekend', 'is_holiday'
        ]
    
    def extract_features(self, data: Dict[str, Any]) -> np.ndarray:
        notifications_7d = data.get('user_notifications_received_7d', 5)
        opened_7d = data.get('user_notifications_opened_7d', 3)
        clicked_7d = data.get('user_notifications_clicked_7d', 1)
        
        return np.array([
            data.get('user_timezone_offset', 0),
            data.get('user_avg_active_hour', 12),
            notifications_7d,
            opened_7d,
            clicked_7d,
            data.get('user_last_notification_hours_ago', 24),
            data.get('user_session_count_7d', 5),
            data.get('user_avg_session_duration', 15),
            data.get('user_preferred_content_type', 0),
            data.get('user_subscription_tier', 0),
            data.get('notification_type', 0),
            data.get('notification_priority', 1),
            data.get('content_relevance_score', 0.5),
            data.get('content_freshness_hours', 12),
            float(data.get('is_personalized', False)),
            float(data.get('has_media', False)),
            float(data.get('has_action_button', False)),
            data.get('current_hour', 12),
            data.get('current_day_of_week', 3),
            float(data.get('is_weekend', False)),
            float(data.get('is_holiday', False)),
        ])
    
    def generate_training_data(self, n_samples: int = 10000) -> Tuple[List[Dict], List[float]]:
        np.random.seed(42)
        
        X_data = []
        y_data = []
        
        for i in range(n_samples):
            # User engagement level
            engagement_level = np.random.choice(['high', 'medium', 'low'], p=[0.2, 0.5, 0.3])
            
            if engagement_level == 'high':
                notifications_7d = np.random.randint(3, 10)
                opened_7d = int(notifications_7d * np.random.uniform(0.6, 0.9))
                clicked_7d = int(opened_7d * np.random.uniform(0.3, 0.6))
                session_count = np.random.randint(10, 30)
            elif engagement_level == 'medium':
                notifications_7d = np.random.randint(2, 7)
                opened_7d = int(notifications_7d * np.random.uniform(0.3, 0.6))
                clicked_7d = int(opened_7d * np.random.uniform(0.2, 0.4))
                session_count = np.random.randint(3, 15)
            else:
                notifications_7d = np.random.randint(1, 5)
                opened_7d = int(notifications_7d * np.random.uniform(0.1, 0.3))
                clicked_7d = int(opened_7d * np.random.uniform(0.1, 0.3))
                session_count = np.random.randint(0, 5)
            
            user_active_hour = np.random.randint(8, 23)
            current_hour = np.random.randint(0, 24)
            hour_diff = abs(current_hour - user_active_hour)
            
            is_personalized = np.random.random() < 0.4
            content_relevance = np.random.uniform(0.2, 1.0)
            last_notification_hours = np.random.exponential(24)
            
            data = {
                'user_timezone_offset': np.random.randint(-12, 12),
                'user_avg_active_hour': user_active_hour,
                'user_notifications_received_7d': notifications_7d,
                'user_notifications_opened_7d': opened_7d,
                'user_notifications_clicked_7d': clicked_7d,
                'user_last_notification_hours_ago': last_notification_hours,
                'user_session_count_7d': session_count,
                'user_avg_session_duration': np.random.uniform(5, 60),
                'user_preferred_content_type': np.random.randint(0, 5),
                'user_subscription_tier': np.random.choice([0, 1, 2]),
                'notification_type': np.random.randint(0, 4),
                'notification_priority': np.random.choice([0, 1, 2]),
                'content_relevance_score': content_relevance,
                'content_freshness_hours': np.random.exponential(12),
                'is_personalized': is_personalized,
                'has_media': np.random.random() < 0.3,
                'has_action_button': np.random.random() < 0.5,
                'current_hour': current_hour,
                'current_day_of_week': np.random.randint(0, 7),
                'is_weekend': np.random.random() < 0.28,
                'is_holiday': np.random.random() < 0.05,
            }
            
            # Calculate click probability
            base_click_prob = 0.1
            
            # Engagement level impact
            if engagement_level == 'high':
                base_click_prob *= 2
            elif engagement_level == 'low':
                base_click_prob *= 0.5
            
            # Time relevance
            if hour_diff < 2:
                base_click_prob *= 1.5
            elif hour_diff > 6:
                base_click_prob *= 0.6
            
            # Personalization
            if is_personalized:
                base_click_prob *= 1.4
            
            # Content relevance
            base_click_prob *= (0.5 + content_relevance * 0.5)
            
            # Fatigue (too many notifications)
            if last_notification_hours < 4:
                base_click_prob *= 0.5
            elif last_notification_hours < 12:
                base_click_prob *= 0.8
            
            clicked = 1 if np.random.random() < base_click_prob else 0
            
            X_data.append(data)
            y_data.append(clicked)
        
        return X_data, y_data
    
    def optimize_notification(self, data: Dict[str, Any]) -> NotificationOptimizationResult:
        """Optimize notification for a user"""
        result = self.predict(data)
        click_probability = result['probability']
        
        # Find optimal hour (near user's active time)
        user_active_hour = data.get('user_avg_active_hour', 12)
        optimal_hour = user_active_hour
        
        # Open probability (typically higher than click)
        open_probability = min(1, click_probability * 2.5)
        
        # Fatigue risk
        notifications_7d = data.get('user_notifications_received_7d', 5)
        last_notification_hours = data.get('user_last_notification_hours_ago', 24)
        
        fatigue_risk = 0
        if notifications_7d > 10:
            fatigue_risk += 0.4
        elif notifications_7d > 5:
            fatigue_risk += 0.2
        
        if last_notification_hours < 4:
            fatigue_risk += 0.4
        elif last_notification_hours < 12:
            fatigue_risk += 0.2
        
        fatigue_risk = min(1, fatigue_risk)
        
        # Should send decision
        should_send = click_probability > 0.05 and fatigue_risk < 0.7
        
        # Recommended frequency
        if notifications_7d < 3:
            frequency = 'daily'
        elif notifications_7d < 7:
            frequency = 'weekly'
        else:
            frequency = 'bi-weekly'
        
        # Personalization score
        is_personalized = data.get('is_personalized', False)
        content_relevance = data.get('content_relevance_score', 0.5)
        personalization_score = (float(is_personalized) * 0.5 + content_relevance * 0.5)
        
        # Best notification type
        notification_types = ['new_video', 'live_stream', 'community_post', 'milestone']
        session_count = data.get('user_session_count_7d', 5)
        
        if session_count > 10:
            best_type = 'new_video'
        elif session_count > 5:
            best_type = 'live_stream'
        else:
            best_type = 'milestone'  # Re-engagement
        
        # Optimal day (based on typical engagement patterns)
        current_day = data.get('current_day_of_week', 3)
        # Tue-Thu typically best for engagement
        optimal_day = 2 if current_day < 2 else (3 if current_day < 4 else 2)
        
        # Content recommendations
        recommendations = []
        if not is_personalized:
            recommendations.append("Personalize notification content")
        if not data.get('has_media', False):
            recommendations.append("Add thumbnail or preview image")
        if not data.get('has_action_button', False):
            recommendations.append("Include clear call-to-action button")
        if content_relevance < 0.5:
            recommendations.append("Improve content targeting relevance")
        if fatigue_risk > 0.5:
            recommendations.append("Reduce notification frequency for this user")
        
        return NotificationOptimizationResult(
            optimal_send_hour=optimal_hour,
            optimal_send_day=optimal_day,
            click_probability=round(click_probability, 3),
            open_probability=round(open_probability, 3),
            fatigue_risk=round(fatigue_risk, 3),
            should_send=should_send,
            recommended_frequency=frequency,
            personalization_score=round(personalization_score, 3),
            content_recommendations=recommendations[:3],
            best_notification_type=best_type,
            confidence=result['confidence']
        )


if __name__ == "__main__":
    import logging
    logging.basicConfig(level=logging.INFO)
    
    agent = NotificationOptimizerAgent()
    metrics = agent.train_and_save(10000)
    
    print(f"\n📊 Training Metrics: {metrics}")
    
    # Test
    test_data = {
        'user_avg_active_hour': 19,
        'user_notifications_received_7d': 4,
        'user_notifications_opened_7d': 3,
        'user_notifications_clicked_7d': 1,
        'user_last_notification_hours_ago': 48,
        'user_session_count_7d': 8,
        'content_relevance_score': 0.8,
        'is_personalized': True,
        'has_media': True,
        'has_action_button': True,
        'current_hour': 18,
    }
    
    result = agent.optimize_notification(test_data)
    print(f"\nOptimal Send Hour: {result.optimal_send_hour}:00")
    print(f"Click Probability: {result.click_probability:.1%}")
    print(f"Open Probability: {result.open_probability:.1%}")
    print(f"Fatigue Risk: {result.fatigue_risk:.1%}")
    print(f"Should Send: {result.should_send}")
    print(f"Best Type: {result.best_notification_type}")
    print(f"Recommendations: {result.content_recommendations}")







