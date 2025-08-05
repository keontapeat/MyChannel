//
//  StoriesView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct FlicksView: View {
    @State private var flicks: [Story] = Story.sampleStories
    @State private var isRefreshing: Bool = false
    @State private var selectedFlick: Story?
    @State private var showingFlickViewer: Bool = false
    @State private var searchText: String = ""
    @State private var selectedFilter: FlickFilter = .all
    @State private var showingCreateFlick: Bool = false
    
    private var filteredFlicks: [Story] {
        let filtered = flicks.filter { flick in
            if !searchText.isEmpty {
                return flick.creator?.displayName.localizedCaseInsensitiveContains(searchText) == true ||
                       flick.caption?.localizedCaseInsensitiveContains(searchText) == true
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered
        case .following:
            // For now, simulate following by checking if creator has more than 100k subscribers
            return filtered.filter { $0.creator?.subscriberCount ?? 0 > 100000 }
        case .trending:
            return filtered.filter { $0.mediaType == .video } // Simulate trending flicks
        case .recent:
            return filtered.filter { 
                Calendar.current.isDateInToday($0.createdAt) || 
                Calendar.current.isDateInYesterday($0.createdAt) 
            }
        }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced header with search and filters
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("")
                                .font(AppTheme.Typography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("\(filteredFlicks.count) active flicks")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingCreateFlick = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                
                                Text("Create")
                                    .font(AppTheme.Typography.bodyMedium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        TextField("Search flicks...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.md)
                    
                    // Filter tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(FlickFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.title,
                                    isSelected: selectedFilter == filter,
                                    count: flicksCount(for: filter)
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedFilter = filter
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.background)
                
                // Flicks grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredFlicks) { flick in
                            FlickCard(flick: flick) {
                                selectedFlick = flick
                                showingFlickViewer = true
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.md)
                }
                .refreshable {
                    await refreshFlicks()
                }
            }
            .background(AppTheme.Colors.background)
            .fullScreenCover(isPresented: $showingFlickViewer) {
                if let flick = selectedFlick {
                    StoryViewerView(
                        stories: flicks,
                        initialStory: flick,
                        onDismiss: {
                            showingFlickViewer = false
                            selectedFlick = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $showingCreateFlick) {
                CreateFlickView()
            }
        }
        .onAppear {
            loadFlicks()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadFlicks() {
        // Use existing sample stories as flicks
        flicks = Story.sampleStories
    }
    
    private func refreshFlicks() async {
        isRefreshing = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        flicks = Story.sampleStories
        isRefreshing = false
    }
    
    private func flicksCount(for filter: FlickFilter) -> Int {
        switch filter {
        case .all:
            return flicks.count
        case .following:
            // For now, simulate following by checking if creator has more than 100k subscribers
            return flicks.filter { $0.creator?.subscriberCount ?? 0 > 100000 }.count
        case .trending:
            return flicks.filter { $0.mediaType == .video }.count // Simulate trending flicks
        case .recent:
            return flicks.filter { 
                Calendar.current.isDateInToday($0.createdAt) || 
                Calendar.current.isDateInYesterday($0.createdAt) 
            }.count
        }
    }
}

// MARK: - Flick Filter
enum FlickFilter: String, CaseIterable {
    case all = "all"
    case following = "following"
    case trending = "trending"
    case recent = "recent"
    
    var title: String {
        switch self {
        case .all: return "All"
        case .following: return "Following"
        case .trending: return "Trending"
        case .recent: return "Recent"
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.white.opacity(0.3) : AppTheme.Colors.primary.opacity(0.2)
                        )
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppTheme.Colors.primary)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.clear)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : AppTheme.Colors.divider,
                        lineWidth: 1
                    )
            )
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flick Card (Updated for Flicks)
struct FlickCard: View {
    let flick: Story
    let onTap: () -> Void
    
    @State private var imageLoaded: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Flick preview
                ZStack(alignment: .topTrailing) {
                    // Background image/video preview
                    if !flick.mediaURL.isEmpty {
                        AsyncImage(url: URL(string: flick.mediaURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(9/16, contentMode: .fill)
                                    .clipped()
                            case .failure(_):
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .aspectRatio(9/16, contentMode: .fill)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "bolt.fill")
                                                .font(.title)
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                    )
                            case .empty:
                                Rectangle()
                                    .fill(AppTheme.Colors.surface)
                                    .aspectRatio(9/16, contentMode: .fill)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        // Text flick background
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .aspectRatio(9/16, contentMode: .fill)
                            .overlay(
                                VStack {
                                    if let caption = flick.caption {
                                        Text(caption)
                                            .font(.title3.weight(.medium))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .padding()
                                    }
                                }
                            )
                    }
                    
                    // Overlay gradients for better text readability
                    VStack {
                        LinearGradient(
                            colors: [Color.black.opacity(0.6), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                        
                        Spacer()
                        
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                    }
                    
                    // Media type indicator with flick branding
                    VStack {
                        HStack {
                            Spacer()
                            
                            if flick.mediaType == .video {
                                Image(systemName: "bolt.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.3)))
                                    .padding(.top, 8)
                                    .padding(.trailing, 8)
                            } else if flick.mediaType == .music {
                                Image(systemName: "music.note.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.3)))
                                    .padding(.top, 8)
                                    .padding(.trailing, 8)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .cornerRadius(AppTheme.CornerRadius.md)
                
                // Flick info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        AsyncImage(url: URL(string: flick.creator?.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.surface)
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(flick.creator?.displayName ?? "Unknown")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            
                            Text(flick.createdAt.timeAgoDisplay)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    
                    if let caption = flick.caption {
                        Text(caption)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Create Flick View
struct CreateFlickView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: CreateOption?
    
    enum CreateOption: CaseIterable {
        case camera, photo, text, music
        
        var title: String {
            switch self {
            case .camera: return "Camera"
            case .photo: return "Photo"
            case .text: return "Text"
            case .music: return "Music"
            }
        }
        
        var icon: String {
            switch self {
            case .camera: return "camera.fill"
            case .photo: return "photo.fill"
            case .text: return "text.bubble.fill"
            case .music: return "music.note"
            }
        }
        
        var color: Color {
            switch self {
            case .camera: return AppTheme.Colors.primary
            case .photo: return AppTheme.Colors.secondary
            case .text: return AppTheme.Colors.accent
            case .music: return .purple
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    VStack(spacing: 8) {
                        Text("Create Your Flick")
                            .font(AppTheme.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Share a quick moment that sparks joy")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    ForEach(CreateOption.allCases, id: \.self) { option in
                        Button(action: {
                            selectedOption = option
                            // Handle creation logic here
                            dismiss()
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(option.color.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: option.icon)
                                        .font(.system(size: 22))
                                        .foregroundColor(option.color)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.title)
                                        .font(AppTheme.Typography.headline)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    
                                    Text("Create a flick with \(option.title.lowercased())")
                                        .font(AppTheme.Typography.subheadline)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(AppTheme.Colors.surface)
                            .cornerRadius(AppTheme.CornerRadius.lg)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                
                Spacer()
            }
            .navigationTitle("Create Flick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
}

#Preview {
    FlicksView()
        .preferredColorScheme(.light)
}