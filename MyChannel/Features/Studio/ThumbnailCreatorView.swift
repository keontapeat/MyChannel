//
//  ThumbnailCreatorView.swift
//  MyChannel
//
//  AI-Powered Viral Thumbnail Creation Suite
//  Created for MyChannel by AI Assistant
//

import SwiftUI
import PhotosUI

struct ThumbnailCreatorView: View {
    @StateObject private var viewModel = ThumbnailCreatorViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: ThumbnailTab = .generate
    @State private var showExportOptions = false
    @State private var showTemplateLibrary = false
    
    enum ThumbnailTab: String, CaseIterable, Identifiable {
        case generate = "AI Generate"
        case edit = "Edit"
        case templates = "Templates"
        case analyze = "Analyze"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .generate: return "wand.and.stars"
            case .edit: return "slider.horizontal.3"
            case .templates: return "square.grid.2x2"
            case .analyze: return "chart.line.uptrend.xyaxis"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab Selector
                    tabSelector
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            switch selectedTab {
                            case .generate:
                                aiGenerateSection
                            case .edit:
                                editSection
                            case .templates:
                                templatesSection
                            case .analyze:
                                analyzeSection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("Thumbnail Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.currentThumbnail != nil {
                        Button {
                            showExportOptions = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Export")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.primary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showExportOptions) {
            ExportThumbnailSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showTemplateLibrary) {
            ThumbnailTemplateLibraryView(viewModel: viewModel)
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ThumbnailTab.allCases) { tab in
                    TabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - AI Generate Section
    private var aiGenerateSection: some View {
        VStack(spacing: 24) {
            // Current Thumbnail Preview
            if let thumbnail = viewModel.currentThumbnail {
                thumbnailPreview(thumbnail)
            } else {
                emptyThumbnailState
            }
            
            // AI Generation Card
            aiGenerationCard
            
            // Quick Actions
            quickActionsGrid
            
            // Recent Generations
            if !viewModel.generatedThumbnails.isEmpty {
                recentGenerationsSection
            }
        }
    }
    
    private var emptyThumbnailState: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.Colors.surface)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.Colors.divider.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                    )
                
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("No thumbnail yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("Generate or upload to get started")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .shadow(color: .black.opacity(0.05), radius: 10)
        }
    }
    
    private func thumbnailPreview(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            // Viral Score
            if let score = viewModel.viralScore ?? viewModel.analysis?.score {
                viralScoreBadge(score)
            }
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            
            // Thumbnail Stats
            if viewModel.isAnalyzing {
                HStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    Text("Analyzing viral potential...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(12)
                .background(AppTheme.Colors.surface)
                .clipShape(Capsule())
            } else if let analysis = viewModel.analysis {
                thumbnailStatsRow(analysis)
            }
        }
    }
    
    private func viralScoreBadge(_ score: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: score >= 80 ? "flame.fill" : score >= 60 ? "sparkles" : "chart.bar.fill")
                .font(.system(size: 16, weight: .bold))
            
            Text("Viral Score: \(score)/100")
                .font(.system(size: 16, weight: .bold))
            
            Circle()
                .fill(scoreColor(score))
                .frame(width: 8, height: 8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    scoreColor(score),
                    scoreColor(score).opacity(0.8)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: scoreColor(score).opacity(0.4), radius: 12, x: 0, y: 6)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
    
    private func thumbnailStatsRow(_ analysis: ThumbnailAnalysis) -> some View {
        HStack(spacing: 12) {
            statChip(icon: "eye.fill", value: analysis.clickPotential, label: "CTR")
            statChip(icon: "face.smiling.fill", value: analysis.emotionalImpact, label: "Emotion")
            statChip(icon: "textformat.size", value: analysis.readability, label: "Readable")
        }
    }
    
    private func statChip(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(value)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(AppTheme.Colors.primary)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var aiGenerationCard: some View {
        VStack(spacing: 20) {
            aiGenerationHeader
            videoTitleInput
            styleSelector
            generateButton
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    private var aiGenerationHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("AI Generation")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Text("Powered by GPT-5 & Claude 4.5")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
    
    private var videoTitleInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Video Title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            TextField("Enter your video title...", text: $viewModel.videoTitle)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(14)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var styleSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Thumbnail Style")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ThumbnailStyle.allCases) { style in
                        StyleChip(
                            title: style.rawValue,
                            icon: style.icon,
                            isSelected: viewModel.selectedStyle == style
                        ) {
                            viewModel.selectedStyle = style
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                }
            }
        }
    }
    
    private var generateButton: some View {
        Button {
            Task {
                await viewModel.generateThumbnail()
            }
        } label: {
            HStack(spacing: 12) {
                if viewModel.isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                }
                
                Text(viewModel.isGenerating ? "Generating..." : "Generate Thumbnail")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .disabled(viewModel.videoTitle.isEmpty || viewModel.isGenerating)
        .opacity(viewModel.videoTitle.isEmpty ? 0.5 : 1.0)
    }
    
    private var quickActionsGrid: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionCard(
                    title: "Upload Photo",
                    icon: "photo.on.rectangle",
                    color: .blue
                ) {
                    viewModel.showImagePicker = true
                }
                
                QuickActionCard(
                    title: "Use Template",
                    icon: "square.grid.2x2",
                    color: .purple
                ) {
                    showTemplateLibrary = true
                }
                
                QuickActionCard(
                    title: "A/B Test",
                    icon: "chart.bar.doc.horizontal",
                    color: .orange
                ) {
                    viewModel.createABTest()
                }
                
                QuickActionCard(
                    title: "Analyze",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                ) {
                    Task {
                        await viewModel.analyzeThumbnail()
                    }
                }
            }
        }
    }
    
    private var recentGenerationsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Generations")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button("Clear") { viewModel.clearRecent() }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.generatedThumbnails) { thumbnail in
                        RecentThumbnailCard(thumbnail: thumbnail) {
                            viewModel.selectThumbnail(thumbnail)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Edit Section
    private var editSection: some View {
        VStack(spacing: 24) {
            if let thumbnail = viewModel.currentThumbnail {
                thumbnailPreview(thumbnail)
                
                // Edit Tools
                editToolsSection
            } else {
                emptyStateMessage(
                    icon: "slider.horizontal.3",
                    title: "No Thumbnail to Edit",
                    message: "Generate or upload a thumbnail first"
                )
            }
        }
    }
    
    private var editToolsSection: some View {
        VStack(spacing: 16) {
            Text("Edit Tools")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Brightness
            editSlider(
                title: "Brightness",
                icon: "sun.max.fill",
                value: $viewModel.brightness,
                range: -1...1
            )
            
            // Contrast
            editSlider(
                title: "Contrast",
                icon: "circle.lefthalf.filled",
                value: $viewModel.contrast,
                range: 0...2
            )
            
            // Saturation
            editSlider(
                title: "Saturation",
                icon: "paintpalette.fill",
                value: $viewModel.saturation,
                range: 0...2
            )
            
            // Filters
            filtersSection
            
            // Text Overlay
            textOverlaySection
        }
    }
    
    private func editSlider(title: String, icon: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Slider(value: value, in: range)
                .tint(AppTheme.Colors.primary)
                .onChange(of: value.wrappedValue) { _ in
                    viewModel.applyFilters()
                }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.filters) { filter in
                        FilterButton(
                            filter: filter,
                            isSelected: viewModel.selectedFilter?.id == filter.id,
                            action: { viewModel.applyFilter(filter) }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var textOverlaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Text Overlay")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $viewModel.showTextOverlay)
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
            }
            
            if viewModel.showTextOverlay {
                TextField("Enter text...", text: $viewModel.overlayText)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(14)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Font size
                HStack {
                    Text("Size")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Slider(value: $viewModel.textSize, in: 20...120)
                        .tint(AppTheme.Colors.primary)
                        .frame(maxWidth: 200)
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Templates Section
    private var templatesSection: some View {
        VStack(spacing: 24) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(ThumbnailTemplate.allTemplates) { template in
                    TemplateCard(template: template) {
                        viewModel.applyTemplate(template)
                    }
                }
            }
        }
    }
    
    // MARK: - Analyze Section
    private var analyzeSection: some View {
        VStack(spacing: 24) {
            if let thumbnail = viewModel.currentThumbnail {
                thumbnailPreview(thumbnail)
                
                if let analysis = viewModel.analysis {
                    detailedAnalysisSection(analysis)
                } else {
                    Button {
                        Task {
                            await viewModel.analyzeThumbnail()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 18, weight: .bold))
                            Text("Analyze Thumbnail")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            } else {
                emptyStateMessage(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No Thumbnail to Analyze",
                    message: "Generate or upload a thumbnail first"
                )
            }
        }
    }
    
    private func detailedAnalysisSection(_ analysis: ThumbnailAnalysis) -> some View {
        VStack(spacing: 20) {
            // Overall Score
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(analysis.score) / 100)
                        .stroke(scoreColor(analysis.score), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: analysis.score)
                    
                    VStack(spacing: 4) {
                        Text("\(analysis.score)")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("Viral Score")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Text(analysis.verdict)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(scoreColor(analysis.score))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Detailed Metrics
            VStack(spacing: 16) {
                Text("Detailed Analysis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                analysisMetric(title: "Click-Through Rate", value: analysis.clickPrediction, suffix: "%", icon: "hand.tap.fill")
                analysisMetric(title: "Text Readability", value: analysis.textReadability, suffix: "%", icon: "textformat.size")
                analysisMetric(title: "Face Detection", value: analysis.faceScore, suffix: "", icon: "face.smiling.fill")
                analysisMetric(title: "Color Harmony", value: analysis.colorScore, suffix: "", icon: "paintpalette.fill")
            }
            
            // AI Suggestions
            aiSuggestionsSection(analysis.suggestions)
        }
    }
    
    private func analysisMetric(title: String, value: Int, suffix: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 30)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            Text("\(value)\(suffix)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.primary)
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func aiSuggestionsSection(_ suggestions: [String]) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)
                
                Text("AI Suggestions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                        
                        Text(suggestion)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Helper Views
    private func emptyStateMessage(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60, weight: .light))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Supporting Views

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.Colors.primary : Color.clear)
            .clipShape(Capsule())
        }
    }
}

struct StyleChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct RecentThumbnailCard: View {
    let thumbnail: GeneratedThumbnail
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                AsyncImage(url: URL(string: thumbnail.imageURL)) { image in
                    image.resizable()
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.cardBackground)
                }
                .aspectRatio(16/9, contentMode: .fill)
                .frame(width: 140, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

struct FilterButton: View {
    let filter: ThumbnailFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Preview circle
                Circle()
                    .fill(AppTheme.Colors.cardBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
                    )
                
                Text(filter.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
            }
        }
    }
}

struct TemplateCard: View {
    let template: ThumbnailTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                AsyncImage(url: URL(string: template.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.cardBackground)
                        .aspectRatio(16/9, contentMode: .fit)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(12)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Export Sheet
struct ExportThumbnailSheet: View {
    @ObservedObject var viewModel: ThumbnailCreatorViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Export your thumbnail")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.top, 24)
                
                VStack(spacing: 16) {
                    exportOption(title: "Save to Photos", icon: "photo.on.rectangle", action: viewModel.saveToPhotos)
                    exportOption(title: "Share", icon: "square.and.arrow.up", action: viewModel.shareThumbnail)
                    exportOption(title: "Use for Video", icon: "video.fill", action: viewModel.useForVideo)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func exportOption(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 32)
                
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(18)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Template Library
struct ThumbnailTemplateLibraryView: View {
    @ObservedObject var viewModel: ThumbnailCreatorViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(ThumbnailTemplate.allTemplates) { template in
                        TemplateCard(template: template) {
                            viewModel.applyTemplate(template)
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ThumbnailCreatorView()
}

