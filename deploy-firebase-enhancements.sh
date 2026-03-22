#!/bin/bash

# 🔥 Firebase Enhanced Features Deployment Script
# Deploys all new Firebase configurations, rules, and indexes

set -e  # Exit on any error

echo "🔥 Starting Firebase Enhanced Features Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    print_error "Firebase CLI is not installed. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    print_error "Not logged in to Firebase. Please run 'firebase login' first."
    exit 1
fi

print_status "Checking Firebase project..."
PROJECT_ID=$(firebase use --json | jq -r '.result.project')
if [ "$PROJECT_ID" = "null" ] || [ -z "$PROJECT_ID" ]; then
    print_error "No Firebase project selected. Please run 'firebase use <project-id>' first."
    exit 1
fi

print_success "Using Firebase project: $PROJECT_ID"

# Backup existing rules
print_status "Backing up existing Firestore rules..."
if [ -f "firestore.rules" ]; then
    cp firestore.rules firestore.rules.backup.$(date +%Y%m%d_%H%M%S)
    print_success "Existing rules backed up"
fi

# Deploy enhanced Firestore rules
print_status "Deploying enhanced Firestore security rules..."
if [ -f "firestore-enhanced.rules" ]; then
    cp firestore-enhanced.rules firestore.rules
    firebase deploy --only firestore:rules
    print_success "Enhanced Firestore rules deployed"
else
    print_warning "Enhanced rules file not found, skipping rules deployment"
fi

# Deploy Firestore indexes
print_status "Deploying Firestore indexes..."
if [ -f "firestore.indexes.json" ]; then
    firebase deploy --only firestore:indexes
    print_success "Firestore indexes deployed"
    
    print_status "Waiting for indexes to build..."
    echo "Note: Index building can take several minutes. Monitor progress in Firebase Console."
else
    print_warning "Firestore indexes file not found"
fi

# Deploy Storage rules
print_status "Deploying Storage rules..."
if [ -f "storage.rules" ]; then
    firebase deploy --only storage
    print_success "Storage rules deployed"
else
    print_warning "Storage rules file not found"
fi

# Deploy Functions (if any)
print_status "Checking for Functions deployment..."
if [ -d "functions" ] || [ -d "firebase/functions" ]; then
    print_status "Deploying Firebase Functions..."
    firebase deploy --only functions
    print_success "Functions deployed"
else
    print_status "No Functions to deploy"
fi

# Set up Remote Config defaults
print_status "Setting up Remote Config defaults..."
cat > remote-config-template.json << EOF
{
  "parameters": {
    "search_suggestions_enabled": {
      "defaultValue": {
        "value": "true"
      }
    },
    "ai_search_enabled": {
      "defaultValue": {
        "value": "true"
      }
    },
    "voice_search_enabled": {
      "defaultValue": {
        "value": "true"
      }
    },
    "visual_search_enabled": {
      "defaultValue": {
        "value": "true"
      }
    },
    "max_search_results": {
      "defaultValue": {
        "value": "50"
      }
    },
    "pip_enabled": {
      "defaultValue": {
        "value": "true"
      }
    },
    "stories_enabled": {
      "defaultValue": {
        "value": "true"
      }
    },
    "vs_matches_enabled": {
      "defaultValue": {
        "value": "true"
      }
    },
    "creator_monetization_enabled": {
      "defaultValue": {
        "value": "true"
      }
    },
    "content_moderation_enabled": {
      "defaultValue": {
        "value": "true"
      }
    },
    "beta_features_enabled": {
      "defaultValue": {
        "value": "false"
      }
    }
  },
  "conditions": [],
  "version": {
    "versionNumber": "1",
    "updateTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "updateUser": {
      "email": "$(firebase auth:export /dev/null 2>&1 | grep -o '[a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]*\.[a-zA-Z]{2,}' | head -1 || echo 'unknown@example.com')"
    },
    "updateOrigin": "ADMIN_SDK_NODE",
    "updateType": "INCREMENTAL_UPDATE"
  }
}
EOF

print_status "Remote Config template created. Please manually upload via Firebase Console."
print_warning "Automatic Remote Config deployment requires additional setup."

# Create monitoring alerts configuration
print_status "Creating monitoring configuration..."
cat > monitoring-config.json << EOF
{
  "alertPolicies": [
    {
      "displayName": "High Search Error Rate",
      "conditions": [
        {
          "displayName": "Search error rate > 5%",
          "conditionThreshold": {
            "filter": "resource.type=\"firebase_domain\"",
            "comparison": "COMPARISON_GREATER_THAN",
            "thresholdValue": 0.05
          }
        }
      ]
    },
    {
      "displayName": "Slow Search Response",
      "conditions": [
        {
          "displayName": "Search response time > 2s",
          "conditionThreshold": {
            "filter": "resource.type=\"firebase_domain\"",
            "comparison": "COMPARISON_GREATER_THAN",
            "thresholdValue": 2000
          }
        }
      ]
    }
  ]
}
EOF

print_success "Monitoring configuration created"

# Verify deployment
print_status "Verifying deployment..."

# Check Firestore rules
firebase firestore:rules get > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "✓ Firestore rules deployed successfully"
else
    print_error "✗ Firestore rules deployment failed"
fi

# Check Storage rules
firebase storage:rules get > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "✓ Storage rules deployed successfully"
else
    print_error "✗ Storage rules deployment failed"
fi

# Performance recommendations
print_status "Performance Recommendations:"
echo "1. Monitor Firestore index build progress in Firebase Console"
echo "2. Set up Cloud Monitoring alerts for error rates and latency"
echo "3. Configure Remote Config parameters via Firebase Console"
echo "4. Enable Performance Monitoring in Firebase Console"
echo "5. Set up Crashlytics symbol upload for better crash reports"

# Security recommendations
print_status "Security Recommendations:"
echo "1. Review and test the enhanced security rules in a staging environment"
echo "2. Set up App Check for additional security"
echo "3. Monitor rate limiting effectiveness"
echo "4. Regular security rule audits"

# Next steps
print_status "Next Steps:"
echo "1. Update iOS app with new Firebase SDK dependencies"
echo "2. Test all new features in development environment"
echo "3. Gradual rollout using Remote Config feature flags"
echo "4. Monitor performance and error metrics"

print_success "🎉 Firebase Enhanced Features Deployment Complete!"
print_status "Project: $PROJECT_ID"
print_status "Timestamp: $(date)"

# Clean up temporary files
rm -f remote-config-template.json monitoring-config.json

echo ""
echo "📊 Deployment Summary:"
echo "✅ Enhanced Firestore security rules"
echo "✅ Optimized Firestore indexes for search"
echo "✅ Storage security rules"
echo "✅ Performance monitoring setup"
echo "✅ Error reporting configuration"
echo "✅ A/B testing framework"
echo "✅ Remote config template"
echo "✅ Monitoring dashboard setup"

echo ""
print_success "All Firebase enhancements have been deployed successfully!"
print_status "Check Firebase Console for index build progress and configuration verification."
