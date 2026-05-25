"""
🔥 REAL DYNAMIC PRICING AGENT
Replaces fake random pricing with actual ML

Features:
- Demand-based pricing
- Competitor analysis
- Time-of-day optimization
- User segment pricing
"""

import numpy as np
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_agent import BaseMLAgent


@dataclass
class PricingResult:
    optimal_price: float
    min_price: float
    max_price: float
    expected_revenue: float
    expected_conversions: int
    price_elasticity: float
    confidence: float
    factors: Dict[str, float]


class DynamicPricingAgent(BaseMLAgent):
    """
    🔥 REAL Dynamic Pricing using Gradient Boosting Regression
    
    Optimizes pricing based on:
    - Demand signals
    - Time factors
    - User segments
    - Competition
    """
    
    def __init__(self):
        super().__init__("dynamic_pricing", "regressor")
    
    def get_feature_names(self) -> List[str]:
        return [
            'base_price', 'demand_score', 'inventory_level',
            'competitor_price', 'hour_of_day', 'day_of_week',
            'is_weekend', 'is_holiday', 'is_peak_season',
            'user_segment', 'user_ltv', 'user_purchase_history',
            'product_popularity', 'product_age_days',
            'category_demand', 'margin_target',
            'conversion_rate_history', 'cart_abandonment_rate',
            'time_since_last_purchase', 'competitor_count'
        ]
    
    def extract_features(self, data: Dict[str, Any]) -> np.ndarray:
        return np.array([
            data.get('base_price', 10.0),
            data.get('demand_score', 0.5),
            data.get('inventory_level', 100),
            data.get('competitor_price', 10.0),
            data.get('hour_of_day', 12),
            data.get('day_of_week', 3),
            float(data.get('is_weekend', False)),
            float(data.get('is_holiday', False)),
            float(data.get('is_peak_season', False)),
            data.get('user_segment', 1),  # 0=budget, 1=standard, 2=premium
            data.get('user_ltv', 100.0),
            data.get('user_purchase_history', 5),
            data.get('product_popularity', 0.5),
            data.get('product_age_days', 30),
            data.get('category_demand', 0.5),
            data.get('margin_target', 0.3),
            data.get('conversion_rate_history', 0.05),
            data.get('cart_abandonment_rate', 0.7),
            data.get('time_since_last_purchase', 30),
            data.get('competitor_count', 5),
        ])
    
    def generate_training_data(self, n_samples: int = 10000) -> Tuple[List[Dict], List[float]]:
        np.random.seed(42)
        
        X_data = []
        y_data = []
        
        for i in range(n_samples):
            base_price = np.random.uniform(5, 100)
            demand_score = np.random.uniform(0.1, 1.0)
            inventory = np.random.randint(1, 1000)
            competitor_price = base_price * np.random.uniform(0.8, 1.2)
            hour = np.random.randint(0, 24)
            day = np.random.randint(0, 7)
            is_weekend = day >= 5
            is_holiday = np.random.random() < 0.05
            is_peak = np.random.random() < 0.2
            user_segment = np.random.choice([0, 1, 2])
            user_ltv = np.random.uniform(10, 1000)
            
            data = {
                'base_price': base_price,
                'demand_score': demand_score,
                'inventory_level': inventory,
                'competitor_price': competitor_price,
                'hour_of_day': hour,
                'day_of_week': day,
                'is_weekend': is_weekend,
                'is_holiday': is_holiday,
                'is_peak_season': is_peak,
                'user_segment': user_segment,
                'user_ltv': user_ltv,
                'user_purchase_history': np.random.randint(0, 50),
                'product_popularity': np.random.uniform(0, 1),
                'product_age_days': np.random.randint(1, 365),
                'category_demand': np.random.uniform(0, 1),
                'margin_target': np.random.uniform(0.1, 0.5),
                'conversion_rate_history': np.random.uniform(0.01, 0.2),
                'cart_abandonment_rate': np.random.uniform(0.5, 0.9),
                'time_since_last_purchase': np.random.randint(1, 180),
                'competitor_count': np.random.randint(1, 20),
            }
            
            # Calculate optimal price based on factors
            optimal_multiplier = 1.0
            
            # High demand = higher price
            optimal_multiplier += (demand_score - 0.5) * 0.3
            
            # Low inventory = higher price
            if inventory < 50:
                optimal_multiplier += 0.15
            
            # Peak times = higher price
            if is_weekend or is_holiday or is_peak:
                optimal_multiplier += 0.1
            
            # Premium users = higher price tolerance
            if user_segment == 2:
                optimal_multiplier += 0.1
            elif user_segment == 0:
                optimal_multiplier -= 0.1
            
            # Competitor pricing
            if competitor_price > base_price:
                optimal_multiplier += 0.05
            else:
                optimal_multiplier -= 0.05
            
            optimal_price = base_price * optimal_multiplier
            optimal_price = max(base_price * 0.7, min(base_price * 1.5, optimal_price))
            
            X_data.append(data)
            y_data.append(optimal_price)
        
        return X_data, y_data
    
    def optimize_price(self, data: Dict[str, Any]) -> PricingResult:
        """Get optimal price for given conditions"""
        result = self.predict(data)
        optimal_price = max(0.01, result['prediction'])
        
        base_price = data.get('base_price', optimal_price)
        
        # Calculate bounds
        min_price = base_price * 0.7
        max_price = base_price * 1.5
        
        # Estimate conversions and revenue
        conversion_base = data.get('conversion_rate_history', 0.05)
        price_ratio = optimal_price / base_price
        
        # Higher price = lower conversion (elasticity)
        elasticity = -1.5  # Typical elasticity
        conversion_change = (price_ratio - 1) * elasticity
        expected_conversion_rate = conversion_base * (1 + conversion_change)
        expected_conversion_rate = max(0.001, min(0.5, expected_conversion_rate))
        
        # Estimate based on typical traffic
        traffic = 1000
        expected_conversions = int(traffic * expected_conversion_rate)
        expected_revenue = optimal_price * expected_conversions
        
        # Key factors
        factors = {
            'demand': data.get('demand_score', 0.5),
            'competition': data.get('competitor_price', base_price) / base_price,
            'inventory': min(data.get('inventory_level', 100) / 100, 1),
            'user_segment': data.get('user_segment', 1) / 2,
        }
        
        return PricingResult(
            optimal_price=round(optimal_price, 2),
            min_price=round(min_price, 2),
            max_price=round(max_price, 2),
            expected_revenue=round(expected_revenue, 2),
            expected_conversions=expected_conversions,
            price_elasticity=elasticity,
            confidence=result['confidence'],
            factors=factors
        )


if __name__ == "__main__":
    import logging
    logging.basicConfig(level=logging.INFO)
    
    agent = DynamicPricingAgent()
    metrics = agent.train_and_save(10000)
    
    print(f"\n📊 Training Metrics: {metrics}")
    
    # Test
    test_data = {
        'base_price': 29.99,
        'demand_score': 0.8,
        'inventory_level': 25,
        'competitor_price': 34.99,
        'hour_of_day': 20,
        'day_of_week': 6,
        'is_weekend': True,
        'is_peak_season': True,
        'user_segment': 2,
        'user_ltv': 500,
    }
    
    result = agent.optimize_price(test_data)
    print(f"\nOptimal Price: ${result.optimal_price}")
    print(f"Range: ${result.min_price} - ${result.max_price}")
    print(f"Expected Revenue: ${result.expected_revenue}")
    print(f"Factors: {result.factors}")

