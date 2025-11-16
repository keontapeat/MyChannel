//
//  PaginatedVideoGrid.swift
//  MyChannel
//
//  🔥 NUCLEAR: Paginated video grid with 24 videos per page
//  Smooth pagination with loading states and keyboard navigation
//

import SwiftUI

struct PaginatedVideoGrid: View {
    let careerPath: CareerPath
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    @State private var videos: [UniversityVideo] = []
    @State private var hasMoreVideos = true
    
    private let videosPerPage = 24
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    @FocusState private var focusedVideoId: String?
    
    var body: some View {
        VStack(spacing: 16) {
            // Video Grid
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(videos) { video in
                    VideoGridCard(video: video, careerPath: careerPath)
                        .focused($focusedVideoId, equals: video.id)
                        .id(video.id)
                        .onAppear {
                            // 🔥 PAGINATION: Load more when near bottom
                            if video.id == videos.suffix(6).first?.id && hasMoreVideos && !isLoadingMore {
                                Task {
                                    await loadMoreVideos()
                                }
                            }
                        }
                }
                
                // Loading indicator at bottom
                if isLoadingMore {
                    paginationLoadingIndicator
                }
            }
            .padding(.horizontal, 20)
            
            // Page indicator
            if videos.count > videosPerPage {
                pageIndicator
            }
        }
        .onAppear {
            Task {
                await loadInitialVideos()
            }
        }
    }
    
    // MARK: - Loading Indicator
    
    private var paginationLoadingIndicator: some View {
        HStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                
                Text("Loading more videos...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            Spacer()
        }
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            Text("Page \(currentPage + 1)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            if hasMoreVideos {
                Spacer()
                
                Button(action: {
                    Task {
                        await loadMoreVideos()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("Load More")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(careerPath.color)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Data Loading
    
    private func loadInitialVideos() async {
        isLoadingMore = true
        
        // Simulate loading (replace with actual service call)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        let mockVideos = generateMockVideos(page: 0, count: videosPerPage)
        
        await MainActor.run {
            videos = mockVideos
            currentPage = 0
            hasMoreVideos = true
            isLoadingMore = false
        }
        
        print("✅ [Pagination] Loaded page 0: \(mockVideos.count) videos")
    }
    
    private func loadMoreVideos() async {
        guard hasMoreVideos, !isLoadingMore else { return }
        
        isLoadingMore = true
        
        // Simulate loading
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let nextPage = currentPage + 1
        let mockVideos = generateMockVideos(page: nextPage, count: videosPerPage)
        
        await MainActor.run {
            videos.append(contentsOf: mockVideos)
            currentPage = nextPage
            
            // Simulate reaching end after 3 pages
            if nextPage >= 2 {
                hasMoreVideos = false
            }
            
            isLoadingMore = false
        }
        
        print("✅ [Pagination] Loaded page \(nextPage): \(mockVideos.count) videos (Total: \(videos.count))")
        
        // 🔥 ACCESSIBILITY: Announce new content
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(mockVideos.count) more videos loaded. Total: \(videos.count)"
        )
    }
    
    private func generateMockVideos(page: Int, count: Int) -> [UniversityVideo] {
        (0..<count).map { index in
            let globalIndex = (page * count) + index
            return UniversityVideo(
                id: "video_\(globalIndex)",
                videoId: "vid\(globalIndex)",
                title: "\(careerPath.name): Lesson \(globalIndex + 1)",
                thumbnailURL: "https://picsum.photos/400/\(225 + globalIndex)",
                duration: TimeInterval(1200 + index * 300),
                creatorId: "creator\(index)",
                creatorName: "Expert \(index + 1)",
                creatorAvatarURL: "https://picsum.photos/\(100 + index)/100",
                careerPaths: [careerPath.id],
                skillTags: Array(careerPath.skillTags.prefix(3)),
                difficultyLevel: [.beginner, .intermediate, .advanced].randomElement() ?? .intermediate,
                isUniversityContent: true,
                certificateEligible: true,
                aiCategorizationScore: Double.random(in: 0.8...0.99),
                watchProgress: index < 3 ? Double.random(in: 0.1...0.7) : 0.0,
                lastWatchedAt: index < 3 ? Date() : nil,
                aiVerificationScore: Int.random(in: 75...95),
                completed: index < 2
            )
        }
    }
    
    // MARK: - Keyboard Navigation
    
    private func navigateUp() {
        guard let currentId = focusedVideoId,
              let currentIndex = videos.firstIndex(where: { $0.id == currentId }) else { return }
        
        let targetIndex = currentIndex - 2 // Move up one row (2 columns)
        if targetIndex >= 0 {
            focusedVideoId = videos[targetIndex].id
        }
    }
    
    private func navigateDown() {
        guard let currentId = focusedVideoId,
              let currentIndex = videos.firstIndex(where: { $0.id == currentId }) else { return }
        
        let targetIndex = currentIndex + 2 // Move down one row (2 columns)
        if targetIndex < videos.count {
            focusedVideoId = videos[targetIndex].id
        }
    }
    
    private func navigateLeft() {
        guard let currentId = focusedVideoId,
              let currentIndex = videos.firstIndex(where: { $0.id == currentId }) else { return }
        
        let targetIndex = currentIndex - 1
        if targetIndex >= 0 {
            focusedVideoId = videos[targetIndex].id
        }
    }
    
    private func navigateRight() {
        guard let currentId = focusedVideoId,
              let currentIndex = videos.firstIndex(where: { $0.id == currentId }) else { return }
        
        let targetIndex = currentIndex + 1
        if targetIndex < videos.count {
            focusedVideoId = videos[targetIndex].id
        }
    }
}

// MARK: - Video Grid Card

struct VideoGridCard: View {
    let video: UniversityVideo
    let careerPath: CareerPath
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Thumbnail
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(careerPath.color.opacity(0.1))
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Progress Bar
                if video.watchProgress > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 3)
                            
                            Rectangle()
                                .fill(careerPath.color)
                                .frame(width: geometry.size.width * video.watchProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
            }
            
            // Title
            Text(video.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
            
            // Creator
            HStack(spacing: 4) {
                Text(video.creatorName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                if video.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(10)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(careerPath.color.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            print("Play video: \(video.title)")
            // TODO: Play video
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        // 🔥 ACCESSIBILITY
        .accessibilityElement(children: .combine)
        .accessibilityLabel(video.title)
        .accessibilityHint("Double tap to watch video")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        PaginatedVideoGrid(careerPath: CareerPath.allCareerPaths[0])
    }
    .background(AppTheme.Colors.background)
}

