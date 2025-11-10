//
//  VoiceCloneDubbingView.swift
//  MyChannel
//
//  AI Voice Clone Dubbing - Translate videos to 100+ languages
//  Keep your voice, speak any language
//  Created for MyChannel by AI Assistant
//

import SwiftUI
import AVFoundation

struct VoiceCloneDubbingView: View {
    @StateObject private var viewModel = VoiceCloneDubbingViewModel()
    @State private var selectedVideo: Video?
    @State private var selectedLanguages: Set<String> = []
    @State private var showLanguagePicker = false
    @State private var processingProgress: Double = 0.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        dubbingHero
                        
                        // Stats
                        statsSection
                        
                        // Language Selection
                        languageSelectionSection
                        
                        // Dubbed Videos
                        dubbedVideosSection
                        
                        // Voice Training
                        voiceTrainingSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Voice Clone Dubbing")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLanguagePicker) {
                DubbingLanguagePickerSheet(selectedLanguages: $selectedLanguages, availableLanguages: viewModel.availableLanguages)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadDubbingData()
            }
        }
    }
    
    // MARK: - Hero Section
    private var dubbingHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.4, blue: 0.9),
                            Color(red: 0.4, green: 0.2, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                    Text("Voice Clone")
                        .font(.system(size: 28, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Speak 100+ languages in YOUR voice")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "brain.head.profile", text: "AI Powered")
                    featureBadge(icon: "globe", text: "100+ Languages")
                    featureBadge(icon: "bolt.fill", text: "Instant")
                }
                
                Button {
                    // Start dubbing
                    showLanguagePicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Start Dubbing")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 12) {
            DubbingStatBox(
                icon: "video.fill",
                value: "\(viewModel.totalDubbedVideos)",
                label: "Videos Dubbed",
                color: .blue
            )
            
            DubbingStatBox(
                icon: "globe",
                value: "\(viewModel.activeLanguages)",
                label: "Languages",
                color: .green
            )
            
            DubbingStatBox(
                icon: "eye.fill",
                value: viewModel.internationalViews,
                label: "Global Views",
                color: .purple
            )
        }
    }
    
    // MARK: - Language Selection
    private var languageSelectionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Target Languages")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    showLanguagePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Language")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if selectedLanguages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "globe.americas")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("Select languages to reach global audiences")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                DubbingFlowLayout(spacing: 10) {
                    ForEach(Array(selectedLanguages), id: \.self) { language in
                        LanguageChip(language: language) {
                            selectedLanguages.remove(language)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Dubbed Videos
    private var dubbedVideosSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Dubbed Videos")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: Text("All Dubbed Videos")) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if viewModel.dubbedVideos.isEmpty {
                EmptyStateView(
                    icon: "waveform.circle",
                    title: "No dubbed videos yet",
                    message: "Start dubbing your videos to reach a global audience"
                )
            } else {
                ForEach(viewModel.dubbedVideos) { dubbedVideo in
                    DubbedVideoCard(video: dubbedVideo)
                }
            }
        }
    }
    
    // MARK: - Voice Training
    private var voiceTrainingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Voice Clone Training")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.15))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Voice Quality: \(viewModel.voiceQuality)%")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Record more videos to improve accuracy")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.cardBackground)
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (Double(viewModel.voiceQuality) / 100.0), height: 12)
                    }
                }
                .frame(height: 12)
                
                Text("💡 Tip: Upload at least 10 minutes of your voice for best results")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Supporting Views

struct DubbingStatBox: View {
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
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct LanguageChip: View {
    let language: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(language)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.primary.opacity(0.15))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DubbedVideoCard: View {
    let video: DubbedVideo
    
    var body: some View {
        VStack(spacing: 14) {
            // Thumbnail with language badges
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.cardBackground)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                // Language badges
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(video.languages.prefix(3), id: \.self) { language in
                        Text(language)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.7))
                            .clipShape(Capsule())
                    }
                    
                    if video.languages.count > 3 {
                        Text("+\(video.languages.count - 3) more")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.7))
                            .clipShape(Capsule())
                    }
                }
                .padding(12)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12))
                        Text(video.totalViews.abbreviated)
                            .font(.system(size: 13, weight: .medium))
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                        Text("\(video.languages.count) languages")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(message)
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

// MARK: - Language Picker Sheet
struct DubbingLanguagePickerSheet: View {
    @Binding var selectedLanguages: Set<String>
    let availableLanguages: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredLanguages: [String] {
        if searchText.isEmpty {
            return availableLanguages
        }
        return availableLanguages.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextField("Search languages", text: $searchText)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Languages List
                List {
                    ForEach(filteredLanguages, id: \.self) { language in
                        Button {
                            if selectedLanguages.contains(language) {
                                selectedLanguages.remove(language)
                            } else {
                                selectedLanguages.insert(language)
                            }
                        } label: {
                            HStack {
                                Text(language)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Spacer()
                                
                                if selectedLanguages.contains(language) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(AppTheme.Colors.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Select Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
}

// FlowLayout helper
struct DubbingFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for size in sizes {
            if lineWidth + size.width > proposal.width ?? 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            totalWidth = max(totalWidth, lineWidth)
        }
        totalHeight += lineHeight
        
        return CGSize(width: totalWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if lineX + size.width > bounds.maxX {
                lineX = bounds.minX
                lineY += lineHeight + spacing
                lineHeight = 0
            }
            
            subview.place(at: CGPoint(x: lineX, y: lineY), proposal: .unspecified)
            lineX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    VoiceCloneDubbingView()
}

