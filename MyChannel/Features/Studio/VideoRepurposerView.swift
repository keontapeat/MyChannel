//
//  VideoRepurposerView.swift
//  MyChannel
//
//  AI VIDEO REPURPOSER - Auto-create viral Flicks from long videos
//  Save creators SO MUCH time!
//  Created for MyChannel by AI Assistant
//

import SwiftUI
import AVFoundation

struct VideoRepurposerView: View {
    @StateObject private var viewModel = VideoRepurposerViewModel()
    @State private var selectedVideo: Video?
    @State private var showVideoSelector = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        repurposerHero
                        
                        // Stats
                        statsSection
                        
                        // Select Video
                        selectVideoSection
                        
                        // Generated Flicks
                        generatedFlicksSection
                        
                        // Templates
                        templatesSection
                        
                        // How It Works
                        howItWorksSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("AI Video Repurposer")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showVideoSelector) {
            VideoSelectorSheet(viewModel: viewModel, selectedVideo: $selectedVideo)
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - Hero Section
    private var repurposerHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.5, green: 0.2, blue: 0.9),
                            Color(red: 0.2, green: 0.4, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 32, weight: .bold))
                    Text("AI Repurposer")
                        .font(.system(size: 28, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Turn 1 long video into 10+ viral Flicks")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "brain.head.profile", text: "AI Powered")
                    featureBadge(icon: "bolt.fill", text: "Instant")
                    featureBadge(icon: "scissors", text: "Auto-Edit")
                }
                
                Text("💡 Save 10+ hours of editing per video")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
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
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 12) {
            RepurposerStatCard(
                icon: "video.fill",
                value: "\(viewModel.videosRepurposed)",
                label: "Videos",
                color: .blue
            )
            
            RepurposerStatCard(
                icon: "film.fill",
                value: "\(viewModel.flicksGenerated)",
                label: "Flicks",
                color: .purple
            )
            
            RepurposerStatCard(
                icon: "clock.fill",
                value: "\(viewModel.hoursSaved)h",
                label: "Saved",
                color: .green
            )
        }
    }
    
    // MARK: - Select Video Section
    private var selectVideoSection: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Select a Video to Repurpose")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            Button {
                showVideoSelector = true
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Choose Video")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("AI will find the best moments automatically")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [10]))
                )
            }
        }
    }
    
    // MARK: - Generated Flicks
    private var generatedFlicksSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Generated Flicks")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if !viewModel.generatedFlicks.isEmpty {
                    Button {
                        // Publish all
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Publish All")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            
            if viewModel.generatedFlicks.isEmpty {
                EmptyFlicksView()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(viewModel.generatedFlicks) { flick in
                        GeneratedFlickCard(flick: flick)
                    }
                }
            }
        }
    }
    
    // MARK: - Templates Section
    private var templatesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Repurpose Templates")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(RepurposeTemplate.allTemplates) { template in
                        TemplateCard(template: template) {
                            // Use template
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - How It Works
    private var howItWorksSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("How It Works")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 14) {
                HowItWorksStep(
                    number: "1",
                    title: "AI Analyzes Video",
                    description: "Scans your entire video for engaging moments, key topics, and viral potential"
                )
                
                HowItWorksStep(
                    number: "2",
                    title: "Extracts Highlights",
                    description: "Automatically finds and extracts the best 15-60 second clips"
                )
                
                HowItWorksStep(
                    number: "3",
                    title: "Smart Editing",
                    description: "Adds captions, music, transitions, and optimizes for mobile viewing"
                )
                
                HowItWorksStep(
                    number: "4",
                    title: "Ready to Publish",
                    description: "Review, edit, and publish your Flicks with one tap"
                )
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct RepurposerStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct GeneratedFlickCard: View {
    let flick: GeneratedFlick
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: flick.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(9/16, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.cardBackground)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Duration
                Text(formatDuration(flick.duration))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(flick.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("\(flick.viralScore)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.purple)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 11))
                        Text(flick.predictedViews)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            HStack(spacing: 8) {
                Button {
                    // Edit
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Button {
                    // Publish
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(10)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct EmptyFlicksView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No generated Flicks yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Select a video and let AI create viral Flicks for you")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct TemplateCard: View {
    let template: RepurposeTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(template.color.opacity(0.2))
                        .frame(height: 100)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(template.color)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(template.description)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(width: 160)
            .padding(14)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(template.color.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

struct HowItWorksStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Text(number)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Video Selector Sheet
struct VideoSelectorSheet: View {
    @ObservedObject var viewModel: VideoRepurposerViewModel
    @Binding var selectedVideo: Video?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.availableVideos) { video in
                        Button {
                            selectedVideo = video
                            Task {
                                await viewModel.repurposeVideo(video)
                            }
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(AppTheme.Colors.cardBackground)
                                }
                                .frame(width: 120, height: 68)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(video.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .lineLimit(2)
                                    
                                    HStack(spacing: 12) {
                                        Text(formatDuration(video.duration))
                                            .font(.system(size: 13))
                                        
                                        Text("\(video.viewCount) views")
                                            .font(.system(size: 13))
                                    }
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            .padding(12)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Select Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    VideoRepurposerView()
}

