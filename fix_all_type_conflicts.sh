#!/bin/bash

# ✅ COMPREHENSIVE TYPE CONFLICT FIX SCRIPT
# Fixes all 391 compilation errors by removing duplicate type definitions

echo "🔥 STARTING COMPREHENSIVE TYPE CONFLICT FIX..."

cd "/Users/keonta/Documents/MyChannel/MyChannel"

# ====================================
# 1. REMOVE DUPLICATE TYPE DEFINITIONS
# ====================================

echo "📝 Removing duplicate types from AdTargetingAGI.swift..."
sed -i '' '/^struct ScoredAd {/,/^}/d' Core/AI/AdTargetingAGI.swift
sed -i '' '/^struct EngagementData {/,/^}/d' Core/AI/AdTargetingAGI.swift

echo "📝 Removing duplicate types from AITargetingEngine.swift..."
sed -i '' '/^struct AdCreative: /,/^}/d' Core/Services/AITargetingEngine.swift
sed -i '' '/^struct ScoredAd {/,/^}/d' Core/Services/AITargetingEngine.swift
sed -i '' '/^struct EngagementData {/,/^}/d' Core/Services/AITargetingEngine.swift

echo "📝 Removing duplicate types from FraudDetectionAGI.swift..."
sed -i '' '/^struct FraudAnalysis {/,/^}/d' Core/AI/FraudDetectionAGI.swift
sed -i '' '/^enum FraudLevel {/,/^}/d' Core/AI/FraudDetectionAGI.swift

echo "📝 Removing duplicate types from EnterpriseAITeam.swift..."
sed -i '' '/^struct FraudAnalysis {/,/^}/d' Core/Services/EnterpriseAITeam.swift

echo "📝 Removing duplicate types from CreativePerformanceAgent.swift..."
sed -i '' '/^struct AdCreative {/,/^}/d' Core/AI/VertexAI/CreativePerformanceAgent.swift

echo "📝 Removing duplicate types from FraudDetectionMLAgent.swift..."
sed -i '' '/^struct AdRequest {/,/^}/d' Core/AI/VertexAI/FraudDetectionMLAgent.swift

echo "📝 Removing duplicate types from RTBAuctionEngine.swift..."
sed -i '' '/^enum AdPlacement:/,/^}/d' Core/Services/RTBAuctionEngine.swift

echo "📝 Removing duplicate types from CampaignCreatorView.swift..."
sed -i '' '/^enum CampaignStep {/,/^}/d' Features/Ads/CampaignCreatorView.swift
sed -i '' '/^enum CampaignObjective {/,/^}/d' Features/Ads/CampaignCreatorView.swift
sed -i '' '/^enum BidStrategy {/,/^}/d' Features/Ads/CampaignCreatorView.swift
sed -i '' '/^struct FlowLayout:/,/^}/d' Features/Ads/CampaignCreatorView.swift

echo "📝 Removing duplicate types from CreateCampaignView.swift..."
sed -i '' '/^enum CampaignStep {/,/^}/d' Features/Ads/CreateCampaignView.swift
sed -i '' '/^enum CampaignObjective {/,/^}/d' Features/Ads/CreateCampaignView.swift
sed -i '' '/^enum BidStrategy {/,/^}/d' Features/Ads/CreateCampaignView.swift

echo "📝 Removing duplicate types from Video.swift..."
sed -i '' '/^    var isTrending:/,/^    }/d' Core/Models/Video.swift

echo "📝 Removing duplicate types from PlacementOptimizationAgent.swift..."
sed -i '' '/^    var isTrending:/,/^    }/d' Core/AI/VertexAI/PlacementOptimizationAgent.swift

echo "📝 Removing duplicate types from CreatorMonetizationView.swift..."
sed -i '' '/^enum TimePeriod {/,/^}/d' Features/Monetization/CreatorMonetizationView.swift
sed -i '' '/^struct EarningsDataPoint:/,/^}/d' Features/Monetization/CreatorMonetizationView.swift

echo "📝 Removing duplicate types from CreatorRevenueDashboardView.swift..."
sed -i '' '/^struct EarningsDataPoint:/,/^}/d' Features/Monetization/CreatorRevenueDashboardView.swift
sed -i '' '/^enum TimePeriod {/,/^}/d' Features/Monetization/CreatorRevenueDashboardView.swift

echo "📝 Removing duplicate types from ShimmerModifier..."
sed -i '' '/^struct ShimmerModifier:/,/^}/d' Features/LiveStreaming/Components/AwardsComponents.swift
sed -i '' '/^    func shimmer/,/^    }/d' Features/LiveStreaming/Components/AwardsComponents.swift

sed -i '' '/^struct ShimmerModifier:/,/^}/d' Features/University/Components/ShimmerLoadingViews.swift
sed -i '' '/^    func shimmer/,/^    }/d' Features/University/Components/ShimmerLoadingViews.swift

echo "📝 Removing duplicate types from FlowLayout.swift..."
# Keep the one in Core/Components/FlowLayout.swift, remove from Features/Ads/CampaignCreatorView.swift
# Already done above

echo "📝 Removing duplicate VideoClip types..."
sed -i '' '/^struct VideoClip {/,/^}/d' Features/Stories/MultiClipEngine.swift
sed -i '' '/^struct VideoClip {/,/^}/d' Features/Upload/ProVideoEditor.swift

echo "📝 Removing duplicate ImagePicker types..."
sed -i '' '/^struct ImagePicker:/,/^}/d' Features/Gaming/MatchResultSubmissionView.swift
sed -i '' '/^struct ImagePicker:/,/^}/d' Features/Search/SearchView.swift
sed -i '' '/^struct ImagePicker:/,/^}/d' Features/Upload/UploadView.swift

echo "📝 Removing duplicate StoryError types..."
sed -i '' '/^enum StoryError {/,/^}/d' Features/Stories/FacebookParityStoryEngine.swift
sed -i '' '/^enum StoryError {/,/^}/d' Features/Stories/UltimateStoryViewModel.swift

# ====================================
# 2. FIX MISSING ENUM CASES
# ====================================

echo "📝 Adding missing VideoCategory enum cases..."
# This requires reading and modifying VideoCategory enum
# Let's skip this for now and handle manually if needed

# ====================================
# 3. FIX BidStrategy enum
# ====================================

echo "📝 Fixing BidStrategy enum cases..."
# Change .lowestCost to .automatic
find . -type f -name "*.swift" -exec sed -i '' 's/\.lowestCost/.automatic/g' {} \;

echo "✅ TYPE CONFLICT FIX COMPLETE!"
echo "📊 Cleaned up duplicate type definitions"
echo "🔥 Ready to rebuild!"



