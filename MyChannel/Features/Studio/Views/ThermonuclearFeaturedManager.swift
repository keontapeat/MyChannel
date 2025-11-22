//
//  ThermonuclearFeaturedManager.swift
//  MyChannel
//
//  🔥💥😤 THERMONUCLEAR FEATURED VIDEO MANAGER
//  Makes adding/removing featured videos EASY AS F***!
//  Swipe left to delete, tap + to add. That's it.
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ThermonuclearFeaturedManager: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = FeaturedManager()
    @State private var showingVideoSelector = false
    @State private var searchText = ""
    @State private var allVideos: [Video] = []
    @State private var isLoadingVideos = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 🔥 HEADER
                    thermonuclearHeader
                    
                    // 📊 STATS
                    statsBar
                    
                    // ⭐ FEATURED VIDEOS LIST
                    if manager.isLoading {
                        loadingView
                    } else if manager.featuredVideos.isEmpty {
                        emptyStateView
                    } else {
                        featuredVideosList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .sheet(isPresented: $showingVideoSelector) {
                videoSelectorSheet
            }
            .task {
                await manager.loadFeaturedVideos()
            }
            .alert("Error", isPresented: .constant(manager.errorMessage != nil)) {
                Button("OK") {
                    manager.errorMessage = nil
                }
            } message: {
                if let error = manager.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Header
    private var thermonuclearHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.Colors.surface.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Featured Videos")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Pin up to 3 flagship videos on your Home feed")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                Spacer()
            }
            
            Text("Keep this reel fresh with your premium drops. Viewers see it first thing on Home.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.surface)
        .overlay(
            Rectangle()
                .fill(AppTheme.Colors.divider.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Stats Bar
    private var statsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statCard(
                    title: "Featured",
                    value: "\(manager.featuredVideos.count)/3",
                    subtitle: "Live on Home",
                    icon: "star.fill"
                )
                
                statCard(
                    title: "Slots Open",
                    value: "\(max(0, 3 - manager.featuredVideos.count))",
                    subtitle: "Ready to pin",
                    icon: "plus.circle"
                )
                
                statCard(
                    title: "Views",
                    value: manager.totalViews,
                    subtitle: "From featured reel",
                    icon: "eye.fill"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(AppTheme.Colors.background)
    }
    
    private func statCard(title: String, value: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.Colors.surface.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    )
                
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(16)
        .frame(width: 180, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Featured Videos List (DRAG TO REORDER! 🔥)
    private var featuredVideosList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(manager.featuredVideos) { video in
                    FeaturedVideoRow(
                        video: video,
                        position: (manager.featuredVideos.firstIndex(where: { $0.id == video.id }) ?? 0) + 1,
                        total: manager.featuredVideos.count
                    ) {
                        await manager.removeFeaturedVideo(video)
                    } onMove: { from, to in
                        await manager.reorderVideos(from: from, to: to)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: manager.featuredVideos)
        }
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        Button {
            showingVideoSelector = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Add")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(manager.canAddMore ? AppTheme.Colors.primary : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(manager.canAddMore ? AppTheme.Colors.primary.opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
        .disabled(!manager.canAddMore)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 1)
                )
            
            VStack(spacing: 10) {
                Text("No Featured Videos Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Pin up to three marquee videos so your audience sees them first.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showingVideoSelector = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Add First Video")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.Colors.primary)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading featured videos...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Video Selector Sheet
    private var videoSelectorSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextField("Search your videos...", text: $searchText)
                        .font(.system(size: 16, weight: .regular))
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.surface)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Videos list
                if isLoadingVideos {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredVideos) { video in
                                SelectableVideoRow(video: video, isSelected: manager.isVideoFeatured(video)) {
                                    await addVideo(video)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Select Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingVideoSelector = false
                    }
                }
            }
            .task {
                await loadUserVideos()
            }
        }
    }
    
    private var filteredVideos: [Video] {
        if searchText.isEmpty {
            return allVideos
        }
        return allVideos.filter { video in
            video.title.localizedCaseInsensitiveContains(searchText) ||
            video.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadUserVideos() async {
        isLoadingVideos = true
        defer { isLoadingVideos = false }
        
        // Load user's videos from Firestore
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("videos")
                .whereField("creatorId", isEqualTo: AuthenticationManager.shared.currentUser?.id ?? "")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            allVideos = snapshot.documents.compactMap { doc in
                try? doc.data(as: Video.self)
            }
        } catch {
            print("❌ Error loading videos: \(error)")
        }
        #endif
    }
    
    private func addVideo(_ video: Video) async {
        await manager.addFeaturedVideo(video)
        showingVideoSelector = false
    }
}

// MARK: - Featured Video Row (SWIPE TO DELETE! 🔥)
struct FeaturedVideoRow: View {
    let video: Video
    let position: Int
    let total: Int
    let onRemove: () async -> Void
    let onMove: (Int, Int) async -> Void
    
    @State private var isPressed = false
    @State private var isRemoving = false
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background (revealed on swipe)
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Remove")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.9))
            )
            
            // Main content
            HStack(spacing: 12) {
                // Position badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.Colors.surface.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 1)
                        )
                    
                    Text("\(position)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                // Thumbnail with drag indicator
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                    .frame(width: 120, height: 68)
                    .cornerRadius(8)
                    
                    // Drag handle
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.45))
                        )
                        .padding(4)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text(video.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 8) {
                        Label(video.formattedViewCount, systemImage: "eye.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("•")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text(video.formattedDuration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Quick remove button
                Button {
                    isRemoving = true
                    Task {
                        await onRemove()
                        isRemoving = false
                    }
                } label: {
                    if isRemoving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .disabled(isRemoving)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 1)
                    )
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        // Only allow left swipe
                        if translation < 0 {
                            offset = translation
                            isSwiping = true
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        
                        // If swiped far enough, trigger delete
                        if translation < -100 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = -80
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                        
                        isSwiping = false
                    }
            )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Selectable Video Row
struct SelectableVideoRow: View {
    let video: Video
    let isSelected: Bool
    let onSelect: () async -> Void
    
    @State private var isSelecting = false
    
    var body: some View {
        Button {
            guard !isSelected else { return }
            isSelecting = true
            Task {
                await onSelect()
                isSelecting = false
            }
        } label: {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 120, height: 68)
                .cornerRadius(8)
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Label(video.formattedViewCount, systemImage: "eye.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("•")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text(video.formattedDuration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.green)
                } else if isSelecting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.1) : AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : AppTheme.Colors.divider.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .disabled(isSelected || isSelecting)
    }
}

// MARK: - Featured Manager
@MainActor
class FeaturedManager: ObservableObject {
    @Published var featuredVideos: [Video] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let maxFeatured = 3
    
    var canAddMore: Bool {
        featuredVideos.count < maxFeatured
    }
    
    var totalViews: String {
        let total = featuredVideos.reduce(0) { $0 + $1.viewCount }
        return formatViews(total)
    }
    
    func loadFeaturedVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("featured_videos")
                .order(by: "priority", descending: false)
                .limit(to: maxFeatured)
                .getDocuments()
            
            // Load video details
            var videos: [Video] = []
            for doc in snapshot.documents {
                if let videoId = doc.data()["videoId"] as? String {
                    if let video = try? await loadVideo(videoId: videoId) {
                        videos.append(video)
                    }
                }
            }
            
            featuredVideos = videos
        } catch {
            errorMessage = "Failed to load featured videos: \(error.localizedDescription)"
            print("❌ Error loading featured videos: \(error)")
        }
        #endif
    }
    
    func addFeaturedVideo(_ video: Video) async {
        guard canAddMore else {
            errorMessage = "Maximum 3 featured videos allowed"
            return
        }
        
        guard !isVideoFeatured(video) else {
            errorMessage = "Video is already featured"
            return
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let docRef = db.collection("featured_videos").document(UUID().uuidString)
            
            try await docRef.setData([
                "videoId": video.id,
                "priority": featuredVideos.count,
                "addedAt": FieldValue.serverTimestamp(),
                "addedBy": AuthenticationManager.shared.currentUser?.id ?? ""
            ])
            
            // Add to local array
            featuredVideos.append(video)
            
            print("✅ Added featured video: \(video.title)")
        } catch {
            errorMessage = "Failed to add video: \(error.localizedDescription)"
            print("❌ Error adding featured video: \(error)")
        }
        #endif
    }
    
    func removeFeaturedVideo(_ video: Video) async {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            
            // Find and delete the document
            let snapshot = try await db.collection("featured_videos")
                .whereField("videoId", isEqualTo: video.id)
                .getDocuments()
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
            
            // Remove from local array
            featuredVideos.removeAll { $0.id == video.id }
            
            // Update priorities
            await updatePriorities()
            
            print("✅ Removed featured video: \(video.title)")
        } catch {
            errorMessage = "Failed to remove video: \(error.localizedDescription)"
            print("❌ Error removing featured video: \(error)")
        }
        #endif
    }
    
    func isVideoFeatured(_ video: Video) -> Bool {
        featuredVideos.contains { $0.id == video.id }
    }
    
    func reorderVideos(from: Int, to: Int) async {
        guard from != to else { return }
        
        // Reorder local array
        var videos = featuredVideos
        let video = videos.remove(at: from)
        videos.insert(video, at: to)
        featuredVideos = videos
        
        // Update priorities in Firestore
        await updatePriorities()
        
        print("✅ Reordered videos: \(from) → \(to)")
    }
    
    private func updatePriorities() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        for (index, video) in featuredVideos.enumerated() {
            let snapshot = try? await db.collection("featured_videos")
                .whereField("videoId", isEqualTo: video.id)
                .getDocuments()
            
            if let doc = snapshot?.documents.first {
                try? await doc.reference.updateData(["priority": index])
            }
        }
        #endif
    }
    
    private func loadVideo(videoId: String) async throws -> Video? {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let doc = try await db.collection("videos").document(videoId).getDocument()
        return try? doc.data(as: Video.self)
        #else
        return nil
        #endif
    }
    
    private func formatViews(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Preview
#Preview {
    ThermonuclearFeaturedManager()
        .environmentObject(AppState.shared)
}

