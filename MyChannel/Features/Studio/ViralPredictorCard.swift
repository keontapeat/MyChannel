//
//  ViralPredictorCard.swift
//  MyChannel
//
//  🔮 AI-POWERED VIRAL PREDICTION CARD
//  Shows viral potential score (0-100) for videos
//

import SwiftUI

struct ViralPredictorCard: View {
    let videoTitle: String
    let videoCategory: String
    let creatorStats: CreatorStats?
    
    @State private var viralScore: Int = 0
    @State private var confidence: Double = 0.0
    @State private var factors: [String] = []
    @State private var tips: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Viral Prediction")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if viralScore > 0 {
                // Viral Score Circle
                HStack(spacing: 24) {
                    // Circular progress
                    ZStack {
                        Circle()
                            .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 12)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: Double(viralScore) / 100.0)
                            .stroke(
                                LinearGradient(
                                    colors: gradientColors(for: viralScore),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viralScore)
                        
                        VStack(spacing: 4) {
                            Text("\(viralScore)")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(color(for: viralScore))
                            
                            Text("Score")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Prediction label
                        HStack {
                            Circle()
                                .fill(color(for: viralScore))
                                .frame(width: 8, height: 8)
                            
                            Text(predictionLabel(for: viralScore))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(color(for: viralScore))
                        }
                        
                        // Confidence
                        HStack {
                            Text("Confidence:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("\(Int(confidence * 100))%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Success Factors
                if !factors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Success Factors")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        ForEach(factors, id: \.self) { factor in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                
                                Text(factor)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Optimization Tips
                if !tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Optimization Tips")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        ForEach(tips, id: \.self) { tip in
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                
                                Text(tip)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("Get AI viral prediction")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Button(action: {
                        predictViralScore()
                    }) {
                        Text("Analyze Now")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
        .task {
            // Auto-predict on appear
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            predictViralScore()
        }
    }
    
    // MARK: - Predict Viral Score
    
    private func predictViralScore() {
        guard !isLoading else { return }
        
        isLoading = true
        
        Task {
            do {
                let prediction = try await VertexAIAgentService.shared.predictViralScore(
                    videoTitle: videoTitle,
                    category: videoCategory
                )
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        self.viralScore = prediction.viralScore
                        self.confidence = prediction.confidence
                        self.factors = prediction.factors
                        self.tips = prediction.optimizationTips
                    }
                    isLoading = false
                }
            } catch {
                print("🚨 [ViralPredictor] Error: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func color(for score: Int) -> Color {
        switch score {
        case 0..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        case 70..<85: return .green
        default: return Color(red: 0.2, green: 0.8, blue: 0.3) // Bright green
        }
    }
    
    private func gradientColors(for score: Int) -> [Color] {
        switch score {
        case 0..<30: return [.red, .orange]
        case 30..<50: return [.orange, .yellow]
        case 50..<70: return [.yellow, .green]
        case 70..<85: return [.green, Color(red: 0.2, green: 0.8, blue: 0.3)]
        default: return [Color(red: 0.2, green: 0.8, blue: 0.3), Color(red: 0.3, green: 0.9, blue: 0.4)]
        }
    }
    
    private func predictionLabel(for score: Int) -> String {
        switch score {
        case 0..<30: return "Low Potential"
        case 30..<50: return "Moderate Potential"
        case 50..<70: return "Good Potential"
        case 70..<85: return "High Potential"
        default: return "🔥 VIRAL POTENTIAL!"
        }
    }
}

#Preview("High Score") {
    ViralPredictorCard(
        videoTitle: "How I Built a $1M Business in 6 Months",
        videoCategory: "education",
        creatorStats: CreatorStats(avgViews: 50000, avgWatchTime: 65.0, bestPostingTime: "7 PM")
    )
    .padding()
    .background(AppTheme.Colors.background)
}

