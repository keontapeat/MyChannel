//
//  AIContentFactoryView.swift
//  MyChannel
//
//  🔥 THE ULTIMATE AI CONTENT FACTORY
//  Automatically generates viral videos 24/7
//  This is the future - content creation without limits!
//

import SwiftUI

struct AIContentFactoryView: View {
    @StateObject private var aiEngine = AIContentGenerationEngine.shared
    @State private var selectedTopic = ""
    @State private var selectedStyle: VideoStyle = .educational
    @State private var targetDuration: Double = 300
    @State private var isAutonomousMode = false
    @State private var showingGeneratedVideo = false
    @State private var selectedGeneratedVideo: AIGeneratedVideo?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with stats
                    headerSection
                    
                    // Autonomous Generation Toggle
                    autonomousSection
                    
                    // Manual Generation
                    manualGenerationSection
                    
                    // Trending Topics
                    trendingTopicsSection
                    
                    // Generated Videos
                    generatedVideosSection
                    
                    // Viral Predictions
                    viralPredictionsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("AI Content Factory")
            .navigationBarTitleDisplayMode(.large)
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        AppTheme.Colors.primary.opacity(0.05),
                        AppTheme.Colors.secondary.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .sheet(isPresented: $showingGeneratedVideo) {
            if let video = selectedGeneratedVideo {
                GeneratedVideoDetailView(video: video)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("🤖 AI Content Factory")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if aiEngine.isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    Text("Autonomous video generation powered by AI")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Generation Status
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isAutonomousMode ? .green : .orange)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isAutonomousMode ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAutonomousMode)
                        
                        Text(isAutonomousMode ? "AUTONOMOUS" : "MANUAL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isAutonomousMode ? .green : .orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    
                    Text("\(aiEngine.generationStats.totalGenerated) videos")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            // Stats Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                StatCard(
                    title: "Generated",
                    value: "\(aiEngine.generationStats.totalGenerated)",
                    change: "+0",
                    isPositive: true,
                    icon: "video.fill",
                    color: AppTheme.Colors.primary
                )
                
                StatCard(
                    title: "Avg Viral Score",
                    value: "\(Int(aiEngine.generationStats.averageViralScore * 100))%",
                    change: "+0%",
                    isPositive: true,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
                
                StatCard(
                    title: "Success Rate",
                    value: "\(Int(aiEngine.generationStats.successRate * 100))%",
                    change: "+0%",
                    isPositive: true,
                    icon: "clock.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Trending",
                    value: "\(aiEngine.trendingTopics.count)",
                    change: "+0",
                    isPositive: true,
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Autonomous Section
    
    private var autonomousSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("Autonomous Generation")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
            }
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("24/7 Content Factory")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("AI automatically creates viral videos from trending topics")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isAutonomousMode)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                if isAutonomousMode {
                    VStack(spacing: 12) {
                        HStack {
                            Text("🚀 Autonomous mode active")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                            Spacer()
                            Text("2 videos/hour")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        ProgressView(value: 0.7)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        
                        HStack {
                            Text("Next generation in 23 minutes")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Manual Generation Section
    
    private var manualGenerationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                Text("Manual Generation")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Topic Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Topic")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextField("Enter topic or select from trending...", text: $selectedTopic)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 16))
                }
                
                // Style & Duration
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Style")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Picker("Style", selection: $selectedStyle) {
                            ForEach(VideoStyle.allCases, id: \.self) { style in
                                Text(style.rawValue.capitalized).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Duration")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Spacer()
                            
                            Text("\(Int(targetDuration / 60)):\(String(format: "%02d", Int(targetDuration.truncatingRemainder(dividingBy: 60))))")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Slider(value: $targetDuration, in: 60...1800, step: 30)
                            .accentColor(AppTheme.Colors.primary)
                    }
                }
                
                // Generate Button
                Button(action: generateVideo) {
                    HStack(spacing: 8) {
                        if aiEngine.isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "star.fill")
                        }
                        
                        Text(aiEngine.isGenerating ? "Generating..." : "Generate Video")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .disabled(selectedTopic.isEmpty || aiEngine.isGenerating)
                .opacity(selectedTopic.isEmpty ? 0.6 : 1.0)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Trending Topics Section
    
    private var trendingTopicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Trending Topics")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button("Refresh") {
                    Task {
                        await aiEngine.updateTrendingTopics()
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(aiEngine.trendingTopics) { topic in
                        AIGenerationTrendingTopicCard(topic: topic, action: {
                            selectedTopic = topic.topic
                        })
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
    
    // MARK: - Generated Videos Section
    
    private var generatedVideosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "video.badge.checkmark")
                    .foregroundColor(.green)
                Text("Generated Videos")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Text("\(aiEngine.generatedVideos.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            if aiEngine.generatedVideos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("No videos generated yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("Start generating content to see your AI-created videos here")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(aiEngine.generatedVideos.prefix(6)) { video in
                        GeneratedVideoCard(video: video) {
                            selectedGeneratedVideo = video
                            showingGeneratedVideo = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Viral Predictions Section
    
    private var viralPredictionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "crystal.ball")
                    .foregroundColor(.purple)
                Text("Viral Predictions")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button("Predict") {
                    Task {
                        _ = try? await aiEngine.predictViralTopics()
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(spacing: 12) {
                PredictionCard(
                    topic: "AI Productivity Revolution",
                    probability: 0.92,
                    expectedViews: "2.5M",
                    timeToViral: "6 hours"
                )
                
                PredictionCard(
                    topic: "Future of Remote Work",
                    probability: 0.87,
                    expectedViews: "1.8M",
                    timeToViral: "12 hours"
                )
                
                PredictionCard(
                    topic: "Sustainable Tech Trends",
                    probability: 0.79,
                    expectedViews: "1.2M",
                    timeToViral: "18 hours"
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateVideo() {
        guard !selectedTopic.isEmpty else { return }
        
        Task {
            do {
                let video = try await aiEngine.generateVideoFromTrend(
                    topic: selectedTopic,
                    style: selectedStyle,
                    duration: targetDuration
                )
                
                await MainActor.run {
                    selectedGeneratedVideo = video
                    showingGeneratedVideo = true
                }
            } catch {
                print("Failed to generate video: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views


struct AIGenerationAIGenerationTrendingTopicCard: View {
    let topic: AIGenerationTrendingTopic
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(topic.topic)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    
                    Text("\(Int(topic.viralPotential * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text(topic.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.textSecondary.opacity(0.1), in: Capsule())
                }
            }
            .padding(12)
            .frame(width: 160, height: 80, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct GeneratedVideoCard: View {
    let video: AIGeneratedVideo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "video.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            
                            Text("\(Int(video.viralScore * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        Text(video.generatedAt.timeAgoDisplay)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct PredictionCard: View {
    let topic: String
    let probability: Double
    let expectedViews: String
    let timeToViral: String
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 12) {
                    Label(expectedViews, systemImage: "eye")
                    Label(timeToViral, systemImage: "clock")
                }
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(probability * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                
                Text("Viral Chance")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct GeneratedVideoDetailView: View {
    let video: AIGeneratedVideo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Video Preview
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .aspectRatio(16/9, contentMode: .fill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(video.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(video.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label("Viral Score: \(Int(video.viralScore * 100))%", systemImage: "star.fill")
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            Label(video.generatedAt.timeAgoDisplay, systemImage: "clock")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Generated Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct AIGenerationTrendingTopicCard: View {
    let topic: AIGenerationTrendingTopic
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(topic.topic)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                }
                
                Text("\(topic.trendingScore, specifier: "%.1f")% trending")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    ForEach(topic.keywords.prefix(3), id: \.self) { keyword in
                        Text(keyword)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - AI Factory Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
                Text(change)
                    .font(.caption)
                    .foregroundColor(isPositive ? .green : .red)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    AIContentFactoryView()
}
