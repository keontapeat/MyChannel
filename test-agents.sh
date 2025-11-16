#!/bin/bash

################################################################################
# 🧪 TEST ALL ML AGENTS
################################################################################

PROJECT_ID="mychannel-ca26d"
BASE_URL="https://us-central1-${PROJECT_ID}.cloudfunctions.net"

echo "🧪 Testing MyChannel ML Agents..."
echo ""

# Get auth token
echo "🔐 Getting authentication token..."
TOKEN=$(gcloud auth print-identity-token)
echo "✅ Token obtained!"
echo ""

# Test 1: Subscription Pricing
echo "💰 [1/6] Testing Subscription Pricing Agent..."
curl -s -X POST ${BASE_URL}/subscription-pricing \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_data": {
      "watch_time_minutes": 450,
      "engagement_score": 0.75,
      "has_wagered": true,
      "avg_wager_amount": 150
    }
  }' | python3 -m json.tool
echo ""

# Test 2: Ad Optimization
echo "📺 [2/6] Testing Ad Optimization Agent..."
curl -s -X POST ${BASE_URL}/ad-optimization \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "video_data": {
      "duration_seconds": 600,
      "engagement_rate": 0.75
    },
    "user_data": {
      "ad_tolerance_score": 0.6
    }
  }' | python3 -m json.tool
echo ""

# Test 3: Churn Prevention
echo "🛡️ [3/6] Testing Churn Prevention Agent..."
curl -s -X POST ${BASE_URL}/churn-prevention \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_data": {
      "days_since_last_active": 5,
      "watch_time_trend": -0.2,
      "engagement_trend": -0.1
    }
  }' | python3 -m json.tool
echo ""

# Test 4: Fraud Detection
echo "🚨 [4/6] Testing Fraud Detection Agent..."
curl -s -X POST ${BASE_URL}/fraud-detection \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_data": {
      "amount": 500,
      "user_history": {
        "avg_amount": 50,
        "transactions_last_hour": 2
      }
    }
  }' | python3 -m json.tool
echo ""

# Test 5: Viral Prediction
echo "📈 [5/6] Testing Viral Prediction Agent..."
curl -s -X POST ${BASE_URL}/viral-prediction \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "video_data": {
      "title": "INSANE Gaming Moments You Will Not Believe!",
      "thumbnail_quality_score": 0.85,
      "creator_subscribers": 50000
    }
  }' | python3 -m json.tool
echo ""

# Test 6: Recommendations
echo "🎯 [6/6] Testing Recommendation Agent..."
curl -s -X POST ${BASE_URL}/recommendations \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_data": {
      "liked_categories": ["gaming", "music"]
    },
    "available_videos": [
      {"id": "1", "title": "Gaming", "category": "gaming", "views": 150000},
      {"id": "2", "title": "Music", "category": "music", "views": 50000}
    ]
  }' | python3 -m json.tool
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ALL TESTS COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

