//
//  StoriesView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct StoriesView: View {
    @State private var stories: [Story] = Story.sampleStories
    @State private var isRefreshing: Bool = false
    @State private var selectedStory: Story?
    @State private var showingStoryViewer: Bool = false
    @State private var searchText: String = ""
    @State private var selectedFilter: StoryFilter = .all
    @State private var showingCreateStory: Bool = false
    
    private var filteredStories: [Story] {
        let filtered = stories.filter { story in
            if !searchText.isEmpty {
                return story.creator.displayName.localizedCaseInsensitiveContains(searchText) ||
                       story.content.contains { $0.text?.localizedCaseInsensitiveContains(searchText) == true }
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered
        case .following:
            // For now, simulate following by checking if creator has more than 100k subscribers
            return filtered.filter { $0.creator.subscriberCount > 100000 }
        case .live:
            return filtered.filter { $0.isLive }
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
                            Text("Stories")
                                .font(AppTheme.Typography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("\(filteredStories.count) active stories")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingCreateStory = true
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
                            .background(AppTheme.Colors.gradient)
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        TextField("Search stories...", text: $searchText)
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
                            ForEach(StoryFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.title,
                                    isSelected: selectedFilter == filter,
                                    count: storiesCount(for: filter)
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
                
                // Stories grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredStories) { story in
                            StoryCard(story: story) {
                                selectedStory = story
                                showingStoryViewer = true
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.md)
                }
                .refreshable {
                    await refreshStories()
                }
            }
            .background(AppTheme.Colors.background)
            .fullScreenCover(isPresented: $showingStoryViewer) {
                if let story = selectedStory {
                    StoryViewerView(
                        stories: stories,
                        initialStory: story,
                        onDismiss: {
                            showingStoryViewer = false
                            selectedStory = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $showingCreateStory) {
                CreateStoryView()
            }
        }
        .onAppear {
            loadStories()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadStories() {
        // Simulate loading fresh stories
        stories = Story.generateFreshStories()
    }
    
    private func refreshStories() async {
        isRefreshing = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        stories = Story.generateFreshStories()
        isRefreshing = false
    }
    
    private func storiesCount(for filter: StoryFilter) -> Int {
        switch filter {
        case .all:
            return stories.count
        case .following:
            // For now, simulate following by checking if creator has more than 100k subscribers
            return stories.filter { $0.creator.subscriberCount > 100000 }.count
        case .live:
            return stories.filter { $0.isLive }.count
        case .recent:
            return stories.filter { 
                Calendar.current.isDateInToday($0.createdAt) || 
                Calendar.current.isDateInYesterday($0.createdAt) 
            }.count
        }
    }
}

// MARK: - Story Filter
enum StoryFilter: String, CaseIterable {
    case all = "all"
    case following = "following"
    case live = "live"
    case recent = "recent"
    
    var title: String {
        switch self {
        case .all: return "All"
        case .following: return "Following"
        case .live: return "Live"
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
                            .fill(AppTheme.Colors.gradient)
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

// MARK: - Story Card
struct StoryCard: View {
    let story: Story
    let onTap: () -> Void
    
    @State private var imageLoaded: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Story preview
                ZStack(alignment: .topTrailing) {
                    // Background image/video preview
                    if let firstContent = story.content.first {
                        AsyncImage(url: URL(string: firstContent.url)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(9/16, contentMode: .fill)
                                    .clipped()
                            case .failure(_):
                                Rectangle()
                                    .fill(AppTheme.Colors.gradient)
                                    .aspectRatio(9/16, contentMode: .fill)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "photo")
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
                        Rectangle()
                            .fill(AppTheme.Colors.gradient)
                            .aspectRatio(9/16, contentMode: .fill)
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
                    
                    // Live indicator
                    if story.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                                .scaleEffect(1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                            
                            Text("LIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red)
                        .cornerRadius(12)
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                    }
                    
                    // Story content count
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            // Progress indicators
                            HStack(spacing: 2) {
                                ForEach(0..<min(story.content.count, 5), id: \.self) { _ in
                                    Rectangle()
                                        .fill(.white.opacity(0.6))
                                        .frame(width: 20, height: 2)
                                        .cornerRadius(1)
                                }
                            }
                            .padding(.bottom, 12)
                            .padding(.trailing, 8)
                        }
                    }
                }
                .cornerRadius(AppTheme.CornerRadius.md)
                
                // Story info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        AsyncImage(url: URL(string: story.creator.profileImageURL ?? "")) { image in
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
                            Text(story.creator.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            
                            Text(story.createdAt.timeAgoDisplay)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    
                    if let firstTextContent = story.content.first(where: { $0.text != nil }) {
                        Text(firstTextContent.text ?? "")
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

// MARK: - Create Story View
struct CreateStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: CreateOption?
    
    enum CreateOption: CaseIterable {
        case camera, photo, text, live
        
        var title: String {
            switch self {
            case .camera: return "Camera"
            case .photo: return "Photo"
            case .text: return "Text"
            case .live: return "Go Live"
            }
        }
        
        var icon: String {
            switch self {
            case .camera: return "camera.fill"
            case .photo: return "photo.fill"
            case .text: return "text.bubble.fill"
            case .live: return "dot.radiowaves.left.and.right"
            }
        }
        
        var color: Color {
            switch self {
            case .camera: return AppTheme.Colors.primary
            case .photo: return AppTheme.Colors.secondary
            case .text: return AppTheme.Colors.accent
            case .live: return .red
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    VStack(spacing: 8) {
                        Text("Create Your Story")
                            .font(AppTheme.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Share a moment with your followers")
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
                                    
                                    Text("Create a story with \(option.title.lowercased())")
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
            .navigationTitle("Create Story")
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

// MARK: - Date Extension
extension Date {
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    StoriesView()
}