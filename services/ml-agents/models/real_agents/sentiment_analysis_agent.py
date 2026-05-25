"""
🔥 REAL SENTIMENT ANALYSIS AGENT
Replaces fake random sentiment with actual ML

Features:
- Positive/Negative/Neutral classification
- Emotion detection
- Intensity scoring
"""

import numpy as np
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_agent import BaseMLAgent


@dataclass
class SentimentResult:
    sentiment: str  # 'positive', 'negative', 'neutral'
    positive_score: float
    negative_score: float
    neutral_score: float
    intensity: float  # 0-1
    emotions: Dict[str, float]
    confidence: float


class SentimentAnalysisAgent(BaseMLAgent):
    """
    🔥 REAL Sentiment Analysis using Gradient Boosting
    """
    
    def __init__(self):
        super().__init__("sentiment_analysis", "regressor")
        
        self.positive_words = [
            'love', 'great', 'awesome', 'amazing', 'excellent', 'fantastic',
            'wonderful', 'best', 'good', 'happy', 'beautiful', 'perfect',
            'brilliant', 'outstanding', 'incredible', 'superb', 'enjoy'
        ]
        self.negative_words = [
            'hate', 'terrible', 'awful', 'horrible', 'worst', 'bad',
            'ugly', 'stupid', 'boring', 'disappointing', 'poor', 'waste',
            'annoying', 'frustrating', 'useless', 'pathetic', 'disgusting'
        ]
        self.intensifiers = [
            'very', 'extremely', 'really', 'absolutely', 'totally',
            'completely', 'incredibly', 'highly', 'super', 'so'
        ]
    
    def get_feature_names(self) -> List[str]:
        return [
            'text_length', 'word_count',
            'positive_word_count', 'negative_word_count',
            'positive_ratio', 'negative_ratio',
            'intensifier_count', 'exclamation_count',
            'question_count', 'caps_ratio',
            'emoji_positive', 'emoji_negative',
            'negation_count', 'but_count',
            'first_person_count', 'superlative_count'
        ]
    
    def extract_features(self, data: Dict[str, Any]) -> np.ndarray:
        text = data.get('text', '')
        text_lower = text.lower()
        words = text_lower.split()
        
        # Basic features
        text_length = len(text)
        word_count = len(words)
        
        # Sentiment word counts
        positive_count = sum(1 for w in words if w in self.positive_words)
        negative_count = sum(1 for w in words if w in self.negative_words)
        positive_ratio = positive_count / max(word_count, 1)
        negative_ratio = negative_count / max(word_count, 1)
        
        # Intensifiers
        intensifier_count = sum(1 for w in words if w in self.intensifiers)
        
        # Punctuation
        exclamation_count = text.count('!')
        question_count = text.count('?')
        caps_ratio = sum(1 for c in text if c.isupper()) / max(len(text), 1)
        
        # Emoji sentiment (simplified)
        positive_emoji = text.count(':)') + text.count(':D') + text.count('❤') + text.count('👍')
        negative_emoji = text.count(':(') + text.count('😢') + text.count('👎') + text.count('😡')
        
        # Negation
        negations = ['not', "n't", 'never', 'no', 'none', 'neither', 'nobody']
        negation_count = sum(1 for w in words if w in negations or w.endswith("n't"))
        
        # Contrast
        but_count = text_lower.count(' but ') + text_lower.count(' however ')
        
        # First person
        first_person = sum(1 for w in words if w in ['i', 'me', 'my', 'mine', 'we', 'our'])
        
        # Superlatives
        superlatives = ['best', 'worst', 'most', 'least', 'greatest', 'biggest']
        superlative_count = sum(1 for w in words if w in superlatives)
        
        return np.array([
            text_length, word_count,
            positive_count, negative_count,
            positive_ratio, negative_ratio,
            intensifier_count, exclamation_count,
            question_count, caps_ratio,
            positive_emoji, negative_emoji,
            negation_count, but_count,
            first_person, superlative_count
        ])
    
    def generate_training_data(self, n_samples: int = 10000) -> Tuple[List[Dict], List[float]]:
        np.random.seed(42)
        
        X_data = []
        y_data = []
        
        positive_templates = [
            "I absolutely love this! Best thing ever!",
            "This is amazing and wonderful!",
            "Great content, really enjoyed it!",
            "Fantastic work, keep it up!",
            "This made my day, so happy!",
        ]
        
        negative_templates = [
            "This is terrible and I hate it.",
            "Worst video ever, complete waste of time.",
            "So disappointing and boring.",
            "Awful content, very frustrating.",
            "I can't stand this, it's horrible.",
        ]
        
        neutral_templates = [
            "This video is about the topic.",
            "The content covers various aspects.",
            "Here is the information presented.",
            "This shows the different options.",
            "The video explains the concept.",
        ]
        
        for i in range(n_samples):
            rand = np.random.random()
            if rand < 0.4:  # Positive
                text = np.random.choice(positive_templates)
                sentiment = np.random.uniform(0.6, 1.0)
            elif rand < 0.7:  # Negative
                text = np.random.choice(negative_templates)
                sentiment = np.random.uniform(0.0, 0.4)
            else:  # Neutral
                text = np.random.choice(neutral_templates)
                sentiment = np.random.uniform(0.4, 0.6)
            
            X_data.append({'text': text})
            y_data.append(sentiment)
        
        return X_data, y_data
    
    def analyze(self, text: str) -> SentimentResult:
        """Analyze sentiment of text"""
        result = self.predict({'text': text})
        score = result['prediction']
        
        # Clamp to 0-1
        score = max(0, min(1, score))
        
        # Determine sentiment
        if score > 0.6:
            sentiment = 'positive'
        elif score < 0.4:
            sentiment = 'negative'
        else:
            sentiment = 'neutral'
        
        # Calculate scores
        positive_score = score
        negative_score = 1 - score
        neutral_score = 1 - abs(score - 0.5) * 2
        
        # Intensity
        intensity = abs(score - 0.5) * 2
        
        # Emotions (simplified)
        emotions = {
            'joy': positive_score * 0.8 if sentiment == 'positive' else 0.1,
            'anger': negative_score * 0.6 if sentiment == 'negative' else 0.05,
            'sadness': negative_score * 0.4 if sentiment == 'negative' else 0.05,
            'surprise': 0.2 if '!' in text else 0.05,
            'neutral': neutral_score,
        }
        
        return SentimentResult(
            sentiment=sentiment,
            positive_score=positive_score,
            negative_score=negative_score,
            neutral_score=neutral_score,
            intensity=intensity,
            emotions=emotions,
            confidence=result['confidence']
        )


if __name__ == "__main__":
    import logging
    logging.basicConfig(level=logging.INFO)
    
    agent = SentimentAnalysisAgent()
    metrics = agent.train_and_save(10000)
    
    print(f"\n📊 Training Metrics: {metrics}")
    
    # Test
    test_texts = [
        "I absolutely love this video! It's amazing!",
        "This is terrible and I hate everything about it.",
        "The video covers the topic adequately.",
    ]
    
    for text in test_texts:
        result = agent.analyze(text)
        print(f"\nText: {text}")
        print(f"  Sentiment: {result.sentiment} ({result.positive_score:.2f})")
        print(f"  Intensity: {result.intensity:.2f}")

