//
//  AICoCreatorView.swift
//  MyChannel
//
//  Revolutionary AI-powered video creation interface
//  The future of content creation - beyond anything YouTube offers
//

import SwiftUI

struct AICoCreatorView: View {
    @StateObject private var aiService = AIVideoCoCreatorService.shared
    @State private var selectedTopic = ""
    @State private var selectedStyle: CreatorStyle = .educational
    @State private var selectedAudience: AICoCreatorAudienceType = .youngAdults
    @State private var targetDuration: Double = 300 // 5 minutes
    @State private var showingScriptEditor = false
    @State private var showingThumbnailGenerator = false
    @State private var showingContentGaps = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Script Generator
                    scriptGeneratorSection
                    
                    // Content Gap Analysis
                    contentGapSection
                    
                    // Trending Topics
                    trendingTopicsSection
                    
                    // AI Insights
                    aiInsightsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("AI Co-Creator")
            .navigationBarTitleDisplayMode(.large)
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.8),
                        AppTheme.Colors.primary.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .sheet(isPresented: $showingScriptEditor) {
            ScriptEditorView(script: aiService.generatedScript)
        }
        .sheet(isPresented: $showingThumbnailGenerator) {
            ThumbnailGeneratorView()
        }
        .sheet(isPresented: $showingContentGaps) {
            ContentGapAnalysisView()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Video Co-Creator")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Create viral content with AI assistance")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // AI Status Indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(aiService.isGenerating ? .orange : .green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(aiService.isGenerating ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: aiService.isGenerating)
                    
                    Text(aiService.isGenerating ? "AI Working..." : "AI Ready")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(aiService.isGenerating ? .orange : .green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            
            // Stats Row
            HStack(spacing: 20) {
                statItem(title: "Scripts Generated", value: "1,247", color: .blue)
                statItem(title: "Viral Predictions", value: "95%", color: .green)
                statItem(title: "Time Saved", value: "2,340h", color: .purple)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                quickActionCard(
                    icon: "cpu",
                    title: "Generate Script",
                    subtitle: "AI writes your video script",
                    color: .purple,
                    action: { showingScriptEditor = true }
                )
                
                quickActionCard(
                    icon: "photo.on.rectangle.angled",
                    title: "Create Thumbnails",
                    subtitle: "AI designs viral thumbnails",
                    color: .orange,
                    action: { showingThumbnailGenerator = true }
                )
                
                quickActionCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Find Content Gaps",
                    subtitle: "Discover untapped opportunities",
                    color: .green,
                    action: { showingContentGaps = true }
                )
                
                quickActionCard(
                    icon: "brain.head.profile",
                    title: "Viral Predictor",
                    subtitle: "Predict video success rate",
                    color: .blue,
                    action: { /* TODO: Implement */ }
                )
            }
        }
    }
    
    private func quickActionCard(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(16)
            .frame(height: 120)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Script Generator Section
    
    private var scriptGeneratorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Script Generator")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 16) {
                // Topic Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Video Topic")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextField("Enter your video topic...", text: $selectedTopic)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 16))
                }
                
                // Style & Audience Selection
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Style")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Picker("Style", selection: $selectedStyle) {
                            ForEach(CreatorStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audience")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Picker("Audience", selection: $selectedAudience) {
                            ForEach(AICoCreatorAudienceType.allCases, id: \.self) { audience in
                                Text(audience.displayName).tag(audience)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Duration Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Target Duration")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text("\(Int(targetDuration / 60)):\(String(format: "%02d", Int(targetDuration.truncatingRemainder(dividingBy: 60))))")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    Slider(value: $targetDuration, in: 60...3600, step: 30)
                        .accentColor(AppTheme.Colors.primary)
                }
                
                // Generate Button
                Button(action: generateScript) {
                    HStack(spacing: 8) {
                        if aiService.isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "cpu")
                        }
                        
                        Text(aiService.isGenerating ? "Generating..." : "Generate Script")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .disabled(selectedTopic.isEmpty || aiService.isGenerating)
                .opacity(selectedTopic.isEmpty ? 0.6 : 1.0)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Content Gap Section
    
    private var contentGapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Content Opportunities")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button("View All") {
                    showingContentGaps = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
            }
            
            if AIVideoCoCreatorService.shared.contentGaps.isEmpty {
                ContentGapPlaceholder()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(aiService.contentGaps.prefix(3)) { gap in
                        AICoCreatorContentGapCard(gap: gap)
                    }
                }
            }
        }
    }
    
    // MARK: - Trending Topics Section
    
    private var trendingTopicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trending Topics")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(aiService.trendingTopics) { topic in
                        AICoCreatorTrendingTopicCard(topic: topic) {
                            selectedTopic = topic.topic
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
    
    // MARK: - AI Insights Section
    
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 12) {
                insightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Optimal Upload Time",
                    value: "2:00 PM EST",
                    subtitle: "Based on your audience activity",
                    color: .blue
                )
                
                insightCard(
                    icon: "target",
                    title: "Viral Potential Score",
                    value: "87%",
                    subtitle: "Your next video has high viral potential",
                    color: .green
                )
                
                insightCard(
                    icon: "dollarsign.circle",
                    title: "Revenue Forecast",
                    value: "$2,450",
                    subtitle: "Projected earnings this month",
                    color: .orange
                )
            }
        }
    }
    
    private func insightCard(icon: String, title: String, value: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Actions
    
    private func generateScript() {
        guard !selectedTopic.isEmpty else { return }
        
        Task {
            do {
                let script = try await aiService.generateScript(
                    topic: selectedTopic,
                    style: selectedStyle,
                    duration: targetDuration,
                    audience: selectedAudience
                )
                
                await MainActor.run {
                    showingScriptEditor = true
                }
            } catch {
                print("Failed to generate script: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct ContentGapPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb.circle")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("Analyzing content opportunities...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("AI is scanning trending topics and competitor content")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AICoCreatorContentGapCard: View {
    let gap: AIContentGap
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(gap.topic)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(gap.opportunity)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(gap.potentialViews.formatted()) views", systemImage: "eye")
                    Label(gap.difficulty.rawValue.capitalized, systemImage: "gauge")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("\(Int(gap.trendScore * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                Text("Trend Score")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AICoCreatorAICoCreatorTrendingTopicCard: View {
    let topic: AICoCreatorTrendingTopic
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(topic.topic)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("+\(Int(topic.growthRate * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                
                Text("\(topic.searchVolume.formatted()) searches")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(12)
            .frame(width: 140, height: 100, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet Views (Placeholders)

struct ScriptEditorView: View {
    let script: VideoScript?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if let script = script {
                    Text(script.title)
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Full script editor with sections
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(script.sections.enumerated()), id: \.offset) { idx, section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Section \(idx + 1)", systemImage: "film")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Text(section.content)
                                        .font(.body)
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("No script generated yet")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("Script Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ThumbnailGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("AI Thumbnail Generator")
                    .font(.title2)
                    .padding()
                
                Text("Thumbnail generator coming soon...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Thumbnail Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ContentGapAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Content Gap Analysis")
                    .font(.title2)
                    .padding()
                
                Text("Full analysis view coming soon...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Content Gaps")
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

struct AICoCreatorTrendingTopicCard: View {
    let topic: AICoCreatorTrendingTopic
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(topic.topic)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                }
                
                Text("Trending in \(topic.category.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(topic.searchVolume.formatted()) searches")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("+\(topic.growthRate, specifier: "%.0f")%")
                        .font(.caption2)
                        .foregroundColor(.green)
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

#Preview {
    AICoCreatorView()
}
