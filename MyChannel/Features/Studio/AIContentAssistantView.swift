//
//  AIContentAssistantView.swift
//  MyChannel
//
//  AI Content Assistant - Help creators go VIRAL
//  Viral score predictions, title optimization, thumbnail analysis
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct AIContentAssistantView: View {
    @StateObject private var viewModel = AIContentAssistantViewModel()
    @State private var videoTitle = ""
    @State private var videoDescription = ""
    @State private var selectedThumbnail: UIImage?
    @State private var showImagePicker = false
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        assistantHero
                        
                        // Viral Score
                        if let analysis = viewModel.currentAnalysis {
                            viralScoreCard(analysis: analysis)
                        }
                        
                        // Input Section
                        inputSection
                        
                        // Suggestions
                        if let analysis = viewModel.currentAnalysis {
                            suggestionsSection(analysis: analysis)
                        }
                        
                        // Trending Topics
                        trendingTopicsSection
                        
                        // Best Upload Times
                        bestUploadTimesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("AI Content Assistant")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            Task {
                await viewModel.loadTrendingTopics()
            }
        }
    }
    
    // MARK: - Hero Section
    private var assistantHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.9, green: 0.2, blue: 0.5),
                            Color(red: 0.5, green: 0.2, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 30, weight: .bold))
                    Text("AI Assistant")
                        .font(.system(size: 26, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Let AI help you create viral content")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "chart.line.uptrend.xyaxis", text: "Viral Score")
                    featureBadge(icon: "lightbulb.fill", text: "Smart Tips")
                    featureBadge(icon: "sparkles", text: "AI Powered")
                }
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Viral Score Card
    private func viralScoreCard(analysis: ContentAnalysis) -> some View {
        VStack(spacing: 20) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(AppTheme.Colors.cardBackground, lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: CGFloat(analysis.viralScore) / 100.0)
                    .stroke(
                        LinearGradient(
                            colors: scoreGradient(score: analysis.viralScore),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(analysis.viralScore)")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Viral Score")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            // Score Label
            Text(scoreLabel(score: analysis.viralScore))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(scoreColor(score: analysis.viralScore))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(scoreColor(score: analysis.viralScore).opacity(0.15))
                .clipShape(Capsule())
            
            // Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricItem(icon: "eye.fill", label: "Est. Views", value: analysis.estimatedViews, color: .blue)
                MetricItem(icon: "hand.thumbsup.fill", label: "Engagement", value: "\(analysis.engagementRate)%", color: .green)
                MetricItem(icon: "clock.fill", label: "Watch Time", value: analysis.watchTime, color: .orange)
                MetricItem(icon: "square.and.arrow.up.fill", label: "Share Rate", value: "\(analysis.shareRate)%", color: .purple)
            }
        }
        .padding(24)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private func scoreGradient(score: Int) -> [Color] {
        if score >= 80 {
            return [.green, Color(red: 0.2, green: 0.8, blue: 0.4)]
        } else if score >= 60 {
            return [.yellow, .orange]
        } else {
            return [.red, .orange]
        }
    }
    
    private func scoreColor(score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .orange }
        else { return .red }
    }
    
    private func scoreLabel(score: Int) -> String {
        if score >= 90 { return "🔥 EXTREMELY VIRAL" }
        else if score >= 80 { return "🚀 VERY VIRAL" }
        else if score >= 70 { return "✨ VIRAL POTENTIAL" }
        else if score >= 60 { return "📈 GOOD POTENTIAL" }
        else if score >= 50 { return "👌 DECENT CHANCE" }
        else { return "⚠️ NEEDS IMPROVEMENT" }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Analyze Your Content")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Video Title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                TextField("Enter your video title...", text: $videoTitle)
                    .font(.system(size: 16))
                    .padding(14)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Description")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                TextEditor(text: $videoDescription)
                    .font(.system(size: 16))
                    .frame(height: 120)
                    .padding(14)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .scrollContentBackground(.hidden)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Thumbnail")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Button {
                    showImagePicker = true
                } label: {
                    if let thumbnail = selectedThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("Upload Thumbnail")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.Colors.divider, style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )
                    }
                }
            }
            
            Button {
                Task {
                    isAnalyzing = true
                    await viewModel.analyzeContent(title: videoTitle, description: videoDescription, thumbnail: selectedThumbnail)
                    isAnalyzing = false
                }
            } label: {
                HStack(spacing: 10) {
                    if isAnalyzing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Analyzing...")
                    } else {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16, weight: .bold))
                        Text("Analyze with AI")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
            }
            .disabled(videoTitle.isEmpty || isAnalyzing)
            .opacity(videoTitle.isEmpty ? 0.5 : 1.0)
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Suggestions Section
    private func suggestionsSection(analysis: ContentAnalysis) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text("AI Suggestions")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ForEach(analysis.suggestions, id: \.self) { suggestion in
                SuggestionRow(suggestion: suggestion)
            }
            
            if !analysis.alternativeTitles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Alternative Titles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    ForEach(analysis.alternativeTitles, id: \.self) { title in
                        AlternativeTitleRow(title: title) {
                            videoTitle = title
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Trending Topics
    private var trendingTopicsSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("Trending Topics")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.trendingTopics, id: \.self) { topic in
                        TrendingTopicCard(topic: topic)
                    }
                }
            }
        }
    }
    
    // MARK: - Best Upload Times
    private var bestUploadTimesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Best Upload Times")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 10) {
                ForEach(viewModel.bestUploadTimes, id: \.day) { timeSlot in
                    UploadTimeRow(timeSlot: timeSlot)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct MetricItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SuggestionRow: View {
    let suggestion: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.yellow)
            
            Text(suggestion)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AlternativeTitleRow: View {
    let title: String
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.up.left.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(12)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct TrendingTopicCard: View {
    let topic: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.orange)
            
            Text(topic)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
        }
        .frame(width: 140, height: 100)
        .padding(14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
    }
}

struct UploadTimeRow: View {
    let timeSlot: UploadTimeSlot
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeSlot.day)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(timeSlot.time)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                Text("\(timeSlot.engagementBoost)% boost")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.green)
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    AIContentAssistantView()
}

