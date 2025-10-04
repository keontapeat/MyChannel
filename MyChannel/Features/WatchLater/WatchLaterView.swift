//
//  WatchLaterView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct WatchLaterView: View {
    @StateObject private var watchLaterService = MockWatchLaterService()
    @State private var selectedSortOption: SortOption = .dateAdded
    @State private var showingStats = false
    @State private var searchText = ""
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case progress = "Watch Progress"
        case alphabetical = "Alphabetical"
        
        var iconName: String {
            switch self {
            case .dateAdded: return "calendar"
            case .progress: return "chart.bar"
            case .alphabetical: return "textformat.abc"
            }
        }
    }
    
    var sortedItems: [WatchLaterItem] {
        let filtered = searchText.isEmpty ? watchLaterService.watchLaterItems : 
            watchLaterService.watchLaterItems.filter { item in
                // In a real app, you'd fetch the video title from the video service
                true // Placeholder filtering
            }
        
        switch selectedSortOption {
        case .dateAdded:
            return filtered.sorted { $0.addedAt > $1.addedAt }
        case .progress:
            return filtered.sorted { $0.watchProgress > $1.watchProgress }
        case .alphabetical:
            return filtered.sorted { $0.videoId < $1.videoId } // Placeholder sorting
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Stats
                headerStatsSection
                
                // Search and Controls
                searchAndControlsSection
                
                // Watch Later List
                watchLaterListSection
            }
            .navigationTitle("Watch Later")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear Watched", action: clearWatchedItems)
                        Button("View Stats", action: { showingStats = true })
                        Divider()
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: { selectedSortOption = option }) {
                                HStack {
                                    Text(option.rawValue)
                                    if selectedSortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingStats) {
                WatchLaterStatsView(watchLaterService: watchLaterService)
            }
        }
    }
    
    private var headerStatsSection: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading) {
                Text("\(watchLaterService.watchLaterItems.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Total Videos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading) {
                Text("\(watchLaterService.watchLaterItems.filter { !$0.isWatched }.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text("Unwatched")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading) {
                Text("\(watchLaterService.watchLaterItems.filter { $0.isWatched }.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showingStats = true }) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var searchAndControlsSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search watch later...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Sort Options
            HStack {
                Text("Sort by:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: { selectedSortOption = option }) {
                                HStack(spacing: 4) {
                                    Image(systemName: option.iconName)
                                        .font(.caption)
                                    Text(option.rawValue)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedSortOption == option ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selectedSortOption == option ? .white : .primary)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var watchLaterListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if sortedItems.isEmpty {
                    emptyWatchLaterView
                } else {
                    ForEach(sortedItems) { item in
                        WatchLaterItemCard(
                            item: item,
                            video: Video.sampleVideos.first { $0.id == item.videoId },
                            onPlay: { playVideo(item) },
                            onRemove: { removeFromWatchLater(item) },
                            onMarkWatched: { markAsWatched(item) }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyWatchLaterView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Videos in Watch Later")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add videos to watch later to keep track of content you want to view")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Browse Videos") {
                // Navigate to home or explore
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Actions
    private func playVideo(_ item: WatchLaterItem) {
        // TODO: Navigate to video player
        print("Playing video: \(item.videoId)")
    }
    
    private func removeFromWatchLater(_ item: WatchLaterItem) {
        Task {
            do {
                try await watchLaterService.removeFromWatchLater(videoId: item.videoId, userId: item.userId)
            } catch {
                print("Error removing from watch later: \(error)")
            }
        }
    }
    
    private func markAsWatched(_ item: WatchLaterItem) {
        Task {
            do {
                _ = try await watchLaterService.markAsWatched(itemId: item.id)
            } catch {
                print("Error marking as watched: \(error)")
            }
        }
    }
    
    private func clearWatchedItems() {
        Task {
            do {
                try await watchLaterService.clearWatchedItems(for: "user-1")
            } catch {
                print("Error clearing watched items: \(error)")
            }
        }
    }
}

// MARK: - Watch Later Item Card
struct WatchLaterItemCard: View {
    let item: WatchLaterItem
    let video: Video?
    let onPlay: () -> Void
    let onRemove: () -> Void
    let onMarkWatched: () -> Void
    
    @State private var showingActionSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with Progress
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: video?.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "play.rectangle")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 120, height: 68)
                .cornerRadius(8)
                
                // Progress Bar
                if item.watchProgress > 0 {
                    VStack {
                        Spacer()
                        ProgressView(value: item.watchProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(x: 1, y: 0.5)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 2)
                    }
                }
                
                // Play Button Overlay
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(video?.title ?? "Unknown Video")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(video?.creator.displayName ?? "Unknown Creator")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Added \(item.timeAgo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.watchProgress > 0 {
                        Text("• \(item.progressPercentage)% watched")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack {
                    if item.isWatched {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Watched")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else if item.watchProgress > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("In Progress")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { showingActionSheet = true }) {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .confirmationDialog("Video Options", isPresented: $showingActionSheet) {
            Button("Play", action: onPlay)
            if !item.isWatched {
                Button("Mark as Watched", action: onMarkWatched)
            }
            Button("Remove from Watch Later", role: .destructive, action: onRemove)
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Watch Later Stats View
struct WatchLaterStatsView: View {
    @ObservedObject var watchLaterService: MockWatchLaterService
    @Environment(\.dismiss) private var dismiss
    @State private var stats: WatchLaterStats?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let stats = stats {
                        // Overview Stats
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Watch Later Stats")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                                WatchLaterStatCard(
                                    title: "Total Videos",
                                    value: "\(stats.totalItems)",
                                    icon: "play.rectangle.stack",
                                    color: .blue
                                )
                                
                                WatchLaterStatCard(
                                    title: "Completion Rate",
                                    value: "\(Int(stats.completionRate * 100))%",
                                    icon: "chart.pie",
                                    color: .green
                                )
                                
                                WatchLaterStatCard(
                                    title: "Average Progress",
                                    value: "\(Int(stats.averageWatchProgress * 100))%",
                                    icon: "gauge.medium",
                                    color: .orange
                                )
                                
                                WatchLaterStatCard(
                                    title: "Watch Time",
                                    value: "\(Int(stats.totalWatchTime / 3600))h",
                                    icon: "clock",
                                    color: .purple
                                )
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        // Progress Breakdown
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Progress Breakdown")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 12) {
                                ProgressBreakdownRow(
                                    title: "Not Started",
                                    count: stats.unwatchedItems,
                                    total: stats.totalItems,
                                    color: .gray
                                )
                                
                                ProgressBreakdownRow(
                                    title: "In Progress",
                                    count: stats.totalItems - stats.unwatchedItems - stats.watchedItems,
                                    total: stats.totalItems,
                                    color: .orange
                                )
                                
                                ProgressBreakdownRow(
                                    title: "Completed",
                                    count: stats.watchedItems,
                                    total: stats.totalItems,
                                    color: .green
                                )
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        // Quick Actions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Quick Actions")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 12) {
                                Button(action: {
                                    Task {
                                        try? await watchLaterService.clearWatchedItems(for: "user-1")
                                        dismiss()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Clear Watched Videos")
                                        Spacer()
                                        Text("\(stats.watchedItems) videos")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .disabled(stats.watchedItems == 0)
                                
                                Button(action: {
                                    // TODO: Navigate to playlist creation with watch later videos
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "plus.rectangle.on.folder")
                                        Text("Create Playlist from Watch Later")
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    } else {
                        ProgressView("Loading stats...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Watch Later Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadStats()
        }
    }
    
    private func loadStats() async {
        do {
            stats = try await watchLaterService.getWatchLaterStats(for: "user-1")
        } catch {
            print("Error loading stats: \(error)")
        }
    }
}

// MARK: - Supporting Views
struct WatchLaterStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProgressBreakdownRow: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("(\(Int(percentage * 100))%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    WatchLaterView()
}